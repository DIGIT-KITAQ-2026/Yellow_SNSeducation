# お知らせ(通知)

申請・承認・スクリーンタイム更新を、相手側の端末に知らせる仕組み。

## 解決した問題

2026-09 以前は、次の3つがどれも成立していなかった。

- **子どもへの通知が一切届かなかった**。`ChildNotificationRegistry` はメモリのみのシングルトンで、承認・却下の通知文は `AchievementRequestRegistry.stamp` などの中、つまり**親の端末上**で作られていた。子どもの端末にはその存在すら伝わらない。
- **親への申請通知がリアルタイムでなかった**。親のお知らせはログイン時に取得した未処理申請の一覧で、Realtime 購読があるのは `activity_requests` だけだった。クエスト達成申請・プレゼント交換申請は再ログインするまで気づけない。
- **スクリーンタイムには通知経路が無かった**。

通知行の生成をすべてサーバ側に移し、各端末は自分宛の行を Realtime で受け取る形に変えた。

## 全体の流れ

```
子: 達成/交換/おでかけを申請
      → task_requests / reward_redemptions / activity_requests に INSERT
      → AFTER INSERT トリガー → notify_group_parents() → notifications(親の人数ぶん)
      → 親の端末の NotificationRealtime が受信 → お知らせベル + OS通知

親: 承認 / 却下
      → approve_*_request / reject_*_request RPC
      → RPC の中で notify_child() → notifications(子ども1行)
      → 子の端末の NotificationRealtime が受信 → お知らせベル + OS通知 + 手元の状態を更新

子: ホームを開く / 引っ張って更新
      → screen_time_daily に upsert
      → AFTER INSERT OR UPDATE トリガー → notify_group_parents() → notifications
      → 親の端末の NotificationRealtime が受信
```

## なぜ申請はトリガーで、承認/却下は RPC の中なのか

**申請がトリガーなのは、入口が揃っていないから。** クエスト達成申請はクライアントからの直 INSERT(`QuestService.requestAchievement`)、交換申請は `request_reward` RPC 経由と経路が違う。トリガーにすれば、どちらから来ても1箇所で拾える。

**承認/却下がトリガーにできないのは、行が消えるから。** `approve_task_request` は `tasks` を物理削除する(0010)ので UPDATE トリガーが発火せず、却下は申請行そのものを消す(0019)。そのため 0017 で各 RPC を `create or replace` し、本体の末尾に `notify_child` を1行足している。

## 申請行の寿命(0019)

「何を了承したのか」を通知から後から辿れるようにするため、申請行(`task_requests` / `reward_redemptions` / `activity_requests`)は承認後も残す。

- **承認** … 申請行は `status='approved'` のまま残る。`tasks` / `rewards` を消すタイミングは従来どおり承認時。`task_requests.task_id` は cascade ではなく `on delete set null` にしてあるので(0019)、`tasks` が消えても申請行は生き延びる
- **却下** … 申請行を即削除する。子どもはやり直して再申請できる状態に戻るだけで、残しておく意味が無い
- **掃除** … `notifications` の DELETE に張った `trg_cleanup_request_on_notification_delete` が、同じ `request_id` を指す通知が親子とも消えた時点で申請行を消す

親宛の申請通知(`quest_request` など)の payload には決着が入っていないので、詳細画面は `RequestDecisionService` で申請行を引いて判定する。**行が無い → 却下 / `approved` → 承認済み / `pending` → 未処理**。

## `kind` と payload

表示文面は DB に持たない。`kind` と `payload` だけを保存し、日本語の組み立ては `lib/services/notification_messages.dart` の純粋関数 `notificationContent` が行う。文面を直すのにマイグレーションを足さずに済む。

| `kind` | 宛先 | payload の主なキー |
|---|---|---|
| `quest_request` / `reward_request` / `activity_request` | 親 | `request_id`, `child_name`, `item_title` |
| `screen_time_updated` | 親 | `child_name`, `date`, `total_minutes` |
| `quest_approved` / `reward_approved` | 子 | `request_id`, `item_title`, `points`, `point_balance` |
| `quest_rejected` / `reward_rejected` | 子 | `request_id`, `item_title` |
| `activity_approved` / `activity_rejected` | 子 | `request_id`, `item_title`, `points` |

`request_id` は、親が申請の通知をタップしたときに承認/却下ダイアログを開く相手を探す鍵。知らない `kind` が来ても `notificationContent` は無難な文面を返すので、サーバ側に `kind` が増えてもアプリは落ちない。

## スクリーンタイム通知の連打対策

`SupabaseScreenTimeService.syncDays` はアプリを開くたびに直近7日ぶんを upsert するので、素朴にトリガーを張ると毎回7通鳴る。2段構えで抑えている。

1. `new.date < current_date - 1` なら鳴らさない(日付は端末ローカル基準・DB は UTC なので1日の余裕を持たせている)
2. `dedupe_key = 'screen_time:<child_id>:<date>'` + `on conflict do nothing`

