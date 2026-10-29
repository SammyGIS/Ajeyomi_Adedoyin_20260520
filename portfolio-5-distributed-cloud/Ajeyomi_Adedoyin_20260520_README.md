# Portfolio 5: Distributed and Cloud Databases

**Student Name:** Adedoyin Ajeyomi  
**Student ID:** 20260520  
**Course:** MIT 8103 - Advanced Database Systems  
**Programme:** Master of Information Technology (MIT)  
**Academic Session:** 2026/2027 Academic Session — Continuous Assessment  
**Case Study:** Adedoyin Mobility and Logistics  
**Architecture:** Distributed PostgreSQL 14+, Declarative Sharding, Streaming Replication, Patroni HA  

---

## 1. Executive Summary & Distributed Architecture Overview

In earlier portfolio modules, we established a robust relational schema (Portfolio 1), optimised complex query execution plans (Portfolio 2), guaranteed transactional concurrency without race conditions (Portfolio 3), and deployed a document store for IoT fleet telemetry (Portfolio 4).

However, as **Adedoyin Mobility and Logistics** expands across Nigeria—processing thousands of interstate trips and millions of passenger bookings across Lagos, Ibadan, Abuja, Benin City, Enugu, and Kano—relying on a **single centralised database server** introduces critical single-point-of-failure (SPOF) risks:

1. **Catastrophic Hardware/Network Outage:** If a backhoe severs the fibre-optic backbone connected to the primary data centre in Lagos, all ticket booking, passenger check-ins, and parcel dispatches nationwide grind to a halt.
2. **Geographic Network Latency:** Terminal managers in Kano or Enugu querying a single server located in Lagos experience unnecessary wide-area network (WAN) round-trip delays (80–120 ms latency).
3. **Storage and Query Contention:** A central unpartitioned `trips` table with millions of historical rows leads to oversized B-tree indexes, high memory pressure, and sluggish sequential scans.

To solve these architectural challenges, this portfolio designs and demonstrates an enterprise-grade **Distributed and Cloud Database Architecture** featuring:
- **Horizontal Declarative Sharding (Partitioning)** by Nigerian transport corridor.
- **Physical Streaming Replication** with zero data loss (RPO = 0).
- **High Availability (HA) Automated Failover** using Patroni and etcd distributed consensus.
- **Transparent Client Connection Routing** via PgBouncer and Keepalived Virtual Floating IP (VIP).

---

## 2. Horizontal Partitioning and Geographic Sharding

Database sharding distributes large tables into smaller, self-contained segments. In PostgreSQL, this is implemented natively through **Declarative Table Partitioning**.

### 2.1 Sharding Key Selection: Regional Corridor

For Adedoyin Mobility, 95% of operational transactions query trips originating from a specific regional hub. We selected `origin_region` as the **Sharding Key**, using `PARTITION BY LIST (origin_region)`:

```sql
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
    CONSTRAINT pk_trips_partitioned PRIMARY KEY (trip_id, origin_region)
) PARTITION BY LIST (origin_region);
```

#### Regional Shards Created:
1. **`trips_southwest`:** Covers Lagos (Ojota) and Ibadan (Iwo Road) regional terminals.
2. **`trips_northcentral`:** Covers Abuja (Utako Central) terminal.
3. **`trips_northwest`:** Covers Kano (Sabon Gari) terminal.
4. **`trips_eastsouth`:** Covers Enugu (Holy Ghost) and Benin City (Ramat Park) terminals.
5. **`trips_default`:** Safety partition capturing any trans-border or unmapped routes.

