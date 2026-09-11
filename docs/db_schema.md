# DB仕様書 (Supabase / PostgreSQL)

このドキュメントは [supabase/migrations/](../supabase/migrations/) に定義されたスキーマの仕様書です。
**マイグレーションのSQLが正**であり、このドキュメントはそれを読み解くための資料です。スキーマを変更したら、このドキュメントも合わせて更新してください。

- 対象プロジェクト: `Dokagaki-edu-sns` (ap-northeast-1)
- 適用済みマイグレーション: `0001` 〜 `0013`

## 目次

- [設計方針](#設計方針)
- [ER図](#er図)
- [列挙型](#列挙型)
- [テーブル定義](#テーブル定義)
- [RPC(状態変更はすべてここを通す)](#rpc状態変更はすべてここを通す)
- [RLS(アクセス制御)](#rlsアクセス制御)
- [主要なユースケースの流れ](#主要なユースケースの流れ)
- [運用](#運用)

---

## 設計方針

| # | 方針 | 理由 |
|---|---|---|
| 1 | 基盤は Supabase (PostgreSQL) + Supabase Auth、アクセス制御は RLS | 認証・DB・ストレージを1つで賄え、クライアント(Flutter)から直接安全に叩ける |
| 2 | ポイント残高・やることリスト・プレゼントは**子どもごと** | 兄弟がいても、誰が何をやって何ポイント持っているか・何と交換できるかが混ざらない |
| 3 | タスクは**1回きり**。繰り返し定義は持たない | 仕様として繰り返しは不要。必要なら親が都度作成する |
| 4 | スクリーンタイムの生データは**直近分のみ**保持 | 子どもの詳細な行動ログを長期に持たない。保持日数は関数1つで変更可能 |
| 5 | ドパガキ指数・AI講評は**保持期間の対象外** | 生データを消しても、指数の推移だけは残して振り返れるようにするため |
| 6 | 残高やステータスの変更は**すべてRPC経由**、クライアントからの直接UPDATEは禁止 | 「ポイント加算」と「台帳への記録」が必ずセットで起きることを保証する |

### 用語

- **ドパガキ指数** … スクリーンタイムをもとにAIが算出する、**SNS依存の深刻さを100点満点で評価した指標**。**高いほど深刻**。`ai_reviews.dopagaki_score` に格納。
- **グループ** … 1組の親子。親アカウント作成時に生成される4桁の**グループコード**で子が参加する。

---

## ER図

```mermaid
erDiagram
    groups ||--o{ profiles : "has members"
    profiles ||--o{ tasks : "assigned to"
    tasks ||--o{ task_requests : "requested via"
    profiles ||--o{ rewards : "owned by"
    rewards ||--o{ reward_redemptions : "requested/redeemed as"
    profiles ||--o{ reward_redemptions : "requested by"
    profiles ||--o{ point_entries : "ledger for"
    profiles ||--o{ screen_time_daily : "tracked for"
    screen_time_daily ||--o{ screen_time_apps : "breaks down into"
    screen_time_daily ||--o{ screen_time_hourly : "breaks down into"
    profiles ||--o{ ai_reviews : "reviewed for"
    profiles ||--o{ activity_suggestions : "suggested to"
    activity_suggestions ||--o{ activity_requests : "requested via"
    profiles ||--o{ activity_requests : "requested by"
    tasks ||--o| activity_requests : "created from"

    groups {
        uuid id PK
        text name
        char_4 group_code UK
        uuid created_by FK
    }
    profiles {
        uuid id PK "= auth.users.id"
        uuid group_id FK
        user_role role
        text display_name
        int point_balance "cache of point_entries sum"
    }
    tasks {
        uuid id PK
        uuid group_id FK
        uuid child_id FK "assigned child"
        text title
        int points
        task_status status
    }
    task_requests {
        uuid id PK
        uuid task_id FK
        uuid child_id FK
        request_status status
    }
    rewards {
        uuid id PK
        uuid group_id FK
        uuid child_id FK "owning child"
        text name
        int cost_points
        boolean always_visible
    }
    reward_redemptions {
        uuid id PK
        uuid reward_id FK
        uuid child_id FK
        text reward_name "snapshot"
        int cost_points "snapshot"
        request_status status "pending/approved/rejected"
    }
    point_entries {
        uuid id PK
        uuid child_id FK
        int amount "positive=earn, negative=spend"
        point_entry_type entry_type
    }
    screen_time_daily {
        uuid child_id PK_FK
        date date PK
        int total_minutes
    }
    screen_time_apps {
        uuid child_id PK_FK
        date date PK
        text app_id PK
        int minutes
    }
    screen_time_hourly {
        uuid child_id PK_FK
        date date PK
        smallint hour PK "0-23"
        smallint minutes "0-60"
    }
    ai_reviews {
        uuid id PK
        uuid child_id FK
        date date
        int dopagaki_score "0-100, higher = more severe"
        text comment
    }
    activity_suggestions {
        uuid id PK
        uuid group_id FK
        uuid child_id FK
        text title
    }
    activity_requests {
        uuid id PK
        uuid suggestion_id FK
        uuid child_id FK
        request_status status
        int points
        uuid created_task_id FK
    }
```

---

## 列挙型

[0001_types_and_groups.sql](../supabase/migrations/0001_types_and_groups.sql) で定義。

| 型 | 値 | 用途 |
|---|---|---|
| `user_role` | `parent` / `child` | アカウント種別 |
| `request_status` | `pending` / `approved` / `rejected` | 達成申請・アクティビティ申請の状態 |
| `task_status` | `open` / `completed` | タスクの状態(1回きりなので承認で `completed` になり終わり) |
| `point_entry_type` | `task_reward` / `reward_redemption` / `adjustment` | ポイント増減の理由 |

---

## テーブル定義

### `groups` — 親子グループ

親アカウント作成時に1つ生成される。子は4桁の `group_code` で参加する。

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | uuid | PK, default `gen_random_uuid()` | |
| `name` | text | not null | グループ名(親が作成時に入力) |
| `group_code` | char(4) | not null, **unique** | 参加用の4桁コード |
| `created_by` | uuid | not null → `auth.users(id)` | ホストの親 |
| `created_at` | timestamptz | not null, default `now()` | |

> **グループコードについて**: `0000`〜`9999` の1万通りしかないため、`generate_group_code()` は重複時に最大10回リトライし、それでも空きが見つからなければ例外を投げます。グループ数が増えると衝突しやすくなるので、規模が大きくなる場合は桁数を増やす検討が必要です。

### `profiles` — アカウント(親/子共通)

Supabase Auth の `auth.users` と1対1。`id` は `auth.users.id` と同一値。

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | uuid | PK → `auth.users(id)` on delete cascade | Auth のユーザーIDと同一 |
| `group_id` | uuid | not null → `groups(id)` | 所属グループ |
| `role` | `user_role` | not null | `parent` / `child` |
| `display_name` | text | not null | 表示名 |
| `avatar_url` | text | | アイコン画像 |
| `point_balance` | int | not null, default 0, check `>= 0` | **子のみ使用**。`point_entries` の合計のキャッシュ |
| `created_at` | timestamptz | not null, default `now()` | |

- インデックス: `(group_id, role)`
- **`unique (id, group_id)`** … `tasks` / `activity_suggestions` が「この子は本当にこのグループの子か」を複合外部キーで検証するために必要
- **`point_balance` はトリガで保護**されており、値を変更するUPDATEは `point_balance can only be changed via point_entries` という例外で弾かれます。増減はRPC(security definer)からのみ可能

### `tasks` — やることリスト

親が**対象の子を1人指定して**作成する。1回きりで、承認されたら行ごと削除され再利用しない(`status = 'completed'` / `completed_at` は列としては残すが、`approve_task_request` が削除するため実際には使われない)。

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | uuid | PK | |
| `group_id` | uuid | not null → `groups(id)` on delete cascade | RLS・親の一覧表示を速くするための冗長列 |
| `child_id` | uuid | not null → `profiles(id)` on delete cascade | **対象の子** |
| `title` | text | not null | タスク名(必須) |
| `description` | text | | 詳細(任意) |
| `points` | int | not null, check `> 0` | 獲得ポイント(必須) |
| `status` | `task_status` | not null, default `open` | |
| `completed_at` | timestamptz | | 承認された時刻 |
| `created_by` | uuid | not null → `profiles(id)` | 作成した親 |
| `created_at` / `updated_at` | timestamptz | not null, default `now()` | |

- インデックス: `(child_id, status)`(子のリスト表示)、`(group_id, status)`(親の一覧表示)
- **`tasks_child_in_group`** … `(child_id, group_id) → profiles(id, group_id)` の複合外部キー。アプリ側にバグがあっても、別グループの子を対象にしたタスクはDBが拒否する
- 同じ内容を複数の子にやらせたい場合は、**子ごとに1行ずつ作成**する
- 削除は物理削除でよい。獲得済みポイントの履歴は `point_entries` にタイトルがスナップショットとして残るため壊れない

### `task_requests` — 達成申請

子が「終わった」と申請し、親が承認/却下する。

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | uuid | PK | |
| `task_id` | uuid | not null → `tasks(id)` on delete cascade | |
| `child_id` | uuid | not null → `profiles(id)` | 申請した子 |
| `status` | `request_status` | not null, default `pending` | |
| `requested_at` | timestamptz | not null, default `now()` | |
| `decided_by` | uuid | → `profiles(id)` | 承認/却下した親 |
| `decided_at` | timestamptz | | |

- **部分unique index `(task_id) where status = 'pending'`** … 1つのタスクに対して同時に複数の申請が並ばないようにする(1タスク1子なので task_id だけで足りる)
- 却下された後は再申請できる(`rejected` は部分indexの対象外のため)
- 承認されると `tasks` の削除に cascade されてこの行も消える。**同じ `task_id` に過去の却下済み申請があれば、それも一緒に削除される**(`status = 'approved'` / `decided_by` / `decided_at` は列としては残すが、承認された行は削除されるため実際には残らない)

### `rewards` — プレゼント(子どもごと)

親が特定の子ども1人に向けて用意した交換対象。`group_id` は RLS・一覧表示を速くするための冗長列で、実際の所有者は `child_id`。

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | uuid | PK | |
| `group_id` | uuid | not null → `groups(id)` on delete cascade | |
| `child_id` | uuid | not null → `profiles(id)` on delete cascade | **対象の子**(0011で追加) |
| `name` | text | not null | 名称(必須) |
| `cost_points` | int | not null, check `> 0` | 必要ポイント(必須) |
| `image_path` | text | | 画像(任意)。Supabase Storage `gift-images` バケットのパス(`<group_id>/<reward_id>.<ext>`) |
| `always_visible` | boolean | not null, default false | true なら承認後もこの行を残し、繰り返し交換できる(0011で追加) |
| `is_active` | boolean | not null, default true | false にすると交換できなくなる |
| `created_by` | uuid | not null → `profiles(id)` | 作成した親 |
| `created_at` / `updated_at` | timestamptz | not null, default `now()` | |

- **`rewards_child_in_group`** … `(child_id, group_id) → profiles(id, group_id)` の複合外部キー。`tasks_child_in_group` と同じ役割
- インデックス: `(child_id) where is_active`
- `always_visible = false`(既定)のプレゼントは、承認された時点で `rewards` 行ごと物理削除される(1回限り)。`true` のものは残り続け、何度でも交換申請できる
- 親の編集モードで「常に表示」の切り替え(`GiftService.setAlwaysVisible`)ができる
- UIの「ポイントが足りると色が変わる」は、クライアント側で `point_balance >= cost_points` を判定するだけでよく、DB列は不要

### `reward_redemptions` — 交換申請 兼 交換履歴

子どもの交換申請(`pending`)から、親の承認/却下までを1行で管理する。`task_requests` と違い、承認後にこの行自体が削除されるかどうかは `rewards.always_visible` に依存する(下記参照)。

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | uuid | PK | |
| `reward_id` | uuid | → `rewards(id)` **on delete set null** | 親が後で消しても履歴は残る |
| `child_id` | uuid | not null → `profiles(id)` | 申請した子 |
| `reward_name` | text | not null | **申請時点のスナップショット** |
| `cost_points` | int | not null | **申請時点のスナップショット** |
| `status` | `request_status` | not null, default `pending`(0011で追加) | |
| `decided_by` | uuid | → `profiles(id)`(0011で追加) | 承認/却下した親 |
| `decided_at` | timestamptz | (0011で追加) | |
| `redeemed_at` | timestamptz | not null, default `now()` | 申請日時 |

- **部分unique index `(reward_id) where status = 'pending'`** … `task_requests` と同様、1つのプレゼントに同時に複数の申請が並ばないようにする
- 却下された後は再申請できる(`rejected` は部分indexの対象外のため)
- **承認時の行の扱い**: `approve_reward_request` が `rewards.always_visible` を見て分岐する
  - `always_visible = false` → `rewards` 行ごと物理削除(この `reward_redemptions` 行は `on delete set null` で `reward_id` が null になって残る = 交換履歴として残る)
  - `always_visible = true` → `rewards` 行は残す。**`reward_redemptions` 行だけ削除**(`point_entries.redemption_id` が `on delete set null` で null になるが、台帳の記録自体は残る)。つまりこのケースでは交換履歴として `reward_redemptions` には残らない
- 名称と必要ポイントをスナップショットしているため、親がプレゼントを編集・削除しても「あのとき何を何ポイントで交換したか」は(残っている場合)正しく分かる

### `point_entries` — ポイント台帳

**残高の正**。`profiles.point_balance` はこのテーブルの合計のキャッシュ。

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | uuid | PK | |
| `child_id` | uuid | not null → `profiles(id)` on delete cascade | |
| `amount` | int | not null, check `<> 0` | **獲得は正、消費は負** |
| `entry_type` | `point_entry_type` | not null | |
| `description` | text | not null | 「宿題」等のスナップショット |
| `task_request_id` | uuid | → `task_requests(id)` on delete set null | 由来(タスク承認時) |
| `redemption_id` | uuid | → `reward_redemptions(id)` on delete set null | 由来(交換時) |
| `created_at` | timestamptz | not null, default `now()` | |

- インデックス: `(child_id, created_at desc)`
- `recompute_point_balance(child_id)` で台帳から残高を再計算できる。`profiles.point_balance` がずれた疑いがあるときの照合用

### `screen_time_daily` / `screen_time_apps` / `screen_time_hourly` — スクリーンタイム

子の端末から同期する。**直近分のみ保持**(初期値7日)。

**`screen_time_daily`**

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `child_id` | uuid | PK, not null → `profiles(id)` on delete cascade | |
| `date` | date | PK, not null | 端末ローカル日付 |
| `total_minutes` | int | not null, check `>= 0` | SNSアプリの合計利用分数 |
| `synced_at` | timestamptz | not null, default `now()` | |

**`screen_time_apps`**(アプリ別内訳)

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `child_id` | uuid | PK, not null | |
| `date` | date | PK, not null | |
| `app_id` | text | PK, not null | Androidパッケージ名(例 `com.instagram.android`) |
| `app_label` | text | not null | 表示名(例 `Insta`) |
| `minutes` | int | not null, check `>= 0` | |

- `(child_id, date)` → `screen_time_daily` への外部キー(**on delete cascade**)。保持期間の削除が自動で連鎖する
- PKが `(child_id, date)` / `(child_id, date, app_id)` なので、**同じ日を再同期するときはUPSERT**する

**`screen_time_hourly`**(時間帯別内訳。時間別グラフを保護者側でも表示するため)

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `child_id` | uuid | PK, not null | |
| `date` | date | PK, not null | |
| `hour` | smallint | PK, not null, check `0-23` | |
| `minutes` | smallint | not null, check `0-60` | その時間帯の全アプリ合計利用分数 |

- `screen_time_apps` と同じ形: `(child_id, date)` → `screen_time_daily` への外部キー(**on delete cascade**)。0分の時間帯は行を作らない
- 現状は `screen_time_apps` と同様に最新日(昨日)分だけが埋まる想定([screen_time_ai_commentary.md](screen_time_ai_commentary.md)参照)

**保持期間の管理**

```sql
-- 保持日数を変えたいときはこの関数の返り値だけを変更する
create or replace function screen_time_retention_days() returns int
  language sql immutable as $$ select 7 $$;

-- 保持期間より古い行を削除(screen_time_apps はカスケードで消える)
select purge_old_screen_time();
```

`purge_old_screen_time()` は、端末からの同期処理の最後に呼ぶか、`pg_cron` で日次実行します。**現時点では自動実行の設定はしていない**ため、呼び出しはアプリ側の実装時に組み込んでください。

### `ai_reviews` — AI講評 / ドパガキ指数

| 列 | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | uuid | PK | |
| `child_id` | uuid | not null → `profiles(id)` on delete cascade | |
| `date` | date | not null | 対象日(通常は「きのう」) |
| `dopagaki_score` | int | check `between 0 and 100` | **ドパガキ指数**。高いほど依存が深刻 |
| `comment` | text | not null | 講評本文(要約) |
| `advice` | jsonb | not null, default `'[]'` | アドバイス文字列の配列(`0008_ai_reviews_advice.sql` で追加) |
| `model` | text | | 生成に使ったモデル名 |
| `created_at` | timestamptz | not null, default `now()` | |

- `unique (child_id, date)` … 1日1件。再生成する場合はUPSERT
- **保持期間の対象外**。スクリーンタイムの生データが消えても、指数と講評は残り続ける
- AIが0〜100の範囲外を返した場合は**アプリ側でクランプしてから保存**する(check制約で弾かれて保存に失敗するため)
- 生成・保存は `supabase/functions/ai-review` (Edge Function) が Gemini API を呼んで行う。詳細は [screen_time_ai_commentary.md](screen_time_ai_commentary.md#aicommentaryservice) を参照

### `activity_suggestions` / `activity_requests` — 周辺アクティビティ提案

子どもがSNS時間の代わりに参加できる、お金のかからない地域の催しをAIが提案する機能。詳細な仕様は [nearby_activities.md](nearby_activities.md) を参照。

**`activity_suggestions`** … AIが提案したアクティビティ

`id`, `group_id`, `child_id`(提案対象), `title`, `description`, `place_name`, `latitude`, `longitude`, `source_url`, `origin_latitude` / `origin_longitude`(0013で追加。提案を生成したときの子どもの現在地。Edge Function のキャッシュキー), `created_at`
※ `tasks` と同様に `(child_id, group_id)` の複合外部キーでグループ整合性を担保
※ 生成・保存は `supabase/functions/activity-suggest` (Edge Function) が行う。`place_name`/`latitude`/`longitude` は Overpass API(OpenStreetMap)から取得した実在施設と一致した場合のみ実データが入り、一致しない/候補が取れない場合は `latitude`/`longitude` が `null` になる。`source_url` は検索グラウンディングを使わないため常に `null`。詳細は [nearby_activities.md](nearby_activities.md#edge-functionactivity-suggest) を参照。
  検索グラウンディングは無料枠が無いため使わず(詳細は [nearby_activities.md](nearby_activities.md#edge-functionactivity-suggest) 参照)、
  `latitude`/`longitude`/`source_url` は常に `null`

**`activity_requests`** … 子から親への「参加したい」申請

`id`, `suggestion_id`(on delete set null), `child_id`, `title` / `description`(スナップショット), `status`, `points`(親が承認時に設定), `created_task_id`(生成された `tasks` へのリンク), `decided_by`, `decided_at`, `requested_at`
- **部分unique index `(child_id, suggestion_id) where status = 'pending'`**(0013で追加) … 同じ提案への同時申請を防ぐ。却下後は再申請できる(`rejected` は対象外)

---

## RPC(状態変更はすべてここを通す)

残高やステータスの変更は、複数テーブルを矛盾なく更新する必要があるため、すべて `security definer` 関数にまとめています。**クライアントから対象テーブルを直接UPDATEすることはできません**(RLSにUPDATEポリシーを作っていないため)。

| RPC | 定義 | 引数 | 効果 |
|---|---|---|---|
| `create_parent_account` | [0002](../supabase/migrations/0002_profiles.sql) | `group_name`, `parent_display_name` | グループ作成 + 親プロフィール作成。`(group_id, group_code)` を返す |
| `join_group` | [0002](../supabase/migrations/0002_profiles.sql) | `code`, `child_display_name` | コードでグループを探し、子プロフィールを作成。`group_id` を返す |
| `approve_task_request` | [0004](../supabase/migrations/0004_points_and_rewards.sql)・[0010](../supabase/migrations/0010_delete_task_on_approve.sql)で更新 | `request_id` | 台帳に加算行 → 残高加算 → `tasks` を物理削除(cascadeで `task_requests` も削除、`point_entries.task_request_id` は null に) |
| `reject_task_request` | [0004](../supabase/migrations/0004_points_and_rewards.sql) | `request_id` | 申請を `rejected` に(タスクは `open` のまま = 再申請可能) |
| `request_reward` | [0011](../supabase/migrations/0011_reward_requests.sql) | `reward_id` | 残高チェック → `reward_redemptions` に `pending` 行を作成(ポイントはまだ減らさない)。生成した申請 id を返す |
| `approve_reward_request` | [0011](../supabase/migrations/0011_reward_requests.sql) | `request_id` | 残高再チェック → 台帳に減算行 → 残高減算 → `rewards.always_visible` に応じて `reward_redemptions` 行 or `rewards` 行を削除 |
| `reject_reward_request` | [0011](../supabase/migrations/0011_reward_requests.sql) | `request_id` | 申請を `rejected` に(プレゼント・ポイントとも変化なし = 再申請可能) |
| `recompute_point_balance` | [0004](../supabase/migrations/0004_points_and_rewards.sql) | `target_child_id` | 台帳から残高を再計算して返す(照合用、更新はしない) |
| `approve_activity_request` | [0006](../supabase/migrations/0006_activities.sql)・[0013](../supabase/migrations/0013_activity_fixes.sql)で修正 | `request_id`, `points` | 承認者が対象の子と同じグループの親か検証 → 申請を `approved` → `tasks` を生成 → `created_task_id` にリンク。生成した task id を返す |
| `reject_activity_request` | [0006](../supabase/migrations/0006_activities.sql)・[0013](../supabase/migrations/0013_activity_fixes.sql)で修正 | `request_id` | 承認者が対象の子と同じグループの親か検証 → 申請を `rejected` に |
| `generate_group_code` | [0001](../supabase/migrations/0001_types_and_groups.sql) | — | 未使用の4桁コードを払い出す(内部用) |
| `screen_time_retention_days` | [0005](../supabase/migrations/0005_screen_time_and_ai.sql) | — | 保持日数を返す。**変更時はここだけ直す** |
| `purge_old_screen_time` | [0005](../supabase/migrations/0005_screen_time_and_ai.sql) | — | 保持期間より古いスクリーンタイムを削除 |

### エラー時の挙動

RPCは不正な状態遷移を例外で弾きます。クライアントは例外メッセージを受け取るので、UIで適切に扱ってください。

- 既にプロフィールがある状態で `create_parent_account` / `join_group` → `This account already has a profile`
- 存在しないコードで `join_group` → `No group found for code XXXX`
- `pending` でない申請を承認/却下 → `Task request ... is not pending` / `Reward request ... is not pending`
- 存在しない(既に承認されて削除済みの) `request_id` で承認/却下 → `Task request ... not found` / `Reward request ... not found`
- 残高不足で `request_reward` / `approve_reward_request` → `Insufficient points: have X, need Y`
- `points <= 0` で `approve_activity_request` → `points must be positive`
- 対象の子と同じグループの親以外が `approve_activity_request` / `reject_activity_request` を呼ぶ → `Not authorized to decide activity request ...`

---

## RLS(アクセス制御)

全12テーブルで RLS 有効。詳細は [0007_rls.sql](../supabase/migrations/0007_rls.sql)。Storage の `gift-images` バケットは [0012_gift_images_bucket.sql](../supabase/migrations/0012_gift_images_bucket.sql) で別途ポリシーを定義。

### ヘルパー関数

`profiles` テーブルのポリシーが自分自身を再帰参照しないよう、`security definer` で定義しています。

| 関数 | 返り値 |
|---|---|
| `current_group_id()` | 呼び出しユーザーの `group_id` |
| `is_parent()` | 呼び出しユーザーが `parent` なら true |

### ポリシー一覧

| テーブル | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `groups` | 自分のグループのみ | — | — | — |
| `profiles` | 同一グループ全員 | — | 本人のみ(※) | — |
| `tasks` | **親: グループ全件 / 子: 自分宛のみ** | 親のみ | 親のみ | 親のみ |
| `task_requests` | 子: 自分の分 / 親: グループ内 | 子が自分宛の `open` タスクに対してのみ | RPC経由のみ | — |
| `rewards` | 同一グループ全員 | 親のみ | 親のみ | 親のみ |
| `reward_redemptions` | 同一グループ全員 | RPC経由のみ | RPC経由のみ | — |
| `point_entries` | 同一グループ全員 | RPC経由のみ | — | — |
| `screen_time_daily` | 同一グループ全員 | 子本人のみ | 子本人のみ | — |
| `screen_time_apps` | 同一グループ全員 | 子本人のみ | 子本人のみ | — |
| `screen_time_hourly` | 同一グループ全員 | 子本人のみ | 子本人のみ | 子本人のみ |
| `ai_reviews` | 同一グループ全員 | service role のみ | — | — |
| `activity_suggestions` | 同一グループ全員 | service role のみ | — | — |
| `activity_requests` | 子: 自分の分 / 親: グループ内 | 子が自分の分のみ | RPC経由のみ | — |

`activity_requests` は Supabase Realtime にも登録されている([0013](../supabase/migrations/0013_activity_fixes.sql)の `alter publication supabase_realtime add table activity_requests`)。`postgres_changes` は上記の SELECT ポリシーを通った行だけを配信するため、購読側で追加のフィルタは不要。詳細は [nearby_activities.md](nearby_activities.md#realtime) を参照。

※ `profiles` の UPDATE は本人のみ許可。`point_balance` の変更はトリガで別途禁止しているため、実質 `display_name` / `avatar_url` のみ変更可能。

### Storage: `gift-images` バケット

非公開バケット。オブジェクトキーは `<group_id>/<reward_id>.<ext>` の形式で、先頭フォルダ名(= `group_id`)で読み書きをグループ内に限定する([0012_gift_images_bucket.sql](../supabase/migrations/0012_gift_images_bucket.sql))。

| 操作 | 条件 |
|---|---|
| SELECT | 同一グループ全員(`(storage.foldername(name))[1] = current_group_id()::text`) |
| INSERT / UPDATE / DELETE | 上記に加え `is_parent()` |

非公開のため、クライアントは署名付きURLではなく `storage.download()` で `Uint8List` を取得して `Image.memory` に渡す(`GiftService.downloadImage`)。

### 重要な前提

- **`ai_reviews` と `activity_suggestions` の生成は service role キーで行う**(AI講評の生成はサーバー/Edge Functionsの責務)。anon キーのクライアントからは書き込めません
- **service_role キーをFlutterアプリに埋め込まないこと**。RLSをすべて無視できてしまいます

---

## 主要なユースケースの流れ

### 親子のリンク

```
親: サインアップ(Auth) → create_parent_account('やまだ家', 'おかあさん')
                        → group_code '7325' が払い出される
子: サインアップ(Auth) → join_group('7325', 'たろう')
```

### タスク → ポイント獲得

```
親: insert into tasks (group_id, child_id, title, points, created_by) values (..., 'たろう', '宿題', 4, ...)
子: insert into task_requests (task_id, child_id) values (..., 'たろう')   -- 達成申請
親: select approve_task_request('<request_id>')
    → point_entries に +4 の行(description='宿題')
    → profiles.point_balance += 4
    → tasks を削除(cascadeで task_requests も削除。同じタスクに対する
      過去の却下済み申請があればそれも一緒に消える)
```

### プレゼント交換(承認フロー)

```
親: insert into rewards (group_id, child_id, name, cost_points, always_visible, created_by)
      values (..., 'たろう', 'Ankerイヤホン', 150, false, ...)
子: select request_reward('<reward_id>')                -- 交換申請
    → 残高 < 150 なら例外
    → reward_redemptions に pending 行(name/cost をスナップショット)
      ※ この時点ではまだポイントは減らない

親: select approve_reward_request('<request_id>')       -- 承認
    → 残高を再チェック(不足していれば例外で失敗、却下にはならない)
    → point_entries に -150 の行
    → profiles.point_balance -= 150
    → always_visible = false なら rewards を物理削除(1回限り)
    → always_visible = true  なら reward_redemptions の申請行だけ削除(プレゼントは残り再交換可)

  または

親: select reject_reward_request('<request_id>')        -- 却下
    → reward_redemptions.status = 'rejected'。ポイント・プレゼントとも変化なし
    → 子は同じプレゼントに再度 request_reward できる
```

### スクリーンタイム同期とAI講評

```
子の端末: screen_time_daily / screen_time_apps に当日分をUPSERT
          → 最後に purge_old_screen_time() を呼んで古い行を削除
サーバー: 前日分の screen_time_* を読んでAIに渡し、
          ai_reviews に (dopagaki_score, comment) をUPSERT
アプリ:   ホーム画面で ai_reviews の最新行と screen_time_* のグラフを表示
```

> **現状**: ホーム画面のカード自体は実装済み([lib/screens/home_body.dart](../lib/screens/home_body.dart))だが、上記の同期・AI生成部分は未実装で、`MockScreenTimeService`/`MockAiCommentaryService` によるダミーデータで動作している。クライアント側の詳細な仕様は [screen_time_ai_commentary.md](screen_time_ai_commentary.md) を参照。

---

## 運用

### マイグレーションの適用

Supabase CLIをnpmのdevDependencyとして導入しています(Dockerは使いません)。

```sh
npm install                                    # 初回のみ
export SUPABASE_ACCESS_TOKEN=<personal access token>
npx supabase link --project-ref <project ref>  # 初回のみ
npx supabase db push                           # マイグレーションを適用
npx supabase migration list                    # local/remote の適用状況を確認
```

Personal Access Token は https://supabase.com/dashboard/account/tokens で発行します。**リポジトリにコミットしないこと**。

### スキーマを変更するとき

1. `supabase/migrations/` に**新しい番号のファイルを追加**する(既存ファイルは編集しない。適用済みのため差分が出なくなる)
2. `npx supabase db push` で適用
3. このドキュメントを更新

### リモートに対するクエリ実行

Dockerを使わずリモートのDBを直接叩けます。

```sh
npx supabase db query --linked "select * from groups;"
```

### 未対応・今後の課題

- **RLSの動作検証が未実施**。別ユーザーのJWTで「子Bから子A宛のタスクが見えないか」等のテストはまだ行っていません
- **`purge_old_screen_time()` の自動実行が未設定**。`pg_cron` かアプリ側の同期処理に組み込む必要があります
- **グループコードは4桁固定**(1万通り)。総当たりで他人のグループに参加できてしまうリスクがあるため、コードの再生成機能や有効期限を将来検討する余地があります
- **`profiles` に子のプロフィール削除のフローがない**。子アカウントを抜けさせる操作は未定義です
- **スクリーンタイム自体は現状クライアント内のモックのみ**。`ScreenTimeService`([lib/services/screen_time_service.dart](../lib/services/screen_time_service.dart))はまだ `screen_time_daily`/`screen_time_apps` を読み書きしていません。一方 `AiCommentaryService` は `SupabaseAiCommentaryService` が `ai-review` Edge Function 経由で実際に `ai_reviews` を読み書きします(モックのスクリーンタイムをリクエストボディで渡す形)。詳細は [screen_time_ai_commentary.md](screen_time_ai_commentary.md) を参照
- **`approve_task_request` / `approve_reward_request` に承認者の資格チェックが無い**。どちらも `security definer` で RLS を素通りするが、呼び出し元が「対象の子と同じグループの親か」を検証していない(`approve_activity_request` は [0013](../supabase/migrations/0013_activity_fixes.sql) でこの穴を塞いだが、既存の2つは未対応のまま)
- **`activity_suggestions.origin_latitude`/`origin_longitude` に生の緯度経度を保存し続ける**。個人情報であり保持期間の議論が未整理。`screen_time_daily` のような保持期間管理の仕組み(`purge_old_screen_time` 相当)を将来検討する余地がある
- **`activity-suggest` Edge Function はリクエストボディの緯度経度をそのまま信頼する**。`ai-review` が `screen_time` を信頼しているのと同じ構造で、呼び出し元が同じグループのメンバーかは検証するが、送られてきた座標自体が本物かは検証していない
