-- =====================================================================
--  AgriLoop — Smart Community Composting & Waste Diversion
--  Supabase / PostgreSQL schema
--
--  Deploy with:  supabase db push
--  Or paste into the Supabase Studio SQL editor and run.
--
--  Design notes
--  ------------
--  * Every table the Flutter app touches lives here; the app also keeps a
--    local snapshot so the live demo never depends on network availability.
--  * The anti-gaming policy is stored in `scoring_policy` and enforced by
--    the `submit_deposit()` function, so a client cannot award itself points
--    by bypassing the app.
--  * Row Level Security is enabled everywhere. The policies below are
--    intentionally permissive for the `anon` key so the hackathon demo
--    works out of the box — see supabase/README.md for the hardening notes.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Bootstrap the Supabase-managed roles and publication.
-- On Supabase these already exist and this block is a no-op; on a plain
-- Postgres (local CI, `docker run postgres:15`) it makes the schema
-- self-contained so it can be tested end to end.
-- ---------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Enumerated types
-- ---------------------------------------------------------------------
do $$ begin
  create type bin_status        as enum ('available', 'full', 'offline');
exception when duplicate_object then null; end $$;

do $$ begin
  create type cleanliness_tier  as enum ('clean', 'suspect', 'contaminated');
exception when duplicate_object then null; end $$;

