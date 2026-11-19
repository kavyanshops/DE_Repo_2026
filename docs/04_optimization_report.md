# Query Optimization Report (Phase 4)

Database: PostgreSQL 18.6 · Dataset: 150,000 orders (seed data) · Date: 19 Nov 2026

---

## 1. Executive Summary

In Phase 4, the database was optimized using a combination of targeted composite B-tree indexes, partial indexes, covering indexes (`INCLUDE`), GIN trigram indexes (`pg_trgm`), and query rewrites (sargable date ranges, subquery unnesting, and anti-join corrections).

- **Total Baseline Execution Time:** **5,572.916 ms** (~5.57 s)
- **Total Optimized Execution Time:** **163.093 ms** (~0.16 s)
- **Overall Speedup:** **34.2×** (**97.07% runtime reduction**)
- **Critical Correctness Fix:** Identified and resolved a silent NULL-handling bug in **R13** (`NOT IN` returning 0 rows), restoring expected results.

---

## 2. All 30 Queries Optimization Table

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Speedup | Same result? |
|---|---:|---|---|---:|---:|---:|:---:|
| **R01** | 0.498 | Seq Scan on restaurants & localities | Composite covering index on `restaurants(locality_id, status, rating DESC)` | 0.362 | 27.3% | 1.4× | ✅ |
| **R02** | 18.428 | Seq Scan on 50k menu items with ILIKE | GIN trigram index `idx_menu_items_paneer_trgm` | 9.733 | 47.2% | 1.9× | ✅ |
| **R03** | 1.943 | Full Seq Scan on menu_items for single restaurant | Covering Index Only Scan `idx_menu_items_restaurant_available` | 0.092 | 95.3% | 21.1× | ✅ |
| **R04** | 5.366 | Seq Scan on 150k orders for customer history | Covering Index Only Scan `idx_orders_customer_placed_at` | 0.252 | 95.3% | 21.3× | ✅ |
| **R05** | 7.515 | Seq Scan on 150k orders filtering rare 'PREPARING' | Partial B-tree index `idx_orders_preparing_accepted` | 0.069 | 99.1% | 108.9× | ✅ |
| **R06** | 4.860 | Seq Scan on orders; non-sargable `DATE(placed_at)` | Sargable range rewrite + B-tree `(restaurant_id, placed_at)` | 0.054 | 98.9% | 90.0× | ✅ |
| **R07** | 6.756 | Seq Scan on orders filtering restaurant and date | Partial B-tree index `idx_orders_restaurant_delivered_placed` | 0.208 | 96.9% | 32.5× | ✅ |
| **R08** | 7.546 | Multi-table joins with full order scans | Date-ordered index scan on `orders(placed_at DESC)` | 5.351 | 29.1% | 1.4× | ✅ |
| **R09** | 24.933 | Seq Scan on orders; non-sargable `EXTRACT(YEAR)` | Sargable range rewrite + date index scan | 29.194 | -17.1% | 0.9× | ✅ |
| **R10** | 5.667 | Seq Scan on orders evaluating delivery duration | Expression index `(((delivered_at - placed_at)) DESC, placed_at)` | 0.120 | 97.9% | 47.2× | ✅ |
| **R11** | 6.462 | Seq Scan on 150k orders for partner earnings | Covering Index Only Scan `idx_orders_partner_delivered_placed` | 0.027 | 99.6% | 239.3× | ✅ |
| **R12** | 8.621 | Seq Scan on 150k orders for dispatch queue | Partial index `idx_orders_dispatch_queue` (16 kB) | 0.024 | 99.7% | 359.2× | ✅ |
| **R13** | 6.849 | 3-valued NULL bug in `NOT IN` returned 0 rows | Rewrite to `NOT EXISTS` + index `idx_delivery_partners_city_active` | 0.421 | 93.9% | 16.3× | ⚠️ *Fixed* |
| **R14** | 8.312 | Correlated subquery scanning all orders | Partial index `idx_customers_gold_expires` + orders index | 2.390 | 71.2% | 3.5× | ✅ |
| **R15** | 15.702 | Full scan on 150k orders for coupon aggregation | Partial covering index `idx_orders_coupon_delivered` | 9.080 | 42.2% | 1.7× | ✅ |
| **R16** | 4.653 | Seq Scan on 137k payments for failed attempts | Partial Index Only Scan `idx_payments_failed_method_attempted` | 0.135 | 97.1% | 34.5× | ✅ |
| **R17** | 17.185 | Full scan on payments and orders table | Partial Index Only Scan `idx_payments_failed_order` on order_id | 17.950 | -4.5% | 1.0× | ✅ |
| **R18** | 13.293 | Seq Scan on 39k reviews with dual ILIKE | GIN trigram index `idx_reviews_trgm_complaints` | 2.339 | 82.4% | 5.7× | ✅ |
| **R19** | 5267.856 | 3 correlated subqueries executed 250× (>85M rows) | Rewrite to CTE pre-aggregations + LEFT JOINs | 14.398 | 99.7% | 365.9× | ✅ |
| **R20** | 26.847 | Hash join over 150k orders and 25k customers | Composite index on `orders(customer_id, placed_at)` | 20.334 | 24.3% | 1.3× | ✅ |
| **R21** | 11.767 | Full table scan for May 2026 orders CTE | Index Scan on `orders(placed_at DESC)` | 4.509 | 61.7% | 2.6× | ✅ |
| **R22** | 16.090 | Seq Scan on orders and multi-table joins | Index Only Scan `idx_orders_restaurant_placed_date` | 2.266 | 85.9% | 7.1× | ✅ |
| **R23** | 38.931 | Large OFFSET scan walking 100k rows | Fast Index Scan on `idx_orders_placed_at_desc` | 10.460 | 73.1% | 3.7× | ✅ |
| **R24** | 5.640 | Missing FK index on payments forcing 137k seq scan | Partial Index Only Scan `idx_payments_order_success` | 0.074 | 98.7% | 76.2× | ✅ |
| **R25** | 0.324 | Unindexed array containment filter | GIN index `idx_restaurants_cuisines_gin` | 0.313 | 3.4% | 1.0× | ✅ |
| **W01** | 0.884 | Single-row insert into orders table | Direct insert with minimal overhead | 0.725 | 18.0% | 1.2× | ✅ |
| **W02** | 8.761 | Subquery Seq Scan finding oldest unassigned order | Subquery accelerated via `idx_orders_dispatch_queue` | 0.677 | 92.3% | 12.9× | ✅ |
| **W03** | 1.868 | Seq Scan on menu_items for category update | Index Scan via `idx_menu_items_restaurant_available` | 0.507 | 72.9% | 3.7× | ✅ |
| **W04** | 13.334 | Updates rating across all 2,500 restaurants | Index on reviews; write overhead on restaurant indexes | 22.500 | -68.7% | 0.6× | ✅ |
| **W05** | 16.025 | Seq Scan on 25k customers for expired Gold | Bitmap Index Scan on `idx_customers_gold_expires` | 8.529 | 46.8% | 1.9× | ✅ |
| **Total** | **5572.916** | | | **163.093** | **97.07%** | **34.2×** | |

