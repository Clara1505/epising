-- ============================================================
-- EPITA Presence — Row Level Security (RLS)
-- Principe : chaque utilisateur ne voit que ce qui le concerne
-- ============================================================

-- ── Activer RLS sur toutes les tables ───────────────────────
alter table public.profiles     enable row level security;
alter table public.courses      enable row level security;
alter table public.sessions     enable row level security;
alter table public.enrollments  enable row level security;
alter table public.attendances  enable row level security;
alter table public.nfc_scan_log enable row level security;

-- ── Helper : récupère le rôle du user connecté ──────────────
create or replace function public.my_role()
returns text language sql stable security definer as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ============================================================
-- PROFILES
-- ============================================================

-- Tout le monde peut lire son propre profil
create policy "profiles_select_own"
  on public.profiles for select
  using (id = auth.uid());

-- Un enseignant peut lire les profils de ses étudiants
create policy "profiles_select_teacher_sees_students"
  on public.profiles for select
  using (
    public.my_role() = 'teacher'
    and role = 'student'
  );

-- Chacun peut mettre à jour son propre profil (device_id, full_name)
create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- ============================================================
-- COURSES
-- ============================================================

-- Un enseignant voit ses propres cours
create policy "courses_select_teacher"
  on public.courses for select
  using (
    public.my_role() = 'teacher'
    and teacher_id = auth.uid()
  );

-- Un étudiant voit les cours auxquels il est inscrit
create policy "courses_select_student"
  on public.courses for select
  using (
    public.my_role() = 'student'
    and exists (
      select 1 from public.enrollments
      where course_id = courses.id
      and student_id = auth.uid()
    )
  );

-- Un enseignant peut créer des cours (le sien uniquement)
create policy "courses_insert_teacher"
  on public.courses for insert
  with check (
    public.my_role() = 'teacher'
    and teacher_id = auth.uid()
  );

-- Un enseignant peut modifier ses propres cours
create policy "courses_update_teacher"
  on public.courses for update
  using (
    public.my_role() = 'teacher'
    and teacher_id = auth.uid()
  );

-- ============================================================
-- SESSIONS
-- ============================================================

-- Un enseignant voit les séances de ses cours
create policy "sessions_select_teacher"
  on public.sessions for select
  using (
    public.my_role() = 'teacher'
    and exists (
      select 1 from public.courses
      where id = sessions.course_id
      and teacher_id = auth.uid()
    )
  );

-- Un étudiant voit les séances des cours auxquels il est inscrit
create policy "sessions_select_student"
  on public.sessions for select
  using (
    public.my_role() = 'student'
    and exists (
      select 1 from public.enrollments
      where course_id = sessions.course_id
      and student_id = auth.uid()
    )
  );

-- Un enseignant peut créer/modifier des séances pour ses cours
create policy "sessions_insert_teacher"
  on public.sessions for insert
  with check (
    public.my_role() = 'teacher'
    and exists (
      select 1 from public.courses
      where id = sessions.course_id
      and teacher_id = auth.uid()
    )
  );

create policy "sessions_update_teacher"
  on public.sessions for update
  using (
    public.my_role() = 'teacher'
    and exists (
      select 1 from public.courses
      where id = sessions.course_id
      and teacher_id = auth.uid()
    )
  );

-- ============================================================
-- ENROLLMENTS
-- ============================================================

-- Un étudiant voit ses propres inscriptions
create policy "enrollments_select_student"
  on public.enrollments for select
  using (
    public.my_role() = 'student'
    and student_id = auth.uid()
  );

-- Un enseignant voit les inscriptions de ses cours
create policy "enrollments_select_teacher"
  on public.enrollments for select
  using (
    public.my_role() = 'teacher'
    and exists (
      select 1 from public.courses
      where id = enrollments.course_id
      and teacher_id = auth.uid()
    )
  );

-- Un enseignant peut inscrire des étudiants à ses cours
create policy "enrollments_insert_teacher"
  on public.enrollments for insert
  with check (
    public.my_role() = 'teacher'
    and exists (
      select 1 from public.courses
      where id = enrollments.course_id
      and teacher_id = auth.uid()
    )
  );

-- ============================================================
-- ATTENDANCES
-- ============================================================

-- Un étudiant voit ses propres présences
create policy "attendances_select_student"
  on public.attendances for select
  using (
    public.my_role() = 'student'
    and student_id = auth.uid()
  );

-- Un enseignant voit toutes les présences de ses séances
create policy "attendances_select_teacher"
  on public.attendances for select
  using (
    public.my_role() = 'teacher'
    and exists (
      select 1
      from public.sessions s
      join public.courses   c on c.id = s.course_id
      where s.id = attendances.session_id
      and c.teacher_id = auth.uid()
    )
  );

-- L'enseignant peut créer/modifier les présences de ses séances (appel manuel)
create policy "attendances_insert_teacher"
  on public.attendances for insert
  with check (
    public.my_role() = 'teacher'
    and exists (
      select 1
      from public.sessions s
      join public.courses   c on c.id = s.course_id
      where s.id = attendances.session_id
      and c.teacher_id = auth.uid()
    )
  );

create policy "attendances_update_teacher"
  on public.attendances for update
  using (
    public.my_role() = 'teacher'
    and exists (
      select 1
      from public.sessions s
      join public.courses   c on c.id = s.course_id
      where s.id = attendances.session_id
      and c.teacher_id = auth.uid()
    )
  );

-- NOTE : les étudiants ne peuvent pas écrire directement dans attendances
-- L'émargement NFC passe par la Edge Function (security definer)

-- ============================================================
-- NFC SCAN LOG
-- ============================================================

-- Un étudiant voit ses propres logs
create policy "nfc_log_select_student"
  on public.nfc_scan_log for select
  using (student_id = auth.uid());

-- Un enseignant voit les logs de ses séances
create policy "nfc_log_select_teacher"
  on public.nfc_scan_log for select
  using (
    public.my_role() = 'teacher'
    and exists (
      select 1
      from public.sessions s
      join public.courses   c on c.id = s.course_id
      where s.id = nfc_scan_log.session_id
      and c.teacher_id = auth.uid()
    )
  );
