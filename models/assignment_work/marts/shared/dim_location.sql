-- Location dimension shared by both restaurant applications and 311 service reqs

WITH all_locations AS (
   -- Get locations from 311 requests
   SELECT DISTINCT CAST(borough as STRING) as borough, CAST(incident_zip as STRING) as zip_code
   FROM {{ ref('stg_nyc_311_dot') }}
   WHERE borough IS NOT NULL

   UNION DISTINCT

   -- Get locations from restaurant applications
   SELECT DISTINCT CAST(borough as STRING) as borough, CAST(zip as STRING) as zip
   FROM {{ ref('stg_nyc_open_restaurant_apps') }}
   WHERE borough IS NOT NULL
),

location_dimension AS (
   SELECT
       {{ dbt_utils.generate_surrogate_key(['borough', 'zip_code']) }} AS location_key,
       borough,
       zip_code
   FROM all_locations
)

SELECT * FROM location_dimension --TODO replace ??s with what to select. HINT: May be quite simple!