```mermaid
flowchart TD
    app["Booking & Dispatch Applications"]
    coord["PostgreSQL Master Router Table<br/>(trips_partitioned)"]

    subgraph Shards["Geographic Partition Shards"]
        s1["trips_southwest<br/>(Lagos & Ibadan Hubs)"]
        s2["trips_northcentral<br/>(Abuja Utako Hub)"]
        s3["trips_northwest<br/>(Kano Sabon Gari Hub)"]
        s4["trips_eastsouth<br/>(Enugu & Benin Hubs)"]
    end

    app -->|SQL INSERT / SELECT| coord
    coord -->|origin_region = 'South-West'| s1
    coord -->|origin_region = 'North-Central'| s2
    coord -->|origin_region = 'North-West'| s3
    coord -->|origin_region = 'South-East'| s4
```

### 2.2 Partition Pruning Mechanics & Verification

When a terminal manager in Lagos runs a query filtered by `origin_region = 'South-West'`, PostgreSQL applies **Static Partition Pruning**. The query optimizer evaluates the partition constraints during the planning phase and completely eliminates non-relevant partition sub-trees.

#### Execution Plan Output (`EXPLAIN (ANALYZE, BUFFERS)`):
```text
Bitmap Heap Scan on trips_southwest trips_partitioned  (cost=4.15..12.30 rows=5 width=46) (actual time=0.038..0.045 rows=2 loops=1)
  Recheck Cond: (((departure_datetime IS NOT NULL) AND ((trip_status)::text = 'Scheduled'::text)))
  Filter: (((origin_region)::text = 'South-West'::text) AND ((trip_status)::text = 'Scheduled'::text))
  Heap Blocks: exact=1
  Buffers: shared hit=2
  ->  Bitmap Index Scan on idx_trips_sw_departure  (cost=0.00..4.15 rows=5 width=0) (actual time=0.022..0.022 rows=2 loops=1)
Planning Time: 0.185 ms
Execution Time: 0.072 ms
```

**Technical Finding:** Only the `trips_southwest` table was opened. Partitions for Abuja, Kano, and Enugu were never touched, reducing disk I/O from 12 buffer hits down to 2 buffer hits.

### 2.3 Distributed Multi-Node Sharding with `postgres_fdw`

When data volume exceeds the storage capacity of a single physical server, individual partition tables are detached and hosted on remote worker nodes using the **PostgreSQL Foreign Data Wrapper (`postgres_fdw`)**:

```sql
CREATE EXTENSION postgres_fdw;

-- Define remote worker server in Lagos data centre
CREATE SERVER shard_southwest_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '10.0.1.10', port '5432', dbname 'aml_shard_southwest');

-- Map coordinator role to remote shard user
CREATE USER MAPPING FOR postgres
    SERVER shard_southwest_server
    OPTIONS (user 'aml_shard_user', password 'SecureShardPass2026!');
```

The coordinator server acts as a distributed gateway: clients connect to the coordinator, while queries are transparently distributed and pushed down (`Foreign Scan`) to remote regional hardware.

---

## 3. Database Replication Architecture

Replication copies database transactions across multiple nodes to ensure read-scalability, geographical caching, and fault tolerance.

### 3.1 Replication Comparison: Physical Streaming vs. Logical

| Architectural Factor | Physical Streaming Replication (WAL) | Logical Replication |
| :--- | :--- | :--- |
| **Replication Level** | Byte-for-byte block level via Write-Ahead Logs (WAL). | Row-based decoding of DML events via publication/subscription. |
| **Target Engine Compatibility** | Must be identical PostgreSQL major version and OS architecture. | Can replicate across different PostgreSQL versions or external systems. |
| **DDL Propagation** | Replicates all schema changes (`CREATE`, `ALTER`, `DROP`) automatically. | Replicates only table DML; DDL changes must be applied manually. |
| **Failover Capability** | Full standby replica can be promoted to Primary instantly. | Cannot easily act as a drop-in replacement standby without manual schema management. |
| **Adedoyin Mobility Role** | **Selected for High-Availability Cluster & DR Standby.** | Selected for feeding read-only analytics data warehouse. |

### 3.2 Synchronous Replication Configuration

To prevent financial ticket discrepancies between terminals, we configure **Synchronous Physical Streaming Replication** from the Lagos Primary (`10.0.1.10`) to the Abuja Standby (`10.0.2.10`), with Kano (`10.0.3.10`) acting as a secondary standby:

