MIT 8103 ADVANCED DATABASE SYSTEMS
INDIVIDUAL PRACTICAL DATABASE PORTFOLIO

Name:          Adedoyin Ajeyomi
Student ID:    20260520
Programme:     Master of Information Technology (MIT)
Case study:    Adedoyin Mobility and Logistics
GitHub link:   https://github.com/SammyGIS/Ajeyomi_Adedoyin_20260520


1. MY CASE STUDY

Adedoyin Mobility and Logistics is a Nigerian transport company. It sells seats on buses and minivans between six cities (Lagos, Ibadan, Abuja, Benin City, Enugu and Kano) and it also carries parcels between the same cities. It has 20 vehicles.

Who uses the database: ticket counter staff, station managers, drivers, fleet managers, finance staff and customers.

What it keeps: stations, vehicles, drivers, customers, routes, trips, seat bookings and parcels. It also keeps identity details (NIN, driver licence and emergency contact) because of road safety rules. A second database keeps the GPS location of each vehicle during a trip and the full history of each parcel.

What it must do: book a seat without selling it twice, track parcels, show money earned on each route, show how much work each driver did, and keep working when a server fails.

The data is 6 stations, 20 vehicles, 20 drivers, 500 customers, 10 routes, 1,200 trips, 8,000 bookings and 3,500 parcels. I made it with a Python script and the Faker library in the data folder. I used the same company in all five portfolios.


2. PORTFOLIO 1: DATABASE DESIGN

I designed 8 tables in PostgreSQL: stations, vehicles, drivers, customers, routes, trips, bookings and parcels. The tables are in third normal form and BCNF. The ER diagram uses Crow's Foot symbols and it is in black and white.

Rules in the database:
- A seat can be booked only once on a trip.
- A NIN must be exactly 11 digits.
- A vehicle has between 7 and 18 seats.
- A trip cannot arrive before it leaves.
- Prices and weights must be more than zero.

I tested the rules in pgAdmin 4. For example, a customer with a 3 digit NIN is refused with the error "violates check constraint chk_customer_nin". The README for Portfolio 1 shows the normalisation steps with an example, and it has the screenshots.


3. PORTFOLIO 2: QUERIES AND SPEED

I wrote 4 queries for the business: money earned on each route, trips on one route for one week, parcels sent by one customer, and work done by each driver in one month.

My data is too small for PostgreSQL to need indexes, so I copied it 50 times in a separate test database (60,000 trips, 400,000 bookings and 175,000 parcels). I timed each query before and after adding indexes, using EXPLAIN (ANALYZE, BUFFERS). The results are real output from PostgreSQL 17.5:

  Money on each route:       7.61 ms to 1.30 ms (5.8 times faster)
  Trips on a route, 1 week:  5.36 ms to 0.10 ms (51 times faster)
  Parcels of one customer:  20.41 ms to 0.31 ms (65 times faster)
  Driver work:               6.39 ms to 1.32 ms (4.8 times faster)

Before the index, PostgreSQL read the whole table. After the index, it went straight to the rows it needed. The pages read dropped too, for example from 624 to 10 for the weekly trips query. The README for Portfolio 2 has the chart, the full plans and the steps to run it again.


4. PORTFOLIO 3: TRANSACTIONS AND LOCKS

A transaction is a group of steps that is saved all together or not at all. I tested five things with a script that starts two real database sessions at the same time:

- Commit and rollback: when a payment is cancelled, no booking is left. When the second step fails, the first step is also undone.
- Two customers, one seat, no lock: both saw the seat as free. The second one waited about 2 seconds and then got the error "duplicate key value violates unique constraint". The seat was saved only by the rule in the database.
- The same case with a row lock (SELECT ... FOR UPDATE): the second customer waited 2.5 seconds, then saw the seat was taken and stopped without an error.
- Isolation levels: with Read Committed, the total in a report changed from 37,000 to 55,500 while the report was still running. With Repeatable Read, it stayed at 55,500 until the report ended.
- Deadlock: two sessions took two vehicle locks in opposite order. PostgreSQL stopped one of them after 1.006 seconds with "deadlock detected". When both took the locks in the same order, there was no deadlock.

The results file is the real output, with the time of each step.


5. PORTFOLIO 4: NOSQL (MONGODB)

GPS locations and parcel history fit better in a document database, which keeps data as documents and not as tables. I used MongoDB with two collections made from my SQL data: vehicle_telemetry (23,802 GPS location records from the real completed trips) and parcel_tracking (3,500 parcels, with all the checkpoints inside each parcel). They share keys with PostgreSQL (vehicle_id, trip_id and waybill_number).

