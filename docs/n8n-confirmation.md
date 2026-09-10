# n8n confirmation mail (keep Supabase, skip that template)

Do **not** import [n8n workflow 3953](https://n8n.io/workflows/3953-double-opt-in-email-verification-system-with-google-sheets/) as-is. It is too much for Teahappy, and it replaces the database you already have.

That template:

- Collects email in **n8n Forms**, not this landing page
- Stores rows in **Google Sheets**
- Sends a **6-digit code**, then a second form to type it, then a **third** “main form”
- Is built for lead-gen + a long questionnaire after verify

Teahappy only needs: one email field, one table, a voucher later. Two databases (Sheets + Supabase) means two places that hold PII, two places that can drift, and Sheets has no RLS. At “lots of people want a free drink,” Sheets API quotas and a shared spreadsheet are the wrong store.

**Keep Supabase. Keep this page. Use n8n only to send mail.**

## Simplify in two steps

### Step 1 — one email, no extra forms (do this first)

```
visitor → Teahappy page → Supabase INSERT
                              ↓
                    Database Webhook (INSERT)
                              ↓
                    n8n (3 nodes): Webhook → check email → SMTP
```

Mail says: we have this address; the milk tea voucher comes when the app launches; this is not the voucher.

Three n8n nodes. No Sheets. No code. No second page. Duplicates that hit the unique constraint do not insert (HTTP 409), so they should not fire the webhook again.

### Step 2 — double opt-in the simple way (later)

Skip 6-digit codes and extra n8n forms. Put a **confirm link** in that same email:

`https://your-n8n.example/webhook/confirm?token=...`

Click → n8n sets `confirmed_at` on that row in **Supabase**. Launch-day voucher mail only goes to rows where `confirmed_at` is set.

A link is one click. A 6-digit code is: open mail, remember the code, come back, type it, handle retries. That is the template’s complexity. You do not need it for a waitlist.

## What n8n should never do here

- Host the signup form (you already have `src/index.html`)
- Use Google Sheets as the list
- Call n8n from page JavaScript (the URL would be public)
- Hold `service_role` and `SELECT *` the table if a webhook payload is enough
- Send the voucher code in the first mail

## Supabase webhook (step 1)

1. Run `schema.sql` and `scripts/verify-rls.sh`. Stop if the read test fails.
2. Database → Webhooks → `public.waitlist` → **Insert** only.
3. URL = n8n production webhook (long random path; treat as a secret).

n8n reads `email` from the webhook body. It does not need Sheets.

## n8n nodes (step 1)

1. **Webhook** — POST, respond immediately so Supabase does not wait on SMTP.
2. **If** — address looks like an email (same idea as the database CHECK).
3. **Send email** — SMTP or Resend/SendGrid on your domain, not a personal Gmail inbox.

Lock down who can open n8n executions; the payload is PII. Do not Slack the raw email to a public channel.

## Before you advertise

A script that only POSTs `{ "email": "..." }` skips the honeypot and will hit this workflow. Add Turnstile or a WAF rate limit before the voucher is public.

## Schema when you add step 2

Keep the same table. Add something like `confirm_token` (long random, not 6 digits) and `confirmed_at`. Still no Google Sheet.
