-- ==============================================================================
-- Portfolio 2: Query Processing and Optimisation
-- Organization: Adedoyin Mobility and Logistics
-- Student Name: Adedoyin Ajeyomi
-- Student ID:   20260520
-- Course:       MIT 8103 - Advanced Database Systems
-- Engine:       PostgreSQL 14+
-- Description:  Core Business Queries, EXPLAIN ANALYZE Execution Plans,
--               and Indexing Strategies (Before vs After Optimisation)
-- ==============================================================================

-- Instructions:
-- 1. Run the base schema from Portfolio 1 first.
-- 2. Populate the tables using the seed data script.
-- 3. Execute the queries below with EXPLAIN ANALYZE to observe performance.
-- 4. Apply the indexes and re-run EXPLAIN ANALYZE to verify improvements.

-- ==============================================================================
-- QUERY 1: Route Revenue and Seat Booking Analysis
-- Purpose: Management report showing total ticket revenue and seat bookings
--          for each travel corridor (e.g., Lagos to Abuja, Abuja to Kano).
-- Tables Involved: routes, stations (origin & destination), trips, bookings
-- ==============================================================================

-- Step 1A: The Business Query
SELECT 
    r.route_id,
    s_orig.station_name AS origin_station,
    s_dest.station_name AS destination_station,
    COUNT(b.booking_id) AS total_tickets_sold,
    SUM(b.ticket_amount) AS total_revenue_ngn,
    ROUND(AVG(b.ticket_amount), 2) AS average_ticket_price_ngn
FROM routes r
JOIN stations s_orig ON r.origin_station_id = s_orig.station_id
JOIN stations s_dest ON r.destination_station_id = s_dest.station_id
JOIN trips t ON r.route_id = t.route_id
JOIN bookings b ON t.trip_id = b.trip_id
WHERE b.booking_status IN ('Confirmed', 'Checked-In', 'Completed')
GROUP BY r.route_id, s_orig.station_name, s_dest.station_name
ORDER BY total_revenue_ngn DESC;

-- Step 1B: Baseline Execution Plan (Before Extra Optimisation)
-- Notice the Sequential Scans across bookings and trips tables.
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    r.route_id,
    s_orig.station_name AS origin_station,
    s_dest.station_name AS destination_station,
    COUNT(b.booking_id) AS total_tickets_sold,
    SUM(b.ticket_amount) AS total_revenue_ngn,
    ROUND(AVG(b.ticket_amount), 2) AS average_ticket_price_ngn
FROM routes r
JOIN stations s_orig ON r.origin_station_id = s_orig.station_id
JOIN stations s_dest ON r.destination_station_id = s_dest.station_id
JOIN trips t ON r.route_id = t.route_id
JOIN bookings b ON t.trip_id = b.trip_id
WHERE b.booking_status IN ('Confirmed', 'Checked-In', 'Completed')
GROUP BY r.route_id, s_orig.station_name, s_dest.station_name
ORDER BY total_revenue_ngn DESC;

-- Step 1C: Optimisation Strategy
-- Create a composite index on bookings covering trip_id and booking_status.
-- This allows PostgreSQL to quickly filter valid tickets without scanning cancelled rows.
CREATE INDEX IF NOT EXISTS idx_opt_bookings_trip_status 
ON bookings (trip_id, booking_status) 
INCLUDE (ticket_amount);

-- Step 1D: Optimised Execution Plan (After Indexing)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    r.route_id,
    s_orig.station_name AS origin_station,
    s_dest.station_name AS destination_station,
    COUNT(b.booking_id) AS total_tickets_sold,
    SUM(b.ticket_amount) AS total_revenue_ngn,
    ROUND(AVG(b.ticket_amount), 2) AS average_ticket_price_ngn
FROM routes r
JOIN stations s_orig ON r.origin_station_id = s_orig.station_id
JOIN stations s_dest ON r.destination_station_id = s_dest.station_id
JOIN trips t ON r.route_id = t.route_id
JOIN bookings b ON t.trip_id = b.trip_id
WHERE b.booking_status IN ('Confirmed', 'Checked-In', 'Completed')
GROUP BY r.route_id, s_orig.station_name, s_dest.station_name
ORDER BY total_revenue_ngn DESC;


