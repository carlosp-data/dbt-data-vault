{{ sat(
    parent_hk='product_hk',
    hashdiff='product_details_hashdiff',
    payload_columns=[
        'menu_product_id',
        'product_name',
        'product_category',
        'product_subcategory',
        'is_healthy',
        'is_dairy_free',
        'is_gluten_free',
        'is_nut_free',
        'ingredients'
    ],
    src_model='stg_raw__products'
) }}
