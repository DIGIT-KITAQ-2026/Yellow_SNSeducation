-- 通知テーブル。これまで子どもへの通知文は親の端末上(ChildNotificationRegistry)で
-- 組み立てられていて、子どもの端末には一切届いていなかった。通知行の生成をすべて
-- サーバ側(トリガーと承認/却下RPC)に寄せ、各端末は自分宛の行を Realtime で受け取る。
--
-- 表示文面はここには持たない。kind と payload だけを保存し、日本語の組み立ては
-- Dart 側 (lib/services/notification_messages.dart) が行う。文面を直すのに
-- マイグレーションを足さなくて済むようにするため。
create table notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles (id) on delete cascade,
  group_id     uuid not null references groups (id) on delete cascade,
  kind         text not null,
  child_id     uuid references profiles (id) on delete cascade,
  payload      jsonb not null default '{}'::jsonb,
  dedupe_key   text,
  read_at      timestamptz,
  created_at   timestamptz not null default now()
);

create index idx_notifications_recipient on notifications (recipient_id, created_at desc);

-- 同じ出来事で何度も鳴らさないための重複排除キー(スクリーンタイム更新で使う)。
create unique index uq_notifications_dedupe on notifications (recipient_id, dedupe_key)
  where dedupe_key is not null;

comment on column notifications.kind is
  'quest_request / reward_request / activity_request / quest_approved / quest_rejected / '
  'reward_approved / reward_rejected / activity_approved / activity_rejected / screen_time_updated';
comment on column notifications.child_id is
  '通知の対象となる子ども。親宛なら「誰についての通知か」、子ども宛なら受信者自身';

