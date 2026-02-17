{% docs transaction_id_globepay_transactions %}
The unique primary key for each transaction. Use this to join with other payment dimension tables.
{% enddocs %}

{% docs event_id_globepay_transactions %}
Unique event identifier associated with the recorded transaction.
{% enddocs %}

{% docs processed_at_globepay_transactions %}
UTC timestamp of the transaction, converted from the ISO 8601 Zulu format.
{% enddocs %}

{% docs transaction_status_globepay_transactions %}
The final outcome of the transaction.
{% enddocs %}

{% docs is_cvv_provided_globepay_transactions %}
Boolean flag indicating if the CVV was provided by the user during checkout.
{% enddocs %}

{% docs country_code_globepay_transactions %}
The two-character ISO country code of the card used for the transaction.
{% enddocs %}

{% docs local_currency_globepay_transactions %}
The three-character ISO currency code used for the transaction.
{% enddocs %}

{% docs local_amount_globepay_transactions %}
The original transaction amount in the customer's currency, calculated by multiplying the settled USD amount by the extracted exchange rate.
{% enddocs %}

{% docs usd_settled_amount_globepay_transactions %}
The transaction value in USD.
{% enddocs %}

{% docs is_valid_globepay_transactions %}
Flags whether the transaction is valid or not based on its status. Useful for filtering out any records that are not relevant for critical metrics to be calculated in downstream models.
{% enddocs %}

{% docs has_chargeback_globepay_chargebacks %}
Boolean flag indicating if a chargeback was reported for this transaction. Value TRUE indicates that the transaction was disputed by the cardholder or issuing bank, resulting in a chargeback record in the source data. FALSE indicates that the transaction was not disputed.
{% enddocs %}

{% docs has_chargeback_evidence_globepay_transactions %}
Boolean field that indicates whether a certain transaction has a matching chargeback record in the source data.
{% enddocs %}

{% docs fx_rates_json_globepay_transactions %}
JSON object containing foreign exchange rates relative to USD (base = 1.0). Each key represents a three-character ISO currency code, and each value represents the exchange rate multiplier to convert from USD to that currency. For example, a value of 1.415 for CAD means 1 USD = 1.415 CAD.
{% enddocs %}