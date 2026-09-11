-- Per-hour breakdown of a child's screen time, synced alongside
-- screen_time_apps so the hourly bar chart works for parents too (they read
-- via SupabaseScreenTimeService, not the device's UsageStatsManager).
-- Same shape/lifecycle as screen_time_apps: cascades from screen_time_daily,
-- so retention pruning (purge_old_screen_time) removes it automatically.
create table screen_time_hourly (
  child_id  uuid not null,
  date      date not null,
  hour      smallint not null check (hour between 0 and 23),
  minutes   smallint not null check (minutes between 0 and 60),
  primary key (child_id, date, hour),
  foreign key (child_id, date) references screen_time_daily (child_id, date) on delete cascade
);

alter table screen_time_hourly enable row level security;

-- Same policy shape as screen_time_apps (0007_rls.sql / 0014_screen_time_delete_policy.sql):
-- any group member can view, only the child themself can sync (insert/update/delete).
create policy screen_time_hourly_select on screen_time_hourly
  for select using (
    exists (
      select 1 from profiles
      where profiles.id = screen_time_hourly.child_id
        and profiles.group_id = current_group_id()
    )
  );

create policy screen_time_hourly_upsert on screen_time_hourly
  for insert with check (child_id = auth.uid());

create policy screen_time_hourly_update on screen_time_hourly
  for update using (child_id = auth.uid());

create policy screen_time_hourly_delete on screen_time_hourly
  for delete using (child_id = auth.uid());
