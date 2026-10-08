{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}

{{ sat(
    parent_hk='order_hk',
    hashdiff='order_details_hashdiff',
    payload_columns=[
        'order_ts',
        'order_currency',
        'order_amount',
        'order_total'
    ],
    src_model='stg_raw__orders_header'
) }}
