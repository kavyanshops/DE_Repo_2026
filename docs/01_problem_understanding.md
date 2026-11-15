# Problem understanding

Zomato needs a transactional PostgreSQL database for customers ordering from
restaurants, restaurants preparing orders, partners delivering them, and
teams monitoring payments, support, marketing, and operations. The database
must preserve correct order state while keeping interactive screens responsive
at peak meal times. The 30 supplied queries are the measurable workload.

| Problem | Business need and affected stakeholder | Classification |
|---|---|---|
| P1 | Show open restaurants in a customer's locality, ranked by rating. Affects customers and the customer-app team. | Customer-facing / real-time |
| P2 | Return available dishes matching a type-ahead search, scoped to the customer's city. Affects customers and Search. | Customer-facing / real-time |
| P3 | Open a customer's recent orders and bill details quickly. Affects customers and Support. | Customer-facing / real-time |
| P4 | Let restaurant partners see incoming orders and dish-wise sales for their restaurant. | Customer-facing / real-time |
| P5 | Refresh unassigned orders and kitchen-delay alerts often enough for Dispatch/Ops to act. | Customer-facing / real-time |
| P6 | Produce a complete idle-partner list so Fleet can allocate capacity. | Customer-facing / real-time |
| P7 | Surface failed attempts and suspicious customers quickly for Payments/Risk. | Customer-facing / real-time |
| P8 | Measure Gold membership expiry, coupon use, and growth performance. Affects Gold and Marketing. | Reporting / analytics |
| P9 | Find late deliveries and reviews mentioning cold food or late service. Affects Support and restaurant partners. | Customer-facing / real-time |
| P10 | Produce delivery-time, heatmap, and restaurant-health views that remain usable as order volume grows 20x. Affects Ops, Leadership, and Admin. | Reporting / analytics |

## Assumptions

- PostgreSQL 15+ is the target; timestamps retain their supplied time-zone
  offsets through `timestamptz`.
- Money is stored as `numeric(12,2)` rather than floating point.
- A customer, restaurant, menu item, partner, order, payment, or review has
  one stable integer identifier. `order_items` is identified by
  `(order_id, item_id)`.
- Empty CSV fields represent SQL `NULL`, not empty business values.
- A restaurant may have no current rating, and a review may omit delivery
  rating or text.
- An order can have multiple payment attempts. A successful payment is not
  made a schema-level prerequisite for delivery because the export contains
  1,304 delivered orders without one; this is a data-quality/reconciliation
  workflow rather than a load-blocking constraint.
- `orders.total_amount` is retained as the historical charged amount and is
  checked against `item_total + delivery_fee - discount`.
- The supplied `restaurants.rating`, `rating_count`, and
  `restaurants.is_pure_veg` are operational snapshots; they are not derived
  automatically by table constraints.
