-- stg_raw__products repeats each menu type once per product; the macro loads distinct rows
{{ sat(
    parent_hk='menu_type_hk',
    hashdiff='menu_type_details_hashdiff',
    payload_columns=[
        'menu_type',
        'truck_brand_name'
    ],
    src_model='stg_raw__products'
) }}
