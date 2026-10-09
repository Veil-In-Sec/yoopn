-- YooPN production telemetry (analytics + crash reports).
-- Run once in Supabase Dashboard → SQL editor → New query → Run.
-- Tables are INSERT-only from the app; review rows in Table editor / SQL.

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id text,
  session_id text,
  event text not null,
  props jsonb not null default '{}'::jsonb,
  platform text,
  app_version text
);

create table if not exists public.crash_reports (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id text,
  session_id text,
  error text not null,
  stack text,
  context jsonb not null default '{}'::jsonb,
  platform text,
  app_version text,
  fatal boolean not null default true
);

create index if not exists analytics_events_created_idx
  on public.analytics_events (created_at desc);
create index if not exists analytics_events_event_idx
  on public.analytics_events (event, created_at desc);
create index if not exists crash_reports_created_idx
  on public.crash_reports (created_at desc);

alter table public.analytics_events enable row level security;
alter table public.crash_reports enable row level security;

-- App clients (anon + logged-in) may only INSERT. Reads happen in the
-- dashboard, which uses a privileged role that bypasses RLS.
drop policy if exists "app insert events" on public.analytics_events;
create policy "app insert events" on public.analytics_events
  for insert to anon, authenticated with check (true);

drop policy if exists "app insert crashes" on public.crash_reports;
create policy "app insert crashes" on public.crash_reports
  for insert to anon, authenticated with check (true);
