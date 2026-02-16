with renaming as (
    select 
        external_ref as transaction_id, 
        cast(chargeback as boolean) as has_chargeback
    from {{ ref('chargeback_report_raw') }}
)

select * from renaming

