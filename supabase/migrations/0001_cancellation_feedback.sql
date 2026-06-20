-- Cancellation feedback captured before sending users to Apple's subscription page.
-- Run this in the Supabase SQL editor (or via `supabase db push`).

create table if not exists public.cancellation_feedback (
    id          uuid primary key default gen_random_uuid(),
    device_id   text,
    reason      text not null,
    details     text,
    app_version text,
    created_at  timestamptz not null default now()
);

-- Lock it down: only the service role can read; the app's anon key may insert.
alter table public.cancellation_feedback enable row level security;

drop policy if exists "anon can insert cancellation feedback" on public.cancellation_feedback;
create policy "anon can insert cancellation feedback"
    on public.cancellation_feedback
    for insert
    to anon
    with check (true);

-- Handy view of recent reasons (read from the dashboard with the service role).
create index if not exists cancellation_feedback_created_at_idx
    on public.cancellation_feedback (created_at desc);
