# Deel <> Analytics Engineering Challenge

## Business Context
Deel clients can add funds to their Deel account using their credit and debit cards. Deel has partnered with Globepay to process all of these account funding credit and debit card transactions. Globepay is an industry-leading global payment processor and is able to process payments in many currencies from cards domiciled in many countries.

Deel has connectivity into Globepay using their API. Deel clients provide their credit and debit details within the Deel web application, Deel systems pass those credentials along with any relevant transaction details to Globepay for processing

# `Part I - Data Ingestion and Architecture Design`

## `1. Preliminary Data Exploration`

### Transaction Acceptance Report
notebook path: `analyses/acceptance_rate_eda.ipynb`

```md
Total records: 5430
Total columns: 11

Min transaction date: `2019-01-01T00:00:00.000Z`
Max transaction date: `2019-06-30T19:12:00.000Z`

Duplicate external refs: 0
Duplicate refs: 0
Rows with broken json rates: 0

Nulls per Column
external_ref    0
status          0
source          0
ref             0
date_time       0
state           0
cvv_provided    0
amount          0
country         0
currency        0
rates           0
```

<img src="analyses/eda_graphics/distribution_grid.png" width="700">

<img src="analyses/eda_graphics/amount_field_distributions.png" width="700">


### Chargeback Report

notebook path: `analyses/chargeback_report_eda.ipynb`

```md
Total records: 5430
Total columns: 4

Duplicate external refs: 0

Nulls per Column
external_ref    0
status          0
source          0
chargeback      0
```

<img src="analyses/eda_graphics/chargeback_distribution_grid.png" width="700">

### Key Observations
* No null or missing values were found across both datasets
* Transactional data covers 6 months of 2019
* A consistent universe of 5430 records is maintained across both reports
* `status` and `source` columns were deprioritised as they carry no analytical value for this task
* **Source data anomaly detected in FX Rates:** Although EDA in python reported no broken JSON records, some warnings/error were triggered during development which revealed that `safe.parse_json()` fails silently on floats with a lot of decimals (Example: `1.4060447923604744`)
  * This was resolved by applying `wide_number_mode => 'round'` during parsing 
  * This is flagged as a known limitation and recommended for further review with the Globepay team to discuss whether a higher precision format can be agreed upon at the source level
  * As long as all incoming rate jsons stay within the same decimal precision range, the parsing will work, any deviations from an common format will cause the pipeline to break

## `2. Summary of your model architecture`

The architecture is divided into 2 standalone layers (marts would be developed by the Analysts) to ensure scalability and clear lineage. Within the base layer, models are grouped by source name rather than concept, for example, all Globepay models live under `base/globepay/`, so that onboarding a new payment processor in the future is as simple as adding a new source folder alongside it, with no restructuring required.

```plaintext

//////////////////////////////////////////////////////

models
├── base
│   └── globepay
│       ├── chargebacks
│       │   ├── _base_chargebacks.yml
│       │   ├── base_chargebacks.sql
│       │   └── intermediate
│       │       ├── _build_base_chargebacks.yml
│       │       └── build_base_chargebacks.sql
│       └── transactions
│           ├── _base_transactions.yml
│           ├── base_transactions.sql
│           └── intermediate
│               ├── _build_base_transactions.yml
│               └── build_base_transactions.sql
├── core
│   └── payment_management
│       ├── _fct_globepay_transactions.yml
│       ├── fct_globepay_transactions.sql
│       └── intermediate
│           ├── _build_fct_globepay_transactions.yml
│           └── build_fct_globepay_transactions.sql
└── globepay_column_descriptions.md

//////////////////////////////////////////////////////

tests
├── base
│   └── base_transaction_flow
│       ├── test_accepted_currencies.sql
│       └── test_no_negative_amounts.sql
└── warn_freshness_base_globepay_transactions.sql

//////////////////////////////////////////////////////
```

### Description per Layer 

