MIT 8103 ADVANCED DATABASE SYSTEMS
INDIVIDUAL PRACTICAL DATABASE PORTFOLIO

Name:          Adedoyin Ajeyomi
Student ID:    20260520
Programme:     Master of Information Technology (MIT)
Case study:    Adedoyin Mobility and Logistics
GitHub link:   https://github.com/SammyGIS/Ajeyomi_Adedoyin_20260520


1. MY CASE STUDY

Adedoyin Mobility and Logistics is a Nigerian transport company. It sells seats on buses and minivans between six cities (Lagos, Ibadan, Abuja, Benin City, Enugu and Kano) and it carries parcels between the same cities. It has 20 vehicles.

Who uses the database: ticket counter staff, station managers, drivers, fleet managers, finance staff and customers.

What it stores: stations, vehicles, drivers, customers, routes, trips, seat bookings and parcels. It also stores identity details (NIN numbers, driver licences, emergency contacts) because of road safety rules. A second database stores the GPS pings from the vehicles and the full history of each parcel.

What it must do: book a seat without ever selling it twice, track parcels, report revenue per route, report on driver work, and keep working when a server fails.

The data is 6 stations, 20 vehicles, 20 drivers, 500 customers, 10 routes, 1,200 trips, 8,000 bookings and 3,500 parcels. I made it with a Python script and the Faker library in the data folder. I used the same company in all five portfolios.


2. PORTFOLIO 1: DATABASE DESIGN

I designed 8 tables in PostgreSQL: stations, vehicles, drivers, customers, routes, trips, bookings and parcels. The tables are in third normal form and BCNF. The ER diagram uses Crow's Foot notation and is in black and white.

Rules in the database:
- A seat can be booked only once per trip.
- A NIN must have exactly 11 digits.
- A vehicle has between 7 and 18 seats.
- A trip cannot arrive before it leaves.
- Prices and weights must be more than zero.

I tested the rules in pgAdmin 4. For example, a customer with a 3 digit NIN is refused with the error "violates check constraint chk_customer_nin". The README for Portfolio 1 shows the normalisation steps with an example and has the screenshots.


3. PORTFOLIO 2: QUERIES AND SPEED

I wrote 4 business queries: revenue per route, weekly trips and vehicles on one route, parcels sent by one customer, and driver work for one month.

My real data is too small for PostgreSQL to need indexes, so I copied it 50 times in a separate test database (60,000 trips, 400,000 bookings, 175,000 parcels). I measured each query with EXPLAIN (ANALYZE, BUFFERS) before and after adding indexes. The results are real output from PostgreSQL 17.5:

  Revenue per route:      7.61 ms to 1.30 ms (5.8 times faster)
  Weekly trips on route:  5.36 ms to 0.10 ms (51 times faster)
  Parcels by customer:   20.41 ms to 0.31 ms (65 times faster)
  Driver work:            6.39 ms to 1.32 ms (4.8 times faster)

The plans changed from a full table scan to an index scan, and the pages read dropped, for example from 624 to 10 for the weekly query. The README for Portfolio 2 has the chart, the full plans and the steps to repeat it.


4. PORTFOLIO 3: TRANSACTIONS AND LOCKS

A transaction is a group of steps that is saved all together or not at all. I tested five things with a script that starts two real database sessions at the same time:

- Commit and rollback: a cancelled payment leaves no booking. A failing second statement undoes the whole transaction, including the first seat.
- Two customers, one seat, no lock: both saw the seat as free. The second one waited about 2 seconds and then got "duplicate key value violates unique constraint". Only the database rule saved the seat.
- The same case with a row lock (SELECT ... FOR UPDATE): the second customer waited 2.5 seconds, then saw the seat was taken and stopped without an error.
- Isolation levels: with Read Committed, a report total changed from 37,000 to 55,500 in the middle of the report. With Repeatable Read, it stayed at 55,500 until the report ended.
- Deadlock: two sessions took two vehicle locks in opposite order. PostgreSQL stopped one of them after 1.006 seconds with "deadlock detected". When both took the locks in the same order, there was no deadlock.

The results file is the real output with clock times.


5. PORTFOLIO 4: NOSQL (MONGODB)

GPS pings and parcel history fit a document database better than tables. I used MongoDB with two collections made from my SQL data: vehicle_telemetry (23,802 GPS pings from the real completed trips) and parcel_tracking (3,500 parcels, with all checkpoints inside each parcel document). They share keys with PostgreSQL (vehicle_id, trip_id, waybill_number).

