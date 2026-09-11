# スクリーンタイム/AI講評 仕様書 (Flutter)

このドキュメントはホーム画面のスクリーンタイム表示・ドパガキ指数・AI講評まわりの実装([lib/screens/home_body.dart](../lib/screens/home_body.dart)、[lib/services/](../lib/services/)、[lib/widgets/](../lib/widgets/)など)の仕様書です。
**コードが正**であり、このドキュメントはそれを読み解くための資料です。実装を変更したら、このドキュメントも合わせて更新してください。

DBスキーマ・RPCの詳細は [db_schema.md](db_schema.md) を参照。

## 目次

- [設計方針](#設計方針)
- [全体構成](#全体構成)
- [ホーム画面の表示ロジック(HomeBody)](#ホーム画面の表示ロジックhomebody)
- [状態管理(ScreenTimeRegistry)](#状態管理screentimeregistry)
- [ドパガキ指数の算出](#ドパガキ指数の算出)
- [ドパガキ対象アプリの判定](#ドパガキ対象アプリの判定)
- [カード一覧](#カード一覧)
- [データ取得の抽象化とモック実装](#データ取得の抽象化とモック実装)
- [UIスタイル](#uiスタイル)
- [テスト](#テスト)
- [既知の制約・今後の課題](#既知の制約今後の課題)

---

## 設計方針

| # | 方針 | 理由 |
|---|---|---|
| 1 | 状態管理は `ChildRegistry`/`AppSession` と同じ「ChangeNotifierシングルトン + `addListener`/`setState`」に統一する | アプリ全体がこの流儀で統一されており、`InheritedWidget`系を混在させると購読方法が画面ごとにバラつく |
| 2 | データ取得は `ScreenTimeService`/`AiCommentaryService` インターフェース越しに行い、呼び出し側はモック/実装の区別を意識しない | 実機のOS API・バックエンドAPIへの差し替えが、実装クラスの追加だけで完結するようにするため |
| 3 | ドパガキ指数はAI講評とセットで算出する(`AiCommentary.dopagakiIndex`) | 単純な比率計算ではなく、AIがスクリーンタイムの内訳(絶対的な利用時間・一極集中度など)から総合的に採点するため |
| 4 | 子ども一覧・選択そのものは持たず、既存の `ChildRegistry`/`AppSession` に委譲する | 二重管理を避け、`AccountBar` の子供切り替えと表示内容を自動的に同期させる |

### 用語

- **ドパガキ指数** … SNS・動画・ゲームなど「ドパガキ対象アプリ」への依存・没入の深刻さをAIが0〜100で採点した指標。高いほど依存が深刻。DB上は `ai_reviews.dopagaki_score`([db_schema.md](db_schema.md#ai_reviews--ai講評--ドパガキ指数))に対応する概念。
- **AI講評** … その日のスクリーンタイムをもとにした、要約(`summary`)・アドバイス(`adviceList`)・ドパガキ指数の採点理由(`scoreReason`)のセット。
- **ドパガキ対象アプリ** … 短時間で強い刺激が得られて没入しやすいアプリ(SNS・動画・ショート動画・ゲーム)。**どのアプリが対象かはアプリ側では判定せず、Geminiがアプリ名とパッケージ名から都度判断する**([ドパガキ対象アプリの判定](#ドパガキ対象アプリの判定)参照)。

---

## 全体構成

```
lib/
  models/
    app_usage.dart          # 1アプリぶんの利用時間
    screen_time_day.dart    # 1日ぶんのスクリーンタイム(アプリ別内訳込み)
    dopagaki_index.dart     # ドパガキ指数(percentage, label)
    ai_commentary.dart      # AI講評(summary, adviceList, generatedAt)
  services/
    screen_time_service.dart      # ScreenTimeService(抽象) + MockScreenTimeService
    ai_commentary_service.dart    # AiCommentaryService(抽象)
    supabase_ai_commentary_service.dart  # 唯一の実装(Gemini呼び出し) + AiCommentaryException
    dopagaki_calculator.dart      # ScreenTimeDay → DopagakiIndex
    screen_time_registry.dart     # 状態管理のシングルトン
  widgets/
    dopagaki_index_card.dart      # 「昨日のドパガキ指数」カード
    screen_time_card.dart         # 「先日のスクリーンタイム」カード
    screen_time_charts.dart       # ↑が使う時間帯別グラフ/アプリ別内訳リスト
    ai_commentary_card.dart       # 「AIによる講評」カード
  screens/
    home_body.dart                # 上記3枚のカードを並べるホーム画面本体
```

`HomeBody` は [main_shell.dart](../lib/screens/main_shell.dart) の `IndexedStack` の1タブ目(ホームタブ)として表示される。

---

## ホーム画面の表示ロジック(HomeBody)

[home_body.dart](../lib/screens/home_body.dart) は `StatefulWidget`。`initState`/`dispose` で以下3つのシングルトンを購読し、変化があれば `setState` で再描画する([account_bar.dart](../lib/widgets/account_bar.dart) の `_AccountBarState` と同じパターン)。

- `ChildRegistry.instance`(子ども一覧・選択)
- `AppSession.instance`(ログイン中のロール・グループ)
- `ScreenTimeRegistry.instance`(スクリーンタイム/AI講評のキャッシュ)

### 表示対象の子どもの決定

```dart
ChildProfile? _resolveChild() {
  return AppSession.instance.isChild
      ? AppSession.instance.childProfile
      : ChildRegistry.instance.selectedInGroup(AppSession.instance.groupCode);
}
```

- 子どもアカウントでログイン中 → 自分自身のデータを表示
- 保護者アカウントでログイン中 → `AccountBar` の子供切り替えで選択中の子ども(`ChildRegistry.selectedInGroup`)のデータを表示
- 該当する子どもがいない場合(保護者がまだ子どもを登録していない等)は「子供が選択されていません」を表示し、カードは描画しない

### 読み込みトリガ

```dart
void _ensureLoaded(ChildProfile child) {
  if (identical(child, _lastLoadedChild)) return;
  _lastLoadedChild = child;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScreenTimeRegistry.instance.ensureScreenTimeLoaded(child);
  });
}
```

`ensureScreenTimeLoaded` は同期的に `notifyListeners()` を呼ぶため、`build()` の実行中に直接呼ぶとFlutterのアサーションに引っかかる。そのため `addPostFrameCallback` でフレーム確定後まで遅延させている。対象の子どもが変わった時だけ読み込みを走らせるため、`identical()` で前回と同一インスタンスかを見ている。

### 画面構成

`FuturisticBackground` の上に `RefreshIndicator`(下に引っ張って `refreshScreenTime` を呼ぶ) → `SingleChildScrollView` → 3枚のカードを縦に並べる。

```dart
Column(
  children: [
    DopagakiIndexCard(index: dopagakiIndex, isLoading: loadingScreenTime),
    ScreenTimeCard(days: days, isLoading: loadingScreenTime),
    AiCommentaryCard(child: child),
  ],
)
```

---

## 状態管理(ScreenTimeRegistry)

[screen_time_registry.dart](../lib/services/screen_time_registry.dart) は `ChangeNotifier` のシングルトン(`ScreenTimeRegistry.instance`)で、子どもごとのスクリーンタイム/AI講評のキャッシュと読み込み状態を保持する。

`ChildProfile` はグループ内で一意な `name` しか持たない(`id` フィールドが無い)ため、キャッシュキーは `'${groupCode}/${name}'` の合成文字列にしている(`_keyFor`)。

| メンバー | 役割 |
|---|---|
| `screenTimeService` / `aiCommentaryService` | 差し替え可能なサービス実装。既定値は `screenTimeService` が `MockScreenTimeService`、`aiCommentaryService` が本番実装の `SupabaseAiCommentaryService`(モックへのフォールバックは無い) |
| `screenTimeFor(child)` / `isScreenTimeLoading(child)` | キャッシュ済みのスクリーンタイムと読み込み中フラグ |
| `commentaryFor(child)` / `isCommentaryLoading(child)` | キャッシュ済みのAI講評と読み込み中フラグ |
| `commentaryErrorFor(child)` | 直近の `getOrGenerateCommentary` が失敗した場合の日本語メッセージ。成功時・未リクエスト時は `null` |
| `ensureScreenTimeLoaded(child)` | 未取得なら `screenTimeService.fetchRecentScreenTime` を呼び、結果をキャッシュ |
| `refreshScreenTime(child)` | キャッシュ(スクリーンタイム・AI講評とも)を破棄して再取得 |
| `dopagakiIndexFor(child)` | キャッシュ済みのAI講評があればその `dopagakiIndex`。無ければスクリーンタイム未取得時は `DopagakiIndex.empty`、取得済みだが講評未生成なら `DopagakiIndex.notGenerated`(「未算出」) |
| `getOrGenerateCommentary(child)` | キャッシュがあれば返す。無ければスクリーンタイムの取得を待って `aiCommentaryService.generateCommentary` を呼び、結果をキャッシュ |
| `regenerateCommentary(child)` | AI講評だけを作り直す。メモリ上のキャッシュを先に破棄して `notifyListeners()` するため、カードは古い講評を表示し続けずに即座にローディング状態へ切り替わる。`force: true` で呼ぶため、サーバ側の `ai_reviews` の行も上書きされる(`(child_id, date)` の一意制約による upsert なので、古い行が別行として残ることはない) |
| `clear()` | 全キャッシュを破棄。サインアウト時に呼ばれる |

サインアウト時は [session_bridge.dart](../lib/services/session_bridge.dart) の `SessionBridge.clear()` が `ChildRegistry.instance.clear()` と合わせて `ScreenTimeRegistry.instance.clear()` を呼ぶ。

---

## ドパガキ指数の算出

ドパガキ指数はAI講評([AiCommentaryService.generateCommentary](../lib/services/ai_commentary_service.dart))が講評本文とセットで算出する。単純な「ドパガキ対象アプリの時間 ÷ 総利用時間」の比率ではなく、`supabase/functions/ai-review/index.ts` のプロンプトで次の3点を総合するようGeminiに指示している:

- (a) ドパガキ対象アプリの**絶対的な利用時間の長さ**(長時間ほど高スコア)
- (b) 特定の1アプリへの**一極集中の度合い**(偏っているほど高スコア)
- (c) 総利用時間に占めるドパガキ対象アプリの割合

総利用時間そのものが短い日は、割合が高くてもスコアを抑えめにするよう指示している。ラベル付け(`良好`/`注意`/`危険`)は [dopagaki_calculator.dart](../lib/services/dopagaki_calculator.dart) の `DopagakiCalculator.labelFor(percentage)` に集約:

- `percentage < 30` → `良好`
- `30 <= percentage < 60` → `注意`
- `percentage >= 60` → `危険`

`DopagakiCalculator` に残るのは `labelFor(percentage)`(しきい値によるラベル付け)のみで、AIが返したスコアのラベル付けに使う。

`ScreenTimeRegistry.dopagakiIndexFor` は、講評未生成の間は `DopagakiIndex.notGenerated`(「未算出」)を返す。「昨日のドパガキ指数」カード([dopagaki_index_card.dart](../lib/widgets/dopagaki_index_card.dart))はこのとき数値の代わりに「—」を表示する。

### 採点理由(scoreReason)

Geminiは点数と一緒に、その点数にした理由(`score_reason`)も返す。「どのアプリの何分をドパガキ対象と見たか」「上記(a)(b)(c)のどれが効いたか」を実際の数字を挙げて1〜2文で説明するようプロンプトで指示している。`ai_reviews.score_reason` 列([0015_ai_reviews_score_reason.sql](../supabase/migrations/0015_ai_reviews_score_reason.sql))に保存され、`AiCommentary.scoreReason` として「AIによる講評」カードに `ドパガキ指数 XX%(ラベル)の理由` の見出し付きで表示される。

この列の追加より前に生成された行には理由が無いため `scoreReason` は null 許容で、null のときはカードに理由ブロックを出さない。

---

## ドパガキ対象アプリの判定

どのアプリが「ドパガキ対象」かは**アプリ側では判定せず、Geminiに委ねている**。`ai-review` へ送るのはアプリの表示名・Androidのパッケージ名・利用分数だけで、判定用のフラグは送らない。

以前は `AppCatalog` がパッケージ名の固定表から `isDistracting` を決めてEdge Functionへ送っていたが、表に無いアプリがすべて「対象外」として明示されるため、実際は動画配信やゲームのアプリをGeminiが対象外として扱い、講評がズレる原因になっていた。対象アプリは次々に増えるので固定表では追いつかない、という判断で撤廃した。

その結果:

- `AppCatalog`([app_catalog.dart](../lib/services/app_catalog.dart))の責務は**アプリ別内訳グラフの表示色を引くこと**だけ(`AppCatalog.colorFor(packageName)`)。既知アプリはブランド色、未知アプリはパッケージ名から決定的に生成した色。
- `AppUsage` に `isDistracting` は無い。`ScreenTimeDay.distractingTotal` も併せて撤廃した(どちらもAIプロンプト以外の利用箇所が無かった)。
- 代わりにEdge Functionのプロンプトで、ドパガキ対象の定義・学習/音楽/地図/連絡手段などを依存の根拠にしないこと・ブラウザのような用途が定まらないアプリは断定を避けること・判断できないアプリには言及しないこと・内訳に無いアプリを憶測で挙げないこと、を明示している。

---

## カード一覧

3枚とも見出しの命名規則は `XxxCard`(ファイル名 `xxx_card.dart`)で統一し、外形は共通の `GlassCard`([UIスタイル](#uiスタイル)参照)を使う。

### DopagakiIndexCard(昨日のドパガキ指数)

[dopagaki_index_card.dart](../lib/widgets/dopagaki_index_card.dart)。`index: DopagakiIndex` と `isLoading: bool` を受け取る `StatelessWidget`。

- ラベル(`危険`/`注意`/`良好`/その他)に応じて枠線・文字色を `AppColors.danger`/`warning`/`good`/白60%に切り替える
- 読み込み中は右側を `CircularProgressIndicator` に差し替える

### ScreenTimeCard(先日のスクリーンタイム)

[screen_time_card.dart](../lib/widgets/screen_time_card.dart)。`days: List<ScreenTimeDay>?` と `isLoading: bool` を受け取る。

- `days == null || isLoading` の間はローディング表示
- 取得後は [screen_time_charts.dart](../lib/widgets/screen_time_charts.dart) の2つのウィジェットを表示:
  - `HourlyScreenTimeChart` … 最新日(`days.first` = 昨日)の時間帯別(0〜23時)利用時間を棒グラフで表示。`ScreenTimeDay.hourlyUsage`(24要素、未取得時は null)が無ければ「時間帯別の記録がありません」を表示
  - `AppBreakdownList` … 直近7日間(`days`)を使い、最新日のアプリ別内訳を横棒グラフで表示。行タップで「昨日 vs 先週平均」の詳細が見られる(先週平均の算出に7日分すべてを使う)

### AiCommentaryCard(AIによる講評)

[ai_commentary_card.dart](../lib/widgets/ai_commentary_card.dart)。`child: ChildProfile` を受け取り、`ScreenTimeRegistry.instance` を `AnimatedBuilder` で購読する。

- 未取得かつ未読込中・エラー無し → 「講評を見る」ボタン。押下で `getOrGenerateCommentary(child)` を呼ぶ
- 読込中 → `CircularProgressIndicator`
- 直近の取得が失敗(`commentaryErrorFor(child)` が非null) → エラー文言 + 「再試行」ボタン
- 取得済み → `summary` 本文 + `scoreReason`(あれば `ドパガキ指数 XX%(ラベル)の理由` 見出し付きのブロック)+ `adviceList` の箇条書き + 生成時刻(`generatedAt` を `HH:mm 時点の講評` 形式で表示)
- 「講評を見る」を押して一度表示された後(`_revealed == true`)は、見出し行の右端にリロードアイコン(`Icons.refresh_rounded`)が出る。押すと `registry.regenerateCommentary(child)` を呼び、古い講評を消してから作り直す。読込中は無効化され、二重に押せない

---

## データ取得の抽象化とモック実装

### ScreenTimeService

[screen_time_service.dart](../lib/services/screen_time_service.dart)。

```dart
abstract class ScreenTimeService {
  Future<List<ScreenTimeDay>> fetchRecentScreenTime(String childId, {int days = 7});
}
```

`MockScreenTimeService` は `childId.hashCode` をシードにした疑似乱数で、固定のアプリカタログ(YouTube/TikTok/Instagram/ゲームアプリ/LINE/勉強アプリ)から各アプリの利用時間をランダム生成する。同じ子どもなら再起動しても同じ傾向のデータになる。400msのダミー遅延あり。

実機のOS API(Android UsageStats / iOS Screen Time)やバックエンドAPIと接続する際は、この抽象クラスを実装した別クラス(例: `SupabaseScreenTimeService`)を作り、`ScreenTimeRegistry.instance.screenTimeService` を差し替えるだけでよい。

### AiCommentaryService

[ai_commentary_service.dart](../lib/services/ai_commentary_service.dart)。

```dart
abstract class AiCommentaryService {
  Future<AiCommentary> generateCommentary({
    required ChildProfile child,
    required ScreenTimeDay screenTime,
    bool force = false,
  });
}
```

ドパガキ指数もこのサービスが算出する(`AiCommentary.dopagakiIndex`)ため、`dopagakiIndex` は引数に無い。

`force` は「サーバ側に同じ日付の講評が保存済みでも作り直す」フラグ。`ScreenTimeRegistry.refreshScreenTime`(引っ張って更新)を通ったキーだけ `true` になる(`_commentaryNeedsRegenerate`)。これが無いと、スクリーンタイムの同期が終わる前に一度生成された講評が `ai_reviews` に固定され、その日はデータを取り直しても古い数字ベースの講評が返り続けてしまう。

**`SupabaseAiCommentaryService`**([supabase_ai_commentary_service.dart](../lib/services/supabase_ai_commentary_service.dart)) — 実際にGeminiで生成する唯一の実装で、モックへのフォールバックは無い。`ScreenTimeRegistry.aiCommentaryService` の既定値であり、`main.dart` での差し替えは不要(`ActivityService.locationService` と同じ流儀)。

- Supabase Edge Function `ai-review`([supabase/functions/ai-review/index.ts](../supabase/functions/ai-review/index.ts))を `Supabase.instance.client.functions.invoke('ai-review', body: {...})` で呼ぶ。ボディは `child_id`・`date`(YYYY-MM-DD)・`force`・`screen_time`(`total_minutes` とアプリ別内訳 `apps: [{name, minutes, app_id}]`)
- Edge Function 側の処理:
  1. 呼び出し元のJWTで対象の子が同じグループのメンバーか検証(profiles_select_group RLSを利用)。親・子どちらから呼んでも同じ検証で通るため、**同じ子の同じ日付なら親子で同一の講評が返る**
  2. `force` でなく `ai_reviews (child_id, date)` に既存行があれば、Geminiを呼ばずそれを返す(1日1回の生成に固定し、親子で必ず同じ結果になる)
  3. なければ Gemini Interactions API(`POST https://generativelanguage.googleapis.com/v1beta/interactions`)を呼び、`dopagaki_score`(0-100)・`score_reason`・`summary`・`advice: string[]` をJSONスキーマで強制取得
  4. 取得結果を `ai_reviews` にservice roleで保存(`0008_ai_reviews_advice.sql` の `advice` 列に配列、`0015_ai_reviews_score_reason.sql` の `score_reason` 列に採点理由)
- `child.id` が無い(Supabase未連携)・Edge Functionが `gemini_not_configured` を返す(APIキー未設定)・通信エラー・レスポンス形状が想定外、のいずれかの場合は `AiCommentaryException`(`activity-suggest` の `ActivitySuggestException` と同じ形。想定外のレスポンス形状のみ `FormatException`)を投げる。フォールバックはせず、常に実際のAI応答だけを採用する
- `ScreenTimeRegistry.getOrGenerateCommentary` がこの例外を捕捉し、`commentaryErrorFor(child)` に日本語メッセージを保存する。`AiCommentaryCard` はこれを検知すると講評の代わりにエラー文言と「再試行」ボタンを表示する(`activity_body.dart` の `_notice` と同じ考え方)
- Geminiへのプロンプト方針: SNS利用の禁止・削減ではなく**適切な距離感での利用を促す**トーン。子どもを断罪しない。ドパガキ指数は単純な比率ではなく「絶対的な利用時間の長さ・一極集中度・総利用時間比」を総合するよう指示している。ドパガキ対象アプリの判定もGeminiに委ねている([ドパガキ対象アプリの判定](#ドパガキ対象アプリの判定)参照)。また、渡すのはその日1日分だけなので**前日以前との比較や増減には触れない**よう明示している(週次グラフを見ながら読む保護者にズレて見えるのを避けるため)

呼び出し側(`ScreenTimeRegistry.getOrGenerateCommentary`)は `AiCommentaryService` インターフェースにしか依存していないため、実装の差し替えによる影響範囲は上記2ファイルに収まる。テストは `AiCommentaryService` を実装した独自の `_FakeAiCommentaryService` を代入するため、この例外設計の影響を受けない。

---

## UIスタイル

3枚のカードは [glass_card.dart](../lib/widgets/glass_card.dart) の `GlassCard` を共通の外枠に使う(角丸16 + 背景ぼかし + 白8%塗り + ネオンシアン `#33F7FF` の枠線とグロー)。ホーム画面全体の背景は [futuristic_background.dart](../lib/widgets/futuristic_background.dart) の `FuturisticBackground`(アニメーションするグリッド演出)。

配色は原則 [app_colors.dart](../lib/theme/app_colors.dart) の `AppColors` を使うが、ネオンシアン(`#33F7FF`)とマゼンタ(`#FF3DAE`、AI講評アイコン)は `home_body.dart` 周辺の既存コードに合わせてリテラル直書きしている。ドパガキ指数の状態色として `AppColors.danger`/`warning`/`good`/`surfaceAlt` を使用する。

---

## テスト

[test/screens/home_body_test.dart](../test/screens/home_body_test.dart)。`ScreenTimeRegistry.instance.screenTimeService`/`aiCommentaryService` はフィールドなのでテストからフェイク実装に差し替え可能。

- `setUp` で `ChildRegistry`/`ScreenTimeRegistry` をクリアし、`AppSession.loginAsParent()` + `ChildRegistry.addChild()` でグループと子どもを用意
- 検証1: 起動直後に「昨日のドパガキ指数」「先日のスクリーンタイム」「AIによる講評」が表示される
- 検証2: 「講評を見る」タップ後にボタンが消え、講評本文が表示される
- 検証3: 講評にドパガキ指数の採点理由(`ドパガキ指数 XX%(ラベル)の理由` の見出し + 本文)が表示される
- 検証4: ドパガキ指数は講評生成前は「未算出」、生成後はAIが返した値になる

**注意**: `FuturisticBackground` は `AnimationController(...)..repeat()` で無限にアニメーションし続けるため、`pumpAndSettle()` は永久にタイムアウトする。テストでは `tester.pump()` + 固定時間の `tester.pump(Duration(...))` を使うこと。

---

## 既知の制約・今後の課題

- **スクリーンタイムは Android 実機のみ実データ**。`ScreenTimeRegistry.screenTimeService` の既定値は `DeviceScreenTimeService` で、子ども本人が Android 端末でログインしている場合のみ `AndroidScreenTimeService`(`UsageStatsManager` を MethodChannel `com.yellow.yellow_sns_education/screen_time` 経由で呼ぶ)から取得し、その結果を `screen_time_daily`/`screen_time_apps`([db_schema.md](db_schema.md#screen_time_daily--screen_time_apps--スクリーンタイム))へバックグラウンド同期する。保護者(または子ども以外)は `SupabaseScreenTimeService` でそのテーブルを読む。iOS・Web・デスクトップでは(保護者のログイン先が Chrome 等の場合も含めて)`ScreenTimeUnavailableException(unsupportedPlatform)` を投げ、「お使いの端末ではスクリーンタイム参照ができません」を表示する。`MockScreenTimeService` はテスト用の差し替え先として引き続き残っている
- **`AppUsage.color` に対応するDB列は無い**。`screen_time_apps` は `app_id`/`app_label` のみを持つため、`AppCatalog`(`lib/services/app_catalog.dart`)がパッケージ名から色を決める。既知アプリ(YouTube/TikTok/Instagram等)は固定のブランド色、未知アプリはパッケージ名から決定的に生成した色になる
- **内訳は「ユーザーが自分で開くアプリ」だけに絞っている**。`UsageStatsManager` はシステムUI・IME・ホームアプリなど裏方のフォアグラウンド時間も返すため、`ScreenTimePlugin.queryDailyUsage` でランチャー用エントリを持たないパッケージ(`getLaunchIntentForPackage` が null)とホームアプリ(`CATEGORY_HOME` の解決先)を除外している。絞らないと総利用時間が膨らみ、AI講評が「一番よく使っているアプリ」としてランチャーを挙げてしまう。副作用として、ランチャーから起動できない特殊なアプリも内訳から落ちる
- **すでに `ai_reviews` に保存済みの過去日の講評は作り直されない**。`force` は `refreshScreenTime` を通ったキーにしか付かないため、`score_reason` 列の追加より前に生成された行は理由が null のまま残る。その日の講評を作り直したい場合は、ホーム画面で下に引っ張って更新してから「講評を見る」を押す
- **Edge Functionはリクエストボディのスクリーンタイムをそのまま信頼する**。`ai-review` は呼び出し元が「同じグループのメンバーか」だけを検証しており、送られてきた `screen_time` の値自体が本物かは検証していない。将来的に `screen_time_daily`/`screen_time_apps` から直接読む実装に変えれば、この点は解消される
- **`purge_old_screen_time()` の自動実行は未設定**([db_schema.md](db_schema.md#未対応今後の課題)と共通)。`ai_reviews` は保持期間の対象外なので、こちらは影響しない
- **AI講評はモックへのフォールバックを行わない**。`GEMINI_API_KEY` 未設定・通信エラー・Gemini呼び出し失敗時は `AiCommentaryCard` にエラー文言と「再試行」ボタンが出るだけで、講評自体は表示されない。ダミー文言で体験を継続させていた以前の挙動と異なる点に注意
