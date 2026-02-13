with scope as (
    select *except(
            fx_rates_json, -- not needed, display of GBP rates for a transaction originally made in MXN is not relevant
            event_id -- not needed, transaction_id  is our PK for the fct model
        ) 
    from {{ ref('int_transactions_joined') }}
)

select * from scope