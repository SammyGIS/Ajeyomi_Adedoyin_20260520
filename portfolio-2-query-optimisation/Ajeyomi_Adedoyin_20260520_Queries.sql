-- Run in the benchmark database adedoyin_mobility_bench after the scale-up script.
-- From a terminal in the repository root (change the port if yours differs):
--   psql -U postgres -p 5433 -d adedoyin_mobility_bench -f portfolio-2-query-optimisation/Ajeyomi_Adedoyin_20260520_Queries.sql -o portfolio-2-query-optimisation/Ajeyomi_Adedoyin_20260520_Query_Execution_Plans.txt
--
-- The script removes the extra indexes created in Portfolio 1 (the baseline), records
-- EXPLAIN (ANALYZE, BUFFERS) for each query, creates the optimisation indexes, and
-- records the plans again. Primary key and unique constraint indexes always remain.

SET max_parallel_workers_per_gather = 0;
SET jit = off;

DROP INDEX IF EXISTS idx_trips_route_date;
DROP INDEX IF EXISTS idx_trips_status;
DROP INDEX IF EXISTS idx_bookings_trip;
DROP INDEX IF EXISTS idx_bookings_customer;
DROP INDEX IF EXISTS idx_parcels_waybill;
DROP INDEX IF EXISTS idx_parcels_trip;
DROP INDEX IF EXISTS idx_parcels_status;
DROP INDEX IF EXISTS idx_opt_trips_status_departure;
DROP INDEX IF EXISTS idx_opt_trips_route_departure;
DROP INDEX IF EXISTS idx_opt_bookings_trip_status;
DROP INDEX IF EXISTS idx_opt_parcels_sender;
ANALYZE;

\echo ================================================================================
\echo ENVIRONMENT
\echo ================================================================================
SELECT version();
SELECT 'trips' AS table_name, COUNT(*) AS row_count FROM trips
UNION ALL SELECT 'bookings', COUNT(*) FROM bookings
UNION ALL SELECT 'parcels',  COUNT(*) FROM parcels;

\echo
\echo ================================================================================
\echo QUERY RESULTS (first rows)
\echo ================================================================================
\echo
\echo QUERY 1: Route Revenue and Seat Booking Analysis
-- Management report: ticket revenue per travel corridor for completed trips in July 2026.
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
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-07-01'
  AND t.departure_datetime <  '2026-08-01'
  AND b.booking_status = 'Confirmed'
GROUP BY r.route_id, s_orig.station_name, s_dest.station_name
ORDER BY total_revenue_ngn DESC;
\echo
\echo QUERY 2: Weekly Trip and Vehicle Dispatch Register
-- Dispatch officers check the trips, vehicles and drivers on one route for one week.
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
WHERE t.route_id = 1
  AND t.departure_datetime >= '2026-07-06'
  AND t.departure_datetime <  '2026-07-13'
ORDER BY t.departure_datetime;
\echo
\echo QUERY 3: Customer Parcel Tracking by Sender Phone Number
-- Customer care desk looks up every parcel sent by one customer.
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
FROM customers c
JOIN parcels p ON p.sender_customer_id = c.customer_id
WHERE c.phone_number = '08171070189'
ORDER BY p.created_at DESC
LIMIT 10;
\echo
\echo QUERY 4: Driver Performance and Trip Workload for August 2026
-- Supervisor report: completed trips and confirmed passengers per driver.
SELECT
    d.driver_id,
    d.full_name AS driver_name,
    d.license_number,
    d.status AS driver_status,
    COUNT(DISTINCT t.trip_id) AS completed_trips_count,
    COUNT(b.booking_id) AS total_passengers_carried
FROM drivers d
JOIN trips t ON d.driver_id = t.driver_id
LEFT JOIN bookings b ON t.trip_id = b.trip_id AND b.booking_status = 'Confirmed'
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-08-01'
  AND t.departure_datetime <  '2026-09-01'
