{{ config(severity='error') }}

select *
from {{ ref('build_base_transactions') }}
where local_currency not in (
    select currency_code 
    from {{ ref('accepted_currencies') }}
    where provider='GLOBEPAY'
)