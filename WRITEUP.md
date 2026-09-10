# Write-up

## Assumptions and gaps

The brief asked for a waitlist page, Netlify, Supabase, and this write-up. Everything else was unspecified. I filled the gaps as follows and then stopped.

**What the waitlist is for.** The brief never names a product. This page is Teahappy: a beverage shop launching an app, giving a free milk tea voucher to people who sign up. That is copy, not extra backend. We do not issue, email, or track the voucher in this version — we only store the email. A real launch would need a way to actually send the voucher and to stop one person claiming many with throwaway addresses.

**How emails reach the database.** Direct from the browser with the anon key (Option A). With a few hours, I wanted one security model to get right — RLS — rather than a function plus a master key that bypasses RLS. The cost is that all safety sits in `schema.sql`.

**Duplicates.** Unique constraint on `email`, and the insert uses PostgREST `Prefer: resolution=ignore-duplicates` (`ON CONFLICT DO NOTHING`). New and repeat signups see the same sentence: "You're on the list." I do not confirm whether an address was already present.

**What is stored.** `id`, `email`, `created_at`. No IP, no user agent, no UTM. I did not need them, and they would widen what a leak exposes.

**Validation.** The browser checks the shape of the string (`type="email"` plus a regex that matches the database `CHECK`). That is a suggestion: anyone can POST with curl. The database is the rule that cannot be edited in DevTools. I cannot tell whether an address exists without sending mail, which I am not doing.

**Spam.** A hidden honeypot. If it has a value, the page pretends to succeed and never calls Supabase. No CAPTCHA, no rate limit.

**Deliberately out of scope**

- Confirmation email (double opt-in). People can sign someone else up. A real waitlist — especially a voucher — needs this.
- Actually sending or redeeming the milk tea voucher. This page only stores the email.
- Unsubscribe or delete. I am collecting an email with no way for the owner to remove it.
- Analytics and a custom domain.
- A Netlify Function. Locked to Option A.

## What would break at 10,000 signups in an hour

That is under three inserts per second. I looked at the public pricing pages on 8 Sep 2026 rather than guessing.

**The page.** Static files on Netlify's CDN. 10,000 visitors in an hour is not a CDN problem. On the current credit-based Free plan ([docs](https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/credit-based-pricing-plans/)): 300 credits/month, then the site pauses. Web requests cost 2 credits per 10,000; bandwidth is 20 credits per GB. 10,000 page loads of a ~20 KB page is a few hundred MB and a couple of credits — fine. This site has no functions, so function compute is zero. The Free-plan number that would actually stop the site is burning the 300 credits (for example many production deploys at 15 credits each, or a lot of bandwidth), not this traffic spike.

**Supabase.** The Free plan lists **unlimited API requests**, 500 MB database, 5 GB egress + 5 GB cached egress, and pauses after a week of inactivity ([pricing](https://supabase.com/pricing)). 10,000 rows of email + timestamp is well under a megabyte. Three inserts per second is nothing for Postgres. Egress on this design is tiny (JSON bodies, no storage downloads). I am estimating the Postgres throughput; I looked up the quota numbers.

**What actually breaks first.** Not latency. A free voucher is a magnet for bots and for people hitting submit over and over. With no rate limit, 10,000 signups in an hour is probably not 10,000 people. The honeypot catches dumb bots that fill every field. It does not catch a script that only posts `email`. The unique constraint stops the same address repeating, not 10,000 distinct fake addresses. You then have a list you cannot trust, and a pile of voucher claims you cannot honour. That is worse than a slow page.

**What I would add, in order:** (1) go live and prove RLS with `scripts/verify-rls.sh`, (2) confirmation mail through n8n on insert, not from the page, (3) a real bot check before that mail can be abused, (4) double opt-in plus a way to send the actual voucher. Detail in [What I would do next](#what-i-would-do-next). I would not start with a cache or a queue at this volume.

## Who can read the stored emails, and how I know

| Who | Can they read the table? | How I know |
| --- | --- | --- |
| Me, and anyone I invite to the Supabase project | Yes | Dashboard / SQL editor use a privileged role, not `anon` |
| Anyone with the `service_role` key | Yes | That key bypasses RLS by design. It is not in this repo, not in Netlify env for this site, and not in the page |
| Anyone with the **anon** key (everyone who loads the page) | **Insert only, no read** | RLS is on; the only policy is `INSERT` for `anon`; `SELECT` is revoked. Proof: `scripts/verify-rls.sh` |
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

The page is done on purpose. A voucher waitlist still needs mail, and Teahappy already uses n8n, so that is the next system — **after** the list is private.

1. **Deploy and prove the read is blocked.** Netlify + `schema.sql` + `scripts/verify-rls.sh`. If anon can `SELECT`, do not add email sending. You would be mailing from a public list.

2. **Confirmation mail in n8n, triggered by Supabase, not by the browser.** Do not import the n8n “double opt-in + Google Sheets” template — extra forms and a second database. Database webhook on `INSERT` → n8n → SMTP. Same table. See `docs/n8n-confirmation.md`.

3. **Bot check before the mail volume is real.** A voucher page will get scripts that POST only `email`. Those skip the honeypot and would make n8n send all day. Turnstile (or similar) on the form, or a provider WAF rate limit, before this is advertised.

4. **Double opt-in, then the voucher.** Confirm with a **link in the email**, not a 6-digit code and extra forms. `confirmed_at` on the Supabase row. Only those addresses get a voucher at launch (second n8n flow).

5. **Unsubscribe, and an alert if insert rate spikes.** Still out of the 3–4 hour build; both are real once you hold PII and promise a drink.

n8n becomes another place that can read emails (execution history). Lock that instance down the same way as the Supabase dashboard.

## AI usage

I used Cursor Grok 4.6 as a cloud agent to implement the spec in this repo.

- **What I asked it for:** the page, `schema.sql`, Netlify build injection, this write-up, and the RLS verify script, following `waitlist-takehome-spec.md`. Later: rebrand to Teahappy; document n8n confirmation mail as the next step (not built).
- **What I changed or refused in the output:** no `service_role` key, no SELECT policy "to make the table easier to debug", no IP/user-agent columns, no React, no confirmation email. The first draft of an RLS policy often grants `SELECT` to `anon`; this schema does not. Grants are `INSERT` only.
- **What I threw away:** a Netlify Function path (Option B). The locked spec is Option A, and a function would mean explaining a key that ignores RLS.
- **What I do not fully understand:** nothing I shipped. PostgREST `resolution=ignore-duplicates` is the documented mapping to `ON CONFLICT DO NOTHING`; if that header were omitted, a duplicate would be HTTP 409 and the page still shows the same success sentence.
