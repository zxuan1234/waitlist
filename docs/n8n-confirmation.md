# n8n confirmation mail (next, not in this build)

The landing page does not call n8n. The browser writes to Supabase. Mail is a private reaction to a successful insert.

```
visitor → Netlify page → Supabase INSERT (anon key, RLS)
                              ↓
                    Database Webhook (INSERT only)
                              ↓
                    n8n webhook (secret URL)
                              ↓
                    Resend / SendGrid / SMTP
```

## Why this shape

- The company already runs n8n.
- The anon key in the page still cannot read the table.
- If n8n is down, the person is still on the list; they just get no mail.
- Do not put an n8n URL in `src/app.js`. Anyone who views source could fire voucher emails.

## Supabase

1. Run `schema.sql` and `scripts/verify-rls.sh`. Stop if the read test fails.
2. Database → Webhooks → create one on `public.waitlist` for **Insert**.
3. URL: the n8n production webhook URL. Use a long random path; treat it as a secret.
4. Leave Update/Delete off. You do not want mail on every dashboard edit.

Payload is the new row (`id`, `email`, `created_at`). n8n does not need to query the table. Prefer that over storing `service_role` in n8n credentials.

`ON CONFLICT DO NOTHING` means a second signup with the same email often **does not insert**, so this webhook should not fire twice for one address.

## n8n workflow (three nodes)

1. **Webhook** — POST, response immediately (do not make Supabase wait on the inbox).
2. **If** — `email` looks like an email (same shape as the database CHECK). Drop the rest.
3. **Send email** — transactional provider. Subject like “Teahappy: you’re on the milk tea list.” Body: we got this address; the voucher is sent when the app launches; this is not the voucher itself.

Then:

- Turn off saving full execution data in production if the instance is shared, or restrict who can open executions. The payload is PII.
- Do not post the raw email to a public Slack channel.
- Do not send the voucher code in this first mail.

## Before you advertise the page

Wire a bot check (Turnstile or a WAF rate limit). A script that only posts `{ "email": "..." }` bypasses the honeypot and will hit this workflow once per fake address.

## After this works

Add `confirmed_at` (and a token) and change this mail to a confirm link. A second n8n flow at launch sends vouchers only where `confirmed_at` is set.
