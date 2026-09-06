-- Daily total SNS screen time for a child, synced from their device. Only recent
-- rows are kept (see screen_time_retention_days below); re-syncing the same day
-- upserts in place.
create table screen_time_daily (
  child_id      uuid not null references profiles (id) on delete cascade,
  date          date not null,
  total_minutes int not null check (total_minutes >= 0),
  synced_at     timestamptz not null default now(),
  primary key (child_id, date)
);

-- Per-app breakdown for a given child/day. Cascades from screen_time_daily so
-- retention pruning removes both together.
create table screen_time_apps (
  child_id  uuid not null,
  date      date not null,
  app_id    text not null,
  app_label text not null,
  minutes   int not null check (minutes >= 0),
  primary key (child_id, date, app_id),
  foreign key (child_id, date) references screen_time_daily (child_id, date) on delete cascade
);

-- Single place to change how many days of raw screen time are retained.
create or replace function screen_time_retention_days()
returns int
language sql
immutable
as $$
  select 7
$$;

-- Deletes screen time older than the retention window. screen_time_apps rows
-- cascade automatically. Call this after each sync, or from a daily pg_cron job.
create or replace function purge_old_screen_time()
returns void
language sql
as $$
  delete from screen_time_daily
    where date < current_date - screen_time_retention_days()
$$;

-- The AI-generated daily review: a comment plus the "Dopagaki score" (0-100,
-- higher = more severe SNS dependency), derived from that day's screen time.
-- Kept indefinitely (outside the screen-time retention window) so the score's
-- trend survives even after the raw screen time it was computed from is purged.
create table ai_reviews (
  id             uuid primary key default gen_random_uuid(),
  child_id       uuid not null references profiles (id) on delete cascade,
  date           date not null,
  dopagaki_score int check (dopagaki_score between 0 and 100),
  comment        text not null,
  model          text,
  created_at     timestamptz not null default now(),
  unique (child_id, date)
);