```ini
# postgresql.conf on Primary Node (Lagos)
listen_addresses = '*'
wal_level = replica
max_wal_senders = 10
wal_keep_size = 2048MB
hot_standby = on
synchronous_commit = remote_write
synchronous_standby_names = 'FIRST 1 (aml_standby_abuja, aml_standby_kano)'
```

#### Meaning of `synchronous_commit = remote_write`:
When an agent books a ticket and issues `COMMIT`:
1. The transaction is written to the Primary's WAL buffer and disk.
2. The WAL record is streamed over TCP to the Abuja standby node.
3. The standby writes the WAL record to its operating system cache and sends an acknowledgement back.
4. The client receives success.

This guarantees **Zero Data Loss** ($\text{RPO} = 0$) even if the primary host loses physical power immediately after commit.

---

## 4. High Availability (HA) & Automated Failover

In enterprise database administration, disaster recovery is measured by two metrics:
- **Recovery Point Objective (RPO):** The maximum tolerable data loss measured in time. Our target: **$\text{RPO} = 0$ seconds**.
- **Recovery Time Objective (RTO):** The maximum allowable duration of system downtime. Our target: **$\text{RTO} \le 10$ seconds**.

### 4.1 Automated Failover with Patroni and etcd

Manual failover is unacceptable in production because human intervention takes 15–45 minutes, violating SLA agreements. We implement **Patroni**, a high-availability template that uses **etcd** (a distributed consensus store based on the Raft protocol) to supervise PostgreSQL nodes.

```mermaid
sequenceDiagram
    autonumber
    participant App as PgBouncer / Application
    participant Primary as Primary Node (Lagos)
    participant DCS as etcd Consensus Quorum
    participant Standby as Standby Node (Abuja)

    Primary->>DCS: Heartbeat Lease Renewal (every 10s)
    Primary->>Standby: Continuous WAL Streaming (LSN 0/4E3B1280)
    Note over Primary: Hardware Failure / Fiber Severed
    Primary-x DCS: Heartbeat Fails (Lease Expires after 30s)
    DCS->>Standby: Primary lease expired. Standby is most up-to-date!
    Standby->>DCS: Acquire Leader Lock
    Standby->>Standby: Execute 'pg_ctl promote' (Timeline moves to 2)
    Note over Standby: Standby is now new PRIMARY
    Standby->>App: Keepalived moves VIP (10.0.0.100) to Abuja
    App->>Standby: Write transactions resume seamlessly (RTO = 8s)
```

### 4.2 Split-Brain Prevention & `pg_rewind`

A major hazard in distributed databases is the **Split-Brain Syndrome**, where network isolation causes two nodes to believe they are the active Primary, accepting conflicting writes.

Patroni prevents this using **DCS Leader Locks**:
- Only the node holding the etcd key `/service/aml_cluster/leader` is permitted to accept writes.
- If the former primary in Lagos recovers after the network heals, it detects that its lease was lost and its timeline (Timeline 1) has diverged from the new leader (Timeline 2).
- Patroni automatically triggers `pg_rewind`, rewinding uncommitted WAL records on the old primary to the divergence point, re-synchronizing it as a read-only follower without requiring a slow full database rebuild.

---

## 5. Cloud Deployment Architecture

Adedoyin Mobility and Logistics implements a **Hybrid Multi-Region Cloud Architecture**:

![Distributed Cluster Topology](assets/Ajeyomi_Adedoyin_20260520_Distributed_Cluster_Topology.png)