-- ==============================================================================
-- QUERY 2: Daily Scheduled Trip and Vehicle Dispatch Search
-- Purpose: Terminal dispatch officers search for active and scheduled trips
--          departing on a given date to verify vehicle and driver readiness.
-- Tables Involved: trips, routes, vehicles, drivers, stations
-- ==============================================================================

-- Step 2A: The Business Query
SELECT 
    t.trip_id,
    t.departure_datetime,
    t.trip_status,
    v.registration_number AS vehicle_plate,
    v.make_model AS vehicle_model,
    d.full_name AS driver_name,
    d.phone_number AS driver_phone,
    s_orig.station_name AS origin,
    s_dest.station_name AS destination
FROM trips t
JOIN routes r ON t.route_id = r.route_id
JOIN stations s_orig ON r.origin_station_id = s_orig.station_id
JOIN stations s_dest ON r.destination_station_id = s_dest.station_id
JOIN vehicles v ON t.vehicle_id = v.vehicle_id
JOIN drivers d ON t.driver_id = d.driver_id
WHERE t.trip_status IN ('Scheduled', 'Boarding')
  AND t.departure_datetime >= '2026-10-01 00:00:00+01'
  AND t.departure_datetime <  '2026-10-08 00:00:00+01'
ORDER BY t.departure_datetime ASC;

-- Step 2B: Baseline Execution Plan (Before Extra Optimisation)
-- Filter requires scanning every row in trips to check status and datetime.
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    t.trip_id,
    t.departure_datetime,
    t.trip_status,
    v.registration_number AS vehicle_plate,
    v.make_model AS vehicle_model,
    d.full_name AS driver_name,
    d.phone_number AS driver_phone,
    s_orig.station_name AS origin,
    s_dest.station_name AS destination
FROM trips t
JOIN routes r ON t.route_id = r.route_id
JOIN stations s_orig ON r.origin_station_id = s_orig.station_id
JOIN stations s_dest ON r.destination_station_id = s_dest.station_id
JOIN vehicles v ON t.vehicle_id = v.vehicle_id
JOIN drivers d ON t.driver_id = d.driver_id
WHERE t.trip_status IN ('Scheduled', 'Boarding')
  AND t.departure_datetime >= '2026-10-01 00:00:00+01'
  AND t.departure_datetime <  '2026-10-08 00:00:00+01'
ORDER BY t.departure_datetime ASC;

-- Step 2C: Optimisation Strategy
-- Create a composite B-tree index on trips (trip_status, departure_datetime).
-- This lets the planner jump straight to upcoming scheduled trips.
CREATE INDEX IF NOT EXISTS idx_opt_trips_status_datetime 
ON trips (trip_status, departure_datetime);

-- Step 2D: Optimised Execution Plan (After Indexing)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    t.trip_id,
    t.departure_datetime,
    t.trip_status,
    v.registration_number AS vehicle_plate,
    v.make_model AS vehicle_model,
    d.full_name AS driver_name,
    d.phone_number AS driver_phone,
    s_orig.station_name AS origin,
    s_dest.station_name AS destination
FROM trips t
JOIN routes r ON t.route_id = r.route_id
JOIN stations s_orig ON r.origin_station_id = s_orig.station_id
JOIN stations s_dest ON r.destination_station_id = s_dest.station_id
JOIN vehicles v ON t.vehicle_id = v.vehicle_id
JOIN drivers d ON t.driver_id = d.driver_id
WHERE t.trip_status IN ('Scheduled', 'Boarding')
  AND t.departure_datetime >= '2026-10-01 00:00:00+01'
  AND t.departure_datetime <  '2026-10-08 00:00:00+01'
ORDER BY t.departure_datetime ASC;


-- ==============================================================================
-- QUERY 3: Customer Parcel Tracking and Status Lookup
-- Purpose: Customer care desk searches for parcel delivery history by customer
--          phone number or waybill code.
-- Tables Involved: parcels, customers, trips, routes
-- ==============================================================================

-- Step 3A: The Business Query
SELECT 
    p.waybill_number,
    p.delivery_status,
    p.weight_kg,
    p.declared_value,
    c.full_name AS sender_name,
    c.phone_number AS sender_phone,
    p.recipient_name,
    p.recipient_phone,
    p.created_at AS date_dispatched
FROM parcels p
JOIN customers c ON p.sender_customer_id = c.customer_id
WHERE c.phone_number = '+2348031234567'
   OR p.delivery_status = 'In-Transit'
ORDER BY p.created_at DESC;