What I did:
- Added validation rules. A parcel with the waybill "BAD-123" was refused.
- Measured 4 queries before and after indexes. For example, one vehicle's pings for one week went from reading 23,802 documents (60 ms) to reading 88 documents (0 ms).
- Used a 2dsphere index to find vehicles within 80 km of Abuja.
- Ran aggregation queries (parcel scans per station, a summary per corridor).
- Tested the TTL index on a small separate collection: 3 documents became 1 after 80 seconds.

Bookings and money stay in PostgreSQL. MongoDB keeps only the pings and parcel history. The README for Portfolio 4 has the Compass screenshots.


6. PORTFOLIO 5: DISTRIBUTED DATABASES

I did not use a paid cloud. I ran separate PostgreSQL servers side by side on my own computer. Each one has its own folder and port. All results are real output.

- Replication and failover: a primary and a standby with synchronous replication. The standby refuses writes. I crashed the primary on purpose and promoted the standby. It was ready after 258 ms and accepted its first write after 461 ms. All 1,000 committed rows were still there.
- Splitting by region: a 60,000 row trips table, normal and split into 4 regions. A query for one region read 704 pages (6.78 ms) on the normal table and only 64 pages (1.02 ms) on the split table.
- Two servers with postgres_fdw: North trips live on a second server. A North query is sent to it as a Foreign Scan. A South query stays on the main server.

The cloud design (servers in Lagos, Abuja and Kano, Patroni and etcd for automatic failover) is explained in the README as a plan. I did not run it.


7. MY REFLECTION

Design choices: I kept money and seats in PostgreSQL because they need strict rules, and I put GPS pings and parcel history in MongoDB because they change shape and arrive all the time. I split trips by region because most work is for one region at a time.

Challenges:
- I generated all of it myself with a Python script and the Faker library. It was hard to make fake data that looks real for Nigeria and also follows every database rule (11 digit NINs, unique phone numbers and plates, one booking per seat, correct dates and prices). I used my own lists of Nigerian names, stations and routes, and I fixed the data whenever the database refused it.
- My data was too small to show index gains. I solved it with a scaled copy in a separate database and I say this clearly in the README.
- Tests with two people at once need good timing. I had to change the delays in my script until the second session really collided with the first.
- MongoDB refused my own generated data twice, for a wrong number type and a fuel level above 100. Fixing it taught me how validation works.
- A real cloud failover cannot be shown on one computer, so I tested what I could and described the rest as a design.

What I learned: indexes and partitions make queries read much less data. A lock makes the second customer wait but protects the data. A synchronous copy is safe but slows writes. A document database is not a replacement for PostgreSQL. It is a second tool for different data.


8. AI USE DECLARATION

I used AI assistants (the Gemini chat app, and Claude) to help with ideas and planning, preparing the data, and writing, correcting and debugging code and errors.
I set up the software on my own computer, ran the scripts and tests, took the screenshots and checked the results, and I can explain all the work in this portfolio.


9. REFERENCES

PostgreSQL 17 documentation: table partitioning, https://www.postgresql.org/docs/17/ddl-partitioning.html
PostgreSQL 17 documentation: transaction isolation, https://www.postgresql.org/docs/17/transaction-iso.html
PostgreSQL 17 documentation: explicit locking, https://www.postgresql.org/docs/17/explicit-locking.html
PostgreSQL 17 documentation: log-shipping standby servers, https://www.postgresql.org/docs/17/warm-standby.html
PostgreSQL 17 documentation: postgres_fdw, https://www.postgresql.org/docs/17/postgres-fdw.html
MongoDB manual: indexes, https://www.mongodb.com/docs/manual/indexes/
MongoDB manual: geospatial 2dsphere indexes, https://www.mongodb.com/docs/manual/core/indexes/index-types/geospatial/2dsphere/
MongoDB manual: schema validation, https://www.mongodb.com/docs/manual/core/schema-validation/
MongoDB manual: TTL indexes, https://www.mongodb.com/docs/manual/core/index-ttl/
Tools: PostgreSQL 17.5, pgAdmin 4, MongoDB 9.0, mongosh, MongoDB Compass, Python 3 with the Faker and openpyxl libraries (data generation), Matplotlib (charts), PowerShell (test scripts).
Data: the data is not real company data. I generated it myself with the Python scripts in the data folder.
Course material: MIT 8103 Advanced Database Systems lecture notes and the assessment brief.


10. WHERE TO FIND MY WORK

The GitHub repository has one folder for each portfolio:
  portfolio-1-database-design
  portfolio-2-query-optimisation
  portfolio-3-transactions-concurrency
  portfolio-4-nosql
  portfolio-5-distributed-cloud
  data (the generated data and the scripts that make it)

Each portfolio folder has its own README with the steps to run it again, the SQL or JavaScript or PowerShell scripts, the real results files, and the screenshots and diagrams in an assets folder.
