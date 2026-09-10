-- Waitlist table, constraints, grants, and RLS.
-- Run this in the Supabase SQL editor (or via the CLI) on a new project.
-- Reviewers: this file is the source of truth for question 3.

-- gen_random_uuid() is available on hosted Supabase; no extra extension needed.

create table if not exists public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  created_at timestamptz not null default now(),
  constraint email_length check (char_length(email) between 3 and 254),
  constraint email_is_lowercase check (email = lower(email)),
  constraint email_format check (
    email ~ '^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$'
  ),
  constraint waitlist_email_key unique (email)
);

comment on table public.waitlist is
  'Waitlist signups. Unique on email. RLS: insert for anon, no select.';

-- Privileges: anon may insert. SELECT is granted so PostgREST can run
-- upserts and queries; RLS (no SELECT policy) still returns no rows.
revoke all on table public.waitlist from public, anon, authenticated;
grant insert, select on table public.waitlist to anon;

alter table public.waitlist enable row level security;

-- Drop and recreate so re-running this file is safe.
drop policy if exists "anon_can_insert" on public.waitlist;

create policy "anon_can_insert"
  on public.waitlist
  for insert
  to anon
  with check (true);

-- Intentionally no SELECT / UPDATE / DELETE policies.
-- With RLS on and no SELECT policy, PostgREST returns [] to the anon key.
-- Test that with scripts/verify-rls.sh.

-- Duplicate inserts: the unique constraint is the rule. The page sends
-- Prefer: resolution=ignore-duplicates, which PostgREST maps to
-- ON CONFLICT DO NOTHING, so a second signup is a silent success.