-- Step 3B: Baseline Execution Plan (Before Extra Optimisation)
-- Sequential Scan over parcels and customers without index on search keys.
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.waybill_number,
    p.delivery_status,
    p.weight_kg,
    p.declared_value,
    c.full_name AS sender_name,
    c.phone_number AS sender_phone,
    p.recipient_name,
    p.recipient_phone,
    p.created_at AS date_dispatched
FROM parcels p
JOIN customers c ON p.sender_customer_id = c.customer_id
WHERE c.phone_number = '+2348031234567'
   OR p.delivery_status = 'In-Transit'
ORDER BY p.created_at DESC;

-- Step 3C: Optimisation Strategy
-- 1. Ensure customers.phone_number has a fast lookup B-tree index.
-- 2. Add an index on parcels (delivery_status, created_at) to speed up parcel status queries.
CREATE INDEX IF NOT EXISTS idx_opt_customers_phone 
ON customers (phone_number);

CREATE INDEX IF NOT EXISTS idx_opt_parcels_status_created 
ON parcels (delivery_status, created_at DESC);

-- Step 3D: Optimised Execution Plan (After Indexing)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    p.waybill_number,
    p.delivery_status,
    p.weight_kg,
    p.declared_value,
    c.full_name AS sender_name,
    c.phone_number AS sender_phone,
    p.recipient_name,
    p.recipient_phone,
    p.created_at AS date_dispatched
FROM parcels p
JOIN customers c ON p.sender_customer_id = c.customer_id
WHERE c.phone_number = '+2348031234567'
   OR p.delivery_status = 'In-Transit'
ORDER BY p.created_at DESC;


-- ==============================================================================
-- QUERY 4: Driver Performance and Trip Workload Summary
-- Purpose: Operations supervisor evaluates driver productivity by calculating
--          the total trips completed and total passengers transported.
-- Tables Involved: drivers, trips, bookings
-- ==============================================================================

-- Step 4A: The Business Query
SELECT 
    d.driver_id,
    d.full_name AS driver_name,
    d.license_number,
    d.status AS driver_status,
    COUNT(DISTINCT t.trip_id) AS completed_trips_count,
    COUNT(b.booking_id) AS total_passengers_carried
FROM drivers d
LEFT JOIN trips t ON d.driver_id = t.driver_id AND t.trip_status = 'Arrived'
LEFT JOIN bookings b ON t.trip_id = b.trip_id AND b.booking_status IN ('Checked-In', 'Completed')
GROUP BY d.driver_id, d.full_name, d.license_number, d.status
ORDER BY completed_trips_count DESC, total_passengers_carried DESC;

-- Step 4B: Baseline Execution Plan (Before Extra Optimisation)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    d.driver_id,
    d.full_name AS driver_name,
    d.license_number,
    d.status AS driver_status,
    COUNT(DISTINCT t.trip_id) AS completed_trips_count,
    COUNT(b.booking_id) AS total_passengers_carried
FROM drivers d
LEFT JOIN trips t ON d.driver_id = t.driver_id AND t.trip_status = 'Arrived'
LEFT JOIN bookings b ON t.trip_id = b.trip_id AND b.booking_status IN ('Checked-In', 'Completed')
GROUP BY d.driver_id, d.full_name, d.license_number, d.status
ORDER BY completed_trips_count DESC, total_passengers_carried DESC;

-- Step 4C: Optimisation Strategy
-- Add an index on trips (driver_id, trip_status) to speed up foreign key joins
-- and status filtering without scanning all trips.
CREATE INDEX IF NOT EXISTS idx_opt_trips_driver_status 
ON trips (driver_id, trip_status);

-- Step 4D: Optimised Execution Plan (After Indexing)
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    d.driver_id,
    d.full_name AS driver_name,
    d.license_number,
    d.status AS driver_status,
    COUNT(DISTINCT t.trip_id) AS completed_trips_count,
    COUNT(b.booking_id) AS total_passengers_carried
FROM drivers d
LEFT JOIN trips t ON d.driver_id = t.driver_id AND t.trip_status = 'Arrived'
LEFT JOIN bookings b ON t.trip_id = b.trip_id AND b.booking_status IN ('Checked-In', 'Completed')
GROUP BY d.driver_id, d.full_name, d.license_number, d.status
ORDER BY completed_trips_count DESC, total_passengers_carried DESC;
