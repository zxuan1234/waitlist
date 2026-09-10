# n8n setup (click by click)

**No domain:** use **Gmail SMTP** (free). From and the daily digest both go through your Gmail address. That is enough for this take-home.

**If you buy a domain later:** switch SMTP to **Resend** (100 emails/day free, better inbox placement). Resend will not send until a domain is verified — skip it for now.

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

## 1. Gmail SMTP (no domain)

1. Open the Google account that should **send** mail (same one can **receive** the daily CSV).
2. Turn on **2-Step Verification**: [Google Account → Security](https://myaccount.google.com/security).
3. Open [App passwords](https://myaccount.google.com/apppasswords) → app: Mail → device: Other → name `n8n` → **Create**.
4. Copy the 16-character password (spaces do not matter). This is **not** your normal Gmail password.
5. SMTP settings for n8n:

| Field | Value |
| --- | --- |
| User | your full address, e.g. `you@gmail.com` |
| Password | 16-character **App password**, field set to **Fixed** (not Expression / *fx*) |
| Host | `smtp.gmail.com` |
| Port | `465` |
| SSL/TLS | **On** |
| Client Host Name | leave empty |

If it still fails, try port `587` and turn **SSL/TLS off** (n8n then uses STARTTLS). Do not use 587 with SSL/TLS on — that is the usual “Couldn’t connect” error.

Never put the app password in GitHub, chat, or screenshots. If it leaked, delete that App password in Google and create a new one.

`__FROM_EMAIL__` and `__STAFF_EMAIL__` can both be `you@gmail.com`. Confirm mails to waitlist people will show as coming from your Gmail, not “Teahappy.com”. That is expected without a domain.

If Google later blocks sign-in, create a new App password. Do not use your mailbox password in n8n.

---

## 2. n8n

1. Create an account at [n8n.io](https://n8n.io) (Cloud) or run n8n yourself (also free).
2. **Workflows** → **Import from File** → choose `n8n/teahappy-waitlist-emails.json`.
3. **Credentials** → add **SMTP** → paste the Gmail table. Open **Send confirm email** and **Send daily digest** and select that credential.

---

## 3. Placeholders in the imported workflow

Click each node and replace:

| Find | Put |
| --- | --- |
| `__FROM_EMAIL__` | your Gmail, e.g. `you@gmail.com` (must match the SMTP user) |
| `__STAFF_EMAIL__` | the same Gmail (daily CSV) |
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

If signup mail never arrives: n8n Executions tab, Gmail Spam, and whether the Database Webhook shows 2xx. Waitlist users may also see your message in Spam because From is Gmail, not teahappy.com.

If confirm click errors with `permission denied for table waitlist` / GRANT to `service_role`:

```sql
grant select, insert, update, delete on table public.waitlist to service_role;
```

If **Fetch new signups** says **Credentials not found**:

1. Set **Authentication** to **None** (do not leave Generic Auth Type empty).
2. Turn **Send Headers** on.
3. Headers: `apikey` = service_role JWT, `Authorization` = `Bearer` + the same JWT.
4. In the URL, use `{{ $now.minus({days:1}).toUTC().toISO() }}` so the time has no `+08:00` (that `+` breaks the query string).

A “Supabase API” credential is optional. Empty Generic Auth is what causes Credentials not found.

---

## 7. What staff see vs the public

- **You:** daily CSV + dashboard.
- **Public / publishable key:** insert only; reads still `[]`.
- **Confirm click:** n8n uses the **secret** key. That key bypasses RLS. Keep n8n login private.

Do not add a SELECT policy so the website can “show the list.”

---

## 8. Later, if you own a domain

Resend (100/day free): verify the domain, SMTP host `smtp.resend.com`, user `resend`, password `re_...` API key, From `hello@yourdomain`. Swap the n8n SMTP credential. Same workflow.
