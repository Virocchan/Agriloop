-- =====================================================================
--  AgriLoop — demo / pilot seed data
--
--  Creates one township with three blocks and eight participating units,
--  the smart bin fleet, the voucher catalogue, and two weeks of pilot
--  deposits (week 1 = baseline with no rewards, week 2 = Green Points live)
--  so the leaderboard, pilot metrics and dispute queue all have data the
--  moment the app connects.
--
--  Run after schema.sql:  psql -f seed.sql
--  Re-runnable: it truncates the transactional tables first.
-- =====================================================================

begin;

truncate table
  notifications, operator_tasks, compost_applications, bokashi_batches,
  redemptions, vouchers, voucher_catalogue, rejected_attempts, disputes,
  point_ledger, deposits, residents, units, blocks, townships, bins,
  community_targets, scoring_policy
restart identity cascade;

-- ---------------------------------------------------------------------
-- Scoring policy (tuned to match the Flutter rules engine)
-- ---------------------------------------------------------------------
insert into scoring_policy (id) values (true);

-- ---------------------------------------------------------------------
-- Township, blocks, units
-- ---------------------------------------------------------------------
insert into townships (code, name) values
  ('ELM', 'City of Elmina (Elmina Valley)');

insert into blocks (township_id, code, name)
select id, v.code, v.name from townships t
join (values
  ('Block A', 'Block A · Elmina Green'),
  ('Block B', 'Block B · Central Park West'),
  ('Block C', 'Block C · Clubhouse & Nursery')
) as v(code, name) on true
where t.code = 'ELM';

insert into units (block_id, unit_number, invite_code)
select b.id, v.unit, v.invite
from blocks b
join (values
  ('Block A', '12-03', 'ELM-9921'),
  ('Block A', '08-02', 'ELM-4417'),
  ('Block A', '15-11', 'ELM-7788'),
  ('Block B', '04-01', 'ELM-2056'),
  ('Block B', '09-07', 'ELM-3164'),
  ('Block B', '14-02', 'ELM-7420'),
  ('Block C', '02-05', 'ELM-5502'),
  ('Block C', '11-04', 'ELM-6038'),
  ('Block C', '06-12', 'ELM-8871')
) as v(block_code, unit, invite) on v.block_code = b.code;

-- ---------------------------------------------------------------------
-- Residents
-- ---------------------------------------------------------------------
insert into residents (unit_id, nickname, invite_code, points_balance,
                       streak_weeks, total_kg_diverted, verified, registered_at)
select u.id,
       coalesce(v.nickname, 'Resident ' || u.unit_number),
       u.invite_code,
       coalesce(v.points, 0),
       coalesce(v.streak, 0),
       coalesce(v.kg, 0),
       true,
       now() - interval '20 days'
from units u
join (values
  ('12-03', 'Norah Lee',   1450, 4, 18.4),
  ('08-02', 'Kelvin T.',    980, 3, 12.1),
  ('15-11', 'Aishah R.',    720, 2,  9.6),
  ('04-01', 'Marcus W.',    640, 1,  8.2),
  ('09-07', 'Siti H.',      520, 2,  7.4),
  ('02-05', 'Lim J.',       410, 1,  5.8),
  ('11-04', 'Priya M.',     380, 0,  4.9),
  ('06-12', 'Daniel O.',    295, 1,  4.1),
  ('14-02', 'Wei L.',       210, 1,  3.4)
) as v(unit, nickname, points, streak, kg) on v.unit = u.unit_number;

-- ---------------------------------------------------------------------
-- Smart bin fleet
-- ---------------------------------------------------------------------
insert into bins (code, name, location, status, weight_g, fill_pct, temp_c,
                  humidity_pct, rssi, lock_state, last_seen) values
  ('A01', 'Bin A01 · Ground Foyer',        'Elmina Green Central',   'available',  8420, 42, 31.2, 64, -61, 'locked', now()),
  ('B02', 'Bin B02 · Central Park Walkway','Central Park West',      'available', 16800, 84, 32.5, 68, -69, 'locked', now() - interval '1 minute'),
  ('C03', 'Bin C03 · Clubhouse Deck',      'Clubhouse & Nursery',    'available',  6200, 31, 29.8, 61, -58, 'locked', now() - interval '3 minutes');

