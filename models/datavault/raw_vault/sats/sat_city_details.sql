{{ sat(
    parent_hk='city_hk',
    hashdiff='city_details_hashdiff',
    payload_columns=[
        'country_code'
    ],
    src_model='stg_raw__locations'
) }}
