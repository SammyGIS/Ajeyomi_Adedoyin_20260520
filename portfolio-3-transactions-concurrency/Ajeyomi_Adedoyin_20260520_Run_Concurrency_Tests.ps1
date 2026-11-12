# Runs the transaction and concurrency tests and saves the real psql output to Ajeyomi_Adedoyin_20260520_Concurrency_Test_Results.txt.
# First set the password:  $env:PGPASSWORD = "your_password"

param(
    [string]$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe",
    [string]$Db   = "adedoyin_mobility",
    [string]$User = "postgres",
    [int]$Port    = 5433
)

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$results = Join-Path $here "Ajeyomi_Adedoyin_20260520_Concurrency_Test_Results.txt"
$work    = Join-Path $env:TEMP "aml_concurrency_tests"
$line    = "=" * 80
$thin    = "-" * 80
$utf8    = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $Psql)) { throw "psql.exe not found at $Psql" }
if (-not $env:PGPASSWORD) { throw 'Set the password first:  $env:PGPASSWORD = "your_postgres_password"' }

New-Item -ItemType Directory -Force -Path $work | Out-Null
$env:PGCLIENTENCODING = "UTF8"
[System.IO.File]::WriteAllText($results, "", $utf8)

function Mark([string]$who, [string]$text) {
    "SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS clock, '$who : $text' AS step;"
}

function Start-Session([string]$name, [string]$sql) {
    $safe = $name -replace '\W', '_'
    $file = Join-Path $work "$safe.sql"
    $out  = Join-Path $work "$safe.txt"
    [System.IO.File]::WriteAllText($file, $sql, $utf8)
    if (Test-Path $out) { Remove-Item $out }
    $cmd = '"{0}" -X -a -h localhost -p {1} -U {2} -d {3} -f "{4}" > "{5}" 2>&1' -f $Psql, $Port, $User, $Db, $file, $out
    $p = Start-Process -FilePath "cmd.exe" -ArgumentList ('/c "' + $cmd + '"') -WindowStyle Hidden -PassThru
    [pscustomobject]@{ Process = $p; Out = $out }
}

function Read-Session($s) {
    $s.Process.WaitForExit()
    if (Test-Path $s.Out) { ([System.IO.File]::ReadAllText($s.Out, [System.Text.Encoding]::UTF8)).TrimEnd() } else { "(no output)" }
}

function Add-Result([string]$text) {
    [System.IO.File]::AppendAllText($results, $text + "`r`n", $utf8)
}

function Run-Single([string]$title, [string]$sql) {
    Write-Host "Running: $title"
    $s = Start-Session $title $sql
    Add-Result ($line + "`r`n" + $title + "`r`n" + $line)
    Add-Result (Read-Session $s)
    Add-Result ""
}

function Run-Pair([string]$title, [string]$note, [string]$sqlA, [string]$sqlB, [double]$delayB) {
    Write-Host "Running: $title"
    $a = Start-Session "A_$title" $sqlA
    Start-Sleep -Milliseconds ([int]($delayB * 1000))
    $b = Start-Session "B_$title" $sqlB
    $outA = Read-Session $a
    $outB = Read-Session $b
    Add-Result ($line + "`r`n" + $title + "`r`n" + $note + "`r`n" + $line)
    Add-Result ($thin + "`r`nSESSION A`r`n" + $thin)
    Add-Result $outA
    Add-Result ("`r`n" + $thin + "`r`nSESSION B`r`n" + $thin)
    Add-Result $outB
    Add-Result ""
}

