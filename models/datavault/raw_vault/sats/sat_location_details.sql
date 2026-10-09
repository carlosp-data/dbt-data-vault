{{ sat(
    parent_hk='location_hk',
    hashdiff='location_details_hashdiff',
    payload_columns=[
        'placekey',
        'location_name',
        'location_region'
    ],
    src_model='stg_raw__locations'
) }}