## `1. Ingestion Layer`
* Loads static CSV files into BigQuery as raw seeds
* Testing applied at this stage despite clean EDA results — pipelines should never assume source quality
* As the project grows, refresh cadence and automated ingestion triggers should be documented — static loads are often where pipelines become brittle at scale

## `2. Base Layer`
* Cleans and standardizes data based on enterprise naming conventions, renaming columns and enforcing data types
* Acts as a schema contract, if a source column changes, the fix is applied in one place only
* Historical models and transaction versioning are preserved for audit purposes
* Each model has a preceding `build_` intermediate step that acts as a **protective barrier**. All data quality tests run exclusively at this stage, bad data is caught before it ever reaches the final models that analysts and downstream consumers depend on

## `3. Core Layer`
* JSON processing extracts nested FX rates using `wide_number_mode => 'round'` to handle high precision floats that would otherwise cause `safe.parse_json()` to fail silently
* Joins transactions with chargebacks and creates `has_chargeback` and `has_chargeback_evidence` boolean fields
* Complex logic is kept here to ensure final tables remain thin and easy to query
* The `build_` intermediate pattern is applied here as well, same protective barrier approach as the base layer

### `Data Limitations & Assumptions`
* **Negative amount:** One record with `-$23.78` was identified within the `ACCEPTED + has_chargeback = true` cohort. Since this integration is exclusively scoped to account funding, negative values have no valid business justification and are flagged via `is_quarantined = true`. The record is preserved at the build layer for review and excluded from `fct_globepay_transactions`.
* **Chargeback evidence flag:** Although the current datasets share a perfect 1:1 mapping, `has_chargeback_evidence` was introduced to surface any transactions missing a chargeback record, avoiding null handling in the BI layer.

---

## `3. Lineage Graph`

The graph below shows the flow from raw seeds to the final fact table.

<img src="docs/dbt_architecture_lineage.png" width="700" alt="dbt Lineage Graph">

---

## `4. Data Quality, Macros & Documentation`

### Data Quality & Validations
* **Uniqueness and Not-Null:** Applied to `transaction_id` across both base and core layers to prevent duplicate generation during joins
* **Relationships:** Guarantees 100% of IDs in `chargeback_report` exist within `acceptance_report`
* **Accepted Values:** Validates `transaction_status` and `local_currency` against expected value sets
* **Accepted Currencies Seed:** A reference seed (`seeds/reference/accepted_currencies.csv`) serves as the single source of truth for valid currencies per payment processor. When Deel expands to a new currency or onboards a new processor, only the seed requires updating — no changes to tests or models needed
* **Freshness:** A warning-severity test monitors `processed_at` to detect delays in time-series data arrival
* **Alerting & Observability:** Depending on criticality, rather than halting the pipeline, workflows are designed to isolate inconsistent records and route them to a quarantine dashboard — giving stakeholders visibility without compromising the main reporting layer

### Macros
* **`is_valid_json`:** Custom generic test that validates JSON columns using `safe.parse_json()`. Applies `wide_number_mode => 'round'` to handle high precision floats that BigQuery cannot parse in standard mode

### Documentation
* Development begins with a formal proposal signed off by all relevant stakeholders before a single line of SQL is written. Once complete, all logic is captured in a design document stored in the initiatives folder — accessible to anyone in the organisation.
```plaintext
initiatives
└── FY25-26
    ├── payment_management
    │   ├── proposal/2025_10_01_payment_integration_proposal.md        # signed off
    │   └── design_document/2025_11_03_payment_integration_design.md  # signed off
    ├── fraud_detection
    │   ├── proposal/2025_10_18_fraud_detection_proposal.md            # signed off
    │   └── design_document/2025_11_20_fraud_detection_design.md      # signed off
    └── revenue_reconciliation
        ├── proposal/2026_02_03_revenue_reconciliation_proposal.md     # signed off
        └── design_document/2026_02_14_revenue_reconciliation_design.md  # in review
```

