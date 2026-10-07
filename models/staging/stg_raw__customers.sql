with

source as (
    select * from {{ source('raw', 'customers') }}
),

renamed as (

    select
        cast(customer_id as integer) as customer_id,
        trim(first_name) as cust_first_name,
        trim(last_name) as cust_last_name,
        trim(e_mail) as cust_email,
        trim(phone_number) as cust_phone,
        birthday_date as cust_birth_date,
        trim(postal_code) as cust_zipcode,
        -- business key of hub_city, shared with franchises, locations and trucks
        trim(city) as city,
        trim(country) as country,
        trim(gender) as cust_gender,
        trim(preferred_language) as cust_language,
        trim(favourite_brand) as cust_fav_brand,
        trim(marital_status) as cust_marital_status,
        -- text domain: '0'..'4', '5+' or 'Undisclosed'; kept as-is, decoded downstream
        trim(children_count) as cust_children_nr,
        sign_up_date as cust_sign_up_date
    from source

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_hk,
        {{ dbt_utils.generate_surrogate_key(['city', 'country']) }} as city_hk,
        {{ dbt_utils.generate_surrogate_key(['city', 'country', 'customer_id']) }} as customer_city_hk,
        customer_id,
        city,
        country,
        cust_first_name,
        cust_last_name,
        cust_email,
        cust_phone,
        cust_birth_date,
        cust_zipcode,
        cust_gender,
        cust_language,
        cust_fav_brand,
        cust_marital_status,
        cust_children_nr,
        cust_sign_up_date,
        {{ dbt_utils.generate_surrogate_key([
            'cust_birth_date',
            'cust_email',
            'cust_first_name',
            'cust_last_name',
            'cust_phone',
            'cust_zipcode'
        ]) }} as customer_pii_hashdiff,
        {{ dbt_utils.generate_surrogate_key([
            'cust_children_nr',
            'cust_fav_brand',
            'cust_gender',
            'cust_language',
            'cust_marital_status',
            'cust_sign_up_date'
        ]) }} as customer_profile_hashdiff,
        {{ record_source(source('raw', 'customers')) }} as record_source
    from renamed

)

select * from final
