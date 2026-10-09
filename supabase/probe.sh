#!/usr/bin/env bash
# Verify YooPN telemetry end-to-end from the command line.
#
#   ./supabase/probe.sh              # insert probes + report counts
#
# Reads SUPABASE_URL / SUPABASE_ANON_KEY from .env (no secrets printed).
# After a fix, both probes must return 201 and the counts must be >= 1.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

[ -f .env ] || { echo "missing .env"; exit 1; }
URL=$(grep -E '^SUPABASE_URL=' .env | cut -d= -f2- | tr -d '\r')
KEY=$(grep -E '^SUPABASE_ANON_KEY=' .env | cut -d= -f2- | tr -d '\r')
[ -n "$URL" ] && [ -n "$KEY" ] || { echo "missing SUPABASE_URL/ANON_KEY"; exit 1; }

REST="$URL/rest/v1"
AUTH=(-H "apikey: $KEY" -H "Authorization: Bearer $KEY")
JSON=(-H "Content-Type: application/json" -H "Prefer: return=minimal")

probe() {
  local table=$1 payload=$2 code body
  body=$(mktemp)
  code=$(curl -s --max-time 10 -o "$body" -w '%{http_code}' \
    -X POST "$REST/$table" "${AUTH[@]}" "${JSON[@]}" -d "$payload")
  printf '%-18s insert -> HTTP %s' "$table" "$code"
  if [ "$code" != "201" ]; then printf '  %s\n' "$(head -c 200 "$body")"; rm -f "$body"; return 1; fi
  echo ' OK'
  rm -f "$body"
}

echo "== inserts =="
probe analytics_events "{\"event\":\"__probe__\",\"props\":{\"probe\":true},\"platform\":\"probe\"}"
probe crash_reports     "{\"error\":\"__probe__\",\"stack\":\"probe\",\"context\":{\"probe\":true}}"

echo
echo "== counts (dashboard SQL) =="
echo "  select count(*) from analytics_events;"
echo "  select count(*) from crash_reports;"
echo
echo "Note: probes are visible in Table editor; delete rows where"
echo "      event = '__probe__' or error = '__probe__' when done."