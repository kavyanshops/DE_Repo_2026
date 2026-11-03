<<<<<<< HEAD
# Zomato Food Delivery Database: DBMS Project

**Course:** Database Management Systems · **Year:** B.Tech 2nd year · **Team size:** 4
**Database:** PostgreSQL 15 or newer · **Final submission:** Mon 23 Nov 2026
**Topics used:** Data types & constraints · Keys & relationships · Normalization · Query execution plans · Indexing · Query optimization · VACUUM/ANALYZE · Partitioning & sharding

## Files in this folder

| Path | What it is |
|------|------------|
| `README.md` | This project brief |
| `seed_data.zip` | 11 CSV files (150,000 orders): the only input for Phase 2. Unzip it to get `seed_data/` |
| `queries/workload_30.sql` | The 30 queries for Phase 3 (do not edit) |
| `benchmarks/run_benchmark.sh` | Timing script: 3 runs per query, average, raw plans saved |
| `CHECKPOINTS.md` | Checkpoint dates and the files each one needs (DE and AP repos) |

**Getting started:** **clone this repository and push it into your team's DE repo** (the DE repo you submitted in the form); the steps are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Keep the structure shown in [Repository structure](#repository-structure-submit-exactly-this). Unzip `seed_data.zip` inside your project folder, but don't commit the CSV files. Deadlines are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Then begin with Phase 1.

---

## Team details (fill in before you start)

| Role | Name | Enrollment No. | GitHub Username |
|------|------|----------------|-----------------|
| Group Lead | Kavyansh Saini | 2501010216 | kavyanshops
| Member 2 | Ansh Verma |2501010069 | ansh-v10|
| Member 3 | Aditya Singh | 2501010027 | opg857609-bot|
| Member 4 | Rajat Soni| 2501010367 | rajatsoni367|

**Team No.:** T0102 · **Section:** B · **Repository URL:** https://github.com/kavyanshops/persistent-world-engine-AP_Repo.git

---

## How this project works

| Phase | What you do | You submit | Counts toward | Marks |
|-------|-------------|------------|---------------|------:|
| 1 | Understand the problem statements | `docs/01_problem_understanding.md` | Query Execution | 2 |
| 2 | Work out the database schema **from the seed data** and load it | `sql/01_schema.sql`, `sql/02_load_data.sql`, `docs/02_schema_design.md` | Query Execution | 5 |
| 3 | Run the **30 given SQL queries** and record their execution time | `docs/03_baseline_timings.md`, `benchmarks/results/baseline/` | Query Execution | 3 |
| 4 | Optimize the queries and record the new times | `sql/05_indexes.sql`, `sql/06_optimized_queries.sql`, `docs/04_optimization_report.md`, `benchmarks/results/optimized/` | Code Optimization | 16 |
| 5 | Scalability test on the **large dataset** (given later by faculty) and final report | `docs/05_scalability_report.md`, `benchmarks/results/large/` | Code Optimization | 14 |
| | **Total** | | | **40** |

---

## Phase 1: Problem statements

Zomato connects hungry customers with restaurants and delivery partners. A customer opens the app, browses restaurants in their **locality**, adds dishes to the cart, applies a coupon and pays (UPI, card, wallet or cash on delivery). The restaurant accepts and prepares the order, a delivery partner picks it up, and after delivery the customer may leave a review. Gold members get free delivery. You have joined the database team for Zomato's operations in **10 Indian cities**, each divided into 10 localities.

The current database was put together quickly by an earlier team. It has **no documented schema** (only data exports survive), and the product teams are complaining:

| # | Problem reported | Team | Related queries |
|---|------------------|------|-----------------|
| P1 | "The **home feed and restaurant pages** load slowly at lunch and dinner peaks." | Customer app | R01, R03, R25 |
| P2 | "**Dish search** ("paneer", "biryani") is too slow to type-ahead." | Search | R02 |
| P3 | "Customers complain that **order history and bills** take seconds to open." | Customer app | R04, R24 |
| P4 | "Restaurant owners want **today's orders and dish-wise sales** instantly on the partner app." | Restaurant partners | R06, R07, R08, W03 |
| P5 | "**Dispatch screens** (unassigned orders, kitchen delays) must refresh every few seconds." | Dispatch / Ops | R05, R12, W01, W02 |
| P6 | "The fleet team's **idle-partner list came back empty**, which can't be right." | Fleet | R11, R13 |
| P7 | "**Payment failures** and suspicious customers need near-real-time reports." | Payments / Risk | R16, R17 |
| P8 | "**Gold, coupon and growth** reports time out." | Gold / Marketing | R14, R15, R20, R21, W05 |
| P9 | "Support needs to find **late deliveries and angry reviews** fast." | Support | R10, R18 |
| P10 | "Leadership dashboards (delivery times, heatmaps, restaurant health) are slow, and order volume will grow **20×**." | Ops / Leadership | R09, R19, R22, R23, W04 |

**Your job:**
1. Rebuild a correct, well-constrained schema from the data exports (Phase 2).
2. Measure how the 30 most important queries perform today (Phase 3).
3. Make them fast **without changing their results** (Phase 4).
4. Prove the database will survive next year's growth (Phase 5).

