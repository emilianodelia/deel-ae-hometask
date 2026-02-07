{{ config(materialized='table') }}

with acceptance_rate_scope as (
    select 
        external_ref as transaction_id,
        cast(date_time as timestamp) as processed_at, --The timestamp of the transaction.
        upper(state) as status, --The binary state of the transaction
        cast(cvv_provided as boolean) as is_cvv_provided,
        country as country_code, --The two-character ISO country code of the issued card
        currency as original_currency, --The three-character ISO currency code in which the transaction was originally processed
        cast(amount as numeric) as settled_usd_amount, --The USD amount for the transaction (in minor units)
        rates as exchange_rates_json, 
        case 
            when upper(state)='ACCEPTED'
                then true
            when upper(state)='DECLINED'
                then false 
        end as is_valid, 
        ref as event_id
    from {{ ref('acceptance_report_raw') }}
), 

charge_back_report_scope as (
    select 
        external_ref as transaction_id, 
        cast(chargeback as boolean) as has_chargeback
    from {{ ref('chargeback_report_raw') }}
), 

assign_chargeback_flag as (
    select 
        txns.transaction_id, 
        txns.processed_at, 
        txns.status, 
        txns.is_cvv_provided, 
        txns.country_code, 
        txns.original_currency, 
        txns.settled_usd_amount, 
        txns.exchange_rates_json, 
        txns.is_valid, 
        txns.event_id, 
        chargeback.has_chargeback
    from acceptance_rate_scope as txns
    left join charge_back_report_scope as chargeback
        using (transaction_id)
)

select * from assign_chargeback_flag
