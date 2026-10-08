{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}

{{ sat(
    parent_hk='order_line_hk',
    hashdiff='order_line_details_hashdiff',
    payload_columns=[
        'order_detail_id',
        'quantity',
        'unit_price',
        'line_amount'
    ],
    src_model='stg_raw__orders_detail'
) }}
