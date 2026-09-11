-- 0017 で入れた通知ヘルパーの穴を塞ぐ。
--
-- notify_child / notify_group_parents は security definer なので、public スキーマに
-- 置いたままだと PostgREST が `/rest/v1/rpc/notify_child` として公開してしまい、
-- ログインした誰でも(anon すら)任意の相手に任意の通知を作れてしまう。
-- 呼ぶのはトリガーと承認/却下RPCの中だけなので、API ロールからは実行権を剥がす。
--
-- 他の security definer 関数(approve_task_request など)は、クライアントから
-- 呼ばれるのが前提で、関数の中で本人・グループ・状態を検証しているため対象外。
-- `public` を外すのを忘れないこと。関数の EXECUTE は既定で PUBLIC に付くため、
-- anon / authenticated から revoke しただけでは PUBLIC 経由で実行できてしまう。
revoke execute on function notify_child(uuid, text, jsonb)
  from public, anon, authenticated;
revoke execute on function notify_group_parents(uuid, text, uuid, jsonb, text)
  from public, anon, authenticated;
