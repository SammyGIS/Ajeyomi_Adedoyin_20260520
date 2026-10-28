-- ==============================================================================
-- Portfolio 3: Transactions and Concurrency Control
-- Organization: Adedoyin Mobility and Logistics
-- Student Name: Adedoyin Ajeyomi
-- Student ID:   20260520
-- Course:       MIT 8103 - Advanced Database Systems
-- Engine:       PostgreSQL 14+
-- Description:  ACID Transactions, Row-Level Locking (SELECT FOR UPDATE),
--               Race Condition Prevention, Isolation Levels, and Deadlocks
-- ==============================================================================

-- ==============================================================================
-- SCENARIO 1: BASIC ACID TRANSACTION (COMMIT AND ROLLBACK)
-- Purpose: Demonstrate Atomicity and Consistency when booking an interstate seat.
--          Either all booking steps succeed together, or all changes are undone.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1A: Successful Transaction (COMMIT)
-- Customer (ID: 101) books Seat 3 on Trip 1 from Lagos to Abuja for ₦28,500.
-- ------------------------------------------------------------------------------
BEGIN;

-- Step 1: Verify the trip is active and has not departed
SELECT trip_id, route_id, vehicle_id, trip_status 
FROM trips 
WHERE trip_id = 1 AND trip_status IN ('Scheduled', 'Boarding');

-- Step 2: Verify Seat 3 is not already booked
SELECT booking_id 
FROM bookings 
WHERE trip_id = 1 AND seat_number = 3 AND booking_status <> 'Cancelled';

-- Step 3: Insert the confirmed passenger booking
INSERT INTO bookings (
    trip_id, 
    customer_id, 
    seat_number, 
    ticket_amount, 
    booking_status, 
    payment_reference
) VALUES (
    1, 
    101, 
    3, 
    28500.00, 
    'Confirmed', 
    'PAY-TXN-2026-001'
);

-- Step 4: Commit changes to persist permanently (Durability)
COMMIT;

-- Verify the booking exists
SELECT * FROM bookings WHERE payment_reference = 'PAY-TXN-2026-001';


-- ------------------------------------------------------------------------------
-- 1B: Failed Transaction with Clean Undo (ROLLBACK)
-- Simulates a situation where payment fails or ticket price is negative.
-- ------------------------------------------------------------------------------
BEGIN;

-- Step 1: Insert provisional booking
INSERT INTO bookings (
    trip_id, 
    customer_id, 
    seat_number, 
    ticket_amount, 
    booking_status, 
    payment_reference
) VALUES (
    1, 
    102, 
    4, 
    28500.00, 
    'Confirmed', 
    'PAY-TXN-2026-FAILED'
);

-- Step 2: External payment verification fails (Card declined or timeout).
-- We issue a ROLLBACK to revert all uncommitted changes.
ROLLBACK;

-- Verify Seat 4 was NOT reserved and remained free
SELECT * FROM bookings WHERE payment_reference = 'PAY-TXN-2026-FAILED';


-- ==============================================================================
-- SCENARIO 2 & 3: CONCURRENCY CONTROL & ROW LOCKING (SELECT FOR UPDATE)
-- Problem: Two customers (Customer A and Customer B) try to book Seat 5
--          on Trip 2 at the exact same second from two different ticket counters.
-- Solution: Use Pessimistic Row Locking (`SELECT ... FOR UPDATE`) to ensure
--           only one customer can hold the lock and complete payment.
-- ==============================================================================

-- Instructions for Testing:
-- Open TWO terminal windows connected to PostgreSQL:
-- Window 1: Session A (Terminal A)
-- Window 2: Session B (Terminal B)

--------------------------------------------------------------------------------
-- STEP-BY-STEP EXECUTION ORDER:
--------------------------------------------------------------------------------

-- [WINDOW 1 - SESSION A]: Customer A begins booking Seat 5
BEGIN;

-- Customer A checks if Seat 5 is booked and locks the trip row
SELECT trip_id, trip_status 
FROM trips 
WHERE trip_id = 2 
FOR UPDATE;

-- Customer A checks if Seat 5 is available
SELECT seat_number 
FROM bookings 
WHERE trip_id = 2 AND seat_number = 5;
-- (Result returns 0 rows: Seat 5 is free!)

-- [WINDOW 2 - SESSION B]: Customer B tries to book Seat 5 at the same time
BEGIN;

-- Customer B tries to lock the same trip row:
SELECT trip_id, trip_status 
FROM trips 
WHERE trip_id = 2 
FOR UPDATE;
-- >>> PAUSE: Session B hangs and waits! Session A holds the exclusive lock. <<<

-- [WINDOW 1 - SESSION A]: Customer A completes the payment and inserts booking
INSERT INTO bookings (
    trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference
) VALUES (
    2, 103, 5, 28500.00, 'Confirmed', 'PAY-TXN-SEAT5-WINNER'
);

