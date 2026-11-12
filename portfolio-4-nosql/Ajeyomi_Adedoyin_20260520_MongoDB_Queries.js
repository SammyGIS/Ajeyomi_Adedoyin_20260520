// Run from the repository root:  mongosh --file portfolio-4-nosql/Ajeyomi_Adedoyin_20260520_MongoDB_Queries.js > portfolio-4-nosql/Ajeyomi_Adedoyin_20260520_NoSQL_Execution_Results.txt

// Database and schema validation

db = db.getSiblingDB("adedoyin_mobility_nosql");

// Drop collections so the script can be run again
db.vehicle_telemetry.drop();
db.parcel_tracking.drop();

// vehicle_telemetry with a JSON Schema validator
db.createCollection("vehicle_telemetry", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["vehicle_id", "registration_number", "gps_tracker_id", "route_corridor", "location", "metrics", "recorded_at"],
      properties: {
        vehicle_id: {
          bsonType: "int",
          description: "Unique integer vehicle ID referencing relational fleet record"
        },
        registration_number: {
          bsonType: "string",
          pattern: "^[A-Z]{3}-[0-9]{3}[A-Z]{2}$",
          description: "Nigerian vehicle registration format (e.g. APP-125KT)"
        },
        gps_tracker_id: {
          bsonType: "string",
          description: "Serial hardware identifier of the onboard GPS IoT modem"
        },
        route_corridor: {
          bsonType: "string",
          description: "Designated highway corridor (e.g. Lagos-Ibadan-Abuja)"
        },
        location: {
          bsonType: "object",
          required: ["type", "coordinates"],
          properties: {
            type: {
              enum: ["Point"],
              description: "Must be GeoJSON Point"
            },
            coordinates: {
              bsonType: "array",
              minItems: 2,
              maxItems: 2,
              items: {
                bsonType: "number"
              },
              description: "[longitude, latitude] in decimal degrees"
            }
          }
        },
        metrics: {
          bsonType: "object",
          required: ["speed_kmh", "fuel_level_percent", "odometer_km"],
          properties: {
            speed_kmh: { bsonType: "number", minimum: 0.0, maximum: 200.0 },
            fuel_level_percent: { bsonType: "number", minimum: 0.0, maximum: 100.0 },
            engine_temp_celsius: { bsonType: "number" },
            odometer_km: { bsonType: "number", minimum: 0.0 }
          }
        },
        recorded_at: {
          bsonType: "date",
          description: "UTC ISODate timestamp of the IoT telemetry ping"
        }
      }
    }
  }
});

// parcel_tracking with a JSON Schema validator
db.createCollection("parcel_tracking", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["waybill_number", "sender", "recipient", "cargo_details", "route", "current_status", "checkpoints"],
      properties: {
        waybill_number: {
          bsonType: "string",
          pattern: "^AML-WB-[0-9]{4}-[0-9]{4,5}$",
          description: "Standard AML tracking waybill format (e.g. AML-WB-2026-00001)"
        },
        sender: {
          bsonType: "object",
          required: ["name", "phone"],
          properties: {
            customer_id: { bsonType: "int" },
            name: { bsonType: "string" },
            phone: { bsonType: "string" },
            nin: { bsonType: "string", pattern: "^[0-9]{11}$" }
          }
        },
        recipient: {
          bsonType: "object",
          required: ["name", "phone"],
          properties: {
            name: { bsonType: "string" },
            phone: { bsonType: "string" },
            nin_required_for_pickup: { bsonType: "bool" },
            verified_nin: { bsonType: ["string", "null"] }
          }
        },
        current_status: {
          enum: ["Registered", "Loaded", "In-Transit", "Arrived-Hub", "Out-for-Delivery", "Delivered", "Returned", "Cancelled"]
        },
        checkpoints: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            required: ["checkpoint_id", "status", "station", "timestamp"],
            properties: {
              checkpoint_id: { bsonType: "int" },
              status: { bsonType: "string" },
              station: { bsonType: "string" },
              timestamp: { bsonType: "date" },
              handled_by: { bsonType: "string" }
            }
          }
        }
      }
    }
  }
});

// Load the data generated from the SQL dataset
const fs = require("fs");

