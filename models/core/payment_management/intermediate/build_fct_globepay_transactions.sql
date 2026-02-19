with scope as (
    select 
        transaction_id,
        event_id,
        processed_at,
        transaction_status,
        is_cvv_provided,
        country_code,
        local_currency,
        settled_amount,
        fx_rates_json  
    from {{ ref('base_globepay_transactions') }}
), 

normalize_to_usd as (
    select
        * except(fx_rates_json), -- Exclude column in json format
        lax_float64(fx_rates_json[local_currency]) AS exchange_rate,
        round(settled_amount / nullif(lax_float64(fx_rates_json[local_currency]), 0), 2) as usd_settled_amount
    from scope
), 

assign_chargeback_flag as (
    select 
        txns.transaction_id, 
        txns.processed_at, 
        txns.transaction_status, 
        txns.is_cvv_provided, 
        txns.country_code, 
        txns.local_currency, 
        txns.usd_settled_amount, 
        txns.exchange_rate,
        case 
            when upper(transaction_status)='ACCEPTED'
                then true
            when upper(transaction_status)='DECLINED'
                then false 
        end as is_valid, 
        chargebacks.has_chargeback, 
       case 
            when chargebacks.transaction_id is not null 
                then true
            else false
        end as has_chargeback_evidence, 
        txns.event_id
    from normalize_to_usd as txns
    left join {{ ref('base_globepay_chargebacks') }} as chargebacks
        on txns.transaction_id=chargebacks.transaction_id
)

select * from assign_chargeback_flag