**Deliverable for Phase 1** (`docs/01_problem_understanding.md`, at most 1 page):
- For each problem P1–P10, write in your own words what the business needs and which **stakeholder** is affected (customer, restaurant partner, delivery partner, dispatch/ops, Gold team, marketing, payments/risk, support, admin).
- Classify each problem as **customer-facing / real-time** or **reporting / analytics**. This decides your performance targets later.
- List any assumptions you make.

---

## Phase 2: Work out the schema from the seed data

You receive **`seed_data.zip`**. Unzip it to get a folder **`seed_data/`** with 11 CSV files, a real export of the production data:

| File | Rows | What it contains |
|------|-----:|------------------|
| `cities.csv` | 10 | Cities where Zomato delivers |
| `localities.csv` | 100 | Neighbourhoods inside each city (with pincode) |
| `customers.csv` | 25,000 | People who order food (some are Gold members) |
| `restaurants.csv` | 2,500 | Restaurants listed on Zomato |
| `menu_items.csv` | 50,000 | Dishes on each restaurant's menu |
| `delivery_partners.csv` | 2,000 | Delivery partners (riders) |
| `coupons.csv` | 30 | Discount coupon codes |
| `orders.csv` | 150,000 | Every order placed from 1 Jan 2025 to 30 Jun 2026 |
| `order_items.csv` | 375,000 | Dishes inside each order |
| `payments.csv` | 137,378 | Payment attempts (an order can have more than one) |
| `reviews.csv` | 39,186 | Customer reviews of delivered orders |

The first line of every file is the header (column names). Here are the headers and the first rows of each file:

**cities.csv**
```
city_id,city_name,state
1,Bengaluru,Karnataka
2,Mumbai,Maharashtra
```

**localities.csv**
```
locality_id,city_id,locality_name,pincode
1,1,Koramangala,560007
2,1,Indiranagar,560014
```

**customers.csv**
```
customer_id,full_name,email,phone,city_id,signup_date,is_gold_member,gold_expires_on,is_active
1,Vivaan Sharma,Vivaan.Sharma1@Gmail.com,9000000001,2,2023-05-20,f,,t
2,Aditya Sharma,Aditya.Sharma2@Gmail.com,9000000002,4,2024-09-10,t,2027-05-04,t
```

**restaurants.csv**
```
restaurant_id,name,locality_id,cuisines,avg_cost_for_two,rating,rating_count,opens_at,closes_at,is_pure_veg,status,onboarded_on
1,Royal House,26,"{Desserts,Mughlai}",300,3.7,815,10:00:00,22:00:00,f,OPEN,2024-01-28
2,Urban House,78,"{""Fast Food"",""North Indian""}",300,4.9,973,11:00:00,22:00:00,f,TEMPORARILY_CLOSED,2024-07-29
```

**menu_items.csv**
```
item_id,restaurant_id,item_name,category,price,is_veg,is_bestseller,is_available
1,1,Dal Makhani,Main Course,251.00,t,t,t
2,1,Chole Masala,Main Course,291.00,t,t,t
```

**delivery_partners.csv**
```
partner_id,full_name,phone,city_id,vehicle_type,joined_on,rating,status
1,Ananya Gupta,8000000001,4,SCOOTER,2022-08-04,4.7,ACTIVE
2,Kavya Khan,8000000002,1,BICYCLE,2021-06-01,4.1,ACTIVE
```

**coupons.csv**
```
coupon_code,discount_pct,max_discount,min_order_value,valid_from,valid_to
DINNER150,20,150.00,299.00,2024-12-01,2026-12-31
DINNER250,20,100.00,199.00,2024-12-01,2026-12-31
```

**orders.csv**
```
order_id,customer_id,restaurant_id,partner_id,coupon_code,placed_at,accepted_at,picked_up_at,delivered_at,distance_km,item_total,delivery_fee,discount,total_amount,status
1,9492,1113,1438,,2025-01-01 00:00:00+05:30,2025-01-01 00:03:03+05:30,2025-01-01 00:25:03+05:30,2025-01-01 01:19:03+05:30,9.0,1116.00,45.00,0.00,1161.00,DELIVERED
2,21129,541,1927,,2025-01-01 00:05:14+05:30,2025-01-01 00:07:29+05:30,2025-01-01 00:33:29+05:30,2025-01-01 01:05:29+05:30,3.5,1726.00,25.00,0.00,1751.00,DELIVERED
```

**order_items.csv**
```
order_id,item_id,quantity,unit_price
1,22241,3,111.00
1,22242,3,142.00
```

**payments.csv**
```
payment_id,order_id,amount,method,payment_status,attempted_at
1,1,1161.00,COD,SUCCESS,2025-01-01 01:19:03+05:30
2,2,1751.00,UPI,SUCCESS,2025-01-01 00:05:54+05:30
```

**reviews.csv**
```
review_id,order_id,customer_id,restaurant_id,food_rating,delivery_rating,review_text,created_at
1,1,9492,1113,5,4,Delivery was late by 30 minutes,2025-01-01 02:37:29+05:30
2,2,21129,541,5,5,"Loved the biryani, will order again",2025-01-01 01:31:29+05:30
```

