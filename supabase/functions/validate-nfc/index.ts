// ============================================================
// Edge Function : validate-nfc
// POST /functions/v1/validate-nfc
//
// Body : {
//   nfc_tag_id : string  — valeur lue sur le tag NFC
//   device_id  : string  — identifiant iPhone (UIDevice.current.identifierForVendor)
// }
//
// Réponse succès :
//   { success: true, attendance_id, signed_at, course_title, slot }
//
// Réponse erreur :
//   { success: false, reason: 'window_closed' | 'not_enrolled' |
//                             'device_mismatch' | 'no_active_session' | ... }
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // ── 1. Parser le body ─────────────────────────────────────
    const { nfc_tag_id, device_id } = await req.json()

    if (!nfc_tag_id || !device_id) {
      return new Response(
        JSON.stringify({ success: false, reason: 'missing_fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── 2. Créer le client Supabase avec le JWT de l'utilisateur ──
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, reason: 'unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    // Supabase Admin pour les opérations privilégiées (record_nfc_attendance)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ── 3. Récupérer l'identité de l'utilisateur connecté ─────
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, reason: 'unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── 4. Vérifier que c'est bien un étudiant ────────────────
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profile?.role !== 'student') {
      return new Response(
        JSON.stringify({ success: false, reason: 'not_a_student' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── 5. Résoudre la session active pour ce tag NFC ─────────
    const { data: sessionData, error: sessionError } = await supabaseAdmin
      .rpc('resolve_session_for_nfc', { p_nfc_tag_id: nfc_tag_id })

    if (sessionError || !sessionData || sessionData.length === 0) {
      return new Response(
        JSON.stringify({ success: false, reason: 'no_active_session' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const session = sessionData[0]

    // ── 6. Vérifier que la fenêtre est ouverte ────────────────
    if (!session.is_window_open) {
      return new Response(
        JSON.stringify({
          success:       false,
          reason:        'window_closed',
          sign_open_at:  session.sign_open_at,
          sign_close_at: session.sign_close_at,
          course_title:  session.course_title,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── 7. Appeler la fonction SQL record_nfc_attendance ──────
    const { data: result, error: recordError } = await supabaseAdmin
      .rpc('record_nfc_attendance', {
        p_session_id: session.session_id,
        p_student_id: user.id,
        p_device_id:  device_id,
      })

    if (recordError) {
      console.error('record_nfc_attendance error:', recordError)
      return new Response(
        JSON.stringify({ success: false, reason: 'internal_error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ── 8. Retourner le résultat enrichi ──────────────────────
    if (result.success) {
      return new Response(
        JSON.stringify({
          success:        true,
          attendance_id:  result.attendance_id,
          signed_at:      result.signed_at,
          course_title:   session.course_title,
          room:           session.room,
          slot:           session.slot,
          teacher_name:   session.teacher_name,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      return new Response(
        JSON.stringify({ success: false, reason: result.reason }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(
      JSON.stringify({ success: false, reason: 'internal_error', detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
