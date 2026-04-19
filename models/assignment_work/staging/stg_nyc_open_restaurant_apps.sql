-- Clean and standardize 311 DOT service request data
-- One row per service request

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           globalid,
           time_of_submission,
           restaurant_name,
           legal_business_name,
           doing_business_as_dba,
           street,
           borough,
           zip,
           business_address,
           food_service_establishment,
           sla_serial_number,
           sla_license_type,
           landmarkdistrict_terms,
           latitude,
           longitude
       ),

       -- Identifiers
       CAST(globalid AS STRING) AS globalid,

       -- Date/Time
       CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,

       -- Restaurant details
       CAST(restaurant_name AS STRING) AS restaurant_name,
       CAST(legal_business_name AS STRING) AS legal_business_name,
       CAST(doing_business_as_dba AS STRING) AS doing_business_as_dba,

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(zip AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(zip AS STRING)) = 5 THEN CAST(zip AS STRING)
           WHEN LENGTH(CAST(zip AS STRING)) = 9 THEN CAST(zip AS STRING)
           WHEN LENGTH(CAST(zip AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(zip AS STRING)
           ELSE NULL
       END AS zip,

       -- Location - standardized borough, just in case
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       CAST(business_address AS STRING) AS business_address,
       CAST(street AS STRING) AS street,
       CAST(food_service_establishment AS STRING) AS food_service_establishment,
       CAST(sla_serial_number AS STRING) AS sla_serial_number,
       CAST(sla_license_type AS STRING) AS sla_license_type,
       CAST(landmarkdistrict_terms AS STRING) AS landmarkdistrict_terms,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE globalid IS NOT NULL
   AND time_of_submission IS NOT NULL
   AND DATE(TIMESTAMP(time_of_submission)) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 YEAR)
   AND borough IS NOT NULL

   -- Deduplicate
   QUALIFY ROW_NUMBER() OVER (PARTITION BY globalid ORDER BY time_of_submission DESC) = 1
),

filtered AS (
   SELECT *
   FROM cleaned
   WHERE zip IS NOT NULL
)

SELECT * 
FROM filtered
-- All should be part of this table: stg_nyc_open_restaurant_apps
