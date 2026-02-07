# Globepay Acceptance Report
## acceptance_report_raw

`external_ref`
* Unique identifier associated with the external transactional event
* Useful for perfoeming joins with records from the charge back report
* Included in our current architecture 

`ref`
* Unique Deel internal identifier, could be interpreted as the card or account ID that executed the transaction
* Included in our current architecture given that in the future we might need this ID to enrich this base model with relevant client information coming from a CRM

`status`
* Possible values detected = TRUE
* Could be a message related to the success of the API call
* Excluded from current architecture 

`source`
* Possible values detected = 'GLOBALOPAY'
* Good to have in order to test and locate any unexpected values that could make their way throgh the data ingestion process
* Excluded from current architecture, we know we are dealing with Globepay data, no need to state it again within the data models

`date_time`
* Stored in timestamp format `2019-01-05T09:36:00.000Z`
* Could be interpreted as the transaction processing timestamp
* The critical nature of this field led me to investigate a deeper into the posisble values of the field
* No nulls and no unexpected formats were found. Either way, I tend to play it cautiuosly and develop for testing to make sure that no timestamps with broken formats reach our final tables

`state`
* Possible values detected = ACCEPTED, DECLINED
* Indicates whether a transaction request got through or not
* Useful for flagging valid transactions that, for exmaple, will be considered for revenue reporting in the future. Said flag will help us keep track of key metrics related to the transaction status themselves while also being able to perform accurate revenue/activity reporting
* Included in our current architecture

`amount`
* Looks like the settled transaction amount already converted into USD
* Useful for tracking transaction volume or activity by individual clients, original transaction currencies and geographies
* Included in our current architecture

`country`
* 3 letter code of the country where the transaction was processed
* Straightfoward, useful for our data analysts 

`currency`
* 3 ISO code of the original currency in which the transaction was processed
* Straightfoward, useful for our data analysts

`rates`
* Crucial field that helped me confirm that the `amount` was indeed already converted into USD since the exchange rate from USD to USD would be 1
* Useful for having an overview of the main currencies that undergo an exchange into USD

`cvv_provided`
* Looks like something that is nice to have but the requirements suggest that it has no current use into our architecture
* Excluded from current architecture