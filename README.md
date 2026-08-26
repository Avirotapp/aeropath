# AeroPath v1.6 — Instructor Session Lifecycle Patch

This release fixes legacy bookings that were already APPROVED for pre-flight before the v1.5 confirmation flow was deployed.

When an instructor/admin opens a booking that is still REQUESTED but whose pre-flight preparation is already APPROVED, AeroPath automatically reconciles the booking to CONFIRMED. The normal v1.5 approval flow remains unchanged.

Session start does not require the scheduled time to be in the future; instructors can start a confirmed session after its scheduled time if the session has not been started/completed.

No new database migration is required.
