# Builds a real primary and standby PostgreSQL server on this computer (ports 5440 and 5441,
# in a temporary folder, separate from the main database), tests streaming replication,
# crashes the primary, promotes the standby and saves the real output.
# Run from PowerShell:  .\portfolio-5-distributed-cloud\Ajeyomi_Adedoyin_20260520_Run_Replication_Failover_Test.ps1
# Add -KeepRunning to leave the promoted server running on the standby port so it can be opened in pgAdmin 4.

param(
    [string]$Bin = "C:\Program Files\PostgreSQL\17\bin",
    [string]$Root = (Join-Path $env:TEMP "aml_ha"),
    [int]$PrimaryPort = 5440,
    [int]$StandbyPort = 5441,
    [switch]$KeepRunning
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent $here
$results = Join-Path $here "Ajeyomi_Adedoyin_20260520_Replication_Failover_Test_Results.txt"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$line = "=" * 80
$env:PGCLIENTENCODING = "UTF8"
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

function Add-Result([string]$text) {
    [System.IO.File]::AppendAllText($results, $text + "`r`n", $utf8)
}

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

foreach ($p in @($StandbyPort, $PrimaryPort)) {
    $d = Join-Path $Root $(if ($p -eq $PrimaryPort) { "primary" } else { "standby" })
    if (Test-Path (Join-Path $d "postmaster.pid")) { & "$Bin\pg_ctl.exe" stop -D $d -m immediate 2>&1 | Out-Null }
}
if (Test-Path $Root) { Remove-Item $Root -Recurse -Force }
New-Item -ItemType Directory -Path $Root | Out-Null
[System.IO.File]::WriteAllText($results, "", $utf8)
Add-Result ($line + "`r`nPOSTGRESQL STREAMING REPLICATION AND FAILOVER TEST`r`nCase study: Adedoyin Mobility and Logistics`r`nRun on: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "`r`n" + $line + "`r`n")

$primary = Join-Path $Root "primary"
$standby = Join-Path $Root "standby"

Step "STEP 1: CREATE THE PRIMARY SERVER (port $PrimaryPort)" (Exec ('"{0}\initdb.exe" -D "{1}" -U postgres -A trust --encoding=UTF8' -f $Bin, $primary))
Add-Content -Path (Join-Path $primary "postgresql.conf") -Value "listen_addresses = 'localhost'`nwal_level = replica`nmax_wal_senders = 10`nwal_keep_size = 128MB"
Step "STEP 2: START THE PRIMARY" (Exec ('"{0}\pg_ctl.exe" -D "{1}" -o "-p {2}" -l "{3}" -w start' -f $Bin, $primary, $PrimaryPort, (Join-Path $Root "primary.log")))
Step "STEP 3: LOAD THE REAL DATA INTO THE PRIMARY" ((Exec ('"{0}\psql.exe" -X -h localhost -p {1} -U postgres -c "CREATE DATABASE aml;"' -f $Bin, $PrimaryPort)) + "`r`n" +
    (Exec ('cd /d "{0}" && "{1}\psql.exe" -X -q -h localhost -p {2} -U postgres -d aml -f "portfolio-1-database-design\Ajeyomi_Adedoyin_20260520_Schema.sql"' -f $repo, $Bin, $PrimaryPort) -replace "(?m)^.*NOTICE.*\r?\n?", "") + "`r`n" +
    (Exec ('cd /d "{0}" && "{1}\psql.exe" -X -h localhost -p {2} -U postgres -d aml -f "portfolio-1-database-design\Ajeyomi_Adedoyin_20260520_Copy_From_CSV.sql"' -f $repo, $Bin, $PrimaryPort) -replace "(?s)\s+setval.*$", ""))

Step "STEP 4: TAKE A BASE BACKUP FOR THE STANDBY" (Exec ('"{0}\pg_basebackup.exe" -D "{1}" -R -X stream -P -d "host=localhost port={2} user=postgres application_name=aml_standby"' -f $Bin, $standby, $PrimaryPort))
Step "STEP 5: START THE STANDBY (port $StandbyPort)" (Exec ('"{0}\pg_ctl.exe" -D "{1}" -o "-p {2}" -l "{3}" -w start' -f $Bin, $standby, $StandbyPort, (Join-Path $Root "standby.log")))

Step "STEP 6: TURN ON SYNCHRONOUS REPLICATION AND CHECK THE LINK (run on the primary)" (Psql $PrimaryPort "aml" @"
ALTER SYSTEM SET synchronous_standby_names = 'aml_standby';
SELECT pg_reload_conf();
SELECT pg_sleep(1);
SHOW synchronous_standby_names;
SELECT application_name, state, sync_state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;
"@)

Step "STEP 7: WRITE ON THE PRIMARY, READ ON THE STANDBY" ((Psql $PrimaryPort "aml" @"
CREATE TABLE failover_test (id serial PRIMARY KEY, note text, written_at timestamptz DEFAULT now());
INSERT INTO failover_test (note) SELECT 'before failover ' || g FROM generate_series(1, 1000) g;
SELECT 'primary' AS node, pg_is_in_recovery() AS in_recovery, (SELECT COUNT(*) FROM bookings) AS bookings, (SELECT COUNT(*) FROM failover_test) AS failover_rows;
"@) + "`r`n`r`n" + (Psql $StandbyPort "aml" @"
SELECT 'standby' AS node, pg_is_in_recovery() AS in_recovery, (SELECT COUNT(*) FROM bookings) AS bookings, (SELECT COUNT(*) FROM failover_test) AS failover_rows;
"@))

Step "STEP 8: THE STANDBY IS READ-ONLY" (Psql $StandbyPort "aml" "INSERT INTO failover_test (note) VALUES ('write on the standby');")

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$crash = Exec ('"{0}\pg_ctl.exe" -D "{1}" -m immediate -w stop' -f $Bin, $primary)
$tCrash = $sw.ElapsedMilliseconds
Step "STEP 9: CRASH THE PRIMARY (immediate stop, no clean shutdown)" ($crash + "`r`nPrimary stopped after $tCrash ms")

$promote = Exec ('"{0}\pg_ctl.exe" -D "{1}" -w promote' -f $Bin, $standby)
$tPromote = $sw.ElapsedMilliseconds
$write = Psql $StandbyPort "aml" @"
SELECT pg_is_in_recovery() AS still_standby;
INSERT INTO failover_test (note) VALUES ('first write after failover');
SELECT COUNT(*) AS rows_after_failover FROM failover_test;
"@
$tWrite = $sw.ElapsedMilliseconds
Step "STEP 10: PROMOTE THE STANDBY TO PRIMARY AND WRITE TO IT" ($promote + "`r`n`r`n" + $write + "`r`n`r`nTimeline since the primary crashed:`r`n  standby promoted and ready: " + ($tPromote - $tCrash) + " ms`r`n  first successful write on the new primary: " + ($tWrite - $tCrash) + " ms")

Step "STEP 11: THE OLD PRIMARY IS DOWN, THE NEW PRIMARY HAS ALL 1,000 ROWS PLUS THE NEW ONE" (Psql $StandbyPort "aml" @"
SELECT COUNT(*) FILTER (WHERE note LIKE 'before failover%') AS rows_written_before_crash, COUNT(*) FILTER (WHERE note LIKE 'first write%') AS rows_written_after_failover FROM failover_test;
SELECT COUNT(*) AS bookings FROM bookings;
"@)

if (-not $KeepRunning) { Exec ('"{0}\pg_ctl.exe" -D "{1}" -m fast stop' -f $Bin, $standby) | Out-Null }
else { Write-Host "The promoted server is still running on port $StandbyPort (user postgres, no password)." }
Write-Host "Finished. Results written to: $results"
