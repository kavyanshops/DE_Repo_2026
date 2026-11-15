CREATE SCHEMA zomato;
SET search_path TO zomato;

CREATE TABLE cities (
    city_id integer PRIMARY KEY,
    city_name text NOT NULL UNIQUE,
    state text NOT NULL
);

CREATE TABLE localities (
    locality_id integer PRIMARY KEY,
    city_id integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    locality_name text NOT NULL,
    pincode text NOT NULL,
    UNIQUE (city_id, locality_name),
    UNIQUE (pincode),
    CHECK (pincode ~ '^[0-9]{6}$')
);

CREATE TABLE customers (
    customer_id integer PRIMARY KEY,
    full_name text NOT NULL,
    email text NOT NULL UNIQUE,
    phone text NOT NULL UNIQUE CHECK (phone ~ '^[0-9]{10}$'),
    city_id integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    signup_date date NOT NULL,
    is_gold_member boolean NOT NULL,
    gold_expires_on date,
    is_active boolean NOT NULL,
    CHECK (gold_expires_on IS NOT NULL OR NOT is_gold_member)
);

CREATE TABLE restaurants (
    restaurant_id integer PRIMARY KEY,
    name text NOT NULL,
    locality_id integer NOT NULL REFERENCES localities(locality_id) ON DELETE RESTRICT,
    cuisines text[] NOT NULL,
    avg_cost_for_two numeric(10,2) NOT NULL CHECK (avg_cost_for_two >= 0),
    rating numeric(2,1) CHECK (rating IS NULL OR rating BETWEEN 1.0 AND 5.0),
    rating_count integer NOT NULL CHECK (rating_count >= 0),
    opens_at time NOT NULL,
    closes_at time NOT NULL,
    is_pure_veg boolean NOT NULL,
    status text NOT NULL CHECK (status IN ('OPEN', 'TEMPORARILY_CLOSED', 'DELISTED')),
    onboarded_on date NOT NULL,
    CHECK (opens_at < closes_at)
);

CREATE TABLE menu_items (
    item_id integer PRIMARY KEY,
    restaurant_id integer NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    item_name text NOT NULL,
    category text NOT NULL CHECK (category IN ('Main Course', 'Starters', 'Rice', 'Breads', 'Desserts', 'Beverages')),
    price numeric(10,2) NOT NULL CHECK (price > 0),
    is_veg boolean NOT NULL,
    is_bestseller boolean NOT NULL,
    is_available boolean NOT NULL
);

CREATE TABLE delivery_partners (
    partner_id integer PRIMARY KEY,
    full_name text NOT NULL,
    phone text NOT NULL UNIQUE CHECK (phone ~ '^[0-9]{10}$'),
    city_id integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    vehicle_type text NOT NULL CHECK (vehicle_type IN ('BIKE', 'SCOOTER', 'EV', 'BICYCLE')),
    joined_on date NOT NULL,
    rating numeric(2,1) NOT NULL CHECK (rating BETWEEN 1.0 AND 5.0),
    status text NOT NULL CHECK (status IN ('ACTIVE', 'INACTIVE', 'BLOCKED'))
);

CREATE TABLE coupons (
    coupon_code text PRIMARY KEY,
    discount_pct numeric(5,2) NOT NULL CHECK (discount_pct BETWEEN 0 AND 100),
    max_discount numeric(10,2) NOT NULL CHECK (max_discount >= 0),
    min_order_value numeric(10,2) NOT NULL CHECK (min_order_value >= 0),
    valid_from date NOT NULL,
    valid_to date NOT NULL,
    CHECK (valid_to >= valid_from)
);

CREATE TABLE orders (
    order_id integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    restaurant_id integer NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE RESTRICT,
    partner_id integer REFERENCES delivery_partners(partner_id) ON DELETE SET NULL,
    coupon_code text REFERENCES coupons(coupon_code) ON DELETE SET NULL,
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
    CHECK (status NOT IN ('PREPARING', 'OUT_FOR_DELIVERY', 'DELIVERED') OR partner_id IS NOT NULL)
);

CREATE TABLE order_items (
    order_id integer NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    item_id integer NOT NULL REFERENCES menu_items(item_id) ON DELETE RESTRICT,
    quantity smallint NOT NULL CHECK (quantity > 0),
    unit_price numeric(10,2) NOT NULL CHECK (unit_price > 0),
    PRIMARY KEY (order_id, item_id)
);

CREATE TABLE payments (
    payment_id integer PRIMARY KEY,
    order_id integer NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    amount numeric(12,2) NOT NULL CHECK (amount > 0),
    method text NOT NULL CHECK (method IN ('UPI', 'CARD', 'WALLET', 'COD')),
    payment_status text NOT NULL CHECK (payment_status IN ('SUCCESS', 'FAILED', 'REFUNDED')),
    attempted_at timestamptz NOT NULL
);

CREATE TABLE reviews (
    review_id integer PRIMARY KEY,
    order_id integer NOT NULL UNIQUE REFERENCES orders(order_id) ON DELETE CASCADE,
    customer_id integer NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    restaurant_id integer NOT NULL REFERENCES restaurants(restaurant_id) ON DELETE RESTRICT,
    food_rating smallint NOT NULL CHECK (food_rating BETWEEN 1 AND 5),
    delivery_rating smallint CHECK (delivery_rating IS NULL OR delivery_rating BETWEEN 1 AND 5),
    review_text text,
    created_at timestamptz NOT NULL
);
