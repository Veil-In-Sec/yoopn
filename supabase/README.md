# YooPN Supabase telemetry — production logs & crashes

The app has no Firebase; production observability is two Postgres tables
populated by `lib/core/telemetry/supabase_telemetry.dart`:

- `analytics_events` — product events (`app_open`, `vpn_connect_started`,
  `vpn_connected`, `vpn_connect_failed`, `vpn_disconnect`, `vpn_cancelled`,
  auth + speed-test events below)
- `crash_reports` — uncaught Flutter/async errors + tracked failures

## One-time setup

1. Supabase Dashboard → SQL editor → paste + Run
   `supabase/migrations/001_app_telemetry.sql`.
2. Verify client writes are actually accepted:

   ```bash
   ./supabase/probe.sh   # both inserts must print HTTP 201 OK
   ```

   If either line prints `42501 … violates row-level security policy`,
   also run `supabase/migrations/002_fix_telemetry_rls.sql` (grants +
   `for insert to public` policies). Verified working 2026-10-09 against
   project `hgkfktsboopvqnobypjq`.
3. Confirm both tables exist in Table editor.

   Cleanup: `probe.sh` inserts rows with `event = '__probe__'` /
   `error = '__probe__'`. Clients have INSERT-only access, so delete them
   from Table editor (or SQL editor):

   ```sql
   delete from analytics_events where event = '__probe__';
   delete from crash_reports where error = '__probe__';
   ```
4. Ship the app (release build). Events appear within seconds of user action.

## Review queries

```sql
-- Latest crashes first
select created_at, error, context, platform, app_version
from crash_reports order by created_at desc limit 50;

-- VPN failures today (which stage do slow relays die at?)
select created_at, props->>'server' as server,
       props->>'stage' as stage, props->>'error' as error
from analytics_events
where event = 'vpn_connect_failed'
  and created_at > now() - interval '1 day'
order by created_at desc;

-- Connect success rate per day
select date_trunc('day', created_at) as day,
  count(*) filter (where event = 'vpn_connected') as connected,
  count(*) filter (where event = 'vpn_connect_failed') as failed
from analytics_events
where event in ('vpn_connected', 'vpn_connect_failed')
group by 1 order by 1 desc;

-- One session, in order (pass session_id from a crash row)
select created_at, event, props from analytics_events
where session_id = '<session-id>' order by created_at;
```

## Event catalogue

| event | props |
|---|---|
| `app_open` | platform, debug |
| `auth_success` / `auth_failed` | method (password/google/otp), email (masked) |
| `vpn_connect_started` | server |
| `vpn_connected` | server, elapsed_s |
| `vpn_connect_failed` | server, error, stage, elapsed_s |
| `vpn_disconnect` / `vpn_cancelled` | server |
| `screen_view` | screen (name from `AppPages`) |

## What is captured

* `lib/main.dart` — `FlutterError.onError`, `PlatformDispatcher.onError` and
  `runZonedGuarded` all report to `crash_reports` (fatal + init/zone context).
* `lib/core/telemetry/telemetry_navigator_observer.dart` — `screen_view` per route
  (registered as a `go_router` observer in `lib/core/routes/app_routes.dart`).
* `lib/features/dashboard/presentation/bloc/vpn_bloc.dart` — VPN lifecycle,
  including the sub-stage a failed relay died at (`props->>'stage'`).
* `lib/features/auth/presentation/bloc/auth_bloc.dart` — sign-in/up/OTP/Google
  outcomes.

## Privacy

Emails are masked (`joh***@mail.com`); passwords, OTPs, tokens and
`.ovpn` configs are never sent. Rows are INSERT-only from clients.
