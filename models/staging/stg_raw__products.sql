with

source as (
    select * from {{ source('raw', 'products') }}
),

renamed as (

    select
        cast(menu_item_id as integer) as product_id,
        cast(menu_id as integer) as menu_product_id,
        cast(menu_type_id as integer) as menu_type_id,
        trim(menu_type) as menu_type,
        trim(truck_brand_name) as truck_brand_name,
        trim(menu_item_name) as product_name,
        trim(item_category) as product_category,
        trim(item_subcategory) as product_subcategory,
        cost_of_goods_usd,
        sale_price_usd,
        -- the health metrics array always holds exactly one element
        menu_item_health_metrics_obj:menu_item_health_metrics[0]:is_healthy_flag::varchar = 'Y' as is_healthy,
        menu_item_health_metrics_obj:menu_item_health_metrics[0]:is_dairy_free_flag::varchar = 'Y' as is_dairy_free,
        menu_item_health_metrics_obj:menu_item_health_metrics[0]:is_gluten_free_flag::varchar = 'Y' as is_gluten_free,
        menu_item_health_metrics_obj:menu_item_health_metrics[0]:is_nut_free_flag::varchar = 'Y' as is_nut_free,
        menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::array as ingredients
    from source

),

final as (

    select
        {{ hash_key(['product_id']) }} as product_hk,
        {{ hash_key(['menu_type_id']) }} as menu_type_hk,
        {{ hash_key(['menu_type_id', 'product_id']) }} as product_menu_type_hk,
        product_id,
        menu_product_id,
        menu_type_id,
        menu_type,
        truck_brand_name,
        product_name,
        product_category,
        product_subcategory,
        cost_of_goods_usd,
        sale_price_usd,
        is_healthy,
        is_dairy_free,
        is_gluten_free,
        is_nut_free,
        ingredients,
        {{ dbt_utils.generate_surrogate_key([
            "array_to_string(ingredients, '|')",
            'is_dairy_free',
            'is_gluten_free',
            'is_healthy',
            'is_nut_free',
            'menu_product_id',
            'product_category',
            'product_name',
            'product_subcategory'
        ]) }} as product_details_hashdiff,
        {{ dbt_utils.generate_surrogate_key([
            'cost_of_goods_usd',
            'sale_price_usd'
        ]) }} as product_pricing_hashdiff,
        {{ dbt_utils.generate_surrogate_key([
            'menu_type',
            'truck_brand_name'
        ]) }} as menu_type_details_hashdiff,
        {{ record_source(source('raw', 'products')) }} as record_source
    from renamed

)

select * from final
