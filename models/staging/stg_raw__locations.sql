with

source as (
    select * from {{ source('raw', 'locations') }}
),

renamed as (

    select
        cast(location_id as integer) as location_id,
        trim(placekey) as placekey,
        trim(location) as location_name,
        -- business key of hub_city, shared with customers, franchises and trucks
        trim(city) as city,
        trim(country) as country,
        trim(region) as location_region,
        upper(trim(iso_country_code)) as location_country_code
    from source

),

final as (

    select
        {{ hash_key(['location_id']) }} as location_hk,
        {{ hash_key(['city', 'country']) }} as city_hk,
        {{ hash_key(['city', 'country', 'location_id']) }} as location_city_hk,
        location_id,
        city,
        country,
        placekey,
        location_name,
        location_region,
        location_country_code,
        {{ dbt_utils.generate_surrogate_key([
            'location_country_code',
            'location_name',
            'location_region',
            'placekey'
        ]) }} as location_details_hashdiff,
        {{ record_source(source('raw', 'locations')) }} as record_source
    from renamed

)

select * from final
