# AeroPath v1.3 — Session Workflow

AeroPath is a lightweight simulator operations portal built with React, Vite and Supabase.

## v1.3 adds

- Booking-linked student pre-flight preparation
- Student session history
- Optional student NavLog / other flight uploads per session
- Instructor/admin session review
- Instructor/admin session-specific file uploads
- Pre-flight approval / changes requested workflow
- Training programme assignment (RPC, JAP, YAP seeded; administrators can add more later)
- Programme comments
- Separate printable instructor/admin training history
- Students cannot read internal instructor training comments/records

## Deploying v1.3 to the existing AeroPath project

1. Keep the existing Supabase project and Vercel project.
2. Run `supabase/migrations_v1.3_session_workflow.sql` once in Supabase SQL Editor after the v1.2 migration.
3. Upload the v1.3 project files to the connected GitHub repository and commit to `main`.
4. Vercel will redeploy automatically.
5. Test with one STUDENT and one INSTRUCTOR account.

Do not rerun the original `schema.sql` or `seed.sql` against the existing production database.

## Supabase environment variables

Set these in Vercel:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

## Stage 2 workflow

Student:

`Booking → My Sessions → Pre-flight Preparation → Optional NavLog/Other Files → Submit`

Instructor/Admin:

`Session Review → View Preparation → View Student Files → Approve / Request Changes → Add Training Record → Training History`

## v1.4 — Instructor session lifecycle
Run `supabase/migrations_v1.4_session_lifecycle.sql` after v1.3. v1.5 requires no database changes; approving a submitted pre-flight preparation now also confirms a REQUESTED booking. Instructors start a confirmed booking with **I am starting this session now**, complete the session review, and submit it through an irreversible confirmation. A submitted session becomes `COMPLETED` and creates the locked training record. An instructor cannot start a second session while one is `IN_PROGRESS`.
