{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}

{{ link(
    link_hk='order_truck_location_customer_shift_hk',
    fk_columns=['order_hk', 'truck_hk', 'location_hk', 'customer_hk', 'shift_hk'],
    src_models=['stg_raw__orders_header']
) }}
