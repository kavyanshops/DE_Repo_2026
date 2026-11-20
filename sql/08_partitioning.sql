-- =====================================================================
-- Zomato DBMS Project: Phase 5 Partitioning Architecture
-- File: sql/08_partitioning.sql
-- Database: PostgreSQL 15+
--
-- Architecture Strategy:
--   1. Table: orders (the highest volume, fastest growing table).
--   2. Method: Declarative RANGE Partitioning by placed_at.
--   3. Granularity: Monthly partitions (e.g., orders_2025_01 to orders_2026_12).
--   4. Primary Key Rule: In PostgreSQL partitioned tables, any UNIQUE / PRIMARY KEY
--      constraint MUST include the partition key: PRIMARY KEY (order_id, placed_at).
--   5. Partition Pruning: Enables the query engine to eliminate non-matching
--      partitions at plan/execution time, drastically accelerating date-filtered queries.
-- =====================================================================

SET search_path TO zomato;

-- ---------------------------------------------------------------------
-- 1. Create the Partitioned Orders Master Table
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS zomato.orders_partitioned (
    order_id integer NOT NULL,
    customer_id integer NOT NULL REFERENCES zomato.customers(customer_id) ON DELETE RESTRICT,
    restaurant_id integer NOT NULL REFERENCES zomato.restaurants(restaurant_id) ON DELETE RESTRICT,
    partner_id integer REFERENCES zomato.delivery_partners(partner_id) ON DELETE SET NULL,
    coupon_code text REFERENCES zomato.coupons(coupon_code) ON DELETE SET NULL,
    placed_at timestamptz NOT NULL,
    accepted_at timestamptz,
    picked_up_at timestamptz,
    delivered_at timestamptz,
    distance_km numeric(6,2) NOT NULL CHECK (distance_km >= 0),
    item_total numeric(12,2) NOT NULL CHECK (item_total >= 0),
    delivery_fee numeric(12,2) NOT NULL CHECK (delivery_fee >= 0),
    discount numeric(12,2) NOT NULL CHECK (discount >= 0 AND discount <= item_total + delivery_fee),
    total_amount numeric(12,2) NOT NULL CHECK (total_amount = item_total + delivery_fee - discount),
    status text NOT NULL CHECK (status IN (
        'PLACED', 'ACCEPTED', 'PREPARING', 'OUT_FOR_DELIVERY',
        'DELIVERED', 'CANCELLED_BY_CUSTOMER', 'CANCELLED_BY_RESTAURANT'
    )),
    CHECK (accepted_at IS NULL OR accepted_at >= placed_at),
    CHECK (picked_up_at IS NULL OR (accepted_at IS NOT NULL AND picked_up_at >= accepted_at)),
    CHECK (delivered_at IS NULL OR (picked_up_at IS NOT NULL AND delivered_at >= picked_up_at)),
    CHECK (status NOT IN ('ACCEPTED', 'PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED') OR accepted_at IS NOT NULL),
    CHECK (status NOT IN ('OUT_FOR_DELIVERY', 'DELIVERED') OR picked_up_at IS NOT NULL),
    CHECK (status <> 'DELIVERED' OR delivered_at IS NOT NULL),
    CHECK (status NOT IN ('PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED') OR partner_id IS NOT NULL),
    -- PostgreSQL Partition Key Rule: Primary Key MUST include partition key
    PRIMARY KEY (order_id, placed_at)
) PARTITION BY RANGE (placed_at);

-- ---------------------------------------------------------------------
-- 2. Create Monthly Partitions (2025 - 2026)
-- ---------------------------------------------------------------------

-- Year 2025 Monthly Partitions
CREATE TABLE IF NOT EXISTS zomato.orders_2025_01 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-02-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_02 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-02-01 00:00:00+05:30') TO ('2025-03-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_03 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-03-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_04 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-05-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_05 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-05-01 00:00:00+05:30') TO ('2025-06-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_06 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-06-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_07 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-08-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_08 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-08-01 00:00:00+05:30') TO ('2025-09-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_09 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-09-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_10 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2025-11-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_11 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-11-01 00:00:00+05:30') TO ('2025-12-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2025_12 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2025-12-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');

-- Year 2026 Monthly Partitions (Workload Period)
CREATE TABLE IF NOT EXISTS zomato.orders_2026_01 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-02-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_02 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-02-01 00:00:00+05:30') TO ('2026-03-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_03 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-03-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_04 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-05-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_05 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-05-01 00:00:00+05:30') TO ('2026-06-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_06 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');

-- Future Partitions (H2 2026)
CREATE TABLE IF NOT EXISTS zomato.orders_2026_07 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2026-08-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_08 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-08-01 00:00:00+05:30') TO ('2026-09-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_09 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-09-01 00:00:00+05:30') TO ('2026-10-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_10 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-10-01 00:00:00+05:30') TO ('2026-11-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_11 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-11-01 00:00:00+05:30') TO ('2026-12-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS zomato.orders_2026_12 PARTITION OF zomato.orders_partitioned
    FOR VALUES FROM ('2026-12-01 00:00:00+05:30') TO ('2027-01-01 00:00:00+05:30');

-- Default Partition for catch-all data integrity
CREATE TABLE IF NOT EXISTS zomato.orders_default PARTITION OF zomato.orders_partitioned DEFAULT;