Open the files yourself (a spreadsheet, `head`, or `SELECT` after a quick load into a scratch table) and study the data carefully. **Nobody will give you the CREATE TABLE statements.** Working them out *is* the task.

### 2.1 What you must identify (for every table)
1. **Table name and column names.** Use exactly the file names and CSV headers. The 30 queries depend on them.
2. **Data type** of every column. Choose the *right* type, not just `TEXT` everywhere. Think about money, timestamps with a time-zone offset, yes/no columns, small whole numbers, decimals and short codes.
3. **Primary key.** Is it one column, or a combination? (Look closely at `order_items`, and at whether `payments.order_id` can repeat.)
4. **Foreign keys.** Which column points to which table? What should happen **ON DELETE** (CASCADE, RESTRICT or SET NULL), and why?
5. **NOT NULL vs NULL.** Some columns are empty in some rows. Find out **when** and **why**, and decide which columns must never be empty. Look at how `partner_id`, `accepted_at`, `picked_up_at` and `delivered_at` depend on the order `status`, and at `gold_expires_on`.
6. **UNIQUE** columns (natural candidate keys such as emails, phone numbers, codes and handles).
7. **CHECK constraints.** Write at least **12** that the data obeys and the business needs. Look for allowed values (statuses, categories, vehicle types, payment methods), ranges (ratings, distance), time order (placed → accepted → picked up → delivered), money rules (e.g. how `total_amount` relates to the other amount columns) and rules that depend on `status` or `method`.
8. **Relationships and cardinalities** (1:1, 1:N, M:N). Draw the **ER diagram** (image + Mermaid code).
9. **Normal form.** Show that each table is in 3NF/BCNF (list its functional dependencies). Point out any column that is *derived or redundant* (hint: `orders.total_amount`; `restaurants.rating` and `rating_count` vs `reviews`; `restaurants.is_pure_veg` vs the menu; `reviews.customer_id`/`restaurant_id` vs `orders`) and say whether keeping it is justified.

