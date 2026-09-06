-- Enums shared across the schema.
create type user_role        as enum ('parent', 'child');
create type request_status   as enum ('pending', 'approved', 'rejected');
create type task_status      as enum ('open', 'completed');
create type point_entry_type as enum ('task_reward', 'reward_redemption', 'adjustment');

-- A group links exactly one parent-created household to its children.
create table groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  group_code  char(4) not null unique,
  created_by  uuid not null references auth.users (id),
  created_at  timestamptz not null default now()
);

-- Generates a random 4-digit code, retrying on collision.
-- Only 10,000 possible codes exist, so callers must not assume this never fails.
create or replace function generate_group_code()
returns char(4)
language plpgsql
as $$
declare
  candidate char(4);
  attempt   int := 0;
begin
  loop
    attempt := attempt + 1;
    candidate := lpad((floor(random() * 10000))::int::text, 4, '0');

    if not exists (select 1 from groups where group_code = candidate) then
      return candidate;
    end if;

    if attempt >= 10 then
      raise exception 'Could not generate a unique group code after % attempts', attempt;
    end if;
  end loop;
end;
$$;
