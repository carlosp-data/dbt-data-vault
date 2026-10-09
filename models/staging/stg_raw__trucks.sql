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
        -- iso_region is not an ISO code but the region name used by locations.region;
        -- region (a coarser, inconsistent naming) is not staged
        trim(iso_region) as truck_region,
        -- iso_country_code is not staged: it is an attribute of the city (sat_city_details)
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
        {{ hash_key(['truck_id']) }} as truck_hk,
        {{ hash_key(['franchise_id']) }} as franchise_hk,
        {{ hash_key(['menu_type_id']) }} as menu_type_hk,
        {{ hash_key(['city', 'country']) }} as city_hk,
        {{ hash_key(['franchise_id', 'truck_id']) }} as truck_franchise_hk,
        {{ hash_key(['menu_type_id', 'truck_id']) }} as truck_menu_type_hk,
        {{ hash_key(['city', 'country', 'truck_id']) }} as truck_city_hk,
        truck_id,
        menu_type_id,
        franchise_id,
        city,
        country,
        truck_region,
        is_franchise,
        is_ev,
        truck_make,
        truck_model,
        truck_model_year,
        truck_opening_date,
        {{ dbt_utils.generate_surrogate_key([
            'is_ev',
            'is_franchise',
            'truck_make',
            'truck_model',
            'truck_model_year',
            'truck_opening_date',
            'truck_region'
        ]) }} as truck_details_hashdiff,
        {{ record_source(source('raw', 'trucks')) }} as record_source
    from renamed

)

select * from final
