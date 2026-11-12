-- Run this ONLY in the separate database adedoyin_mobility_bench, after loading
-- the Portfolio 1 schema and CSV data into it. It is not for adedoyin_mobility.
--
-- Why: with about 1,200 trips and 8,000 bookings every table fits in a few
-- memory pages, so PostgreSQL always chooses a sequential scan and indexes show
-- no benefit. This script copies the real records 49 more times (50 copies in
-- total) so index effects can be measured honestly. Each copy has new primary
-- keys, new unique references and dates shifted by 120 days.

BEGIN;

INSERT INTO trips (trip_id, route_id, vehicle_id, driver_id, departure_datetime, arrival_datetime, trip_status)
SELECT t.trip_id + 1200 * g,
       t.route_id,
       t.vehicle_id,
       t.driver_id,
       t.departure_datetime + g * INTERVAL '120 days',
       t.arrival_datetime   + g * INTERVAL '120 days',
       t.trip_status
FROM trips t
CROSS JOIN generate_series(1, 49) AS g
WHERE t.trip_id <= 1200;

INSERT INTO bookings (booking_id, trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference, booking_timestamp)
SELECT b.booking_id + 8000 * g,
       b.trip_id + 1200 * g,
       b.customer_id,
       b.seat_number,
       b.ticket_amount,
       b.booking_status,
       b.payment_reference || '-' || g,
       b.booking_timestamp + g * INTERVAL '120 days'
FROM bookings b
CROSS JOIN generate_series(1, 49) AS g
WHERE b.booking_id <= 8000;

INSERT INTO parcels (parcel_id, trip_id, sender_customer_id, recipient_name, recipient_phone, recipient_nin, waybill_number, weight_kg, declared_value, delivery_status, created_at)
SELECT p.parcel_id + 3500 * g,
       p.trip_id + 1200 * g,
       p.sender_customer_id,
       p.recipient_name,
       p.recipient_phone,
       p.recipient_nin,
       p.waybill_number || '-' || g,
       p.weight_kg,
       p.declared_value,
       p.delivery_status,
       p.created_at + g * INTERVAL '120 days'
FROM parcels p
CROSS JOIN generate_series(1, 49) AS g
WHERE p.parcel_id <= 3500;

COMMIT;

SELECT setval('trips_trip_id_seq',       (SELECT MAX(trip_id)    FROM trips));
SELECT setval('bookings_booking_id_seq', (SELECT MAX(booking_id) FROM bookings));
SELECT setval('parcels_parcel_id_seq',   (SELECT MAX(parcel_id)  FROM parcels));

ANALYZE;

SELECT 'trips' AS table_name, COUNT(*) AS row_count FROM trips
UNION ALL SELECT 'bookings', COUNT(*) FROM bookings
UNION ALL SELECT 'parcels',  COUNT(*) FROM parcels;
