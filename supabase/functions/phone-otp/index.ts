import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
});

const normalizePhone = (value: string) => {
  const digits = value.replace(/[^0-9]/g, '');
  if (digits.length < 8 || digits.length > 15) throw new Error('رقم الهاتف غير صالح');
  return `+${digits}`;
};

const hashOtp = async (code: string, secret: string) => {
  const data = new TextEncoder().encode(`${secret}:${code}`);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
};

const randomOtp = () => {
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return String(100000 + (bytes[0] % 900000));
};

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

async function sendWhatsAppOtp(phone: string, code: string) {
  const token = Deno.env.get('WHATSAPP_ACCESS_TOKEN');
  const phoneNumberId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID');
  const template = Deno.env.get('WHATSAPP_OTP_TEMPLATE') ?? 'phonek_otp';
  const language = Deno.env.get('WHATSAPP_OTP_LANG') ?? 'en_US';
  const graphVersion = Deno.env.get('WHATSAPP_GRAPH_VERSION') ?? 'v23.0';
  if (!token || !phoneNumberId) throw new Error('WhatsApp integration is not configured');

  const response = await fetch(`https://graph.facebook.com/${graphVersion}/${phoneNumberId}/messages`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to: phone.replace('+', ''),
      type: 'template',
      template: {
        name: template,
        language: { code: language },
        components: [{ type: 'body', parameters: [{ type: 'text', text: code }] }],
      },
    }),
  });

  if (!response.ok) {
    console.error('WhatsApp send failed', await response.text());
    throw new Error('تعذر إرسال رمز التحقق عبر WhatsApp');
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const { action, phone, code } = await req.json();
    const phoneE164 = normalizePhone(String(phone ?? ''));
    const secret = Deno.env.get('PHONE_OTP_SECRET');
    if (!secret) return json({ error: 'OTP service is not configured' }, 503);

    if (action === 'send') {
      const sourceIp = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
      const ipKey = await hashOtp(sourceIp, secret);
      const quota = await admin.rpc('consume_otp_ip_quota', {
        p_key_hash: ipKey,
        p_window_seconds: 3600,
        p_max_requests: 10,
      });
      if (quota.error) throw quota.error;
      if (quota.data !== true) return json({ error: 'تم تجاوز عدد طلبات التحقق. حاول لاحقاً' }, 429);

      const recent = await admin.from('phone_otp_challenges')
        .select('id,last_sent_at')
        .eq('phone_e164', phoneE164)
        .is('consumed_at', null)
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(1);
      if (recent.error) throw recent.error;
      if (recent.data?.[0]) {
        const elapsed = Date.now() - new Date(recent.data[0].last_sent_at).getTime();
        if (elapsed < 60_000) return json({ error: 'انتظر دقيقة قبل طلب رمز جديد' }, 429);
      }

      const codeValue = randomOtp();
      const codeHash = await hashOtp(codeValue, secret);
      const now = new Date();
      const expires = new Date(now.getTime() + 5 * 60_000);

      const cancelled = await admin.from('phone_otp_challenges')
        .update({ consumed_at: now.toISOString() })
        .eq('phone_e164', phoneE164)
        .is('consumed_at', null);
      if (cancelled.error) throw cancelled.error;

      const inserted = await admin.from('phone_otp_challenges').insert({
        phone_e164: phoneE164,
        code_hash: codeHash,
        purpose: 'login',
        expires_at: expires.toISOString(),
        last_sent_at: now.toISOString(),
      });
      if (inserted.error) throw inserted.error;

      await sendWhatsAppOtp(phoneE164, codeValue);
      return json({ ok: true, expiresInSeconds: 300, resendAfterSeconds: 60 });
    }

    if (action === 'verify') {
      const rowResult = await admin.from('phone_otp_challenges')
        .select('id,code_hash,attempts,max_attempts,expires_at')
        .eq('phone_e164', phoneE164)
        .is('consumed_at', null)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (rowResult.error) throw rowResult.error;
      const challenge = rowResult.data;
      if (!challenge) return json({ error: 'لا يوجد رمز فعال' }, 400);
      if (new Date(challenge.expires_at).getTime() <= Date.now()) return json({ error: 'انتهت صلاحية الرمز' }, 400);
      if (challenge.attempts >= challenge.max_attempts) return json({ error: 'تم تجاوز عدد المحاولات' }, 429);

      const expected = await hashOtp(String(code ?? ''), secret);
      if (expected !== challenge.code_hash) {
        await admin.from('phone_otp_challenges').update({ attempts: challenge.attempts + 1 }).eq('id', challenge.id);
        return json({ error: 'رمز التحقق غير صحيح' }, 400);
      }

      await admin.from('phone_otp_challenges').update({ consumed_at: new Date().toISOString() }).eq('id', challenge.id);

      const lookup = await admin.rpc('find_auth_user_by_phone', { p_phone: phoneE164 });
      if (lookup.error) throw lookup.error;
      const existingId = lookup.data as string | null;
      const temporaryPassword = `${crypto.randomUUID()}-${crypto.randomUUID()}`;
      let userId = existingId;

      if (!existingId) {
        const created = await admin.auth.admin.createUser({ phone: phoneE164, password: temporaryPassword, phone_confirm: true });
        if (created.error) throw created.error;
        userId = created.data.user.id;
      } else {
        const updated = await admin.auth.admin.updateUserById(existingId, { password: temporaryPassword, phone_confirm: true });
        if (updated.error) throw updated.error;
      }

      const profile = await admin.from('profiles').upsert({ id: userId, phone: phoneE164, phone_verified: true }, { onConflict: 'id' });
      if (profile.error) throw profile.error;

      const tokenResponse = await fetch(`${Deno.env.get('SUPABASE_URL')}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: { apikey: Deno.env.get('SUPABASE_ANON_KEY')!, 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: phoneE164, password: temporaryPassword }),
      });
      const session = await tokenResponse.json();
      if (!tokenResponse.ok || !session.access_token || !session.refresh_token) {
        console.error('Token exchange failed', session);
        return json({ error: 'تم التحقق من الهاتف لكن تعذر إنشاء جلسة الدخول' }, 500);
      }
      return json({ ok: true, accessToken: session.access_token, refreshToken: session.refresh_token });
    }

    return json({ error: 'إجراء غير معروف' }, 400);
  } catch (error) {
    console.error(error);
    return json({ error: error instanceof Error ? error.message : 'حدث خطأ غير متوقع' }, 500);
  }
});
