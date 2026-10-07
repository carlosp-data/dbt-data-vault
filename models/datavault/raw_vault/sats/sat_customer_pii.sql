{{ sat(
    parent_hk='customer_hk',
    hashdiff='customer_pii_hashdiff',
    payload_columns=[
        'cust_first_name',
        'cust_last_name',
        'cust_email',
        'cust_phone',
        'cust_birth_date',
        'cust_zipcode'
    ],
    src_model='stg_raw__customers'
) }}