### 2.2 Rules for your schema
- Create every table in a schema named **`zomato`**: `CREATE SCHEMA zomato;` and `SET search_path TO zomato;`
- In this phase create **only constraints**: PK, FK, UNIQUE, NOT NULL, CHECK. **Do not create any other index yet.** (PostgreSQL automatically indexes PRIMARY KEY and UNIQUE columns; that's allowed. Note which indexes exist.) Your baseline in Phase 3 must reflect a database *without* tuning.
- Your constraints must accept **all** rows of the seed data. If a load fails, either your constraint is wrong or you found a data problem. Explain which in your design doc.

### 2.3 Load the data
Write `sql/02_load_data.sql` using `\copy`, loading tables in the right order (parents before children):

```sql
SET search_path TO zomato;
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
-- ... the other tables, in an order that satisfies your foreign keys
ANALYZE;
```

Then verify the row counts match the table above, and run at least **3 integrity checks** of your own (e.g. "every order line's dish belongs to the order's restaurant", "every delivered order has exactly one successful payment", "a pure-veg restaurant has no non-veg dish"). Paste the results into `docs/02_schema_design.md`.

### Phase 2 deliverables
- `sql/01_schema.sql`: runs top-to-bottom on an empty database without errors
- `sql/02_load_data.sql`: loads all 11 files without errors
- `docs/02_schema_design.md`: data dictionary (table · column · type · constraint · *why*), ER diagram, FDs and normal form per table, integrity-check results, and every data problem you found

---

## Phase 3: Run the 30 queries and record the time

The file **`queries/workload_30.sql`** contains **30 queries**: 25 reads (`R01`–`R25`) and 5 writes (`W01`–`W05`). They're also listed in the [Appendix](#appendix-the-30-queries). **Do not modify them.** If a query fails, your schema doesn't match the seed data; fix the schema, not the query.

### 3.1 How to measure (everyone must use the same method)
- Run each query with `EXPLAIN (ANALYZE, BUFFERS)` and read the **`Execution Time`** at the bottom.
- Run each query **3 times** and record the **average** of the three `Execution Time` values. Keep all three runs in the raw plan file.
- Write queries (`W01`–`W05`) must be measured inside `BEGIN; … ROLLBACK;` so the data does not change.
- Close other heavy applications while measuring, and use the **same laptop** for Phase 3 and Phase 4.

The helper script does all of this for you:
```bash
./benchmarks/run_benchmark.sh <your_database> baseline
# → benchmarks/results/baseline/summary.csv   (avg, median, min, max, scan types)
# → benchmarks/results/baseline/R01.txt …     (full plans of all 3 runs)
```
> ⚠️ One of the 30 queries takes **over a second** on the seed data. That's intentional. Let it finish, and don't skip it.

### 3.2 Deliverable: the timing table
In `docs/03_baseline_timings.md`, fill this table for **all 30** queries:

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Home feed: open restaurants in Koramangala, best rated first | READ | | | | |
| R02: Dish search: available "paneer" dishes in Bengaluru | READ | | | | |
| R03: Restaurant page: the menu of one restaurant, grouped by category | READ | | | | |
| R04: "Your orders": a customer's last 10 orders with restaurant names | READ | | | | |
| R05: Kitchen-delay alert: orders stuck in PREPARING for over 40 minutes (checked at 23:59 on 30 Jun 2026) | READ | | | | |
| R06: Restaurant partner app: all orders received by restaurant 217 on 15 June 2026 | READ | | | | |
| R07: Restaurant partner app: units sold per dish in May 2026 | READ | | | | |
| R08: Bestseller badges: top 3 dishes of every Pune restaurant in the last 30 days | READ | | | | |
| R09: Ops dashboard: average delivery time (minutes) per city per month in 2026 | READ | | | | |
| R10: Customer support: deliveries in June 2026 that took more than 60 minutes | READ | | | | |
| R11: Delivery partner app: this week's earnings (delivery fees) for partner 150 | READ | | | | |
| R12: Dispatch: orders still waiting for a delivery partner, oldest first | READ | | | | |
| R13: Fleet team: active Bengaluru partners who have not been assigned any order since 25 June 2026 | READ | | | | |
| R14: Gold team: Gold members whose membership expires before July 2026 but who ordered in June 2026 | READ | | | | |
| R15: Marketing: coupon effectiveness (orders, total discount, average bill) | READ | | | | |
| R16: Payments team: failed payment attempts per method in the last 7 days | READ | | | | |
| R17: Risk team: customers with 2 or more failed payment attempts (all time) | READ | | | | |
| R18: Review moderation: newest reviews that complain about cold food or late delivery | READ | | | | |
| R19: Restaurant health report for Bengaluru: last order time, delivered orders and average food rating | READ | | | | |
| R20: Growth: top 20 customers in Mumbai by total spend on delivered orders | READ | | | | |
| R21: Growth: share of customers in each city who ordered at least twice in May 2026 | READ | | | | |
| R22: Ops heatmap: Bengaluru orders by weekday and hour, last 8 weeks | READ | | | | |
| R23: Admin panel: "All orders", newest first, page 4,001 (25 rows per page) | READ | | | | |
| R24: Bill page: one order with its items, restaurant and successful payment | READ | | | | |
| R25: Cuisine filter: open Chinese restaurants in Pune | READ | | | | |
| W01: Customer app: place a new order (header row) | WRITE | | | | |
| W02: Dispatch: assign partner 150 to the oldest accepted order that has no partner | WRITE | | | | |
| W03: Restaurant partner app: desserts sold out, so hide them | WRITE | | | | |
| W04: Nightly job: recompute every restaurant's rating from its reviews | WRITE | | | | |
| W05: Nightly job: end Gold membership for customers whose plan has expired | WRITE | | | | |
| **Total (sum of all 30)** | | | | | |

Below the table, add for each query the **scan type** from the plan (Seq Scan, Index Scan, …) and one line on **why** it is slow or fast.

---

## Phase 4: Optimize the queries

Make the queries faster. **The results must stay the same** (same rows; order matters only where the query has an `ORDER BY`).

### 4.1 Techniques you may use
| Technique | Example |
|-----------|---------|
| B-tree index (single / composite) | the right column **order** matters: equality columns first, then range/sort |
| Partial index | index only the rows a query needs (e.g. a rare status) |
| Covering index | `INCLUDE (...)` so the table is never visited (Index Only Scan) |
| Expression index | index the exact expression used in `WHERE` |
| GIN index | for `ILIKE '%text%'` (extension `pg_trgm`), arrays or full-text search |
| BRIN index | for huge tables stored in time order |
| Query rewrite | sargable date ranges instead of functions on columns; `NOT EXISTS` instead of `NOT IN`; joins instead of correlated subqueries; keyset instead of `OFFSET` pagination; `UNION ALL` instead of `OR` across columns |
| VACUUM / ANALYZE | fresh statistics and visibility maps |
| Summary table / materialized view | for heavy reports that don't need live data (state how it's refreshed) |

**Not allowed:** changing the data, deleting rows, changing PostgreSQL server settings to hide the problem (e.g. huge `work_mem`, `enable_seqscan = off`), or caching results outside the database.

### 4.2 How to work
1. Put every index in `sql/05_indexes.sql`, each with a comment: **which queries it serves and why this type and column order**.
2. Put rewritten queries in `sql/06_optimized_queries.sql`. Copy `queries/workload_30.sql` and change **only** the queries you rewrite, keeping the `-- @R01` markers.
3. **Prove the results are unchanged** for every rewritten query (compare row counts, plus a checksum or an `EXCEPT` query). Put the proof in your report.
4. Benchmark again with the same method:
```bash
./benchmarks/run_benchmark.sh <your_database> optimized 5 sql/06_optimized_queries.sql
```
> 🔎 **Read the results, not just the timings.** At least one of the 30 original queries returns a **wrong answer** because of a subtle SQL rule about NULLs. Find it, explain it, and fix it. This is worth marks.

