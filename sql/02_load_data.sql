SET search_path TO zomato;

\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy localities FROM 'seed_data/localities.csv' WITH (FORMAT csv, HEADER true)
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true)
\copy restaurants FROM 'seed_data/restaurants.csv' WITH (FORMAT csv, HEADER true)
\copy menu_items FROM 'seed_data/menu_items.csv' WITH (FORMAT csv, HEADER true)
\copy delivery_partners FROM 'seed_data/delivery_partners.csv' WITH (FORMAT csv, HEADER true)
\copy coupons FROM 'seed_data/coupons.csv' WITH (FORMAT csv, HEADER true)
\copy orders FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true)
\copy order_items FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true)
\copy payments FROM 'seed_data/payments.csv' WITH (FORMAT csv, HEADER true)
\copy reviews FROM 'seed_data/reviews.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;

-- Expected counts: cities 10, localities 100, customers 25000,
-- restaurants 2500, menu_items 50000, delivery_partners 2000,
-- coupons 30, orders 150000, order_items 375000, payments 137378,
-- reviews 39186.
SELECT 'cities' AS table_name, count(*) AS row_count FROM cities
UNION ALL SELECT 'localities', count(*) FROM localities
UNION ALL SELECT 'customers', count(*) FROM customers
UNION ALL SELECT 'restaurants', count(*) FROM restaurants
UNION ALL SELECT 'menu_items', count(*) FROM menu_items
UNION ALL SELECT 'delivery_partners', count(*) FROM delivery_partners
UNION ALL SELECT 'coupons', count(*) FROM coupons
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'payments', count(*) FROM payments
UNION ALL SELECT 'reviews', count(*) FROM reviews
ORDER BY table_name;

-- The first three integrity checks should return zero. The payment check
-- intentionally exposes the known seed-data anomaly instead of hiding it
-- with a constraint.
SELECT count(*) AS order_items_from_other_restaurant
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN menu_items m ON m.item_id = oi.item_id
WHERE o.restaurant_id <> m.restaurant_id;

SELECT count(*) AS review_order_identity_mismatches
FROM reviews v
JOIN orders o ON o.order_id = v.order_id
WHERE v.customer_id <> o.customer_id OR v.restaurant_id <> o.restaurant_id;

SELECT count(*) AS order_total_mismatches
FROM orders
WHERE total_amount <> item_total + delivery_fee - discount;

SELECT count(*) AS delivered_orders_without_successful_payment
FROM orders o
WHERE o.status = 'DELIVERED'
  AND NOT EXISTS (
      SELECT 1 FROM payments p
      WHERE p.order_id = o.order_id AND p.payment_status = 'SUCCESS'
  );
