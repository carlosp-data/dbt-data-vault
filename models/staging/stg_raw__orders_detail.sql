{{ config(
    snowflake_warehouse='compute_big',
    tags=['large_table']
) }}

with

source as (

    -- "discount_id" and "discount_amount" are entirely NULL
    -- in the source and are not staged
    select
        order_detail_id,
        order_id,
        menu_item_id,
        line_number,
        quantity,
        unit_price,
        price
    from {{ source('raw', 'orders_detail') }}

),

renamed as (

    select
        cast(order_detail_id as integer) as order_detail_id,
        cast(order_id as integer) as order_id,
        cast(menu_item_id as integer) as product_id,
        cast(line_number as integer) as line_number,
        cast(quantity as integer) as quantity,
        unit_price,
        -- always equals quantity * unit_price
        price as line_amount
    from source

),

final as (

    select
        {{ hash_key(['order_id']) }} as order_hk,
        {{ hash_key(['product_id']) }} as product_hk,
        {{ hash_key(['line_number', 'order_id', 'product_id']) }} as order_line_hk,
        order_detail_id,
        order_id,
        product_id,
        line_number,
        quantity,
        unit_price,
        line_amount,
        {{ dbt_utils.generate_surrogate_key([
            'line_amount',
            'order_detail_id',
            'quantity',
            'unit_price'
        ]) }} as order_line_details_hashdiff,
        {{ record_source(source('raw', 'orders_detail')) }} as record_source
    from renamed

)

select * from final
