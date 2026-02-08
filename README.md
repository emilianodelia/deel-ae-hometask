# Deel x Globepay: Account Funding Analysis

## Overview
This repository contains the Analytics Engineering solution for processing and analyzing credit/debit card funding transactions handled by Globepay

## Business Context
Deel leverages Globepay as a global payment processor to allow clients to fund their accounts. This project focuses on:

Standardizing multi-currency transaction data.

Mapping Globepay API responses to Deel’s internal account funding structures.

Providing visibility into transaction success rates and processing performance across different countries.

## Tools to be used 
* dbt

## 1. Preliminary data exploration

## 2. Summary of your model architecture

Architecture Overview

The architecture is divided into four standalone layers to ensure scalability, data quality, and clear lineage

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
* Every layer is validated using dbt tests such as `not_null` and `unique` in order to detect any duplicate or null critical transaction identifiers that will be used across the layers
* `accepted_values` test was used in order to detect whether the values from columns such as `status` are displaying the expected values that were seen in the EDA process