-- 同じグループの親全員に1行ずつ配る。既読を受信者ごとに持ちたいので、
-- 「親ロール宛の1行」ではなく親の人数ぶんファンアウトする。
create or replace function notify_group_parents(
  p_group_id   uuid,
  p_kind       text,
  p_child_id   uuid,
  p_payload    jsonb,
  p_dedupe_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into notifications (recipient_id, group_id, kind, child_id, payload, dedupe_key)
  select p.id, p_group_id, p_kind, p_child_id, p_payload, p_dedupe_key
    from profiles p
   where p.group_id = p_group_id and p.role = 'parent'
  on conflict do nothing;
end;
$$;

create or replace function notify_child(p_child_id uuid, p_kind text, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  g uuid;
begin
  select group_id into g from profiles where id = p_child_id;
  if g is null then
    return; -- 退会済みなど。通知できないだけで、呼び出し元の処理は止めない。
  end if;

  insert into notifications (recipient_id, group_id, kind, child_id, payload)
    values (p_child_id, g, p_kind, p_child_id, p_payload);
end;
$$;

-- ---------------------------------------------------------------------------
-- 申請 → 親
--
-- クエスト達成申請はクライアントからの直 INSERT、交換申請は request_reward RPC 経由と
-- 入口が違うので、RPC ではなくトリガーで拾う。
-- ---------------------------------------------------------------------------

create or replace function notify_task_request() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  child profiles%rowtype;
  tsk   tasks%rowtype;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  select * into child from profiles where id = new.child_id;
  select * into tsk from tasks where id = new.task_id;

  perform notify_group_parents(
    child.group_id, 'quest_request', new.child_id,
    jsonb_build_object(
      'request_id', new.id,
      'child_name', child.display_name,
      'item_title', coalesce(tsk.title, '')
    )
  );
  return new;
end;
$$;

create trigger trg_notify_task_request
  after insert on task_requests
  for each row execute function notify_task_request();

create or replace function notify_reward_request() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  child profiles%rowtype;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  select * into child from profiles where id = new.child_id;

  perform notify_group_parents(
    child.group_id, 'reward_request', new.child_id,
    jsonb_build_object(
      'request_id', new.id,
      'child_name', child.display_name,
      'item_title', new.reward_name,
      'points', new.cost_points
    )
  );
  return new;
end;
$$;

create trigger trg_notify_reward_request
  after insert on reward_redemptions
  for each row execute function notify_reward_request();

create or replace function notify_activity_request() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  child profiles%rowtype;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  select * into child from profiles where id = new.child_id;

  perform notify_group_parents(
    child.group_id, 'activity_request', new.child_id,
    jsonb_build_object(
      'request_id', new.id,
      'child_name', child.display_name,
      'item_title', new.title
    )
  );
  return new;
end;
$$;

create trigger trg_notify_activity_request
  after insert on activity_requests
  for each row execute function notify_activity_request();

-- ---------------------------------------------------------------------------
-- スクリーンタイム更新 → 親
--
-- SupabaseScreenTimeService.syncDays はアプリを開くたび直近7日ぶんを upsert するので、
-- 素朴にトリガーを張ると毎回7通鳴る。(1) 直近の日付だけを対象にし、
-- (2) 子ども・日付ごとの dedupe_key で重複を弾く。
-- 日付は端末ローカル基準・DB は UTC なので、current_date - 1 まで見る。
-- ---------------------------------------------------------------------------
create or replace function notify_screen_time_updated() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  child profiles%rowtype;
begin
  if new.date < current_date - 1 then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.total_minutes = old.total_minutes then
    return new; -- 中身が変わっていない upsert では鳴らさない
  end if;

  select * into child from profiles where id = new.child_id;

  perform notify_group_parents(
    child.group_id, 'screen_time_updated', new.child_id,
    jsonb_build_object(
      'child_name', child.display_name,
      'date', to_char(new.date, 'YYYY-MM-DD'),
      'total_minutes', new.total_minutes
    ),
    'screen_time:' || new.child_id || ':' || to_char(new.date, 'YYYY-MM-DD')
  );
  return new;
end;
$$;

create trigger trg_notify_screen_time
  after insert or update on screen_time_daily
  for each row execute function notify_screen_time_updated();

-- ---------------------------------------------------------------------------
-- 承認 / 却下 → 子ども
--
-- こちらはトリガーにできない。approve_task_request は tasks を削除して
-- task_requests を cascade で消す(0010)ため UPDATE トリガーが発火せず、
-- approve_reward_request も always_visible 分岐で申請行を消す(0011)ため。
-- 既存の RPC 本体に notify_child を1行足す形で置き換える。
-- ---------------------------------------------------------------------------

-- 0010_delete_task_on_approve.sql の定義に通知を足したもの。
create or replace function approve_task_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req task_requests%rowtype;
  tsk tasks%rowtype;
begin
  select * into req from task_requests where id = request_id for update;
  if req is null then
    raise exception 'Task request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Task request % is not pending', request_id;
  end if;

  select * into tsk from tasks where id = req.task_id for update;
  if tsk.status <> 'open' then
    raise exception 'Task % is already completed', tsk.id;
  end if;

  insert into point_entries (child_id, amount, entry_type, description, task_request_id)
    values (tsk.child_id, tsk.points, 'task_reward', tsk.title, request_id);

  perform set_config('app.allow_point_balance_change', 'on', true);
  update profiles
    set point_balance = point_balance + tsk.points
    where id = tsk.child_id;

  -- point_entries insert より後に実行すること。先に消すと task_requests が
  -- cascade で消え、上の insert が外部キー違反になる。
  delete from tasks where id = tsk.id;

  -- tsk は削除前に読んだレコード変数なので、ここでも中身を参照できる。
  perform notify_child(tsk.child_id, 'quest_approved', jsonb_build_object(
    'request_id', request_id,
    'item_title', tsk.title,
    'points', tsk.points,
    'point_balance', (select point_balance from profiles where id = tsk.child_id)
  ));
end;
$$;

create or replace function reject_task_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req task_requests%rowtype;
  tsk tasks%rowtype;
begin
  select * into req from task_requests where id = request_id for update;
  if req is null then
    raise exception 'Task request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Task request % is not pending', request_id;
  end if;

  update task_requests
    set status = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = request_id;

  -- 却下では tasks 行を消さない(status は 'open' のまま)。子どもはやり直して
  -- 再申請できる。pending が1件までなのは idx_task_requests_one_pending_per_task。
  select * into tsk from tasks where id = req.task_id;

  perform notify_child(req.child_id, 'quest_rejected', jsonb_build_object(
    'request_id', request_id,
    'item_title', coalesce(tsk.title, '')
  ));
end;
$$;

-- 0011_reward_requests.sql の定義に通知を足したもの。
create or replace function approve_reward_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req     reward_redemptions%rowtype;
  rwd     rewards%rowtype;
  balance int;
begin
  select * into req from reward_redemptions where id = request_id for update;
  if req is null then
    raise exception 'Reward request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Reward request % is not pending', request_id;
  end if;

  select * into rwd from rewards where id = req.reward_id for update;
  if rwd is null then
    raise exception 'Reward % not found', req.reward_id;
  end if;

  select point_balance into balance from profiles where id = req.child_id for update;
  if balance < req.cost_points then
    raise exception 'Insufficient points: have %, need %', balance, req.cost_points;
  end if;

  insert into point_entries (child_id, amount, entry_type, description, redemption_id)
    values (req.child_id, -req.cost_points, 'reward_redemption', req.reward_name, request_id);

  perform set_config('app.allow_point_balance_change', 'on', true);
  update profiles set point_balance = point_balance - req.cost_points where id = req.child_id;

  if rwd.always_visible then
    -- プレゼントは残す。申請行だけ消す(point_entries.redemption_id は
    -- on delete set null で連動するので台帳の記録は残る)。
    delete from reward_redemptions where id = request_id;
  else
    -- point_entries insert より後に実行すること。先に rewards を消すと
    -- reward_redemptions.reward_id が set null になった後の cascade 順序に
    -- 依存させないため。
    update reward_redemptions
      set status = 'approved', decided_by = auth.uid(), decided_at = now()
      where id = request_id;
    delete from rewards where id = rwd.id;
  end if;

  perform notify_child(req.child_id, 'reward_approved', jsonb_build_object(
    'request_id', request_id,
    'item_title', req.reward_name,
    'points', req.cost_points,
    'point_balance', (select point_balance from profiles where id = req.child_id)
  ));
end;
$$;

create or replace function reject_reward_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req reward_redemptions%rowtype;
begin
  select * into req from reward_redemptions where id = request_id for update;
  if req is null then
    raise exception 'Reward request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Reward request % is not pending', request_id;
  end if;

  update reward_redemptions
    set status = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = request_id;

  perform notify_child(req.child_id, 'reward_rejected', jsonb_build_object(
    'request_id', request_id,
    'item_title', req.reward_name
  ));
end;
$$;

-- 0013_activity_fixes.sql の定義に通知を足したもの。
create or replace function approve_activity_request(request_id uuid, points int)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  req      activity_requests%rowtype;
  child    profiles%rowtype;
  new_task uuid;
  award    int := points;  -- 列名 points との衝突を避けるための別名
begin
  if award is null or award <= 0 then
    raise exception 'points must be positive';
  end if;

  select * into req from activity_requests where id = request_id for update;
  if not found then
    raise exception 'Activity request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Activity request % is not pending', request_id;
  end if;

  select * into child from profiles where id = req.child_id;

  -- 承認できるのは、その子と同じグループの親だけ。
  if not is_parent() or child.group_id is distinct from current_group_id() then
    raise exception 'Not authorized to decide activity request %', request_id;
  end if;

  insert into tasks (group_id, child_id, title, description, points, created_by)
    values (child.group_id, req.child_id, req.title, req.description, award, auth.uid())
    returning id into new_task;

  update activity_requests
    set status = 'approved', points = award, created_task_id = new_task,
        decided_by = auth.uid(), decided_at = now()
    where id = request_id;

  perform notify_child(req.child_id, 'activity_approved', jsonb_build_object(
    'request_id', request_id,
    'item_title', req.title,
    'points', award
  ));

  return new_task;
end;
$$;

create or replace function reject_activity_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req   activity_requests%rowtype;
  child profiles%rowtype;
begin
  select * into req from activity_requests where id = request_id for update;
  if not found then
    raise exception 'Activity request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Activity request % is not pending', request_id;
  end if;

  select * into child from profiles where id = req.child_id;
  if not is_parent() or child.group_id is distinct from current_group_id() then
    raise exception 'Not authorized to decide activity request %', request_id;
  end if;

  update activity_requests
    set status = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = request_id;

  perform notify_child(req.child_id, 'activity_rejected', jsonb_build_object(
    'request_id', request_id,
    'item_title', req.title
  ));
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS と Realtime
--
-- 自分宛の行だけ読めて、自分宛の行の既読だけ立てられる。INSERT ポリシーは作らない
-- (上の security definer 関数だけが通知を作れる)。
-- ---------------------------------------------------------------------------
alter table notifications enable row level security;

create policy notifications_select on notifications
  for select using (recipient_id = auth.uid());

create policy notifications_update on notifications
  for update using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

-- postgres_changes は RLS の SELECT ポリシーを通った行だけを配信するが、
-- 購読側でも recipient_id でフィルタして無駄な配信を減らす(0013 の activity_requests と同じ方針)。
alter publication supabase_realtime add table notifications;