-- Customer A commits the transaction
COMMIT;
-- >>> The lock is released! Session B immediately unblocks and resumes in Window 2. <<<

-- [WINDOW 2 - SESSION B]: Now unblocked, Customer B checks if Seat 5 is free:
SELECT seat_number, booking_status 
FROM bookings 
WHERE trip_id = 2 AND seat_number = 5;
-- >>> Result: Seat 5 is already Confirmed by Customer A! <<<

-- Customer B's application detects the seat is taken and cancels safely:
ROLLBACK;


-- ==============================================================================
-- SCENARIO 4: TRANSACTION ISOLATION LEVELS
-- Comparing READ COMMITTED (Default) vs REPEATABLE READ
-- In financial reporting, we need a consistent snapshot of total ticket revenue
-- while new bookings are actively being inserted by passengers.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 4A: READ COMMITTED (Default Behavior)
-- ------------------------------------------------------------------------------
-- In Read Committed, each statement sees newly committed rows from other sessions.
-- This can cause a "Non-Repeatable Read" inside the same report transaction.

-- [SESSION 1 - AUDITOR REPORT]:
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT SUM(ticket_amount) AS revenue_snapshot_1 FROM bookings WHERE trip_id = 1;
-- Output: e.g. ₦142,500.00

-- [SESSION 2 - NEW PASSENGER]:
BEGIN;
INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (1, 104, 6, 28500.00, 'Confirmed', 'PAY-NEW-001');
COMMIT;

-- [SESSION 1 - AUDITOR REPORT (Same Transaction)]:
SELECT SUM(ticket_amount) AS revenue_snapshot_2 FROM bookings WHERE trip_id = 1;
-- Output: ₦171,000.00 (The number changed inside the same transaction!)
COMMIT;

-- ------------------------------------------------------------------------------
-- 4B: REPEATABLE READ (Consistent Snapshot Isolation)
-- ------------------------------------------------------------------------------
-- In Repeatable Read, the transaction sees a frozen snapshot taken at the start.

-- [SESSION 1 - AUDITOR REPORT]:
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT SUM(ticket_amount) AS revenue_snapshot_1 FROM bookings WHERE trip_id = 1;
-- Output: e.g. ₦171,000.00

-- [SESSION 2 - ANOTHER PASSENGER]:
BEGIN;
INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (1, 105, 7, 28500.00, 'Confirmed', 'PAY-NEW-002');
COMMIT;

-- [SESSION 1 - AUDITOR REPORT (Same Transaction)]:
SELECT SUM(ticket_amount) AS revenue_snapshot_2 FROM bookings WHERE trip_id = 1;
-- Output: Still ₦171,000.00! The new booking is ignored, preserving report consistency.
COMMIT;


-- ==============================================================================
-- SCENARIO 5: DEADLOCK DEMONSTRATION AND AUTOMATIC RESOLUTION
-- Problem: Two transactions attempt to update two shared resources in opposite
--          order, causing an infinite circular wait.
-- PostgreSQL detects this condition and automatically aborts one transaction.
-- ==============================================================================

-- [WINDOW 1 - SESSION 1]:
BEGIN;
UPDATE vehicles SET status = 'In-Transit' WHERE vehicle_id = 1;
-- Vehicle 1 locked by Session 1.

-- [WINDOW 2 - SESSION 2]:
BEGIN;
UPDATE vehicles SET status = 'Under-Maintenance' WHERE vehicle_id = 2;
-- Vehicle 2 locked by Session 2.

-- [WINDOW 1 - SESSION 1]: Session 1 now tries to update Vehicle 2
UPDATE vehicles SET status = 'In-Transit' WHERE vehicle_id = 2;
-- >>> Session 1 waits on Session 2... <<<

-- [WINDOW 2 - SESSION 2]: Session 2 now tries to update Vehicle 1
UPDATE vehicles SET status = 'Under-Maintenance' WHERE vehicle_id = 1;
-- >>> CIRCULAR WAIT: Session 2 waits on Session 1, which waits on Session 2! <<<

-- Result after 1 second (deadlock_timeout):
-- PostgreSQL terminates Session 2 with:
-- ERROR: deadlock detected
-- DETAIL: Process 12345 waits for ShareLock on transaction 67890; blocked by process 67890.
-- Process 67890 waits for ExclusiveLock on tuple of relation "vehicles"; blocked by process 12345.
-- HINT: See server log for query details.

-- Session 2 rolls back:
ROLLBACK;

-- Session 1 can now safely finish:
COMMIT;

-- ==============================================================================
-- Best Practice Note to Prevent Deadlocks:
-- Always acquire resource locks in a consistent, alphabetical or numerical order
-- (e.g., always lock vehicle_id in ascending order: vehicle 1 before vehicle 2).
-- ==============================================================================
