{{ sat(
    parent_hk='product_hk',
    hashdiff='product_pricing_hashdiff',
    payload_columns=[
        'cost_of_goods_usd',
        'sale_price_usd'
    ],
    src_model='stg_raw__products'
) }}
