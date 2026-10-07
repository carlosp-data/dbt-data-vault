with

source as (
    select * from {{ source('raw', 'trucks') }}
),

renamed as (

    select
        cast(truck_id as integer) as truck_id,
        cast(menu_type_id as integer) as menu_type_id,
        cast(franchise_id as integer) as franchise_id,
        -- business key of hub_city, shared with customers, franchises and locations
        trim(primary_city) as city,
        trim(country) as country,
        trim(region) as truck_region,
        trim(iso_region) as truck_region_code,
        upper(trim(iso_country_code)) as truck_country_code,
        -- flags are stored as 0/1 numbers in the source
        franchise_flag = 1 as is_franchise,
        ev_flag = 1 as is_ev,
        trim(make) as truck_make,
        trim(model) as truck_model,
        cast(year as integer) as truck_model_year,
        truck_opening_date
    from source

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['truck_id']) }} as truck_hk,
        {{ dbt_utils.generate_surrogate_key(['franchise_id']) }} as franchise_hk,
        {{ dbt_utils.generate_surrogate_key(['menu_type_id']) }} as menu_type_hk,
        {{ dbt_utils.generate_surrogate_key(['city', 'country']) }} as city_hk,
        {{ dbt_utils.generate_surrogate_key(['franchise_id', 'truck_id']) }} as truck_franchise_hk,
        {{ dbt_utils.generate_surrogate_key(['menu_type_id', 'truck_id']) }} as truck_menu_type_hk,
        {{ dbt_utils.generate_surrogate_key(['city', 'country', 'truck_id']) }} as truck_city_hk,
        truck_id,
        menu_type_id,
        franchise_id,
        city,
        country,
        truck_region,
        truck_region_code,
        truck_country_code,
        is_franchise,
        is_ev,
        truck_make,
        truck_model,
        truck_model_year,
        truck_opening_date,
        {{ dbt_utils.generate_surrogate_key([
            'is_ev',
            'is_franchise',
            'truck_country_code',
            'truck_make',
            'truck_model',
            'truck_model_year',
            'truck_opening_date',
            'truck_region',
            'truck_region_code'
        ]) }} as truck_hashdiff,
        {{ record_source(source('raw', 'trucks')) }} as record_source
    from renamed

)

select * from final
