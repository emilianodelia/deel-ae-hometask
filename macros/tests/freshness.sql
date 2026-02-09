{% test is_fresh(model, column_name, index, period) %}

with validation as (
    select
        max({{ column_name }}) as last_record
    from {{ model }}
)

select *
from validation
where last_record < timestamp_sub(current_timestamp(), interval {{ index }} {{ period }})

{% endtest %}