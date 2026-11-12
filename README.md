# Advanced Database Systems Portfolio

Student Name: Adedoyin Ajeyomi
Student ID: 20260520
Course: MIT 8103 - Advanced Database Systems
Programme: Master of Information Technology (MIT)
Case Study: Adedoyin Mobility and Logistics
GitHub: https://github.com/SammyGIS/Ajeyomi_Adedoyin_20260520

---

## 1. About this project
Adedoyin Mobility and Logistics is a Nigerian transport company. It sells seats on buses and minivans between Lagos, Ibadan, Abuja, Benin City, Enugu and Kano, and it carries parcels between the same cities. It has 20 vehicles and 6 stations.

The data is created using the faker libary, with Python scripts in the `data` folder: 500 customers, 1,200 trips, 8,000 bookings and 3,500 parcels.

For a short summary of the whole work, read `Ajeyomi_Adedoyin_README.txt`.

## 2. The five portfolios

Every result below is real output from my own PostgreSQL 17.5 and MongoDB 9.0.

1. [Portfolio 1: Database Design](portfolio-1-database-design/Ajeyomi_Adedoyin_20260520_README.md). 8 tables, an ER diagram in Crow's Foot symbols, rules for the data, and normalisation up to BCNF.
2. [Portfolio 2: Query Processing and Optimisation](portfolio-2-query-optimisation/Ajeyomi_Adedoyin_20260520_README.md). 4 queries timed before and after indexes on a bigger copy of the data. They became 4.8 to 65 times faster.
3. [Portfolio 3: Transactions and Concurrency](portfolio-3-transactions-concurrency/Ajeyomi_Adedoyin_20260520_README.md). Commit and rollback, a seat race with and without a lock, two isolation levels, and a real deadlock.
4. [Portfolio 4: NoSQL](portfolio-4-nosql/Ajeyomi_Adedoyin_20260520_README.md). A MongoDB database of 23,802 GPS location records and 3,500 parcels, made from the SQL data. Indexes cut the documents read from 23,802 to 88 in one query.
5. [Portfolio 5: Distributed and Cloud Databases](portfolio-5-distributed-cloud/Ajeyomi_Adedoyin_20260520_README.md). A live copy of the database that took over in 258 ms after a crash, trips split by region (704 pages down to 64), and two servers working together with postgres_fdw. The cloud plan is described but not run.

## 3. Files and folders

```text
Ajeyomi_Adedoyin_20260520/
│
├── portfolio-1-database-design/
│   ├── assets/                  ER diagram and pgAdmin screenshots
│   ├── Ajeyomi_Adedoyin_20260520_README.md
│   ├── Ajeyomi_Adedoyin_20260520_Schema.sql          the 8 tables and rules
│   ├── Ajeyomi_Adedoyin_20260520_Seed_Data.sql       data as plain SQL
│   └── Ajeyomi_Adedoyin_20260520_Copy_From_CSV.sql   loads the full data from CSV files
│
├── portfolio-2-query-optimisation/
│   ├── assets/                  chart and screenshots
│   ├── Ajeyomi_Adedoyin_20260520_README.md
│   ├── Ajeyomi_Adedoyin_20260520_Queries.sql         4 queries, baseline, indexes, plans
│   ├── Ajeyomi_Adedoyin_20260520_Benchmark_Scale_Up.sql   makes the bigger copy of the data
│   └── Ajeyomi_Adedoyin_20260520_Query_Execution_Plans.txt  the real output
│
├── portfolio-3-transactions-concurrency/
│   ├── assets/                  lock diagram and screenshot
│   ├── Ajeyomi_Adedoyin_20260520_README.md
│   ├── Ajeyomi_Adedoyin_20260520_Transactions.sql    commit, rollback and a failed statement
│   ├── Ajeyomi_Adedoyin_20260520_Run_Concurrency_Tests.ps1  runs the two-session tests
│   └── Ajeyomi_Adedoyin_20260520_Concurrency_Test_Results.txt  the real output
│
├── portfolio-4-nosql/
│   ├── assets/                  diagram and Compass screenshots
│   ├── Ajeyomi_Adedoyin_20260520_README.md
│   ├── Ajeyomi_Adedoyin_20260520_MongoDB_Queries.js  the MongoDB script
│   ├── Ajeyomi_Adedoyin_20260520_NoSQL_Model.json    the model with example documents
│   └── Ajeyomi_Adedoyin_20260520_NoSQL_Execution_Results.txt  the real output
│
├── portfolio-5-distributed-cloud/
│   ├── assets/                  overview diagram and chart
│   ├── Ajeyomi_Adedoyin_20260520_README.md
│   ├── Ajeyomi_Adedoyin_20260520_Run_Replication_Failover_Test.ps1  copy and failover test
│   ├── Ajeyomi_Adedoyin_20260520_Replication_Failover_Test_Results.txt
│   ├── Ajeyomi_Adedoyin_20260520_Run_Sharding_Test.ps1  region split and two-server test
│   └── Ajeyomi_Adedoyin_20260520_Sharding_Test_Results.txt
│
├── data/                        the data (CSV, Excel, JSON) and the Python scripts that make it
├── Ajeyomi_Adedoyin_README.txt  the short README for submission
├── Ajeyomi_Adedoyin_20260520_LMS_Documentation.docx
└── README.md
```

## 4. How to run the work

You need PostgreSQL 17, pgAdmin 4, MongoDB, mongosh and Python 3. Each portfolio README has its own steps. In short:

1. Portfolio 1: create the database `adedoyin_mobility` in pgAdmin 4, run the Schema file, then load the data.
2. Portfolio 2: build a separate test database and run the scale-up and queries scripts.
3. Portfolio 3: run `Run_Concurrency_Tests.ps1` in PowerShell.
4. Portfolio 4: run the MongoDB script with `mongosh --file`.
5. Portfolio 5: run the two PowerShell scripts. They use a temporary folder and do not touch the main database.

## 5. AI Use Declaration

I used AI assistants (the Gemini chat app, and Claude) to help with ideas and planning, preparing the data, writing, correcting and debugging code and errors, and writing and arranging my README files so they read well.

I set up the software on my own computer, ran the scripts and tests, took the screenshots and checked the results, and I can explain all the work in this portfolio.
