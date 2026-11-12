# Tests partition pruning and sharding across two real PostgreSQL servers on this computer
# (ports 5442 and 5443, in a temporary folder, separate from the main database) and saves the real output.
# Run from PowerShell:  .\portfolio-5-distributed-cloud\Ajeyomi_Adedoyin_20260520_Run_Sharding_Test.ps1

param(
    [string]$Bin = "C:\Program Files\PostgreSQL\17\bin",
    [string]$Root = (Join-Path $env:TEMP "aml_shard"),
    [int]$MainPort = 5442,
    [int]$NorthPort = 5443
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent $here
$results = Join-Path $here "Ajeyomi_Adedoyin_20260520_Sharding_Test_Results.txt"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$line = "=" * 80
$env:PGCLIENTENCODING = "UTF8"
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

function Add-Result([string]$text) { [System.IO.File]::AppendAllText($results, $text + "`r`n", $utf8) }

function Exec([string]$cmd) {
    $out = Join-Path $Root ("out_" + [guid]::NewGuid().ToString("N") + ".txt")
    $p = Start-Process -FilePath "cmd.exe" -ArgumentList ('/c "' + $cmd + ' > "' + $out + '" 2>&1"') -WindowStyle Hidden -PassThru
    $p.WaitForExit()
    if (Test-Path $out) {
        $fs = [System.IO.File]::Open($out, "Open", "Read", "ReadWrite")
        $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
        $t = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
        return $t.TrimEnd()
    }
    return ""
}

function Psql([int]$port, [string]$db, [string]$sql) {
    $file = Join-Path $Root ("q_" + [guid]::NewGuid().ToString("N") + ".sql")
    [System.IO.File]::WriteAllText($file, $sql, $utf8)
    return Exec ('"{0}\psql.exe" -X -a -h localhost -p {1} -U postgres -d {2} -f "{3}"' -f $Bin, $port, $db, $file)
}

function Step([string]$title, [string]$body) {
    Write-Host $title
    Add-Result ($line + "`r`n" + $title + "`r`n" + $line)
    Add-Result $body
    Add-Result ""
}

foreach ($d in @("main", "north")) {
    $dir = Join-Path $Root $d
    if (Test-Path (Join-Path $dir "postmaster.pid")) { & "$Bin\pg_ctl.exe" stop -D $dir -m immediate 2>&1 | Out-Null }
}
if (Test-Path $Root) { Remove-Item $Root -Recurse -Force }
New-Item -ItemType Directory -Path $Root | Out-Null
[System.IO.File]::WriteAllText($results, "", $utf8)
Add-Result ($line + "`r`nPARTITION PRUNING AND SHARDING ACROSS TWO SERVERS`r`nCase study: Adedoyin Mobility and Logistics`r`nRun on: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "`r`n" + $line + "`r`n")

$main = Join-Path $Root "main"
$north = Join-Path $Root "north"
Step "STEP 1: CREATE AND START TWO SERVERS (main on $MainPort, north shard on $NorthPort)" (
    (Exec ('"{0}\initdb.exe" -D "{1}" -U postgres -A trust --encoding=UTF8' -f $Bin, $main) | Select-Object -Last 1) + "`r`n" +
    (Exec ('"{0}\initdb.exe" -D "{1}" -U postgres -A trust --encoding=UTF8' -f $Bin, $north) | Select-Object -Last 1) + "`r`n" +
    (Exec ('"{0}\pg_ctl.exe" -D "{1}" -o "-p {2}" -l "{3}" -w start' -f $Bin, $main, $MainPort, (Join-Path $Root "main.log"))) + "`r`n" +
    (Exec ('"{0}\pg_ctl.exe" -D "{1}" -o "-p {2}" -l "{3}" -w start' -f $Bin, $north, $NorthPort, (Join-Path $Root "north.log"))))

Step "STEP 2: LOAD THE REAL DATA AND SCALE IT UP (60,000 trips, 400,000 bookings, 175,000 parcels)" (
    (Exec ('"{0}\psql.exe" -X -h localhost -p {1} -U postgres -c "CREATE DATABASE aml;"' -f $Bin, $MainPort)) + "`r`n" +
    ((Exec ('cd /d "{0}" && "{1}\psql.exe" -X -q -h localhost -p {2} -U postgres -d aml -f "portfolio-1-database-design\Ajeyomi_Adedoyin_20260520_Schema.sql"' -f $repo, $Bin, $MainPort)) -replace "(?m)^.*NOTICE.*\r?\n?", "") + "`r`n" +
    ((Exec ('cd /d "{0}" && "{1}\psql.exe" -X -h localhost -p {2} -U postgres -d aml -f "portfolio-1-database-design\Ajeyomi_Adedoyin_20260520_Copy_From_CSV.sql"' -f $repo, $Bin, $MainPort)) -replace "(?s)\s+setval.*$", "") + "`r`n" +
    (Exec ('cd /d "{0}" && "{1}\psql.exe" -X -h localhost -p {2} -U postgres -d aml -f "portfolio-2-query-optimisation\Ajeyomi_Adedoyin_20260520_Benchmark_Scale_Up.sql"' -f $repo, $Bin, $MainPort) | Select-Object -Last 8))

Step "STEP 3: BUILD A NORMAL TABLE AND A TABLE PARTITIONED BY REGION" (Psql $MainPort "aml" @"
CREATE TABLE trips_flat AS
SELECT t.trip_id, t.route_id, t.vehicle_id, t.driver_id,
       CASE s.state WHEN 'Lagos' THEN 'South-West' WHEN 'Oyo' THEN 'South-West'
                    WHEN 'FCT' THEN 'North-Central' WHEN 'Kano' THEN 'North-West'
                    ELSE 'South-East-South' END::varchar(30) AS origin_region,
       t.departure_datetime, t.arrival_datetime, t.trip_status
FROM trips t
JOIN routes r ON r.route_id = t.route_id
JOIN stations s ON s.station_id = r.origin_station_id;
ALTER TABLE trips_flat ADD PRIMARY KEY (trip_id);
CREATE INDEX idx_flat_departure ON trips_flat (departure_datetime);

CREATE TABLE trips_part (LIKE trips_flat INCLUDING DEFAULTS) PARTITION BY LIST (origin_region);
CREATE TABLE trips_part_southwest PARTITION OF trips_part FOR VALUES IN ('South-West');
CREATE TABLE trips_part_northcentral PARTITION OF trips_part FOR VALUES IN ('North-Central');
CREATE TABLE trips_part_northwest PARTITION OF trips_part FOR VALUES IN ('North-West');
CREATE TABLE trips_part_southeast PARTITION OF trips_part FOR VALUES IN ('South-East-South');
INSERT INTO trips_part SELECT * FROM trips_flat;
ALTER TABLE trips_part ADD PRIMARY KEY (trip_id, origin_region);
CREATE INDEX idx_part_departure ON trips_part (departure_datetime);
ANALYZE trips_flat;
ANALYZE trips_part;
SELECT origin_region, COUNT(*) AS trips FROM trips_flat GROUP BY origin_region ORDER BY origin_region;
SELECT tableoid::regclass AS partition, COUNT(*) AS trips FROM trips_part GROUP BY 1 ORDER BY 1;
"@)

Step "STEP 4: THE SAME QUERY ON THE NORMAL TABLE (reads the whole table)" (Psql $MainPort "aml" @"
SET max_parallel_workers_per_gather = 0;
SELECT COUNT(*) AS warm_up FROM trips_flat WHERE origin_region = 'North-West' AND trip_status = 'Completed';
EXPLAIN (ANALYZE, BUFFERS)
SELECT trip_id, departure_datetime, trip_status FROM trips_flat
WHERE origin_region = 'North-West' AND trip_status = 'Completed';
"@)

Step "STEP 5: THE SAME QUERY ON THE PARTITIONED TABLE (reads one partition)" (Psql $MainPort "aml" @"
SET max_parallel_workers_per_gather = 0;
SELECT COUNT(*) AS warm_up FROM trips_part WHERE origin_region = 'North-West' AND trip_status = 'Completed';
EXPLAIN (ANALYZE, BUFFERS)
SELECT trip_id, departure_datetime, trip_status FROM trips_part
WHERE origin_region = 'North-West' AND trip_status = 'Completed';
"@)

Step "STEP 6: A QUERY WITHOUT THE REGION CANNOT BE PRUNED (reads every partition)" (Psql $MainPort "aml" @"
SET max_parallel_workers_per_gather = 0;
EXPLAIN (ANALYZE, BUFFERS)
SELECT trip_id, departure_datetime, trip_status FROM trips_part
WHERE trip_status = 'Cancelled';
"@)

Step "STEP 7: CREATE THE NORTH SHARD ON THE SECOND SERVER AND COPY THE NORTH TRIPS TO IT" (
    (Exec ('"{0}\psql.exe" -X -h localhost -p {1} -U postgres -c "CREATE DATABASE shard_north;"' -f $Bin, $NorthPort)) + "`r`n" +
    (Psql $NorthPort "shard_north" @"
CREATE TABLE trips_north (
    trip_id int, route_id int, vehicle_id int, driver_id int, origin_region varchar(30),
    departure_datetime timestamptz, arrival_datetime timestamptz, trip_status varchar(30),
    PRIMARY KEY (trip_id, origin_region));
"@) + "`r`n" +
    (Exec ('"{0}\psql.exe" -X -h localhost -p {1} -U postgres -d aml -c "COPY (SELECT * FROM trips_flat WHERE origin_region IN (''North-Central'', ''North-West'')) TO STDOUT" | "{0}\psql.exe" -X -h localhost -p {2} -U postgres -d shard_north -c "COPY trips_north FROM STDIN"' -f $Bin, $MainPort, $NorthPort)) + "`r`n" +
    (Psql $NorthPort "shard_north" "SELECT origin_region, COUNT(*) AS trips_on_north_server FROM trips_north GROUP BY origin_region ORDER BY origin_region;"))

Step "STEP 8: JOIN THE TWO SERVERS WITH postgres_fdw (south trips stay local, north trips live on the other server)" (Psql $MainPort "aml" @"
CREATE EXTENSION postgres_fdw;
CREATE SERVER north_node FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'localhost', port '$NorthPort', dbname 'shard_north');
CREATE USER MAPPING FOR postgres SERVER north_node OPTIONS (user 'postgres');
CREATE TABLE trips_sharded (LIKE trips_flat INCLUDING DEFAULTS) PARTITION BY LIST (origin_region);
CREATE TABLE trips_sharded_south PARTITION OF trips_sharded FOR VALUES IN ('South-West', 'South-East-South');
CREATE FOREIGN TABLE trips_sharded_north PARTITION OF trips_sharded FOR VALUES IN ('North-Central', 'North-West')
    SERVER north_node OPTIONS (table_name 'trips_north');
INSERT INTO trips_sharded_south SELECT * FROM trips_flat WHERE origin_region IN ('South-West', 'South-East-South');
ANALYZE trips_sharded_south;
SELECT origin_region, COUNT(*) AS trips FROM trips_sharded GROUP BY origin_region ORDER BY origin_region;
"@)

Step "STEP 9: A NORTH QUERY GOES TO THE OTHER SERVER, A SOUTH QUERY STAYS LOCAL" (Psql $MainPort "aml" @"
EXPLAIN (VERBOSE, COSTS OFF)
SELECT trip_id, trip_status FROM trips_sharded WHERE origin_region = 'North-West' AND trip_id < 100;
EXPLAIN (VERBOSE, COSTS OFF)
SELECT trip_id, trip_status FROM trips_sharded WHERE origin_region = 'South-West' AND trip_id < 100;
SELECT trip_id, origin_region, trip_status FROM trips_sharded WHERE origin_region = 'North-West' ORDER BY trip_id LIMIT 3;
"@)

foreach ($d in @($north, $main)) { Exec ('"{0}\pg_ctl.exe" -D "{1}" -m fast stop' -f $Bin, $d) | Out-Null }
Write-Host "Finished. Results written to: $results"
