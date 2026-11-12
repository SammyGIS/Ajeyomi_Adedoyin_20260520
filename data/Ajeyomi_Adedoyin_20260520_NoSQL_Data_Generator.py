import csv
import json
import os
import random
from datetime import datetime, timedelta, timezone

random.seed(20260520)
HERE = os.path.dirname(os.path.abspath(__file__))
LAGOS = timezone(timedelta(hours=1))


def rows(name):
    with open(os.path.join(HERE, name + ".csv"), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def utc_iso(text):
    local = datetime.strptime(text[:19], "%Y-%m-%d %H:%M:%S").replace(tzinfo=LAGOS)
    return local.astimezone(timezone.utc)


def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%S.000Z")


stations = {int(r["station_id"]): r for r in rows("stations")}
coords = {1: (3.3833, 6.5833), 2: (3.9470, 7.3775), 3: (7.4913, 9.0765),
          4: (5.6270, 6.3350), 5: (7.4985, 6.4410), 6: (8.5167, 11.9990)}
city = {i: s["station_name"].split()[0] for i, s in stations.items()}
routes = {int(r["route_id"]): r for r in rows("routes")}
vehicles = {int(r["vehicle_id"]): r for r in rows("vehicles")}
drivers = {int(r["driver_id"]): r for r in rows("drivers")}
customers = {int(r["customer_id"]): r for r in rows("customers")}
trips = {int(r["trip_id"]): r for r in rows("trips")}
parcels = rows("parcels")


def corridor(route):
    return city[int(route["origin_station_id"])] + "-" + city[int(route["destination_station_id"])]


odometer = {v: random.randint(60000, 180000) for v in vehicles}
telemetry = []
completed = sorted((t for t in trips.values() if t["trip_status"] == "Completed"),
                   key=lambda t: t["departure_datetime"])
for t in completed:
    route = routes[int(t["route_id"])]
    vid, did = int(t["vehicle_id"]), int(t["driver_id"])
    v, d = vehicles[vid], drivers[did]
    o, de = int(route["origin_station_id"]), int(route["destination_station_id"])
    dep, arr = utc_iso(t["departure_datetime"]), utc_iso(t["arrival_datetime"])
    total = (arr - dep).total_seconds()
    km = float(route["distance_km"])
    steps = max(int(total // 900), 1)
    start_odo = odometer[vid]
    for i in range(steps + 1):
        f = i / steps
        when = dep + timedelta(seconds=total * f)
        lon = coords[o][0] + f * (coords[de][0] - coords[o][0]) + random.uniform(-0.01, 0.01)
        lat = coords[o][1] + f * (coords[de][1] - coords[o][1]) + random.uniform(-0.01, 0.01)
        if i == 0 or i == steps:
            speed = 0.0
        elif random.random() < 0.03:
            speed = round(random.uniform(101, 118), 1)
        else:
            speed = round(min(max(random.gauss(76, 11), 35), 98), 1)
        temp = round(random.gauss(90, 4), 1)
        harsh = random.random() < 0.01
        if i == 0:
            place = stations[o]["station_name"] + " exit"
        elif i == steps:
            place = stations[de]["station_name"] + " arrival"
        else:
            place = "%s to %s highway, about km %d" % (city[o], city[de], int(km * f))
        telemetry.append({
            "vehicle_id": vid,
            "registration_number": v["registration_number"],
            "vehicle_type": v["make_model"],
            "gps_tracker_id": v["gps_tracker_id"],
            "route_corridor": corridor(route),
            "current_trip_id": int(t["trip_id"]),
            "driver": {"driver_id": did, "name": d["full_name"], "license_number": d["license_number"]},
            "location": {"type": "Point", "coordinates": [round(lon, 5), round(lat, 5)]},
            "location_address": place,
            "metrics": {"speed_kmh": speed,
                        "fuel_level_percent": round(min(max(100 - 55 * f + random.uniform(-2, 2), 5), 100), 1),
                        "engine_temp_celsius": temp,
                        "odometer_km": round(start_odo + km * f, 1)},
            "alerts": {"speed_warning": speed > 100, "harsh_braking": harsh,
                       "engine_temp_warning": temp > 100, "fuel_leak_detected": False},
            "device_status": {"battery_health": random.choice(["Good", "Good", "Good", "Fair"]),
                              "cellular_signal_dbm": random.randint(-95, -60),
                              "firmware_version": "v3.4.1"},
            "recorded_at": iso(when),
        })
    odometer[vid] = round(start_odo + km, 1)

categories = [("Electronics", "Laptops and phone accessories", True, "Ambient Dry"),
              ("Documents", "Sealed legal and school documents", False, "Ambient Dry"),
              ("Clothing", "Boxed clothes and fabric", False, "Ambient Dry"),
              ("Medical Supplies", "Packed medical items", True, "Cold Chain (2-8 C)"),
              ("Food Items", "Packed dry food items", False, "Ambient Dry"),
              ("Spare Parts", "Vehicle spare parts", False, "Ambient Dry"),
              ("Cosmetics", "Boxed beauty products", True, "Ambient Dry")]
tracking = []
for p in parcels:
    t = trips[int(p["trip_id"])]
    route = routes[int(t["route_id"])]
    o, de = int(route["origin_station_id"]), int(route["destination_station_id"])
    dep, arr = utc_iso(t["departure_datetime"]), utc_iso(t["arrival_datetime"])
    cust = customers[int(p["sender_customer_id"])]
    drv = drivers[int(t["driver_id"])]
    cat = random.choice(categories)
    status = p["delivery_status"]
    declared = float(p["declared_value"])
    steps = [("Registered", o, dep - timedelta(hours=2), "Dispatch officer, " + stations[o]["station_name"], "Parcel registered and waybill issued."),
             ("Loaded", o, dep - timedelta(minutes=20), "Driver " + drv["full_name"], "Loaded into vehicle " + vehicles[int(t["vehicle_id"])]["registration_number"] + "."),
             ("In-Transit", None, dep + (arr - dep) / 2, "Automated GPS", "Parcel on the road."),
             ("Arrived-Hub", de, arr, "Hub supervisor, " + stations[de]["station_name"], "Parcel received at destination.")]
    if status == "Delivered":
        steps.append(("Delivered", de, arr + timedelta(hours=2), "Hub supervisor, " + stations[de]["station_name"], "Recipient identity checked and parcel handed over."))
    elif status == "Returned":
        steps.append(("Returned", de, arr + timedelta(hours=3), "Hub supervisor, " + stations[de]["station_name"], "Recipient not reached, parcel returned."))
    checkpoints = []
    for n, (st, sid, when, by, note) in enumerate(steps, 1):
        if sid is None:
            lon = (coords[o][0] + coords[de][0]) / 2
            lat = (coords[o][1] + coords[de][1]) / 2
            station = city[o] + " to " + city[de] + " highway"
        else:
            lon, lat = coords[sid]
            station = stations[sid]["station_name"]
        checkpoints.append({"checkpoint_id": n, "status": st, "station": station,
                            "location_coords": [round(lon, 4), round(lat, 4)], "timestamp": iso(when),
                            "handled_by": by, "security_check_passed": True, "notes": note})
    tracking.append({
        "waybill_number": p["waybill_number"],
        "sender": {"customer_id": int(cust["customer_id"]), "name": cust["full_name"],
                   "phone": cust["phone_number"], "nin": cust["nin"]},
        "recipient": {"name": p["recipient_name"], "phone": p["recipient_phone"],
                      "nin_required_for_pickup": True,
                      "verified_nin": p["recipient_nin"] if status == "Delivered" else None},
        "cargo_details": {"category": cat[0], "description": cat[1], "weight_kg": float(p["weight_kg"]),
                          "declared_value_ngn": declared, "is_fragile": cat[2],
                          "insurance_covered": declared >= 150000, "storage_condition": cat[3]},
        "route": {"origin_hub": stations[o]["station_name"], "destination_hub": stations[de]["station_name"],
                  "assigned_vehicle_reg": vehicles[int(t["vehicle_id"])]["registration_number"],
                  "trip_id": int(t["trip_id"])},
        "current_status": status,
        "checkpoints": checkpoints,
    })

for name, data in (("vehicle_telemetry", telemetry), ("parcel_tracking", tracking)):
    path = os.path.join(HERE, name + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    print(name, len(data), "documents,", round(os.path.getsize(path) / 1e6, 1), "MB")
