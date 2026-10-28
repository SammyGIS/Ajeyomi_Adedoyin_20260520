# Portfolio 3: Transactions and Concurrency Control

**Student Name:** Adedoyin Ajeyomi  
**Student ID:** 20260520  
**Course:** MIT 8103 - Advanced Database Systems  
**Case Study:** Adedoyin Mobility and Logistics  
**Database Engine:** PostgreSQL 14+  

---

## 1. Introduction: What is a Database Transaction?

A **transaction** is a sequence of one or more database operations treated as a single, indivisible unit of work.

In a passenger transport and courier company like **Adedoyin Mobility and Logistics**, hundreds of passengers buy tickets and reserve seats at the same time across our 6 regional stations (Lagos, Ibadan, Abuja, Benin City, Enugu, Kano). 

If two passengers try to reserve the same seat simultaneously, or if a payment fails halfway through booking, the database must guarantee data accuracy without selling duplicate tickets.

---

## 2. The ACID Principles Explained

Every reliable relational database guarantees four properties known as **ACID**:

1. **Atomicity ("All or Nothing"):**  
   All steps of a booking must complete successfully (checking availability $\rightarrow$ debiting customer $\rightarrow$ recording ticket). If any step fails, the entire transaction is rolled back with `ROLLBACK`, leaving no partial changes.
2. **Consistency (Preserving Business Rules):**  
   The database starts in a valid state and ends in a valid state. For example, our unique constraint on `(trip_id, seat_number)` and check constraint on ticket prices are strictly enforced at all times.
3. **Isolation (Separation of Concurrent Work):**  
   Operations running at the same time do not interfere with each other or see intermediate, uncommitted changes.
4. **Durability (Permanent Storage):**  
   Once a transaction issues `COMMIT`, its changes are safely recorded on disk (via the Write-Ahead Log / WAL) and will not be lost even if the server crashes or loses power.

---

## 3. The Double-Booking Race Condition

When multiple users interact with the system simultaneously, standard SQL statements can cause a **Race Condition**:

```text
Time 08:00:01 — Passenger A checks Seat 4 on Trip 1. (Database says: "Vacant")
Time 08:00:02 — Passenger B checks Seat 4 on Trip 1. (Database says: "Vacant")
Time 08:00:03 — Passenger A pays and inserts booking for Seat 4.
Time 08:00:04 — Passenger B pays and attempts to insert booking for Seat 4.
```

Without concurrency control, either two customers receive the same seat (a critical business failure) or Passenger B loses their money when the database throws a duplicate key error after payment.

---

## 4. Concurrency Control with Row-Level Locking (`SELECT FOR UPDATE`)

To prevent this problem, we use **Pessimistic Row-Level Locking**:

```sql
SELECT trip_id, trip_status 
FROM trips 
WHERE trip_id = 2 
FOR UPDATE;
```

### How `FOR UPDATE` Works:
1. When Passenger A runs `SELECT ... FOR UPDATE`, PostgreSQL places an **Exclusive Row Lock** on the selected trip record.
2. When Passenger B tries to run the same query, Passenger B's session is put into a **wait state**.
3. Passenger A confirms the seat is free, inserts the booking, and runs `COMMIT`.
4. As soon as Passenger A commits, Passenger B unblocks, re-checks the seat, sees that Seat 4 is now marked as `Confirmed`, and is safely redirected to choose another seat.

---

## 5. PostgreSQL Transaction Isolation Levels

SQL standards define four isolation levels. PostgreSQL supports three:

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read | Typical Use Case |
| :--- | :---: | :---: | :---: | :--- |
| **Read Committed** (Default) | Prevented | Allowed | Allowed | Standard web browsing, general ticket searches |
| **Repeatable Read** | Prevented | **Prevented** | **Prevented** | Financial reporting, end-of-day revenue reconciliation |
| **Serializable** | Prevented | Prevented | Prevented | Strict bank ledger transfers, high-value asset auctions |

### Demonstration in Our Tests:
- In **Read Committed**, when our finance auditor ran `SELECT SUM(ticket_amount)` twice inside the same transaction, the total increased from **₦142,500.00** to **₦171,000.00** because another passenger booked a ticket in between.
- In **Repeatable Read**, the auditor's view was frozen at **₦171,000.00** throughout the report generation, completely ignoring concurrent inserts until the report finished.

