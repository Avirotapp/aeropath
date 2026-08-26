# AeroPath v1.1 — Simulator Scheduler

AeroPath is a React + Vite + Supabase MVP for flight simulator operations.

## Included in this release
- Supabase authentication
- Student role-based portal
- Four seeded simulator types:
  - Cessna 172 G1000
  - Diamond DA20 Analogue
  - ATC Simulator
  - VR Simulator
- Weekly simulator scheduler
- Simulator/date/status filters
- Booking request modal
- 30/60/90/120/180 minute sessions
- Booking overlap protection through the existing Supabase trigger
- Student booking list and cancellation
- Instructor/administrator request confirmation and cancellation UI
- Responsive calendar layout
- Existing progress, documents, safety, modules and audit foundations

## Deploy
The project is designed for Vercel.

Environment variables:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

The database schema and seed data are in `supabase/schema.sql` and `supabase/seed.sql`.

## Important
The scheduler uses the existing `bookings` table and its database-level overlap trigger. It does not claim to implement instructor availability rules, recurring schedules, email notifications, or advanced calendar administration yet. Those can be added as later AeroPath modules.
