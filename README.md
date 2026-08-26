# AeroPath v1

React + Vite + Supabase MVP for AeroPath.

## Quick start
1. Create a Supabase project.
2. Run `supabase/schema.sql` in Supabase SQL Editor.
3. Run `supabase/seed.sql`.
4. Copy `.env.example` to `.env` and add your Supabase URL and anon key.
5. Run `npm install` then `npm run dev`.
6. Push the folder to GitHub and import it into Vercel for public deployment.

New accounts default to STUDENT. For development, change roles in the Supabase `profiles` table.

This is a functional MVP foundation. Advanced pre-flight approval, full ESMS workflow, advanced admin controls and production hardening are later modules.