### 4.3 Deliverable: the optimization table
In `docs/04_optimization_report.md`:

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|-------|------------:|---------------------------|----------------------|-----------:|------------:|:------------:|
| R04 | | e.g. Seq Scan on 150k orders | e.g. composite index `(customer_id, placed_at DESC)` | | e.g. 99.2% (130×) | ✅ |
| … all 30 … | | | | | | |
| **Total** | | | | | | |

Improvement % = (before − after) / before × 100

Also include:
- **Before/after `EXPLAIN` plans** for your 5 biggest improvements
- **Write overhead:** which write queries got **slower** because of your indexes, by how much, and whether that's acceptable
- **Index storage:** the size of each index you created (`pg_relation_size`) compared with its table
- **Queries you could not speed up**, and why (an honest "this query must read most of the table" earns marks)

---

## Phase 5: Scalability report (large dataset round)

Your optimizations worked on 150,000 orders. Next year the business expects **20× the volume**.

By **Thu 19 Nov 2026**, faculty will release **`large_data.zip`**: the same 11 CSV files with about **20× the rows** (≈ 3,000,000 orders, ≈ 7,500,000 order items, ≈ 500,000 customers, ≈ 50,000 restaurants). Until then, work on the design part of the report.

### 5.1 What to do with the large dataset
1. Create a new database. Run **your** `01_schema.sql`, load `large_data/` with your load script (change the folder name only), then run **your** `05_indexes.sql` and `ANALYZE`.
2. Run your **optimized** queries (`sql/06_optimized_queries.sql`). **Do not run the original 30 on the large data.** Some of them could run for a very long time.
   - R23 pages with `OFFSET`; if you replaced it with keyset pagination, explain how the "last seen" value is chosen for the large data.
3. Record the times and compare with your Phase 4 results on the seed data.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what you changed |
|-------|------------------------:|------------------------:|----------------------:|:-------------:|--------------------------|
| R01 | | | | | |
| … all 30 … | | | | | |

### 5.2 Performance targets on the large dataset
| Query group | Queries | Target (average of 3 runs) |
|-------------|---------|----------------:|
| Real-time / customer-facing | R01, R03, R04, R05, R06, R11, R12, R24, W01, W02, W03 | **under 5 ms** |
| Interactive search and ops | R02, R10, R13, R16, R18, R25, R14 | **under 250 ms** |
| Reports and analytics | R07, R08, R09, R15, R17, R19, R20, R21, R22, R23 | **under 5,000 ms** |
| Batch jobs | W04, W05 | **under 2,000 ms** |

If a query misses its target, **find out why from the plan and fix it.** A query that was fast on the seed data can become slow on large data for reasons that only appear at scale. Show the before/after plans for every fix.

### 5.3 Deliverable: `docs/05_scalability_report.md`
1. **Results table** (above), with every target met or explained.
2. **Growth analysis.** Group your queries by how their time grew when the data grew 20×:
   - *stayed about the same* (why? e.g. index lookups grow with log n)
   - *grew about 20×* (why? e.g. they read a fixed *share* of the table)
   - *grew more than 20×* (why, and what you did about it)
3. **What broke at scale** and how you fixed it (plans before/after).
4. **Storage:** total database size, table vs index size, on seed and large data.
5. **Architecture for 100×:** explain with numbers from your own measurements:
   - **Partitioning:** which table, by which column (RANGE / LIST / HASH), and why. Write the DDL for `orders`, show partition pruning with `EXPLAIN`, and note the primary-key rule for partitioned tables.
   - **Sharding:** Would you shard by city, by restaurant, or by customer? An order touches one customer, one restaurant and one partner. Which queries become cross-shard, and how would you handle them?
   - **Read replicas and caching:** which of the 30 queries you would send to a replica or cache, and which must hit the primary.
   - **Maintenance:** VACUUM/autovacuum settings for `orders`, archiving old data, refreshing summary tables.
6. **Conclusion:** is your database ready for next year? What are the remaining risks?

---

## Repository structure (submit exactly this)

```
zomato-dbms-<team-no>/
├── README.md                          # team table, how to run, headline numbers
├── team.json                          # group lead, members, enrollment numbers
├── docs/
│   ├── 01_problem_understanding.md
│   ├── 02_schema_design.md
│   ├── 03_baseline_timings.md
│   ├── 04_optimization_report.md
│   └── 05_scalability_report.md
├── diagrams/
│   └── er_diagram.png
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_data.sql
│   ├── 05_indexes.sql
│   ├── 06_optimized_queries.sql
│   └── 08_partitioning.sql
├── queries/
│   └── workload_30.sql                # given; do not edit
└── benchmarks/
    ├── run_benchmark.sh               # given
    └── results/
        ├── baseline/                  # Phase 3: summary.csv + raw plans
        ├── optimized/                 # Phase 4
        └── large/                     # Phase 5
```

`team.json`:
```json
{
  "team_number": "",
  "group_lead": { "name": "", "enrollment_no": "", "github": "" },
  "members": [
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" }
  ],
  "postgres_version": "",
  "laptop_used_for_benchmarks": ""
}
```

**Do not commit the CSV files** (`seed_data/`, `large_data/`); add them to `.gitignore`. They are too large and we already have them.

---

## Timeline