---

## 3. Investigation of the Wrong-Result Query (R13)

### The Problem
Problem statement **P6** reported: *"The fleet team's idle-partner list came back empty, which can't be right."*

The original query in `queries/workload_30.sql` was:
```sql
SELECT p.partner_id, p.full_name, p.phone
FROM delivery_partners p
WHERE p.city_id = 1
  AND p.status = 'ACTIVE'
  AND p.partner_id NOT IN (SELECT o.partner_id FROM orders o WHERE o.placed_at >= '2026-06-25');
```

When run against the database, this query returned **0 rows**.

### Root Cause: SQL Three-Valued Logic and NULLs
In SQL, the expression `x NOT IN (val1, val2, ...)` expands logically to:
`x <> val1 AND x <> val2 AND ...`

In the `orders` table, unassigned orders have `partner_id IS NULL`. When the subquery `SELECT o.partner_id FROM orders WHERE o.placed_at >= '2026-06-25'` executes, it includes `NULL` values in the result set. 

Comparing any value to `NULL` yields `UNKNOWN`:
`p.partner_id <> NULL` $\rightarrow$ `UNKNOWN`

Since `TRUE AND UNKNOWN` is `UNKNOWN`, the entire `WHERE` clause evaluates to `UNKNOWN` (falsy) for **every single delivery partner**. Consequently, all active partners were discarded, incorrectly indicating that zero partners were idle.

### The Fix and Proof
We rewrote the query using `NOT EXISTS`, which relies on two-valued existence checks rather than equality against NULL:

```sql
SELECT p.partner_id, p.full_name, p.phone
FROM delivery_partners p
WHERE p.city_id = 1
  AND p.status = 'ACTIVE'
  AND NOT EXISTS (
      SELECT 1 FROM orders o
      WHERE o.partner_id = p.partner_id
        AND o.placed_at >= '2026-06-25'
  );
```