## `Future Improvements`
* **Look-back window:** Implement a 3-day look-back in incremental logic to capture chargebacks raised after the initial transaction event
* **Data Contracts:** Enforce schema constraints at the ingestion layer so breaking source changes are caught before reaching final models
* **Alerting:** Introduce automated test failure notifications so teams are alerted immediately when a `build_` intermediate step catches bad data
* **Marts Layer:** As consumer count grows, a dedicated marts layer would provide cleaner access control and pre-aggregated views tailored to specific use cases



Initiave documentation would look like this 

```plaintext
initiatives
└── FY25-26
    ├── payment_management
    │   ├── proposal
    │   │   └── 2025_10_01_payment_integration_proposal.md  # proposal
    │   └── design_document
    │       └── 2025_11_03_payment_integration_design.md    # signed off
    ├── fraud_detection
    │   ├── proposal
    │   │   └── 2025_10_18_fraud_detection_proposal.md      # proposal
    │   └── design_document
    │       └── 2025_11_20_fraud_detection_design.md        # signed off
    ├── customer_lifetime_value
    │   ├── proposal
    │   │   └── 2026_01_07_clv_modelling_proposal.md        # proposal
    │   └── design_document
    │       └── 2026_01_21_clv_modelling_design.md          # signed off
    └── revenue_reconciliation
        ├── proposal
        │   └── 2026_02_03_revenue_reconciliation_proposal.md  # proposal
        └── design_document
            └── 2026_02_14_revenue_reconciliation_design.md    # in review
```

## `Future Improvements`
* Implement a "look-back" window in the incremental logic (checking the last 3 days) to capture chargebacks that occur days after the initial transaction event
* Use Data Contracts to enforce schema constraints at the Ingestion layer so that that any breaking changes in the source data are caught before they reach our final models

# `Part II - Final Model Testing`
For the second part of the challenge, please develop a production version of the model for the
Data Analyst to utilize. This model should be able to answer these three questions at a
minimum

Final Model -----> `fct_globepay_transactions`

dbt build ran as expected, all good 

```sql
dbt build -s +fct_globepay_transactions
```

<img src="docs/dbt_build_evidence.png" width="700">

----------------------------------------

1. What is the acceptance rate over time?

```sql
with calculations as (
  select 
    extract(year from processed_at) as year,
    extract(month from processed_at) as month_num,
    format_timestamp('%B', processed_at) AS month,
    sum(case when transaction_status='DECLINED' then 1 else 0 end) as total_declined_transactions, 
    sum(case when transaction_status='ACCEPTED' then 1 else 0 end) as total_accepted_transactions,
    count(transaction_id) as total_transactions
  from deel-task-12345.core_payment_management.fct_globepay_transactions 
  group by all 
)

select 
  *except(month_num), 
  round(safe_divide(total_accepted_transactions, total_transactions)*100, 2) as acceptance_rate_pct
from calculations
order by year, month_num asc
```

<img src="docs/query_results/acceptance_rate_over_time.png" width="700">

----------------------------------------

2. List the countries where the amount of declined transactions went over $25M
```sql
with declined_transactions_scope as (
  select 
    country_code, 
    sum(usd_settled_amount) as total_settled_amount_usd_for_declined_txns
  from deel-task-12345.core_payment_management.fct_globepay_transactions 
  where transaction_status='DECLINED'
group by country_code 
)

select * from declined_transactions_scope 
where total_settled_amount_usd_for_declined_txns>25000000
```

<img src="docs/query_results/countries_declined_txns_over_25_million.png" width="700">

----------------------------------------

3. Which transactions are missing chargeback data?

```sql
select count(*) as txns_with_no_chargeback_record
from deel-task-12345.core_payment_management.fct_globepay_transactions 
where has_chargeback_evidence=false
```

<img src="docs/query_results/txns_with_no_chargeback_report.png" width="700">