GROUP BY d.driver_id, d.full_name, d.license_number, d.status
ORDER BY completed_trips_count DESC, total_passengers_carried DESC;
\echo
\echo ================================================================================
\echo BASELINE EXECUTION PLANS (no optimisation indexes)
\echo ================================================================================
\echo
\echo [BASELINE] QUERY 1: Route Revenue and Seat Booking Analysis
-- warm-up run so the recorded plan reflects cached data
SELECT COUNT(*) AS warm_up_rows FROM (
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
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-07-01'
  AND t.departure_datetime <  '2026-08-01'
  AND b.booking_status = 'Confirmed'
GROUP BY r.route_id, s_orig.station_name, s_dest.station_name
ORDER BY total_revenue_ngn DESC
) q;
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
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-07-01'
  AND t.departure_datetime <  '2026-08-01'
  AND b.booking_status = 'Confirmed'
GROUP BY r.route_id, s_orig.station_name, s_dest.station_name
ORDER BY total_revenue_ngn DESC;
\echo
\echo [BASELINE] QUERY 2: Weekly Trip and Vehicle Dispatch Register
-- warm-up run so the recorded plan reflects cached data
SELECT COUNT(*) AS warm_up_rows FROM (
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
WHERE t.route_id = 1
  AND t.departure_datetime >= '2026-07-06'
  AND t.departure_datetime <  '2026-07-13'
ORDER BY t.departure_datetime
) q;
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
WHERE t.route_id = 1
  AND t.departure_datetime >= '2026-07-06'
  AND t.departure_datetime <  '2026-07-13'
ORDER BY t.departure_datetime;
\echo
\echo [BASELINE] QUERY 3: Customer Parcel Tracking by Sender Phone Number
-- warm-up run so the recorded plan reflects cached data
SELECT COUNT(*) AS warm_up_rows FROM (
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
FROM customers c
JOIN parcels p ON p.sender_customer_id = c.customer_id
WHERE c.phone_number = '08171070189'
ORDER BY p.created_at DESC
) q;
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
FROM customers c
JOIN parcels p ON p.sender_customer_id = c.customer_id
WHERE c.phone_number = '08171070189'
ORDER BY p.created_at DESC;
\echo
\echo [BASELINE] QUERY 4: Driver Performance and Trip Workload for August 2026
-- warm-up run so the recorded plan reflects cached data
SELECT COUNT(*) AS warm_up_rows FROM (
SELECT
    d.driver_id,
    d.full_name AS driver_name,
    d.license_number,
    d.status AS driver_status,
    COUNT(DISTINCT t.trip_id) AS completed_trips_count,
    COUNT(b.booking_id) AS total_passengers_carried
FROM drivers d
JOIN trips t ON d.driver_id = t.driver_id
LEFT JOIN bookings b ON t.trip_id = b.trip_id AND b.booking_status = 'Confirmed'
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-08-01'
  AND t.departure_datetime <  '2026-09-01'
GROUP BY d.driver_id, d.full_name, d.license_number, d.status
ORDER BY completed_trips_count DESC, total_passengers_carried DESC
) q;
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    d.driver_id,
    d.full_name AS driver_name,
    d.license_number,
    d.status AS driver_status,
    COUNT(DISTINCT t.trip_id) AS completed_trips_count,
    COUNT(b.booking_id) AS total_passengers_carried
FROM drivers d
JOIN trips t ON d.driver_id = t.driver_id
LEFT JOIN bookings b ON t.trip_id = b.trip_id AND b.booking_status = 'Confirmed'
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-08-01'
  AND t.departure_datetime <  '2026-09-01'
GROUP BY d.driver_id, d.full_name, d.license_number, d.status
ORDER BY completed_trips_count DESC, total_passengers_carried DESC;
\echo
\echo ================================================================================
\echo CREATING OPTIMISATION INDEXES
\echo ================================================================================
-- Queries 1 and 4: filter completed trips by date range without scanning every trip.
CREATE INDEX idx_opt_trips_status_departure
    ON trips (trip_status, departure_datetime) INCLUDE (route_id, driver_id);

-- Query 2: find one route's trips inside a date range.
CREATE INDEX idx_opt_trips_route_departure
    ON trips (route_id, departure_datetime);

