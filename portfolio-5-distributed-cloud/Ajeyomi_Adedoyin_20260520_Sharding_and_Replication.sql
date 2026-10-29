-- ============================================================================
-- MIVA OPEN UNIVERSITY - MIT 8103: ADVANCED DATABASE SYSTEMS
-- PORTFOLIO 5: DISTRIBUTED AND CLOUD DATABASES
-- ============================================================================
-- Student Name: Adedoyin Ajeyomi
-- Student ID:   20260520
-- Programme:    Master of Information Technology (MIT)
-- Case Study:   Adedoyin Mobility and Logistics
-- File:         Ajeyomi_Adedoyin_20260520_Sharding_and_Replication.sql
-- Database:     adedoyin_mobility_distributed
-- Engine:       PostgreSQL 14+ / postgres_fdw / Patroni HA
-- Description:  Enterprise distributed database scripts covering:
--               1. Declarative Table Partitioning by Geographic Corridor
--               2. Multi-Node Distributed Sharding via postgres_fdw
--               3. Primary-Replica Streaming Replication Configuration
--               4. High-Availability Automatic Failover & Quorum Setup
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PART 1: DECLARATIVE HORIZONTAL PARTITIONING (CORRIDOR-BASED SHARDING)
-- ----------------------------------------------------------------------------
-- Adedoyin Mobility operates across distinct Nigerian geopolitical transport zones.
-- To prevent massive sequential scans on the central trips table (millions of rows),
-- we implement declarative LIST partitioning based on the regional origin hub.

-- Clean up existing structures if rerunning
DROP TABLE IF EXISTS bookings_partitioned CASCADE;
DROP TABLE IF EXISTS trips_partitioned CASCADE;

-- Master Partitioned Trips Table
CREATE TABLE trips_partitioned (
    trip_id BIGSERIAL,
    route_id INT NOT NULL,
    vehicle_id INT NOT NULL,
    driver_id INT NOT NULL,
    origin_region VARCHAR(30) NOT NULL, -- Sharding Key
    departure_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    arrival_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    seat_capacity INT NOT NULL CHECK (seat_capacity BETWEEN 7 AND 18),
    trip_status VARCHAR(20) NOT NULL DEFAULT 'Scheduled',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_trips_partitioned PRIMARY KEY (trip_id, origin_region),
    CONSTRAINT chk_trip_status_part CHECK (trip_status IN ('Scheduled', 'Boarding', 'In-Transit', 'Completed', 'Cancelled'))
) PARTITION BY LIST (origin_region);

-- Regional Partition 1: South-West Zone (Lagos Ojota, Ibadan Iwo Road)
CREATE TABLE trips_southwest PARTITION OF trips_partitioned
    FOR VALUES IN ('South-West');

-- Regional Partition 2: North-Central Zone (Abuja Utako Terminal)
CREATE TABLE trips_northcentral PARTITION OF trips_partitioned
    FOR VALUES IN ('North-Central');

-- Regional Partition 3: North-West Zone (Kano Sabon Gari Terminal)
CREATE TABLE trips_northwest PARTITION OF trips_partitioned
    FOR VALUES IN ('North-West');

-- Regional Partition 4: South-East & South-South (Enugu Holy Ghost, Benin Ramat Park)
CREATE TABLE trips_eastsouth PARTITION OF trips_partitioned
    FOR VALUES IN ('South-East', 'South-South');

-- Default Partition for Unmapped or Trans-Saharan Corridors
CREATE TABLE trips_default PARTITION OF trips_partitioned
    DEFAULT;

-- Create Indexes on Individual Partitions
CREATE INDEX idx_trips_sw_departure ON trips_southwest (departure_datetime, trip_status);
CREATE INDEX idx_trips_nc_departure ON trips_northcentral (departure_datetime, trip_status);
CREATE INDEX idx_trips_nw_departure ON trips_northwest (departure_datetime, trip_status);
CREATE INDEX idx_trips_es_departure ON trips_eastsouth (departure_datetime, trip_status);

