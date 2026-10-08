-- stg_raw__orders_header repeats each shift once per order; the macro keeps one row per key
{{ link(
    link_hk='shift_truck_location_hk',
    fk_columns=['shift_hk', 'truck_hk', 'location_hk'],
    src_models=['stg_raw__orders_header']
) }}