| Due | Work | Checkpoint |
|-----|------|------------|
| Tue 3 Nov 2026 | Clone this repo into your team's DE repo, add members, commit `team.json` | **CP0** Setup |
| Mon 16 Nov 2026 | Phase 1 + Phase 2 (schema, load, ER, data dictionary) | **CP1** Schema loads all seed data with no errors |
| Tue 17 Nov 2026 | Phase 3 (baseline, 3 runs, average) + start Phase 4 | **CP2** Baseline table for all 30 queries committed |
| Thu 19 Nov 2026 | Phase 4 (indexes, rewrites, wrong-result query) | **CP3** Optimization table committed |
| Mon 23 Nov 2026 | Phase 5 on the large dataset + final report | **CP4 Final submission:** last commit on the default branch |
| Wed 25 – Thu 26 Nov 2026 | Individual analysis, in class time | **CP5** Individual analysis |

Full list of files per checkpoint, including the AP repo: [`CHECKPOINTS.md`](CHECKPOINTS.md).

---

## Evaluation (40 marks)

These 40 marks are the DE part of the project: **Query Execution (10)** and **Code Optimization (30)**.
The AP project (20) and your Individual analysis (40) make up the rest of the 100.

| Phase | Criteria | Marks |
|-------|----------|------:|
| | **Query Execution** | **10** |
| 1 | Problems understood, stakeholders and query groups correctly identified | 2 |
| 2 | Correct data types (1), keys and foreign keys with justified delete rules (1), ≥12 meaningful CHECK / NOT NULL / UNIQUE constraints (1), ER diagram + normal-form analysis (1), data loads cleanly + integrity checks (1) | 5 |
| 3 | All 30 queries measured with the required method: 3 runs, average (1), raw plans committed (1), scan type and reason for each query (1) | 3 |
| | **Code Optimization** | **30** |
| 4 | Speed-up achieved with appropriate techniques (6), every index justified (3), results proven unchanged (2), wrong-result query found and explained (2), write overhead and index storage reported (3) | 16 |
| 5 | Large-dataset results with all targets met or explained (4), growth analysis (3), scale-only problems found and fixed (3), partitioning DDL + sharding/replica design backed by your numbers (4) | 14 |
| | **Total** | **40** |

**Integrity rules**
- Every number in your reports must match the raw plan files in `benchmarks/results/`. Copied or invented timings make the whole phase score 0.
- Every member must have commits; the commit history is checked.
- You may use AI tools to learn, but you must be able to explain every index and rewrite in your individual analysis.

---

## Appendix: the 30 queries

These are identical to `queries/workload_30.sql`. Use the file, not copy-paste from this page.

**R01: Home feed: open restaurants in Koramangala, best rated first**
```sql
SELECT r.restaurant_id, r.name, r.cuisines, r.avg_cost_for_two, r.rating
FROM restaurants r
JOIN localities l ON l.locality_id = r.locality_id
WHERE l.locality_name = 'Koramangala'
  AND r.status = 'OPEN'
ORDER BY r.rating DESC NULLS LAST
LIMIT 20;
```

**R02: Dish search: available "paneer" dishes in Bengaluru**
```sql
SELECT m.item_id, m.item_name, m.price, r.name AS restaurant
FROM menu_items m
JOIN restaurants r ON r.restaurant_id = m.restaurant_id
JOIN localities l  ON l.locality_id   = r.locality_id
WHERE l.city_id = 1
  AND m.is_available
  AND m.item_name ILIKE '%paneer%'
ORDER BY m.price
LIMIT 50;
```

**R03: Restaurant page: the menu of one restaurant, grouped by category**
```sql
SELECT category, item_name, price, is_veg, is_bestseller
FROM menu_items
WHERE restaurant_id = 217 AND is_available
ORDER BY category, is_bestseller DESC, item_name;
```

**R04: "Your orders": a customer's last 10 orders with restaurant names**
```sql
SELECT o.order_id, r.name AS restaurant, o.status, o.total_amount, o.placed_at
FROM orders o
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
WHERE o.customer_id = 1042
ORDER BY o.placed_at DESC
LIMIT 10;
```

**R05: Kitchen-delay alert: orders stuck in PREPARING for over 40 minutes (checked at 23:59 on 30 Jun 2026)**
```sql
SELECT order_id, restaurant_id, accepted_at
FROM orders
WHERE status = 'PREPARING'
  AND accepted_at < TIMESTAMPTZ '2026-06-30 23:59:00+05:30' - interval '40 minutes'
ORDER BY accepted_at;
```

**R06: Restaurant partner app: all orders received by restaurant 217 on 15 June 2026**
```sql
SELECT order_id, status, item_total, placed_at
FROM orders
WHERE restaurant_id = 217
  AND DATE(placed_at) = '2026-06-15'
ORDER BY placed_at;
```

**R07: Restaurant partner app: units sold per dish in May 2026**
```sql
SELECT m.item_name, sum(oi.quantity) AS units, sum(oi.quantity * oi.unit_price) AS sales
FROM order_items oi
JOIN orders o     ON o.order_id = oi.order_id
JOIN menu_items m ON m.item_id  = oi.item_id
WHERE o.restaurant_id = 217
  AND o.status = 'DELIVERED'
  AND o.placed_at >= '2026-05-01' AND o.placed_at < '2026-06-01'
GROUP BY m.item_name
ORDER BY units DESC;
```

