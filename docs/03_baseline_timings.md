# Baseline Query Timings (Phase 3)

Database: PostgreSQL 18.6 · Dataset: 150,000 orders (seed data) · Date: 17 Nov 2026

Each query was executed 3 times using `EXPLAIN (ANALYZE, BUFFERS)` via `./benchmarks/run_benchmark.sh zomato baseline`. Write queries (`W01`–`W05`) were executed inside `BEGIN ... ROLLBACK;` transactions so that database state remained unchanged across runs. The execution times below reflect the PostgreSQL engine execution times in milliseconds recorded directly in `benchmarks/results/baseline/`.

## Timing Table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Home feed: open restaurants in Koramangala, best rated first | READ | 0.631 | 0.437 | 0.426 | 0.498 |
| R02: Dish search: available "paneer" dishes in Bengaluru | READ | 20.723 | 18.654 | 15.906 | 18.428 |
| R03: Restaurant page: the menu of one restaurant, grouped by category | READ | 2.087 | 1.690 | 2.052 | 1.943 |
| R04: "Your orders": a customer's last 10 orders with restaurant names | READ | 6.392 | 4.895 | 4.812 | 5.366 |
| R05: Kitchen-delay alert: orders stuck in PREPARING for over 40 minutes (checked at 23:59 on 30 Jun 2026) | READ | 8.349 | 6.933 | 7.263 | 7.515 |
| R06: Restaurant partner app: all orders received by restaurant 217 on 15 June 2026 | READ | 4.802 | 4.646 | 5.133 | 4.860 |
| R07: Restaurant partner app: units sold per dish in May 2026 | READ | 7.210 | 6.550 | 6.509 | 6.756 |
| R08: Bestseller badges: top 3 dishes of every Pune restaurant in the last 30 days | READ | 7.500 | 7.626 | 7.513 | 7.546 |
| R09: Ops dashboard: average delivery time (minutes) per city per month in 2026 | READ | 25.360 | 24.482 | 24.958 | 24.933 |
| R10: Customer support: deliveries in June 2026 that took more than 60 minutes | READ | 5.046 | 5.703 | 6.253 | 5.667 |
| R11: Delivery partner app: this week's earnings (delivery fees) for partner 150 | READ | 5.906 | 6.670 | 6.811 | 6.462 |
| R12: Dispatch: orders still waiting for a delivery partner, oldest first | READ | 8.435 | 8.589 | 8.838 | 8.621 |
| R13: Fleet team: active Bengaluru partners who have not been assigned any order since 25 June 2026 | READ | 7.253 | 6.697 | 6.597 | 6.849 |
| R14: Gold team: Gold members whose membership expires before July 2026 but who ordered in June 2026 | READ | 8.564 | 8.119 | 8.254 | 8.312 |
| R15: Marketing: coupon effectiveness (orders, total discount, average bill) | READ | 15.974 | 15.532 | 15.599 | 15.702 |
| R16: Payments team: failed payment attempts per method in the last 7 days | READ | 5.633 | 4.137 | 4.189 | 4.653 |
| R17: Risk team: customers with 2 or more failed payment attempts (all time) | READ | 17.755 | 16.937 | 16.862 | 17.185 |
| R18: Review moderation: newest reviews that complain about cold food or late delivery | READ | 13.415 | 13.260 | 13.204 | 13.293 |
| R19: Restaurant health report for Bengaluru: last order time, delivered orders and average food rating | READ | 4900.660 | 5260.847 | 5642.061 | 5267.856 |
| R20: Growth: top 20 customers in Mumbai by total spend on delivered orders | READ | 21.596 | 21.150 | 37.796 | 26.847 |
| R21: Growth: share of customers in each city who ordered at least twice in May 2026 | READ | 12.218 | 11.597 | 11.487 | 11.767 |
| R22: Ops heatmap: Bengaluru orders by weekday and hour, last 8 weeks | READ | 17.595 | 15.832 | 14.842 | 16.090 |
| R23: Admin panel: "All orders", newest first, page 4,001 (25 rows per page) | READ | 39.440 | 39.189 | 38.163 | 38.931 |
| R24: Bill page: one order with its items, restaurant and successful payment | READ | 6.261 | 5.635 | 5.023 | 5.640 |
| R25: Cuisine filter: open Chinese restaurants in Pune | READ | 0.314 | 0.354 | 0.305 | 0.324 |
| W01: Customer app: place a new order (header row) | WRITE | 1.509 | 0.566 | 0.577 | 0.884 |
| W02: Dispatch: assign partner 150 to the oldest accepted order that has no partner | WRITE | 8.997 | 8.248 | 9.039 | 8.761 |
| W03: Restaurant partner app: desserts sold out, so hide them | WRITE | 2.003 | 1.654 | 1.946 | 1.868 |
| W04: Nightly job: recompute every restaurant's rating from its reviews | WRITE | 12.003 | 13.407 | 14.593 | 13.334 |
| W05: Nightly job: end Gold membership for customers whose plan has expired | WRITE | 13.742 | 12.243 | 22.089 | 16.025 |
| **Total (sum of all 30)** | | **5207.373** | **5552.279** | **5959.100** | **5572.917** |