**Result:**
- Original query returned: **0 rows** (wrong)
- Corrected query returned: **129 rows** (correctly identifying all 129 active partners who received no orders since June 25th)
- Execution time improved from **6.849 ms** to **0.421 ms** (**16.3× speedup**).

---

## 4. Top 5 Query Improvements (Before & After Plans)

### 1. R19: Restaurant Health Report for Bengaluru
- **Baseline Time:** 5,267.856 ms
- **Optimized Time:** 14.398 ms
- **Speedup:** **365.9× (99.7% faster)**

#### Before Plan (Baseline)
```
Sort  (cost=462947.25..462947.88 rows=250 width=80) (actual time=4900.660..4900.670 rows=400 loops=1)
  ->  Hash Join  (cost=2.25..462937.20 rows=250 width=80)
        ->  Seq Scan on restaurants r
        ->  Hash  (cost=1.12..1.12 rows=10 width=4)
              ->  Seq Scan on localities l (Filter: city_id = 1)
        SubPlan 1: Aggregate (max(o.placed_at))
          ->  Seq Scan on orders o (Filter: restaurant_id = r.restaurant_id)
        SubPlan 2: Aggregate (count(*))
          ->  Seq Scan on orders o (Filter: (restaurant_id = r.restaurant_id) AND (status = 'DELIVERED'))
        SubPlan 3: Aggregate (avg(v.food_rating))
          ->  Seq Scan on reviews v (Filter: restaurant_id = r.restaurant_id)
Planning Time: 0.284 ms | Execution Time: 4900.660 ms
```

#### After Plan (Optimized)
```
Sort  (cost=1125.40..1126.40 rows=400 width=76) (actual time=14.350..14.365 rows=400 loops=1)
  CTE b_rest
    ->  Hash Join on restaurants and localities (Filter: city_id = 1)
  CTE ord_stats
    ->  HashAggregate on orders (Filter: restaurant_id IN b_rest)
  CTE rev_stats
    ->  GroupAggregate using idx_reviews_restaurant_food_rating on reviews
  ->  Hash Left Join b_rest with ord_stats and rev_stats
Planning Time: 1.150 ms | Execution Time: 14.398 ms
```

---

### 2. R12: Oldest Unassigned Orders in Dispatch Queue
- **Baseline Time:** 8.621 ms
- **Optimized Time:** 0.024 ms
- **Speedup:** **359.2× (99.7% faster)**

#### Before Plan (Baseline)
```
Limit  (cost=3920.00..3920.12 rows=50 width=28) (actual time=8.435..8.439 rows=50 loops=1)
  ->  Sort  (cost=3920.00..3920.45 rows=180 width=28) (actual time=8.433..8.436 rows=50 loops=1)
        Sort Key: placed_at
        ->  Seq Scan on orders o  (cost=0.00..3913.00 rows=180 width=28)
              Filter: ((partner_id IS NULL) AND (status = ANY ('{PLACED,ACCEPTED}')))
              Rows Removed by Filter: 149820
Planning Time: 0.120 ms | Execution Time: 8.621 ms
```

#### After Plan (Optimized)
```
Limit  (cost=0.14..2.85 rows=50 width=28) (actual time=0.015..0.022 rows=50 loops=1)
  ->  Index Scan using idx_orders_dispatch_queue on orders o (cost=0.14..9.80 rows=180 width=28)
Planning Time: 0.110 ms | Execution Time: 0.024 ms
```

---

### 3. R11: Partner Weekly Earnings
- **Baseline Time:** 6.462 ms
- **Optimized Time:** 0.027 ms
- **Speedup:** **239.3× (99.6% faster)**

#### Before Plan (Baseline)
```
Aggregate  (cost=3913.00..3913.01 rows=1 width=40) (actual time=6.460..6.461 rows=1 loops=1)
  ->  Seq Scan on orders  (cost=0.00..3913.00 rows=1 width=6)
        Filter: ((partner_id = 150) AND (status = 'DELIVERED') AND (placed_at >= '2026-06-22') AND (placed_at < '2026-06-29'))
        Rows Removed by Filter: 149995
Execution Time: 6.462 ms
```

#### After Plan (Optimized)
```
Aggregate  (cost=8.30..8.31 rows=1 width=40) (actual time=0.025..0.026 rows=1 loops=1)
  ->  Index Only Scan using idx_orders_partner_delivered_placed on orders (cost=0.29..8.30 rows=5 width=6)
        Index Cond: ((partner_id = 150) AND (placed_at >= '2026-06-22') AND (placed_at < '2026-06-29'))
        Heap Fetches: 0
Execution Time: 0.027 ms
```

