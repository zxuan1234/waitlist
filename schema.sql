-- Waitlist table, constraints, grants, and RLS.

create table if not exists public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  created_at timestamptz not null default now(),
  confirm_token uuid not null default gen_random_uuid(),
  confirmed_at timestamptz,
  constraint email_length check (char_length(email) between 3 and 254),
  constraint email_is_lowercase check (email = lower(email)),
  constraint email_format check (
    email ~ '^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$'
  ),
  constraint waitlist_email_key unique (email),
  constraint waitlist_confirm_token_key unique (confirm_token)
);

-- Existing projects created before confirm_token: add the columns.
alter table public.waitlist add column if not exists confirm_token uuid;
alter table public.waitlist add column if not exists confirmed_at timestamptz;

update public.waitlist
set confirm_token = gen_random_uuid()
where confirm_token is null;

alter table public.waitlist alter column confirm_token set default gen_random_uuid();
alter table public.waitlist alter column confirm_token set not null;

create unique index if not exists waitlist_confirm_token_key on public.waitlist (confirm_token);

comment on table public.waitlist is
  'Waitlist signups. Unique on email. RLS: insert for anon, no select. Confirm via n8n + token.';

revoke all on table public.waitlist from public, anon, authenticated;
grant insert, select on table public.waitlist to anon, authenticated;
-- service_role bypasses RLS but still needs GRANTs. n8n uses it to set confirmed_at and read the digest.
grant select, insert, update, delete on table public.waitlist to service_role;

alter table public.waitlist enable row level security;

drop policy if exists "anon_can_insert" on public.waitlist;

create policy "anon_can_insert"
  on public.waitlist
  for insert
  to anon, authenticated
  with check (confirmed_at is null);

-- Intentionally no SELECT / UPDATE / DELETE policies.
-- Confirm clicks are applied by n8n using the secret key (bypasses RLS).
-- Test reads with scripts/verify-rls.sh.

-- Ignore a client-supplied confirmed_at / token on insert.
create or replace function public.waitlist_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.confirmed_at := null;
  new.confirm_token := gen_random_uuid();
  return new;
end;
$$;

revoke all on function public.waitlist_on_insert() from public, anon, authenticated;

drop trigger if exists waitlist_on_insert on public.waitlist;
create trigger waitlist_on_insert
  before insert on public.waitlist
  for each row
  execute function public.waitlist_on_insert();