---

## Plan Analysis: Scan Types and Baseline Performance Drivers

Per the Phase 2 specification, only `PRIMARY KEY` and `UNIQUE` constraints exist in the baseline database, with zero secondary or covering indexes created. Consequently, the query planner must rely heavily on sequential scans across large tables (`orders`: 150,000 rows, `payments`: 137,378 rows, `menu_items`: 50,000 rows, `reviews`: 39,186 rows). Foreign key lookups (`orders.customer_id`, `orders.restaurant_id`, `orders.partner_id`, `payments.order_id`) have no supporting indexes.

### R01: Home feed: open restaurants in Koramangala, best rated first
- **Scan Type(s):** `Seq Scan on restaurants | Seq Scan on localities`
- **Why it is slow / fast:** Fast (~0.4 ms) because localities (100 rows) and restaurants (2,500 rows) are small and cached in memory, but lacks composite index on (locality_id, rating) for scalable sorting.

### R02: Dish search: available "paneer" dishes in Bengaluru
- **Scan Type(s):** `Seq Scan on menu_items | Seq Scan on restaurants | Seq Scan on localities`
- **Why it is slow / fast:** Moderate (~17.9 ms) due to full sequential scan over 50,000 menu items evaluating an unindexed ILIKE pattern without a GIN trigram index.

### R03: Restaurant page: the menu of one restaurant, grouped by category
- **Scan Type(s):** `Seq Scan on menu_items`
- **Why it is slow / fast:** Fast (~1.8 ms) for 50k rows in memory, but performs an unnecessary full table scan on menu_items instead of an index lookup on restaurant_id (<0.05 ms).

### R04: "Your orders": a customer's last 10 orders with restaurant names
- **Scan Type(s):** `Seq Scan on orders | Index Scan using restaurants_pkey on restaurants`
- **Why it is slow / fast:** Moderate (~4.8 ms) because it sequentially scans all 150,000 orders to find the few orders belonging to customer_id 1042 due to missing index on customer_id.

### R05: Kitchen-delay alert: orders stuck in PREPARING for over 40 minutes (checked at 23:59 on 30 Jun 2026)
- **Scan Type(s):** `Seq Scan on orders`
- **Why it is slow / fast:** Takes ~7.0 ms because it scans all 150,000 orders to filter for a rare status ('PREPARING') and timestamp predicate without a partial index.

### R06: Restaurant partner app: all orders received by restaurant 217 on 15 June 2026
- **Scan Type(s):** `Seq Scan on orders`
- **Why it is slow / fast:** Takes ~5.5 ms because all 150,000 orders are scanned sequentially, further aggravated by wrapping placed_at inside DATE(placed_at) preventing standard B-tree range scans.

