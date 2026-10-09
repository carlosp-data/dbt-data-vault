with

source as (
    select * from {{ source('raw', 'franchises') }}
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
    from source

),

final as (

    select
        {{ hash_key(['franchise_id']) }} as franchise_hk,
        {{ hash_key(['city', 'country']) }} as city_hk,
        {{ hash_key(['city', 'country', 'franchise_id']) }} as franchise_city_hk,
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
