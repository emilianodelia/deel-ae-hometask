with transactions as (
    select * 
    from {{ ref('stg_globepay__transactions') }}
),

chargebacks as (
    select * 
    from {{ ref('stg_globepay__chargebacks') }}
), 

assign_chargeback_flag as (
    select 
        txns.transaction_id, 
        txns.processed_at, 
        txns.status, 
        txns.is_cvv_provided, 
        txns.country_code, 
        txns.original_currency, 
        txns.usd_settled_amount, 
        txns.exchange_rates_json, 
        case 
            when upper(status)='ACCEPTED'
                then true
            when upper(status)='DECLINED'
                then false 
        end as is_valid, 
        chargebacks.has_chargeback, 
        txns.event_id
    from transactions as txns
    left join chargebacks
        on txns.transaction_id=chargebacks.transaction_id
),

flattened_rates as (
    select
        transaction_id,
        -- Extract the key (such as "USD") and value (1.0) using regex
        regexp_extract(kv_pair, r'"([A-Z]{3})"') as rate_currency,
        cast(regexp_extract(kv_pair, r':([\d\.]+)') as numeric) as rate_value
    from assign_chargeback_flag,
    -- unnest in order to create a row for every currency found in field
    unnest(regexp_extract_all(exchange_rates_json, r'"[A-Z]{3}":[\d\.]+')) as kv_pair
), 

assign_applied_usd_rate as (
    select
        main.*,
        rates.rate_value as usd_exchange_rate
    from assign_chargeback_flag as main
    left join flattened_rates as rates
        on main.transaction_id = rates.transaction_id
        and main.original_currency = rates.rate_currency
)

select * from assign_applied_usd_rate
