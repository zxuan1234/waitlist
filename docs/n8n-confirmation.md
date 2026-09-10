# n8n + Supabase (no Google Sheets)

Do **not** import the n8n template that uses Google Sheets and 6-digit codes. That is a different product (n8n forms + a spreadsheet database).

**This repo:** landing page → Supabase. n8n only sends mail.

- Import `n8n/teahappy-waitlist-emails.json`
- Follow **[click-by-click setup](n8n-setup.md)**
- SMTP: **Gmail** if you have no domain (see that doc). Resend later if you buy one.

Visitor mail has a **confirm link** (not a code). Click sets `confirmed_at` on the same row. You also get a **daily CSV** of new signups.
