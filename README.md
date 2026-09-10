# Teahappy waitlist

Landing page for a beverage shop launching an app. People on the list get a free milk tea voucher at launch.

Live: *(add Netlify URL)*

**Review:** [WRITEUP.md](WRITEUP.md) — assumptions, 10k signups/hour, who can read emails.

## Stack

Plain HTML/CSS/JS on Netlify. Browser → Supabase with the publishable key. n8n for a confirm-link email and a daily CSV. No Netlify Functions. `service_role` is not in this repo.

## Run locally

```bash
export SUPABASE_URL=...          # https://….supabase.co
export SUPABASE_ANON_KEY=...     # sb_publishable_… or legacy anon JWT
node build.js
python3 -m http.server 4173 --directory dist
```

## Deploy

Netlify build: `node build.js`. Publish: `dist`. Env: `SUPABASE_URL`, `SUPABASE_ANON_KEY` only.

Run `schema.sql` in the Supabase SQL editor first, then `./scripts/verify-rls.sh` (expect `[]` on read).

Mail: import `n8n/teahappy-waitlist-emails.json`. Operator notes: [docs/n8n.md](docs/n8n.md).