### R07: Restaurant partner app: units sold per dish in May 2026
- **Scan Type(s):** `Seq Scan on orders | Index Scan using order_items_pkey on order_items | Index Scan using menu_items_pkey on menu_items`
- **Why it is slow / fast:** Takes ~6.3 ms because orders table requires a full sequential scan to filter for restaurant 217, DELIVERED status, and date range.

### R08: Bestseller badges: top 3 dishes of every Pune restaurant in the last 30 days
- **Scan Type(s):** `Seq Scan on orders | Seq Scan on restaurants | Seq Scan on localities | Index Scan using order_items_pkey on order_items`
- **Why it is slow / fast:** Takes ~7.2 ms because all orders in June 2026 are filtered via sequential scan and joined across 4 tables before window partitioning and ranking.

### R09: Ops dashboard: average delivery time (minutes) per city per month in 2026
- **Scan Type(s):** `Seq Scan on orders | Seq Scan on restaurants | Seq Scan on localities`
- **Why it is slow / fast:** Slow (~25.2 ms) because it reads the bulk of orders in 2026 (>100k rows) via sequential scan and performs multi-table hash joins and date_trunc groupings.

### R10: Customer support: deliveries in June 2026 that took more than 60 minutes
- **Scan Type(s):** `Seq Scan on orders`
- **Why it is slow / fast:** Takes ~5.3 ms due to full sequential scan over 150,000 orders evaluating expression (delivered_at - placed_at > interval '60 minutes').

### R11: Delivery partner app: this week's earnings (delivery fees) for partner 150
- **Scan Type(s):** `Seq Scan on orders`
- **Why it is slow / fast:** Takes ~6.4 ms because it sequentially scans all 150,000 orders to filter partner_id = 150 and date range due to lack of index on partner_id.

### R12: Dispatch: orders still waiting for a delivery partner, oldest first
- **Scan Type(s):** `Seq Scan on orders`
- **Why it is slow / fast:** Takes ~8.6 ms because it sequentially scans 150,000 orders looking for rare unassigned orders (partner_id IS NULL AND status IN ('PLACED', 'ACCEPTED')).

### R13: Fleet team: active Bengaluru partners who have not been assigned any order since 25 June 2026
- **Scan Type(s):** `Seq Scan on delivery_partners | Seq Scan on orders`
- **Why it is slow / fast:** Takes ~7.1 ms because subquery scans 150,000 orders without placed_at index, and NOT IN construct forces full materialization and null-safety overhead.

### R14: Gold team: Gold members whose membership expires before July 2026 but who ordered in June 2026
- **Scan Type(s):** `Seq Scan on orders | Seq Scan on customers`
- **Why it is slow / fast:** Takes ~7.6 ms because it scans customers sequentially and repeatedly checks orders via correlated EXISTS subquery scanning orders.

### R15: Marketing: coupon effectiveness (orders, total discount, average bill)
- **Scan Type(s):** `Seq Scan on orders | Seq Scan on coupons`
- **Why it is slow / fast:** Takes ~15.4 ms because it sequentially scans 150,000 orders and hash joins against all coupons with GROUP BY aggregation.

### R16: Payments team: failed payment attempts per method in the last 7 days
- **Scan Type(s):** `Seq Scan on payments`
- **Why it is slow / fast:** Takes ~4.7 ms because 137,378 payments are scanned sequentially to filter for recent FAILED status without a partial index.

### R17: Risk team: customers with 2 or more failed payment attempts (all time)
- **Scan Type(s):** `Seq Scan on orders | Seq Scan on payments`
- **Why it is slow / fast:** Takes ~17.3 ms because all payments (137k rows) and orders (150k rows) are sequentially scanned and hash-joined across the entire database history.

### R18: Review moderation: newest reviews that complain about cold food or late delivery
- **Scan Type(s):** `Seq Scan on reviews`
- **Why it is slow / fast:** Takes ~13.4 ms because 39,186 reviews are scanned sequentially evaluating two wildcard ILIKE filters without a GIN trigram index, followed by sorting.

