#!/usr/bin/env bash
# Prove that the public anon key cannot read waitlist rows.
# Usage: SUPABASE_URL=... SUPABASE_ANON_KEY=... ./scripts/verify-rls.sh
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY}"

email="rls-proof-$(date +%s)@example.com"
base="${SUPABASE_URL%/}/rest/v1/waitlist"
auth_headers=(
  -H "apikey: ${SUPABASE_ANON_KEY}"
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}"
)

echo "== 1. Insert a row so an empty table cannot fake a passing read test"
insert_code=$(curl -sS -o /tmp/waitlist-insert-body -w "%{http_code}" -X POST \
  "${base}?on_conflict=email" \
  "${auth_headers[@]}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=ignore-duplicates,return=minimal" \
  -d "{\"email\":\"${email}\"}")

echo "INSERT HTTP ${insert_code}"
if [[ "${insert_code}" != "201" && "${insert_code}" != "200" ]]; then
  echo "Insert failed. Body:"
  cat /tmp/waitlist-insert-body
  echo
  echo "If this is 401/403, RLS or grants are blocking writes. Check schema.sql."
  exit 1
fi

echo
echo "== 2. Read as a stranger (anon key, no extra privileges)"
read_body=$(curl -sS -w "\n%{http_code}" \
  "${base}?select=*" \
  "${auth_headers[@]}")
read_code=$(echo "${read_body}" | tail -n1)
read_json=$(echo "${read_body}" | sed '$d')

echo "SELECT HTTP ${read_code}"
echo "Body: ${read_json}"

if [[ "${read_json}" == "[]" ]]; then
  echo
  echo "PASS: anon reads return an empty list. RLS is on and there is no SELECT policy."
  echo "Note: an empty *table* with RLS off also returns []. This script inserts first, so this is a real pass."
  exit 0
fi

echo
echo "FAIL: anon was able to read rows. RLS is off or a SELECT policy exists."
echo "Do not ship this. Fix schema.sql and re-run it in the SQL editor."
exit 1
