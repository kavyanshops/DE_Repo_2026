-- =====================================================================
-- Zomato DBMS Project: Phase 4 Index Design
-- File: sql/05_indexes.sql
-- Database: PostgreSQL 15+
--
-- Optimization strategy:
--   1. Composite B-tree indexes following Equality -> Sort -> Range rule.
--   2. Partial indexes to filter out unneeded rows (status, NULLs).
--   3. Covering indexes using INCLUDE (...) to allow Index Only Scans.
--   4. GIN trigram indexes (pg_trgm) for wildcard ILIKE text search.
--   5. GIN array index for array membership filters.
-- =====================================================================

SET search_path TO zomato;

-- Enable trigram extension for fuzzy/wildcard text searching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------
-- 1. Localities & Restaurants
-- ---------------------------------------------------------------------

-- Serves: R01, R02, R08, R09, R19, R22, R25
-- Why: Speeds up locality lookup by name and covers foreign key joins to cities/localities.
CREATE INDEX IF NOT EXISTS idx_localities_name_id
ON zomato.localities (locality_name, locality_id);

-- Serves: R01, R25
-- Why: Equality filter on locality_id, status filter ('OPEN'), and pre-sorted by rating DESC NULLS LAST.
-- Covering with INCLUDE avoids visiting table heap for home feed display attributes.
CREATE INDEX IF NOT EXISTS idx_restaurants_locality_status_rating
ON zomato.restaurants (locality_id, status, rating DESC NULLS LAST)
INCLUDE (name, cuisines, avg_cost_for_two);

-- Serves: R25 (Cuisine filter: open Chinese restaurants in Pune)
-- Why: GIN index allows fast array containment ('Chinese' = ANY(cuisines)) scans without sequential scan.
CREATE INDEX IF NOT EXISTS idx_restaurants_cuisines_gin
ON zomato.restaurants USING gin (cuisines);

-- ---------------------------------------------------------------------
-- 2. Menu Items
-- ---------------------------------------------------------------------

-- Serves: R02 (Dish search: available "paneer" dishes in Bengaluru)
-- Why: Trigram GIN index for ILIKE '%paneer%' pattern matching. Partial index filters only available items.
CREATE INDEX IF NOT EXISTS idx_menu_items_paneer_trgm
ON zomato.menu_items USING gin (item_name gin_trgm_ops)
WHERE is_available;

-- Serves: R03 (Restaurant page menu grouped by category)
-- Why: Filters by restaurant_id and is_available, pre-sorted by category, bestseller DESC, item_name.
-- Covering INCLUDE (price, is_veg) provides an Index Only Scan.
CREATE INDEX IF NOT EXISTS idx_menu_items_restaurant_available
ON zomato.menu_items (restaurant_id, is_available, category, is_bestseller DESC, item_name)
INCLUDE (price, is_veg);

-- ---------------------------------------------------------------------
-- 3. Customers
-- ---------------------------------------------------------------------

-- Serves: R14, W05 (Gold member expiration checks and nightly updates)
-- Why: Partial index on gold members with expiration date for quick range scans.
CREATE INDEX IF NOT EXISTS idx_customers_gold_expires
ON zomato.customers (gold_expires_on, customer_id)
WHERE is_gold_member;

-- ---------------------------------------------------------------------
-- 4. Delivery Partners
-- ---------------------------------------------------------------------

-- Serves: R13 (Fleet team: active Bengaluru delivery partners)
-- Why: Equality filter on city_id and active status.
CREATE INDEX IF NOT EXISTS idx_delivery_partners_city_active
ON zomato.delivery_partners (city_id, status);

-- ---------------------------------------------------------------------
-- 5. Orders - Customer & Restaurant Lookups
-- ---------------------------------------------------------------------

-- Serves: R04 ("Your orders": customer last 10 orders)
-- Why: Equality on customer_id, ordered by placed_at DESC. Covering index for Index Only Scan.
CREATE INDEX IF NOT EXISTS idx_orders_customer_placed_at
ON zomato.orders (customer_id, placed_at DESC)
INCLUDE (restaurant_id, status, total_amount);

-- Serves: R06, R07 (Restaurant partner app: orders received, dish sales)
-- Why: Equality on restaurant_id, range on placed_at.
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_placed_date
ON zomato.orders (restaurant_id, placed_at);

-- Serves: R07 (Restaurant partner sales in May 2026)
-- Why: Partial index filtering only DELIVERED orders for restaurant-level sales.
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_delivered_placed
ON zomato.orders (restaurant_id, placed_at)
WHERE (status = 'DELIVERED');