### R19: Restaurant health report for Bengaluru: last order time, delivered orders and average food rating
- **Scan Type(s):** `Seq Scan on restaurants | Seq Scan on localities | Seq Scan on orders | Seq Scan on reviews`
- **Why it is slow / fast:** Extremely slow (~5,183.5 ms / 5.2s) because it executes three correlated scalar subqueries for each Bengaluru restaurant (~250), scanning 150k orders twice and 39k reviews once per restaurant (>85 million row evaluations).

### R20: Growth: top 20 customers in Mumbai by total spend on delivered orders
- **Scan Type(s):** `Seq Scan on orders | Seq Scan on customers`
- **Why it is slow / fast:** Takes ~21.2 ms because all 150,000 orders and 25,000 customers are sequentially scanned and hash joined before grouping and sorting top spenders.

### R21: Growth: share of customers in each city who ordered at least twice in May 2026
- **Scan Type(s):** `Seq Scan on customers | Seq Scan on orders`
- **Why it is slow / fast:** Takes ~10.3 ms because the CTE sequentially scans all 150,000 orders for May 2026, aggregates by customer, and hash joins with customers table.

### R22: Ops heatmap: Bengaluru orders by weekday and hour, last 8 weeks
- **Scan Type(s):** `Seq Scan on orders | Seq Scan on restaurants | Seq Scan on localities`
- **Why it is slow / fast:** Takes ~13.9 ms because all 150,000 orders are scanned sequentially and joined with restaurants and localities to filter city_id = 1 and 8-week range.

### R23: Admin panel: "All orders", newest first, page 4,001 (25 rows per page)
- **Scan Type(s):** `Seq Scan on orders`
- **Why it is slow / fast:** Takes ~37.1 ms because it must sequentially scan and sort orders, walking through and discarding 100,000 rows (OFFSET 100000) to return 25 rows.

### R24: Bill page: one order with its items, restaurant and successful payment
- **Scan Type(s):** `Index Scan using orders_pkey on orders | Index Scan using restaurants_pkey on restaurants | Seq Scan on payments | Index Scan using order_items_pkey on order_items | Index Scan using menu_items_pkey on menu_items`
- **Why it is slow / fast:** Takes ~5.8 ms despite PK index scans on orders, order_items, and menu_items, because payments table lacks an index on foreign key order_id, forcing a full 137k-row sequential scan on payments.

### R25: Cuisine filter: open Chinese restaurants in Pune
- **Scan Type(s):** `Seq Scan on restaurants | Seq Scan on localities`
- **Why it is slow / fast:** Fast (~0.33 ms) because Pune restaurants is a small dataset in memory, but uses sequential scan on restaurants checking array membership without a GIN index.

### W01: Customer app: place a new order (header row)
- **Scan Type(s):** `(no scan)`
- **Why it is slow / fast:** Fast (~0.70 ms) as it is a single-row INSERT into orders validating table constraints.

### W02: Dispatch: assign partner 150 to the oldest accepted order that has no partner
- **Scan Type(s):** `Seq Scan on orders | Index Scan using orders_pkey on orders`
- **Why it is slow / fast:** Takes ~8.6 ms because the subquery performs a full sequential scan across 150,000 orders to find the oldest unassigned ACCEPTED order before updating via PK.

### W03: Restaurant partner app: desserts sold out, so hide them
- **Scan Type(s):** `Seq Scan on menu_items`
- **Why it is slow / fast:** Takes ~1.6 ms because it sequentially scans all 50,000 menu_items to find and update rows matching restaurant_id = 217 AND category = 'Desserts'.

### W04: Nightly job: recompute every restaurant's rating from its reviews
- **Scan Type(s):** `Seq Scan on restaurants | Seq Scan on reviews`
- **Why it is slow / fast:** Takes ~10.5 ms because it scans all 39,186 reviews, aggregates them by restaurant_id, and updates all 2,500 restaurants in batch.

### W05: Nightly job: end Gold membership for customers whose plan has expired
- **Scan Type(s):** `Seq Scan on customers`
- **Why it is slow / fast:** Takes ~8.8 ms because it sequentially scans all 25,000 customers to evaluate boolean and date expiration filters.