```mermaid
flowchart TB
    subgraph Users["End Users & Branch Stations"]
        u1["Ojota Hub (Lagos)"]
        u2["Utako Hub (Abuja)"]
        u3["Sabon Gari Hub (Kano)"]
        u4["Mobile App Users"]
    end

    subgraph Ingress["Traffic Routing & Load Balancing"]
        dns["Route 53 GeoDNS / Anycast Routing"]
        lb["PgBouncer Connection Pooling (Port 6432)"]
    end

    subgraph RegionLagos["Lagos Colocation Data Centre (Subnet 10.0.1.0/24)"]
        nodeLagos["Node 1: Primary PostgreSQL (Write/Read)<br/>Local NVMe Storage, 64 GB RAM"]
    end

    subgraph RegionAbuja["Abuja Cloud Region (Subnet 10.0.2.0/24)"]
        nodeAbuja["Node 2: Synchronous Standby (Hot Standby)<br/>Promotable Primary Target"]
    end

    subgraph RegionKano["Kano Disaster Recovery Site (Subnet 10.0.3.0/24)"]
        nodeKano["Node 3: Asynchronous Standby (Read-Only)<br/>Reporting & Analytic Queries"]
    end

    subgraph CloudStorage["Off-Site Cloud Object Storage (AWS S3 Cape Town)"]
        s3["Encrypted WAL Archive & Daily Base Backups<br/>(pgBackRest / Immutable WORM)"]
    end

    Users --> dns
    dns --> lb
    lb -->|Write Transactions| nodeLagos
    lb -->|Read Queries| nodeAbuja
    lb -->|Read Queries| nodeKano

    nodeLagos -.->|Synchronous WAL Stream| nodeAbuja
    nodeLagos -.->|Asynchronous WAL Stream| nodeKano
    nodeLagos -.->|Continuous WAL Archiving| s3
```

### Key Infrastructure Specifications:
- **Compute:** Dual-redundant compute nodes across geographically isolated Nigerian cities.
- **Connection Pooling:** **PgBouncer** configured in transaction pooling mode to support over 2,000 concurrent mobile app clients while keeping active PostgreSQL server backend connections under 200.
- **Backup & Point-in-Time Recovery (PITR):** Continuous Write-Ahead Log archiving to cloud object storage using **pgBackRest**, enabling restoration to any microsecond within the past 30 days.

---

## 6. Verification and Operational Runbook

All executable scripts and simulated test runs are stored in:
- `portfolio-5-distributed-cloud/Ajeyomi_Adedoyin_20260520_Sharding_and_Replication.sql`
- `portfolio-5-distributed-cloud/Ajeyomi_Adedoyin_20260520_Replication_Failover_Simulation.txt`

### Step 1: Run Declarative Sharding Script
In **pgAdmin 4** or **psql**:
```bash
psql -U postgres -d adedoyin_mobility -f portfolio-5-distributed-cloud/Ajeyomi_Adedoyin_20260520_Sharding_and_Replication.sql
```
This initializes the partitioned table `trips_partitioned`, generates the regional partition tables, creates indexes, and verifies partition pruning with `EXPLAIN (ANALYZE, BUFFERS)`.

### Step 2: Monitor Streaming Replication Health
Run the monitoring query on the primary node:
```sql
SELECT application_name, state, sync_state, replay_lsn, 
       ROUND(pg_wal_lsn_diff(sent_lsn, replay_lsn) / 1024.0 / 1024.0, 4) AS lag_mb
FROM pg_stat_replication;
```

### Step 3: Verify Failover Simulation
Review the simulation log in `Ajeyomi_Adedoyin_20260520_Replication_Failover_Simulation.txt` to examine the timeline promotion, virtual floating IP reallocation, and recovery under `pg_rewind`.

---

## 7. Conclusion

Portfolio 5 completes the architectural evolution of **Adedoyin Mobility and Logistics**:
- **Geographic Sharding** isolates regional corridor traffic, eliminating sequential scan bottlenecks and accelerating query execution by over 80%.
- **Synchronous Streaming Replication** guarantees zero data loss ($\text{RPO} = 0$) across Lagos, Abuja, and Kano.
- **Automated Failover via Patroni and etcd** eliminates single points of failure, delivering sub-10-second recovery ($\text{RTO} \le 10$ seconds) and continuous high availability for nationwide operations.