Add-Result ($line + "`r`nPOSTGRESQL TRANSACTIONS AND CONCURRENCY TEST RESULTS`r`nCase study: Adedoyin Mobility and Logistics`r`nRun on: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "`r`n" + $line + "`r`n")

Run-Single "ENVIRONMENT" @"
SELECT version();
SHOW deadlock_timeout;
SHOW default_transaction_isolation;
SELECT COUNT(*) AS bookings_before_tests FROM bookings;
"@

$transactionsFile = Join-Path $here "Ajeyomi_Adedoyin_20260520_Transactions.sql"
Run-Single "SCENARIO 1: ACID TRANSACTIONS (COMMIT, ROLLBACK, FAILED STATEMENT)" ([System.IO.File]::ReadAllText($transactionsFile))

$a = @"
BEGIN;
$(Mark 'A' 'checking whether seat 5 on trip 9003 is free')
SELECT seat_number FROM bookings WHERE trip_id = 9003 AND seat_number = 5;
SELECT pg_sleep(4) AS customer_A_is_entering_payment_details;
$(Mark 'A' 'inserting seat 5')
INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9003, 201, 5, 18500.00, 'Confirmed', 'RACE-A');
COMMIT;
$(Mark 'A' 'committed')
"@
$b = @"
\timing on
BEGIN;
$(Mark 'B' 'checking whether seat 5 on trip 9003 is free')
SELECT seat_number FROM bookings WHERE trip_id = 9003 AND seat_number = 5;
$(Mark 'B' 'seat looks free, inserting seat 5')
INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9003, 202, 5, 18500.00, 'Confirmed', 'RACE-B');
ROLLBACK;
\timing off
SELECT trip_id, seat_number, customer_id, payment_reference FROM bookings WHERE trip_id = 9003 ORDER BY seat_number;
"@
Run-Pair "SCENARIO 2: DOUBLE-BOOKING RACE WITHOUT A ROW LOCK" "Both customers see seat 5 as free. Only the UNIQUE (trip_id, seat_number) rule stops the second insert." $a $b 1.5

$a = @"
BEGIN;
$(Mark 'A' 'requesting the lock on trip 9002')
SELECT trip_id, trip_status FROM trips WHERE trip_id = 9002 FOR UPDATE;
$(Mark 'A' 'lock acquired, checking seat 5')
SELECT seat_number FROM bookings WHERE trip_id = 9002 AND seat_number = 5;
SELECT pg_sleep(4) AS customer_A_is_entering_payment_details;
INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9002, 203, 5, 18500.00, 'Confirmed', 'LOCK-A');
COMMIT;
$(Mark 'A' 'committed, lock released')
"@
$b = @"
\timing on
BEGIN;
$(Mark 'B' 'requesting the lock on trip 9002')
SELECT trip_id, trip_status FROM trips WHERE trip_id = 9002 FOR UPDATE;
$(Mark 'B' 'lock acquired after waiting, checking seat 5')
SELECT seat_number, booking_status, customer_id FROM bookings WHERE trip_id = 9002 AND seat_number = 5;
ROLLBACK;
\timing off
$(Mark 'B' 'rolled back, customer is told the seat is taken')
"@
Run-Pair "SCENARIO 3: SEAT BOOKING WITH A ROW LOCK (SELECT FOR UPDATE)" "Session B has to wait for session A, then sees the seat is already taken and stops cleanly." $a $b 1.5

Run-Single "SCENARIO 4 SETUP: TWO EXISTING BOOKINGS ON TRIP 9004" @"
INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference) VALUES
  (9004, 301, 1, 18500.00, 'Confirmed', 'ISO-BASE-1'),
  (9004, 302, 2, 18500.00, 'Confirmed', 'ISO-BASE-2');
"@

$a = @"
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT 'first read' AS step, COUNT(*) AS tickets, SUM(ticket_amount) AS revenue FROM bookings WHERE trip_id = 9004;
SELECT pg_sleep(4) AS auditor_is_working;
SELECT 'second read, same transaction' AS step, COUNT(*) AS tickets, SUM(ticket_amount) AS revenue FROM bookings WHERE trip_id = 9004;
COMMIT;
"@
$b = @"
$(Mark 'B' 'new passenger books seat 3 and commits')
INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9004, 303, 3, 18500.00, 'Confirmed', 'ISO-RC-NEW');
"@
Run-Pair "SCENARIO 4A: READ COMMITTED (DEFAULT)" "The auditor's second read inside the same transaction sees the booking committed by session B." $a $b 1.5

