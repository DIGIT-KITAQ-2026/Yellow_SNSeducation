-- prevent_direct_point_balance_change (0002_profiles.sql) unconditionally raised
-- whenever profiles.point_balance changed, with no way to distinguish a direct
-- client UPDATE from the legitimate change made by approve_task_request /
-- redeem_reward themselves. Those are precisely "the point_entries ledger" the
-- trigger's own error message says is the allowed path, so every call to either
-- RPC raised inside the trigger and rolled back the whole transaction: a task
-- request could never actually be approved (or a reward ever redeemed).
--
-- Gate the trigger on a transaction-local flag that only these security-definer
-- functions set, immediately before writing the ledger's balance side. The
-- flag is set with set_config(..., true) (local to the current transaction),
-- so it clears itself once the function's implicit transaction ends and can't
-- leak into any later, unrelated statement on the same connection.
create or replace function prevent_direct_point_balance_change()
returns trigger
language plpgsql
as $$
begin
  if new.point_balance <> old.point_balance
     and coalesce(current_setting('app.allow_point_balance_change', true), '') <> 'on' then
    raise exception 'point_balance can only be changed via point_entries';
  end if;
  return new;
end;
$$;

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

  update task_requests
    set status = 'approved', decided_by = auth.uid(), decided_at = now()
    where id = request_id;

  update tasks
    set status = 'completed', completed_at = now(), updated_at = now()
    where id = tsk.id;

  insert into point_entries (child_id, amount, entry_type, description, task_request_id)
    values (tsk.child_id, tsk.points, 'task_reward', tsk.title, request_id);

  perform set_config('app.allow_point_balance_change', 'on', true);
  update profiles
    set point_balance = point_balance + tsk.points
    where id = tsk.child_id;
end;
$$;

create or replace function redeem_reward(reward_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  rwd        rewards%rowtype;
  redemption uuid;
  balance    int;
begin
  select * into rwd from rewards where id = reward_id and is_active;
  if rwd is null then
    raise exception 'Reward % not found or inactive', reward_id;
  end if;

  select point_balance into balance from profiles where id = auth.uid() for update;
  if balance < rwd.cost_points then
    raise exception 'Insufficient points: have %, need %', balance, rwd.cost_points;
  end if;

  insert into reward_redemptions (reward_id, child_id, reward_name, cost_points)
    values (rwd.id, auth.uid(), rwd.name, rwd.cost_points)
    returning id into redemption;

  insert into point_entries (child_id, amount, entry_type, description, redemption_id)
    values (auth.uid(), -rwd.cost_points, 'reward_redemption', rwd.name, redemption);

  perform set_config('app.allow_point_balance_change', 'on', true);
  update profiles set point_balance = point_balance - rwd.cost_points where id = auth.uid();
end;
$$;