**R08: Bestseller badges: top 3 dishes of every Pune restaurant in the last 30 days**
```sql
SELECT *
FROM (
    SELECT o.restaurant_id, oi.item_id, sum(oi.quantity) AS units,
           RANK() OVER (PARTITION BY o.restaurant_id ORDER BY sum(oi.quantity) DESC) AS rnk
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN restaurants r  ON r.restaurant_id = o.restaurant_id
    JOIN localities l   ON l.locality_id = r.locality_id
    WHERE l.city_id = 6
      AND o.status = 'DELIVERED'
      AND o.placed_at >= '2026-06-01'
    GROUP BY o.restaurant_id, oi.item_id
) t
WHERE rnk <= 3
ORDER BY restaurant_id, rnk;
```

**R09: Ops dashboard: average delivery time (minutes) per city per month in 2026**
```sql
SELECT l.city_id, date_trunc('month', o.placed_at) AS month,
       round(avg(EXTRACT(EPOCH FROM (o.delivered_at - o.placed_at)) / 60), 1) AS avg_minutes
FROM orders o
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
JOIN localities l  ON l.locality_id   = r.locality_id
WHERE o.status = 'DELIVERED'
  AND EXTRACT(YEAR FROM o.placed_at) = 2026
GROUP BY 1, 2
ORDER BY 1, 2;
```

**R10: Customer support: deliveries in June 2026 that took more than 60 minutes**
```sql
SELECT order_id, customer_id, restaurant_id, placed_at, delivered_at
FROM orders
WHERE delivered_at - placed_at > interval '60 minutes'
  AND placed_at >= '2026-06-01' AND placed_at < '2026-07-01'
ORDER BY delivered_at - placed_at DESC
LIMIT 100;
```

**R11: Delivery partner app: this week's earnings (delivery fees) for partner 150**
```sql
SELECT count(*) AS deliveries, sum(delivery_fee) AS fees_earned
FROM orders
WHERE partner_id = 150
  AND status = 'DELIVERED'
  AND placed_at >= '2026-06-22' AND placed_at < '2026-06-29';
```

**R12: Dispatch: orders still waiting for a delivery partner, oldest first**
```sql
SELECT o.order_id, o.restaurant_id, o.status, o.placed_at
FROM orders o
WHERE o.partner_id IS NULL
  AND o.status IN ('PLACED', 'ACCEPTED')
ORDER BY o.placed_at
LIMIT 50;
```

**R13: Fleet team: active Bengaluru partners who have not been assigned any order since 25 June 2026**
```sql
SELECT p.partner_id, p.full_name, p.phone
FROM delivery_partners p
WHERE p.city_id = 1
  AND p.status = 'ACTIVE'
  AND p.partner_id NOT IN (SELECT o.partner_id FROM orders o WHERE o.placed_at >= '2026-06-25');
```

**R14: Gold team: Gold members whose membership expires before July 2026 but who ordered in June 2026**
```sql
SELECT c.customer_id, c.full_name, c.gold_expires_on
FROM customers c
WHERE c.is_gold_member
  AND c.gold_expires_on < '2026-07-01'
  AND EXISTS (SELECT 1 FROM orders o
              WHERE o.customer_id = c.customer_id
                AND o.placed_at >= '2026-06-01' AND o.placed_at < '2026-07-01');
```

**R15: Marketing: coupon effectiveness (orders, total discount, average bill)**
```sql
SELECT c.coupon_code, c.discount_pct, count(o.order_id) AS orders,
       coalesce(sum(o.discount), 0) AS total_discount, round(avg(o.total_amount), 2) AS avg_bill
FROM coupons c
LEFT JOIN orders o ON o.coupon_code = c.coupon_code AND o.status = 'DELIVERED'
GROUP BY c.coupon_code, c.discount_pct
ORDER BY orders DESC;
```

**R16: Payments team: failed payment attempts per method in the last 7 days**
```sql
SELECT method, count(*) AS failed_attempts
FROM payments
WHERE payment_status = 'FAILED'
  AND attempted_at >= '2026-06-24'
GROUP BY method
ORDER BY failed_attempts DESC;
```

**R17: Risk team: customers with 2 or more failed payment attempts (all time)**
```sql
SELECT o.customer_id, count(*) AS failed_attempts
FROM payments p
JOIN orders o ON o.order_id = p.order_id
WHERE p.payment_status = 'FAILED'
GROUP BY o.customer_id
HAVING count(*) >= 2
ORDER BY failed_attempts DESC, o.customer_id;
```

**R18: Review moderation: newest reviews that complain about cold food or late delivery**
```sql
SELECT review_id, restaurant_id, food_rating, review_text, created_at
FROM reviews
WHERE review_text ILIKE '%cold%' OR review_text ILIKE '%late%'
ORDER BY created_at DESC
LIMIT 50;
```

