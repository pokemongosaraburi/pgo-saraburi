-- ============================================================
-- SECURITY PATCH v1 — PGO Saraburi
-- รันใน Supabase Dashboard → SQL Editor
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- STEP 1: Trigger — อัปเดต events/points อัตโนมัติเมื่อเช็คอิน
--          (แทนการให้ client เรียก UPDATE members โดยตรง)
-- ─────────────────────────────────────────────────────────────
create or replace function public.fn_update_member_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update members
  set events     = events + 1,
      points     = points + coalesce(NEW.pts_earned, 20),
      updated_at = now()
  where id = NEW.member_id;
  return NEW;
end $$;

drop trigger if exists trg_checkin_stats on public.checkins;
create trigger trg_checkin_stats
  after insert on public.checkins
  for each row execute function public.fn_update_member_stats();


-- ─────────────────────────────────────────────────────────────
-- STEP 2: RPC — login_member
--          ตรวจ gameid + phone → อัปเดต fp → คืน member (ไม่มี phone)
-- ─────────────────────────────────────────────────────────────
create or replace function public.login_member(
  p_gameid text,
  p_phone  text,
  p_fp     text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_m members%rowtype;
begin
  select * into v_m
  from members
  where lower(trim(gameid)) = lower(trim(p_gameid));

  if not found
     or regexp_replace(coalesce(v_m.phone,''), '\D', '', 'g')
        != regexp_replace(p_phone, '\D', '', 'g')
  then
    perform pg_sleep(0.3);  -- หน่วงกัน brute-force
    raise exception using errcode = 'P0001', message = 'LOGIN_FAILED';
  end if;

  -- ผูก fingerprint ใหม่
  update members set fp = p_fp, updated_at = now() where id = v_m.id;

  return jsonb_build_object(
    'id',      v_m.id,
    'name',    v_m.name,
    'gameid',  v_m.gameid,
    'team',    v_m.team,
    'events',  v_m.events,
    'points',  v_m.points,
    'fp',      p_fp
  );
end $$;

grant execute on function public.login_member(text, text, text) to anon;


-- ─────────────────────────────────────────────────────────────
-- STEP 3: RPC — register_member
--          ตรวจ gameid ซ้ำ → upsert by fp → คืน member
-- ─────────────────────────────────────────────────────────────
create or replace function public.register_member(
  p_name   text,
  p_gameid text,
  p_phone  text,
  p_team   text,
  p_fp     text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing members%rowtype;
  v_m        members%rowtype;
begin
  -- ตรวจ gameid ว่าถูกใช้โดย fp อื่นหรือเปล่า
  select * into v_existing
  from members
  where lower(trim(gameid)) = lower(trim(p_gameid));

  if found and v_existing.fp != p_fp then
    raise exception using errcode = 'P0001', message = 'GAMEID_TAKEN';
  end if;

  -- Upsert by fingerprint
  insert into members (name, gameid, phone, team, fp, events, points, registered_at, updated_at)
  values (p_name, p_gameid, p_phone, p_team, p_fp, 0, 0, now(), now())
  on conflict (fp) do update set
    name       = excluded.name,
    gameid     = excluded.gameid,
    phone      = excluded.phone,
    team       = excluded.team,
    updated_at = now()
  returning * into v_m;

  return jsonb_build_object(
    'id',      v_m.id,
    'name',    v_m.name,
    'gameid',  v_m.gameid,
    'team',    v_m.team,
    'events',  v_m.events,
    'points',  v_m.points,
    'fp',      v_m.fp
  );
end $$;

grant execute on function public.register_member(text, text, text, text, text) to anon;


-- ─────────────────────────────────────────────────────────────
-- STEP 4: RPC — get_member_by_fp
--          ดึงข้อมูล member + rank โดยไม่เปิด SELECT ตาราง
-- ─────────────────────────────────────────────────────────────
create or replace function public.get_member_by_fp(p_fp text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_m    members%rowtype;
  v_rank integer;
begin
  select * into v_m from members where fp = p_fp;
  if not found then return null; end if;

  select count(*) + 1 into v_rank
  from members where points > v_m.points;

  return jsonb_build_object(
    'id',      v_m.id,
    'name',    v_m.name,
    'gameid',  v_m.gameid,
    'team',    v_m.team,
    'events',  v_m.events,
    'points',  v_m.points,
    'fp',      v_m.fp,
    '_rank',   v_rank
  );
end $$;

grant execute on function public.get_member_by_fp(text) to anon;


-- ─────────────────────────────────────────────────────────────
-- STEP 5: ปิด policy ที่อันตราย
--          (RPC functions ทำงานเป็น security definer จึงไม่ต้องใช้ policy)
-- ─────────────────────────────────────────────────────────────
drop policy if exists members_select on public.members;
drop policy if exists members_update on public.members;
drop policy if exists members_insert on public.members;

-- ตรวจสอบ: ควรเหลือแค่ team_manage และ team_select บน team_members
-- และ draw_manage, draw_select, activities_manage, activities_select,
-- checkins_insert, checkins_select, checkins_delete ตามเดิม


-- ─────────────────────────────────────────────────────────────
-- STEP 6: ตรวจสอบผลลัพธ์ — run แยกเพื่อยืนยัน
-- ─────────────────────────────────────────────────────────────
-- select schemaname, tablename, policyname, roles, cmd
-- from pg_policies where schemaname = 'public' order by tablename;
