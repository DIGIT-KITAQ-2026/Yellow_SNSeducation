-- One profile per auth user: either the parent hosting a group, or one of its children.
create table profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  group_id      uuid not null references groups (id),
  role          user_role not null,
  display_name  text not null,
  avatar_url    text,
  point_balance int not null default 0 check (point_balance >= 0),
  created_at    timestamptz not null default now()
);

create index idx_profiles_group_role on profiles (group_id, role);

-- Lets tasks/rewards enforce "this child belongs to this group" via a composite FK
-- instead of a trigger.
alter table profiles add constraint profiles_id_group_id_unique unique (id, group_id);

-- security definer helpers so RLS policies can check the caller's own group/role
-- without recursively re-evaluating the profiles RLS policy on themselves.
create function current_group_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select group_id from profiles where id = auth.uid()
$$;

create function is_parent()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from profiles where id = auth.uid() and role = 'parent'
  )
$$;

-- Creates a brand-new group plus its parent profile, and returns the group's code.
create or replace function create_parent_account(group_name text, parent_display_name text)
returns table (group_id uuid, group_code char(4))
language plpgsql
security definer
set search_path = public
as $$
declare
  new_group_id   uuid;
  new_group_code char(4);
begin
  if exists (select 1 from profiles where id = auth.uid()) then
    raise exception 'This account already has a profile';
  end if;

  new_group_code := generate_group_code();

  insert into groups (name, group_code, created_by)
  values (group_name, new_group_code, auth.uid())
  returning id into new_group_id;

  insert into profiles (id, group_id, role, display_name)
  values (auth.uid(), new_group_id, 'parent', parent_display_name);

  return query select new_group_id, new_group_code;
end;
$$;

-- Joins an existing group as a child using its 4-digit code.
create or replace function join_group(code char(4), child_display_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_group_id uuid;
begin
  if exists (select 1 from profiles where id = auth.uid()) then
    raise exception 'This account already has a profile';
  end if;

  select id into target_group_id from groups where group_code = code;

  if target_group_id is null then
    raise exception 'No group found for code %', code;
  end if;

  insert into profiles (id, group_id, role, display_name)
  values (auth.uid(), target_group_id, 'child', child_display_name);

  return target_group_id;
end;
$$;

-- point_balance must only ever change through the point_entries ledger (see
-- 0004_points_and_rewards.sql), never via a direct client UPDATE.
create or replace function prevent_direct_point_balance_change()
returns trigger
language plpgsql
as $$
begin
  if new.point_balance <> old.point_balance then
    raise exception 'point_balance can only be changed via point_entries';
  end if;
  return new;
end;
$$;

create trigger trg_prevent_direct_point_balance_change
  before update on profiles
  for each row
  execute function prevent_direct_point_balance_change();
