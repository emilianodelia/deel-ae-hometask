with transactions as (
    select * 
    from {{ ref('base_globepay_transactions') }}
),

chargebacks as (
    select * 
    from {{ ref('base_globepay_chargebacks') }}
), 

assign_chargeback_flag as (
    select 
        txns.transaction_id, 
        txns.processed_at, 
        txns.transaction_status, 
        txns.is_cvv_provided, 
        txns.country_code, 
        txns.local_currency, 
        txns.settled_amount_usd, 
        txns.fx_rates_json, 
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
    from transactions as txns
    left join chargebacks
        on txns.transaction_id=chargebacks.transaction_id
)

select * from assign_chargeback_flag

