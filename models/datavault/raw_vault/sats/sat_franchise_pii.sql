{{ sat(
    parent_hk='franchise_hk',
    hashdiff='franchise_pii_hashdiff',
    payload_columns=[
        'franchise_first_name',
        'franchise_last_name',
        'franchise_email',
        'franchise_phone'
    ],
    src_model='stg_raw__franchises'
) }}
