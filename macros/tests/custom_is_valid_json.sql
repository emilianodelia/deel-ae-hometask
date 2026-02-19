{% macro is_valid_json(column_name) %}
    (
        {{ column_name }} is not null
        and trim(to_json_string({{ column_name }})) != ''
    )
{% endmacro %}

{% test custom_is_valid_json(model, column_name) %}
    select *
    from {{ model }}
    where not {{ is_valid_json(column_name) }}
{% endtest %}