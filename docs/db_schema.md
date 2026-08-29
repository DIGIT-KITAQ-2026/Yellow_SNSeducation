# DB設計 (Supabase / PostgreSQL)

このドキュメントは [supabase/migrations/](../supabase/migrations/) に定義されたスキーマの概要です。
マイグレーション本体が正、ここは全体像を把握するための補助資料。

## 方針

- 基盤: Supabase (PostgreSQL) + Supabase Auth。アクセス制御は Row Level Security (RLS)。
- ポイント残高・やることリストは**子どもごと**(親が対象の子を指定してタスクを作成)。プレゼントは**グループ共有**。
- タスクは**1回きり**。繰り返しは持たず、親が必要な都度作成する。
- スクリーンタイムの生データは**直近分のみ**保持([`screen_time_retention_days()`](../supabase/migrations/0005_screen_time_and_ai.sql) で一元管理、初期値7日)。
  ドパガキ指数・AI講評 (`ai_reviews`) は保持期間の対象外で、生データが消えても推移を残す。

## ER図

```mermaid
erDiagram
    groups ||--o{ profiles : "has members"
    profiles ||--o{ tasks : "assigned to"
    tasks ||--o{ task_requests : "requested via"
    groups ||--o{ rewards : "offers"
    rewards ||--o{ reward_redemptions : "redeemed as"
    profiles ||--o{ reward_redemptions : "redeemed by"
    profiles ||--o{ point_entries : "ledger for"
    profiles ||--o{ screen_time_daily : "tracked for"
    screen_time_daily ||--o{ screen_time_apps : "breaks down into"
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
        text name
        int cost_points
    }
    reward_redemptions {
        uuid id PK
        uuid reward_id FK
        uuid child_id FK
        text reward_name "snapshot"
        int cost_points "snapshot"
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

## テーブル一覧

| テーブル | 役割 | 主な参照先 |
|---|---|---|
| `groups` | 親子グループ。4桁 `group_code` で子が参加 | — |
| `profiles` | 親/子のアカウント。`point_balance` は台帳のキャッシュ | `groups` |
| `tasks` | やることリスト(子ごとに割り当て、1回きり) | `groups`, `profiles` |
| `task_requests` | 子の達成申請。1タスクにつき同時に1件のpendingのみ | `tasks`, `profiles` |
| `rewards` | プレゼント(グループ共有) | `groups`, `profiles` |
| `reward_redemptions` | 交換履歴(名称・必要ポイントをスナップショット) | `rewards`, `profiles` |
| `point_entries` | ポイント台帳。残高の正 | `profiles`, `task_requests`, `reward_redemptions` |
| `screen_time_daily` / `screen_time_apps` | 日次スクリーンタイム(直近分のみ保持) | `profiles` |
| `ai_reviews` | AI講評とドパガキ指数(削除されない) | `profiles` |
| `activity_suggestions` / `activity_requests` | 周辺アクティビティ提案(将来機能) | `groups`, `profiles`, `tasks` |

## 状態変更はRPC経由

残高やステータスに関わる更新は、整合性を保つため security definer 関数(RPC)にまとめている。クライアントから対象テーブルを直接 UPDATE することはできない。

| RPC | 定義ファイル | 効果 |
|---|---|---|
| `create_parent_account` / `join_group` | [0002_profiles.sql](../supabase/migrations/0002_profiles.sql) | グループ作成/参加とプロフィール作成 |
| `approve_task_request` / `reject_task_request` | [0004_points_and_rewards.sql](../supabase/migrations/0004_points_and_rewards.sql) | タスク承認 → 完了化・ポイント加算 / 却下 |
| `redeem_reward` | [0004_points_and_rewards.sql](../supabase/migrations/0004_points_and_rewards.sql) | 残高チェック → 交換履歴・ポイント減算 |
| `approve_activity_request` / `reject_activity_request` | [0006_activities.sql](../supabase/migrations/0006_activities.sql) | 承認 → `tasks` 生成 / 却下 |

## RLSの要点

詳細は [0007_rls.sql](../supabase/migrations/0007_rls.sql) を参照。

- `current_group_id()` / `is_parent()` は `security definer` の補助関数で、`profiles` テーブル自身のRLSと循環しないようにしている。
- `tasks` の SELECT は「親はグループ全件、子は自分に割り当てられた分のみ」。
- `tasks.child_id` が同一グループの子であることは、`profiles (id, group_id)` の複合UNIQUEキーへの複合外部キー(`tasks_child_in_group`)で保証しており、アプリ側のチェック漏れがあってもDBレベルで弾かれる。
- `point_entries` / `reward_redemptions` / `ai_reviews` はSELECTのみ許可し、書き込みは上表のRPC経由に限定。