-- ---------------------------------------------------------------------
-- Voucher catalogue
-- ---------------------------------------------------------------------
insert into voucher_catalogue (code, merchant, merchant_code, title, terms, icon,
                               cost_points, value_rm, expiry_days) values
  ('cat-jg-5',  'Jaya Grocer',     'JG', 'RM 5.00 Grocery Voucher',
   'Valid on fresh produce & grocery items across Sime Darby townships.', '🛒', 1000, 5, 30),
  ('cat-zus-5', 'Zus Coffee',      'ZU', 'RM 5.00 Handcrafted Beverage',
   'Applicable in the Zus Coffee app or in-store at the Elmina lakeside kiosk.', '☕', 900, 5, 14),
  ('cat-tea-5', 'Tealive',         'TE', 'RM 5.00 Tea Voucher',
   'Valid for any handcrafted tea or eco-reusable cup refill.', '🧋', 900, 5, 21),
  ('cat-vg-10', 'Village Grocer',  'VG', 'RM 10.00 Organic Produce Pass',
   'Valid with a minimum spend of RM 30 in the organic section.', '🥬', 1900, 10, 45);

-- ---------------------------------------------------------------------
-- Two weeks of pilot activity.
--   days 13..7  -> 'baseline'  (bin open, no Green Points)
--   days 6..0   -> 'rewarded'  (Green Points live)
-- The demo resident keeps a two-day gap so the 10-minute cooldown and the
-- daily caps are clear the moment the app opens.
-- ---------------------------------------------------------------------
insert into deposits (
  external_id, resident_id, unit_id, block_id, bin_id, weight_kg,
  points_awarded, is_clean, tier, confidence, base_points, quality_bonus,
  streak_bonus, cleanliness_multiplier, reward_latency_ms, session_nonce,
  phase, image_path, verdict, violations, created_at)
select
  'DEP-S' || lpad((row_number() over ())::text, 4, '0'),
  r.id,
  u.id,
  b.id,
  bn.id,
  w.kg,
  case when w.phase = 'rewarded' and w.tier = 'clean'
       then round(w.kg * 100) + round(round(w.kg * 100) * 0.2)
       else 0 end,
  (w.tier = 'clean'),
  w.tier::cleanliness_tier,
  w.confidence,
  round(w.kg * 100),
  case when w.phase = 'rewarded' and w.tier = 'clean'
       then round(round(w.kg * 100) * 0.1) else 0 end,
  case when w.phase = 'rewarded' and w.tier = 'clean'
       then round(round(w.kg * 100) * 0.1) else 0 end,
  case w.tier when 'clean' then 1 when 'suspect' then 0.5 else 0 end,
  900 + (row_number() over () % 1400),
  'S' || lpad((row_number() over ())::text, 5, '0'),
  w.phase::pilot_phase,
  case when w.tier = 'clean'
       then 'assets/images/deposit_clean.jpg'
       else 'assets/images/deposit_contaminated.jpg' end,
  case when w.tier = 'clean'
       then 'Clean organic waste and Bokashi bran verified.'
       else 'Flagged: non-food items detected, points withheld.' end,
  case when w.tier = 'clean' then '{}' else array['below_min_weight'] end,
  -- place the deposit in the afternoon of the given day offset
  date_trunc('day', now()) - make_interval(days => w.day_offset)
    + interval '13 hours' + make_interval(mins => ((row_number() over () % 8) * 37)::int)
