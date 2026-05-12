-- ============================================================
-- EPITA Presence — Schema v1
-- Auth : Supabase email+password
-- Roles : student | teacher
-- Attendance : NFC only (student) + manual override (teacher)
-- Signature : validated locally (1000px min), NOT stored
-- ============================================================

-- ── Extensions ───────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ── 1. PROFILES ──────────────────────────────────────────────
-- Extends auth.users (1-to-1)
create table public.profiles (
  id          uuid        primary key references auth.users(id) on delete cascade,
  email       text        not null unique,
  full_name   text        not null,
  role        text        not null check (role in ('student', 'teacher')),
  -- device_id : identifiant iPhone enregistré au 1er login (device binding)
  device_id   text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Profils utilisateurs (étend auth.users). Chaque user a un rôle student|teacher.';

-- ── 2. COURSES ───────────────────────────────────────────────
-- Définition d'un cours récurrent (pas d'occurrence de date)
create table public.courses (
  id          uuid        primary key default gen_random_uuid(),
  title       text        not null,
  teacher_id  uuid        not null references public.profiles(id) on delete restrict,
  room        text        not null,            -- ex: "B204"
  -- nfc_tag_id : valeur lue sur le tag NFC physique collé dans la salle
  -- Format libre : ex "EPITA-B204", "room-a101"
  nfc_tag_id  text        not null unique,
  created_at  timestamptz not null default now()
);

comment on table public.courses is
  'Définition d un cours. nfc_tag_id est la valeur encodée sur le tag NFC de la salle.';

-- ── 3. SESSIONS ──────────────────────────────────────────────
-- Occurrence concrète d'un cours (date + créneau)
create table public.sessions (
  id            uuid        primary key default gen_random_uuid(),
  course_id     uuid        not null references public.courses(id) on delete cascade,
  session_date  date        not null,
  slot          text        not null check (slot in ('morning', 'afternoon')),
  start_time    time        not null,   -- ex: '09:00'
  end_time      time        not null,   -- ex: '12:00'
  -- Fenêtre pendant laquelle l'émargement NFC est accepté
  -- Par défaut : start_time-5min → start_time+30min (géré via fonction)
  sign_open_at  timestamptz,
  sign_close_at timestamptz,
  created_at    timestamptz not null default now(),
  -- Une session = un cours + une date + un créneau (pas de doublon)
  unique (course_id, session_date, slot)
);

comment on table public.sessions is
  'Occurrence d un cours (séance). sign_open_at/close_at définit la fenêtre NFC.';

-- ── 4. ENROLLMENTS ───────────────────────────────────────────
-- Quels étudiants sont inscrits à quels cours
create table public.enrollments (
  id          uuid primary key default gen_random_uuid(),
  course_id   uuid not null references public.courses(id) on delete cascade,
  student_id  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (course_id, student_id)
);

comment on table public.enrollments is
  'Inscriptions : quel étudiant est dans quel cours.';

-- ── 5. ATTENDANCES ───────────────────────────────────────────
-- Enregistrement de présence pour une séance
create table public.attendances (
  id            uuid        primary key default gen_random_uuid(),
  session_id    uuid        not null references public.sessions(id) on delete cascade,
  student_id    uuid        not null references public.profiles(id) on delete cascade,

  -- Statuts possibles :
  --   pending      → séance pas encore passée / pas encore émargé
  --   present      → émargé (NFC ou manuel enseignant)
  --   absent       → absent (calculé ou marqué manuellement)
  --   early_leave  → parti avant la fin (marqué par l'enseignant)
  status        text        not null default 'pending'
                            check (status in ('pending','present','absent','early_leave')),

  -- Source de la mise à jour
  marked_by     text        check (marked_by in ('student_nfc', 'teacher_manual')),

  -- Horodatage de l'émargement effectif
  signed_at     timestamptz,

  -- device_id capturé au moment du scan NFC (anti-fraude)
  device_id     text,

  -- Heure de départ anticipé (si early_leave)
  left_at       timestamptz,

  -- Note optionnelle de l'enseignant
  teacher_note  text,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  unique (session_id, student_id)
);

comment on table public.attendances is
  'Enregistrement de présence. Une ligne par (session, étudiant).';

-- ── 6. NFC TOKENS ────────────────────────────────────────────
-- Tokens à vie courte générés par le backend au moment du scan NFC
-- Le tag NFC contient l'URL : https://<app>/nfc?tag=<nfc_tag_id>
-- L'app appelle la Edge Function validate-nfc qui vérifie et crée/update l'attendance
create table public.nfc_scan_log (
  id          uuid        primary key default gen_random_uuid(),
  session_id  uuid        not null references public.sessions(id) on delete cascade,
  student_id  uuid        not null references public.profiles(id) on delete cascade,
  device_id   text,
  scanned_at  timestamptz not null default now(),
  -- success : false si hors fenêtre, mauvais device, etc.
  success     boolean     not null default false,
  fail_reason text        -- ex: 'window_closed', 'device_mismatch', 'not_enrolled'
);

comment on table public.nfc_scan_log is
  'Journal de tous les scans NFC (succès et échecs). Traçabilité anti-fraude.';

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Met à jour updated_at automatiquement
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger trg_attendances_updated_at
  before update on public.attendances
  for each row execute function public.set_updated_at();

-- ============================================================
-- FONCTION : auto-créer le profil après signup
-- Appelée par un trigger Supabase Auth (via Dashboard)
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'student')
  );
  return new;
