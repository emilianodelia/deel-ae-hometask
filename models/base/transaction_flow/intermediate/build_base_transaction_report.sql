{{ config(materialized='table') }}

select * from {{ ref('int_base_transaction_report_1_scope_definition') }}
