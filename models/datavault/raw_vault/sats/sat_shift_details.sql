-- stg_raw__orders_header repeats each shift once per order; the macro loads distinct rows
{{ sat(
    parent_hk='shift_hk',
    hashdiff='shift_details_hashdiff',
    payload_columns=[
        'shift_date',
        'shift_start_time',
        'shift_end_time'
    ],
    src_model='stg_raw__orders_header'
) }}