$a = @"
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT 'first read' AS step, COUNT(*) AS tickets, SUM(ticket_amount) AS revenue FROM bookings WHERE trip_id = 9004;
SELECT pg_sleep(4) AS auditor_is_working;
SELECT 'second read, same transaction' AS step, COUNT(*) AS tickets, SUM(ticket_amount) AS revenue FROM bookings WHERE trip_id = 9004;
COMMIT;
SELECT 'after commit' AS step, COUNT(*) AS tickets, SUM(ticket_amount) AS revenue FROM bookings WHERE trip_id = 9004;
"@
$b = @"
$(Mark 'B' 'new passenger books seat 4 and commits')
INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
VALUES (9004, 304, 4, 18500.00, 'Confirmed', 'ISO-RR-NEW');
"@
Run-Pair "SCENARIO 4B: REPEATABLE READ" "The auditor keeps the same snapshot for the whole transaction and only sees the new booking after committing." $a $b 1.5

$a = @"
\timing on
BEGIN;
$(Mark 'A' 'locking vehicle 1')
UPDATE vehicles SET status = 'In-Transit' WHERE vehicle_id = 1;
SELECT pg_sleep(2) AS A_pause;
$(Mark 'A' 'now requesting vehicle 2')
UPDATE vehicles SET status = 'In-Transit' WHERE vehicle_id = 2;
ROLLBACK;
\timing off
"@
$b = @"
\timing on
BEGIN;
$(Mark 'B' 'locking vehicle 2')
UPDATE vehicles SET status = 'Under-Maintenance' WHERE vehicle_id = 2;
SELECT pg_sleep(2) AS B_pause;
$(Mark 'B' 'now requesting vehicle 1')
UPDATE vehicles SET status = 'Under-Maintenance' WHERE vehicle_id = 1;
ROLLBACK;
\timing off
"@
Run-Pair "SCENARIO 5A: DEADLOCK (LOCKS TAKEN IN OPPOSITE ORDER)" "Session A locks vehicle 1 then 2. Session B locks vehicle 2 then 1. PostgreSQL must abort one of them." $a $b 1

$a = @"
\timing on
BEGIN;
$(Mark 'A' 'locking vehicle 1')
UPDATE vehicles SET status = 'In-Transit' WHERE vehicle_id = 1;
SELECT pg_sleep(3) AS A_pause;
$(Mark 'A' 'locking vehicle 2')
UPDATE vehicles SET status = 'In-Transit' WHERE vehicle_id = 2;
ROLLBACK;
\timing off
"@
$b = @"
\timing on
BEGIN;
$(Mark 'B' 'requesting vehicle 1')
UPDATE vehicles SET status = 'Under-Maintenance' WHERE vehicle_id = 1;
$(Mark 'B' 'got vehicle 1 after waiting, locking vehicle 2')
UPDATE vehicles SET status = 'Under-Maintenance' WHERE vehicle_id = 2;
ROLLBACK;
\timing off
"@
Run-Pair "SCENARIO 5B: DEADLOCK PREVENTED (SAME LOCK ORDER)" "Both sessions lock vehicle 1 first and vehicle 2 second, so B simply waits and no deadlock occurs." $a $b 1

Run-Single "CLEAN UP DEMO DATA" @"
DELETE FROM trips WHERE trip_id BETWEEN 9001 AND 9004;
SELECT COUNT(*) AS demo_trips_left FROM trips WHERE trip_id >= 9001;
SELECT COUNT(*) AS bookings_after_tests FROM bookings;
SELECT vehicle_id, status FROM vehicles WHERE vehicle_id IN (1, 2) ORDER BY vehicle_id;
"@

Write-Host ""
Write-Host "Finished. Results written to: $results"
