{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}

with

source as (

    -- discount_id, order_channel, served_ts, order_tax_amount and order_discount_amount
    -- are entirely NULL in the source and are not staged
    select
        order_id,
        truck_id,
        location_id,
        customer_id,
        shift_id,
        shift_start_time,
        shift_end_time,
        order_ts,
        order_currency,
        order_amount,
        order_total
    from {{ source('raw', 'orders_header') }}

),

renamed as (

    select
        cast(order_id as integer) as order_id,
        cast(truck_id as integer) as truck_id,
        -- stored as float in the source; all values are whole numbers
        cast(location_id as integer) as location_id,
        -- NULL for orders placed by customers outside the loyalty program
        cast(customer_id as integer) as customer_id,
        cast(shift_id as integer) as shift_id,
        -- the source has no shift date; every order of a shift falls on the same date
        to_date(order_ts) as shift_date,
        shift_start_time,
        shift_end_time,
        to_date(order_ts) as order_date,
        order_ts,
        upper(trim(order_currency)) as order_currency,
        order_amount,
        order_total
    from source

),

final as (

    select
        {{ hash_key(['order_id']) }} as order_hk,
        {{ hash_key(['truck_id']) }} as truck_hk,
        {{ hash_key(['location_id']) }} as location_hk,
        {{ hash_key(['customer_id']) }} as customer_hk,
        {{ hash_key(['shift_id']) }} as shift_hk,
        {{ hash_key(['customer_id', 'order_id', 'shift_id']) }} as order_shift_customer_hk,
        {{ hash_key(['location_id', 'shift_id', 'truck_id']) }} as shift_truck_location_hk,
        order_id,
        truck_id,
        location_id,
        customer_id,
        shift_id,
        shift_date,
        shift_start_time,
        shift_end_time,
        order_date,
        order_ts,
        order_currency,
        order_amount,
        order_total,
        {{ dbt_utils.generate_surrogate_key([
            'order_amount',
            'order_currency',
            'order_date',
            'order_total',
            'order_ts'
        ]) }} as order_details_hashdiff,
        {{ dbt_utils.generate_surrogate_key([
            'shift_date',
            'shift_end_time',
            'shift_start_time'
        ]) }} as shift_details_hashdiff,
        {{ record_source(source('raw', 'orders_header')) }} as record_source
    from renamed

)

select * from final
