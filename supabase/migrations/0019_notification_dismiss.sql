-- お知らせの「消去」と、それに合わせた申請行の寿命の整理。
--
-- これまで承認は申請行を道連れに消していた(approve_task_request は tasks を
-- 消して task_requests を cascade で、approve_reward_request は always_visible の
-- とき申請行そのものを)。そのため「何を了承したのか」を後から辿る先が無かった。
--
-- ここからは:
--   * 承認 … 申請行を 'approved' のまま残す。tasks / rewards を消すのは従来どおり。
--             その申請を指す通知が親子とも消えた時点で、申請行も消える。
--   * 却下 … 申請行を即削除する(やり直して再申請できる状態に戻すだけなので、
--             残しておく意味が無い)。
--   * 通知 … 受信者が自分の行を物理削除できる。

-- ---------------------------------------------------------------------------
-- 1. 承認済みの task_requests が tasks の削除を生き延びられるようにする
-- ---------------------------------------------------------------------------
-- 0003 では on delete cascade だったので、approve_task_request の
-- `delete from tasks` が申請行まで消していた。set null に変えて、承認済みの
-- 申請行だけが残るようにする。
-- 部分ユニーク idx_task_requests_one_pending_per_task は status='pending' の
-- 行だけを見るので、task_id が null の承認済み行が増えても影響しない。
alter table task_requests alter column task_id drop not null;
alter table task_requests drop constraint task_requests_task_id_fkey;
alter table task_requests add constraint task_requests_task_id_fkey
  foreign key (task_id) references tasks (id) on delete set null;

-- ---------------------------------------------------------------------------
-- 2. 承認RPC: 申請行を消さない
-- ---------------------------------------------------------------------------
-- 0017 の定義から、申請行の扱いだけを差し替えたもの。
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

  -- 申請行は残す(0019)。tasks を消すと task_id は null になる。
  update task_requests
    set status = 'approved', decided_by = auth.uid(), decided_at = now()
    where id = request_id;

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

  -- 申請行は always_visible かどうかに関わらず残す(0019)。分岐は
  -- 「プレゼント本体を消すかどうか」だけになった。
  update reward_redemptions
    set status = 'approved', decided_by = auth.uid(), decided_at = now()
    where id = request_id;

  if not rwd.always_visible then
    -- point_entries insert より後に実行すること(reward_id は set null で外れる)。
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

-- approve_activity_request はもともと申請行を消していないので変更しない。

-- ---------------------------------------------------------------------------
-- 3. 却下RPC: 申請行を即削除する
-- ---------------------------------------------------------------------------
-- notify_child に渡す値はレコード変数から読むので、削除より後に通知しても
-- 文面は作れる。point_entries からの参照は on delete set null。
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

  select * into tsk from tasks where id = req.task_id;

  -- 却下では tasks 行を消さない(status は 'open' のまま)。子どもはやり直して
  -- 再申請できる。申請行のほうは残しても使い道が無いのでここで消す(0019)。
  delete from task_requests where id = request_id;

  perform notify_child(req.child_id, 'quest_rejected', jsonb_build_object(
    'request_id', request_id,
    'item_title', coalesce(tsk.title, '')
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

  delete from reward_redemptions where id = request_id;

  perform notify_child(req.child_id, 'reward_rejected', jsonb_build_object(
    'request_id', request_id,
    'item_title', req.reward_name
  ));
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

  delete from activity_requests where id = request_id;

  perform notify_child(req.child_id, 'activity_rejected', jsonb_build_object(
    'request_id', request_id,
    'item_title', req.title
  ));
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. 通知の消去
-- ---------------------------------------------------------------------------
-- 自分宛の行だけ消せる(既読と同じ条件)。
create policy notifications_delete on notifications
  for delete using (recipient_id = auth.uid());

-- 申請の通知は親にも子にも1件ずつ出る。両方消えて初めて、その申請を辿る先が
-- 誰にも無くなるので、そのときに申請行も片付ける。
-- security definer なのは、申請テーブルに DELETE の RLS ポリシーを作らずに
-- (= クライアントから直接消せないままで)済ませるため。
create function cleanup_request_on_notification_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  rid uuid;
begin
  begin
    rid := (old.payload ->> 'request_id')::uuid;
  exception when invalid_text_representation then
    return old;
  end;
  if rid is null then
    return old;
  end if;

  if exists (
    select 1 from notifications
    where payload ->> 'request_id' = rid::text
  ) then
    return old;
  end if;

  delete from task_requests where id = rid;
  delete from reward_redemptions where id = rid;
  delete from activity_requests where id = rid;
  return old;
end;
$$;

create trigger trg_cleanup_request_on_notification_delete
  after delete on notifications
  for each row execute function cleanup_request_on_notification_delete();

-- トリガーからしか呼ばないので、0018 と同じく API ロールからは実行権を剥がす。
-- `public` を外すのを忘れないこと(EXECUTE は既定で PUBLIC に付く)。
revoke execute on function cleanup_request_on_notification_delete()
  from public, anon, authenticated;