**R19: Restaurant health report for Bengaluru: last order time, delivered orders and average food rating**
```sql
SELECT r.restaurant_id, r.name,
       (SELECT max(o.placed_at) FROM orders o WHERE o.restaurant_id = r.restaurant_id) AS last_order_at,
       (SELECT count(*) FROM orders o WHERE o.restaurant_id = r.restaurant_id AND o.status = 'DELIVERED') AS delivered_orders,
       (SELECT round(avg(v.food_rating), 2) FROM reviews v WHERE v.restaurant_id = r.restaurant_id) AS avg_food_rating
FROM restaurants r
JOIN localities l ON l.locality_id = r.locality_id
WHERE l.city_id = 1
ORDER BY last_order_at DESC NULLS LAST;
```

**R20: Growth: top 20 customers in Mumbai by total spend on delivered orders**
```sql
SELECT c.customer_id, c.full_name, count(*) AS orders, sum(o.total_amount) AS lifetime_spend
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE c.city_id = 2 AND o.status = 'DELIVERED'
GROUP BY c.customer_id, c.full_name
ORDER BY lifetime_spend DESC
LIMIT 20;
```

**R21: Growth: share of customers in each city who ordered at least twice in May 2026**
```sql
WITH may AS (
    SELECT customer_id, count(*) AS n
    FROM orders
    WHERE placed_at >= '2026-05-01' AND placed_at < '2026-06-01'
    GROUP BY customer_id
)
SELECT c.city_id,
       count(*) AS ordering_customers,
       count(*) FILTER (WHERE may.n >= 2) AS repeat_customers,
       round(100.0 * count(*) FILTER (WHERE may.n >= 2) / count(*), 1) AS repeat_pct
FROM may
JOIN customers c ON c.customer_id = may.customer_id
GROUP BY c.city_id
ORDER BY c.city_id;
```

**R22: Ops heatmap: Bengaluru orders by weekday and hour, last 8 weeks**
```sql
SELECT EXTRACT(ISODOW FROM o.placed_at) AS weekday, EXTRACT(HOUR FROM o.placed_at) AS hour, count(*) AS orders
FROM orders o
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
JOIN localities l  ON l.locality_id   = r.locality_id
WHERE l.city_id = 1
  AND o.placed_at >= TIMESTAMPTZ '2026-07-01 00:00:00+05:30' - interval '8 weeks'
GROUP BY 1, 2
ORDER BY 1, 2;
```

**R23: Admin panel: "All orders", newest first, page 4,001 (25 rows per page)**
```sql
SELECT order_id, customer_id, restaurant_id, status, total_amount, placed_at
FROM orders
ORDER BY placed_at DESC
OFFSET 100000
LIMIT 25;
```

**R24: Bill page: one order with its items, restaurant and successful payment**
```sql
SELECT o.order_id, o.placed_at, r.name AS restaurant, m.item_name, oi.quantity, oi.unit_price,
       o.total_amount, p.method
FROM orders o
JOIN restaurants r  ON r.restaurant_id = o.restaurant_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN menu_items m   ON m.item_id = oi.item_id
LEFT JOIN payments p ON p.order_id = o.order_id AND p.payment_status = 'SUCCESS'
WHERE o.order_id = 123457;
```

**R25: Cuisine filter: open Chinese restaurants in Pune**
```sql
SELECT r.restaurant_id, r.name, r.cuisines, r.rating
FROM restaurants r
JOIN localities l ON l.locality_id = r.locality_id
WHERE l.city_id = 6
  AND r.status = 'OPEN'
  AND 'Chinese' = ANY (r.cuisines)
ORDER BY r.rating DESC NULLS LAST;
```

**W01: Customer app: place a new order (header row)**
```sql
INSERT INTO orders (order_id, customer_id, restaurant_id, placed_at, distance_km,
                    item_total, delivery_fee, discount, total_amount, status)
VALUES (90000001, 1042, 217, '2026-07-01 13:05:00+05:30', 3.2, 540.00, 25.00, 0.00, 565.00, 'PLACED');
```

**W02: Dispatch: assign partner 150 to the oldest accepted order that has no partner**
```sql
UPDATE orders
SET partner_id = 150, status = 'PREPARING'
WHERE order_id = (SELECT order_id FROM orders
                  WHERE partner_id IS NULL AND status = 'ACCEPTED'
                  ORDER BY placed_at
                  LIMIT 1);
```

**W03: Restaurant partner app: desserts sold out, so hide them**
```sql
UPDATE menu_items
SET is_available = FALSE
WHERE restaurant_id = 217 AND category = 'Desserts';
```

**W04: Nightly job: recompute every restaurant's rating from its reviews**
```sql
UPDATE restaurants r
SET rating = s.avg_rating, rating_count = s.n
FROM (SELECT restaurant_id, round(avg(food_rating), 1) AS avg_rating, count(*) AS n
      FROM reviews GROUP BY restaurant_id) s
WHERE s.restaurant_id = r.restaurant_id;
```

**W05: Nightly job: end Gold membership for customers whose plan has expired**
```sql
UPDATE customers
SET is_gold_member = FALSE
WHERE is_gold_member
  AND gold_expires_on < '2026-07-01';
```