from (values
  -- day offset, unit, bin, weight, tier, confidence, phase
  (13, '12-03', 'A01', 0.42, 'clean', 0.94, 'baseline'),
  (12, '08-02', 'A01', 0.31, 'clean', 0.91, 'baseline'),
  (11, '09-07', 'A01', 0.55, 'clean', 0.93, 'baseline'),
  (10, '12-03', 'A01', 0.38, 'clean', 0.92, 'baseline'),
  (10, '02-05', 'C03', 0.29, 'clean', 0.90, 'baseline'),
  (9,  '04-01', 'B02', 0.47, 'clean', 0.95, 'baseline'),
  (8,  '08-02', 'A01', 0.36, 'clean', 0.89, 'baseline'),
  (7,  '11-04', 'C03', 0.33, 'clean', 0.91, 'baseline'),
  (6,  '12-03', 'A01', 0.72, 'clean', 0.97, 'rewarded'),
  (6,  '15-11', 'B02', 0.65, 'clean', 0.95, 'rewarded'),
  (5,  '09-07', 'A01', 0.58, 'clean', 0.96, 'rewarded'),
  (5,  '06-12', 'A01', 0.44, 'clean', 0.93, 'rewarded'),
  (5,  '02-05', 'C03', 0.39, 'clean', 0.92, 'rewarded'),
  (4,  '12-03', 'A01', 0.81, 'clean', 0.98, 'rewarded'),
  (4,  '04-01', 'B02', 0.66, 'clean', 0.94, 'rewarded'),
  (4,  '11-04', 'C03', 0.52, 'clean', 0.90, 'rewarded'),
  (3,  '15-11', 'B02', 0.74, 'clean', 0.97, 'rewarded'),
  (3,  '09-07', 'A01', 0.61, 'clean', 0.95, 'rewarded'),
  (2,  '08-02', 'A01', 0.49, 'clean', 0.92, 'rewarded'),
  (2,  '06-12', 'A01', 0.43, 'clean', 0.94, 'rewarded'),
  (2,  '14-02', 'B02', 0.68, 'clean', 0.96, 'rewarded'),
  (1,  '12-03', 'A01', 0.95, 'clean', 0.98, 'rewarded'),
  (1,  '02-05', 'C03', 0.37, 'clean', 0.91, 'rewarded'),
  (1,  '04-01', 'B02', 0.54, 'clean', 0.93, 'rewarded'),
  (0,  '15-11', 'B02', 0.71, 'clean', 0.97, 'rewarded'),
  (0,  '09-07', 'A01', 0.62, 'clean', 0.95, 'rewarded'),
  (0,  '11-04', 'C03', 0.48, 'contaminated', 0.42, 'rewarded'),
  (0,  '06-12', 'A01', 0.57, 'clean', 0.94, 'rewarded')
) as w(day_offset, unit_number, bin_code, kg, tier, confidence, phase)
join units u on u.unit_number = w.unit_number
join residents r on r.unit_id = u.id
join blocks b on b.id = u.block_id
join bins bn on bn.code = w.bin_code
-- the demo resident keeps a two-day gap so cooldown/caps are clear on launch
where not (w.unit_number = '12-03' and w.day_offset < 2);

-- Recompute the resident balances from the seeded deposits.
update residents r
   set points_balance = coalesce((
         select sum(d.points_awarded) from deposits d
          where d.resident_id = r.id and d.phase = 'rewarded'
       ), 0),
       total_kg_diverted = coalesce((
         select sum(d.weight_kg) from deposits d where d.resident_id = r.id
       ), 0);

-- ---------------------------------------------------------------------
-- Points ledger for the rewarded week
-- ---------------------------------------------------------------------
insert into point_ledger (external_id, resident_id, delta, reason, ref_type,
                          ref_id, balance_after)
select 'L-' || d.external_id, d.resident_id, d.points_awarded,
       'Deposit ' || d.weight_kg || ' kg at Bin ' || bn.code,
       'deposit', d.external_id, d.points_awarded
  from deposits d join bins bn on bn.id = d.bin_id
 where d.points_awarded > 0;

-- ---------------------------------------------------------------------
-- One open dispute from the contaminated deposit
-- ---------------------------------------------------------------------
insert into disputes (external_id, deposit_id, resident_id, unit_id, bin_id,
                      reason, image_path, weight_kg, confidence,
                      withheld_points, status, created_at)
