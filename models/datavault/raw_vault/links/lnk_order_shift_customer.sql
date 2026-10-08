{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}

{{ link(
    link_hk='order_shift_customer_hk',
    fk_columns=['order_hk', 'shift_hk', 'customer_hk'],
    src_models=['stg_raw__orders_header']
) }}
