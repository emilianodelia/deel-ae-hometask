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
* High reliability: No null or missing values were found in any columns across both datasets.
* All JSON FX rate records look good. No weird formatting or broken records were detected.
* Transactional data only covers 6 months of 2019.
* A consistent universe of 5430 records is maintained across both the acceptance report and the chargeback report.
* Column `status` in both reports looks like a message related to the success of the API call, we can ignore it for now.
* Column `source` (chargebacks) has only one possible value which is GLOBALPAY, useful for differentiating between sources in the case  more payment third parties get integrated in the future but it is not relevant for the task. Ignore for now.


## `2. Summary of your model architecture`

The architecture is divided into 2 standalone layers (marts would be developed by the Analysts) to ensure scalability and clear lineage. Within the base layer, models are grouped by source name rather than concept, for example, all Globepay models live under `base/globepay/`, so that onboarding a new payment processor in the future is as simple as adding a new source folder alongside it, with no restructuring required.

```plaintext
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
```

### Description per Layer 

### Layer Descriptions

### `1. Ingestion Layer`
* Ingests raw transaction acceptance and chargeback reports by loading static CSV files into BigQuery as raw tables
* EDA showed no messy or broken data formats, however testing was still applied at this stage to ensure data quality from the start of the pipeline
* **Worth noting:** as the project grows, documenting the refresh cadence and planning for automated or event-triggered loads will be important — static ingestion is often where pipelines become brittle at scale

### `2. Base Layer`
* Cleans and standardizes data based on enterprise-level naming conventions, renaming columns and enforcing data types according to business logic
* Acts as a schema contract between raw source and everything downstream — if a source column name changes, the fix only needs to be applied in one place, minimising the blast radius of upstream changes
* Keeps historical models and transaction versioning intact for future audits
* As a rule of thumb, both a historical base model (not meant for direct analyst queries) and models used to build the core layer are maintained separately

### `3. Core Layer`
* Handles all heavy lifting: JSON processing extracts nested exchange rates from the rates column to identify the FX rate needed for USD conversion
* Joins transactions with chargebacks and creates the has_chargeback and has_chargeback_evidence boolean fields
* Keeps complex logic out of the marts layer, ensuring final tables remain thin and easy to query
* An intermediate folder pattern is applied across all layers. Eeach model has a preceding `build_` intermediate step that acts as a protective barrier for the final models. All data quality tests are applied exclusively at this stage, ensuring that bad data is caught and never allowed to reach the final models that analysts and downstream consumers depend on.


### `Data Limitations & Assumptions`
* **Assumption on Chargeback Status**: Although the current acceptance and chargeback reports share a perfect 1:1 mapping, I have introduced a boolean validation field to identify any transactions missing a corresponding chargeback record. The field `has_chargeback_evidence` will let the analysts filter any transaction with missing chargeback data and avoid dealing with nulls within the BI tool to be used by the analyst

## 3. Lineage graphs

The graph below shows the flow from raw seeds to the final fact table.

<img src="docs/dbt_architecture_lineage.png" width="700" alt="dbt Lineage Graph">

## `4. Tips around macros, data validation, and documentation`

### Data Quality & Validations

* **Uniqueness and Not-Null:** Applied to transaction_id and external_ref across both the Base and Core layers. These tests ensure no duplicates are generated during joins, preventing the distortion of critical financial metrics.
* **Relationships:** Used to guarantee that 100% of the IDs in the chargeback_report exist within the acceptance_report, ensuring referential integrity across the two source datasets.
* **Accepted Values:** Validates that categorical fields such as state fall within the expected set of values defined in the source data, catching any unexpected classifications early.
* **Custom Generic Tests:** Where native dbt tests were not sufficient, custom generic tests were written to handle edge cases specific to the business logic of this pipeline.
* **Freshness:** Freshness testing is particularly critical for time-series financial data. Tests are configured against the processed_at column to detect any delays or gaps in data arrival as early as possible. (Test was created but not yet applied.)
* **Alerting & Observability:**
  * Depending on the criticality of the failure, rather than halting the entire pipeline, workflows would be designed to isolate and exclude inconsistent or       unreconciled records from the final models, routing them instead to a dedicated quarantine or exception dashboard. 
  * This gives stakeholders and data reviewers full visibility over problematic cases without compromising the integrity or availability of the main reporting layer.
* During data exploration, one negative amount `(-$23.78)` was identified within the `ACCEPTED + has_chargeback = true` cohort. Given that this integration is exclusively scoped to account funding operations, negative values were flagged via `is_quarantined = true`. The correlation with a chargeback event may suggest a reversal or dispute scenario that falls outside the expected data contract with Globepay, and is preserved at the build layer for further investigation.

### Documentation
* In my current role, the development lifecycle begins with a formal proposal outlining requirements, expected outputs, and delivery timelines. 
Modelling only begins once all relevant stakeholders have reviewed and signed off, this ensures alignment before a single line of SQL is written and avoids costly rework down the line. 
* Once development is complete, all details are fully captured in a design document where any addition or change related to business logic or data ingestion must be specified. 
* This document will live in the initiatives folder, accessible to anyone in the organisation who needs to understand the reasoning and logic behind a given initiative. 


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
  from deel-task-12345.core_transactional.fct_globepay_transactions 
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
  from deel-task-12345.core_transactional.fct_globepay_transactions 
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
from deel-task-12345.core_transactional.fct_globepay_transactions 
where has_chargeback_evidence=false
```

<img src="docs/query_results/txns_with_no_chargeback_report.png" width="700">