-- ----------------------------------------------------------------------------
-- PART 2: MULTI-NODE DISTRIBUTED SHARDING VIA POSTGRES_FDW
-- ----------------------------------------------------------------------------
-- When traffic exceeds single-server capacity, individual regional partitions 
-- are physically hosted on independent database servers (Shards) across Nigeria.
-- The Coordinator Node connects to remote worker shards using postgres_fdw.

-- Step 2.1: Enable Foreign Data Wrapper extension on Coordinator Node
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Step 2.2: Define Remote Foreign Server Nodes
-- Worker Node 1: Lagos Data Centre (Serving South-West Shard)
CREATE SERVER shard_southwest_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '10.0.1.10', port '5432', dbname 'aml_shard_southwest');

-- Worker Node 2: Abuja Cloud Node (Serving North-Central Shard)
CREATE SERVER shard_northcentral_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '10.0.2.10', port '5432', dbname 'aml_shard_northcentral');

-- Step 2.3: Create User Mappings for Distributed Authentication
CREATE USER MAPPING FOR postgres
    SERVER shard_southwest_server
    OPTIONS (user 'aml_shard_user', password 'SecureShardPass2026!');

CREATE USER MAPPING FOR postgres
    SERVER shard_northcentral_server
    OPTIONS (user 'aml_shard_user', password 'SecureShardPass2026!');

-- Step 2.4: Attach Remote Foreign Tables as Partition Shards
-- (Demonstrated on distributed coordinator)
/*
CREATE FOREIGN TABLE trips_southwest_remote PARTITION OF trips_partitioned
    FOR VALUES IN ('South-West')
    SERVER shard_southwest_server
    OPTIONS (schema_name 'public', table_name 'trips_southwest');

CREATE FOREIGN TABLE trips_northcentral_remote PARTITION OF trips_partitioned
    FOR VALUES IN ('North-Central')
    SERVER shard_northcentral_server
    OPTIONS (schema_name 'public', table_name 'trips_northcentral');
*/

-- ----------------------------------------------------------------------------
-- PART 3: PRIMARY-REPLICA PHYSICAL STREAMING REPLICATION CONFIGURATION
-- ----------------------------------------------------------------------------
-- For high availability and read-scalability, Adedoyin Mobility uses
-- PostgreSQL Physical Streaming Replication (WAL Shipping) with a Primary node
-- in Lagos and Read-Only Standby Replicas in Abuja and Kano.

-- [Configuration Directives for Primary Node: postgresql.conf]
/*
# --- Primary Node Configuration (Lagos Data Centre) ---
listen_addresses = '*'
port = 5432
wal_level = replica                     # Enables streaming replication WAL logs
max_wal_senders = 10                    # Maximum concurrent replication connections
wal_keep_size = 2048MB                  # Retain WAL logs in case standby temporarily disconnects
hot_standby = on                        # Allows read-only queries during recovery
synchronous_commit = remote_write       # Balance between zero data loss and low latency
synchronous_standby_names = 'FIRST 1 (aml_standby_abuja, aml_standby_kano)'
archive_mode = on
archive_command = 'test ! -f /mnt/nfs_wal_archive/%f && cp %p /mnt/nfs_wal_archive/%f'
*/

-- [Security Configuration for Primary Node: pg_hba.conf]
/*
# Allow replication user to connect securely from standby subnets
host    replication     aml_replicator  10.0.2.10/32    scram-sha-256   # Abuja Standby Node
host    replication     aml_replicator  10.0.3.10/32    scram-sha-256   # Kano Standby Node
host    all             all             10.0.0.0/16     scram-sha-256   # Corporate Subnet
*/

-- Step 3.1: Create Dedicated Replication User on Primary Node
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'aml_replicator') THEN
        CREATE ROLE aml_replicator WITH REPLICATION LOGIN ENCRYPTED PASSWORD 'StrongReplicationKey2026#';
    END IF;
END $$;

-- Step 3.2: Create Dedicated Physical Replication Slots on Primary
SELECT pg_create_physical_replication_slot('slot_standby_abuja');
SELECT pg_create_physical_replication_slot('slot_standby_kano');

-- Step 3.3: Baseline Backup Command executed from Standby Node (Terminal)
-- pg_basebackup -h 10.0.1.10 -p 5432 -U aml_replicator -D /var/lib/postgresql/14/main -Fp -Xs -P -R -S slot_standby_abuja

