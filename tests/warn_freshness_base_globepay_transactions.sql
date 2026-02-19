select count(*) as stale_records
from {{ ref('base_globepay_transactions') }}
where cast(processed_at as date) < '2019-01-01'