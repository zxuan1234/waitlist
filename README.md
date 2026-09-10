# Teahappy waitlist

A one-page waitlist for **Teahappy**, a beverage shop launching an app. People on the list get a free milk tea voucher. The original brief never named a product; this story is so the page has a reason people are signing up.

Live site: *not deployed from this environment — connect the repo to Netlify and add the two env vars below.*

Emails go from the browser to Supabase. There is no Netlify Function and no `service_role` key.

## Stack

- Plain HTML, CSS, and JavaScript
- Netlify for hosting (a 20-line `build.js` only injects env vars)
- Supabase Postgres + RLS for storage

## Local preview

```bash
cp .env.example .env   # optional; without real keys the form validates but will not save
export SUPABASE_URL=...
export SUPABASE_ANON_KEY=...
node build.js
python3 -m http.server 4173 --directory dist
```

Open http://localhost:4173

## Deploy

1. Create a free Supabase project. In the SQL editor, run `schema.sql`.
2. Copy **Project URL** (green **Connect** button) and the **publishable** key (`sb_publishable_…`) or the **Legacy anon** JWT. Do not copy `sb_secret_` or `service_role`.
3. Create a Netlify site from this repo. Build command and publish directory are in `netlify.toml`.
4. In Netlify: Site configuration → Environment variables:

   - `SUPABASE_URL` — `https://….supabase.co` from **Connect**, not the publishable key
   - `SUPABASE_ANON_KEY` — `sb_publishable_…` or the Legacy `anon` JWT

5. Trigger a deploy. Confirm the live page source contains the real URL, not `__SUPABASE_URL__`.
6. Prove reads are blocked:

```bash
SUPABASE_URL=... SUPABASE_ANON_KEY=... ./scripts/verify-rls.sh
```

You want `PASS` and a body of `[]`. Insert happens first so an empty table cannot fake that result.

If insert fails with `new row violates row-level security policy`, RLS is on but the insert policy is missing. In the SQL editor run the `create policy "anon_can_insert"` block from `schema.sql`, then run the script again.

## Layout

```
schema.sql             table, unique email, CHECK, RLS, grants
src/                   page source (placeholders, not secrets)
build.js               copies src/ → dist/ and fills placeholders
scripts/verify-rls.sh  stranger-with-the-anon-key read test
WRITEUP.md             assumptions, scale, who can read emails, next steps
docs/n8n-confirmation.md   planned Supabase → n8n confirmation mail
```

## Locked choices

| Decision | Choice |
| --- | --- |
| Path into Supabase | Browser → REST with the anon key |
| Duplicates | Unique on `email`. Second insert is 409; the page still says success. |
| Columns | `id`, `email`, `created_at` |
| Validation | `type="email"`, JS checks, database `CHECK` |
| Spam | Honeypot field. Filled bots get a fake success and no insert. |
