# 周辺アクティビティ提案 仕様書 (Flutter)

このドキュメントは、子どもの現在地周辺にあるお金のかからない催しをAIが提案し、子どもが申請 → 親が承認するとやることリスト(クエスト)に追加される機能([lib/screens/activity_body.dart](../lib/screens/activity_body.dart)、[lib/services/](../lib/services/)、[lib/widgets/](../lib/widgets/)など)の仕様書です。
**コードが正**であり、このドキュメントはそれを読み解くための資料です。実装を変更したら、このドキュメントも合わせて更新してください。

DBスキーマ・RPCの詳細は [db_schema.md](db_schema.md#activity_suggestions--activity_requests--周辺アクティビティ提案) を参照。

## 目次

- [設計方針](#設計方針)
- [全体構成](#全体構成)
- [ボトムナビゲーション(子どものみ表示)](#ボトムナビゲーション子どものみ表示)
- [画面の表示ロジック(ActivityBody)](#画面の表示ロジックactivitybody)
- [位置情報の取得(LocationService)](#位置情報の取得locationservice)
- [Edge Function(activity-suggest)](#edge-functionactivity-suggest)
- [申請 → 承認 → クエスト追加のフロー](#申請--承認--クエスト追加のフロー)
- [Realtime](#realtime)
- [UIスタイル](#uiスタイル)
- [テスト](#テスト)
- [既知の制約・今後の課題](#既知の制約今後の課題)

### 用語

- **アクティビティ** … `activity_suggestions` の1行。AIが提案した、地域の無料の催しや過ごし方。
- **おでかけ申請** … `activity_requests` の1行。子どもが「行きたい」と申請すること。承認されると `tasks` にタスクが生成される。

---

## 設計方針

| # | 方針 | 理由 |
|---|---|---|
| 1 | 状態管理は既存の「ChangeNotifierシングルトン + `addListener`/`setState`」に統一する | `ChildRegistry`/`AppSession`/`AchievementRequestRegistry` 等と同じ流儀に揃え、購読方法が画面ごとにばらつかないようにするため |
| 2 | 「子が申請 → 親が承認」は達成申請・交換申請と同じ形にする | 3つ目の似た機能を作るときに、既存の2例(`AchievementRequestRegistry`/`ExchangeRequestRegistry`)を踏襲すれば実装・レビューの負荷が下がるため |
| 3 | 位置情報の取得は `LocationService` インターフェース越しに行う | `flutter test` はプラグインを持たないため、テストで差し替えられないとウィジェットテストが書けない。ただし [ScreenTimeService](screen_time_ai_commentary.md) と異なり `lib/` にモック実装は置かず、既定を最初から本実装(`GeolocatorLocationService`)にしている(Chromeの `flutter run -d chrome` は localhost が secure context 扱いなので追加設定なしで動く) |
| 4 | AIへの実在性のヒントは Overpass API(OpenStreetMap)の実データで与え、検索グラウンディングは使わない | 検索グラウンディング(Google検索)は無料枠が無く、429を約0.5秒で即返すと実測で確認した(2026-09-09)。追加課金を避けつつ実在性の確率を上げるため、現在地周辺の実在施設(図書館・公民館・公園など)を無料の Overpass API から取得し、Gemini には「参考情報」として渡す。候補地からの選択を強制せず、Geminiが確信のある実在施設名を自身の知識で挙げることも許可する(候補地外の施設名についてはハルシネーションのリスクを許容する設計)。期間限定イベントは候補地の有無によらず一貫して禁止し、恒常的な公共施設に限定する |
| 5 | 外部APIキーは Edge Function の secret としてのみ持つ | `ai-review` と同じ方針。`.env` は `pubspec.yaml` の assets に含まれアプリに同梱されるため、Flutter側に置くと漏洩する |
| 6 | 親への通知だけ Supabase Realtime を使う | 達成申請・交換申請は起動時取得のみだが、この機能だけ「親のアプリを開いたままでも申請が届く」体験にする(ユーザー要件)。この機能とそれ以外で通知の即時性が非対称になる点は[既知の制約](#既知の制約今後の課題)を参照 |

---

## 全体構成

```
lib/
  models/
    geo_point.dart              # 緯度経度の組
    activity_suggestion.dart    # AIが提案した1件のアクティビティ
    activity_request.dart       # 子の申請1件(達成申請/交換申請と同形)
  services/
    location_service.dart              # LocationService(抽象) + 例外
    geolocator_location_service.dart   # 実装。既定として使う(モックは lib/ に置かない)
    activity_service.dart              # Supabaseアクセスの薄いラッパ(全static)
    activity_request_registry.dart     # 申請一覧の状態管理シングルトン
    activity_realtime.dart             # activity_requests の Realtime 購読
  screens/
    activity_body.dart          # ボトムナビ4タブ目(子のみ)の中身
  widgets/
    activity_review_dialog.dart # 親の承認ダイアログ(ポイント入力あり)

supabase/
  functions/activity-suggest/index.ts   # Overpass候補取得 + Gemini呼び出し + activity_suggestions への保存
  migrations/0013_activity_fixes.sql    # RPCバグ修正・認可ガード・Realtime有効化
```

`ActivityBody` は [main_shell.dart](../lib/screens/main_shell.dart) の `IndexedStack` の4タブ目として、**子どもでログインしているときだけ**表示される。

---

## ボトムナビゲーション(子どものみ表示)

`AppBottomNav`(旧: `items` を4件 `const` でハードコード)を「`items` を引数で受け取るだけの部品」に変更し、[main_shell.dart](../lib/screens/main_shell.dart) がロールに応じたタブ一覧を組み立てる。

```dart
const _commonTabs = <_NavTab>[ホーム, クエスト, プレゼント]; // 親・子共通
const _childTabs = <_NavTab>[..._commonTabs, おでかけ];      // 子のみ
```

`_NavTab` はアイコン・ラベル・body(タブの中身のWidget)を1つにまとめたレコードで、これを唯一の真実として `IndexedStack.children` と `AppBottomNav.items` の両方を組み立てる。以前は「`IndexedStack` の子リスト」と「`AppBottomNav` のアイコン一覧」が別々に4件ずつ `const` 定義されており、位置でしか対応が取れていなかった(片方だけロールで出し分けると選択タブと表示ボディがズレる)。この設計により、そのバグのクラス自体が起きなくなる。

`MainShell` は `AppSession` を購読してロール変化時に再ビルドし、保存している `_index` は表示直前に `tabs.length` でクランプする(クランプ済みの値は保存しないので、子に戻ったとき選択位置が復元される)。

タブ名は「おでかけ」(既存3タブと同じ3〜5文字)。「アクティビティ」は7文字で4タブ幅だと読みにくいため採用しなかった。

---

## 画面の表示ロジック(ActivityBody)

**`initState` では自動検索しない。** `IndexedStack` は全タブを起動時に build するため、ここで位置情報や Edge Function を呼ぶと「ログインしただけで権限ダイアログ + Gemini課金」が走ってしまう。検索は必ず「現在地から探す」ボタンのタップを起点にする。

```dart
Future<void> _search({bool force = false}) async {
  final point = await ActivityService.locationService.currentPosition();
  final list = await ActivityService.fetchSuggestions(
    childId: profile.id!, latitude: point.latitude, longitude: point.longitude, force: force,
  );
  setState(() => _suggestions = list);
}
```

画面の状態は次の4つを排他的に出し分ける:

1. `_busy`(検索中) … `CircularProgressIndicator`
2. `_notice`(位置情報エラー・Edge Function側のエラー) … `LocationUnavailableException.message` / `ActivitySuggestException.message`(どちらも日本語) + 「再試行」ボタン
3. 検索済みで結果が空 … 「近くのアクティビティが見つかりませんでした」
4. 一覧 … `_ActivityCard` を `for` スプレッドで並べる(`ListView` は使わない既存流儀)

`ActivitySuggestFailure` の reason と表示文言:

| failure | 状況 | メッセージ |
|---|---|---|
| `quotaExceeded` | Gemini APIの無料枠クォータ超過(429 `gemini_quota_exceeded`) | 「AIの提案が今日の上限に達しました。明日またお試しください」 |
| `notConfigured` | `GEMINI_API_KEY` 未設定(200 `gemini_not_configured`) | 「現在AIの提案は利用できません。おうちの方にお知らせください」 |
| `failed` | 上記以外(想定外のステータス・レスポンス形状) | 「提案を取得できませんでした。しばらくしてから、もう一度お試しください」 |

判定は必ず body の `error` 値で行い、HTTPステータスだけでは判定しない(`gemini_not_configured` は200応答でも返るため、ステータスだけでは区別できない)。

各カードは `quest_body.dart` の `_QuestItemBar` と同じ「タップで展開」形式。折りたたみ時はタイトルと場所名のみ、展開時に詳細(`description`)・出典URL(現在は使わない。下記「Edge Function」節を参照)・「申請する」ボタンを表示する。`ActivityRequestRegistry.hasPendingRequestFor(suggestion.id)` が真なら「申請中」にしてボタンを無効化する。

「AIの提案です。おでかけ前におうちの人と確認してください」という注意書きを画面上部に常設している(AIが実在性を断定しない設計と対になっている)。

---

## 位置情報の取得(LocationService)

```dart
abstract class LocationService {
  Future<GeoPoint> currentPosition();
}
```

実装は `GeolocatorLocationService` のみ。`ActivityService.locationService` の既定値がこれなので、`main.dart` での差し替えは不要(`ScreenTimeService`/`AiCommentaryService` と異なる点)。テストだけが `implements LocationService` の Fake を代入する(`flutter test` はプラグインチャネルを持たないため)。

**web とモバイルで分岐する。** web は `checkPermission()` が「ブラウザが Permissions API に対応していない」だけで `LocationPermission.denied` を返す仕様があり、事前チェックで弾くと実際には取得できるのに失敗扱いになる。`kIsWeb` のときは事前チェックを飛ばし、ブラウザ自身の許可ダイアログに任せて直接 `getCurrentPosition()` を呼ぶ。

失敗理由は `LocationUnavailableReason` で分類し、`LocationUnavailableException.message` がそのまま画面に出せる日本語文を返す:

| reason | 状況 | メッセージ |
|---|---|---|
| `serviceDisabled` | 端末の位置情報自体がオフ | 「端末の位置情報がオフになっています。設定から有効にしてください」 |
| `denied` | 権限を拒否された(web はほぼ常にこちら) | 「位置情報の利用が許可されませんでした。…」 |
| `deniedForever` | 「今後表示しない」で拒否(Android) | 「位置情報が『許可しない』に設定されています。…」 |
| `timeout` | 30秒以内に取得できなかった | 「現在地を取得できませんでした。もう一度お試しください」 |
| `positionUnavailable` | 権限は許可されたが実際の測位に失敗(ブラウザの `POSITION_UNAVAILABLE` 等) | 「現在地を特定できませんでした。時間をおいて、もう一度お試しください」 |
| `unsupported` | 未対応プラットフォーム等 | 「この端末では現在地を取得できません」 |

精度は `LocationAccuracy.medium`(数百m〜数kmの誤差で十分)。web は `enableHighAccuracy=false` 相当でWi-Fi/IP測位になる(Chrome デスクトップは市区町村〜ISPの所在地レベルまでずれることがある)。

**Android は `ACCESS_FINE_LOCATION` と `ACCESS_COARSE_LOCATION` の両方を宣言する。** 精度としては COARSE で足りるが、COARSE だけだと Google Play開発者サービスが無い端末(Playストア無しのエミュレータなど)で必ず失敗する。geolocator はその場合 `FusedLocationProviderClient` ではなく `LocationManager` にフォールバックし、Android 12+ では `FUSED_PROVIDER`、それ未満では `GPS_PROVIDER` を選ぶが、この2つは Android プラットフォーム側で `ACCESS_FINE_LOCATION` が必須であり、COARSE だけでは `requestLocationUpdates` が `SecurityException` を投げる。geolocator はこれを捕捉しないため、例外はそのまま `unsupported`(「この端末では現在地を取得できません」)になる。FINE を宣言しても Android 12+ の権限ダイアログはユーザーが「おおよその位置情報」を選べるため、実際の精度はユーザーが決められる。

**Android には素の `LocationSettings` ではなく `AndroidSettings` を渡す。** `Geolocator.getCurrentPosition` は `locationSettings` が渡されるとそれをそのままプラットフォームへ送るため、素の `LocationSettings` だと Android 固有の設定(`forceLocationManager`・`timeInterval` など)が一切適用されず、ネイティブ側の既定値で動いてしまう。

**タイムアウト時は `getLastKnownPosition()` にフォールバックする。** `getCurrentPosition` は「新しい位置の更新」を待つ実装で、屋内やエミュレータのように測位できない環境では毎回タイムアウトしてしまう。端末がキャッシュしている直前の測位結果が1時間以内のものであればそれを使い、無い/古すぎる場合だけ `timeout` として扱う。フォールバック自体が失敗しても元の `TimeoutException` は握り潰さない。`kDebugMode` では「キャッシュが無い」「古すぎる」「取得自体が失敗」をログで区別できるようにしてある(この3つは原因も対処もまったく違うため)。

**待ち時間は30秒、Android の `intervalDuration` は1秒。** 電源投入直後や屋内では15秒では測位が間に合わないことが実機で確認できたため延長した。`intervalDuration` を指定しないとネイティブ側の既定5秒が使われ、測位できていても最初のコールバックが最大5秒遅れる(1回取れれば終わりなので短くてよい)。

`LocationUnavailableException` は `message`(画面表示用の日本語)とは別に `detail`(開発者向けの原因情報)を持つ。`GeolocatorLocationService` の各 catch 節は、元例外が持つ生のメッセージ(例えば web で `POSITION_UNAVAILABLE` になったときの Chrome 側のエラー文言)を握りつぶさず `detail` に載せ、`kDebugMode` 時にコンソールへログ出力する。原因不明の失敗を「この端末では現在地を取得できません」のような一般的な文言に丸めてしまうと、後から原因を特定できなくなるため。

**web 実装の既知の制約(geolocator_web 4.1.4)**: `LocationSettings.timeLimit` はプラットフォーム実装が解釈する値で、`geolocator` 本体は強制しない。geolocator_web はこれをブラウザの `PositionOptions.timeout`(ミリ秒)に渡す際に `Duration.inMicroseconds` を使っており、単位を取り違えている(`Duration(seconds: 15)` が `15,000,000ms` ≒ 4.17時間として解釈される)。そのため web ではブラウザ側のタイムアウトが実質無効になり、ブラウザが応答を返さない場合に永久にハングし得る。これを迂回するため、`GeolocatorLocationService._getPosition()` は `Geolocator.getCurrentPosition(...)` の呼び出しに `.timeout(_positionTimeout)` を重ねて掛け、Dart側でもタイムアウトを強制している。

---

## Edge Function(activity-suggest)

`supabase/functions/activity-suggest/index.ts` は `ai-review`(スクリーンタイムのAI講評)と同じ骨格を踏襲する。

**リクエスト**: `{ child_id, latitude, longitude, force? }`
**レスポンス**: `{ suggestions: [...], model, cached }` または `{ error, detail? }`

### 処理の流れ

1. 呼び出し元JWTの anon クライアントで `profiles` から `id, group_id` を取得(取れなければ403)。同一グループのメンバーかの検証であり、`ai-review` と同じ仕組み。`display_name` は取らない(子どもの名前を外部APIに送らないため)
2. `force` でなければ、直近6時間・半径約2km以内にキャッシュがあればそれを返す(`activity_suggestions.origin_latitude`/`origin_longitude` をキーに使う)
3. `fetchNearbyPlaces()` が Overpass API(OpenStreetMap)に、現在地半径2km以内の図書館・公民館・児童館・公園・遊び場・運動広場を問い合わせる(下記コラム参照)。失敗・タイムアウト・0件はいずれも空配列を返し、処理は続行する(候補が無い地域向けのフォールバックがあるため)
4. Gemini Interactions API を呼ぶ。`response_format` で構造化JSON出力を強制する。候補地が取れていれば、その名称・カテゴリ・距離のリストを「参考情報」としてプロンプトに渡す。候補地から選んでもよいし、Geminiが確信のある実在施設名を候補地外から挙げても構わない。Gemini 側が無料枠クォータ超過(429)を返した場合は `GeminiQuotaExceededError` に変換し、`{ error: "gemini_quota_exceeded" }` で429を返す。それ以外のGemini呼び出し失敗は `{ error: "gemini_call_failed", detail }` で502
5. Geminiの応答をパースしたあと、`place_name` を候補地リストの名称と完全一致で突き合わせる。一致すればその候補地の実在座標を付与するが、一致しなくても要素は破棄しない(座標は `null` のまま採用する)
6. サーバ側で `is_free !== true` の要素とタイトル空の要素を機械的に除外し、最大5件に切り詰め、`description` に「確認」の文字が無ければ締め文(下記プロンプト方針を参照)を機械的に追記する
7. service role で `activity_suggestions` に保存し、`insert().select()` で採番済みの行をそのまま返す

**このEdge Functionが返す429はGemini側のクォータ超過(`gemini_quota_exceeded`)のみ**(旧: アプリ独自のレートリミットもあったが撤廃した。下記「既知の制約」参照)。`gemini_not_configured`(`GEMINI_API_KEY` 未設定)は例外的にステータス200のまま返る(`ai-review` 側の同種フォールバック判定と挙動を合わせるため)。

> **検索グラウンディングを使わず Overpass API(OpenStreetMap)を使う理由**: 2026-09-09の実測で、`tools: [{ type: "google_search" }]` を付けると同一キー・同一モデルで**429を約0.5秒で即返す**と確認した(`response_format` のみなら200)。検索グラウンディングには無料枠が無いと判断した。ただし Gemini の知識だけに頼ると実在性の確率が下がるため、APIキー・利用登録が不要で完全無料の Overpass API から実在の施設を取得し、Gemini には「参考情報」として渡している。ただし候補地からの選択は強制しておらず、Geminiが確信を持てる実在施設名であれば候補地外から挙げることも許可している(その分、候補地外の施設名についてはハルシネーションのリスクを完全には排除できない設計に変更した)。

### プロンプト方針

「お金のかからない地域の過ごし方」を最優先とし、図書館・公民館・児童館・公園・自治体主催イベントなど公共性の高い場所を中心に提案するよう指示する。安全性の観点で夜間のみの催し・出会い目的の集まり・年齢制限のある場所などを明示的に除外する。

**候補地(Overpass)がある場合**: プロンプトに「1. ○○図書館(図書館、現在地から約350m)」のような番号付きリストを「参考情報」として渡す。選んでもよいし、他に知っている実在の施設があれば具体的に挙げてもよいと明示する。

**候補地が取れなかった場合**: Overpass にデータが少ない地域(郊外・地方など)では候補地が0件になりうる。この場合も具体的な施設名を挙げること自体は禁止しない。

両方のケースに共通する指示:

- `place_name` は、施設名に確信がある場合は具体的な名前を挙げてよい。確信が持てない場合は無理に固有名詞を作らず、「お近くの市立図書館」のように種類がわかる一般的な書き方にさせる(候補地の有無で分岐させず、確信の度合いだけを判断基準にする)
- **期間限定のイベント・お祭り・ワークショップは提案させない。** 一年を通していつでも行ける公共施設だけに限定する
- 具体的な開催日時・料金・電話番号・URL・アクセス方法は書かせない
- `title` は場所名ではなく「そこで何ができるか」を具体化した見出しにさせる(例:「図書館で世界の絵本さがし」)。場所を一般化する代わりに過ごし方を具体的にすることで、機能の価値(SNSの代わりになる提案)を保つ
- `description` の末尾に必ず「場所や開いている時間は、おでかけの前におうちの人と確認してください。」を添えさせる。プロンプト遵守だけに頼らず、手順7のサーバ側フィルタでも機械的に保証する
- 実在しない場所を作らないことを最優先とし、5件に届かなくてもよいと明示する(`callGemini` は0件の応答をエラーにしない。プロンプトで許容している以上、0件は正当な結果であり502にしてはならない)

### `source_url` / `latitude` / `longitude` の扱い

`latitude`/`longitude` は、Overpass候補と名称が一致した提案には**実在の座標**が入る(手順6の突き合わせ結果)。候補地が無い/一致しなかった場合は引き続き `null`(モデルの自己申告は捏造されうるため、突き合わせできない座標を保存することはしない)。座標が無くても提案自体は破棄されない。`source_url` は検索グラウンディングを使わないため出典URLが取得できず、常に `null` のまま。カラム自体と `ActivitySuggestion.sourceUrl`・`activity_body.dart` の表示分岐は、将来グラウンディングを復活させたときのために残置している。

---

## 申請 → 承認 → クエスト追加のフロー

既存の達成申請(`AchievementRequestRegistry`)・交換申請(`ExchangeRequestRegistry`)と同じ形。

```
子: ActivityRequestRegistry.addRequest(profile, suggestion)
    → ActivityService.requestActivity(...) が activity_requests に pending 行を insert
親: 通知ベルに「〇〇からおでかけ申請をされました。」
    → ActivityReviewDialog でポイントを設定して「承認してクエストに追加」
    → ActivityRequestRegistry.approve(request, points)
       → ActivityService.approveRequest(...) が approve_activity_request RPC を呼ぶ
       → RPC が tasks に行を作り、生成した task id を返す
       → 返ってきた id で QuestItem を組み立てて childProfile.questItems に楽観追加
          (再取得はしない。title/points/detail はすべて呼び出し側が持っているため)
```

**既存の達成申請・交換申請ダイアログにはポイント入力欄が無い**ため、`ActivityReviewDialog` を新規に作った。`new_task_dialog.dart` のポイント入力(`NumericInputFormatter` + 1以上の検証)と、`exchange_review_dialog.dart` の承認/却下ボタンの骨格を合成している。

`QuestBody` は `ActivityRequestRegistry` を購読しているため、親が承認した瞬間に(同一端末内であれば)クエスト一覧へ即座に反映される。`ChildRegistry` は `questItems` の直接変更を検知しないので、`ActivityRequestRegistry` 自身の `notifyListeners()` に頼っている(`AchievementRequestRegistry.stamp` と同じ仕組み)。

---

## Realtime

`activity_requests` は、このプロジェクトで唯一 Supabase Realtime を使うテーブル。`0013_activity_fixes.sql` で `supabase_realtime` publication に追加した。

- **親**: `ActivityRealtime.subscribeAsParent()` が INSERT を購読し、`ActivityRequestRegistry.addFromRealtime(...)` で通知ベルに即時反映する。`activity_requests` に `group_id` 列が無いためフィルタは付けられないが、`activity_requests_select` の RLS が同一グループの行だけを配信するので実害はない
- **子**: `ActivityRealtime.subscribeAsChild(childId)` が `child_id=eq.<childId>` でUPDATEを購読し、`status == 'approved'` になったら `QuestService.fetchTasks(childId)` で再取得して `AppSession.refreshChildQuests(...)` を呼ぶ。承認操作は親の端末で走るため、子側は再取得しないと反映されない
- 購読の開始/終了は `SessionBridge.hydrate()`/`clear()` から行う(ロールを知っているのがここだけのため)
- 接続失敗・切断はアプリを止めない。失敗しても起動時取得(`auth_gate.dart` の `_loadAndHydrate`)がフォールバックとして機能する

---

## UIスタイル

`quest_body.dart` と同じ配色・構造。`FuturisticBackground` を背景に、`GlassCard` で説明文とボタンを囲み、リストは `for` スプレッドで並べる。色はファイル先頭にローカル定数として `_cyan = Color(0xFF33F7FF)` / `_magenta = Color(0xFFFF3DAE)` を置く(申請ボタンは magenta、他の主要アクションは cyan)。

---

## テスト

`test/screens/activity_body_test.dart` — `test/screens/home_body_test.dart` と同じ組み立てで、`setUp` で `LocationService` の Fake を `ActivityService.locationService` に直接代入する(`lib/` にモック実装を置かない設計のため)。

検証内容:
- 子でログイン時、説明カードと「現在地から探す」ボタンが表示される。`initState` で自動検索しないため `CircularProgressIndicator` は出ない
- 子は4タブ(「おでかけ」を含む)、親は3タブ(「おでかけ」が無い)

`FuturisticBackground` は無限にアニメーションし続けるため `pumpAndSettle()` はタイムアウトする。`tester.pump()` + 固定時間の `pump()` を使う。

`ActivityService`/`ActivityRequestRegistry` は Supabase を直接叩くため、`fetchSuggestions`/`requestActivity` を実際に呼ぶ操作までは踏み込まない(`home_body_test.dart` と同じ割り切り)。

`test/services/activity_service_test.dart` — `ActivitySuggestException.fromFunctionException`/`fromErrorCode`(`FunctionException.details` から `ActivitySuggestFailure` への変換ロジック)のみを対象にした純粋関数テスト。Supabase の初期化は不要。`gemini_quota_exceeded`/`gemini_not_configured`/`error`キー無し/未知の`error`値/`details`がMapでない/`details`がnull、の各ケースを検証する。

---

## 既知の制約・今後の課題

- ~~**通知の即時性がこの機能だけ非対称**~~ / ~~**子は承認に気づかない**~~ — 2026-09 に `notifications` テーブル(`0017_notifications.sql`)を新設して解消した。申請はトリガー、承認/却下は各 RPC がサーバ側で通知行を作り、親も子も `NotificationRealtime` で自分宛の行を購読する。詳細は `docs/notifications.md`
- **`activity-suggest` はリクエストボディの緯度経度をそのまま信頼する**。`ai-review` が `screen_time` を信頼しているのと同じ構造。子が任意の座標を送れるが、被害は「無関係な地域の提案が出る」程度
- **Overpass(OpenStreetMap)のデータ網羅性に依存する**。都市部は候補が豊富だが、地方・郊外では候補地が0件になりやすく、その場合は従来通りモデルの知識に依存したフォールバック(一般的な場所名、または確信があれば具体的な施設名)になる
- **候補地リストに無い施設名をGeminiが挙げた場合、実在性を機械的には保証できない**。候補地からの選択を強制しない設計にしたため(具体的な施設名を挙げられるようにする方が提案の価値が高いと判断)、ハルシネーション(実在しない施設の捏造)のリスクを許容している。安全網は「おでかけ前におうちの人と確認してください」という画面上部の注意書きと `description` 末尾の一文のみ
- **Overpass API は外部の無料公開サービスであり、SLAが無い**。利用が集中する時間帯は応答が遅い/失敗することがある。呼び出しは8秒でタイムアウトさせ、失敗時は空配列にフォールバックするため機能全体は止まらないが、実在の場所を提示できる確率は下がる
- **`activity_suggestions.origin_latitude`/`origin_longitude` の保持期間が未整理**。緯度経度は個人情報であり、`screen_time_daily` のような保持期間管理の仕組み(`purge_old_screen_time` 相当)を将来検討する余地がある
- **Chrome デスクトップの測位精度は粗い**。GPSが無いためWi-Fi/IP測位になり、数km〜ISPの所在地レベルまでずれることがある
- **アプリ独自のレートリミット(旧: 直近24時間に保存された行数が20件を超えたら429)は撤廃した**。1回の検索で最大5行保存されるため実質4回/日でブロックされてしまうバグがあり(2026-09-10発覚)、原因の複雑さに見合う価値が無いと判断して仕組みごと削除した。連打・コストの歯止めは、検索中はボタンを無効化する `ActivityBody._busy`、6時間/半径2kmのキャッシュ、Gemini無料枠自体のクォータ(`gemini_quota_exceeded`)の3点に委ねている
