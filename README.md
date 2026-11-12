# Advanced Database Systems Portfolio

**Student Name:** Adedoyin Ajeyomi  
**Student ID:** 20260520  
**Course:** MIT 8103 - Advanced Database Systems  
**Programme:** Master of Information Technology (MIT)  
**Session:** 2026/2027 Academic Session — Continuous Assessment (40 Marks)  
**Case Study Organisation:** Adedoyin Mobility and Logistics  
**GitHub Repository:** [https://github.com/SammyGIS/Ajeyomi_Adedoyin_20260520](https://github.com/SammyGIS/Ajeyomi_Adedoyin_20260520)  
**LMS Submission Document:** [Ajeyomi_Adedoyin_20260520_LMS_Documentation.docx](Ajeyomi_Adedoyin_20260520_LMS_Documentation.docx)  

---

## 1. Project Overview

This repository contains the comprehensive practical portfolio work for **MIT 8103: Advanced Database Systems**. The portfolio demonstrates real-world database design, implementation, analysis, optimisation, and distributed cloud deployment using a realistic Nigerian transport and courier enterprise: **Adedoyin Mobility and Logistics**.

The portfolio covers five core database engineering areas:
1. **Portfolio 1: Database Design and Modelling** (Relational schemas, ER diagrams, business constraints, and normalisation)
2. **Portfolio 2: Query Processing and Optimisation** (Execution plans, indexing strategies, and query tuning)
3. **Portfolio 3: Transactions and Concurrency** (ACID guarantees, row locking, and avoiding race conditions)
4. **Portfolio 4: NoSQL Databases** (Document stores, JSON telemetry, geospatial indexing, and polyglot persistence)
5. **Portfolio 5: Distributed and Cloud Databases** (Corridor sharding, replication, Patroni HA failover, and high availability)

---

## 2. Selected Case Study: Adedoyin Mobility and Logistics

### 2.1 Company Background
Adedoyin Mobility and Logistics provides scheduled interstate travel and parcel delivery across major highway corridors in Nigeria.

- **Fleet:** 20 commercial vehicles, including Toyota HiAce buses (14–18 seats) and Toyota Sienna minivans (7–8 seats).
- **6 Regional Stations:**
  1. **Lagos:** Ojota Regional Terminal
  2. **Ibadan:** Iwo Road Terminal
  3. **Abuja:** Utako Central Terminal
  4. **Benin City:** Ramat Park Terminal
  5. **Enugu:** Holy Ghost Regional Terminal
  6. **Kano:** Sabon Gari Regional Terminal

### 2.2 Core Business Activities
- **Interstate Passenger Travel:** Customers search scheduled trips, choose their preferred seat, provide passenger manifest details, and purchase tickets.
- **Express Parcel Logistics:** Customers send packages between stations along the same vehicle routes. Each package receives a unique waybill tracking code.
- **KYC & Security Compliance:** The database enforces identity verification (National Identity Numbers / NIN and Driver's Licenses for drivers, passenger emergency contacts for Federal Road Safety Corps / FRSC compliance, and recipient verification for package pickups).
- **Operations Dashboard:** Fleet managers track vehicle status, GPS positions, seat occupancy, and delivery milestones in real time.

---

## 3. Repository Structure & Naming Standard

Every file in this repository strictly follows the university naming pattern:  
`Surname_Firstname_StudentID_DocumentType.ext` (`Ajeyomi_Adedoyin_20260520_...`)

```tree
Ajeyomi_Adedoyin_20260520/
│
├── portfolio-1-database-design/
│   ├── assets/
│   │   └── Ajeyomi_Adedoyin_20260520_ERD.png         # Clean black-and-white Entity Relationship Diagram
│   ├── Ajeyomi_Adedoyin_20260520_README.md       # Full design report, schema catalog, normalisation
│   ├── Ajeyomi_Adedoyin_20260520_Schema.sql      # Executable DDL SQL table schemas & constraints
│   ├── Ajeyomi_Adedoyin_20260520_Seed_Data.sql   # SQL seed records for hubs, vehicles, and trips
│   └── Ajeyomi_Adedoyin_20260520_Copy_From_CSV.sql # Script to load data directly from CSV files
│
├── portfolio-2-query-optimisation/
│   ├── assets/
│   │   └── Ajeyomi_Adedoyin_20260520_Query_Performance_Comparison.png # Execution benchmark visual chart
│   ├── Ajeyomi_Adedoyin_20260520_README.md       # Query explanations, execution plans, and benchmarks
│   ├── Ajeyomi_Adedoyin_20260520_Queries.sql     # 4 business queries, EXPLAIN commands, and index scripts
│   └── Ajeyomi_Adedoyin_20260520_Query_Execution_Plans.txt # Text output of execution plans before and after
│
├── portfolio-3-transactions-concurrency/
│   ├── assets/
│   │   └── Ajeyomi_Adedoyin_20260520_Concurrency_Locking_Workflow.png # Row-level locking sequence diagram
│   ├── Ajeyomi_Adedoyin_20260520_README.md       # Explanations of ACID, locking, and isolation levels
│   ├── Ajeyomi_Adedoyin_20260520_Transactions.sql # Executable SQL scripts for Session A and Session B
│   └── Ajeyomi_Adedoyin_20260520_Concurrency_Test_Results.txt # Text log of terminal tests and deadlock output
│
├── portfolio-4-nosql/
│   ├── assets/
│   │   └── Ajeyomi_Adedoyin_20260520_NoSQL_Document_Architecture.png # Polyglot persistence architecture diagram
│   ├── Ajeyomi_Adedoyin_20260520_README.md       # Comprehensive NoSQL document store report
│   ├── Ajeyomi_Adedoyin_20260520_NoSQL_Model.json # JSON data model specification for collections
│   ├── Ajeyomi_Adedoyin_20260520_MongoDB_Queries.js # Mongosh script (validators, 2dsphere index, aggregations)
│   └── Ajeyomi_Adedoyin_20260520_NoSQL_Execution_Results.txt # Mongosh execution output and explain plans
│
├── portfolio-5-distributed-cloud/
│   ├── assets/
│   │   ├── Ajeyomi_Adedoyin_20260520_Distributed_Cluster_Topology.png # What was tested and what is only a design
│   │   └── Ajeyomi_Adedoyin_20260520_Partition_Pruning_Benchmark.png  # Partition pruning chart
│   ├── Ajeyomi_Adedoyin_20260520_README.md
│   ├── Ajeyomi_Adedoyin_20260520_Run_Replication_Failover_Test.ps1  # Real primary, standby and failover test
│   ├── Ajeyomi_Adedoyin_20260520_Replication_Failover_Test_Results.txt
│   ├── Ajeyomi_Adedoyin_20260520_Run_Sharding_Test.ps1              # Real partitioning and postgres_fdw test
│   └── Ajeyomi_Adedoyin_20260520_Sharding_Test_Results.txt
│
├── data/                                         # Central Data Repository (All data: CSV, XLSX, and JSON)
│   ├── Ajeyomi_Adedoyin_20260520_Adedoyin_Mobility_Data.xlsx # Full multi-sheet Excel workbook
│   ├── Ajeyomi_Adedoyin_20260520_Data_Generator.py           # Python synthetic data generator script
│   ├── Ajeyomi_Adedoyin_20260520_NoSQL_Model.json            # Full NoSQL document database export
│   ├── Ajeyomi_Adedoyin_20260520_NoSQL_Data_Generator.py     # Builds the MongoDB data from the SQL dataset
│   ├── vehicle_telemetry.json                                # 23,802 GPS pings for MongoDB
│   ├── parcel_tracking.json                                  # 3,500 parcel documents for MongoDB
│   └── *.csv (stations, vehicles, drivers, customers, routes, trips, bookings, parcels)
│
├── Ajeyomi_Adedoyin_20260520_LMS_Documentation.docx  # 2-3 page summary document for LMS submission
├── Ajeyomi_Adedoyin_20260520_README.md               # Main student portfolio overview
└── README.md                                         # GitHub landing page overview
```

---

## 4. Portfolio Modules Progress Tracker

| Module | Title | Key Deliverables | Status |
| :--- | :--- | :--- | :---: |
| **Portfolio 1** | [Database Design & Modelling](portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_README.md) | 8-table relational schema, clean B&W ERD, KYC integration, constraints, and UNF-to-BCNF normalisation | **Completed** |
| **Portfolio 2** | [Query Optimisation](portfolio-2-query-optimisation/Ajeyomi_Adedoyin_20260520_README.md) | Query execution plans (`EXPLAIN ANALYZE`), B-tree & composite indexes, 4.8x to 65.4x speedup | **Completed** |
| **Portfolio 3** | [Transactions & Concurrency](portfolio-3-transactions-concurrency/Ajeyomi_Adedoyin_20260520_README.md) | ACID guarantees, row locking (`SELECT FOR UPDATE`), isolation levels, deadlock handling | **Completed** |
| **Portfolio 4** | [NoSQL Databases](portfolio-4-nosql/Ajeyomi_Adedoyin_20260520_README.md) | Document store generated from the SQL data, 2dsphere geospatial index, measured index speedups, TTL demo, aggregation pipelines | **Completed** |
| **Portfolio 5** | [Distributed & Cloud Databases](portfolio-5-distributed-cloud/Ajeyomi_Adedoyin_20260520_README.md) | Real replication and failover test, partition pruning, postgres_fdw sharding, cloud design | **Completed** |

---

## 5. Summary of Completed Work

### 5.1 Portfolio 1: Database Design & Modelling
- **Relational Schema:** Designed 8 normalized 3NF/BCNF tables (`stations`, `vehicles`, `drivers`, `customers`, `routes`, `trips`, `bookings`, `parcels`).
- **Entity Relationship Diagram (ERD):** Created a clean, professional black-and-white Crow's Foot diagram showing primary keys, foreign keys, and cardinalities.
- **Constraints & Business Rules:**
  - Guaranteed no double-seat booking via a unique constraint on `(trip_id, seat_number)`.
  - Enforced regulatory KYC (11-digit NIN checks, driver's license numbers, passenger emergency contacts).
  - Validated vehicle seating capacities (7 to 18 seats) and chronological travel dates (`arrival_datetime > departure_datetime`).
- **Data Population:** Built a realistic synthetic data generator in Python producing 8,000 bookings, 3,500 parcel waybill records and 1,200 trips.

### 5.2 Portfolio 2: Query Processing & Optimisation
- **Core Business Queries:** Implemented four operational SQL queries:
  1. *Route Revenue Report:* Calculates total passenger income per interstate corridor.
  2. *Weekly Trip and Vehicle Dispatch Register:* Lists the trips, vehicles and drivers on one route for one week.
  3. *Customer Parcel Tracking:* Looks up every parcel sent by a customer using the sender's phone number.
  4. *Driver Performance:* Summarizes trips completed and passengers carried per driver.
- **Query Analysis with `EXPLAIN (ANALYZE, BUFFERS)`:**
  - Captured baseline plans showing high-cost **Sequential Scans** (`Seq Scan`) across large tables.
  - Designed targeted B-tree composite and covering indexes (`INCLUDE` clause).
  - Re-benchmarked queries to verify the switch to **Index Scans** and **Bitmap Index Scans**.

#### **Portfolio 2 Benchmark Summary (scaled test database: 60,000 trips, 400,000 bookings, 175,000 parcels):**

| Query Description | Baseline Time | Optimised Time | Speedup Factor | Buffers Read (Before → After) |
| :--- | :---: | :---: | :---: | :---: |
| **Query 1: Route Revenue** | 7.61 ms | 1.30 ms | 5.8x | 1,550 → 949 pages |
| **Query 2: Weekly Dispatch** | 5.36 ms | 0.10 ms | 51.1x | 624 → 10 pages |
| **Query 3: Parcel Tracking** | 20.41 ms | 0.31 ms | 65.4x | 2,871 → 406 pages |
| **Query 4: Driver Workload** | 6.39 ms | 1.32 ms | 4.8x | 1,538 → 934 pages |

These figures are real `EXPLAIN (ANALYZE, BUFFERS)` output from PostgreSQL 17.5. The real dataset was copied 50 times into a separate benchmark database because the original tables are too small for the planner to use indexes. See the Portfolio 2 README for the method.

### 5.3 Portfolio 3: Transactions & Concurrency Control
- **ACID Demonstrations:** Tested full atomic seat reservations with `COMMIT` upon payment confirmation and automatic clean reversion with `ROLLBACK` on transaction failure.
- **Race Condition Prevention:** Simulated two passengers simultaneously purchasing the same seat. Implemented pessimistic row-level locking via `SELECT ... FOR UPDATE` to force concurrent sessions to wait safely, preventing double-bookings.
- **Isolation Levels Analysis:** Compared PostgreSQL's default `READ COMMITTED` against `REPEATABLE READ`, proving snapshot stability for financial and accounting reports.
- **Deadlock Detection & Resolution:** Tested circular lock dependencies between vehicle updates, observing PostgreSQL's automatic cycle detection and abort mechanism within 1000ms.

### 5.4 Portfolio 4: NoSQL Databases (Document Data Store)
- **Document Data Model:** MongoDB collections for GPS telemetry (23,802 pings) and parcel tracking (3,500 parcels), generated from the real SQL dataset so both databases describe the same company.
- **Validation and Indexes:** JSON Schema validation (a bad waybill number is refused), a `2dsphere` index for vehicles near a place, and compound and unique indexes. Four queries were measured before and after indexing with `explain("executionStats")`: full scans of 23,802 documents became index scans of between 1 and 2,762 documents.
- **Aggregation Pipelines:** Parcel scans per station and a telemetry summary per corridor.
- **TTL Expiry:** Shown on a separate demo collection (3 documents became 1 after 80 seconds).
- **Polyglot Persistence:** PostgreSQL keeps bookings and money, and MongoDB keeps GPS pings and parcel history.

### 5.5 Portfolio 5: Distributed & Cloud Databases
- **Real replication and failover:** a primary and a standby PostgreSQL server on one computer, with synchronous replication. The primary was crashed and the standby took over in 258 ms with no committed rows lost.
- **Partition pruning:** trips split by region. A one-region query read 64 pages instead of 704, and ran in 1.02 ms instead of 6.78 ms.
- **Sharding across two servers:** `postgres_fdw` sends a North query to a second server, while a South query stays on the main one.
- **Cloud design:** Patroni, etcd and servers in Lagos, Abuja and Kano are described as a plan and were not run.

---

## 6. How to Run and Verify This Project

### 6.1 Relational Database Modules (Portfolios 1, 2, 3, 5) in pgAdmin 4
1. Open **pgAdmin 4** and connect to your local PostgreSQL server.
2. Create database `adedoyin_mobility`.
3. Execute `portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_Schema.sql` to generate all 8 tables and constraints.
4. Load the data using **one** of the two options (not both, as they populate the same tables): `portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_Seed_Data.sql` (plain SQL `INSERT` sample records, runs directly in pgAdmin 4), or `portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_Copy_From_CSV.sql` (full dataset of 8,000 bookings, 3,500 parcels and 1,200 trips from `data/`, uses psql `\copy`, so run it from `psql` in the repository root).
5. Execute `portfolio-2-query-optimisation/Ajeyomi_Adedoyin_20260520_Queries.sql` to test query execution plans (`EXPLAIN ANALYZE`).
6. Test concurrency in dual tabs using instructions in `portfolio-3-transactions-concurrency/Ajeyomi_Adedoyin_20260520_README.md`.
7. Execute `portfolio-5-distributed-cloud/Ajeyomi_Adedoyin_20260520_Sharding_and_Replication.sql` to test partition pruning and replication configurations.

### 6.2 NoSQL Module (Portfolio 4) in MongoDB Compass / mongosh
1. Start MongoDB: `mongod --dbpath /path/to/data`.
2. Execute the query script in `mongosh`:
   ```bash
   load("portfolio-4-nosql/Ajeyomi_Adedoyin_20260520_MongoDB_Queries.js")
   ```
3. Alternatively, in **MongoDB Compass**, import `portfolio-4-nosql/Ajeyomi_Adedoyin_20260520_NoSQL_Model.json` into database `adedoyin_mobility_nosql` to inspect collections and visual aggregation pipelines.

---

## 7. AI Use Declaration

I used AI assistants (Google Antigravity with Gemini, and Claude) to help with ideas and planning, preparing the data, and writing, validating and debugging code.

I set up the software on my own computer, ran the scripts and tests, took the screenshots and checked the results, and I can explain all the work in this portfolio.
