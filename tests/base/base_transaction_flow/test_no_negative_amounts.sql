-- Account funding transactions should always carry a positive amount
-- A negative value would indicate that something is up
-- For this case, I'm going to exclude negative values from upstream
{{ config(severity='warn') }}

select *
from {{ ref('build_base_globepay_transactions') }}
where settled_amount < 0