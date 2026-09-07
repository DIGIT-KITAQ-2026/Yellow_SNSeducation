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
| 3 | ドパガキ指数の算出ロジックは `DopagakiCalculator` に集約する | 「昨日のドパガキ指数」カードと「AI講評」の両方が同じ計算結果を参照する必要があるため |
| 4 | 子ども一覧・選択そのものは持たず、既存の `ChildRegistry`/`AppSession` に委譲する | 二重管理を避け、`AccountBar` の子供切り替えと表示内容を自動的に同期させる |

### 用語

- **ドパガキ指数** … その日の総利用時間に対する「ドパガキ対象アプリ(SNS・動画・ゲームなど)」の割合(0〜100)。高いほど依存が深刻。DB上は `ai_reviews.dopagaki_score`([db_schema.md](db_schema.md#ai_reviews--ai講評--ドパガキ指数))に対応する概念。
- **AI講評** … その日のスクリーンタイムをもとにした、要約(`summary`)とアドバイス(`adviceList`)のセット。

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
    ai_commentary_service.dart    # AiCommentaryService(抽象) + MockAiCommentaryService
    dopagaki_calculator.dart      # ScreenTimeDay → DopagakiIndex
    screen_time_registry.dart     # 状態管理のシングルトン
  widgets/
    dopagaki_index_card.dart      # 「昨日のドパガキ指数」カード
    screen_time_card.dart         # 「先日のスクリーンタイム」カード
    screen_time_charts.dart       # ↑が使う週次グラフ/アプリ別内訳リスト
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
| `screenTimeService` / `aiCommentaryService` | 差し替え可能なサービス実装。既定値は各 `Mock*Service` |
| `screenTimeFor(child)` / `isScreenTimeLoading(child)` | キャッシュ済みのスクリーンタイムと読み込み中フラグ |
| `commentaryFor(child)` / `isCommentaryLoading(child)` | キャッシュ済みのAI講評と読み込み中フラグ |
| `ensureScreenTimeLoaded(child)` | 未取得なら `screenTimeService.fetchRecentScreenTime` を呼び、結果をキャッシュ |
| `refreshScreenTime(child)` | キャッシュ(スクリーンタイム・AI講評とも)を破棄して再取得 |
| `dopagakiIndexFor(child)` | キャッシュ済みの最新日(=昨日)を `DopagakiCalculator` に渡した結果。未取得時は `DopagakiIndex.empty` |
| `getOrGenerateCommentary(child)` | キャッシュがあれば返す。無ければスクリーンタイムの取得を待って `aiCommentaryService.generateCommentary` を呼び、結果をキャッシュ |
| `clear()` | 全キャッシュを破棄。サインアウト時に呼ばれる |

サインアウト時は [session_bridge.dart](../lib/services/session_bridge.dart) の `SessionBridge.clear()` が `ChildRegistry.instance.clear()` と合わせて `ScreenTimeRegistry.instance.clear()` を呼ぶ。

---

## ドパガキ指数の算出

[dopagaki_calculator.dart](../lib/services/dopagaki_calculator.dart) が `ScreenTimeDay` → `DopagakiIndex` の変換を担う。

```
percentage = round(distractingTotal(分) / total(分) × 100)
```

- `total` が0(記録なし)の場合は `DopagakiIndex.empty`(`percentage: 0, label: '記録なし'`)
- `percentage < 30` → `良好`
- `30 <= percentage < 60` → `注意`
- `percentage >= 60` → `危険`

`ScreenTimeDay.distractingTotal` は `AppUsage.isDistracting == true` のアプリ(SNS・動画・ゲームなど)の合計利用時間。

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
  - `WeeklyScreenTimeChart` … 直近7日間(`days`、先頭が昨日)の合計利用時間を棒グラフで表示
  - `AppBreakdownList` … 最新日(`days.first` = 昨日)のアプリ別内訳を横棒グラフで表示

### AiCommentaryCard(AIによる講評)

[ai_commentary_card.dart](../lib/widgets/ai_commentary_card.dart)。`child: ChildProfile` を受け取り、`ScreenTimeRegistry.instance` を `AnimatedBuilder` で購読する。

- 未取得かつ未読込中 → 「講評を見る」ボタン。押下で `getOrGenerateCommentary(child)` を呼ぶ
- 読込中 → `CircularProgressIndicator`
- 取得済み → `summary` 本文 + `adviceList` の箇条書き + 生成時刻(`generatedAt` を `HH:mm 時点の講評` 形式で表示)

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
    required DopagakiIndex dopagakiIndex,
  });
}
```

`MockAiCommentaryService` はドパガキ指数のラベル(`危険`/`注意`/`記録なし`/それ以外)で分岐するルールベースの文章生成。実際のAI API呼び出しは行っていない。800msのダミー遅延あり。

バックエンドのAI講評API(担当・使用モデルは未定)が用意でき次第、この抽象クラスを実装した別クラス(例: `BackendAiCommentaryService`)に差し替える。呼び出し側(`ScreenTimeRegistry.getOrGenerateCommentary`)はインターフェースにしか依存していないため、差し替えの影響範囲はこのファイルのみで収まる。

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

**注意**: `FuturisticBackground` は `AnimationController(...)..repeat()` で無限にアニメーションし続けるため、`pumpAndSettle()` は永久にタイムアウトする。テストでは `tester.pump()` + 固定時間の `tester.pump(Duration(...))` を使うこと。

---

## 既知の制約・今後の課題

- **Supabase未接続**。`screen_time_daily`/`screen_time_apps`/`ai_reviews`([db_schema.md](db_schema.md#screen_time_daily--screen_time_apps--スクリーンタイム))を読み書きする実装(`SupabaseScreenTimeService` 等)はまだ無く、`Mock*Service` のダミーデータのみで動作している
- **`AiCommentary` と `ai_reviews` の構造差**。アプリ側のモデルは `summary` + `adviceList: List<String>` + `generatedAt` だが、DBの `ai_reviews` は `comment`(単一text) + `dopagaki_score` + `model`。永続化する際はどちらかのモデルに寄せる必要がある(例: `adviceList` を改行結合して `comment` に格納する、または `ai_reviews` に列を追加する)
- **`AppUsage.color`/`isDistracting` に対応するDB列が無い**。`screen_time_apps` は `app_id`/`app_label` のみを持つため、実装時はアプリ別の色・「ドパガキ対象アプリか」の判定をクライアント側のカタログ(または別途マスタテーブル)でマッピングする方針を決める必要がある
- **AI講評の生成主体が未定**。[db_schema.md](db_schema.md#重要な前提) の通り `ai_reviews` への書き込みは service role キー(サーバー/Edge Functions)の責務であり、クライアントから直接書き込むことはできない。AI講評の生成をどこで実行するか(Edge Function化など)は未着手
- **子ども識別に `ChildProfile.id` が使えない**。`ScreenTimeRegistry` のキャッシュキーは `groupCode + name` の合成文字列で代用しているため、同一グループ内で同姓同名の子どもがいると衝突する。`ChildProfile` にDBの `profiles.id` を持たせる改修が望ましい
