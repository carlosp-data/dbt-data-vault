{#-
    Loads an effectivity satellite on a link, insert-only. It records when a link row becomes
    active or inactive for its driving key, for example which `lnk_customer_city` row is the
    customer's current city. Each staged row is the current relationship of its driving key.
    A load inserts:

    - `is_active = true` for a staged link key that is not in the satellite yet, or whose
      latest row is inactive (the relationship is new or came back);
    - `is_active = false` for an active link key whose driving key now arrives with another
      link key (the relationship ended).

    A driving key missing from the batch keeps its current relationship: the sources are full
    snapshots without delete markers, so absence is not treated as an end.

    The link model must hold the driving key column, so the satellite only stores the link key.

        {{ eff_sat(
            link_hk='customer_city_hk',
            driving_key='customer_hk',
            link_model='lnk_customer_city',
            src_model='stg_raw__customers'
        ) }}
-#}
{% macro eff_sat(link_hk, driving_key, link_model, src_model) -%}

-- the link is read only on incremental runs; declare the dependency for every run
-- depends_on: {{ ref(link_model) }}

with

staged as (

    select distinct
        {{ link_hk }},
        {{ driving_key }},
        record_source
    from {{ ref(src_model) }}

),
{%- if is_incremental() %}

latest as (

    -- latest status of every link key already in the satellite, with its driving key
    select
        esat.{{ link_hk }},
        lnk.{{ driving_key }},
        esat.is_active
    from {{ this }} as esat
    inner join {{ ref(link_model) }} as lnk
        on esat.{{ link_hk }} = lnk.{{ link_hk }}
    qualify row_number() over (partition by esat.{{ link_hk }} order by esat.load_dts desc) = 1

),

opened as (

    -- relationships that are new, or were inactive and are current again
    select
        staged.{{ link_hk }},
        true as is_active,
        staged.record_source
    from staged
    left join latest
        on staged.{{ link_hk }} = latest.{{ link_hk }}
    where latest.{{ link_hk }} is null
        or not latest.is_active

),

closed as (

    -- active relationships whose driving key now points to another link row
    select
        latest.{{ link_hk }},
        false as is_active,
        staged.record_source
    from latest
    inner join staged
        on latest.{{ driving_key }} = staged.{{ driving_key }}
    where latest.is_active
        and latest.{{ link_hk }} != staged.{{ link_hk }}

),

changes as (

    select
        {{ link_hk }},
        is_active,
        record_source
    from opened

    union all

    select
        {{ link_hk }},
        is_active,
        record_source
    from closed

),
{%- else %}

changes as (

    -- first load: every staged relationship is active
    select
        {{ link_hk }},
        true as is_active,
        record_source
    from staged

),
{%- endif %}

final as (

    select
        {{ link_hk }},
        {{ load_dts() }} as load_dts,
        is_active,
        record_source
    from changes

)

select * from final

{%- endmacro %}
