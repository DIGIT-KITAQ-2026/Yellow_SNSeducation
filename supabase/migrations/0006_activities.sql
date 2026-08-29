-- Stretch goal feature: AI-suggested nearby activities as an alternative to SNS time.
create table activity_suggestions (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups (id) on delete cascade,
  child_id    uuid not null references profiles (id) on delete cascade,
  title       text not null,
  description text,
  place_name  text,
  latitude    double precision,
  longitude   double precision,
  source_url  text,
  created_at  timestamptz not null default now(),

  constraint activity_suggestions_child_in_group foreign key (child_id, group_id)
    references profiles (id, group_id)
);

-- A child's request to turn a suggestion into a rewarded task. The parent sets the
-- point value on approval, which creates the corresponding row in tasks.
create table activity_requests (
  id              uuid primary key default gen_random_uuid(),
  suggestion_id   uuid references activity_suggestions (id) on delete set null,
  child_id        uuid not null references profiles (id),
  title           text not null,
  description     text,
  status          request_status not null default 'pending',
  points          int check (points > 0),
  created_task_id uuid references tasks (id) on delete set null,
  decided_by      uuid references profiles (id),
  decided_at      timestamptz,
  requested_at    timestamptz not null default now()
);

-- Approves an activity request: creates the task for the requesting child at the
-- given point value, and links it back via created_task_id.
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
begin
  if points <= 0 then
    raise exception 'points must be positive';
  end if;

  select * into req from activity_requests where id = request_id for update;
  if req is null then
    raise exception 'Activity request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Activity request % is not pending', request_id;
  end if;

  select * into child from profiles where id = req.child_id;

  insert into tasks (group_id, child_id, title, description, points, created_by)
    values (child.group_id, req.child_id, req.title, req.description, points, auth.uid())
    returning id into new_task;

  update activity_requests
    set status = 'approved', points = points, created_task_id = new_task,
        decided_by = auth.uid(), decided_at = now()
    where id = request_id;

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
  req activity_requests%rowtype;
begin
  select * into req from activity_requests where id = request_id for update;
  if req is null then
    raise exception 'Activity request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Activity request % is not pending', request_id;
  end if;

  update activity_requests
    set status = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = request_id;
end;
$$;
