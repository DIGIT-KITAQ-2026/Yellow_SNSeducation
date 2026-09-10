-- screen_time_daily / screen_time_apps は 0007_rls.sql で insert/update/select の
-- ポリシーを定義したが、delete が無かった。実機のスクリーンタイム同期
-- (SupabaseScreenTimeService.syncDays)では、その日にもう使われていない
-- アプリの行を削除してから入れ直すため、delete ポリシーが必要。

create policy screen_time_daily_delete on screen_time_daily
  for delete using (child_id = auth.uid());

create policy screen_time_apps_delete on screen_time_apps
  for delete using (child_id = auth.uid());