---

## 6. Deadlocks and Resolution

A **deadlock** happens when two transactions each hold a lock that the other needs, creating an infinite circular wait:

```text
Session 1 holds Lock on Vehicle 1, requests Lock on Vehicle 2.
Session 2 holds Lock on Vehicle 2, requests Lock on Vehicle 1.
```

### How PostgreSQL Handles Deadlocks:
1. PostgreSQL runs a background deadlock detector that wakes up after `deadlock_timeout` (default: 1 second / 1000ms).
2. It breaks the cycle by automatically aborting one transaction with:  
   `ERROR: deadlock detected`.
3. The aborted transaction issues a `ROLLBACK`, allowing the surviving transaction to finish with `COMMIT`.

### Prevention Best Practice:
To avoid deadlocks, all application services must acquire resource locks in a **consistent global order** (e.g., always locking vehicle IDs in ascending order: Vehicle 1 before Vehicle 2).

---

## 7. How to Test Concurrency in pgAdmin 4 (Step-by-Step)

You do not need to use the terminal. Concurrency tests simulate two users acting at the same time, which is easily done in **pgAdmin 4** by opening **two separate Query Tool tabs**:

1. **Open Two Query Tool Tabs in pgAdmin 4:**
   - Launch pgAdmin 4 and connect to your database server.
   - In the left Browser tree, right-click the **`adedoyin_mobility`** database and select **Query Tool**. This is **Tab 1 (Customer A)**.
   - Right-click the **`adedoyin_mobility`** database a second time and select **Query Tool** again. This opens **Tab 2 (Customer B)**.
   - You now have two completely independent database sessions running side-by-side.

2. **Step-by-Step Row-Level Locking Test (`SELECT ... FOR UPDATE`):**
   - **In Tab 1 (Customer A):** Copy and run the lock query:
     ```sql
     BEGIN;
     SELECT trip_id, trip_status FROM trips WHERE trip_id = 2 FOR UPDATE;
     ```
     Press **F5** (Execute). Customer A has acquired an exclusive lock on Trip 2.
   - **In Tab 2 (Customer B):** Copy and run the concurrent booking attempt:
     ```sql
     BEGIN;
     SELECT trip_id, trip_status FROM trips WHERE trip_id = 2 FOR UPDATE;
     ```
     Press **F5** (Execute). Notice the spinning activity indicator in pgAdmin — Tab 2 is safely waiting for Customer A to finish!
   - **In Tab 1 (Customer A):** Complete Customer A's booking and release the lock:
     ```sql
     INSERT INTO bookings (trip_id, customer_id, seat_number, ticket_amount, booking_status, payment_reference)
     VALUES (2, 103, 5, 28500.00, 'Confirmed', 'PAY-TXN-SEAT5-WINNER');
     COMMIT;
     ```
     Press **F5**.
   - **Switch to Tab 2 (Customer B):** As soon as Tab 1 commits, Tab 2 immediately unblocks! When you check the seat status:
     ```sql
     SELECT seat_number, booking_status FROM bookings WHERE trip_id = 2 AND seat_number = 5;
     ```
     pgAdmin displays that Seat 5 is already `Confirmed` by Customer A.
   - **In Tab 2:** Safely cancel Customer B's transaction:
     ```sql
     ROLLBACK;
     ```

3. **View Full Test Outputs:**
   Open [Ajeyomi_Adedoyin_20260520_Concurrency_Test_Results.txt](Ajeyomi_Adedoyin_20260520_Concurrency_Test_Results.txt) to inspect the complete transcript logs for all 5 scenarios.

---

## 8. Visual Verification Evidence (Screenshots in `assets/`)

| Test Scenario | pgAdmin 4 Verification Screenshot |
| :--- | :--- |
| **ACID Commit & Rollback** | ![ACID Commit & Rollback in pgAdmin](assets/acid_commit_rollback.png) |
| **Row Locking (`SELECT FOR UPDATE`)** | ![Row Locking Wait State in pgAdmin](assets/concurrency_row_locking.png) |
| **Deadlock Detection Alert** | ![Deadlock Detected Error in pgAdmin](assets/deadlock_detected.png) |