end;
$$;

-- Trigger sur auth.users → crée le profil automatiquement
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- FONCTION : ouvrir la fenêtre d'émargement NFC
-- Appelée manuellement ou depuis l'app enseignant
-- ============================================================
create or replace function public.open_sign_window(
  p_session_id  uuid,
  p_duration_minutes int default 30
)
returns void language plpgsql security definer as $$
begin
  update public.sessions
  set
    sign_open_at  = now(),
    sign_close_at = now() + (p_duration_minutes || ' minutes')::interval
  where id = p_session_id;
end;
$$;

-- ============================================================
-- FONCTION : résoudre la session active pour un tag NFC
-- Retourne la session en cours ou imminente (±5 min) pour ce tag
-- ============================================================
create or replace function public.resolve_session_for_nfc(
  p_nfc_tag_id text
)
returns table (
  session_id    uuid,
  course_id     uuid,
  course_title  text,
  room          text,
  teacher_name  text,
  session_date  date,
  slot          text,
  start_time    time,
  end_time      time,
  sign_open_at  timestamptz,
  sign_close_at timestamptz,
  is_window_open boolean
)
language sql stable security definer as $$
  select
    s.id                                              as session_id,
    c.id                                              as course_id,
    c.title                                           as course_title,
    c.room,
    p.full_name                                       as teacher_name,
    s.session_date,
    s.slot,
    s.start_time,
    s.end_time,
    s.sign_open_at,
    s.sign_close_at,
    (
      s.sign_open_at is not null
      and now() >= s.sign_open_at
      and now() <= s.sign_close_at
    )                                                 as is_window_open
  from public.sessions s
  join public.courses   c on c.id = s.course_id
  join public.profiles  p on p.id = c.teacher_id
  where
    c.nfc_tag_id = p_nfc_tag_id
    and s.session_date = current_date
    -- Séances du jour, dans une plage ±2h autour de maintenant
    and (s.start_time - interval '30 minutes') <= current_time
    and (s.end_time   + interval '30 minutes') >= current_time
  order by s.start_time
  limit 1;
$$;

-- ============================================================
-- FONCTION : enregistrer une présence NFC
-- Appelée par la Edge Function validate-nfc
-- ============================================================
create or replace function public.record_nfc_attendance(
  p_session_id  uuid,
  p_student_id  uuid,
  p_device_id   text
)
returns jsonb language plpgsql security definer as $$
declare
  v_session     record;
  v_enrollment  record;
  v_attendance  record;
  v_profile     record;
  v_result      jsonb;
begin
  -- 1. Vérifier que la session existe et la fenêtre est ouverte
  select * into v_session from public.sessions where id = p_session_id;
  if not found then
    insert into public.nfc_scan_log (session_id, student_id, device_id, success, fail_reason)
    values (p_session_id, p_student_id, p_device_id, false, 'session_not_found');
    return jsonb_build_object('success', false, 'reason', 'session_not_found');
  end if;

  if v_session.sign_open_at is null
     or now() < v_session.sign_open_at
     or now() > v_session.sign_close_at then
    insert into public.nfc_scan_log (session_id, student_id, device_id, success, fail_reason)
    values (p_session_id, p_student_id, p_device_id, false, 'window_closed');
    return jsonb_build_object('success', false, 'reason', 'window_closed');
  end if;

  -- 2. Vérifier que l'étudiant est inscrit au cours
  select e.* into v_enrollment
  from public.enrollments e
  join public.sessions s on s.course_id = e.course_id
  where s.id = p_session_id and e.student_id = p_student_id;

  if not found then
    insert into public.nfc_scan_log (session_id, student_id, device_id, success, fail_reason)
    values (p_session_id, p_student_id, p_device_id, false, 'not_enrolled');
    return jsonb_build_object('success', false, 'reason', 'not_enrolled');
  end if;

  -- 3. Vérifier le device binding
  select * into v_profile from public.profiles where id = p_student_id;
  if v_profile.device_id is not null and v_profile.device_id != p_device_id then
    insert into public.nfc_scan_log (session_id, student_id, device_id, success, fail_reason)
    values (p_session_id, p_student_id, p_device_id, false, 'device_mismatch');
    return jsonb_build_object('success', false, 'reason', 'device_mismatch');
  end if;

  -- 4. Enregistrer le device_id si premier login
  if v_profile.device_id is null then
    update public.profiles set device_id = p_device_id where id = p_student_id;
  end if;

  -- 5. Créer ou mettre à jour l'attendance
  insert into public.attendances (session_id, student_id, status, marked_by, signed_at, device_id)
  values (p_session_id, p_student_id, 'present', 'student_nfc', now(), p_device_id)
  on conflict (session_id, student_id)
  do update set
    status    = 'present',
    marked_by = 'student_nfc',
    signed_at = now(),
    device_id = p_device_id,
    updated_at = now()
  returning * into v_attendance;

  -- 6. Logger le scan
  insert into public.nfc_scan_log (session_id, student_id, device_id, success)
  values (p_session_id, p_student_id, p_device_id, true);

  return jsonb_build_object(
    'success',     true,
    'attendance_id', v_attendance.id,
    'signed_at',   v_attendance.signed_at
  );
end;
$$;
