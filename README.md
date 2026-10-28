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

This repository contains the practical portfolio work for **MIT 8103: Advanced Database Systems**. The portfolio demonstrates real-world database design, implementation, analysis, and optimisation using a realistic Nigerian transport and courier enterprise: **Adedoyin Mobility and Logistics**.

The portfolio covers five core database engineering areas:
1. **Portfolio 1: Database Design and Modelling** (Relational schemas, ER diagrams, business constraints, and normalisation)
2. **Portfolio 2: Query Processing and Optimisation** (Execution plans, indexing strategies, and query tuning)
3. **Portfolio 3: Transactions and Concurrency** (ACID guarantees, row locking, and avoiding race conditions)
4. **Portfolio 4: NoSQL Databases** (Document stores, JSON telemetry, and polyglot persistence)
5. **Portfolio 5: Distributed and Cloud Databases** (Sharding, replication, failover, and high availability)

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
│   ├── Ajeyomi_Adedoyin_20260520_README.md       # Full design report, schema catalog, normalisation
│   ├── Ajeyomi_Adedoyin_20260520_ERD.png         # Clean black-and-white Entity Relationship Diagram
│   ├── Ajeyomi_Adedoyin_20260520_Schema.sql      # Executable DDL SQL table schemas & constraints
│   ├── Ajeyomi_Adedoyin_20260520_Seed_Data.sql   # SQL seed records for hubs, vehicles, and trips
│   └── Ajeyomi_Adedoyin_20260520_Copy_From_CSV.sql # Script to load data directly from CSV files
│
├── portfolio-2-query-optimisation/
│   ├── Ajeyomi_Adedoyin_20260520_README.md       # Query explanations, execution plans, and benchmarks
│   ├── Ajeyomi_Adedoyin_20260520_Queries.sql     # 4 business queries, EXPLAIN commands, and index scripts
│   └── Ajeyomi_Adedoyin_20260520_Query_Execution_Plans.txt # Text output of execution plans before and after
│
├── portfolio-3-transactions-concurrency/
│   ├── Ajeyomi_Adedoyin_20260520_README.md       # Explanations of ACID, locking, and isolation levels
│   ├── Ajeyomi_Adedoyin_20260520_Transactions.sql # Executable SQL scripts for Session A and Session B
│   └── Ajeyomi_Adedoyin_20260520_Concurrency_Test_Results.txt # Text log of terminal tests and deadlock output
│
├── portfolio-4-nosql/                            # Document store for GPS tracking and cargo telemetry
├── portfolio-5-distributed-cloud/                # Sharding, replication, and high-availability architecture
│
├── data/                                         # Generated CSV datasets (stations, vehicles, trips, etc.)
├── utils/                                        # Python synthetic data generator script
├── Ajeyomi_Adedoyin_20260520_LMS_Documentation.docx  # 2-3 page summary document for LMS submission
├── Ajeyomi_Adedoyin_20260520_README.md               # Main student portfolio overview
└── README.md                                         # GitHub landing page overview
```

---

## 4. Portfolio Modules Progress Tracker

| Module | Title | Key Deliverables | Status |
| :--- | :--- | :--- | :---: |
| **Portfolio 1** | [Database Design & Modelling](portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_README.md) | 8-table relational schema, clean B&W ERD, KYC integration, constraints, and UNF-to-BCNF normalisation | **Completed** |
| **Portfolio 2** | [Query Optimisation](portfolio-2-query-optimisation/Ajeyomi_Adedoyin_20260520_README.md) | Query execution plans (`EXPLAIN ANALYZE`), B-tree & composite indexes, 6.5x–12.8x speedup | **Completed** |
| **Portfolio 3** | [Transactions & Concurrency](portfolio-3-transactions-concurrency/Ajeyomi_Adedoyin_20260520_README.md) | ACID guarantees, row locking (`SELECT FOR UPDATE`), isolation levels, deadlock handling | **Completed** |
| **Portfolio 4** | NoSQL Databases | Document data modelling, GPS telemetry tracking, JSON storage | Scheduled |
| **Portfolio 5** | Distributed & Cloud Databases | Regional sharding, database replication, and cloud failover | Scheduled |

---

## 5. Summary of Completed Work

### 5.1 Portfolio 1: Database Design & Modelling
- **Relational Schema:** Designed 8 normalized 3NF/BCNF tables (`stations`, `vehicles`, `drivers`, `customers`, `routes`, `trips`, `bookings`, `parcels`).
- **Entity Relationship Diagram (ERD):** Created a clean, professional black-and-white Crow's Foot diagram showing primary keys, foreign keys, and cardinalities.
- **Constraints & Business Rules:**
  - Guaranteed no double-seat booking via a unique constraint on `(trip_id, seat_number)`.
  - Enforced regulatory KYC (11-digit NIN checks, driver's license numbers, passenger emergency contacts).
  - Validated vehicle seating capacities (7 to 18 seats) and chronological travel dates (`arrival_datetime > departure_datetime`).
- **Data Population:** Built a realistic synthetic data generator in Python producing over 5,000 bookings and 1,200 parcel waybill records.

### 5.2 Portfolio 2: Query Processing & Optimisation
- **Core Business Queries:** Implemented four operational SQL queries:
  1. *Route Revenue Report:* Calculates total passenger income per interstate corridor.
  2. *Daily Trip Dispatch:* Lists upcoming scheduled and boarding trips for station managers.
  3. *Customer Parcel Tracking:* Looks up active packages by sender phone number or waybill status.
  4. *Driver Performance:* Summarizes trips completed and passengers carried per driver.
- **Query Analysis with `EXPLAIN (ANALYZE, BUFFERS)`:**
  - Captured baseline plans showing high-cost **Sequential Scans** (`Seq Scan`) across large tables.
  - Designed targeted B-tree composite and covering indexes (`INCLUDE` clause).
  - Re-benchmarked queries to verify the switch to **Index Scans** and **Bitmap Index Scans**.

#### **Portfolio 2 Benchmark Summary:**

| Query Description | Baseline Time | Optimised Time | Speedup Factor | Buffers Read (Before $\rightarrow$ After) |
| :--- | :---: | :---: | :---: | :---: |
| **Query 1: Route Revenue** | 18.52 ms | 2.18 ms | **8.5x Faster** | 82 $\rightarrow$ 18 blocks |
| **Query 2: Trip Dispatch** | 5.89 ms | 0.46 ms | **12.8x Faster** | 36 $\rightarrow$ 14 blocks |
| **Query 3: Parcel Tracking** | 7.28 ms | 0.97 ms | **7.5x Faster** | 48 $\rightarrow$ 16 blocks |
| **Query 4: Driver Workload** | 22.75 ms | 3.49 ms | **6.5x Faster** | 114 $\rightarrow$ 28 blocks |

### 5.3 Portfolio 3: Transactions & Concurrency Control
- **ACID Demonstrations:** Tested full atomic seat reservations with `COMMIT` upon payment confirmation and automatic clean reversion with `ROLLBACK` on transaction failure.
- **Race Condition Prevention:** Simulated two passengers simultaneously purchasing the same seat. Implemented pessimistic row-level locking via `SELECT ... FOR UPDATE` to force concurrent sessions to wait safely, preventing double-bookings.
- **Isolation Levels Analysis:** Compared PostgreSQL's default `READ COMMITTED` against `REPEATABLE READ`, proving snapshot stability for financial and accounting reports.
- **Deadlock Detection & Resolution:** Tested circular lock dependencies between vehicle updates, observing PostgreSQL's automatic cycle detection and abort mechanism within 1000ms.

---

## 6. How to Run and Verify This Project in pgAdmin 4

You do not need to use the command line terminal. You can run all portfolio scripts and test execution plans directly using the **pgAdmin 4** graphical interface.

### 6.1 Prerequisites
- **PostgreSQL 14+** and **pgAdmin 4** installed.
- Python 3.10+ (if you wish to re-generate synthetic datasets in `utils/`).

### 6.2 Step-by-Step Instructions in pgAdmin 4

#### **Step 1: Create the Database**
1. Open **pgAdmin 4** and connect to your local PostgreSQL server.
2. In the left **Browser** tree, right-click **Databases** and select **Create > Database...**
3. In the Database field, enter `adedoyin_mobility` and click **Save**.

#### **Step 2: Create the Schema (Portfolio 1)**
1. In the Browser tree, click on the **`adedoyin_mobility`** database.
2. Open the Query Tool: click **Tools > Query Tool** from the top menu.
3. Click the **Open File** icon (folder icon, or press `Ctrl + O`).
4. Select `portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_Schema.sql` and click **Select**.
5. Click the **Execute / Refresh** button (play icon, or press `F5`).
6. All 8 tables, foreign keys, and integrity constraints are created.

#### **Step 3: Load the Seed Data**
1. In the Query Tool, click **Open File** (`Ctrl + O`).
2. Select `portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_Seed_Data.sql` and click **Select**.
3. Press `F5` (Execute). This safely populates the database with 6 regional stations, 20 fleet vehicles, 150 drivers, 1,000 customers, 500 trips, 5,000 bookings, and 1,200 parcels.

#### **Step 4: Run Query Optimisation & Plans (Portfolio 2)**
1. In the Query Tool, click **Open File** (`Ctrl + O`).
2. Select `portfolio-2-query-optimisation/Ajeyomi_Adedoyin_20260520_Queries.sql` and click **Select**.
3. Highlight any query and press `F5` to execute, or click the **Explain Analyze** icon (`Shift + F7`) to view the visual execution plan.

#### **Step 5: Test Transactions & Concurrency (Portfolio 3)**
1. Open two separate Query Tool tabs on the `adedoyin_mobility` database (representing Customer A and Customer B).
2. Follow the step-by-step instructions in [Portfolio 3 README](portfolio-3-transactions-concurrency/Ajeyomi_Adedoyin_20260520_README.md#7-how-to-test-concurrency-in-pgadmin-4-step-by-step) to observe `SELECT ... FOR UPDATE` row locking and race condition prevention.

---

## 7. Academic Integrity & AI Use Declaration

This portfolio was developed in full compliance with MIVA Open University's academic integrity guidelines:

1. **AI Tools Used:** Generative AI assistant (Google Antigravity / Gemini) was utilised as an interactive learning aid and pair-programming assistant.
2. **Purpose of Use:**
   - Brainstorming realistic transport corridors, vehicle configurations, and KYC requirements in Nigeria.
   - Assisting with synthetic data generation scripts and formatting markdown tables.
   - Reviewing query execution plan nodes and index explanations.
3. **Student Verification & Ownership:**
   - Every SQL DDL schema, table relationship, constraint, and query was personally reviewed, tested, and validated for technical correctness.
   - All execution plans and indexing strategies were verified against standard PostgreSQL query planner behavior.
   - I am fully prepared to defend and explain all architectural choices, normalisation steps, and optimisation decisions during technical verification.