function loadJson(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

function insertInBatches(collection, docs, size) {
  for (let i = 0; i < docs.length; i += size) {
    collection.insertMany(docs.slice(i, i + size));
  }
}

const telemetry = loadJson("data/vehicle_telemetry.json");
telemetry.forEach(d => { d.recorded_at = new Date(d.recorded_at); });
insertInBatches(db.vehicle_telemetry, telemetry, 5000);

const parcels = loadJson("data/parcel_tracking.json");
parcels.forEach(d => d.checkpoints.forEach(c => { c.timestamp = new Date(c.timestamp); }));
insertInBatches(db.parcel_tracking, parcels, 1000);

print("vehicle_telemetry documents: " + db.vehicle_telemetry.countDocuments());
print("parcel_tracking documents:   " + db.parcel_tracking.countDocuments());

// Benchmark queries, measured before and after the indexes exist
const abuja = [7.4913, 9.0765];
const benchmarks = [
  { name: "Q1 pings within 80 km of Abuja", coll: db.vehicle_telemetry,
    query: { location: { $geoWithin: { $centerSphere: [abuja, 80 / 6378.1] } } } },
  { name: "Q2 one vehicle's pings in one week", coll: db.vehicle_telemetry,
    query: { vehicle_id: 5, recorded_at: { $gte: ISODate("2026-07-01T00:00:00Z"), $lt: ISODate("2026-07-08T00:00:00Z") } },
    sort: { recorded_at: -1 } },
  { name: "Q3 parcel lookup by waybill", coll: db.parcel_tracking,
    query: { waybill_number: "AML-WB-2026-00002" } },
  { name: "Q4 speeding alerts on Lagos-Abuja", coll: db.vehicle_telemetry,
    query: { route_corridor: "Lagos-Abuja", "alerts.speed_warning": true } }
];

function stageNames(plan) {
  const names = [];
  while (plan) {
    names.push(plan.stage + (plan.indexName ? " (" + plan.indexName + ")" : ""));
    plan = plan.inputStage;
  }
  return names.join(" > ");
}

function cursorFor(b) {
  const c = b.coll.find(b.query);
  return b.sort ? c.sort(b.sort) : c;
}

function measure(b) {
  cursorFor(b).toArray();
  const ex = cursorFor(b).explain("executionStats");
  const s = ex.executionStats;
  return { plan: stageNames(ex.queryPlanner.winningPlan), ms: s.executionTimeMillis,
           docs: s.totalDocsExamined, keys: s.totalKeysExamined, returned: s.nReturned };
}

function show(label, results) {
  print("\n" + label);
  benchmarks.forEach((b, i) => {
    const r = results[i];
    print(b.name);
    print("  plan: " + r.plan);
    print("  time: " + r.ms + " ms | documents examined: " + r.docs + " | index keys examined: " + r.keys + " | returned: " + r.returned);
  });
}

const before = benchmarks.map(measure);
show("BASELINE (no extra indexes)", before);

// Indexes
db.vehicle_telemetry.createIndex({ location: "2dsphere" }, { name: "idx_telemetry_2dsphere_location" });
db.vehicle_telemetry.createIndex({ vehicle_id: 1, recorded_at: -1 }, { name: "idx_telemetry_vehicle_time" });
db.vehicle_telemetry.createIndex({ route_corridor: 1, "alerts.speed_warning": 1 }, { name: "idx_telemetry_corridor_speed_alert" });
db.parcel_tracking.createIndex({ waybill_number: 1 }, { unique: true, name: "idx_parcel_waybill_unique" });
db.parcel_tracking.createIndex({ "checkpoints.status": 1, "checkpoints.station": 1 }, { name: "idx_parcel_checkpoints_multikey" });
db.parcel_tracking.createIndex({ "route.origin_hub": 1, "route.destination_hub": 1, current_status: 1 }, { name: "idx_parcel_route_status" });

const after = benchmarks.map(measure);
show("OPTIMISED (with indexes)", after);

print("\nSUMMARY");
benchmarks.forEach((b, i) => {
  print(b.name + ": examined " + before[i].docs + " documents -> " + after[i].docs +
        ", " + before[i].ms + " ms -> " + after[i].ms + " ms");
});

// Operational queries
print("\nQUERY 1: vehicles within 80 km of Abuja Utako (nearest pings first)");
printjson(db.vehicle_telemetry.find(
  { location: { $nearSphere: { $geometry: { type: "Point", coordinates: abuja }, $maxDistance: 80000 } } },
  { registration_number: 1, route_corridor: 1, location_address: 1, "metrics.speed_kmh": 1, recorded_at: 1, _id: 0 }
).limit(5).toArray());

print("\nQUERY 2: fastest speeding events above the 100 km/h limit");
printjson(db.vehicle_telemetry.find(
  { "alerts.speed_warning": true },
  { registration_number: 1, route_corridor: 1, "driver.name": 1, "metrics.speed_kmh": 1, recorded_at: 1, _id: 0 }
).sort({ "metrics.speed_kmh": -1 }).limit(5).toArray());

print("\nQUERY 3: full audit trail of waybill AML-WB-2026-00002");
printjson(db.parcel_tracking.findOne(
  { waybill_number: "AML-WB-2026-00002" },
  { waybill_number: 1, "sender.name": 1, "recipient.name": 1, "route.origin_hub": 1, "route.destination_hub": 1,
    current_status: 1, "checkpoints.status": 1, "checkpoints.station": 1, "checkpoints.timestamp": 1, _id: 0 }
));

print("\nQUERY 4: parcel scans per station and status (top 10)");
printjson(db.parcel_tracking.aggregate([
  { $unwind: "$checkpoints" },
  { $group: { _id: { station: "$checkpoints.station", status: "$checkpoints.status" },
              scans: { $sum: 1 }, last_scan: { $max: "$checkpoints.timestamp" } } },
  { $project: { _id: 0, station: "$_id.station", status: "$_id.status", scans: 1, last_scan: 1 } },
  { $sort: { scans: -1, station: 1 } },
  { $limit: 10 }
]).toArray());

print("\nQUERY 5: telemetry summary per corridor");
printjson(db.vehicle_telemetry.aggregate([
  { $group: { _id: "$route_corridor", pings: { $sum: 1 }, avg_speed_kmh: { $avg: "$metrics.speed_kmh" },
              max_speed_kmh: { $max: "$metrics.speed_kmh" },
              speeding_pings: { $sum: { $cond: ["$alerts.speed_warning", 1, 0] } } } },
  { $project: { _id: 0, corridor: "$_id", pings: 1, avg_speed_kmh: { $round: ["$avg_speed_kmh", 1] },
                max_speed_kmh: { $round: ["$max_speed_kmh", 1] }, speeding_pings: 1 } },
  { $sort: { corridor: 1 } }
]).toArray());

// Validation check: a document that breaks the rules is refused
print("\nVALIDATION: inserting a parcel with a bad waybill number");
try {
  db.parcel_tracking.insertOne({ waybill_number: "BAD-123", sender: { name: "x", phone: "1" },
    recipient: { name: "y", phone: "2" }, cargo_details: {}, route: {}, current_status: "Registered",
    checkpoints: [{ checkpoint_id: 1, status: "Registered", station: "Test", timestamp: new Date() }] });
  print("inserted (unexpected)");
} catch (e) {
  print("refused: " + e.message);
}

// TTL index on a separate demo collection (the real telemetry is historical, so it must not expire)
print("\nTTL DEMO: documents expire 30 seconds after recorded_at");
db.ttl_demo.drop();
db.ttl_demo.createIndex({ recorded_at: 1 }, { expireAfterSeconds: 30, name: "idx_ttl_demo_30s" });
db.ttl_demo.insertMany([
  { note: "old ping 1", recorded_at: new Date(Date.now() - 120000) },
  { note: "old ping 2", recorded_at: new Date(Date.now() - 90000) },
  { note: "ping not yet expired", recorded_at: new Date(Date.now() + 3600000) }
]);
print("documents before waiting: " + db.ttl_demo.countDocuments());
sleep(80000);
print("documents after waiting 80 s: " + db.ttl_demo.countDocuments());
printjson(db.ttl_demo.find({}, { _id: 0, note: 1 }).toArray());
db.ttl_demo.drop();
