with scope as (
    select 
        external_ref as external_id, -- needed
        ref as id, -- internal ID for future joins with enterprise level data
        cast(date_time as timestamp) as processed_at, --The timestamp of the transaction.
        upper(state) as status, --The binary state of the transaction
        cast(cvv_provided as boolean) as is_cvv_provided,
        country as country_code, --The two-character ISO country code of the issued card
        currency as original_currency, --The three-character ISO currency code in which the transaction was originally processed
        cast(safe_divide(amount, 100) as numeric) as settled_usd_amount, --The USD amount for the transaction (in minor units)
        rates as exchange_rates_json
    from {{ ref('acceptance_report_raw') }}
)

select * from scope