What I did:
- Added rules for the data. A parcel with the waybill "BAD-123" was refused.
- Timed 4 queries before and after adding indexes. For example, the GPS locations of one vehicle for one week went from reading 23,802 documents (61 ms) to reading 88 documents (0 ms).
- Used a map index (2dsphere) to find vehicles within 80 km of Abuja.
- Ran grouping queries (parcel scans at each station, and a summary for each route).
- Tested the TTL index on a small separate collection. It had 3 documents, and after 80 seconds only 1 was left.

Bookings and money stay in PostgreSQL. MongoDB keeps only the GPS locations and parcel history. The README for Portfolio 4 has the Compass screenshots.


6. PORTFOLIO 5: DISTRIBUTED DATABASES

I did not use a paid cloud service. I ran separate PostgreSQL servers side by side on my own computer, each with its own folder and port. All the results are real output.

- Copy and failover: a main server and a standby server that keeps a live copy. A write is only confirmed after the copy has it too. The standby does not allow writes. I crashed the main server on purpose and made the standby the new main server. It was ready after 258 ms and took its first write after 461 ms. All 1,000 saved rows were still there.
- Splitting by region: a trips table of 60,000 rows, once as a normal table and once split into 4 regions. A query for one region read 704 pages (6.78 ms) on the normal table and only 64 pages (1.02 ms) on the split table.
- Two servers with postgres_fdw: the North trips live on a second server. A query for the North is sent to that server. A query for the South stays on the main server.

The cloud plan (servers in Lagos, Abuja and Kano, with Patroni and etcd to switch servers by themselves) is explained in the README. I did not run it.


7. MY REFLECTION

Design choices: I kept money and seats in PostgreSQL because they need strict rules. I put GPS locations and parcel history in MongoDB because the data keeps coming and its shape can change. I split trips by region because most work is for one region at a time.

Challenges:
- I generated all of it myself with a Python script and the Faker library. It was hard to make fake data that looks real for Nigeria and also follows every database rule (11 digit NINs, unique phone numbers and plates, one booking per seat, correct dates and prices). I used my own lists of Nigerian names, stations and routes, and I fixed the data whenever the database refused it.
- My data was too small to show the gain from indexes. I solved it with a bigger copy in a separate database, and I say this clearly in the README.
- Tests with two people at the same time need good timing. I changed the waiting times in my script until the second session really met the first one.
- MongoDB refused my own data twice, once for a wrong number type and once for a fuel level above 100. Fixing it taught me how the rules for data work.
- A real cloud failover cannot be shown on one computer, so I tested what I could and described the rest as a plan.

What I learned: indexes and splitting a table make a query read much less data. A lock makes the second customer wait, but it protects the data. A live copy is safe, but it makes writes slower. A document database does not replace PostgreSQL. It is a second tool for different data.


8. AI USE DECLARATION

I used AI assistants (the Gemini chat app, and Claude) to help with ideas and planning, preparing the data, writing, correcting and debugging code and errors, and writing and arranging my README files so they read well.

I set up the software on my own computer, ran the scripts and tests, took the screenshots and checked the results, and I can explain all the work in this portfolio.


9. REFERENCES

PostgreSQL 17 documentation: table partitioning, https://www.postgresql.org/docs/17/ddl-partitioning.html
PostgreSQL 17 documentation: transaction isolation, https://www.postgresql.org/docs/17/transaction-iso.html
PostgreSQL 17 documentation: explicit locking, https://www.postgresql.org/docs/17/explicit-locking.html
PostgreSQL 17 documentation: standby servers, https://www.postgresql.org/docs/17/warm-standby.html
PostgreSQL 17 documentation: postgres_fdw, https://www.postgresql.org/docs/17/postgres-fdw.html
MongoDB manual: indexes, https://www.mongodb.com/docs/manual/indexes/
MongoDB manual: 2dsphere indexes, https://www.mongodb.com/docs/manual/core/indexes/index-types/geospatial/2dsphere/
MongoDB manual: schema validation, https://www.mongodb.com/docs/manual/core/schema-validation/
MongoDB manual: TTL indexes, https://www.mongodb.com/docs/manual/core/index-ttl/
Tools: PostgreSQL 17.5, pgAdmin 4, MongoDB 9.0, mongosh, MongoDB Compass, Python 3 with the Faker and openpyxl libraries (data), Matplotlib (charts), PowerShell (test scripts).
Data: the data is not real company data. I generated it myself with the Python scripts in the data folder.
Course material: MIT 8103 Advanced Database Systems lecture notes and the assessment brief.


10. WHERE TO FIND MY WORK

The GitHub repository has one folder for each portfolio:
  portfolio-1-database-design
  portfolio-2-query-optimisation
  portfolio-3-transactions-concurrency
  portfolio-4-nosql
  portfolio-5-distributed-cloud
  data (the data and the scripts that make it)

Each portfolio folder has its own README with the steps to run it again, the scripts, the real results files, and the screenshots and diagrams in an assets folder.
