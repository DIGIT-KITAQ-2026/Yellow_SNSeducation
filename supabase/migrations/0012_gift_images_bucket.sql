-- プレゼント画像用の非公開バケット。パス規約は `<group_id>/<uuid>.<ext>` とし、
-- 先頭フォルダ名(= group_id)で読み書きをグループ内に限定する。
insert into storage.buckets (id, name, public)
  values ('gift-images', 'gift-images', false)
  on conflict (id) do nothing;

create policy gift_images_select on storage.objects
  for select using (
    bucket_id = 'gift-images'
    and (storage.foldername(name))[1] = current_group_id()::text
  );

create policy gift_images_insert on storage.objects
  for insert with check (
    bucket_id = 'gift-images'
    and (storage.foldername(name))[1] = current_group_id()::text
    and is_parent()
  );

create policy gift_images_update on storage.objects
  for update using (
    bucket_id = 'gift-images'
    and (storage.foldername(name))[1] = current_group_id()::text
    and is_parent()
  );

create policy gift_images_delete on storage.objects
  for delete using (
    bucket_id = 'gift-images'
    and (storage.foldername(name))[1] = current_group_id()::text
    and is_parent()
  );