さらに UPDATE で `total_minutes` が変わっていない場合もスキップする。結果として**子ども1人・1日あたり最大1〜2通**に収まる。

## クライアント側の構成

| ファイル | 役割 |
|---|---|
| `lib/models/app_notification.dart` | `notifications` の1行 |
| `lib/services/notification_messages.dart` | `kind` + payload → 表示文面 / スタンプ画像(純粋関数) |
| `lib/services/notification_service.dart` | Supabase の薄いラッパー(取得・既読・削除・一括削除)。行を作るのはサーバなので insert は無い |
| `lib/services/notification_registry.dart` | 一覧を保持するシングルトン。`replaceAll` / `addFromRealtime` / `markRead` / `remove` / `removeAll` / `unreadCount` |
| `lib/services/notification_realtime.dart` | 自分宛の INSERT を購読し、ベル更新・OS通知・子ども側の状態反映を行う |
| `lib/services/request_decision_service.dart` | 親宛の申請通知から、その申請の決着(承認/却下/未処理)を引く |
| `lib/widgets/notification_bell.dart` | ベルと一覧ダイアログ。親・子で同じ一覧を出す |
| `lib/widgets/notification_detail_dialog.dart` | 処理済みの通知をタップしたときの詳細。消去ボタンもここ |

一覧の行をタップしたときの分岐は `NotificationBell.handleTap`。**未処理の申請が手元にあれば承認/却下ダイアログ、それ以外は詳細ダイアログ**を開く。消去は一覧の行の × と詳細の「このお知らせを消去」の2箇所からで、どちらも `showConfirmDeleteDialog` で確認してから `NotificationRegistry.remove` を呼ぶ。一覧の左上の「すべて消去」は `removeAll` → `NotificationService.deleteAll`(`recipient_id` で絞った1回の delete)。**一覧は直近50件しか取っていないので、手元に無い古い通知もここで消える**。`remove` は表示を待たせないよう先に手元から外し、サーバ側の削除が失敗したら元の位置に戻して例外を投げ直す(`markRead` と違い、消えたはずの通知が黙って復活するほうが分かりにくいため)。

起動時取得は `auth_gate.dart` → `SessionBridge.hydrate`、購読の開始と解除も `SessionBridge` が持つ。Realtime が繋がらなくても起動時取得がフォールバックになる。

### 承認/却下を受け取った子ども側の後始末

判断は親の端末で走るので、通知が届いた時点が子どもにとって結果を知る最初のタイミングになる。`NotificationRealtime._applySideEffects` がここで手元の状態を直す。

- `quest_approved` … 申請を取り下げ、承認済みの `QuestItem` を消し、`point_balance` で残高を更新する
- `quest_rejected` … 手元の申請だけ取り下げる。`tasks` 行は `open` のまま残るのでクエスト自体は消さず、もう一度「達成」を押せるようにする
- `reward_approved` … 申請を取り下げ、`always_visible` でなければプレゼントを消し、残高を更新する
- `reward_rejected` … 申請だけ取り下げる
- `activity_approved` … ここでは何もしない。増えたクエストは `ActivityRealtime` が `tasks` を取り直して反映する

**ここで申請を取り下げないと、却下されてもボタンが「申請中」のまま固まって再申請できない。**

## OS通知

`DailyNotificationService.showMessage` を使う。FCM は入れていないので、**届くのはアプリが起動している間・Android だけ**(見送った経緯は [daily_notification.md](daily_notification.md) を参照)。出せなくてもアプリ内のお知らせベルには載るため、失敗は握りつぶしている。

毎朝8時の定期通知(ID 1)とテスト送信(ID 2)とは別のID帯(10〜19)を使い回す。連続して届いても直前の通知を上書きしないようにするため。

## テスト

- `test/services/notification_messages_test.dart` — `kind` + payload → 文面の純粋関数テスト
- `test/services/notification_registry_test.dart` — 並べ替え・重複排除・既読・`unreadCount`・`remove` / `removeAll` の差し戻し

`NotificationService` / `NotificationRealtime` は Supabase を直接叩くので、実際に呼ぶ操作までは踏み込まない(`home_body_test.dart` と同じ割り切り)。

## 既知の制約

- **アプリを終了している間の通知は取りこぼす**。次回ログイン時の一覧取得で読めるが、OS通知は出ない。解消するには FCM の導入が必要
- **既読は端末をまたいで共有される**。`read_at` は行そのものに持たせているため、同じアカウントを2台で使うと片方で読めばもう片方でも既読になる
- **通知の保持期間を決めていない**。1件ずつ・まとめて消せるようになったが、放っておけば `notifications` は増え続ける。取得は直近50件に絞っているので表示は重くならないが、`purge_old_screen_time` 相当の掃除は将来必要になる
- **承認済みの申請行も、通知が消されるまで残り続ける**。片方(親か子)が通知を消さない限り申請行は消えない。上の保持期間の話と同じ性質の宿題
- **親が複数いる場合、誰かが承認しても他の親の申請通知は未読のまま残る**。既読にできるのは承認操作をした端末だけ(`markReadByRequestId`)
