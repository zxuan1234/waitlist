# Write-up

## Assumptions and gaps

The brief asked for a waitlist page, Netlify, Supabase, and this write-up. Everything else was unspecified. I filled the gaps as follows and then stopped.

**What the waitlist is for.** The brief never names a product. This page is Teahappy: a beverage shop launching an app, giving a free milk tea voucher to people who sign up. That is copy, not extra backend. We do not issue, email, or track the voucher in this version — we only store the email. A real launch would need a way to actually send the voucher and to stop one person claiming many with throwaway addresses.

**How emails reach the database.** Direct from the browser with the anon key (Option A). With a few hours, I wanted one security model to get right — RLS — rather than a function plus a master key that bypasses RLS. The cost is that all safety sits in `schema.sql`.

**Duplicates.** Unique constraint on `email`. A second insert is HTTP 409; the page still shows the same success sentence. I do not confirm whether an address was already present. We do not use PostgREST `on_conflict` upsert: that path needs a SELECT policy and is how a public read can sneak in.

**What is stored.** `id`, `email`, `created_at`, `confirm_token` (only for the confirm link), `confirmed_at`. No IP, no user agent, no UTM. The token is minted in a trigger so the browser cannot pick it.

**Validation.** The browser checks the shape of the string (`type="email"` plus a regex that matches the database `CHECK`). That is a suggestion: anyone can POST with curl. The database is the rule that cannot be edited in DevTools. I cannot tell whether an address exists without sending mail, which I am not doing.

**Spam.** A hidden honeypot. If it has a value, the page pretends to succeed and never calls Supabase. No CAPTCHA, no rate limit.

**Deliberately out of scope**

- Sending or redeeming the milk tea **voucher code** (only confirm + waitlist).
- Unsubscribe or delete from the page.
- Analytics, custom domain, CAPTCHA.
- A Netlify Function. Locked to Option A. Mail is n8n, not Netlify.

## What would break at 10,000 signups in an hour

That is under three inserts per second. I looked at the public pricing pages on 8 Sep 2026 rather than guessing.

**The page.** Static files on Netlify's CDN. 10,000 visitors in an hour is not a CDN problem. On the current credit-based Free plan ([docs](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/credit-based-pricing-plans/)): 300 credits/month, then the site pauses. Web requests cost 2 credits per 10,000; bandwidth is 20 credits per GB. 10,000 page loads of a ~20 KB page is a few hundred MB and a couple of credits — fine. This site has no functions, so function compute is zero. The Free-plan number that would actually stop the site is burning the 300 credits (for example many production deploys at 15 credits each, or a lot of bandwidth), not this traffic spike.

**Supabase.** The Free plan lists **unlimited API requests**, 500 MB database, 5 GB egress + 5 GB cached egress, and pauses after a week of inactivity ([pricing](https://supabase.com/pricing)). 10,000 rows of email + timestamp is well under a megabyte. Three inserts per second is nothing for Postgres. Egress on this design is tiny (JSON bodies, no storage downloads). I am estimating the Postgres throughput; I looked up the quota numbers.

**What actually breaks first.** Not latency. A free voucher is a magnet for bots and for people hitting submit over and over. With no rate limit, 10,000 signups in an hour is probably not 10,000 people. The honeypot catches dumb bots that fill every field. It does not catch a script that only posts `email`. The unique constraint stops the same address repeating, not 10,000 distinct fake addresses. You then have a list you cannot trust, and a pile of voucher claims you cannot honour. That is worse than a slow page.

**What I would add, in order:** (1) go live and prove RLS, (2) wire n8n from `docs/n8n-setup.md`, (3) a bot check before the voucher is advertised, (4) launch-day mail only where `confirmed_at` is set. I would not start with a cache or a queue at this volume.

## Who can read the stored emails, and how I know

| Who | Can they read the table? | How I know |
| --- | --- | --- |
| Me, and anyone I invite to the Supabase project | Yes | Dashboard / SQL editor use a privileged role, not `anon` |
| Anyone with the `service_role` / secret key | Yes | Bypasses RLS. Not in the repo, not in Netlify, not in the page. **n8n** holds it to set `confirmed_at` and to build your daily CSV |
| Anyone who can open the n8n instance | Yes, in execution history and the digest mail | Lock n8n login; the daily CSV is a copy for you, not a second database |
| Anyone with the **anon / publishable** key (everyone who loads the page) | **Insert only, no read** | RLS is on; the only policy is `INSERT` for `anon`. SELECT is granted so the API can run the query; with no SELECT policy the result is `[]`. Proof: `scripts/verify-rls.sh` |
| Anyone with admin access to the Netlify site | They can read the anon key from env vars, which does not grant SELECT. They cannot read rows unless they also have Supabase access | Netlify env is `SUPABASE_URL` and `SUPABASE_ANON_KEY` only |
| Supabase and Netlify | Yes, as operators, per their terms | I did not independently audit that; it is the hosting tradeoff |

The trap: RLS is off by default. Off plus the public anon key means the waitlist is a public JSON file. The other trap: an empty table with RLS off also returns `[]`, which looks like a pass. The verify script **inserts a row first**, then reads. A pass is `[]` after a successful insert.

I could not run that curl against a live project from this environment (no Supabase account credentials here). The proof is the script plus `schema.sql`. After you run the SQL and set the two env vars, run:

```bash
SUPABASE_URL=... SUPABASE_ANON_KEY=... ./scripts/verify-rls.sh
```

Expected: insert HTTP 201, select body `[]`, `PASS`.

If you see a JSON array of emails, RLS is off or a SELECT policy exists. Do not leave the site up.

## What I would do next

Mail is specified in `docs/n8n-setup.md` (import `n8n/teahappy-waitlist-emails.json`). Still to do in your accounts, not in this environment: Resend domain, n8n import, Supabase insert webhook.

Then, before advertising a free drink: Turnstile or a WAF. At launch: a second n8n flow that emails voucher codes **only** where `confirmed_at` is set. Unsubscribe remains a gap.

## AI usage

I used Cursor Grok 4.6 as a cloud agent to implement the spec in this repo.

- **What I asked it for:** the page, RLS, verify script, Teahappy copy, then n8n import JSON + Resend setup for confirm-link and daily CSV.
- **What I changed or refused in the output:** no `service_role` key, no SELECT policy "to make the table easier to debug", no IP/user-agent columns, no React, no confirmation email. The first draft of an RLS policy often grants `SELECT` to `anon`; this schema does not. Grants are `INSERT` only.
- **What I threw away:** a Netlify Function path (Option B). The locked spec is Option A, and a function would mean explaining a key that ignores RLS.
- **What I do not fully understand:** nothing I shipped. A duplicate email is HTTP 409 from the unique constraint; the page still shows the same success sentence.
