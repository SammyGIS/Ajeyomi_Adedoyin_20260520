/**
 * ============================================================================
 * MIVA OPEN UNIVERSITY - MIT 8103: ADVANCED DATABASE SYSTEMS
 * PORTFOLIO 4: NoSQL DATABASES (DOCUMENT DATA STORE - MONGODB)
 * ============================================================================
 * Student Name: Adedoyin Ajeyomi
 * Student ID:   20260520
 * Programme:    Master of Information Technology (MIT)
 * Case Study:   Adedoyin Mobility and Logistics
 * File:         Ajeyomi_Adedoyin_20260520_MongoDB_Queries.js
 * Database:     adedoyin_mobility_nosql
 * Description:  Production-grade MongoDB (mongosh) script demonstrating:
 *               1. Database setup with strict JSON Schema Validation ($jsonSchema)
 *               2. Seed data insertion for vehicle telemetry & parcel tracking
 *               3. Specialised Indexing (2dsphere, Compound B-tree, TTL, Multikey)
 *               4. 5 Operational Queries and Complex Aggregation Pipelines
 *               5. Performance benchmarking with explain("executionStats")
 * ============================================================================
 */

// ----------------------------------------------------------------------------
// STEP 1: INITIALISE DATABASE AND SCHEMA VALIDATION
// ----------------------------------------------------------------------------

use adedoyin_mobility_nosql;

// Drop collections if they exist for clean rerun
db.vehicle_telemetry.drop();
db.parcel_tracking.drop();

