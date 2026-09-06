alter table groups enable row level security;
alter table profiles enable row level security;
alter table tasks enable row level security;
alter table task_requests enable row level security;
alter table rewards enable row level security;
alter table reward_redemptions enable row level security;
alter table point_entries enable row level security;
alter table screen_time_daily enable row level security;
alter table screen_time_apps enable row level security;
alter table ai_reviews enable row level security;
alter table activity_suggestions enable row level security;
alter table activity_requests enable row level security;

-- groups: any member (parent or child) can see their own group.
create policy groups_select_own on groups
  for select using (id = current_group_id());

-- profiles: any member can see every profile in their group.
create policy profiles_select_group on profiles
  for select using (group_id = current_group_id());

-- profiles: a user may only edit their own display_name/avatar_url (point_balance
-- changes are blocked by the trigger in 0002_profiles.sql regardless of this policy).
create policy profiles_update_self on profiles
  for update using (id = auth.uid());

-- tasks: parents see every task in their group; a child sees only tasks
-- assigned to them.
create policy tasks_select on tasks
  for select using (
    (is_parent() and group_id = current_group_id())
    or child_id = auth.uid()
  );

-- tasks: only a parent may create/edit/delete tasks in their own group. The
-- tasks_child_in_group FK (0003_tasks.sql) additionally guarantees child_id
-- belongs to that same group.
create policy tasks_insert on tasks
  for insert with check (is_parent() and group_id = current_group_id());

create policy tasks_update on tasks
  for update using (is_parent() and group_id = current_group_id());

create policy tasks_delete on tasks
  for delete using (is_parent() and group_id = current_group_id());

-- task_requests: a child may only see and create requests for themselves,
-- targeting an open task assigned to them. A parent sees requests for tasks
-- in their group. Approval/rejection only happens via the security-definer
-- RPCs, so there is no direct UPDATE policy.
create policy task_requests_select on task_requests
  for select using (
    child_id = auth.uid()
    or exists (
      select 1 from tasks
      where tasks.id = task_requests.task_id
        and is_parent()
        and tasks.group_id = current_group_id()
    )
  );

create policy task_requests_insert on task_requests
  for insert with check (
    child_id = auth.uid()
    and exists (
      select 1 from tasks
      where tasks.id = task_requests.task_id
        and tasks.child_id = auth.uid()
        and tasks.status = 'open'
    )
  );

-- rewards: any member can see their group's rewards; only a parent may
-- create/edit/delete them.
create policy rewards_select on rewards
  for select using (group_id = current_group_id());

create policy rewards_insert on rewards
  for insert with check (is_parent() and group_id = current_group_id());

create policy rewards_update on rewards
  for update using (is_parent() and group_id = current_group_id());

create policy rewards_delete on rewards
  for delete using (is_parent() and group_id = current_group_id());

-- reward_redemptions: any member of the child's group can see the history.
-- All writes go through the redeem_reward RPC, so there is no INSERT policy.
create policy reward_redemptions_select on reward_redemptions
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = reward_redemptions.child_id
        and profiles.group_id = current_group_id()
    )
  );

-- point_entries: any member of the child's group can see the ledger. All
-- writes go through security-definer RPCs, so there is no INSERT policy.
create policy point_entries_select on point_entries
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = point_entries.child_id
        and profiles.group_id = current_group_id()
    )
  );

-- screen_time_daily / screen_time_apps: any member of the group can view; only
-- the child themself can sync (insert/update) their own data.
create policy screen_time_daily_select on screen_time_daily
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = screen_time_daily.child_id
        and profiles.group_id = current_group_id()
    )
  );

create policy screen_time_daily_upsert on screen_time_daily
  for insert with check (child_id = auth.uid());

create policy screen_time_daily_update on screen_time_daily
  for update using (child_id = auth.uid());

create policy screen_time_apps_select on screen_time_apps
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = screen_time_apps.child_id
        and profiles.group_id = current_group_id()
    )
  );

create policy screen_time_apps_upsert on screen_time_apps
  for insert with check (child_id = auth.uid());

create policy screen_time_apps_update on screen_time_apps
  for update using (child_id = auth.uid());

-- ai_reviews: any member of the group can view. Generation happens via a
-- trusted backend (service role), so there is no client INSERT policy.
create policy ai_reviews_select on ai_reviews
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = ai_reviews.child_id
        and profiles.group_id = current_group_id()
    )
  );

-- activity_suggestions: any member of the group can view. Generation happens
-- via a trusted backend (service role), so there is no client INSERT policy.
create policy activity_suggestions_select on activity_suggestions
  for select using (group_id = current_group_id());

-- activity_requests: a child sees/creates only their own; a parent sees all
-- requests in their group. Approval/rejection only via RPC.
create policy activity_requests_select on activity_requests
  for select using (
    child_id = auth.uid()
    or exists (
      select 1 from profiles
      where profiles.id = activity_requests.child_id
        and is_parent()
        and profiles.group_id = current_group_id()
    )
  );

create policy activity_requests_insert on activity_requests
  for insert with check (child_id = auth.uid());
