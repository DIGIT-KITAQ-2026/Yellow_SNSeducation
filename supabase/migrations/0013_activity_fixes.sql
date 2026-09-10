-- 周辺アクティビティ提案機能をアプリ側で実装するにあたっての修正。

-- 1) approve_activity_request の「column reference "points" is ambiguous」修正。
--    関数引数 points と activity_requests.points が同名なため、update の set 句
--    右辺で plpgsql の既定 (variable_conflict = error) が衝突を検出し、初回実行時に
--    必ず失敗していた。引数名は PostgREST の rpc 名前付き呼び出しで使うので変えず、
--    ローカル変数 award に退避して参照する。
--    あわせて、security definer なのに承認者の資格を検証していなかった穴を塞ぐ。
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
  award    int := points;  -- 列名 points との衝突を避けるための別名
begin
  if award is null or award <= 0 then
    raise exception 'points must be positive';
  end if;

  select * into req from activity_requests where id = request_id for update;
  if not found then
    raise exception 'Activity request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Activity request % is not pending', request_id;
  end if;

  select * into child from profiles where id = req.child_id;

  -- 承認できるのは、その子と同じグループの親だけ。
  if not is_parent() or child.group_id is distinct from current_group_id() then
    raise exception 'Not authorized to decide activity request %', request_id;
  end if;

  insert into tasks (group_id, child_id, title, description, points, created_by)
    values (child.group_id, req.child_id, req.title, req.description, award, auth.uid())
    returning id into new_task;

  update activity_requests
    set status = 'approved', points = award, created_task_id = new_task,
        decided_by = auth.uid(), decided_at = now()
    where id = request_id;

  return new_task;
end;
$$;

-- 2) reject 側にも同じ認可ガードを入れる(こちらに points の衝突は無い)。
create or replace function reject_activity_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req   activity_requests%rowtype;
  child profiles%rowtype;
begin
  select * into req from activity_requests where id = request_id for update;
  if not found then
    raise exception 'Activity request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Activity request % is not pending', request_id;
  end if;

  select * into child from profiles where id = req.child_id;
  if not is_parent() or child.group_id is distinct from current_group_id() then
    raise exception 'Not authorized to decide activity request %', request_id;
  end if;

  update activity_requests
    set status = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = request_id;
end;
$$;

-- 3) Edge Function のキャッシュキー用の列。
--    latitude/longitude は「提案された場所」の座標なので、
--    「どの現在地に対する提案か」を別に持たないとキャッシュ判定ができない。
alter table activity_suggestions
  add column origin_latitude  double precision,
  add column origin_longitude double precision;

comment on column activity_suggestions.origin_latitude is
  '提案を生成したときの子どもの現在地(緯度)。同一エリア・短時間の再検索で'
  'Gemini呼び出しを省くためのキャッシュキー';

create index idx_activity_suggestions_child_created
  on activity_suggestions (child_id, created_at desc);

-- 4) 同じ提案への pending 申請は1件まで(task_requests / reward_redemptions と同じ方針)。
--    却下後は再申請できる(rejected は部分indexの対象外)。
create unique index uq_activity_requests_pending
  on activity_requests (child_id, suggestion_id) where status = 'pending';

-- 5) Realtime: 親が「子が申請した」を再起動なしで受け取れるようにする。
--    postgres_changes は RLS の SELECT ポリシー(activity_requests_select)を通った
--    行だけを配信するので、購読側で追加のフィルタは要らない。
alter publication supabase_realtime add table activity_requests;
