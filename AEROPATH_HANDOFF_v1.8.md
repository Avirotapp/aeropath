# AeroPath — Project Handoff / Recovery Notes

Snapshot source: `AeroPath_v1.7_Instructor_Session_Confirmation(1).zip` + v1.8 changes
Snapshot date: 27 August 2026 (Singapore time)
Current build: v1.8

## PURPOSE OF THIS FILE

This file is the persistent handoff/context record for future AeroPath builds. Read this before modifying the project. The full source code and Supabase SQL are included in this backup.

Do not rebuild the app from memory. Continue from the code in this archive and preserve existing functionality.

---

# 1. CURRENT PRODUCT

AeroPath is a simulator-training operations web app with role-based dashboards.

Current roles include:
- STUDENT
- INSTRUCTOR
- ADMINISTRATOR
- SAFETY_MANAGER

Instructor/admin workflow is designed around:
- simulator bookings
- student profiles
- programme assignment (e.g. JAP, RPC, YAP, and future programmes)
- student-specific pre-flight preparation
- student/instructor session files
- instructor session reviews
- immutable training records
- printable training history
- documents
- safety / ESMS area

---

# 2. CURRENT SOURCE OF TRUTH

Use these files as the current source of truth:

- `src/main.jsx` — primary React application/UI logic
- `src/styles.css` — styling
- `index.html`
- `package.json`
- `supabase/schema.sql`
- `supabase/migrations_v1.2_instructor_operations.sql`
- `supabase/migrations_v1.3_session_workflow.sql`
- `supabase/migrations_v1.4_session_lifecycle.sql`
- `supabase/migrations_v1.5_preflight_confirmation.sql`
- `supabase/migrations_v1.7_session_confirmation_reconciliation.sql`
- `supabase/seed.sql`

The project uses:
- React
- Vite
- Supabase
- lucide-react

---

# 3. FEATURES ALREADY IMPLEMENTED / VERIFIED

## Instructor dashboard
Instructor can:
- see simulator fleet
- see students
- open student profiles
- access session review
- access training history
- access documents
- access training progress
- access Safety Control Tower
- see bookings

## Student profile
Instructor can open a student profile and see:
- student name
- total simulator hours
- programme selection
- programme comment
- historical simulator session comments/training records

The earlier requested student-training-record workflow exists in the codebase.

## Programme
A student can have a programme such as:
- JAP
- RPC
- YAP
- other future programme values

Programme selection is staff-facing.

## Pre-flight preparation
Each booking has its own preparation.

Current preparation includes the requested copy/paste-style fields:
- Departure ICAO
- Arrival ICAO
- Sunrise
- Sunset
- NOTAM
- METAR
- TAF
- Weight & balance
- Departure take-off run required
- Departure take-off distance required
- Departure TORA
- Departure LDA
- Arrival landing run
- Arrival TORA
- Arrival LDA

Preparation is associated with the specific booking/session.

Student uploads for the booking are also associated with that session.

## Student session files
Students can upload files for a particular booking/session.

Requested optional student uploads include:
- optional navlog
- optional other flight-related uploads
- cross-country paperwork can be uploaded by the student rather than having a dedicated cross-country booking option

Instructor can see student session uploads.

## Instructor session files
Instructor can upload files associated with the specific student session.

Instructor uploads are visible in the session review.

## Student privacy
Students can see:
- past sessions
- their own session uploads
- their own preparation/history

Students must NOT see:
- instructor comments
- internal instructor training comments
- internal staff-only training records/comments

## Training history
There is a separate printable Training History page.

It is intended for:
- instructors
- administrators

It contains the official student training record and is designed to be simple/printable.

Students cannot access internal comments.

## Session lifecycle
Current database lifecycle uses:
- `NOT_STARTED`
- `IN_PROGRESS`
- `COMPLETED`

The intended workflow is:

CONFIRMED
→ instructor starts session
→ IN_PROGRESS
→ instructor submits session review
→ COMPLETED

Database RPCs exist for:
- `start_simulator_session`
- `submit_simulator_session`

The start RPC prevents one instructor from having more than one active session.

A completed session should be immutable.

## Start-session behaviour
The UI now has the working “I am starting this session now” flow.

IMPORTANT: in the current build this start control was placed/implemented around the session workflow, and the user most recently requested that the control be moved to the BOTTOM of the session page in the next build.

The user has already successfully tested that clicking it changes the session to:
- `IN PROGRESS`

## Session review
The instructor session review contains:
- Training activity / lesson
- Duration
- Grade / score
- Instructor comments

The app displays a confirmation prompt:

“Are you sure you want to submit the session review?

Once submitted it can no longer be edited. Please make sure the training activity, duration, grade and instructor comments are correct.”

The intended result is:
- save official training record
- lock the review
- change booking to COMPLETED

---

# 4. v1.8 BUILD CORRECTION

The first v1.8 frontend package contained a JavaScript syntax error in `src/main.jsx` at the session-review confirmation prompt. The confirmation message had a literal line break inside a single-quoted JavaScript string, causing Vite to report `Unterminated string`.