-- [Configuration Directives for Standby Node: postgresql.auto.conf (Generated by pg_basebackup)]
/*
# --- Standby Node Configuration (Abuja Cloud Node) ---
primary_conninfo = 'host=10.0.1.10 port=5432 user=aml_replicator password=StrongReplicationKey2026# application_name=aml_standby_abuja'
primary_slot_name = 'slot_standby_abuja'
hot_standby = on
hot_standby_feedback = on               # Prevents query cancellation on standby due to VACUUM
*/

-- ----------------------------------------------------------------------------
-- PART 4: REPLICATION MONITORING & HEALTH AUDIT QUERIES
-- ----------------------------------------------------------------------------

-- Audit 4.1: View Active Replication Connections and Lag on Primary
SELECT 
    client_addr AS replica_ip,
    application_name,
    state,
    sync_state,
    sync_priority,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    ROUND(pg_wal_lsn_diff(sent_lsn, replay_lsn) / 1024.0 / 1024.0, 2) AS replication_lag_mb
FROM pg_stat_replication;

-- Audit 4.2: Check Standby Recovery Status (Run on Standby Node)
SELECT 
    pg_is_in_recovery() AS is_standby_node,
    pg_last_wal_receive_lsn() AS last_received_wal,
    pg_last_wal_replay_lsn() AS last_replayed_wal,
    pg_last_xact_replay_timestamp() AS last_transaction_replayed_at,
    ROUND(EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))::numeric, 2) AS lag_seconds;

-- ----------------------------------------------------------------------------
-- PART 5: HIGH AVAILABILITY (HA) PATRONI & FAILOVER DIRECTIVES
-- ----------------------------------------------------------------------------
-- In production, manual failover introduces downtime. We deploy Patroni with etcd
-- distributed consensus to automate leader election and split-brain prevention.

/*
# --- patroni.yml Configuration Excerpt ---
scope: aml_cluster
namespace: /service
name: aml_node_lagos_primary

etcd3:
  hosts:
    - 10.0.1.21:2379
    - 10.0.2.21:2379
    - 10.0.3.21:2379

restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.0.1.10:8008

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576 # 1 MB max lag permitted for election
    synchronous_mode: true
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        max_connections: 500
        hot_standby: "on"

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.0.1.10:5432
  data_dir: /var/lib/postgresql/14/main
  bin_dir: /usr/lib/postgresql/14/bin
  authentication:
    replication:
      username: aml_replicator
      password: StrongReplicationKey2026#
    superuser:
      username: postgres
      password: SuperSecretAdmin2026!
*/

-- ----------------------------------------------------------------------------
-- PART 6: SAMPLE SHARD PRUNING VERIFICATION QUERY
-- ----------------------------------------------------------------------------
-- Populate sample partitioned trips data
INSERT INTO trips_partitioned (route_id, vehicle_id, driver_id, origin_region, departure_datetime, arrival_datetime, seat_capacity, trip_status)
VALUES 
    (1, 1, 1, 'South-West', '2026-10-30 06:30:00+01', '2026-10-30 15:30:00+01', 16, 'Scheduled'),
    (2, 2, 2, 'South-West', '2026-10-30 07:00:00+01', '2026-10-30 10:00:00+01', 16, 'Scheduled'),
    (4, 3, 3, 'North-Central', '2026-10-30 08:00:00+01', '2026-10-30 14:00:00+01', 7, 'Scheduled'),
    (6, 4, 4, 'North-West', '2026-10-30 06:00:00+01', '2026-10-30 12:00:00+01', 7, 'Scheduled'),
    (7, 5, 5, 'South-East', '2026-10-30 07:30:00+01', '2026-10-30 16:30:00+01', 16, 'Scheduled');

-- Verify Partition Pruning (EXPLAIN output proves query only scans the South-West partition table)
EXPLAIN (ANALYZE, BUFFERS)
SELECT trip_id, origin_region, departure_datetime, seat_capacity, trip_status
FROM trips_partitioned
WHERE origin_region = 'South-West' AND trip_status = 'Scheduled';
