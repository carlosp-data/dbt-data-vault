{{ hub(
    hk='city_hk',
    bk_columns=['city', 'country'],
    src_models=[
        'stg_raw__locations',
        'stg_raw__trucks',
        'stg_raw__franchises',
        'stg_raw__customers'
    ]
) }}