The corrected source now uses escaped newline characters (`\n\n`) in the confirmation string. This is a source/build correction only; no additional Supabase migration is required.

The intended finalization workflow remains:

1. Session is `IN_PROGRESS`.
2. Instructor completes the session review.
3. Confirmation dialog appears.
4. Confirming calls `submit_simulator_session`.
5. The trusted RPC inserts the training record and changes the booking to `COMPLETED` in one transaction.
6. The UI reloads the booking and displays the locked completed record.

If Vercel reports a runtime/database error after this syntax correction, capture the exact error before changing the database.

This means the finalization path is currently not completing successfully.

The relevant client code in `src/main.jsx` calls:

`supabase.rpc('submit_simulator_session', {...})`

The relevant SQL is in:

`supabase/migrations_v1.4_session_lifecycle.sql`

The RPC is intended to:
1. lock the booking
2. verify IN_PROGRESS
3. insert into `training_records`
4. update booking to:
   - `session_status = 'COMPLETED'`
   - `status = 'COMPLETED'`
   - `session_completed_at = now()`
5. return the training record ID

DO NOT assume the UI is the root cause.

Next build should first diagnose why the RPC is failing or why the UI is not reflecting its result.

Likely investigation order:
1. Confirm the v1.4 migration/RPC is actually installed in the deployed Supabase project.
2. Check the exact Supabase RPC error returned by `submit_simulator_session`.
3. Check RLS/policies on `training_records`.
4. Check whether the RPC's `INSERT` is permitted under its security-definer context and existing policies.
5. Check whether a trigger/constraint on `training_records` rejects the insert.
6. Check whether the booking update is blocked by the session lifecycle trigger.
7. Verify the client reload/select code updates `selected` after success.
8. Test the entire transaction with a fresh test booking.

Do not simply hide the error.

---

# 5. NEXT BUILD REQUIREMENTS

The user explicitly requested these next:

## A. Move “I am starting this session now”
Put the start-session control at the BOTTOM of the instructor session page, after the preparation/files area and before/around the session review area as appropriate.

The user specifically said:
“lets put i am starting this session now at the bottom.”

## B. Student pre-flight submission becomes locked
When a student submits preparation for review:

Change the student page to a state similar to:

**Pre-flight sent!**

Then display the exact submitted values, including:
- Departure ICAO
- Arrival ICAO
- Sunrise
- Sunset
- NOTAM
- METAR
- TAF
- Weight & balance
- performance values

After submission:
- student cannot edit
- student cannot draft/edit the submitted preparation
- student cannot submit it again
- the submitted preparation remains visible as read-only

## C. Instructor review of student preparation
Instructor sees the submitted preparation for that exact booking/session.

If a “request changes” workflow is added later, preserve auditability and avoid silently overwriting a previously submitted preparation.

## D. Final session submission
Once instructor submits the final session review:
- confirmation
- training record created
- booking becomes COMPLETED
- session becomes immutable
- instructor form disappears
- completed record is shown
- student training hours update
- training history includes the record
- session list shows COMPLETED

## E. No overlapping instructor sessions
Already intended/implemented:
- instructor cannot start a second session while another session is IN_PROGRESS

Preserve this rule.

---

# 6. IMPORTANT USER REQUIREMENTS / PRODUCT DECISIONS

These are deliberate product decisions and should not be accidentally removed:

- No dedicated cross-country booking option.
- Students may optionally upload a navlog.
- Students may optionally upload other flight files for that particular booking.
- Each booking has its own preparation and files.
- Instructors can see previous simulator-session comments from previous instructors.
- Instructors can add training records.
- Instructors can see files uploaded by CFI/admin for reference where permitted by the document/session design.
- Administrators can access all instructor features plus administrative/training-history functions.
- Students can see their own past sessions/uploads but not instructor comments.
- Training history should have a simple printable view.
- Safety Control Tower is planned as an ESMS area, not merely a generic safety page.
- Safety Control Tower landing page should emphasize ESMS and the Four Pillars of the SMS Framework.
- Planned ESMS framework should let students/instructors log:
  - incidents
  - accidents
  - occurrences
  - OSHE reports
  using a simple ICAO-standard-style reporting matrix/framework.
- Keep the ESMS feature simple initially; it is a framework, not a full enterprise SMS product.

---

# 7. DATABASE / SECURITY PRINCIPLES

Preserve the existing server-side workflow.

Important RPCs:
- `start_simulator_session(p_booking_id uuid)`
- `submit_simulator_session(p_booking_id uuid, p_lesson_title text, p_duration_minutes integer, p_grade integer, p_comments text)`
- `reconcile_booking_confirmation(p_booking_id uuid)`

The booking session lifecycle is protected by a trigger:
`enforce_session_lifecycle`

Do not bypass this with client-side direct status updates.

Training records are intended to be append-only.

Do not give instructors a normal UPDATE/DELETE path for official submitted training records.

---

# 8. LEGACY BOOKING RECONCILIATION

v1.7 added:

`reconcile_booking_confirmation(p_booking_id uuid)`

