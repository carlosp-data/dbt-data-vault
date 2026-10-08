-- stg_raw__orders_header repeats each shift once per order; the macro keeps one row per key
{{ hub(
    hk='shift_hk',
    bk_columns=['shift_id'],
    src_models=['stg_raw__orders_header']
) }}
