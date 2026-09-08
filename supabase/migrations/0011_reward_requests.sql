-- プレゼントを子どもごとにする(設計方針2の変更: グループ共有 → 子どもごと)。
-- rewards / reward_redemptions とも現在0行のため、後方互換を気にせず not null で追加できる。
alter table rewards add column child_id uuid references profiles (id) on delete cascade;
update rewards set child_id = created_by where child_id is null;
alter table rewards alter column child_id set not null;
alter table rewards add constraint rewards_child_in_group
  foreign key (child_id, group_id) references profiles (id, group_id);

-- 「常に表示」: true なら承認してもプレゼントは消えず、繰り返し交換できる。
-- 親の編集モード中のみ切り替え可(UI側で制御)。
alter table rewards add column always_visible boolean not null default false;

create index idx_rewards_child on rewards (child_id) where is_active;

-- reward_redemptions を交換申請テーブルとして兼用する。
-- pending: 子が申請した直後 / approved・rejected: 親が判断した後の記録
-- (always_visible = false で承認された場合はこの行ごと削除されるため、
--  実際に approved のまま残るのは always_visible = true のケースのみ)。
alter table reward_redemptions
  add column status      request_status not null default 'pending',
  add column decided_by  uuid references profiles (id),
  add column decided_at  timestamptz;

-- task_requests と同じく、同じプレゼントへの pending 申請は1件まで
-- (却下された後は再申請できる = rejected は対象外)。
create unique index uq_reward_redemptions_pending
  on reward_redemptions (reward_id) where status = 'pending';

-- redeem_reward は承認を経ずにポイントを引けてしまう抜け穴なので削除し、
-- request_reward / approve_reward_request / reject_reward_request に置き換える。
drop function if exists redeem_reward(uuid);

-- 子どもがプレゼントの交換を申請する。残高チェックはここでも行うが、
-- 実際にポイントが引かれるのは approve_reward_request の時点。
create or replace function request_reward(reward_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  rwd     rewards%rowtype;
  balance int;
  redemption uuid;
begin
  select * into rwd from rewards
    where id = reward_id and is_active and child_id = auth.uid();
  if rwd is null then
    raise exception 'Reward % not found or inactive', reward_id;
  end if;

  select point_balance into balance from profiles where id = auth.uid() for update;
  if balance < rwd.cost_points then
    raise exception 'Insufficient points: have %, need %', balance, rwd.cost_points;
  end if;

  insert into reward_redemptions (reward_id, child_id, reward_name, cost_points)
    values (rwd.id, auth.uid(), rwd.name, rwd.cost_points)
    returning id into redemption;

  return redemption;
end;
$$;

-- 親が交換申請を承認する。残高を再チェックしたうえで台帳に記録し、
-- always_visible に応じてプレゼント/申請行のどちらを消すか分岐する。
create or replace function approve_reward_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req     reward_redemptions%rowtype;
  rwd     rewards%rowtype;
  balance int;
begin
  select * into req from reward_redemptions where id = request_id for update;
  if req is null then
    raise exception 'Reward request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Reward request % is not pending', request_id;
  end if;

  select * into rwd from rewards where id = req.reward_id for update;
  if rwd is null then
    raise exception 'Reward % not found', req.reward_id;
  end if;

  select point_balance into balance from profiles where id = req.child_id for update;
  if balance < req.cost_points then
    raise exception 'Insufficient points: have %, need %', balance, req.cost_points;
  end if;

  insert into point_entries (child_id, amount, entry_type, description, redemption_id)
    values (req.child_id, -req.cost_points, 'reward_redemption', req.reward_name, request_id);

  perform set_config('app.allow_point_balance_change', 'on', true);
  update profiles set point_balance = point_balance - req.cost_points where id = req.child_id;

  if rwd.always_visible then
    -- プレゼントは残す。申請行だけ消す(point_entries.redemption_id は
    -- on delete set null で連動するので台帳の記録は残る)。
    delete from reward_redemptions where id = request_id;
  else
    -- point_entries insert より後に実行すること。先に rewards を消すと
    -- reward_redemptions.reward_id が set null になった後の cascade 順序に
    -- 依存させないため。
    update reward_redemptions
      set status = 'approved', decided_by = auth.uid(), decided_at = now()
      where id = request_id;
    delete from rewards where id = rwd.id;
  end if;
end;
$$;

create or replace function reject_reward_request(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req reward_redemptions%rowtype;
begin
  select * into req from reward_redemptions where id = request_id for update;
  if req is null then
    raise exception 'Reward request % not found', request_id;
  end if;
  if req.status <> 'pending' then
    raise exception 'Reward request % is not pending', request_id;
  end if;

  update reward_redemptions
    set status = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = request_id;
end;
$$;