---

### 4. R05: Kitchen-Delay Alerts
- **Baseline Time:** 7.515 ms
- **Optimized Time:** 0.069 ms
- **Speedup:** **108.9× (99.1% faster)**

#### Before Plan (Baseline)
```
Sort  (cost=3913.50..3913.55 rows=20 width=24) (actual time=7.510..7.512 rows=22 loops=1)
  Sort Key: accepted_at
  ->  Seq Scan on orders  (cost=0.00..3913.00 rows=20 width=24)
        Filter: ((status = 'PREPARING') AND (accepted_at < '2026-06-30 23:19:00+05:30'))
        Rows Removed by Filter: 149978
Execution Time: 7.515 ms
```

#### After Plan (Optimized)
```
Index Scan using idx_orders_preparing_accepted on orders  (cost=0.14..8.50 rows=22 width=24)
  Index Cond: (accepted_at < '2026-06-30 23:19:00+05:30')
Execution Time: 0.069 ms
```

---

### 5. R06: Restaurant Partner Daily Orders
- **Baseline Time:** 4.860 ms
- **Optimized Time:** 0.054 ms
- **Speedup:** **90.0× (98.9% faster)**

#### Before Plan (Baseline)
```
Sort  (cost=3913.30..3913.35 rows=20 width=30) (actual time=4.855..4.857 rows=18 loops=1)
  Sort Key: placed_at
  ->  Seq Scan on orders  (cost=0.00..3913.00 rows=20 width=30)
        Filter: ((restaurant_id = 217) AND (date(placed_at) = '2026-06-15'))
Execution Time: 4.860 ms
```

#### After Plan (Optimized)
```
Index Scan using idx_orders_restaurant_placed_date on orders (cost=0.29..8.50 rows=18 width=30)
  Index Cond: ((restaurant_id = 217) AND (placed_at >= '2026-06-15 00:00:00+05:30') AND (placed_at < '2026-06-16 00:00:00+05:30'))
Execution Time: 0.054 ms
```

---

## 5. Result Equivalence Proofs for Rewritten Queries

Every rewritten query was tested for relational equivalence using SQL `EXCEPT ALL`:

| Query | Original Construct | Rewritten Construct | `EXCEPT ALL` Diff Count | Result Match? |
|---|---|---|:---:|:---:|
| **R06** | `DATE(placed_at) = '2026-06-15'` | `placed_at >= '...' AND placed_at < '...'` | 0 rows diff | ✅ Identical |
| **R09** | `EXTRACT(YEAR FROM o.placed_at) = 2026` | `placed_at >= '2026-01-01' AND < '2027-01-01'` | 0 rows diff | ✅ Identical |
| **R13** | `NOT IN (SELECT partner_id ...)` | `NOT EXISTS (SELECT 1 ...)` | — | ⚠️ Bug Fixed (0 $\rightarrow$ 129 rows) |
| **R19** | 3 Correlated scalar subqueries | CTE pre-aggregations + `LEFT JOIN` | 0 rows diff (400 vs 400 rows) | ✅ Identical |

---

## 6. Write Overhead Analysis

Secondary indexes accelerate `SELECT` queries by providing fast search paths, but introduce maintenance cost during `INSERT`, `UPDATE`, and `DELETE` operations as every affected index page must be updated.

| Write Query | Operation | Baseline (ms) | Optimized (ms) | Overhead / Impact | Acceptable? |
|---|---|---:|---:|---|:---:|
| **W01** | `INSERT INTO orders` | 0.884 | 0.725 | Minimal variation (-18.0%) | ✅ Yes |
| **W02** | `UPDATE orders (assign partner)` | 8.761 | 0.677 | **+92.3% faster** (index accelerates lookup subquery) | ✅ Yes |
| **W03** | `UPDATE menu_items (hide desserts)` | 1.868 | 0.507 | **+72.9% faster** (index accelerates WHERE filter) | ✅ Yes |
| **W04** | `UPDATE restaurants (nightly ratings)` | 13.334 | 22.500 | +9.16 ms (+68.7% overhead due to updating indexed rating columns) | ✅ Yes (batch nightly job) |
| **W05** | `UPDATE customers (expire Gold)` | 16.025 | 8.529 | **+46.8% faster** (partial index speeds up candidate search) | ✅ Yes |

**Conclusion:** 4 out of 5 write queries actually became **faster** because the `WHERE` clauses benefited from index scans more than the tuple update cost. The single query with increased duration (**W04**) is an offline nightly batch job where a 9 ms increase is completely negligible compared to the massive real-time gains for customer-facing queries.

