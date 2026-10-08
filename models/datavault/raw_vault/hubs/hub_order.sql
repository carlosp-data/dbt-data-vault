{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}

{{ hub(
    hk='order_hk',
    bk_columns=['order_id'],
    src_models=['stg_raw__orders_header']
) }}
