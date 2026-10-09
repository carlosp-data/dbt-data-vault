{{ sat(
    parent_hk='truck_hk',
    hashdiff='truck_details_hashdiff',
    payload_columns=[
        'truck_region',
        'is_franchise',
        'is_ev',
        'truck_make',
        'truck_model',
        'truck_model_year',
        'truck_opening_date'
    ],
    src_model='stg_raw__trucks'
) }}
