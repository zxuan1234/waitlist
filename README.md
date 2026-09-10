# Teahappy waitlist
A one-page waitlist for Teahappy, a beverage shop launching an app. People on the list get a free milk tea voucher. The original brief never named a product. Thus, I have this story to make the page has a reason people are signing up.

Live: 

**Review:** [WRITEUP.md](WRITEUP.md) — assumptions, 10,000 signups in an hour, who can read emails.

## Stack
- Plain HTML/CSS/JS on Netlify. 
- Supabase Postgres + RLS for storage
- n8n for a confirm-link email and a daily CSV. 
- Netlify for hosting (a 20-line `build.js` only injects env vars)

## Layout
schema.sql             table, unique email, CHECK, RLS, grants
src/                   page source (placeholders, not secrets)
build.js               copies src/ → dist/ and fills placeholders
scripts/verify-rls.sh  stranger-with-the-anon-key read test
WRITEUP.md             assumptions, scale, who can read emails
