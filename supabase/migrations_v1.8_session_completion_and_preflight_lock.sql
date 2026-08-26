-- AeroPath v1.8: reliable session finalization + immutable submitted pre-flight
-- Run once after v1.7.

-- Prevent a student from changing a submitted/approved preparation even if
-- future policies are broadened. Staff may still change the workflow state.
create or replace function public.enforce_preflight_submission_lock()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if public.my_role() = 'STUDENT'
     and old.status in ('SUBMITTED','APPROVED') then
    raise exception 'This pre-flight preparation has already been submitted and is locked.';
  end if;
  return new;
end;
$$;

drop trigger if exists preflight_submission_lock on public.preflight_preparations;
create trigger preflight_submission_lock
before update on public.preflight_preparations
for each row execute function public.enforce_preflight_submission_lock();

-- Reliable, atomic finalization. This replaces the v1.4 implementation.
-- The function explicitly disables RLS for its own transaction because it is
-- the trusted server-side workflow boundary, while all caller/ownership checks
-- remain explicit below.
create or replace function public.submit_simulator_session(
  p_booking_id uuid,
  p_lesson_title text,
  p_duration_minutes integer,
  p_grade integer default null,
  p_comments text default null
)
returns uuid
language plpgsql
security definer
set search_path=public
set row_security=off
as $$
declare
  b public.bookings;
  record_id uuid;
begin
  if public.my_role() not in ('INSTRUCTOR','ADMINISTRATOR') then
    raise exception 'Only instructors or administrators can submit simulator sessions.';
  end if;

  if nullif(trim(p_lesson_title),'') is null then
    raise exception 'Training activity / lesson is required.';
  end if;
  if p_duration_minutes is null or p_duration_minutes < 0 then
    raise exception 'Duration must be zero or greater.';
  end if;
  if p_grade is not null and (p_grade < 1 or p_grade > 5) then
    raise exception 'Grade must be between 1 and 5.';
  end if;

  -- Lock the booking for the entire operation so the training record and
  -- booking completion cannot diverge.
  select * into b
  from public.bookings
  where id = p_booking_id
  for update;

  if not found then
    raise exception 'Booking not found.';
  end if;

  if b.session_status <> 'IN_PROGRESS' then
    raise exception 'Only an in-progress session can be submitted. Current session status: %', b.session_status;
  end if;

  if b.instructor_id <> auth.uid() and public.my_role() <> 'ADMINISTRATOR' then
    raise exception 'This session is assigned to another instructor.';
  end if;

  if exists(select 1 from public.training_records where booking_id = p_booking_id) then
    raise exception 'A training record already exists for this booking.';
  end if;

  insert into public.training_records(
    student_id,
    instructor_id,
    booking_id,
    simulator_id,
    session_date,
    lesson_title,
    duration_minutes,
    grade,
    comments
  )
  values(
    b.student_id,
    coalesce(b.instructor_id, auth.uid()),
    b.id,
    b.simulator_id,
    coalesce(b.session_started_at, now())::date,
    trim(p_lesson_title),
    p_duration_minutes,
    p_grade,
    nullif(trim(p_comments), '')
  )
  returning id into record_id;

  -- Allow the lifecycle trigger to accept the controlled transition.
  perform set_config('aeropath.session_workflow', 'on', true);

  update public.bookings
  set session_status = 'COMPLETED',
      status = 'COMPLETED',
      session_completed_at = now()
  where id = p_booking_id
    and session_status = 'IN_PROGRESS';

  if not found then
    raise exception 'The session could not be marked completed.';
  end if;

  return record_id;
end;
$$;

revoke all on function public.submit_simulator_session(uuid,text,integer,integer,text) from public;
grant execute on function public.submit_simulator_session(uuid,text,integer,integer,text) to authenticated;
