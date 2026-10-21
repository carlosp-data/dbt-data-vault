/*--
Loads the Tasty Bytes source tables from the public Snowflake quickstart bucket into
'tasty_bytes.source'. Run it after 'tasty_bytes_admin.sql'.
--*/

USE ROLE sysadmin;
USE WAREHOUSE compute_wh;

/*--
file format and stage creation
--*/

CREATE OR REPLACE FILE FORMAT tasty_bytes.public.csv_ff TYPE = 'csv';

CREATE OR REPLACE STAGE tasty_bytes.public.s3load
URL = 's3://sfquickstarts/tasty-bytes-builder-education/'
FILE_FORMAT = tasty_bytes.public.csv_ff;


/*--
raw zone table build
--*/

-- franchise table build
CREATE OR REPLACE TABLE tasty_bytes.source.franchises
(
   franchise_id NUMBER(8,0),
   first_name VARCHAR(50),
   last_name VARCHAR(50),
   city VARCHAR(50),
   country VARCHAR(50),
   e_mail VARCHAR(100),
   phone_number VARCHAR(50)
);

-- location table build
CREATE OR REPLACE TABLE tasty_bytes.source.locations
(
   location_id NUMBER(8,0),
   placekey VARCHAR(50),
   location VARCHAR(500),
   city VARCHAR(50),
   region VARCHAR(50),
   iso_country_code CHAR(2),
   country VARCHAR(50)
);

-- menu table build
CREATE OR REPLACE TABLE tasty_bytes.source.products
(
   menu_id NUMBER(8,0),
   menu_type_id NUMBER(4,0),
   menu_type VARCHAR(50),
   truck_brand_name VARCHAR(50),
   menu_item_id NUMBER(8,0),
   menu_item_name VARCHAR(50),
   item_category VARCHAR(50),
   item_subcategory VARCHAR(50),
   cost_of_goods_usd NUMBER(8,2),
   sale_price_usd NUMBER(8,2),
   menu_item_health_metrics_obj VARIANT
);

-- truck table build
CREATE OR REPLACE TABLE tasty_bytes.source.trucks
(
   truck_id NUMBER(8,0),
   menu_type_id NUMBER(4,0),
   primary_city VARCHAR(50),
   region VARCHAR(50),
   iso_region VARCHAR(50),
   country VARCHAR(50),
   iso_country_code CHAR(2),
   franchise_flag BOOLEAN,
   year NUMBER(4,0),
   make VARCHAR(50),
   model VARCHAR(50),
   ev_flag BOOLEAN,
   franchise_id NUMBER(8,0),
   truck_opening_date DATE
);

-- order_header table build
CREATE OR REPLACE TABLE tasty_bytes.source.orders_header
(
   order_id NUMBER(12,0),
   truck_id NUMBER(8,0),
   location_id NUMBER(8,0),
   customer_id NUMBER(8,0),
   discount_id NUMBER(8,0),            -- all values are NULL
   shift_id NUMBER(12,0),
   shift_start_time TIME,
   shift_end_time TIME,
   order_channel VARCHAR(50),          -- all values are NULL
   order_ts TIMESTAMP,
   served_ts TIMESTAMP,                -- all values are NULL
   order_currency CHAR(3),
   order_amount NUMBER(4,0),
   order_tax_amount NUMBER(8,2),       -- all values are NULL
   order_discount_amount NUMBER(8,2),  -- all values are NULL
   order_total NUMBER(8,2)
);

-- order_detail table build
CREATE OR REPLACE TABLE tasty_bytes.source.orders_detail
(
   order_detail_id NUMBER(12,0),
   order_id NUMBER(12,0),
   menu_item_id NUMBER(8,0),
   discount_id NUMBER(8,0),       -- all values are NULL
   line_number NUMBER(4,0),
   quantity NUMBER(4,0),
   unit_price NUMBER(8,2),
   price NUMBER(8,2),
   discount_amount NUMBER(8,2)    -- all values are NULL
);

-- customer loyalty table build
CREATE OR REPLACE TABLE tasty_bytes.source.customers
(
   customer_id NUMBER(8,0),
   first_name VARCHAR(50),
   last_name VARCHAR(50),
   city VARCHAR(50),
   country VARCHAR(50),
   postal_code VARCHAR(20),
   preferred_language VARCHAR(50),
   gender VARCHAR(50),
   favourite_brand VARCHAR(100),
   marital_status VARCHAR(50),
   children_count VARCHAR(50),
   sign_up_date DATE,
   birthday_date DATE,
   e_mail VARCHAR(100),
   phone_number VARCHAR(500)
);


/*--
raw zone table load
--*/

-- franchise table load
COPY INTO tasty_bytes.source.franchises
FROM @tasty_bytes.public.s3load/raw_pos/franchise/;

-- location table load
COPY INTO tasty_bytes.source.locations
FROM @tasty_bytes.public.s3load/raw_pos/location/;

-- menu table load
COPY INTO tasty_bytes.source.products
FROM @tasty_bytes.public.s3load/raw_pos/menu/;

-- truck table load
COPY INTO tasty_bytes.source.trucks
FROM @tasty_bytes.public.s3load/raw_pos/truck/;

-- customer_loyalty table load
COPY INTO tasty_bytes.source.customers
FROM @tasty_bytes.public.s3load/raw_customer/customer_loyalty/;

-- order_header table load
COPY INTO tasty_bytes.source.orders_header
FROM @tasty_bytes.public.s3load/raw_pos/order_header/;

-- order_detail table load
COPY INTO tasty_bytes.source.orders_detail
FROM @tasty_bytes.public.s3load/raw_pos/order_detail/;
