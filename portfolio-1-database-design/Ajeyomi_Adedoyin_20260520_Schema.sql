-- ==============================================================================
-- Portfolio 1: Relational Database Schema DDL
-- Organization: Adedoyin Mobility and Logistics
-- Student Name: Adedoyin Ajeyomi
-- Student ID:   20260520
-- Engine:       PostgreSQL 14+ (Standard ANSI SQL compatible)
-- Description:  8-Table Core Academic Schema with KYC and Dashboard Fields
-- ==============================================================================

-- Clean up existing tables in reverse dependency order
DROP TABLE IF EXISTS parcels CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS routes CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS vehicles CASCADE;
DROP TABLE IF EXISTS stations CASCADE;

-- ------------------------------------------------------------------------------
-- 1. STATIONS: 6 Regional Hubs across Nigeria
-- ------------------------------------------------------------------------------
CREATE TABLE stations (
    station_id          SERIAL PRIMARY KEY,
    station_name        VARCHAR(100) NOT NULL UNIQUE,
    state               VARCHAR(50)  NOT NULL,
    address             TEXT         NOT NULL,
    contact_phone       VARCHAR(20)  NOT NULL,
    manager_name        VARCHAR(100) NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 2. VEHICLES: Fleet of 20 Commercial Interstate Assets
-- ------------------------------------------------------------------------------
CREATE TABLE vehicles (
    vehicle_id              SERIAL PRIMARY KEY,
    registration_number     VARCHAR(20)  NOT NULL UNIQUE,  -- Plate number
    chassis_number          VARCHAR(30)  NOT NULL UNIQUE,  -- VIN for asset KYC
    make_model              VARCHAR(80)  NOT NULL,         -- e.g., 'Toyota HiAce 2022'
    seating_capacity        INT          NOT NULL,
    current_station_id      INT          NOT NULL REFERENCES stations(station_id) ON DELETE RESTRICT,
    roadworthiness_expiry   DATE         NOT NULL,
    gps_tracker_id          VARCHAR(50)  NOT NULL UNIQUE,  -- Dashboard IoT Telemetry ID
    status                  VARCHAR(30)  NOT NULL DEFAULT 'Active',
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_vehicle_capacity CHECK (seating_capacity BETWEEN 7 AND 18),
    CONSTRAINT chk_vehicle_status   CHECK (status IN ('Active', 'In-Transit', 'Under-Maintenance', 'Decommissioned'))
);

-- ------------------------------------------------------------------------------
-- 3. DRIVERS: Driver Bio-Data and Regulatory KYC
-- ------------------------------------------------------------------------------
CREATE TABLE drivers (
    driver_id           SERIAL PRIMARY KEY,
    full_name           VARCHAR(120) NOT NULL,
    phone_number        VARCHAR(20)  NOT NULL UNIQUE,
    nin                 CHAR(11)     NOT NULL UNIQUE,      -- Nigerian 11-digit NIN
    license_number      VARCHAR(30)  NOT NULL UNIQUE,      -- FRSC Driver's License
    license_expiry      DATE         NOT NULL,
    assigned_vehicle_id INT          REFERENCES vehicles(vehicle_id) ON DELETE SET NULL,
    status              VARCHAR(30)  NOT NULL DEFAULT 'Available',
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_driver_nin    CHECK (nin ~ '^[0-9]{11}$'),
    CONSTRAINT chk_driver_status CHECK (status IN ('Available', 'On-Trip', 'On-Leave', 'Suspended'))
);

-- ------------------------------------------------------------------------------
-- 4. CUSTOMERS: Passengers and Parcel Senders with KYC
-- ------------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id             SERIAL PRIMARY KEY,
    full_name               VARCHAR(120) NOT NULL,
    phone_number            VARCHAR(20)  NOT NULL UNIQUE,
    email                   VARCHAR(100),
    nin                     CHAR(11),                          -- Customer KYC / Security
    emergency_contact_name  VARCHAR(120) NOT NULL,             -- FRSC Manifest compliance
    emergency_contact_phone VARCHAR(20)  NOT NULL,
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------------------------
-- 5. ROUTES: Interstate Corridors connecting Regional Stations
-- ------------------------------------------------------------------------------
CREATE TABLE routes (
    route_id                SERIAL PRIMARY KEY,
    origin_station_id       INT            NOT NULL REFERENCES stations(station_id) ON DELETE RESTRICT,
    destination_station_id  INT            NOT NULL REFERENCES stations(station_id) ON DELETE RESTRICT,
    distance_km             NUMERIC(7, 2)  NOT NULL,
    est_travel_hours        NUMERIC(4, 2)  NOT NULL,
    base_passenger_fare     NUMERIC(10, 2) NOT NULL,
    base_parcel_rate        NUMERIC(10, 2) NOT NULL,
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_route_pair CHECK (origin_station_id <> destination_station_id),
    CONSTRAINT uq_origin_destination UNIQUE (origin_station_id, destination_station_id),
    CONSTRAINT chk_route_metrics CHECK (
        distance_km > 0 AND est_travel_hours > 0 AND base_passenger_fare >= 0 AND base_parcel_rate >= 0
    )
);

-- ------------------------------------------------------------------------------
-- 6. TRIPS: Scheduled and Executed Interstate Journeys
-- ------------------------------------------------------------------------------
CREATE TABLE trips (
    trip_id                 SERIAL PRIMARY KEY,
    route_id                INT         NOT NULL REFERENCES routes(route_id) ON DELETE RESTRICT,
    vehicle_id              INT         NOT NULL REFERENCES vehicles(vehicle_id) ON DELETE RESTRICT,
    driver_id               INT         NOT NULL REFERENCES drivers(driver_id) ON DELETE RESTRICT,
    departure_datetime      TIMESTAMP WITH TIME ZONE NOT NULL,
    arrival_datetime        TIMESTAMP WITH TIME ZONE,
    trip_status             VARCHAR(30) NOT NULL DEFAULT 'Scheduled',
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_trip_datetimes CHECK (arrival_datetime IS NULL OR arrival_datetime > departure_datetime),
    CONSTRAINT chk_trip_status    CHECK (trip_status IN ('Scheduled', 'Boarding', 'In-Transit', 'Arrived', 'Cancelled'))
);

-- ------------------------------------------------------------------------------
-- 7. BOOKINGS: Seat Reservations & Manifest (Anti-Double Booking)
-- ------------------------------------------------------------------------------
CREATE TABLE bookings (
    booking_id          SERIAL PRIMARY KEY,
    trip_id             INT            NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
    customer_id         INT            NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    seat_number         INT            NOT NULL,
    ticket_amount       NUMERIC(10, 2) NOT NULL,
    booking_status      VARCHAR(30)    NOT NULL DEFAULT 'Confirmed',
    payment_reference   VARCHAR(60)    NOT NULL UNIQUE,    -- Payment gateway / POS ref
    booking_timestamp   TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_trip_seat_no     UNIQUE (trip_id, seat_number),
    CONSTRAINT chk_booking_amount  CHECK (ticket_amount > 0),
    CONSTRAINT chk_booking_status  CHECK (booking_status IN ('Confirmed', 'Checked-In', 'Completed', 'Cancelled', 'Refunded'))
);

-- ------------------------------------------------------------------------------
-- 8. PARCELS: Waybill Logistics Cargo Tracking
-- ------------------------------------------------------------------------------
CREATE TABLE parcels (
    parcel_id           SERIAL PRIMARY KEY,
    trip_id             INT            REFERENCES trips(trip_id) ON DELETE SET NULL,
    sender_customer_id  INT            NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    recipient_name      VARCHAR(120)   NOT NULL,
    recipient_phone     VARCHAR(20)    NOT NULL,
    recipient_nin       CHAR(11),                          -- Recipient KYC verification
    waybill_number      VARCHAR(40)    NOT NULL UNIQUE,    -- Tracking Code (e.g., AML-WB-2026-001)
    weight_kg           NUMERIC(6, 2)  NOT NULL,
    declared_value      NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    delivery_status     VARCHAR(30)    NOT NULL DEFAULT 'Registered',
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_parcel_weight   CHECK (weight_kg > 0 AND weight_kg <= 100),
    CONSTRAINT chk_delivery_status CHECK (
        delivery_status IN ('Registered', 'Loaded', 'In-Transit', 'Arrived-Hub', 'Delivered', 'Returned')
    )
);

-- ------------------------------------------------------------------------------
-- Performance Indexes for Operational Queries and Dashboard Lookups
-- ------------------------------------------------------------------------------
CREATE INDEX idx_trips_route_date       ON trips(route_id, departure_datetime);
CREATE INDEX idx_trips_status           ON trips(trip_status);
CREATE INDEX idx_bookings_trip          ON bookings(trip_id);
CREATE INDEX idx_bookings_customer      ON bookings(customer_id);
CREATE INDEX idx_parcels_waybill        ON parcels(waybill_number);
CREATE INDEX idx_parcels_trip           ON parcels(trip_id);
CREATE INDEX idx_parcels_status         ON parcels(delivery_status);