-- ---------------------------------------------------------------------
-- 3. Partitioned Local Indexes
-- ---------------------------------------------------------------------
-- When created on the partitioned table, PostgreSQL automatically creates
-- matching local indexes on all current and future child partitions.

-- Serves: R04, R20 (Customer order history lookups)
CREATE INDEX IF NOT EXISTS idx_part_orders_customer_placed_at
ON zomato.orders_partitioned (customer_id, placed_at DESC)
INCLUDE (restaurant_id, status, total_amount);

-- Serves: R06, R07 (Restaurant partner daily and monthly orders)
CREATE INDEX IF NOT EXISTS idx_part_orders_restaurant_placed_date
ON zomato.orders_partitioned (restaurant_id, placed_at);

-- Serves: R07 (Delivered orders per restaurant)
CREATE INDEX IF NOT EXISTS idx_part_orders_restaurant_delivered_placed
ON zomato.orders_partitioned (restaurant_id, placed_at)
WHERE (status = 'DELIVERED');

-- Serves: R05 (Kitchen delay alerts)
CREATE INDEX IF NOT EXISTS idx_part_orders_preparing_accepted
ON zomato.orders_partitioned (accepted_at)
WHERE (status = 'PREPARING');

-- Serves: R11 (Delivery partner earnings)
CREATE INDEX IF NOT EXISTS idx_part_orders_partner_delivered_placed
ON zomato.orders_partitioned (partner_id, placed_at)
INCLUDE (delivery_fee)
WHERE (status = 'DELIVERED');

-- Serves: R12, W02 (Dispatch queue for unassigned orders)
CREATE INDEX IF NOT EXISTS idx_part_orders_dispatch_queue
ON zomato.orders_partitioned (placed_at, order_id)
WHERE (partner_id IS NULL AND status IN ('PLACED', 'ACCEPTED'));

-- Serves: R10 (Delivery duration SLA tracking)
CREATE INDEX IF NOT EXISTS idx_part_orders_delivery_duration
ON zomato.orders_partitioned (((delivered_at - placed_at)) DESC, placed_at)
WHERE (delivered_at IS NOT NULL);

-- Serves: R15 (Coupon marketing effectiveness)
CREATE INDEX IF NOT EXISTS idx_part_orders_coupon_delivered
ON zomato.orders_partitioned (coupon_code, status)
INCLUDE (discount, total_amount)
WHERE (coupon_code IS NOT NULL);

-- ---------------------------------------------------------------------
-- 4. Data Migration Script
-- ---------------------------------------------------------------------
-- Populate partitioned table from monolithic orders table:
INSERT INTO zomato.orders_partitioned
SELECT * FROM zomato.orders
ON CONFLICT (order_id, placed_at) DO NOTHING;

ANALYZE zomato.orders_partitioned;

-- ---------------------------------------------------------------------
-- 5. Partition Pruning Demonstration
-- ---------------------------------------------------------------------
-- In PostgreSQL, when enable_partition_pruning = on (default), queries
-- with range constraints only scan the partitions matching the date filter.
-- Non-matching partitions are pruned from the query plan.

-- Demonstration 1: R06 - June 15, 2026 (Only scans orders_2026_06)
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, status, item_total, placed_at
FROM zomato.orders_partitioned
WHERE restaurant_id = 217
  AND placed_at >= '2026-06-15 00:00:00+05:30'
  AND placed_at < '2026-06-16 00:00:00+05:30'
ORDER BY placed_at;

-- Demonstration 2: R07 - May 2026 (Only scans orders_2026_05)
EXPLAIN (ANALYZE, BUFFERS)
SELECT oi.item_id, sum(oi.quantity) AS units
FROM zomato.order_items oi
JOIN zomato.orders_partitioned o ON o.order_id = oi.order_id
WHERE o.restaurant_id = 217
  AND o.status = 'DELIVERED'
  AND o.placed_at >= '2026-05-01 00:00:00+05:30'
  AND o.placed_at < '2026-06-01 00:00:00+05:30'
GROUP BY oi.item_id;

-- ---------------------------------------------------------------------
-- 6. Automated Partition Maintenance Function
-- ---------------------------------------------------------------------
-- Stored procedure to automatically create future monthly partitions
-- to prevent inserts falling into the default partition.

CREATE OR REPLACE FUNCTION zomato.create_monthly_orders_partition(p_year int, p_month int)
RETURNS text AS $$
DECLARE
    v_partition_name text;
    v_start_date text;
    v_end_date text;
    v_sql text;
BEGIN
    v_partition_name := format('orders_%s_%s', p_year, lpad(p_month::text, 2, '0'));
    v_start_date := format('%s-%s-01 00:00:00+05:30', p_year, lpad(p_month::text, 2, '0'));
    
    IF p_month = 12 THEN
        v_end_date := format('%s-01-01 00:00:00+05:30', p_year + 1);
    ELSE
        v_end_date := format('%s-%s-01 00:00:00+05:30', p_year, lpad((p_month + 1)::text, 2, '0'));
    END IF;

    v_sql := format(
        'CREATE TABLE IF NOT EXISTS zomato.%I PARTITION OF zomato.orders_partitioned FOR VALUES FROM (%L) TO (%L);',
        v_partition_name, v_start_date, v_end_date
    );

    EXECUTE v_sql;
    RETURN format('Created partition zomato.%I from %s to %s', v_partition_name, v_start_date, v_end_date);
END;
$$ LANGUAGE plpgsql;
