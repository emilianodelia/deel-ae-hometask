{{ config(severity='warn') }}

select 
    max(processed_at) as latest_processed_at_date, 
    date_diff(max(date(processed_at)), current_date(), day) as days_since_last_record_load, 
    'base_globepay_transactions' as model
from {{ ref('base_globepay_transactions') }}
-- leaving it as is to make sure the warning is triggered correctly
where max(processed_at)<current_date()