-- Serves: R20 (Top spending customers on delivered orders)
-- Why: Equality on customer_id, covering total_amount for DELIVERED orders.
CREATE INDEX IF NOT EXISTS idx_orders_customer_placed
ON zomato.orders (customer_id, placed_at)
INCLUDE (total_amount)
WHERE (status = 'DELIVERED');

-- ---------------------------------------------------------------------
-- 6. Orders - Dispatch, Partner & Operational Flows
-- ---------------------------------------------------------------------

-- Serves: R05 (Kitchen-delay alert: orders stuck in PREPARING)
-- Why: Partial index on orders currently in 'PREPARING' status sorted by accepted_at.
CREATE INDEX IF NOT EXISTS idx_orders_preparing_accepted
ON zomato.orders (accepted_at)
WHERE (status = 'PREPARING');

-- Serves: R11 (Delivery partner weekly earnings)
-- Why: Partner equality filter, placed_at range filter, covering delivery_fee.
CREATE INDEX IF NOT EXISTS idx_orders_partner_delivered_placed
ON zomato.orders (partner_id, placed_at)
INCLUDE (delivery_fee)
WHERE (status = 'DELIVERED');

-- Serves: R12, W02 (Dispatch screen & assignment of unassigned orders)
-- Why: Partial index on orders without partner and status in ('PLACED', 'ACCEPTED').
CREATE INDEX IF NOT EXISTS idx_orders_dispatch_queue
ON zomato.orders (placed_at, order_id)
WHERE (partner_id IS NULL AND status IN ('PLACED', 'ACCEPTED'));

-- Serves: R13 (Active partners with no recent orders)
-- Why: Subquery anti-join index on partner_id and placed_at.
CREATE INDEX IF NOT EXISTS idx_orders_partner_placed
ON zomato.orders (partner_id, placed_at)
WHERE (partner_id IS NOT NULL);

-- ---------------------------------------------------------------------
-- 7. Orders - Analytics, Marketing & Paging
-- ---------------------------------------------------------------------

-- Serves: R10 (Deliveries taking > 60 minutes)
-- Why: Expression index on computed delivery duration interval.
CREATE INDEX IF NOT EXISTS idx_orders_delivery_duration
ON zomato.orders (((delivered_at - placed_at)) DESC, placed_at)
WHERE (delivered_at IS NOT NULL);

-- Serves: R15 (Coupon marketing effectiveness)
-- Why: Partial index on non-null coupon codes for DELIVERED orders.
CREATE INDEX IF NOT EXISTS idx_orders_coupon_delivered
ON zomato.orders (coupon_code, status)
INCLUDE (discount, total_amount)
WHERE (coupon_code IS NOT NULL);

-- Serves: R23 (Admin panel newest orders pagination)
-- Why: B-tree scan ordered by placed_at DESC.
CREATE INDEX IF NOT EXISTS idx_orders_placed_at_desc
ON zomato.orders (placed_at DESC);

-- ---------------------------------------------------------------------
-- 8. Payments
-- ---------------------------------------------------------------------

-- Serves: R16 (Failed payment attempts per method in last 7 days)
-- Why: Partial index on failed payments, indexed by method and attempted_at.
CREATE INDEX IF NOT EXISTS idx_payments_failed_method_attempted
ON zomato.payments (method, attempted_at)
WHERE (payment_status = 'FAILED');

-- Serves: R17 (Customers with multiple failed payments)
-- Why: Foreign key index on order_id for failed payments to enable hash/merge join with orders.
CREATE INDEX IF NOT EXISTS idx_payments_failed_order
ON zomato.payments (order_id)
WHERE (payment_status = 'FAILED');

-- Serves: R24 (Bill page: successful payment for order)
-- Why: Index on order_id for SUCCESS payments covering payment method.
CREATE INDEX IF NOT EXISTS idx_payments_order_success
ON zomato.payments (order_id)
INCLUDE (method)
WHERE (payment_status = 'SUCCESS');

-- ---------------------------------------------------------------------
-- 9. Reviews
-- ---------------------------------------------------------------------

-- Serves: R18 (Review moderation: text search for 'cold' or 'late')
-- Why: GIN trigram index on review_text for efficient ILIKE text search.
CREATE INDEX IF NOT EXISTS idx_reviews_trgm_complaints
ON zomato.reviews USING gin (review_text gin_trgm_ops);

-- Serves: R19, W04 (Average rating and reviews by restaurant)
-- Why: B-tree index on restaurant_id covering food_rating for aggregations.
CREATE INDEX IF NOT EXISTS idx_reviews_restaurant_food_rating
ON zomato.reviews (restaurant_id, food_rating);
