{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}

{{ link(
    link_hk='order_line_hk',
    fk_columns=['order_hk', 'product_hk'],
    src_models=['stg_raw__orders_detail'],
    child_key_columns=['line_number']
) }}
