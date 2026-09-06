-- A prize a parent has made available to the whole group, redeemable by any child
-- with enough points.
create table rewards (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references groups (id) on delete cascade,
  name         text not null,
  cost_points  int not null check (cost_points > 0),
  image_path   text,
  is_active    boolean not null default true,
  created_by   uuid not null references profiles (id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- History of redemptions. Snapshots name/cost so it stays accurate even if the
-- reward is later edited or removed.
create table reward_redemptions (
  id           uuid primary key default gen_random_uuid(),
  reward_id    uuid references rewards (id) on delete set null,
  child_id     uuid not null references profiles (id),
  reward_name  text not null,
  cost_points  int not null,
  redeemed_at  timestamptz not null default now()
);

-- The point ledger is the source of truth for a child's balance. profiles.point_balance
-- is a cache that must only be moved in lockstep with a row inserted here.
create table point_entries (
  id               uuid primary key default gen_random_uuid(),
  child_id         uuid not null references profiles (id) on delete cascade,
  amount           int not null check (amount <> 0),
  entry_type       point_entry_type not null,
  description      text not null,
  task_request_id  uuid references task_requests (id) on delete set null,
  redemption_id    uuid references reward_redemptions (id) on delete set null,
  created_at       timestamptz not null default now()
);

create index idx_point_entries_child_created on point_entries (child_id, created_at desc);

-- Recomputes a child's balance from the ledger, for reconciling profiles.point_balance
-- if it were ever suspected to have drifted.
create or replace function recompute_point_balance(target_child_id uuid)
returns int
language sql
stable
as $$
  select coalesce(sum(amount), 0) from point_entries where child_id = target_child_id
$$;

-- Approves a pending task request: marks it approved, closes the task, and credits
-- the child's point ledger/balance, all in one transaction.
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

  update profiles
    set point_balance = point_balance + tsk.points
    where id = tsk.child_id;
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
end;
$$;

-- Redeems a reward for the calling child: checks balance, records history,
-- and debits the ledger/balance, all in one transaction.
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

  update profiles set point_balance = point_balance - rwd.cost_points where id = auth.uid();
end;
$$;