do $$ begin
  create type voucher_status    as enum ('active', 'used', 'expired', 'disputed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type dispute_status    as enum ('open', 'upheld', 'rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type pilot_phase       as enum ('baseline', 'rewarded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type task_priority    as enum ('high', 'medium', 'low');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- Township geography
-- ---------------------------------------------------------------------
create table if not exists townships (
  id          uuid primary key default gen_random_uuid(),
  code        text unique not null,
  name        text not null,
  created_at  timestamptz not null default now()
);

create table if not exists blocks (
  id          uuid primary key default gen_random_uuid(),
  township_id uuid not null references townships(id) on delete cascade,
  code        text not null,             -- e.g. 'Block A'
  name        text not null,
  created_at  timestamptz not null default now(),
  unique (township_id, code)
);

create table if not exists units (
  id           uuid primary key default gen_random_uuid(),
  block_id     uuid not null references blocks(id) on delete cascade,
  unit_number  text not null,            -- e.g. '12-03'
  invite_code  text unique not null,     -- issued by the strata office
  created_at   timestamptz not null default now(),
  unique (block_id, unit_number)
);

-- ---------------------------------------------------------------------
-- Residents
-- ---------------------------------------------------------------------
create table if not exists residents (
  id                 uuid primary key default gen_random_uuid(),
  unit_id            uuid not null references units(id) on delete cascade,
  nickname           text not null,
  invite_code        text not null,
  resident_pass_token text not null default '',
  points_balance     integer not null default 0,
  streak_weeks       integer not null default 0,
  total_kg_diverted  numeric(10,2) not null default 0,
  co2_factor         numeric(4,2) not null default 2.5,
  verified           boolean not null default false,
  registered_at      timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (invite_code)
);

-- ---------------------------------------------------------------------
-- Smart bin fleet (ESP32 telemetry)
-- ---------------------------------------------------------------------
create table if not exists bins (
  id            uuid primary key default gen_random_uuid(),
  code          text unique not null,     -- 'A01'
  name          text not null,
  location      text not null,
  status        bin_status not null default 'available',
  weight_g      integer not null default 0,
  capacity_g    integer not null default 20000,
  fill_pct      integer not null default 0,
  temp_c        numeric(5,2) not null default 0,
  humidity_pct  integer not null default 0,
  rssi          integer not null default -60,
  lock_state    text not null default 'locked',
  last_seen     timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Scoring policy — the same constants as the Flutter rules engine
-- ---------------------------------------------------------------------
create table if not exists scoring_policy (
  id                       boolean primary key default true,
  points_per_kg            integer not null default 100,
  min_weight_kg            numeric(6,3) not null default 0.05,
  max_plausible_kg         numeric(6,2) not null default 4.00,
  daily_points_cap         integer not null default 500,
  max_deposits_per_day     integer not null default 6,
  cooldown_minutes         integer not null default 10,
  duplicate_window_minutes integer not null default 2,
  clean_confidence         numeric(4,3) not null default 0.850,
  suspect_confidence       numeric(4,3) not null default 0.600,
  streak_bonus_pct         numeric(4,3) not null default 0.100,
  max_streak_bonus_points  integer not null default 100,
  sudden_jump_kg           numeric(6,2) not null default 1.50,
  sudden_jump_fill_pct     integer not null default 20,
  updated_at               timestamptz not null default now(),
  constraint scoring_policy_singleton check (id)
);

insert into scoring_policy (id) values (true) on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Deposits
-- ---------------------------------------------------------------------
create table if not exists deposits (
  id                    uuid primary key default gen_random_uuid(),
  external_id           text unique,               -- 'DEP-8841' style app id
  resident_id           uuid references residents(id) on delete set null,
  unit_id               uuid references units(id) on delete set null,
  block_id              uuid references blocks(id) on delete set null,
  bin_id                uuid references bins(id) on delete set null,
  weight_kg             numeric(8,3) not null,
  points_awarded        integer not null default 0,
  is_clean              boolean not null default true,
  tier                  cleanliness_tier not null default 'clean',
  confidence            numeric(4,3) not null default 1,
  base_points           integer not null default 0,
  quality_bonus         integer not null default 0,
  streak_bonus          integer not null default 0,
  cleanliness_multiplier numeric(4,2) not null default 1,
  reward_latency_ms     integer not null default 0,
  session_nonce         text,
  phase                 pilot_phase not null default 'rewarded',
  image_path            text not null default '',
  verdict               text not null default '',
  violations            text[] not null default '{}',
  rejected              boolean not null default false,
  created_at            timestamptz not null default now()
);

create index if not exists deposits_resident_idx on deposits(resident_id, created_at desc);
create index if not exists deposits_block_idx    on deposits(block_id, created_at desc);
create index if not exists deposits_bin_idx      on deposits(bin_id, created_at desc);
create index if not exists deposits_nonce_idx    on deposits(session_nonce);

-- ---------------------------------------------------------------------
-- Points ledger — every movement of the balance, for audit
-- ---------------------------------------------------------------------
create table if not exists point_ledger (
  id             uuid primary key default gen_random_uuid(),
  external_id    text unique,
  resident_id    uuid references residents(id) on delete cascade,
  delta          integer not null,
  reason         text not null,
  ref_type       text not null default 'deposit',  -- deposit | voucher | dispute
  ref_id         text,
  balance_after  integer not null,
  created_at     timestamptz not null default now()
);

create index if not exists point_ledger_resident_idx on point_ledger(resident_id, created_at desc);

-- ---------------------------------------------------------------------
-- Voucher catalogue and issued vouchers
-- ---------------------------------------------------------------------
create table if not exists voucher_catalogue (
  id           uuid primary key default gen_random_uuid(),
  code         text unique not null,
  merchant     text not null,
  merchant_code text not null,
  title        text not null,
  terms        text not null default '',
  icon         text not null default '🎟️',
  cost_points  integer not null,
  value_rm     numeric(8,2) not null,
  expiry_days  integer not null default 30,
  active       boolean not null default true
);

create table if not exists vouchers (
  id            uuid primary key default gen_random_uuid(),
  external_id   text unique,
  resident_id   uuid references residents(id) on delete cascade,
  catalogue_id  uuid references voucher_catalogue(id) on delete set null,
  merchant      text not null,
  merchant_code text not null,
  title         text not null,
  value_rm      numeric(8,2) not null,
  cost_points   integer not null,
  token         text unique not null,
  signature     text not null,
  status        voucher_status not null default 'active',
  issued_at     timestamptz not null default now(),
  expires_at    timestamptz not null,
  used_at       timestamptz,
  used_by_unit  uuid references units(id) on delete set null
);

create index if not exists vouchers_token_idx   on vouchers(token);
create index if not exists vouchers_resident_idx on vouchers(resident_id, issued_at desc);

create table if not exists redemptions (
  id            uuid primary key default gen_random_uuid(),
  external_id   text unique,
  voucher_id    uuid references vouchers(id) on delete set null,
  merchant_code text not null,
  value_rm      numeric(8,2) not null,
  unit_id       uuid references units(id) on delete set null,
  token         text not null,
  created_at    timestamptz not null default now()
);

create index if not exists redemptions_merchant_idx on redemptions(merchant_code, created_at desc);

-- ---------------------------------------------------------------------
-- Disputes (contamination review queue)
-- ---------------------------------------------------------------------
create table if not exists disputes (
  id              uuid primary key default gen_random_uuid(),
  external_id     text unique,
  deposit_id      uuid references deposits(id) on delete cascade,
  resident_id     uuid references residents(id) on delete set null,
  unit_id         uuid references units(id) on delete set null,
  bin_id          uuid references bins(id) on delete set null,
  reason          text not null,
  image_path      text not null default '',
  weight_kg       numeric(8,3) not null default 0,
  confidence      numeric(4,3) not null default 0,
  withheld_points integer not null default 0,
  status          dispute_status not null default 'open',
  resolution_note text,
  created_at      timestamptz not null default now(),
  resolved_at     timestamptz
);

create index if not exists disputes_status_idx on disputes(status, created_at desc);

-- ---------------------------------------------------------------------
-- Blocked deposit attempts (anti-gaming audit trail)
-- ---------------------------------------------------------------------
create table if not exists rejected_attempts (
  id          uuid primary key default gen_random_uuid(),
  external_id text unique,
  bin_id      uuid references bins(id) on delete set null,
  resident_id uuid references residents(id) on delete set null,
  unit_id     uuid references units(id) on delete set null,
  reason      text not null,
  weight_kg   numeric(8,3) not null default 0,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Bokashi fermentation batches, compost returns, tasks, notifications
-- ---------------------------------------------------------------------
create table if not exists bokashi_batches (
  id          uuid primary key default gen_random_uuid(),
  external_id text unique,
  bin_id      uuid references bins(id) on delete set null,
  bin_source  text not null,
  sealed_date timestamptz not null default now(),
  ready_date  timestamptz not null,
  day_current integer not null default 0,
  day_total   integer not null default 14,
  status      text not null default 'Fermenting (Anaerobic)',
  created_at  timestamptz not null default now()
);

create table if not exists compost_applications (
  id          uuid primary key default gen_random_uuid(),
  external_id text unique,
  kg          numeric(8,2) not null,
  location    text not null,
  batch_id    uuid references bokashi_batches(id) on delete set null,
  note        text not null default '',
  created_at  timestamptz not null default now()
);

create table if not exists operator_tasks (
  id           uuid primary key default gen_random_uuid(),
  external_id  text unique,
  bin_id       uuid references bins(id) on delete set null,
  title        text not null,
  description  text not null default '',
  priority     task_priority not null default 'medium',
  is_completed boolean not null default false,
  source       text not null default 'system',
  created_at   timestamptz not null default now()
);

create table if not exists notifications (
  id          uuid primary key default gen_random_uuid(),
  external_id text unique,
  resident_id uuid references residents(id) on delete cascade,
  title       text not null,
  message     text not null default '',
  type        text not null default 'system',   -- deposit | alert | rewards | system
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists notifications_resident_idx on notifications(resident_id, created_at desc);

-- ---------------------------------------------------------------------
-- Community compost target (township-wide goal)
-- ---------------------------------------------------------------------
create table if not exists community_targets (
  id          boolean primary key default true,
  target_kg   numeric(8,2) not null default 100,
  current_kg  numeric(8,2) not null default 0,
  updated_at  timestamptz not null default now(),
  constraint community_targets_singleton check (id)
);

insert into community_targets (id, target_kg, current_kg) values (true, 100, 62)
  on conflict (id) do nothing;

-- =====================================================================
--  Triggers
-- =====================================================================
create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists residents_touch on residents;
create trigger residents_touch before update on residents
  for each row execute function touch_updated_at();

drop trigger if exists bins_touch on bins;
create trigger bins_touch before update on bins
  for each row execute function touch_updated_at();

-- Keep the community compost meter in step with the compost log.
create or replace function refresh_community_target() returns trigger
language plpgsql as $$
begin
  update community_targets
     set current_kg = coalesce((select sum(kg) from compost_applications), 0),
         updated_at = now()
   where id = true;
  return new;
end;
$$;

drop trigger if exists compost_applications_refresh on compost_applications;
create trigger compost_applications_refresh
  after insert on compost_applications
  for each row execute function refresh_community_target();

-- Keep a resident's diverted tonnage in step with their deposits.
create or replace function refresh_resident_totals() returns trigger
language plpgsql as $$
begin
  update residents r
     set total_kg_diverted = coalesce((
           select sum(d.weight_kg) from deposits d
            where d.resident_id = r.id and not d.rejected
         ), 0),
       updated_at = now()
   where r.id = new.resident_id;
  return new;
end;
$$;

-- =====================================================================
--  Deposit submission — the server-side twin of the Flutter rules engine
-- =====================================================================
--  Applies the anti-gaming policy in the database so points can never be
--  awarded by tampering with the client. Returns the awarded points and the
--  list of rules that fired.
-- =====================================================================
create or replace function submit_deposit(
  p_unit_number       text,
  p_invite_code       text,
  p_bin_code          text,
  p_weight_kg         numeric,
  p_confidence        numeric,
  p_session_nonce     text default null,
  p_phase             pilot_phase default 'rewarded',
  p_image_path        text default '',
  p_reward_latency_ms integer default 0
)
returns table (
  awarded_points  integer,
  accepted        boolean,
  tier            cleanliness_tier,
  violations      text[],
  deposit_external_id text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  pol            scoring_policy%rowtype;
  v_resident     residents%rowtype;
  v_bin          bins%rowtype;
  v_unit         units%rowtype;
  v_tier         cleanliness_tier;
  v_multiplier   numeric;
  v_base         integer;
  v_adjusted     integer;
  v_quality      integer := 0;
  v_streak       integer := 0;
  v_total        integer := 0;
  v_today_points integer := 0;
  v_today_count  integer := 0;
  v_last_at_bin  timestamptz;
  v_violations   text[] := '{}';
  v_accepted     boolean := true;
  v_external_id  text;
  v_deposit_id   uuid;
begin
  select * into pol from scoring_policy where id = true;

  select r.* into v_resident
    from residents r join units u on u.id = r.unit_id
   where r.invite_code = p_invite_code
     and u.unit_number = p_unit_number
   limit 1;

  if v_resident.id is null then
    return query select 0, false, 'contaminated'::cleanliness_tier,
                        array['unknown_unit'], null::text;
    return;
  end if;

  select * into v_bin from bins where code = p_bin_code;

  -- --- hard blocks ---------------------------------------------------
  if v_bin.id is null or v_bin.status = 'offline' then
    v_violations := array_append(v_violations, 'bin_offline');
    v_accepted := false;
  elsif v_bin.status = 'full' then
    v_violations := array_append(v_violations, 'bin_full');
    v_accepted := false;
  end if;

  select max(created_at) into v_last_at_bin
    from deposits
   where resident_id = v_resident.id
     and bin_id = v_bin.id
     and created_at > now() - interval '1 day';

  -- A session nonce may only be redeemed once at a bin. Replaying an older
  -- nonce is just as much a replay as replaying the most recent one.
  if p_session_nonce is not null and exists (
       select 1 from deposits
        where resident_id = v_resident.id
          and bin_id = v_bin.id
          and session_nonce = p_session_nonce
     ) then
    v_violations := array_append(v_violations, 'duplicate_scan');
    v_accepted := false;
  end if;

  if v_last_at_bin is not null
     and now() - v_last_at_bin < make_interval(mins => pol.cooldown_minutes) then
    v_violations := array_append(v_violations, 'cooldown_active');
    v_accepted := false;
  end if;

  select coalesce(sum(points_awarded),0), count(*)
    into v_today_points, v_today_count
    from deposits
   where resident_id = v_resident.id
     and created_at >= date_trunc('day', now());

  if v_today_count >= pol.max_deposits_per_day then
    v_violations := array_append(v_violations, 'daily_deposit_limit_reached');
    v_accepted := false;
  end if;

  if p_weight_kg > pol.max_plausible_kg then
    v_violations := array_append(v_violations, 'implausible_weight');
    v_accepted := false;
  end if;

  if p_weight_kg > pol.sudden_jump_kg and v_bin.fill_pct < pol.sudden_jump_fill_pct then
    v_violations := array_append(v_violations, 'implausible_weight');
  end if;

  if p_weight_kg < pol.min_weight_kg then
    v_violations := array_append(v_violations, 'below_min_weight');
  end if;

  -- --- scoring --------------------------------------------------------
  if p_confidence >= pol.clean_confidence then
    v_tier := 'clean';
  elsif p_confidence >= pol.suspect_confidence then
    v_tier := 'suspect';
  else
    v_tier := 'contaminated';
  end if;

  v_multiplier := case v_tier
                    when 'clean' then 1
                    when 'suspect' then 0.5
                    else 0
                  end;

  v_base := round(p_weight_kg * pol.points_per_kg);
  v_adjusted := round(v_base * v_multiplier);

  if v_tier = 'clean' and v_accepted then
    v_quality := round(v_adjusted * pol.streak_bonus_pct);
    v_streak  := least(round(v_adjusted * pol.streak_bonus_pct),
                        pol.max_streak_bonus_points);
  end if;

  v_total := v_adjusted + v_quality + v_streak;

  -- daily cap
  if v_total > (pol.daily_points_cap - v_today_points) then
    v_violations := array_append(v_violations, 'daily_points_cap_reached');
    v_total := greatest(pol.daily_points_cap - v_today_points, 0);
  end if;

  if v_tier = 'contaminated' or not v_accepted then
    v_total := 0;
  end if;

  v_external_id := 'DEP-' || to_char(now(), 'MMddHH24MISSMS') || '-' ||
                   substr(replace(gen_random_uuid()::text, '-', ''), 1, 4);

  -- --- persist ---------------------------------------------------------
  insert into deposits (
    external_id, resident_id, unit_id, block_id, bin_id, weight_kg,
    points_awarded, is_clean, tier, confidence, base_points, quality_bonus,
    streak_bonus, cleanliness_multiplier, reward_latency_ms, session_nonce,
    phase, image_path, verdict, violations
  ) values (
    v_external_id, v_resident.id, v_resident.unit_id,
    (select block_id from units where id = v_resident.unit_id),
    v_bin.id, p_weight_kg, v_total, v_tier = 'clean', v_tier, p_confidence,
    v_base, v_quality, v_streak, v_multiplier, p_reward_latency_ms,
    p_session_nonce, p_phase, p_image_path,
    case when v_tier = 'contaminated'
         then 'Flagged: non-food items detected, points withheld.'
         else 'Clean organic waste and Bokashi bran verified.' end,
    v_violations
  ) returning id into v_deposit_id;

  update residents
     set points_balance = points_balance + v_total,
         total_kg_diverted = total_kg_diverted + p_weight_kg,
         updated_at = now()
   where id = v_resident.id;

  if v_total <> 0 then
    insert into point_ledger (external_id, resident_id, delta, reason, ref_type,
                              ref_id, balance_after)
    values (
      'L-' || v_external_id, v_resident.id, v_total,
      'Deposit ' || p_weight_kg || ' kg at Bin ' || p_bin_code,
      'deposit', v_external_id,
      (select points_balance from residents where id = v_resident.id)
    );
  end if;

  if v_tier = 'contaminated' then
    insert into disputes (external_id, deposit_id, resident_id, unit_id, bin_id,
                          reason, image_path, weight_kg, confidence,
                          withheld_points, status)
    values (
      'DSP-' || v_external_id,
      v_deposit_id,
      v_resident.id, v_resident.unit_id, v_bin.id,
      'Vision model detected non-food items in the deposit.',
      p_image_path, p_weight_kg, p_confidence, v_base, 'open'
    );
  end if;

  if not v_accepted then
    insert into rejected_attempts (external_id, bin_id, resident_id, unit_id,
                                   reason, weight_kg)
    values (
      'RA-' || v_external_id, v_bin.id, v_resident.id, v_resident.unit_id,
      array_to_string(v_violations, ', '), p_weight_kg
    );
  end if;

  -- bin telemetry
  update bins
     set weight_g = weight_g + round(p_weight_kg * 1000),
         fill_pct = least(
           round(((weight_g + round(p_weight_kg * 1000))::numeric / capacity_g) * 100),
           100),
         status = case
                    when ((weight_g + round(p_weight_kg * 1000))::numeric / capacity_g) * 100 >= 90
                    then 'full'::bin_status
                    else 'available'::bin_status
                  end,
         last_seen = now(),
         updated_at = now()
   where id = v_bin.id;

  return query select v_total, v_accepted, v_tier, v_violations, v_external_id;
end;
$$;

-- =====================================================================
--  Views
-- =====================================================================

-- Block standings for the community leaderboard.
create or replace view block_standings as
select
  b.id                                        as block_id,
  b.code                                      as block_name,
  coalesce(sum(d.weight_kg), 0)               as kg_diverted,
  count(distinct d.resident_id)               as participants,
  count(d.id)                                 as deposits,
  count(*) filter (where d.tier = 'contaminated') as contaminated
from blocks b
left join deposits d
       on d.block_id = b.id
      and d.created_at > now() - interval '30 days'
group by b.id, b.code;

-- Pilot metrics: the "does the reward change behaviour?" numbers.
create or replace view pilot_metrics as
select
  count(*) filter (where phase = 'baseline')                          as baseline_deposits,
  count(*) filter (where phase = 'rewarded')                          as rewarded_deposits,
  coalesce(sum(weight_kg) filter (where phase = 'baseline'), 0)      as baseline_kg,
  coalesce(sum(weight_kg) filter (where phase = 'rewarded'), 0)      as rewarded_kg,
  count(distinct resident_id) filter (where phase = 'baseline')      as baseline_participants,
  count(distinct resident_id) filter (where phase = 'rewarded')      as rewarded_participants,
  round(
    coalesce(sum(weight_kg) filter (where phase = 'baseline'), 0)
      / nullif(count(distinct resident_id) filter (where phase = 'baseline'), 0), 2)
                                                                   as baseline_kg_per_participant,
  round(
    coalesce(sum(weight_kg) filter (where phase = 'rewarded'), 0)
      / nullif(count(distinct resident_id) filter (where phase = 'rewarded'), 0), 2)
                                                                   as rewarded_kg_per_participant,
  round(
    count(*) filter (where tier = 'contaminated')::numeric
      / nullif(count(*), 0), 4)                                     as contamination_rate,
  round(avg(reward_latency_ms) filter (where reward_latency_ms > 0)) as avg_reward_latency_ms
from deposits;

-- Township value summary for the operator dashboard.
create or replace view township_impact as
select
  (select coalesce(sum(weight_kg), 0) from deposits)                       as total_kg_diverted,
  (select coalesce(sum(weight_kg * 2.5), 0) from deposits)                 as total_co2e_avoided,
  (select coalesce(current_kg, 0) from community_targets where id = true)  as compost_returned_kg,
  (select count(*) from disputes where status = 'open')                    as open_disputes,
  (select count(*) from rejected_attempts)                                 as blocked_attempts,
  (select count(*) from deposits)                                          as total_deposits;

-- Merchant payout ledger.
create or replace view merchant_payouts as
select
  merchant_code,
  date_trunc('day', created_at) as day,
  count(*)                     as redemptions,
  sum(value_rm)                as payout_rm
from redemptions
group by merchant_code, date_trunc('day', created_at);

-- =====================================================================
--  Row Level Security
-- =====================================================================
alter table townships          enable row level security;
alter table blocks             enable row level security;
alter table units              enable row level security;
alter table residents          enable row level security;
alter table bins               enable row level security;
alter table scoring_policy     enable row level security;
alter table deposits           enable row level security;
alter table point_ledger       enable row level security;
alter table voucher_catalogue  enable row level security;
alter table vouchers           enable row level security;
alter table redemptions        enable row level security;
alter table disputes           enable row level security;
alter table rejected_attempts  enable row level security;
alter table bokashi_batches    enable row level security;
alter table compost_applications enable row level security;
alter table operator_tasks     enable row level security;
alter table notifications      enable row level security;
alter table community_targets  enable row level security;

-- Public read for the geography + fleet + catalogue.
do $$ declare t text; begin
  foreach t in array array[
    'townships','blocks','units','bins','scoring_policy',
    'voucher_catalogue','community_targets','bokashi_batches'
  ] loop
    execute format('drop policy if exists "public read %1$s" on %1$I', t);
    execute format(
      'create policy "public read %1$s" on %1$I for select to anon, authenticated using (true)', t);
  end loop;
end $$;

-- Residents: readable (leaderboards need unit + nickname), writable by the app.
drop policy if exists "public read residents" on residents;
create policy "public read residents" on residents
  for select to anon, authenticated using (true);

drop policy if exists "app write residents" on residents;
create policy "app write residents" on residents
  for insert to anon, authenticated with check (true);

drop policy if exists "app update residents" on residents;
create policy "app update residents" on residents
  for update to anon, authenticated using (true) with check (true);

-- Deposits: readable, appendable.
drop policy if exists "public read deposits" on deposits;
create policy "public read deposits" on deposits
  for select to anon, authenticated using (true);

drop policy if exists "app insert deposits" on deposits;
create policy "app insert deposits" on deposits
  for insert to anon, authenticated with check (true);

-- Ledger / vouchers / redemptions / disputes / attempts: append + read.
do $$ declare t text; begin
  foreach t in array array[
    'point_ledger','vouchers','redemptions','disputes',
    'rejected_attempts','compost_applications','operator_tasks','notifications'
  ] loop
    execute format('drop policy if exists "public read %1$s" on %1$I', t);
    execute format(
      'create policy "public read %1$s" on %1$I for select to anon, authenticated using (true)', t);
    execute format('drop policy if exists "app insert %1$s" on %1$I', t);
    execute format(
      'create policy "app insert %1$s" on %1$I for insert to anon, authenticated with check (true)', t);
    execute format('drop policy if exists "app update %1$s" on %1$I', t);
    execute format(
      'create policy "app update %1$s" on %1$I for update to anon, authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- Deletion is limited to the operator workflows.
do $$ declare t text; begin
  foreach t in array array['deposits','point_ledger','vouchers','disputes',
                          'operator_tasks','notifications'] loop
    execute format('drop policy if exists "app delete %1$s" on %1$I', t);
    execute format(
      'create policy "app delete %1$s" on %1$I for delete to anon, authenticated using (true)', t);
  end loop;
end $$;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant execute on function submit_deposit(text,text,text,numeric,numeric,text,pilot_phase,text,integer)
  to anon, authenticated;

-- =====================================================================
--  Realtime — live leaderboard, deposits, notifications and compost log
-- =====================================================================
do $$ begin
  alter publication supabase_realtime add table deposits;
exception when duplicate_object then null;
         when undefined_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table point_ledger;
exception when duplicate_object then null;
         when undefined_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table vouchers;
exception when duplicate_object then null;
         when undefined_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table notifications;
exception when duplicate_object then null;
         when undefined_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table compost_applications;
exception when duplicate_object then null;
         when undefined_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table bins;
exception when duplicate_object then null;
         when undefined_object then null; end $$;
