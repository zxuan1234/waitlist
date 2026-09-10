# Waitlist take-home — notes for review

Static page on Netlify. Browser inserts into Supabase with the publishable key. Confirm mail and a daily CSV run in n8n, not in the page.

I treated this as a small public form with a list that has to stay private, not as a mini-product. Feature count stayed low on purpose.

## Assumptions

The brief did not name a product, a duplicate policy, or how mail should work.

**Product.** Teahappy — a beverage shop launching an app, free milk tea voucher for the list. Copy only. There is no voucher issuer in this repo.

**Path into the database.** Option A: the browser talks to PostgREST with the publishable / `anon` key. I did not put a Netlify Function in front of it. One security story (RLS in `schema.sql`) is easier to defend than a second privileged path on Netlify. `service_role` is not in git, not in Netlify env, not on the page. n8n holds it for confirm + digest.

**Duplicates.** Unique on `email`. A second POST is HTTP 409; the UI still shows the same success line so the page does not leak whether an address is already stored. I do not use PostgREST `on_conflict` upsert: that needs a SELECT policy, which is how a public read sneaks in. I tried upsert on a live project; it came back RLS 401. Plain insert + unique is enough.

**Columns.** `id`, `email`, `created_at`, `confirm_token`, `confirmed_at`. No IP, user-agent, or UTM. A `BEFORE INSERT` trigger (security definer) zeros `confirmed_at` and mints `confirm_token`, so the client cannot self-confirm. n8n sets `confirmed_at` after the user clicks a link.

**Validation.** Browser regex matches the table `CHECK`. That is a UX filter; curl can skip it. I cannot prove an inbox exists without sending mail.

**Spam.** Honeypot field `#company`. Filled bots get a fake success and no insert. No CAPTCHA, no rate limit.

**Mail.** n8n, triggered by a Supabase Database Webhook on insert — not by JavaScript. Confirm is a **link**, not a 6-digit code. I did not use Google Sheets as a second store. SMTP is Gmail (no domain to verify for Resend). Staff see new rows via a daily CSV to my inbox, not a public admin page.

**Left out.** Voucher codes, unsubscribe, analytics, custom domain, Netlify Functions.

---

## 10,000 signups in an hour

That is under three inserts per second. Quotas below are from vendor pages (8 Sep 2026), not guesses.

**The page.** Static files on Netlify’s CDN. Not the bottleneck. Current credit-based Free plan: 300 credits/month, then the site pauses ([docs](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/credit-based-pricing-plans/)). Web requests are 2 credits / 10,000; bandwidth 20 credits / GB. ~10,000 loads of a ~20 KB page is a few hundred MB and a couple of credits. This site has no functions. What would pause the site is burning the 300 credits (many production deploys at 15 credits each, or a lot of bandwidth), not this spike.

**Supabase.** Free plan: unlimited API requests, 500 MB database, 5 GB + 5 GB cached egress, pause after a week idle ([pricing](https://supabase.com/pricing)). 10,000 rows of email + timestamps is well under a megabyte. Three inserts per second is nothing for Postgres.

**What actually fails first.** Trust, not latency. A free voucher attracts bots. The honeypot misses a script that only posts `{ "email": "..." }`. Uniqueness stops the same address repeating, not 10,000 fake addresses. Then the list is not honourable. n8n would also try to send confirm mail up to Gmail limits — Gmail app-password SMTP is not a bulk sender.

I would add, in order: a bot check (Turnstile or a WAF) before advertising the voucher; then launch-day mail only where `confirmed_at` is set. I would not add a cache or a queue at this volume.

---

## Who can read the emails

| Who | Read? | Why I believe that |
| --- | --- | --- |
| Project owners / anyone invited to the Supabase project | Yes | Table Editor and SQL use a privileged role |
| Anyone holding `service_role` / secret key | Yes | Bypasses RLS. Lives only in n8n, for PATCH `confirmed_at` and SELECT for the CSV |
| Anyone who can log into n8n | Yes (executions + digest) | Same as holding the secret while it is stored there |
| Anyone with the publishable / `anon` key (the page) | **Insert only** | RLS on; INSERT policy only; no SELECT policy. `GRANT SELECT` is still there so PostgREST can run the query; the result is `[]`. Proof: `scripts/verify-rls.sh` inserts a row, then GET. An empty table with RLS *off* also returns `[]` — inserting first is the point |
| Netlify site admins | Key only, not rows | Env is `SUPABASE_URL` + `SUPABASE_ANON_KEY` |
| Supabase / Netlify as hosts | Yes, per their terms | Not independently audited |

`service_role` still needs table GRANTs. After `REVOKE` from `PUBLIC`, confirm-clicks returned 403 until I granted `SELECT, UPDATE` to `service_role`. BYPASSRLS does not skip GRANT. That is in `schema.sql`.

```bash
./scripts/verify-rls.sh
```

Expect insert 201, body `[]`, `PASS`. A JSON array of emails means RLS is off or a SELECT policy exists.

---

## What I would do next

Turnstile (or similar) before a public voucher campaign. At launch, a second n8n flow that sends voucher codes only where `confirmed_at` is set. An unsubscribe path. If we owned a domain, move SMTP from Gmail to Resend.

---

## AI

I used an LLM while writing this. CSS and some of the HTML copy started as drafts I then edited. I also used it to pull the current Netlify credit and Supabase free-tier pages so the 10k/hour section was not a guess.

The data path I specified myself: browser → RLS insert, no public SELECT, mail in n8n not on the page, unique + 409 instead of upsert. Generated SQL/JSON that did not match that got changed — including after a live 403 because `service_role` still needs GRANT after `REVOKE FROM PUBLIC`, and after a digest query that broke on a `+08:00` timestamp.

Happy to walk through `schema.sql` and the verify script on a call.
