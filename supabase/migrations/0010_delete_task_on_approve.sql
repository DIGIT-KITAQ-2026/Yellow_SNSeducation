-- 達成承認されたタスクは物理削除する(docs/db_schema.md:208 の設計方針)。
-- task_requests は tasks への on delete cascade で、point_entries.task_request_id
-- は task_requests への on delete set null で連動して処理される。
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
end;
$$;
