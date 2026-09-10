# n8n (confirm mail + daily CSV)

The page never calls n8n. Insert → Supabase Database Webhook → Signup webhook → SMTP (confirm link). Click → Confirm webhook → PATCH `confirmed_at` with the secret key. Daily 09:00 UTC → SELECT new rows → CSV to staff.

Import `n8n/teahappy-waitlist-emails.json`. Use **Production** webhook URLs (`/webhook/…`), not `/webhook-test/`. Google Sheets is not used.

## Placeholders

| Token | Value |
| --- | --- |
| `__FROM_EMAIL__` / `__STAFF_EMAIL__` | SMTP From / digest To |
| `__SUPABASE_URL__` | `https://….supabase.co` |
| `__SUPABASE_SECRET_KEY__` | Legacy `service_role` JWT. Not Netlify, not the page |
| `__CONFIRM_LINK_BASE__` | Confirm **Production** URL, no `?token=` |

SMTP for this take-home is Gmail (no domain). Resend needs a verified domain; swap the credential later if we own one.

HTTP nodes: Authentication **None**, **Send Headers** on (`apikey` + `Authorization: Bearer`). Empty Generic Auth fails with “Credentials not found”. Digest filter time must be UTC ISO (`$now.minus({days:1}).toUTC().toISO()`) so `+08:00` does not break the query string.

If confirm returns `permission denied for table waitlist`, grant table rights to `service_role` (already in `schema.sql`).
