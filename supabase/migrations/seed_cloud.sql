-- ============================================================
-- EPITA Presence — Seed data (tests / développement)
-- ⚠️  NE PAS exécuter en production
--
-- Crée :
--   - 1 enseignant : prof@epita.fr / password123
--   - 3 étudiants  : alice@epita.fr / bob@epita.fr / carol@epita.fr
--   - 2 cours avec tags NFC
--   - Des séances pour la semaine courante
--   - Des inscriptions
-- ============================================================

-- ── Désactiver temporairement le trigger pour les inserts manuels ──
-- (les profils seront créés manuellement ici)

-- 1. Créer les users dans auth.users via la fonction Supabase Admin
--    (à faire via Dashboard > Authentication > Add user)
--    OU via SQL en insérant dans auth.users directement (local dev)

-- Pour un environnement LOCAL (supabase start), on peut insérer directement.
-- Pour un projet cloud, utilisez le Dashboard ou l'Admin API.

do $$
declare
  v_teacher_id  uuid := gen_random_uuid();
  v_alice_id    uuid := gen_random_uuid();
  v_bob_id      uuid := gen_random_uuid();
  v_carol_id    uuid := gen_random_uuid();
  v_course1_id  uuid := gen_random_uuid();
  v_course2_id  uuid := gen_random_uuid();
  v_today       date := current_date;
begin

  -- ── Insérer dans auth.users (local uniquement) ──────────────
  -- Le mot de passe est haché avec bcrypt : "password123"
  insert into auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    raw_user_meta_data, created_at, updated_at, aud, role
  ) values
  (
    v_teacher_id, '00000000-0000-0000-0000-000000000000',
    'prof@epita.fr',
    crypt('password123', gen_salt('bf')),
    now(),
    jsonb_build_object('full_name', 'M. Lambert', 'role', 'teacher'),
    now(), now(), 'authenticated', 'authenticated'
  ),
  (
    v_alice_id, '00000000-0000-0000-0000-000000000000',
    'alice@epita.fr',
    crypt('password123', gen_salt('bf')),
    now(),
    jsonb_build_object('full_name', 'Alice Dupont', 'role', 'student'),
    now(), now(), 'authenticated', 'authenticated'
  ),
  (
    v_bob_id, '00000000-0000-0000-0000-000000000000',
    'bob@epita.fr',
    crypt('password123', gen_salt('bf')),
    now(),
    jsonb_build_object('full_name', 'Bob Martin', 'role', 'student'),
    now(), now(), 'authenticated', 'authenticated'
  ),
  (
    v_carol_id, '00000000-0000-0000-0000-000000000000',
    'carol@epita.fr',
    crypt('password123', gen_salt('bf')),
    now(),
    jsonb_build_object('full_name', 'Carol Bernard', 'role', 'student'),
    now(), now(), 'authenticated', 'authenticated'
  );

  -- Les profils sont créés automatiquement par le trigger handle_new_user
  -- Mais comme on est en local, on les insère manuellement par sécurité
  insert into public.profiles (id, email, full_name, role) values
  (v_teacher_id, 'prof@epita.fr',   'M. Lambert',    'teacher'),
  (v_alice_id,   'alice@epita.fr',  'Alice Dupont',  'student'),
  (v_bob_id,     'bob@epita.fr',    'Bob Martin',    'student'),
  (v_carol_id,   'carol@epita.fr',  'Carol Bernard', 'student')
  on conflict (id) do nothing;

  -- ── Cours ──────────────────────────────────────────────────
  insert into public.courses (id, title, teacher_id, room, nfc_tag_id) values
  (
    v_course1_id,
    'Développement iOS',
    v_teacher_id,
    'B204',
    'EPITA-B204'   -- valeur encodée sur le tag NFC de la salle B204
  ),
  (
    v_course2_id,
    'Architecture logicielle',
    v_teacher_id,
    'A101',
    'EPITA-A101'
  );

  -- ── Sessions : semaine courante ─────────────────────────────
  -- Dév. iOS : Lundi et Mercredi matin
  insert into public.sessions (course_id, session_date, slot, start_time, end_time) values
  (v_course1_id, v_today,                      'morning',   '09:00', '12:00'),
  (v_course1_id, v_today + interval '2 days',  'morning',   '09:00', '12:00'),
  (v_course1_id, v_today + interval '7 days',  'morning',   '09:00', '12:00'),
  (v_course1_id, v_today - interval '7 days',  'morning',   '09:00', '12:00'),
  -- Architecture : Mardi après-midi et Jeudi après-midi
  (v_course2_id, v_today + interval '1 day',   'afternoon', '14:00', '17:00'),
  (v_course2_id, v_today + interval '3 days',  'afternoon', '14:00', '17:00'),
  (v_course2_id, v_today - interval '6 days',  'afternoon', '14:00', '17:00');

  -- ── Inscriptions ───────────────────────────────────────────
  -- Tous les étudiants dans les 2 cours
  insert into public.enrollments (course_id, student_id) values
  (v_course1_id, v_alice_id),
  (v_course1_id, v_bob_id),
  (v_course1_id, v_carol_id),
  (v_course2_id, v_alice_id),
  (v_course2_id, v_bob_id),
  (v_course2_id, v_carol_id);

  -- ── Présences historiques (séance de la semaine passée) ────
  -- Alice : présente aux deux
  -- Bob : présent iOS, absent Architecture
  -- Carol : partie tôt iOS, présente Architecture
  insert into public.attendances
    (session_id, student_id, status, marked_by, signed_at)
  select
    s.id,
    v_alice_id,
    'present',
    'student_nfc',
    (s.session_date + s.start_time + interval '5 minutes')::timestamptz
  from public.sessions s
  where s.session_date < v_today
  on conflict do nothing;

  insert into public.attendances
    (session_id, student_id, status, marked_by, signed_at)
  select
    s.id,
    v_bob_id,
    case when s.course_id = v_course1_id then 'present' else 'absent' end,
    case when s.course_id = v_course1_id then 'student_nfc' else 'teacher_manual' end,
    case when s.course_id = v_course1_id
      then (s.session_date + s.start_time + interval '8 minutes')::timestamptz
      else null
    end
  from public.sessions s
  where s.session_date < v_today
  on conflict do nothing;

  insert into public.attendances
    (session_id, student_id, status, marked_by, signed_at, left_at)
  select
    s.id,
    v_carol_id,
    case when s.course_id = v_course1_id then 'early_leave' else 'present' end,
    'teacher_manual',
    (s.session_date + s.start_time + interval '3 minutes')::timestamptz,
    case when s.course_id = v_course1_id
      then (s.session_date + '10:30:00'::time)::timestamptz
      else null
    end
  from public.sessions s
  where s.session_date < v_today
  on conflict do nothing;

  raise notice '✅ Seed terminé. Comptes créés :';
  raise notice '   prof@epita.fr   / password123  (teacher)';
  raise notice '   alice@epita.fr  / password123  (student)';
  raise notice '   bob@epita.fr    / password123  (student)';
  raise notice '   carol@epita.fr  / password123  (student)';
  raise notice '   Tags NFC : EPITA-B204 (salle B204) | EPITA-A101 (salle A101)';

end;
$$;
