-- Run in adedoyin_mobility. Uses four new demo trips (9001 to 9004) because the real trips already have their seats booked.

-- Demo trips on route 3 (Lagos to Abuja)
DELETE FROM trips WHERE trip_id BETWEEN 9001 AND 9004;

INSERT INTO trips (trip_id, route_id, vehicle_id, driver_id, departure_datetime, trip_status) VALUES
    (9001, 3, 3, 3, '2026-12-01 07:00:00+01', 'Scheduled'),
    (9002, 3, 4, 4, '2026-12-01 09:00:00+01', 'Scheduled'),
    (9003, 3, 5, 5, '2026-12-01 11:00:00+01', 'Scheduled'),
    (9004, 3, 6, 6, '2026-12-01 13:00:00+01', 'Scheduled');

SELECT setval('bookings_booking_id_seq', (SELECT MAX(booking_id) FROM bookings));

-- Commit
BEGIN;

SELECT trip_id, route_id, vehicle_id, trip_status
FROM trips
WHERE trip_id = 9001 AND trip_status IN ('Scheduled', 'Boarding');

SELECT booking_id
FROM bookings
WHERE trip_id = 9001 AND seat_number = 3 AND booking_status <> 'Cancelled';

INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9001, 101, 3, 18500.00, 'Confirmed', 'PAY-TXN-1A-001');

COMMIT;

SELECT booking_id, trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference
FROM bookings
WHERE payment_reference = 'PAY-TXN-1A-001';

-- Rollback
BEGIN;

INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9001, 102, 4, 18500.00, 'Confirmed', 'PAY-TXN-1B-FAILED');

SELECT booking_id, seat_number, payment_reference
FROM bookings
WHERE payment_reference = 'PAY-TXN-1B-FAILED';

ROLLBACK;

SELECT booking_id, seat_number, payment_reference
FROM bookings
WHERE payment_reference = 'PAY-TXN-1B-FAILED';

-- Failed statement cancels the whole transaction
BEGIN;

INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9001, 103, 6, 18500.00, 'Confirmed', 'PAY-TXN-1C-SEAT6');

INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9001, 104, 7, -100.00, 'Confirmed', 'PAY-TXN-1C-SEAT7');

SELECT COUNT(*) FROM bookings WHERE trip_id = 9001;

ROLLBACK;

SELECT booking_id, seat_number, payment_reference
FROM bookings
WHERE payment_reference IN ('PAY-TXN-1C-SEAT6', 'PAY-TXN-1C-SEAT7');

-- Remove demo rows (bookings go with their trip)
-- DELETE FROM trips WHERE trip_id BETWEEN 9001 AND 9004;