-- Queries 1 and 4: covering index so booking amounts are read from the index alone.
CREATE INDEX idx_opt_bookings_trip_status
    ON bookings (trip_id, booking_status) INCLUDE (ticket_amount);

-- Query 3: find one sender's parcels, newest first, without scanning every parcel.
CREATE INDEX idx_opt_parcels_sender
    ON parcels (sender_customer_id, created_at DESC);

ANALYZE;

\echo ================================================================================
\echo OPTIMISED EXECUTION PLANS (with optimisation indexes)
\echo ================================================================================
\echo
\echo [OPTIMISED] QUERY 1: Route Revenue and Seat Booking Analysis
-- warm-up run so the recorded plan reflects cached data
SELECT COUNT(*) AS warm_up_rows FROM (
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
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-07-01'
  AND t.departure_datetime <  '2026-08-01'
  AND b.booking_status = 'Confirmed'
GROUP BY r.route_id, s_orig.station_name, s_dest.station_name
ORDER BY total_revenue_ngn DESC
) q;
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
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-07-01'
  AND t.departure_datetime <  '2026-08-01'
  AND b.booking_status = 'Confirmed'
GROUP BY r.route_id, s_orig.station_name, s_dest.station_name
ORDER BY total_revenue_ngn DESC;
\echo
\echo [OPTIMISED] QUERY 2: Weekly Trip and Vehicle Dispatch Register
-- warm-up run so the recorded plan reflects cached data
SELECT COUNT(*) AS warm_up_rows FROM (
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
WHERE t.route_id = 1
  AND t.departure_datetime >= '2026-07-06'
  AND t.departure_datetime <  '2026-07-13'
ORDER BY t.departure_datetime
) q;
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
WHERE t.route_id = 1
  AND t.departure_datetime >= '2026-07-06'
  AND t.departure_datetime <  '2026-07-13'
ORDER BY t.departure_datetime;
\echo
\echo [OPTIMISED] QUERY 3: Customer Parcel Tracking by Sender Phone Number
-- warm-up run so the recorded plan reflects cached data
SELECT COUNT(*) AS warm_up_rows FROM (
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
FROM customers c
JOIN parcels p ON p.sender_customer_id = c.customer_id
WHERE c.phone_number = '08171070189'
ORDER BY p.created_at DESC
) q;
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
FROM customers c
JOIN parcels p ON p.sender_customer_id = c.customer_id
WHERE c.phone_number = '08171070189'
ORDER BY p.created_at DESC;
\echo
\echo [OPTIMISED] QUERY 4: Driver Performance and Trip Workload for August 2026
-- warm-up run so the recorded plan reflects cached data
SELECT COUNT(*) AS warm_up_rows FROM (
SELECT
    d.driver_id,
    d.full_name AS driver_name,
    d.license_number,
    d.status AS driver_status,
    COUNT(DISTINCT t.trip_id) AS completed_trips_count,
    COUNT(b.booking_id) AS total_passengers_carried
FROM drivers d
JOIN trips t ON d.driver_id = t.driver_id
LEFT JOIN bookings b ON t.trip_id = b.trip_id AND b.booking_status = 'Confirmed'
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-08-01'
  AND t.departure_datetime <  '2026-09-01'
GROUP BY d.driver_id, d.full_name, d.license_number, d.status
ORDER BY completed_trips_count DESC, total_passengers_carried DESC
) q;
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    d.driver_id,
    d.full_name AS driver_name,
    d.license_number,
    d.status AS driver_status,
    COUNT(DISTINCT t.trip_id) AS completed_trips_count,
    COUNT(b.booking_id) AS total_passengers_carried
FROM drivers d
JOIN trips t ON d.driver_id = t.driver_id
LEFT JOIN bookings b ON t.trip_id = b.trip_id AND b.booking_status = 'Confirmed'
WHERE t.trip_status = 'Completed'
  AND t.departure_datetime >= '2026-08-01'
  AND t.departure_datetime <  '2026-09-01'
GROUP BY d.driver_id, d.full_name, d.license_number, d.status
ORDER BY completed_trips_count DESC, total_passengers_carried DESC;