select 'DSP-' || d.external_id, d.id, d.resident_id, d.unit_id, d.bin_id,
       'Vision model detected a plastic bag and takeout cutlery in the deposit.',
       'assets/images/deposit_contaminated.jpg', d.weight_kg, d.confidence,
       round(d.weight_kg * 100), 'open', d.created_at
  from deposits d
 where d.tier = 'contaminated'
 order by d.created_at desc
 limit 1;

-- One blocked attempt, so the operator queue is not empty on day zero.
insert into rejected_attempts (external_id, bin_id, resident_id, unit_id,
                               reason, weight_kg, created_at)
select 'RA-9001', bn.id, r.id, u.id,
       'Cooldown active on this bin — one deposit per 10 minutes.',
       0.42, now() - interval '1 day 2 hours'
  from bins bn, residents r join units u on u.id = r.unit_id
 where bn.code = 'B02' and r.nickname = 'Siti H.';

-- ---------------------------------------------------------------------
-- Bokashi batches, compost returns, operator tasks, notifications
-- ---------------------------------------------------------------------
insert into bokashi_batches (external_id, bin_id, bin_source, sealed_date,
                             ready_date, day_current, day_total, status)
select 'Batch B-03', bn.id, 'Bin A01', now() - interval '8 days',
       now() + interval '6 days', 8, 14, 'Fermenting (Anaerobic)'
  from bins bn where bn.code = 'A01';

insert into bokashi_batches (external_id, bin_id, bin_source, sealed_date,
                             ready_date, day_current, day_total, status)
select 'Batch B-02', bn.id, 'Bin B02', now() - interval '14 days',
       now(), 14, 14, 'Ready for garden soil incorporation'
  from bins bn where bn.code = 'B02';

insert into compost_applications (external_id, kg, location, batch_id, note, created_at)
select 'CMP-8801', 25, 'Central Community Planter #3', b.id,
       'Pre-compost buried, 2 week cure complete.', now() - interval '3 days'
  from bokashi_batches b where b.external_id = 'Batch B-02';

insert into compost_applications (external_id, kg, location, note, created_at)
values ('CMP-8794', 18, 'Elmina Valley North Herbal Garden',
        'Bokashi tea diluted 1:50 for the herb beds.', now() - interval '11 days');

insert into operator_tasks (external_id, bin_id, title, description, priority, source)
select 'T-101', bn.id, 'Swap 20L bucket & seal',
       'Bucket reaches 84% fill level. Transfer to the curing bay.', 'high', 'system'
  from bins bn where bn.code = 'B02';

insert into operator_tasks (external_id, bin_id, title, description, priority, source)
select 'T-102', bn.id, 'Refill Bokashi microbial bran',
       'Top up the hopper dispenser with fresh EM-1 bran specks.', 'medium', 'system'
  from bins bn where bn.code = 'A01';

insert into operator_tasks (external_id, bin_id, title, description, priority, source)
select 'T-103', bn.id, 'Drain the Bokashi tea tap',
       'Harvest concentrated liquid microbial feed for community planters.', 'low', 'system'
  from bins bn where bn.code = 'C03';

insert into notifications (external_id, resident_id, title, message, type, is_read, created_at)
select 'N-01', r.id, 'Deposit successful (+79 pts)',
       '0.72 kg organic waste diverted at Bin A01. Thank you for enriching Elmina soil!',
       'deposit', false, now() - interval '18 hours'
  from residents r where r.nickname = 'Norah Lee';

insert into notifications (external_id, resident_id, title, message, type, is_read, created_at)
select 'N-02', r.id, 'RM 5.00 Jaya Grocer voucher issued',
       'Your voucher is active and ready to be scanned at the cashier checkout.',
       'rewards', false, now() - interval '2 days'
  from residents r where r.nickname = 'Norah Lee';

-- Community compost meter
insert into community_targets (id, target_kg, current_kg) values (true, 100, 0)
  on conflict (id) do update set target_kg = excluded.target_kg;

update community_targets
   set current_kg = coalesce((select sum(kg) from compost_applications), 0),
       target_kg = 100
 where id = true;

commit;
