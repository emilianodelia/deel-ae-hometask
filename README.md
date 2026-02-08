# Deel x Globepay: Account Funding Analysis

## Overview
This repository contains the Analytics Engineering solution for processing and analyzing credit/debit card funding transactions handled by Globepay

## Business Context
Deel leverages Globepay as a global payment processor to allow clients to fund their accounts. This project focuses on:

Standardizing multi-currency transaction data.

Mapping Globepay API responses to Deel’s internal account funding structures.

Providing visibility into transaction success rates and processing performance across different countries.

# Part 1 - Data Ingestion and Architecture Design
For the first part of the challenge, please ingest and model the source data

## 1. Preliminary data exploration

## 2. Summary of your model architecture

Architecture Overview

The architecture is divided into four standalone layers to ensure scalability, data quality, and clear lineage. 

_Note on Implementation:_ All models in this project were fully materialized within BigQuery

```bash
models
├── seeds/ # csv files / ingestion layer 
│   ├── acceptance_report_raw.csv
│   └── charge_back_report_raw.csv
│
└── models/
    ├── 1_staging/              
    │   ├── _stg_globepay__models.yml
    │   ├── stg_globepay__chargebacks.sql
    │   └── stg_globepay__transactions.sql
    │
    ├── 2_intermediate/            
    │   ├── _int_globepay__models.yml
    │   └── int_transactions_joined.sql
    │
    └── 3_marts/                 
        └── payment_management
            ├── _marts_payment_management__models.yml
            └── fct_transactions.sql
```

### Description per Layer 

### 1. Ingestion Layer
* **Role**: Ingestion for raw transaction acceptance and chargedbak data
* **Action**: Static CSV files are loaded into BigQuery as raw tables using dbt seed
* **Notes**: EDA did not show messy data or broken data type formats. Testing was applied anyways to ensure data quality in this first step of the pipeline
### 2. Staging Layer
* **Role**: Cleaning & Standardizing.Action: We create views that rename columns to a consistent snake_case (e.g., external_ref becomes transaction_id), cast timestamps, and clean up string values
* **Why**: This layer ensures that if the source column names change, we only have to fix them in one place
### 3. Intermediate Layer
* **Role**: Business logic integration and relevant transformation
* **Action**: This is where the heavy lifting happens
* **JSON Processing**: Extracting nested exchange rates from the string-based rates column in order to display the USD exchange rate that was used in the conversion
* **Joining**: Performing a LEFT JOIN between transactions and chargebacks.
* **Flagging**: Creating the has_chargeback boolean logic
* **Why**: We keep this logic out of the final Mart to make the final table "thin" and easy to query
### 4. Marts Layer
* **Role**: Consumption & Reporting.
* **Action**: Building the final `fct_transactions` capable of answering the business questions defined in the task when queried 
* **Why**: This table is optimized for BI tools and end-users. It is tested for uniqueness and nulls to ensure financial reporting accuracy

### Data Limitations & Assumptions
* **Assumption on Chargeback Status**: I have modeled the `has_chargeback` flag as a Boolean. While a TRUE value indicates a confirmed dispute in the source data, a FALSE value indicates the absence of a record in the provided `chargeback_report`. In a live production environment, I would distinguish between a 'Confirmed Negative' and 'No Data Received,' but for the scope of this task, I have treated unmatched records as non-disputed to facilitate aggregate reporting. (Nulls can be tricky to hanlde in BI tools such as Looker)

## 3. Lineage graphs

The graph below shows the flow from raw seeds to the final fact table.

<img src="docs/dbt_architecture_lineage.png" width="700" alt="dbt Lineage Graph">

## 4. Tips around macros, data validation, and documentation

### Data Quality and Validations
* `uniqueness` and `not_null` testing was applied to `transaction_id` and `external_ref` across staging and marts to ensure no duplicates were generated during joins or other operations. This set of tests are usefull for avoiding duplication or distortion of any critical financial metric
* `relationship` testing was used to ensure that 100% of the IDs in the `chargeback_report` actually exist in the `acceptance_report`.
* `accepted_values` testing was used to validate that statuses (like state) fall within the expected set of values that are seen in our source data 

### Documentation
* yml descriptions were included in every model and column and I made sure to transfer that information into the materialized models in BQ
* CTEs in SQL are key to make the transformation steps easy for anyone to follow. In my day-to-day I also welcome the inclusion of comments within the code. Our entreprise level repository has a ton of collaborators and therefore it is always nice to pick up were someone left off with some context and SQL logic explanations
* The project is fully compatible with `dbt docs generate` which provides a searchable data catalog for anyone that needs or want to check the lineages or data flows. Not everyone wants to clone a repo and make some research from the inside. This kind of UI is quite helpful
* Hot Tip! To avoid copy/pasting the column names again and again across every layer a `markdown` file can be created to centralize all common column definitions and assign them when needed. Initially I avoided using this in the repo because I assumed you wanted to the see the definitions in the yml themselves and not in separate doc

Example

md file would look like this 
```md
{% docs external_ref %}
The unique transaction identifier generated by the Globepay API. 
This is the primary join key across all Globepay reports.
{% enddocs %}

{% docs transaction_state %}
The final business outcome of the payment attempt. 
Common values include `ACCEPTED`, `DECLINED`, or `ERROR`.
{% enddocs %}
```

yml files would look like this 

```yml
version: 2

seeds:
  - name: chargeback_report_raw
    columns:
      - name: external_ref
        description: "{{ doc('external_ref') }}" # <--- Pulls from the .md file

models:
  - name: stg_globepay__transactions
    columns:
      - name: external_ref
        description: "{{ doc('external_ref') }}"
      - name: state
        description: "{{ doc('transaction_state') }}"
```

# Part 2 - Final Model Testing
For the second part of the challenge, please develop a production version of the model for the
Data Analyst to utilize. This model should be able to answer these three questions at a
minimum

Final Model -----> `fct_transactions`

1. What is the acceptance rate over time?

```sql
with calculations as (
  select 
    date(date_trunc(processed_at, month)) as year_month_txn_date,
    sum(case when status='DECLINED' then 0 else 1 end)  as total_declined_transactions, 
    sum(case when status!='DECLINED' then 0 else 1 end) as total_accepted_transactions,
    count(transaction_id) as total_transactions
  from deel-task-12345.payment_management.fct_transactions 
  group by year_month_txn_date 
)

select 
  *, 
  round(safe_divide(total_accepted_transactions, total_transactions)*100, 2) as acceptance_rate_pct
from calculations
order by year_month_txn_date desc
```

<img src="docs/query_results/acceptance_rate_over_time.png" width="700">

2. List the countries where the amount of declined transactions went over $25M
```sql
with declined_transactions_scope as (
  select 
    country_code, 
    sum(usd_settled_amount) as total_settled_amount_usd_for_declined_txns
  from deel-task-12345.payment_management.fct_transactions 
  where status='DECLINED'
group by country_code 
)

select * from declined_transactions_scope 
where total_settled_amount_usd_for_declined_txns>25000000
```

<img src="docs/query_results/countries_declined_txns_over_25_million.png" width="700">

3. Which transactions are missing chargeback data?

```sql
select count(*) as txns_with_no_chargeback_record
from deel-task-12345.payment_management.fct_transactions 
where has_chargeback is null
```
<img src="docs/query_results/txns_with_no_chargeback_report.png" width="700">
