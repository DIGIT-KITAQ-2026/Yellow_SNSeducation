-- A to-do item assigned by a parent to exactly one child. One-shot: it is not
-- reset or repeated, the parent creates a new row for the next occurrence.
create table tasks (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references groups (id) on delete cascade,
  child_id     uuid not null references profiles (id) on delete cascade,
  title        text not null,
  description  text,
  points       int not null check (points > 0),
  status       task_status not null default 'open',
  completed_at timestamptz,
  created_by   uuid not null references profiles (id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- Ensures child_id really belongs to group_id, via profiles' composite unique key.
  constraint tasks_child_in_group foreign key (child_id, group_id)
    references profiles (id, group_id)
);

create index idx_tasks_child_status on tasks (child_id, status);
create index idx_tasks_group_status on tasks (group_id, status);

-- A child's request to be credited for completing a task. Since each task has
-- exactly one assigned child, at most one pending request can exist per task.
create table task_requests (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references tasks (id) on delete cascade,
  child_id     uuid not null references profiles (id),
  status       request_status not null default 'pending',
  requested_at timestamptz not null default now(),
  decided_by   uuid references profiles (id),
  decided_at   timestamptz
);

create unique index idx_task_requests_one_pending_per_task
  on task_requests (task_id)
  where status = 'pending';
