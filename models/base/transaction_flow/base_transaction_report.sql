{{ config(materialized='table') }}

select * from {{ ref('build_base_transaction_report') }}
