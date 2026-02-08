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
)

select * from assign_chargeback_flag
