# n8n setup (click by click)

**SMTP:** use **Resend** (free: 100 emails/day, 3,000/month). It is made for this. Gmail SMTP is free too but Google often blocks “app” sends; use it only if Resend is blocked for you.

The landing page still does **not** call n8n. Flow:

```
page → Supabase INSERT (publishable key)
         → Database Webhook POST
         → n8n Signup webhook → check email → SMTP (confirm link)

click link → n8n Confirm webhook → PATCH row with secret key → confirmed_at

every day 09:00 UTC → n8n reads new rows with secret key → CSV email to you
```

Google Sheets is not used. The secret key lives only in n8n.

---

## 0. In this repo

1. `git pull` this branch.
2. In the **Supabase SQL editor**, run the whole `schema.sql` (adds `confirm_token`, `confirmed_at`, trigger).
3. If the trigger line errors on `execute function`, change that one line to `execute procedure public.waitlist_on_insert();` and run again.
4. `./scripts/verify-rls.sh` still wants `INSERT 201` and `Body: []`.

---

## 1. Resend (free SMTP)

1. Sign up at [resend.com](https://resend.com) (no card for Free).
2. **Domains** → add a domain you own → add the DNS records they show → wait until verified.  
   For a first test, Resend may allow a test sender after you verify; production From must be on that domain.
3. **API Keys** → create → copy `re_...` once.
4. SMTP settings you will paste into n8n:

| Field | Value |
| --- | --- |
| Host | `smtp.resend.com` |
| Port | `465` (SSL) or `587` (STARTTLS) |
| User | `resend` (the word resend, not your email) |
| Password | the `re_...` API key |
| From | e.g. `Teahappy <hello@your-verified-domain>` |

---

## 2. n8n

1. Create an account at [n8n.io](https://n8n.io) (Cloud) or run n8n yourself (also free).
2. **Workflows** → **Import from File** → choose `n8n/teahappy-waitlist-emails.json`.
3. **Credentials** → add **SMTP** → name it `SMTP (Resend)` → paste the table above. Open **Send confirm email** and **Send daily digest** and select that credential if import did not attach it.

---

## 3. Placeholders in the imported workflow

Click each node and replace:

| Find | Put |
| --- | --- |
| `__FROM_EMAIL__` | `hello@your-verified-domain` (same domain as Resend) |
| `__STAFF_EMAIL__` | **your** inbox (daily CSV) |
| `__SUPABASE_URL__` | `https://YOUR-REF.supabase.co` (Connect button, no trailing slash) |
| `__SUPABASE_SECRET_KEY__` | **Legacy `service_role` JWT** (`eyJ...`) from API Keys → **Legacy** tab. Not `sb_publishable_`. Not in Netlify. |
| `__CONFIRM_LINK_BASE__` | Confirm webhook **Production** URL **without** `?token=` (step 4) |

There are two HTTP nodes (**Mark confirmed**, **Fetch new signups**) that both need the URL and secret.

---

## 4. Turn the workflow on and copy URLs

1. Toggle the workflow **Active**.
2. Open **Signup webhook** → copy **Production URL**  
   (looks like `https://….n8n.cloud/webhook/teahappy-signup`).
3. Open **Confirm webhook** → copy **Production URL**  
   (`…/webhook/teahappy-confirm`).  
   That value (no query string) is `__CONFIRM_LINK_BASE__`. Save the node **Send confirm email**.

Do not use Test URL for real signups; Test only works while you click Listen.

---

## 5. Supabase Database Webhook (not from the browser)

1. Supabase → **Database** → **Webhooks** → **Create**.
2. Table: `waitlist`. Events: **Insert** only (leave Update/Delete off).
3. Type: HTTP. Method: POST. URL: the **Signup webhook Production URL**.
4. Save.

Payload is the new row, including `confirm_token`. n8n does not need to `SELECT` for the visitor mail.

---

## 6. Try it

1. Submit your own address on the Teahappy page.
2. You should get “Confirm my email”. Click it → browser says confirmed.
3. In **Table Editor**, that row’s `confirmed_at` is set.
4. **Send daily digest**: in n8n, open **Every day 09:00 UTC** → Execute workflow (or wait until 09:00 UTC). You should get mail: “N new emails” + CSV.

If signup mail never arrives: n8n Executions tab, Resend domain, spam folder, and whether the Database Webhook shows 2xx.

---

## 7. What staff see vs the public

- **You:** daily CSV + dashboard.
- **Public / publishable key:** insert only; reads still `[]`.
- **Confirm click:** n8n uses the **secret** key. That key bypasses RLS. Keep n8n login private.

Do not add a SELECT policy so the website can “show the list.”
