{{ sat(
    parent_hk='customer_hk',
    hashdiff='customer_profile_hashdiff',
    payload_columns=[
        'cust_gender',
        'cust_language',
        'cust_marital_status',
        'cust_children_nr',
        'cust_sign_up_date'
    ],
    src_model='stg_raw__customers'
) }}