// Create 'vehicle_telemetry' collection with strict JSON Schema Validator
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
          pattern: "^[A-Z]{3}-[0-9]{3}-[A-Z]{2}$",
          description: "Nigerian vehicle registration format (e.g. LAG-101-XA)"
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
                bsonType: "double"
              },
              description: "[longitude, latitude] in decimal degrees"
            }
          }
        },
        metrics: {
          bsonType: "object",
          required: ["speed_kmh", "fuel_level_percent", "odometer_km"],
          properties: {
            speed_kmh: { bsonType: "double", minimum: 0.0, maximum: 200.0 },
            fuel_level_percent: { bsonType: "double", minimum: 0.0, maximum: 100.0 },
            engine_temp_celsius: { bsonType: "double" },
            odometer_km: { bsonType: "double", minimum: 0.0 }
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

// Create 'parcel_tracking' collection with strict JSON Schema Validator
db.createCollection("parcel_tracking", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["waybill_number", "sender", "recipient", "cargo_details", "route", "current_status", "checkpoints"],
      properties: {
        waybill_number: {
          bsonType: "string",
          pattern: "^AML-WB-[0-9]{4}-[0-9]{4}$",
          description: "Standard AML tracking waybill format (e.g. AML-WB-2026-0001)"
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

// ----------------------------------------------------------------------------
// STEP 2: INSERT SEED DATA
// ----------------------------------------------------------------------------

db.vehicle_telemetry.insertMany([
  {
    vehicle_id: NumberInt(1),
    registration_number: "LAG-101-XA",
    vehicle_type: "Toyota HiAce Bus (16 Seats)",
    gps_tracker_id: "GPS-AML-001",
    route_corridor: "Lagos-Ibadan-Abuja",
    current_trip_id: NumberInt(1),
    driver: { driver_id: NumberInt(1), name: "Babatunde Alabi", license_number: "AAA12345678" },
    location: { type: "Point", coordinates: [3.3792, 6.5244] },
    location_address: "Ojota Regional Terminal Exit, Lagos",
    metrics: { speed_kmh: 45.0, fuel_level_percent: 95.0, engine_temp_celsius: 86.0, odometer_km: 142350.0 },
    alerts: { speed_warning: false, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-68), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T06:30:00Z")
  },
  {
    vehicle_id: NumberInt(1),
    registration_number: "LAG-101-XA",
    vehicle_type: "Toyota HiAce Bus (16 Seats)",
    gps_tracker_id: "GPS-AML-001",
    route_corridor: "Lagos-Ibadan-Abuja",
    current_trip_id: NumberInt(1),
    driver: { driver_id: NumberInt(1), name: "Babatunde Alabi", license_number: "AAA12345678" },
    location: { type: "Point", coordinates: [3.6184, 6.8920] },
    location_address: "Lagos-Ibadan Expressway, Sagamu Interchange",
    metrics: { speed_kmh: 92.5, fuel_level_percent: 88.0, engine_temp_celsius: 89.5, odometer_km: 142412.0 },
    alerts: { speed_warning: false, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-75), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T07:45:00Z")
  },
  {
    vehicle_id: NumberInt(1),
    registration_number: "LAG-101-XA",
    vehicle_type: "Toyota HiAce Bus (16 Seats)",
    gps_tracker_id: "GPS-AML-001",
    route_corridor: "Lagos-Ibadan-Abuja",
    current_trip_id: NumberInt(1),
    driver: { driver_id: NumberInt(1), name: "Babatunde Alabi", license_number: "AAA12345678" },
    location: { type: "Point", coordinates: [3.9167, 7.3775] },
    location_address: "Iwo Road Interchange Hub, Ibadan",
    metrics: { speed_kmh: 15.0, fuel_level_percent: 81.0, engine_temp_celsius: 91.0, odometer_km: 142485.0 },
    alerts: { speed_warning: false, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-70), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T09:10:00Z")
  },
  {
    vehicle_id: NumberInt(1),
    registration_number: "LAG-101-XA",
    vehicle_type: "Toyota HiAce Bus (16 Seats)",
    gps_tracker_id: "GPS-AML-001",
    route_corridor: "Lagos-Ibadan-Abuja",
    current_trip_id: NumberInt(1),
    driver: { driver_id: NumberInt(1), name: "Babatunde Alabi", license_number: "AAA12345678" },
    location: { type: "Point", coordinates: [6.0520, 8.4210] },
    location_address: "Lokoja-Abuja Expressway, Koton-Karfe corridor",
    metrics: { speed_kmh: 108.0, fuel_level_percent: 58.5, engine_temp_celsius: 95.5, odometer_km: 142820.0 },
    alerts: { speed_warning: true, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-84), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T13:45:00Z")
  },
  {
    vehicle_id: NumberInt(2),
    registration_number: "ABJ-202-BC",
    vehicle_type: "Toyota Sienna Minivan (7 Seats)",
    gps_tracker_id: "GPS-AML-002",
    route_corridor: "Abuja-Kaduna-Kano",
    current_trip_id: NumberInt(4),
    driver: { driver_id: NumberInt(2), name: "Chukwudi Okonkwo", license_number: "BBB87654321" },
    location: { type: "Point", coordinates: [7.4913, 9.0765] },
    location_address: "Utako Central Terminal, Abuja",
    metrics: { speed_kmh: 0.0, fuel_level_percent: 100.0, engine_temp_celsius: 78.0, odometer_km: 98450.0 },
    alerts: { speed_warning: false, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Excellent", cellular_signal_dbm: NumberInt(-62), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T07:00:00Z")
  },
  {
    vehicle_id: NumberInt(2),
    registration_number: "ABJ-202-BC",
    vehicle_type: "Toyota Sienna Minivan (7 Seats)",
    gps_tracker_id: "GPS-AML-002",
    route_corridor: "Abuja-Kaduna-Kano",
    current_trip_id: NumberInt(4),
    driver: { driver_id: NumberInt(2), name: "Chukwudi Okonkwo", license_number: "BBB87654321" },
    location: { type: "Point", coordinates: [7.4382, 10.5105] },
    location_address: "Abuja-Kaduna Dual Carriage, Toll Gate Bypass",
    metrics: { speed_kmh: 104.2, fuel_level_percent: 82.0, engine_temp_celsius: 93.0, odometer_km: 98640.0 },
    alerts: { speed_warning: true, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-81), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T09:30:00Z")
  },
  {
    vehicle_id: NumberInt(2),
    registration_number: "ABJ-202-BC",
    vehicle_type: "Toyota Sienna Minivan (7 Seats)",
    gps_tracker_id: "GPS-AML-002",
    route_corridor: "Abuja-Kaduna-Kano",
    current_trip_id: NumberInt(4),
    driver: { driver_id: NumberInt(2), name: "Chukwudi Okonkwo", license_number: "BBB87654321" },
    location: { type: "Point", coordinates: [8.5167, 12.0000] },
    location_address: "Sabon Gari Regional Terminal, Kano",
    metrics: { speed_kmh: 0.0, fuel_level_percent: 48.0, engine_temp_celsius: 84.0, odometer_km: 98920.0 },
    alerts: { speed_warning: false, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-66), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T13:00:00Z")
  },
  {
    vehicle_id: NumberInt(3),
    registration_number: "BEN-303-CD",
    vehicle_type: "Toyota HiAce Bus (16 Seats)",
    gps_tracker_id: "GPS-AML-003",
    route_corridor: "Benin-Ore-Lagos",
    current_trip_id: NumberInt(7),
    driver: { driver_id: NumberInt(3), name: "Ibrahim Danladi", license_number: "CCC11223344" },
    location: { type: "Point", coordinates: [5.6037, 6.3350] },
    location_address: "Ramat Park Terminal, Benin City",
    metrics: { speed_kmh: 0.0, fuel_level_percent: 98.0, engine_temp_celsius: 76.0, odometer_km: 115200.0 },
    alerts: { speed_warning: false, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-69), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T06:00:00Z")
  },
  {
    vehicle_id: NumberInt(3),
    registration_number: "BEN-303-CD",
    vehicle_type: "Toyota HiAce Bus (16 Seats)",
    gps_tracker_id: "GPS-AML-003",
    route_corridor: "Benin-Ore-Lagos",
    current_trip_id: NumberInt(7),
    driver: { driver_id: NumberInt(3), name: "Ibrahim Danladi", license_number: "CCC11223344" },
    location: { type: "Point", coordinates: [4.8820, 6.7450] },
    location_address: "Sagamu-Benin Expressway, Ore Waypoint Rest Stop",
    metrics: { speed_kmh: 78.0, fuel_level_percent: 74.0, engine_temp_celsius: 90.0, odometer_km: 115340.0 },
    alerts: { speed_warning: false, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-79), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T08:50:00Z")
  },
  {
    vehicle_id: NumberInt(4),
    registration_number: "ENU-404-EF",
    vehicle_type: "Toyota Sienna Minivan (7 Seats)",
    gps_tracker_id: "GPS-AML-004",
    route_corridor: "Enugu-Makurdi-Abuja",
    current_trip_id: NumberInt(11),
    driver: { driver_id: NumberInt(4), name: "Emeka Okereke", license_number: "DDD55667788" },
    location: { type: "Point", coordinates: [7.5086, 6.4584] },
    location_address: "Holy Ghost Regional Terminal, Enugu",
    metrics: { speed_kmh: 0.0, fuel_level_percent: 96.0, engine_temp_celsius: 75.0, odometer_km: 87400.0 },
    alerts: { speed_warning: false, harsh_braking: false, engine_temp_warning: false, fuel_leak_detected: false },
    device_status: { battery_health: "Good", cellular_signal_dbm: NumberInt(-71), firmware_version: "v3.4.1" },
    recorded_at: ISODate("2026-10-28T06:15:00Z")
  }
]);

db.parcel_tracking.insertMany([
  {
    waybill_number: "AML-WB-2026-0001",
    sender: { customer_id: NumberInt(101), name: "Chinedu Okafor", phone: "+2348031234567", nin: "11223344556" },
    recipient: { name: "Amina Bello", phone: "+2348099887766", nin_required_for_pickup: true, verified_nin: null },
    cargo_details: {
      category: "Electronics",
      description: "2x Dell Laptops and Accessories",
      weight_kg: 4.5,
      declared_value_ngn: 180000.0,
      is_fragile: true,
      insurance_covered: true,
      storage_condition: "Ambient Dry"
    },
    route: { origin_hub: "Lagos (Ojota)", destination_hub: "Abuja (Utako)", assigned_vehicle_reg: "LAG-101-XA", assigned_trip_id: NumberInt(1) },
    current_status: "In-Transit",
    fee_details: { base_freight_ngn: 9500.0, insurance_ngn: 1800.0, vat_ngn: 847.5, total_ngn: 12147.5, payment_status: "Paid (Online Monnify)" },
    checkpoints: [
      {
        checkpoint_id: NumberInt(1),
        status: "Registered",
        station: "Lagos Ojota Terminal",
        location_coords: [3.3792, 6.5244],
        timestamp: ISODate("2026-10-28T06:15:00Z"),
        handled_by: "Folake Adebayo (Station Officer)",
        security_check_passed: true,
        notes: "Package inspected, barcode label AML-WB-2026-0001 generated, fragile stickers applied."
      },
      {
        checkpoint_id: NumberInt(2),
        status: "Loaded",
        station: "Lagos Ojota Terminal",
        location_coords: [3.3792, 6.5244],
        timestamp: ISODate("2026-10-28T07:10:00Z"),
        handled_by: "Babatunde Alabi (Driver)",
        security_check_passed: true,
        notes: "Securely stowed into overhead secure compartment of bus LAG-101-XA."
      },
      {
        checkpoint_id: NumberInt(3),
        status: "In-Transit",
        station: "Sagamu Interchange Checkpoint",
        location_coords: [3.6184, 6.8920],
        timestamp: ISODate("2026-10-28T08:15:00Z"),
        handled_by: "Automated GPS Geofence",
        security_check_passed: true,
        notes: "Vehicle entered Ogun corridor heading north towards Ibadan/Abuja."
      }
    ]
  },
  {
    waybill_number: "AML-WB-2026-0002",
    sender: { customer_id: NumberInt(104), name: "Tunde Bakare", phone: "+2348023456789", nin: "22334455667" },
    recipient: { name: "Emeka Eze", phone: "+2348077665544", nin_required_for_pickup: true, verified_nin: "98765432101" },
    cargo_details: {
      category: "Medical Supplies",
      description: "Temperature-controlled Insulin Vials & Reagents",
      weight_kg: 12.0,
      declared_value_ngn: 450000.0,
      is_fragile: true,
      insurance_covered: true,
      storage_condition: "Cold Chain (2-8 C)"
    },
    route: { origin_hub: "Abuja (Utako)", destination_hub: "Kano (Sabon Gari)", assigned_vehicle_reg: "ABJ-202-BC", assigned_trip_id: NumberInt(4) },
    current_status: "Delivered",
    fee_details: { base_freight_ngn: 18000.0, insurance_ngn: 4500.0, vat_ngn: 1687.5, total_ngn: 24187.5, payment_status: "Paid (POS Card)" },
    checkpoints: [
      {
        checkpoint_id: NumberInt(1),
        status: "Registered",
        station: "Abuja Utako Central",
        location_coords: [7.4913, 9.0765],
        timestamp: ISODate("2026-10-27T08:00:00Z"),
        handled_by: "Usman Garba (Dispatch Officer)",
        security_check_passed: true,
        notes: "Cold-chain thermal insulation container verified at 4.2 C."
      },
      {
        checkpoint_id: NumberInt(2),
        status: "Loaded",
        station: "Abuja Utako Central",
        location_coords: [7.4913, 9.0765],
        timestamp: ISODate("2026-10-27T08:45:00Z"),
        handled_by: "Chukwudi Okonkwo (Driver)",
        security_check_passed: true,
        notes: "Loaded into climate-secured cabin locker of Sienna ABJ-202-BC."
      },
      {
        checkpoint_id: NumberInt(3),
        status: "In-Transit",
        station: "Kaduna Bypass Waypoint",
        location_coords: [7.4382, 10.5105],
        timestamp: ISODate("2026-10-27T11:20:00Z"),
        handled_by: "Automated GPS Geofence",
        security_check_passed: true,
        notes: "Transiting Kaduna corridor without delay."
      },
      {
        checkpoint_id: NumberInt(4),
        status: "Arrived-Hub",
        station: "Kano Sabon Gari Terminal",
        location_coords: [8.5167, 12.0000],
        timestamp: ISODate("2026-10-27T15:45:00Z"),
        handled_by: "Aliyu Musa (Hub Supervisor)",
        security_check_passed: true,
        notes: "Offloaded, temperature logged at 4.8 C, stored in cold storage."
      },
      {
        checkpoint_id: NumberInt(5),
        status: "Delivered",
        station: "Kano Sabon Gari Terminal",
        location_coords: [8.5167, 12.0000],
        timestamp: ISODate("2026-10-27T17:10:00Z"),
        handled_by: "Aliyu Musa (Hub Supervisor)",
        security_check_passed: true,
        notes: "Recipient verified with valid NIN: 98765432101. Digital signature received."
      }
    ]
  },
  {
    waybill_number: "AML-WB-2026-0003",
    sender: { customer_id: NumberInt(108), name: "Ngozi Adeleke", phone: "+2348055443322", nin: "33445566778" },
    recipient: { name: "Funmilayo Olufemi", phone: "+2348033221100", nin_required_for_pickup: false, verified_nin: null },
    cargo_details: {
      category: "Apparel & Textiles",
      description: "50 Yards Aso-Oke Fabric in 2 bundles",
      weight_kg: 8.0,
      declared_value_ngn: 75000.0,
      is_fragile: false,
      insurance_covered: false,
      storage_condition: "Ambient Dry"
    },
    route: { origin_hub: "Benin City (Ramat Park)", destination_hub: "Lagos (Ojota)", assigned_vehicle_reg: "BEN-303-CD", assigned_trip_id: NumberInt(7) },
    current_status: "In-Transit",
    fee_details: { base_freight_ngn: 8000.0, insurance_ngn: 0.0, vat_ngn: 600.0, total_ngn: 8600.0, payment_status: "Paid (Direct Cash at Station)" },
    checkpoints: [
      {
        checkpoint_id: NumberInt(1),
        status: "Registered",
        station: "Benin Ramat Park Terminal",
        location_coords: [5.6037, 6.3350],
        timestamp: ISODate("2026-10-28T06:05:00Z"),
        handled_by: "Osasere Igbinovia (Clerk)",
        security_check_passed: true,
        notes: "Textile package weighed, sealed, and tagged."
      },
      {
        checkpoint_id: NumberInt(2),
        status: "Loaded",
        station: "Benin Ramat Park Terminal",
        location_coords: [5.6037, 6.3350],
        timestamp: ISODate("2026-10-28T06:45:00Z"),
        handled_by: "Ibrahim Danladi (Driver)",
        security_check_passed: true,
        notes: "Loaded into trunk luggage hold of bus BEN-303-CD."
      },
      {
        checkpoint_id: NumberInt(3),
        status: "In-Transit",
        station: "Ore Waypoint Hub",
        location_coords: [4.8820, 6.7450],
        timestamp: ISODate("2026-10-28T08:55:00Z"),
        handled_by: "Ore Terminal Gatekeeper",
        security_check_passed: true,
        notes: "Interstate transit checkpoint clearance confirmed."
      }
    ]
  },
  {
    waybill_number: "AML-WB-2026-0004",
    sender: { customer_id: NumberInt(115), name: "Abubakar Sadiq", phone: "+2348181239876", nin: "44556677889" },
    recipient: { name: "Zainab Mohammed", phone: "+2348123450987", nin_required_for_pickup: true, verified_nin: null },
    cargo_details: {
      category: "Legal & Corporate Documents",
      description: "Sealed Land Title Deeds & Court Filings",
      weight_kg: 1.2,
      declared_value_ngn: 200000.0,
      is_fragile: false,
      insurance_covered: true,
      storage_condition: "Waterproof Pouch"
    },
    route: { origin_hub: "Kano (Sabon Gari)", destination_hub: "Abuja (Utako)", assigned_vehicle_reg: "ABJ-202-BC", assigned_trip_id: NumberInt(5) },
    current_status: "Registered",
    fee_details: { base_freight_ngn: 5000.0, insurance_ngn: 2000.0, vat_ngn: 525.0, total_ngn: 7525.0, payment_status: "Paid (Online Transfer)" },
    checkpoints: [
      {
        checkpoint_id: NumberInt(1),
        status: "Registered",
        station: "Kano Sabon Gari Terminal",
        location_coords: [8.5167, 12.0000],
        timestamp: ISODate("2026-10-28T08:00:00Z"),
        handled_by: "Aliyu Musa (Hub Supervisor)",
        security_check_passed: true,
        notes: "Sealed tamper-evident envelope registered. Awaiting loading."
      }
    ]
  },
  {
    waybill_number: "AML-WB-2026-0005",
    sender: { customer_id: NumberInt(120), name: "Kehinde Ogundipe", phone: "+2348066778899", nin: "55667788990" },
    recipient: { name: "Biodun Ajayi", phone: "+2348088990011", nin_required_for_pickup: true, verified_nin: "66778899001" },
    cargo_details: {
      category: "Automotive Spare Parts",
      description: "Alternator & Brake Calipers for HiAce Bus",
      weight_kg: 15.5,
      declared_value_ngn: 140000.0,
      is_fragile: false,
      insurance_covered: true,
      storage_condition: "Heavy Duty Box"
    },
    route: { origin_hub: "Lagos (Ojota)", destination_hub: "Ibadan (Iwo Road)", assigned_vehicle_reg: "LAG-101-XA", assigned_trip_id: NumberInt(1) },
    current_status: "Arrived-Hub",
    fee_details: { base_freight_ngn: 6500.0, insurance_ngn: 1400.0, vat_ngn: 592.5, total_ngn: 8492.5, payment_status: "Paid (Online Debit Card)" },
    checkpoints: [
      {
        checkpoint_id: NumberInt(1),
        status: "Registered",
        station: "Lagos Ojota Terminal",
        location_coords: [3.3792, 6.5244],
        timestamp: ISODate("2026-10-28T06:20:00Z"),
        handled_by: "Folake Adebayo (Station Officer)",
        security_check_passed: true,
        notes: "Package inspected and secured."
      },
      {
        checkpoint_id: NumberInt(2),
        status: "Loaded",
        station: "Lagos Ojota Terminal",
        location_coords: [3.3792, 6.5244],
        timestamp: ISODate("2026-10-28T07:12:00Z"),
        handled_by: "Babatunde Alabi (Driver)",
        security_check_passed: true,
        notes: "Loaded into bus LAG-101-XA rear floor hold."
      },
      {
        checkpoint_id: NumberInt(3),
        status: "Arrived-Hub",
        station: "Ibadan Iwo Road Terminal",
        location_coords: [3.9167, 7.3775],
        timestamp: ISODate("2026-10-28T09:20:00Z"),
        handled_by: "Kolapo Adeleke (Station Officer)",
        security_check_passed: true,
        notes: "Offloaded at Ibadan dropoff hub. Recipient SMS generated."
      }
    ]
  }
]);

// ----------------------------------------------------------------------------
// STEP 3: CREATE SPECIALISED INDEXES
// ----------------------------------------------------------------------------

// Index 1: 2dsphere index for spherical geospatial proximity queries
db.vehicle_telemetry.createIndex(
  { location: "2dsphere" },
  { name: "idx_telemetry_2dsphere_location" }
);

// Index 2: Compound index for vehicle time-series chronology
db.vehicle_telemetry.createIndex(
  { vehicle_id: 1, recorded_at: -1 },
  { name: "idx_telemetry_vehicle_timestamp" }
);

// Index 3: Compound index for corridor and safety alerts
db.vehicle_telemetry.createIndex(
  { route_corridor: 1, "alerts.speed_warning": 1 },
  { name: "idx_telemetry_corridor_speed_alert" }
);

// Index 4: TTL (Time-To-Live) index for automated retention management (30 days)
db.vehicle_telemetry.createIndex(
  { recorded_at: 1 },
  { expireAfterSeconds: 2592000, name: "idx_telemetry_ttl_30d" }
);

// Index 5: Unique B-tree index on Waybill Number for fast package lookups
db.parcel_tracking.createIndex(
  { waybill_number: 1 },
  { unique: true, name: "idx_parcel_waybill_unique" }
);

// Index 6: Multikey index for package status and handling station tracking
db.parcel_tracking.createIndex(
  { "checkpoints.status": 1, "checkpoints.station": 1 },
  { name: "idx_parcel_checkpoints_multikey" }
);

// Index 7: Compound index on route origin, destination, and current status
db.parcel_tracking.createIndex(
  { "route.origin_hub": 1, "route.destination_hub": 1, current_status: 1 },
  { name: "idx_parcel_route_status" }
);

// ----------------------------------------------------------------------------
// STEP 4: FIVE OPERATIONAL NOSQL QUERIES & AGGREGATION PIPELINES
// ----------------------------------------------------------------------------

print("\n================================================================================");
print("QUERY 1: GEOSPATIAL PROXIMITY DISPATCH QUERY ($nearSphere)");
print("Business Objective: Find all fleet vehicles currently within 80km of Utako Hub, Abuja.");
print("================================================================================");

const nearbyVehicles = db.vehicle_telemetry.find({
  location: {
    $nearSphere: {
      $geometry: {
        type: "Point",
        coordinates: [7.4913, 9.0765] // Abuja Utako Central Terminal Coordinates
      },
      $maxDistance: 80000 // 80 kilometres in metres
    }
  }
}, {
  registration_number: 1,
  route_corridor: 1,
  "metrics.speed_kmh": 1,
  "metrics.fuel_level_percent": 1,
  location_address: 1,
  recorded_at: 1,
  _id: 0
}).toArray();

printjson(nearbyVehicles);


print("\n================================================================================");
print("QUERY 2: FLEET SAFETY AUDIT & SPEED VIOLATION MONITORING");
print("Business Objective: Identify vehicles exceeding the 100 km/h FRSC statutory speed limit.");
print("================================================================================");

const speedingVehicles = db.vehicle_telemetry.find({
  "alerts.speed_warning": true,
  "metrics.speed_kmh": { $gt: 100.0 }
}, {
  registration_number: 1,
  route_corridor: 1,
  "driver.name": 1,
  "metrics.speed_kmh": 1,
  location_address: 1,
  recorded_at: 1,
  _id: 0
}).sort({ "metrics.speed_kmh": -1 }).toArray();

printjson(speedingVehicles);


print("\n================================================================================");
print("QUERY 3: REAL-TIME PARCEL LIFECYCLE & AUDIT TRAIL LOOKUP");
print("Business Objective: Fetch end-to-end checkpoint verification for waybill AML-WB-2026-0002.");
print("================================================================================");

const parcelAuditTrail = db.parcel_tracking.findOne({
  waybill_number: "AML-WB-2026-0002"
}, {
  waybill_number: 1,
  "sender.name": 1,
  "recipient.name": 1,
  "recipient.verified_nin": 1,
  "cargo_details.category": 1,
  "cargo_details.storage_condition": 1,
  current_status: 1,
  checkpoints: 1,
  _id: 0
});

printjson(parcelAuditTrail);


print("\n================================================================================");
print("QUERY 4: AGGREGATION PIPELINE - TERMINAL THROUGHPUT & MILESTONE AUDIT");
print("Business Objective: Compute parcel scanning throughput grouped by hub and status.");
print("================================================================================");

const hubMilestonesPipeline = [
  // Stage 1: Deconstruct checkpoints array into individual milestone documents
  { $unwind: "$checkpoints" },
  
  // Stage 2: Group by station name and handling milestone status
  {
    $group: {
      _id: {
        station: "$checkpoints.station",
        milestone: "$checkpoints.status"
      },
      packages_processed: { $sum: 1 },
      last_event_logged: { $max: "$checkpoints.timestamp" }
    }
  },
  
  // Stage 3: Shape clean presentation projection
  {
    $project: {
      _id: 0,
      station_name: "$_id.station",
      milestone_status: "$_id.milestone",
      packages_processed: 1,
      last_event_logged: 1
    }
  },
  
  // Stage 4: Order by busiest hub
  { $sort: { packages_processed: -1, station_name: 1 } }
];

const hubThroughputResults = db.parcel_tracking.aggregate(hubMilestonesPipeline).toArray();
printjson(hubThroughputResults);


print("\n================================================================================");
print("QUERY 5: AGGREGATION PIPELINE - VEHICLE PERFORMANCE & TELEMETRY METRICS");
print("Business Objective: Calculate average speed, fuel drawdown, and alert counts per corridor.");
print("================================================================================");

const fleetPerformancePipeline = [
  // Stage 1: Group by vehicle registration and corridor
  {
    $group: {
      _id: {
        vehicle_reg: "$registration_number",
        corridor: "$route_corridor"
      },
      pings_recorded: { $sum: 1 },
      avg_speed_kmh: { $avg: "$metrics.speed_kmh" },
      max_speed_kmh: { $max: "$metrics.speed_kmh" },
      min_fuel_remaining_percent: { $min: "$metrics.fuel_level_percent" },
      speed_violations_count: {
        $sum: { $cond: [{ $eq: ["$alerts.speed_warning", true] }, 1, 0] }
      }
    }
  },
  
  // Stage 2: Format output metrics
  {
    $project: {
      _id: 0,
      vehicle_registration: "$_id.vehicle_reg",
      corridor: "$_id.corridor",
      pings_recorded: 1,
      avg_speed_kmh: { $round: ["$avg_speed_kmh", 1] },
      max_speed_kmh: { $round: ["$max_speed_kmh", 1] },
      min_fuel_remaining_percent: { $round: ["$min_fuel_remaining_percent", 1] },
      speed_violations_count: 1
    }
  },
  
  // Stage 3: Order by corridor and registration
  { $sort: { corridor: 1, vehicle_registration: 1 } }
];

const fleetMetricsResults = db.vehicle_telemetry.aggregate(fleetPerformancePipeline).toArray();
printjson(fleetMetricsResults);


// ----------------------------------------------------------------------------
// STEP 5: PERFORMANCE BENCHMARKING WITH EXPLAIN("executionStats")
// ----------------------------------------------------------------------------

print("\n================================================================================");
print("EXPLAIN PLAN 1: GEOSPATIAL 2DSPHERE INDEX SCAN (Query 1)");
print("================================================================================");

const explainGeo = db.vehicle_telemetry.find({
  location: {
    $nearSphere: {
      $geometry: {
        type: "Point",
        coordinates: [7.4913, 9.0765]
      },
      $maxDistance: 80000
    }
  }
}).explain("executionStats");

print("Winning Stage: " + explainGeo.executionStats.executionStages.stage);
print("Keys Examined: " + explainGeo.executionStats.totalKeysExamined);
print("Docs Examined: " + explainGeo.executionStats.totalDocsExamined);
print("Returned Docs: " + explainGeo.executionStats.nReturned);


print("\n================================================================================");
print("EXPLAIN PLAN 2: WAYBILL UNIQUE B-TREE INDEX SCAN (Query 3)");
print("================================================================================");

const explainWaybill = db.parcel_tracking.find({
  waybill_number: "AML-WB-2026-0002"
}).explain("executionStats");

print("Winning Stage: " + explainWaybill.executionStats.executionStages.stage);
print("Keys Examined: " + explainWaybill.executionStats.totalKeysExamined);
print("Docs Examined: " + explainWaybill.executionStats.totalDocsExamined);
print("Returned Docs: " + explainWaybill.executionStats.nReturned);
