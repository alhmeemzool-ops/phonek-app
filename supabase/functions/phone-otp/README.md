# PhoneK WhatsApp OTP

The app's phone login now uses a server-side OTP challenge and the official WhatsApp Business Cloud API. OTP values are generated and hashed inside the Edge Function; they are never stored in plaintext.

## Supabase setup

1. Apply migrations, including `supabase/migrations/004_phone_otp.sql`.
2. Deploy the function:

```bash
supabase functions deploy phone-otp --no-verify-jwt
```

3. Configure these Supabase Edge Function secrets. Never commit them to Git:

- `PHONE_OTP_SECRET` — long random secret used for OTP hashing and IP-key derivation.
- `WHATSAPP_ACCESS_TOKEN` — Meta WhatsApp Cloud API access token.
- `WHATSAPP_PHONE_NUMBER_ID` — WhatsApp Cloud API phone-number ID.
- `WHATSAPP_OTP_TEMPLATE` — approved WhatsApp authentication/OTP template name (default: `phonek_otp`).
- `WHATSAPP_OTP_LANG` — template language code (default: `en_US`).
- `WHATSAPP_GRAPH_VERSION` — Graph API version (default: `v23.0`).

Supabase automatically supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` to the deployed Edge Function.

## WhatsApp template

The Meta template must be approved for authentication/OTP delivery and must contain a variable matching the single code parameter sent by the function.

## Security behavior

- 6-digit cryptographically generated OTP.
- OTP expires after 5 minutes.
- 5 verification attempts maximum.
- One-minute resend cooldown per phone.
- 10 send requests per source IP per hour.
- OTP records are inaccessible to `anon` and `authenticated` clients.
- Authenticated Supabase sessions are created only after successful OTP verification.
