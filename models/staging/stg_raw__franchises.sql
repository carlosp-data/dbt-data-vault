with

source as (
    select * from {{ source('raw', 'franchises') }}
),

deduplicated as (

    select *
    from source
    -- franchise_id is not unique in the source: some ids are exact duplicates and others
    -- appear once per city. Keep one deterministic row per franchise.
    qualify row_number() over (partition by franchise_id order by country, city) = 1

),

renamed as (

    select
        cast(franchise_id as integer) as franchise_id,
        trim(first_name) as franchise_first_name,
        trim(last_name) as franchise_last_name,
        -- business key of hub_city, shared with customers, locations and trucks
        trim(city) as city,
        trim(country) as country,
        trim(e_mail) as franchise_email,
        trim(phone_number) as franchise_phone
    from deduplicated

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['franchise_id']) }} as franchise_hk,
        {{ dbt_utils.generate_surrogate_key(['city', 'country']) }} as city_hk,
        {{ dbt_utils.generate_surrogate_key(['city', 'country', 'franchise_id']) }} as franchise_city_hk,
        franchise_id,
        city,
        country,
        franchise_first_name,
        franchise_last_name,
        franchise_email,
        franchise_phone,
        {{ dbt_utils.generate_surrogate_key([
            'franchise_email',
            'franchise_first_name',
            'franchise_last_name',
            'franchise_phone'
        ]) }} as franchise_pii_hashdiff,
        {{ record_source(source('raw', 'franchises')) }} as record_source
    from renamed

)

select * from final
