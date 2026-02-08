with renaming as (
    select 
        external_ref as transaction_id,
        ref as event_id,
        cast(date_time as timestamp) as processed_at,
        upper(state) as status,
        cast(cvv_provided as boolean) as is_cvv_provided,
        country as country_code,
        currency as original_currency,
        cast(amount as numeric) as usd_settled_amount,
        rates as exchange_rates_json
    from {{ ref('acceptance_report_raw') }}
)

select * from renaming