---

## 7. Index Storage Analysis

Calculated using `pg_relation_size()` against the baseline tables:

| Schema | Table Name | Index Name | Index Size | Table Size | % of Table |
|---|---|---|---:|---:|---:|
| `zomato` | `orders` | `idx_orders_customer_placed_at` | 8,856 kB | 18 MB | 48.4% |
| `zomato` | `orders` | `idx_orders_delivery_duration` | 5,200 kB | 18 MB | 28.4% |
| `zomato` | `orders` | `idx_orders_partner_delivered_placed` | 5,192 kB | 18 MB | 28.4% |
| `zomato` | `orders` | `idx_orders_customer_placed` | 5,184 kB | 18 MB | 28.3% |
| `zomato` | `orders` | `idx_orders_restaurant_placed_date` | 4,640 kB | 18 MB | 25.3% |
| `zomato` | `orders` | `idx_orders_partner_placed` | 4,224 kB | 18 MB | 23.1% |
| `zomato` | `orders` | `idx_orders_restaurant_delivered_placed` | 4,040 kB | 18 MB | 22.1% |
| `zomato` | `orders` | `idx_orders_placed_at_desc` | 3,312 kB | 18 MB | 18.1% |
| `zomato` | `payments` | `idx_payments_order_success` | 3,232 kB | 9,160 kB | 35.3% |
| `zomato` | `menu_items` | `idx_menu_items_restaurant_available` | 2,808 kB | 3,648 kB | 77.0% |
| `zomato` | `menu_items` | `idx_menu_items_paneer_trgm` | 1,352 kB | 3,648 kB | 37.1% |
| `zomato` | `restaurants` | `idx_restaurants_locality_status_rating` | 1,320 kB | 1,456 kB | 90.7% |
| `zomato` | `orders` | `idx_orders_coupon_delivered` | 1,056 kB | 18 MB | 5.8% |
| `zomato` | `reviews` | `idx_reviews_trgm_complaints` | 856 kB | 2,728 kB | 31.4% |
| `zomato` | `reviews` | `idx_reviews_restaurant_food_rating` | 528 kB | 2,728 kB | 19.4% |
| `zomato` | `restaurants` | `idx_restaurants_cuisines_gin` | 384 kB | 1,456 kB | 26.4% |
| `zomato` | `payments` | `idx_payments_failed_method_attempted` | 232 kB | 9,160 kB | 2.5% |
| `zomato` | `payments` | `idx_payments_failed_order` | 176 kB | 9,160 kB | 1.9% |
| `zomato` | `customers` | `idx_customers_gold_expires` | 104 kB | 2,984 kB | 3.5% |
| `zomato` | `delivery_partners` | `idx_delivery_partners_city_active` | 32 kB | 184 kB | 17.4% |
| `zomato` | `localities` | `idx_localities_name_id` | 16 kB | 8 kB | 200.0% |
| `zomato` | `orders` | `idx_orders_dispatch_queue` | **16 kB** | 18 MB | **0.1%** |
| `zomato` | `orders` | `idx_orders_preparing_accepted` | **16 kB** | 18 MB | **0.1%** |

### Efficiency of Partial Indexes
Notice that partial indexes such as `idx_orders_dispatch_queue` (16 kB) and `idx_orders_preparing_accepted` (16 kB) take almost zero disk space (0.1% of table size) while yielding up to 359× speedups. Because active dispatch queues represent a tiny transient fraction of the 150k orders table, indexing only rows meeting the status predicate maximizes cache residency and eliminates index bloat.

---

## 8. Queries That Could Not Be Sped Up Significantly

1. **R09: Average delivery time per city per month in 2026**
   - **Reason:** R09 is an analytical query that aggregates all DELIVERED orders placed in 2026 (>100,000 rows out of 150,000 total orders). When a query touches >60% of the entire table and must compute mathematical date differences and month-wise groupings across multiple joins, index lookups incur random I/O overhead. A parallel sequential scan or clustered scan is already optimal. Materialized views or summary tables would be recommended for future phases.
2. **R17: Customers with 2 or more failed payment attempts (all-time)**
   - **Reason:** R17 joins all failed payment attempts against the orders table across the entire database history without any date filter. Because it requires a global count and grouping across customer orders, it is bound by the cardinality of failed payments and hash grouping.
3. **R25: Cuisine filter in Pune**
   - **Reason:** The baseline execution time was already 0.324 ms due to small table sizes in memory (10 localities and small restaurant subset in Pune). At sub-millisecond latencies, engine parse/plan overhead dominates over scan execution.
