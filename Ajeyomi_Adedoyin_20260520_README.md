# Advanced Database Systems Portfolio

**Student Name:** Adedoyin Ajeyomi  
**Student ID:** 20260520  
**Course:** Advanced Database Systems  
**Case Study Organisation:** Adedoyin Mobility and Logistics  
**GitHub Repository:** [https://github.com/SammyGIS/Ajeyomi_Adedoyin_20260520](https://github.com/SammyGIS/Ajeyomi_Adedoyin_20260520)  
**LMS Submission Document:** [Ajeyomi_Adedoyin_20260520_LMS_Documentation.docx](Ajeyomi_Adedoyin_20260520_LMS_Documentation.docx)  

---

## 1. Project Overview

This repository contains the complete 5-part database portfolio for **Adedoyin Mobility and Logistics**, an interstate transport and courier company in Nigeria. 

The portfolio demonstrates practical database engineering across five key areas:
1. **Database Design & Modelling** (Relational schemas, ER diagrams, constraints, and normalisation)
2. **Query Optimisation** (Execution plans, indexing strategies, and query performance tuning)
3. **Transactions & Concurrency** (ACID compliance, row locking, and preventing race conditions)
4. **NoSQL Databases** (Document stores, JSON telemetry, and polyglot persistence)
5. **Distributed & Cloud Databases** (Sharding, replication, failover, and high availability)

---

## 2. Selected Case Study: Adedoyin Mobility and Logistics

### 2.1 Company Background
Adedoyin Mobility and Logistics provides scheduled interstate travel and parcel delivery services across major highway corridors in Nigeria.

- **Fleet:** 20 commercial vehicles, including Toyota HiAce buses (14–18 seats) and Toyota Sienna minivans (7–8 seats).
- **6 Regional Stations:**
  - **Lagos:** Ojota Regional Terminal
  - **Ibadan:** Iwo Road Terminal
  - **Abuja:** Utako Central Terminal
  - **Benin City:** Ramat Park Terminal
  - **Enugu:** Holy Ghost Regional Terminal
  - **Kano:** Sabon Gari Regional Terminal

### 2.2 Core Operations
- **Interstate Passenger Travel:** Customers search scheduled trips, choose their preferred seat, provide passenger manifest details, and purchase tickets.
- **Express Parcel Logistics:** Customers send packages between stations along the same vehicle routes. Each package receives a unique waybill tracking code.
- **KYC & Security Compliance:** The database enforces identity verification (National Identity Numbers / NIN and Driver's Licenses for drivers, passenger emergency contacts for Federal Road Safety Corps compliance, and recipient verification for package pickups).
- **Management Operations Dashboard:** Fleet managers track vehicle status, GPS positions, seat occupancy, and delivery milestones in real time.

---

## 3. Repository Structure & Naming Standard

Every file in this repository strictly follows the required academic naming pattern:  
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
├── portfolio-3-transactions-concurrency/         # ACID tests, isolation levels, row-level locking
├── portfolio-4-nosql/                            # Document store for GPS tracking and cargo telemetry
├── portfolio-5-distributed-cloud/                # Sharding, replication, and high-availability architecture
│
├── Ajeyomi_Adedoyin_20260520_LMS_Documentation.docx  # 2-3 page summary document for LMS submission
├── Ajeyomi_Adedoyin_20260520_README.md               # Main student portfolio overview
└── README.md                                         # GitHub landing page overview
```

---

## 4. Portfolio Modules Status

| Module | Title | Key Topics Covered | Status |
| :--- | :--- | :--- | :--- |
| **Portfolio 1** | [Database Design & Modelling](portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_README.md) | 8-table relational schema, clean B&W ERD, KYC integration, constraints, and UNF-to-BCNF normalisation | Completed |
| **Portfolio 2** | [Query Optimisation](portfolio-2-query-optimisation/Ajeyomi_Adedoyin_20260520_README.md) | Query execution plans (`EXPLAIN ANALYZE`), B-tree & composite indexes, 6.5x–12.8x speedup | Completed |
| **Portfolio 3** | Transactions & Concurrency | ACID compliance, row locking (`SELECT FOR UPDATE`), preventing double bookings | Scheduled |
| **Portfolio 4** | NoSQL Databases | Document data modelling, GPS telemetry tracking, JSON storage | Scheduled |
| **Portfolio 5** | Distributed & Cloud Databases | Regional sharding, database replication, and cloud failover | Scheduled |
