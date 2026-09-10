# Write-up

## Assumptions and gaps
The brief asked for a waitlist page, Netlify, Supabase, and this write-up. Everything else was unspecified. I filled the gaps as follows and then stopped.

**What the waitlist is for.** The brief never names a product. This page is Teahappy. A beverage shop launching an app, giving a free milk tea voucher to people who sign up. That is copy, not extra backend. I did not issue email or track the voucher in this version, I only store the email. A real launch would need a way to actually send the voucher and to stop one person claiming many with throwaway addresses.

**How emails reach the database.** Direct from the browser with the anon key with a few hours, I wanted one security model to get right RLS rather than a function plus a master key that bypasses RLS. The cost is that all safety sits in `schema.sql`.

**Duplicates.** Unique constraint on `email`. A second insert is HTTP 409, the page still shows the same success sentence. I do not confirm whether an address was already present. We do not use PostgREST `on_conflict` upsert, that path needs a SELECT policy and is how a public read can sneak in.

If the first confirm mail is lost, submitting the same address again does not send a second link. Unique on email blocks a new insert, so the insert-only webhook never runs. I left that on purpose.A resend path would need the secret key, since the page still cannot read rows. I would add it only if people were actually dropping off before confirm.

**What is stored.** `id`, `email`, `created_at`. No IP, no user agent, no UTM. I did not need them, and they would widen what a leak exposes.

**Validation.** The browser checks the shape of the string (`type="email"` plus a regex that matches the database `CHECK`). That is a suggestion, anyone can POST with curl. The database is the rule that cannot be edited in DevTools. I cannot tell whether an address exists without sending mail, which I am not doing.

**Spam.** A hidden honeypot. If it has a value, the page pretends to succeed and never calls Supabase. No CAPTCHA, no rate limit.

**Deliberately out of scope**
- Actually sending or redeeming the milk tea voucher. This page only stores the email.
- Unsubscribe or delete. I am collecting an email with no way for the owner to remove it.
- Analytics and a custom domain.
- A Netlify Function. I locked to RLS way.

## What would break at 10,000 signups in an hour
That is under three inserts per second. I checked Netlify and Supabase pricing pages on 8 Sep 2026 instead of guessing the numbers.

The page is static files on Netlify. 10,000 visitors in an hour will not knock over a CDN. The site has no functions. On the free plan the site pauses after 300 credits in a month. This spike is only a couple of credits. What would burn the month is lots of deploys or a lot of bandwidth, not this hour of traffic.

Supabase free allows unlimited API requests and 500 MB of database. 10,000 emails plus timestamps is well under a megabyte. Three inserts per second is easy for Postgres.

**What actually breaks first.** Not latency. A free voucher is a magnet for bots and for people hitting submit over and over. With no rate limit, 10,000 signups in an hour is probably not 10,000 people. The honeypot catches dumb bots that fill every field. It does not catch a script that only posts `email`. The unique constraint stops the same address repeating, not 10,000 distinct fake addresses. You then have a list you cannot trust, and a pile of voucher claims you cannot honour. That is worse than a slow page.

I would add a real bot check before sending confirm mail and I would not add a cache or a queue at this volume.

## Who can read the emails
Project owners and anyone invited into the Supabase project can read every row. Table Editor and the SQL editor use a privileged role.

Anyone who holds the service_role or secret key can also read. That key bypasses RLS. I keep it only in n8n, where it PATCHes confirmed_at and SELECTs for the daily CSV. Anyone who can log into n8n can see those emails too. They can open past workflow runs, and they get that daily CSV in their inbox. While the secret key lives in n8n, that login is as powerful as holding the key.

The publishable or anon key on the page cannot read. RLS is on, there is an INSERT policy, and there is no SELECT policy. GRANT SELECT still exists so PostgREST can run the query, but the result is an empty list. scripts/verify-rls.sh proves this. It inserts a row first, then GETs. An empty table with RLS off also returns an empty list, so the insert-first step is what makes the check real.

Netlify site admins can see SUPABASE_URL and SUPABASE_ANON_KEY in env. They do not get the rows.

Supabase and Netlify as hosts can read per their terms. I have not independently audited that.

service_role still needs table GRANTs. After REVOKE from PUBLIC, confirm clicks returned 403 until I granted SELECT and UPDATE to service_role. BYPASSRLS does not skip GRANT. That grant is in schema.sql.

I run ./scripts/verify-rls.sh locally. A pass looks like insert 201, an empty body, and PASS. A JSON array of emails means RLS is off or a SELECT policy exists.

## AI
I used an LLM while writing this, mainly for CSS and a first pass at the page copy, which I then edited.

I did not take the data path from the generated draft. I specified it. From the browser, inserts use the public key, and RLS allows insert only with no public read. Mail goes through n8n instead of the page, and a second signup with the same email triggers a unique-constraint 409 that the UI treats as a success. I avoided using upsert because that requires public read access.

Where generated SQL or n8n JSON did not match that, I changed it. Two things I only caught on the live project were confirm clicks throwing a 403 until service_role was given a table GRANT, since bypassing RLS does not skip GRANT, and the daily digest query breaking due to a +08:00 timestamp in the URL.

Happy to walk through schema SQL file and the verify script on a call.