Purpose:
If a legacy booking is:
- `REQUESTED`
while its pre-flight preparation is already:
- `APPROVED`

then staff can reconcile it to:
- `CONFIRMED`

This exists because the confirmation workflow was introduced after some older test bookings.

---

# 9. CURRENT TEST DATA / TEST STATE

The test environment has included:
- Student: `Tung Tung Sahur`
- Instructor: `Test Boy`
- Simulator: `ATC-01`
- Simulator: `C172-01`
- Programme: `JAP`

A historical training record exists for the test student:
- Familiarisation Flight
- C172-01
- 60 min
- Instructor: Test Boy
- Grade 3
- comments describing basic cockpit familiarisation

There is also an active test session that was started successfully and reached:
- `IN PROGRESS`

The latest failure occurred when submitting its instructor session review.

Do not treat these test records as production requirements; they are test fixtures/state.

---

# 10. FILE STRUCTURE

Expected project structure:

- `README.md`
- `index.html`
- `package.json`
- `.env.example`
- `src/main.jsx`
- `src/styles.css`
- `supabase/schema.sql`
- `supabase/seed.sql`
- `supabase/migrations_v1.2_instructor_operations.sql`
- `supabase/migrations_v1.3_session_workflow.sql`
- `supabase/migrations_v1.4_session_lifecycle.sql`
- `supabase/migrations_v1.5_preflight_confirmation.sql`
- `supabase/migrations_v1.7_session_confirmation_reconciliation.sql`

---

# 11. DEVELOPMENT APPROACH

The user is deploying through GitHub/Vercel/Supabase.

Typical workflow used:
1. Modify source/SQL.
2. Provide updated files/archive.
3. User uploads/commits to GitHub.
4. Vercel deploys.
5. User tests in browser.
6. Iterate.

The user does NOT want to lose existing progress.

Therefore:
- make incremental builds
- do not replace working features unnecessarily
- keep migration files
- add new migrations rather than editing already-applied migrations when database changes are needed
- update README/handoff after significant builds
- preserve a complete source backup at each major milestone

---

# 12. RECOVERY RULE

If future conversation context is lost:

1. Open this handoff.
2. Open `src/main.jsx`.
3. Open the latest migration files.
4. Treat the latest numbered migration as the database state to continue from.
5. Verify what is already implemented before proposing duplicate work.
6. Start with the CURRENT KNOWN BUG section if continuing immediately from this snapshot.

The latest source snapshot in this archive is the baseline, not an instruction to revert deployed code.

---

# 13. IMMEDIATE NEXT TASK

**Fix final session submission.**

Do not move on to ESMS or visual redesign until:
- Submit Session Review works
- booking changes to COMPLETED
- training record is created
- form locks
- training history updates
- student hours update
- completed session cannot be restarted

Then implement the student “Pre-flight sent!” locked state and move the instructor start control to the bottom.

---

# 5. v1.8 planned/implemented changes

## Session completion
- The instructor's `I am starting this session now` control is moved to the bottom of the session page.
- The instructor session review remains available only while the booking is `IN_PROGRESS`.
- Final submission uses the `submit_simulator_session` RPC as the single atomic workflow boundary.
- The v1.8 RPC explicitly locks the booking, inserts the training record, then changes both booking status and session status to `COMPLETED`.
- A completed session is immutable from the instructor UI.
- The UI displays a completed-session confirmation and training record summary.
- Submission errors are surfaced directly in the session page instead of silently leaving the user unsure.

## Student pre-flight lock
- Before submission, students can save a draft.
- `Submit for review` changes the preparation to `SUBMITTED`.
- `SUBMITTED` and `APPROVED` preparation is read-only to the student.
- The student sees a clear `Pre-flight sent!` state with the exact submitted values.
- If an instructor chooses `Request changes`, the student can edit and resubmit.
- A database trigger additionally prevents a student from modifying a `SUBMITTED` or `APPROVED` preparation directly.

## v1.8 testing target
1. Existing ATC-01 session is `IN_PROGRESS`.
2. Instructor enters lesson, duration, grade and comments.
3. Confirm `Submit Session Review`.
4. Expect `COMPLETED` in the session list.
5. Expect the training record in Training History.
6. Expect simulator hours to update.
7. Refresh and verify the review cannot be edited.
8. Student submits pre-flight and sees `Pre-flight sent!` with read-only values.
9. Instructor requests changes; student can edit again.
10. Student resubmits; preparation becomes locked again.

## v1.8 implementation status

Implemented in this archive; deployment/testing still required:
- Move instructor session start control to the bottom of the session page.
- Lock student pre-flight UI after SUBMITTED/APPROVED and show submitted values read-only.
- Keep Request Changes as the path back to editable preparation.
- Replace session completion RPC with a server-side atomic finalization implementation that explicitly locks the booking and completes the training record workflow.
- Surface RPC errors to the instructor instead of leaving the UI silently IN PROGRESS.
- Show the completed training record on the completed session page.

Do not mark the session-completion bug fixed until the v1.8 SQL migration has been run and the live ATC-01 test reaches COMPLETED.
