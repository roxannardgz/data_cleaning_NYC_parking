# Data Cleaning with PostgreSQL
<br>


## Goal
Ensure the dataset is well-structured and consistent, reducing the need for additional cleaning during the analysis phase.

## Overview
Data quality is crucial, especially when used for analysis and reporting. This case study explores the process of cleaning and standardizing data using PostgreSQL. The dataset used consists of 5,000 rows of New York City parking violation records, including vehicle details, time and location of the infraction, and associated metadata. The data originates from a transactional system, and contains inconsistencies, missing values, and formatting issues that should be addressed before further analysis.

## Key Functions Used

➜ CTEs, `ROW-NUMBER()` `OVER (PARTITION BY ...)` to identify and eliminate duplicate records.

➜ `DIFFERENCE()`, `CASE WHEN` to standardize data, and the `fuzzystrmatch` extension to identify similar phonetic matching (Soundex).

➜ `COALESCE()` to handle missing values.

➜ `TRIM()` and Regular Expressions (using `SIMILAR TO` and `~`), to identify and update invalid values.

➜ `NULLIF()`, `LEFT()`, `SUBSTR()`, `TO_TIMESTAMP()` for data transformation

➜ `UPDATE`, `DELETE`, `ALTER TABLE` to apply changes to the table.


## Results and Impact
After applying the SQL cleaning steps, the dataset became structured and standardized, making it significantly easier to work with for reporting. While some minor adjustments may still be needed for specific analyses, analysts can focus on generating insights rather than extensive data cleaning. The cleaned data will support reports on violation frequency, trends by location, and correlations with vehicle attributes.

By proactively addressing data quality issues at this stage, the project achieves its primary goal: **reducing future cleaning efforts and improving report accuracy**.
