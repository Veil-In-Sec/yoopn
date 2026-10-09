-- 002: fix telemetry RLS so app inserts are accepted.
--
-- Probe (2026-10-09) showed the tables exist but every client insert fails:
--   {"code":"42501","message":"new row violates row-level security policy"}
-- i.e. RLS is enabled but the insert policy is missing (or bound to the wrong
-- role) for the `anon` role that publishable keys resolve to.
--
-- Run this once in Supabase Dashboard → SQL editor → Run. Idempotent.

grant usage on schema public to anon, authenticated;

grant insert on table public.analytics_events to anon, authenticated;
grant insert on table public.crash_reports to anon, authenticated;

-- Recreate policies bound to `public` (covers anon + authenticated) instead
-- of naming roles, so new-style `sb_publishable_…` keys cannot miss them.
drop policy if exists "app insert events" on public.analytics_events;
create policy "app insert events" on public.analytics_events
  for insert to public with check (true);

drop policy if exists "app insert crashes" on public.crash_reports;
create policy "app insert crashes" on public.crash_reportsplease 
  for insert to public with check (true);

-- Backfill any rows that failed while the policy was missing is not possible
-- (they were rejected before insert); only future events are captured.

-- Optional: allow reads for authenticated users (e.g. your own dashboard
-- backend). Leave commented out so clients cannot read the raw data.
-- create policy "auth read own events" on public.analytics_events
--   for select to authenticated using (auth.uid()::text = user_id);