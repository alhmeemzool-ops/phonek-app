import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.0";
import { importPKCS8, SignJWT } from "npm:jose@5.10.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type PushRequest = {
  thread_id?: string;
  message_id?: string;
};

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function getFirebaseAccessToken() {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error("إعدادات Firebase السرية غير مكتملة");
  }

  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(privateKey, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const body = await response.json();
  if (!response.ok || !body.access_token) {
    throw new Error("تعذر الحصول على رمز Firebase");
  }
  return { accessToken: body.access_token as string, projectId };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "method_not_allowed" }, 405);

  const authorization = req.headers.get("Authorization");
  const token = authorization?.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ success: false, error: "missing_jwt" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ success: false, error: "server_configuration_error" }, 500);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !authData.user) {
    return json({ success: false, error: "invalid_jwt" }, 401);
  }

  let payload: PushRequest;
  try {
    payload = await req.json();
  } catch (_) {
    return json({ success: false, error: "invalid_json" }, 400);
  }

  const threadId = payload.thread_id?.trim();
  const messageId = payload.message_id?.trim();
  if (!threadId || !messageId) {
    return json({ success: false, error: "thread_id_and_message_id_required" }, 400);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: thread, error: threadError } = await adminClient
    .from("chat_threads")
    .select("id, buyer_id, seller_id")
    .eq("id", threadId)
    .maybeSingle();

  if (threadError) return json({ success: false, error: "thread_lookup_failed" }, 500);
  if (!thread) return json({ success: false, error: "thread_not_found" }, 404);

  const senderId = authData.user.id;
  const buyerId = String(thread.buyer_id);
  const sellerId = String(thread.seller_id);
  if (senderId !== buyerId && senderId !== sellerId) {
    return json({ success: false, error: "not_a_thread_participant" }, 403);
  }

  const { data: message, error: messageError } = await adminClient
    .from("chat_messages")
    .select("id, thread_id, sender_id, text, type, offer_amount")
    .eq("id", messageId)
    .eq("thread_id", threadId)
    .maybeSingle();

  if (messageError) return json({ success: false, error: "message_lookup_failed" }, 500);
  if (!message) return json({ success: false, error: "message_not_found" }, 404);
  if (String(message.sender_id) !== senderId) {
    return json({ success: false, error: "message_sender_mismatch" }, 403);
  }

  const recipientId = senderId === buyerId ? sellerId : buyerId;

  const { data: senderCard } = await adminClient
    .from("public_seller_cards")
    .select("name")
    .eq("id", senderId)
    .maybeSingle();

  const { data: tokens, error: tokenError } = await adminClient
    .from("push_tokens")
    .select("token")
    .eq("user_id", recipientId)
    .eq("enabled", true);

  if (tokenError) return json({ success: false, error: "token_lookup_failed" }, 500);

  const registrationTokens = (tokens ?? [])
    .map((row) => String(row.token ?? "").trim())
    .filter((value) => value.length > 0);

  if (registrationTokens.length === 0) {
    return json({
      success: true,
      sent: 0,
      recipient_id: recipientId,
      reason: "no_enabled_fcm_tokens",
    });
  }

  const senderName = String(senderCard?.name ?? "مستخدم PhoneK");
  const type = String(message.type ?? "text");
  const offerAmount = Number(message.offer_amount ?? 0);
  const notificationBody =
    type === "offer" && offerAmount > 0
      ? `أرسل لك عرضاً بقيمة ${offerAmount} جنيه`
      : String(message.text ?? "").trim() || "أرسل لك رسالة جديدة";

  const { accessToken, projectId } = await getFirebaseAccessToken();
  let sent = 0;
  let failed = 0;

  for (const registrationToken of registrationTokens) {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: registrationToken,
            notification: {
              title: `رسالة من ${senderName}`,
              body: notificationBody,
            },
            data: {
              thread_id: threadId,
              message_id: messageId,
              type,
            },
            android: {
              priority: "high",
              notification: {
                channel_id: "phonek_alerts_v2",
              },
            },
          },
        }),
      },
    );

    if (response.ok) sent++;
    else failed++;
  }

  return json({
    success: true,
    sent,
    failed,
    recipient_id: recipientId,
    message_id: messageId,
  });
});
