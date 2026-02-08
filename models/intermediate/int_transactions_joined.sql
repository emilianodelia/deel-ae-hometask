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
        txns.local_currency, 
        txns.settled_amount_usd, 
        txns.fx_rates_json, 
        case 
            when upper(status)='ACCEPTED'
                then true
            when upper(status)='DECLINED'
                then false 
        end as is_valid, 
        chargebacks.has_chargeback, 
       case 
            when chargebacks.transaction_id is not null 
                then true
            else false
        end as has_chargeback_evidence, 
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
    unnest(regexp_extract_all(fx_rates_json, r'"[A-Z]{3}":[\d\.]+')) as kv_pair
), 

assign_applied_usd_rate as (
    select
        main.*,
        rates.rate_value as fx_rate_to_usd, 
        round(settled_amount_usd * nullif(rates.rate_value, 0), 2) as local_amount,
    from assign_chargeback_flag as main
    left join flattened_rates as rates
        on main.transaction_id=rates.transaction_id
        and main.local_currency=rates.rate_currency
),

column_arrangement as (
    select
        transaction_id, 
        processed_at, 
        status, 
        is_cvv_provided, 
        country_code, 
        local_currency, 
        local_amount,
        settled_amount_usd, 
        fx_rate_to_usd, 
        is_valid, 
        has_chargeback, 
        has_chargeback_evidence, 
        fx_rates_json,
        event_id
    from assign_applied_usd_rate
)

select * from column_arrangement
