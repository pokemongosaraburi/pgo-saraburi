-- ============================================================
-- PGO Saraburi Activity System — Supabase Setup
-- วิธีใช้: เปิด Supabase Dashboard → SQL Editor → วาง SQL นี้ → Run
-- ============================================================

-- ===== TABLES =====

CREATE TABLE IF NOT EXISTS members (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name        TEXT NOT NULL,
  gameid      TEXT NOT NULL,
  phone       TEXT DEFAULT '',
  team        TEXT NOT NULL CHECK (team IN ('mystic','valor','instinct')),
  fp          TEXT NOT NULL UNIQUE,
  events      INTEGER DEFAULT 0,
  points      INTEGER DEFAULT 0,
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS activities (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name            TEXT NOT NULL,
  type            TEXT NOT NULL DEFAULT 'draw' CHECK (type IN ('draw','points','pvp','checkin')),
  lat             DOUBLE PRECISION NOT NULL DEFAULT 14.5289,
  lng             DOUBLE PRECISION NOT NULL DEFAULT 100.9103,
  radius          INTEGER NOT NULL DEFAULT 100,
  time_label      TEXT DEFAULT '',
  pts_per_checkin INTEGER DEFAULT 20,
  is_open         BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS checkins (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  member_id     UUID REFERENCES members(id) ON DELETE CASCADE,
  activity_id   UUID REFERENCES activities(id) ON DELETE CASCADE,
  member_name   TEXT NOT NULL,
  member_gameid TEXT NOT NULL,
  member_team   TEXT NOT NULL,
  activity_name TEXT NOT NULL,
  distance      INTEGER DEFAULT 0,
  accuracy      INTEGER DEFAULT 0,
  fp            TEXT NOT NULL,
  timestamp     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(fp, activity_id)
);

-- team_members: ทีมงาน Admin (ต่างจาก สมาชิกผู้เล่น)
CREATE TABLE IF NOT EXISTS team_members (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  role       TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('superadmin','admin','staff')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS draw_winners (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  activity_id   UUID REFERENCES activities(id) ON DELETE CASCADE,
  member_id     UUID REFERENCES members(id),
  member_name   TEXT NOT NULL,
  member_gameid TEXT NOT NULL,
  member_team   TEXT NOT NULL,
  prize_rank    INTEGER DEFAULT 1,
  drawn_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===== ROW LEVEL SECURITY =====

ALTER TABLE members       ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities    ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkins      ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE draw_winners  ENABLE ROW LEVEL SECURITY;

-- Members: ทุกคนอ่านได้, insert/update ผ่าน anon key (ไม่ต้อง login)
CREATE POLICY "members_select" ON members FOR SELECT USING (true);
CREATE POLICY "members_insert" ON members FOR INSERT WITH CHECK (true);
CREATE POLICY "members_update" ON members FOR UPDATE USING (true);

-- Activities: ทุกคนอ่านได้, แก้ไขต้อง login (ทีมงาน)
CREATE POLICY "activities_select" ON activities FOR SELECT USING (true);
CREATE POLICY "activities_manage" ON activities FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Checkins: ทุกคนอ่าน/insert ได้ (GPS ตรวจจาก client)
CREATE POLICY "checkins_select" ON checkins FOR SELECT USING (true);
CREATE POLICY "checkins_insert" ON checkins FOR INSERT WITH CHECK (true);
CREATE POLICY "checkins_delete" ON checkins FOR DELETE TO authenticated USING (true);

-- Team members: เฉพาะ authenticated เท่านั้น
CREATE POLICY "team_select" ON team_members FOR SELECT TO authenticated USING (true);
CREATE POLICY "team_manage" ON team_members FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Draw winners: อ่านได้, เขียน/ลบต้อง login
CREATE POLICY "draw_select" ON draw_winners FOR SELECT USING (true);
CREATE POLICY "draw_manage" ON draw_winners FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ===== SAMPLE DEMO ACTIVITY =====
INSERT INTO activities (name, type, lat, lng, radius, time_label, pts_per_checkin, is_open)
VALUES ('Raid Day สระบุรี (Demo)', 'draw', 14.5289, 100.9103, 50000, 'วันนี้ 14:00–17:00 น.', 20, true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- ขั้นตอนหลังรัน SQL นี้แล้ว:
--
-- 1. ไป Supabase Dashboard → Authentication → Users
-- 2. กด "Invite user" ใส่ email ของ Super Admin
-- 3. เปิด admin.html → Login → ไปหน้า "ทีมงาน"
-- 4. เพิ่มตัวเองด้วย role = superadmin
-- 5. เพิ่มทีมงานคนอื่นจาก Dashboard → Invite → แล้วกำหนด role ใน admin.html
-- ============================================================
