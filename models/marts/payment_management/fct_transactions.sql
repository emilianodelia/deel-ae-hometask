with scope as (
    select *except(
            exchange_rates_json, 
            event_id
        ) 
    from {{ ref('int_transactions_joined') }}
)

select * from scope
