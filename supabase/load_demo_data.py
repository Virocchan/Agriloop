#!/usr/bin/env python3
"""
Loads the AgriLoop demo / pilot dataset into a Supabase project via PostgREST.

Idempotent: it clears the transactional tables and re-seeds them, so it can be
re-run whenever the pilot history needs to be reset.

    source /tmp/agri_env.sh && python3 supabase/load_demo_data.py
"""
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

URL = os.environ["SUPA_URL"].rstrip("/") + "/rest/v1"
KEY = os.environ["SUPA_KEY"]
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
}
NOW = datetime.now(timezone.utc)


def req(method, path, body=None, extra=None):
    headers = dict(HEADERS)
    if extra:
        headers.update(extra)
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(f"{URL}/{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode()
        try:
            return exc.code, json.loads(raw)
        except json.JSONDecodeError:
            return exc.code, raw


def select(table, query="select=*"):
    status, data = req("GET", f"{table}?{query}")
    if status != 200:
        raise SystemExit(f"GET {table} failed: {status} {data}")
    return data


def insert(table, rows):
    """Inserts rows, returning the saved rows (with generated ids)."""
    if not rows:
        return []
    out = []
    for row in rows:
        status, data = req("POST", table, row, {"Prefer": "return=representation"})
        if status not in (200, 201):
            raise SystemExit(f"INSERT {table} failed: {status} {data}\nrow={row}")
        out.extend(data if isinstance(data, list) else [data])
    return out


def patch(table, query, body):
    status, data = req("PATCH", f"{table}?{query}", body, {"Prefer": "return=representation"})
    if status not in (200, 204):
        raise SystemExit(f"PATCH {table} failed: {status} {data}")
    return data


def delete(table, query="id=neq.00000000-0000-0000-0000-000000000000"):
    status, data = req("DELETE", f"{table}?{query}")
    if status not in (200, 204):
        raise SystemExit(f"DELETE {table} failed: {status} {data}")


def iso(dt):
    return dt.isoformat()


# ---------------------------------------------------------------------
# 1. Clear the transactional tables
# ---------------------------------------------------------------------
print("Clearing transactional tables...")
for table in ("notifications", "operator_tasks", "compost_applications",
              "bokashi_batches", "redemptions", "vouchers", "rejected_attempts",
              "disputes", "point_ledger", "deposits"):
    delete(table)

# ---------------------------------------------------------------------
# 2. Geography — keep the existing township, add two more blocks
# ---------------------------------------------------------------------
townships = select("townships")
if not townships:
    raise SystemExit("No township found — run the schema first.")
township_id = townships[0]["id"]
print(f"Township: {townships[0]['name']} ({townships[0]['code']})")

blocks = select("blocks")
block_by_code = {b["code"]: b for b in blocks}
for code, name in (("Block B", "Block B · Central Park West"),
                   ("Block C", "Block C · Clubhouse & Nursery")):
    if code in block_by_code:
        continue
    created = insert("blocks", [{
        "township_id": township_id,
        "code": code,
        "name": name,
    }])
    block_by_code[code] = created[0]
    print(f"  + block {code}")

# Re-read so newly created blocks are visible to the pilot data below.
blocks = select("blocks")
block_by_code = {b["code"]: b for b in blocks}

# ---------------------------------------------------------------------
# 3. Units + residents
# ---------------------------------------------------------------------
PILOT_UNITS = [
    ("Block A", "12-03", "INV-1203-XYZ", "Virocchan"),
    ("Block A", "08-02", "INV-0802-ABC", "Kelvin T."),
    ("Block A", "15-11", "INV-1511-JKL", "Aishah R."),
    ("Block B", "04-01", "INV-0401-PQR", "Marcus W."),
    ("Block B", "09-07", "INV-0907-STU", "Siti H."),
    ("Block B", "14-02", "INV-1402-VWX", "Wei L."),
    ("Block C", "02-05", "INV-0205-YZA", "Lim J."),
    ("Block C", "11-04", "INV-1104-BCD", "Priya M."),
    ("Block C", "06-12", "INV-0612-EFG", "Daniel O."),
]

existing_units = {u["unit_number"]: u for u in select("units")}
unit_rows = []
for block_code, unit_number, invite, nickname in PILOT_UNITS:
    if unit_number in existing_units:
        unit_rows.append(existing_units[unit_number])
        continue
    created = insert("units", [{
        "block_id": block_by_code[block_code]["id"],
        "unit_number": unit_number,
        "invite_code": invite,
    }])
    unit_rows.append(created[0])
    print(f"  + unit {unit_number}")

unit_by_number = {u["unit_number"]: u for u in unit_rows}

existing_residents = {r["invite_code"]: r for r in select("residents")}
resident_rows = []
for block_code, unit_number, invite, nickname in PILOT_UNITS:
    if invite in existing_residents:
        resident_rows.append(existing_residents[invite])
        continue
    created = insert("residents", [{
        "unit_id": unit_by_number[unit_number]["id"],
        "nickname": nickname,
        "invite_code": invite,
        "points_balance": 0,
        "streak_weeks": 0,
        "total_kg_diverted": 0,
        "co2_factor": 2.5,
        "verified": True,
        "registered_at": iso(NOW - timedelta(days=20)),
    }])
    resident_rows.append(created[0])
    print(f"  + resident {nickname}")

resident_by_unit = {}
for resident in resident_rows:
    unit_number = next(u["unit_number"] for u in unit_rows if u["id"] == resident["unit_id"])
    resident_by_unit[unit_number] = resident

# ---------------------------------------------------------------------
# 4. Smart bin fleet
# ---------------------------------------------------------------------
BINS = [
    ("A01", "Lobby Smart Bin A01", "Ground Floor Lobby Block A", 8420, 42, 31.2, 64, -61),
    ("B02", "Bin B02 · Central Park Walkway", "Central Park West", 16800, 84, 32.5, 68, -69),
    ("C03", "Bin C03 · Clubhouse Deck", "Clubhouse & Nursery", 6200, 31, 29.8, 61, -58),
]
existing_bins = {b["code"]: b for b in select("bins")}
bin_by_code = {}
for code, name, location, weight, fill, temp, humidity, rssi in BINS:
    body = {
        "name": name,
        "location": location,
        "status": "available",
        "weight_g": weight,
        "capacity_g": 20000,
        "fill_pct": fill,
        "temp_c": temp,
        "humidity_pct": humidity,
        "rssi": rssi,
        "lock_state": "locked",
        "last_seen": iso(NOW),
    }
    if code in existing_bins:
        patch("bins", f"code=eq.{code}", body)
        bin_by_code[code] = {**existing_bins[code], **body}
    else:
        created = insert("bins", [{"code": code, **body}])
        bin_by_code[code] = created[0]
        print(f"  + bin {code}")

# ---------------------------------------------------------------------
# 5. Voucher catalogue — keep the existing rows, add the app's merchants
# ---------------------------------------------------------------------
CATALOGUE = [
    ("cat-jg-5", "Jaya Grocer", "JG", "RM 5.00 Grocery Voucher",
     "Valid on fresh produce & grocery items across Sime Darby townships.",
     "\U0001F6D2", 1000, 5, 30),
    ("cat-zus-5", "Zus Coffee", "ZU", "RM 5.00 Handcrafted Beverage",
     "Applicable in the Zus Coffee app or in-store at the Elmina lakeside kiosk.",
     "☕", 900, 5, 14),
    ("cat-tea-5", "Tealive", "TE", "RM 5.00 Tea Voucher",
     "Valid for any handcrafted tea or eco-reusable cup refill.",
     "\U0001F9CB", 900, 5, 21),
    ("cat-vg-10", "Village Grocer", "VG", "RM 10.00 Organic Produce Pass",
     "Valid with a minimum spend of RM 30 in the organic section.",
     "\U0001F96C", 1900, 10, 45),
]
existing_catalogue = {c["code"]: c for c in select("voucher_catalogue")}
for code, merchant, mcode, title, terms, icon, cost, value, days in CATALOGUE:
    if code in existing_catalogue:
        continue
    insert("voucher_catalogue", [{
        "code": code,
        "merchant": merchant,
        "merchant_code": mcode,
        "title": title,
        "terms": terms,
        "icon": icon,
        "cost_points": cost,
        "value_rm": value,
        "expiry_days": days,
        "active": True,
    }])
    print(f"  + catalogue {code}")

# ---------------------------------------------------------------------
# 6. Two weeks of pilot activity
#    days 13..7 = baseline (no rewards), days 6..0 = rewards live
# ---------------------------------------------------------------------
PILOT = [
    # day, unit, bin, kg, tier, confidence
    (13, "12-03", "A01", 0.42, "clean", 0.94),
    (12, "08-02", "A01", 0.31, "clean", 0.91),
    (11, "09-07", "A01", 0.55, "clean", 0.93),
    (10, "12-03", "A01", 0.38, "clean", 0.92),
    (10, "02-05", "C03", 0.29, "clean", 0.90),
    (9, "04-01", "B02", 0.47, "clean", 0.95),
    (8, "08-02", "A01", 0.36, "clean", 0.89),
    (7, "11-04", "C03", 0.33, "clean", 0.91),
    (6, "12-03", "A01", 0.72, "clean", 0.97),
    (6, "15-11", "B02", 0.65, "clean", 0.95),
    (5, "09-07", "A01", 0.58, "clean", 0.96),
    (5, "06-12", "A01", 0.44, "clean", 0.93),
    (5, "02-05", "C03", 0.39, "clean", 0.92),
    (4, "12-03", "A01", 0.81, "clean", 0.98),
    (4, "04-01", "B02", 0.66, "clean", 0.94),
    (4, "11-04", "C03", 0.52, "clean", 0.90),
    (3, "15-11", "B02", 0.74, "clean", 0.97),
    (3, "09-07", "A01", 0.61, "clean", 0.95),
    (2, "08-02", "A01", 0.49, "clean", 0.92),
    (2, "06-12", "A01", 0.43, "clean", 0.94),
    (2, "14-02", "B02", 0.68, "clean", 0.96),
    (1, "12-03", "A01", 0.95, "clean", 0.98),
    (1, "02-05", "C03", 0.37, "clean", 0.91),
    (1, "04-01", "B02", 0.54, "clean", 0.93),
    (0, "15-11", "B02", 0.71, "clean", 0.97),
    (0, "09-07", "A01", 0.62, "clean", 0.95),
    (0, "11-04", "C03", 0.48, "contaminated", 0.42),
    (0, "06-12", "A01", 0.57, "clean", 0.94),
]

deposit_rows = []
ledger_rows = []
for index, (day, unit_number, bin_code, kg, tier, confidence) in enumerate(PILOT):
    # The demo resident keeps a two-day gap so the 10-minute cooldown and the
    # daily caps are clear the moment the app opens.
    if unit_number == "12-03" and day < 2:
        continue
    phase = "baseline" if day >= 7 else "rewarded"
    base = round(kg * 100)
    awarded = base + round(base * 0.2) if (phase == "rewarded" and tier == "clean") else 0
    created_at = (NOW - timedelta(days=day)).replace(
        hour=13, minute=(index * 37) % 60, second=0, microsecond=0)
    unit = unit_by_number[unit_number]
    resident = resident_by_unit[unit_number]
    block = next(b for b in blocks if b["id"] == unit["block_id"])

    row = {
        "external_id": f"DEP-S{index:04d}",
        "resident_id": resident["id"],
        "unit_id": unit["id"],
        "block_id": block["id"],
        "bin_id": bin_by_code[bin_code]["id"],
        "weight_kg": kg,
        "points_awarded": awarded,
        "is_clean": tier == "clean",
        "tier": tier,
        "confidence": confidence,
        "base_points": base,
        "quality_bonus": round(base * 0.1) if (phase == "rewarded" and tier == "clean") else 0,
        "streak_bonus": round(base * 0.1) if (phase == "rewarded" and tier == "clean") else 0,
        "cleanliness_multiplier": 1 if tier == "clean" else 0,
        "reward_latency_ms": 900 + (index * 137) % 1400,
        "session_nonce": f"S{index:05d}",
        "phase": phase,
        "image_path": "assets/images/deposit_clean.jpg" if tier == "clean"
                      else "assets/images/deposit_contaminated.jpg",
        "verdict": "Clean organic waste and Bokashi bran verified." if tier == "clean"
                   else "Flagged: non-food items detected, points withheld.",
        "violations": [] if tier == "clean" else ["CONTAMINATION_DETECTED"],
        "rejected": False,
        "created_at": iso(created_at),
    }
    deposit_rows.append(row)

created_deposits = insert("deposits", deposit_rows)
print(f"  + {len(created_deposits)} deposits")

# Points ledger for the rewarded week
for deposit in created_deposits:
    if deposit["points_awarded"] <= 0:
        continue
    ledger_rows.append({
        "external_id": f"L-{deposit['external_id']}",
        "resident_id": deposit["resident_id"],
        "delta": deposit["points_awarded"],
        "reason": f"Deposit {deposit['weight_kg']} kg at Bin "
                  f"{next(c for c, b in bin_by_code.items() if b['id'] == deposit['bin_id'])}",
        "ref_type": "deposit",
        "ref_id": deposit["external_id"],
        "balance_after": deposit["points_awarded"],
        "created_at": deposit["created_at"],
    })
insert("point_ledger", ledger_rows)
print(f"  + {len(ledger_rows)} ledger entries")

# ---------------------------------------------------------------------
# 7. Balances, streak and tonnage per resident
# ---------------------------------------------------------------------
print("Recomputing resident balances...")
for resident in resident_rows:
    mine = [d for d in created_deposits if d["resident_id"] == resident["id"]]
    rewarded_points = sum(d["points_awarded"] for d in mine if d["phase"] == "rewarded")
    total_kg = round(sum(float(d["weight_kg"]) for d in mine), 2)
    clean_days = len({d["created_at"][:10] for d in mine if d["is_clean"]})
    streak = min(clean_days, 8)
    patch("residents", f"id=eq.{resident['id']}", {
        "points_balance": rewarded_points,
        "total_kg_diverted": total_kg,
        "streak_weeks": streak,
        "verified": True,
    })

# ---------------------------------------------------------------------
# 8. Dispute, blocked attempt, batches, compost, tasks, notifications
# ---------------------------------------------------------------------
contaminated = next((d for d in created_deposits if d["tier"] == "contaminated"), None)
if contaminated:
    insert("disputes", [{
        "external_id": f"DSP-{contaminated['external_id']}",
        "deposit_id": contaminated["id"],
        "resident_id": contaminated["resident_id"],
        "unit_id": contaminated["unit_id"],
        "bin_id": contaminated["bin_id"],
        "reason": "Vision model detected a plastic bag and takeout cutlery in the deposit.",
        "image_path": "assets/images/deposit_contaminated.jpg",
        "weight_kg": contaminated["weight_kg"],
        "confidence": contaminated["confidence"],
        "withheld_points": contaminated["base_points"],
        "status": "open",
        "created_at": contaminated["created_at"],
    }])
    print("  + 1 open dispute")

insert("rejected_attempts", [{
    "external_id": "RA-9001",
    "bin_id": bin_by_code["B02"]["id"],
    "resident_id": resident_by_unit["09-07"]["id"],
    "unit_id": unit_by_number["09-07"]["id"],
    "reason": "COOLDOWN_VIOLATION, DUPLICATE_SESSION_NONCE",
    "weight_kg": 0.42,
    "created_at": iso(NOW - timedelta(days=1, hours=2)),
}])
print("  + 1 blocked attempt")

batches = insert("bokashi_batches", [
    {
        "external_id": "Batch B-03",
        "bin_id": bin_by_code["A01"]["id"],
        "bin_source": "Bin A01",
        "sealed_date": iso(NOW - timedelta(days=8)),
        "ready_date": iso(NOW + timedelta(days=6)),
        "day_current": 8,
        "day_total": 14,
        "status": "Fermenting (Anaerobic)",
    },
    {
        "external_id": "Batch B-02",
        "bin_id": bin_by_code["B02"]["id"],
        "bin_source": "Bin B02",
        "sealed_date": iso(NOW - timedelta(days=14)),
        "ready_date": iso(NOW),
        "day_current": 14,
        "day_total": 14,
        "status": "Ready for garden soil incorporation",
    },
])
print(f"  + {len(batches)} bokashi batches")

compost = insert("compost_applications", [
    {
        "external_id": "CMP-8801",
        "kg": 25,
        "location": "Central Community Planter #3",
        "batch_id": batches[1]["id"],
        "note": "Pre-compost buried, 2 week cure complete.",
        "created_at": iso(NOW - timedelta(days=3)),
    },
    {
        "external_id": "CMP-8794",
        "kg": 18,
        "location": "Elmina Valley North Herbal Garden",
        "note": "Bokashi tea diluted 1:50 for the herb beds.",
        "created_at": iso(NOW - timedelta(days=11)),
    },
])
print(f"  + {len(compost)} compost applications")

insert("operator_tasks", [
    {
        "external_id": "T-101",
        "bin_id": bin_by_code["B02"]["id"],
        "title": "Swap 20L bucket & seal",
        "description": "Bucket reaches 84% fill level. Transfer to the curing bay.",
        "priority": "high",
        "is_completed": False,
        "source": "system",
        "created_at": iso(NOW),
    },
    {
        "external_id": "T-102",
        "bin_id": bin_by_code["A01"]["id"],
        "title": "Refill Bokashi microbial bran",
        "description": "Top up the hopper dispenser with fresh EM-1 bran specks.",
        "priority": "medium",
        "is_completed": False,
        "source": "system",
        "created_at": iso(NOW),
    },
    {
        "external_id": "T-103",
        "bin_id": bin_by_code["C03"]["id"],
        "title": "Drain the Bokashi tea tap",
        "description": "Harvest concentrated liquid microbial feed for community planters.",
        "priority": "low",
        "is_completed": False,
        "source": "system",
        "created_at": iso(NOW),
    },
])
print("  + 3 operator tasks")

demo_resident = resident_by_unit["12-03"]
insert("notifications", [
    {
        "external_id": "N-01",
        "resident_id": demo_resident["id"],
        "title": "Deposit successful (+79 pts)",
        "message": "0.72 kg organic waste diverted at Bin A01. Thank you for enriching Elmina soil!",
        "type": "deposit",
        "is_read": False,
        "created_at": iso(NOW - timedelta(hours=18)),
    },
    {
        "external_id": "N-02",
        "resident_id": demo_resident["id"],
        "title": "RM 5.00 Jaya Grocer voucher issued",
        "message": "Your voucher is active and ready to be scanned at the cashier checkout.",
        "type": "rewards",
        "is_read": False,
        "created_at": iso(NOW - timedelta(days=2)),
    },
])
print("  + 2 notifications")

# ---------------------------------------------------------------------
# 9. Community compost meter
# ---------------------------------------------------------------------
total_compost = sum(float(c["kg"]) for c in compost)
patch("community_targets", "id=eq.true", {
    "target_kg": 100,
    "current_kg": total_compost,
    "updated_at": iso(NOW),
})
print(f"  community compost meter -> {total_compost} kg")

print("\nDone. Summary:")
print(f"  deposits          {len(select('deposits'))}")
print(f"  ledger            {len(select('point_ledger'))}")
print(f"  residents         {len(select('residents'))}")
print(f"  bins              {len(select('bins'))}")
print(f"  disputes          {len(select('disputes'))}")
print(f"  catalogue         {len(select('voucher_catalogue'))}")
