-- Clean and standardize DOB NOW Build Job Application Filings
-- One row per job filing
WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
    SELECT
        -- Base fields except those transformed below
        * EXCEPT (
            job_filing_number,
            filing_status,
            filing_date,
            borough,
            job_type,
            initial_cost,
            total_fee,
            gis_latitude,
            gis_longitude
        ),

        -- Identifiers
        CAST(job_filing_number AS STRING) AS job_filing_number,

        -- Status & Type
        UPPER(TRIM(CAST(filing_status AS STRING))) AS filing_status,
        UPPER(TRIM(CAST(job_type AS STRING))) AS job_type,

        -- Timestamps
        CAST(filing_date AS TIMESTAMP) AS filing_date,

        -- Standardized Borough (aligned with 311 staging conventions)
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Financial / Cost measures
        SAFE_CAST(initial_cost AS NUMERIC) AS initial_cost,
        SAFE_CAST(total_fee AS NUMERIC) AS total_fee,

        -- Coordinates
        SAFE_CAST(gis_latitude AS DECIMAL) AS latitude,
        SAFE_CAST(gis_longitude AS DECIMAL) AS longitude,

        -- Metadata tracking
        CURRENT_TIMESTAMP() AS stg_loaded_at

    FROM source
    WHERE job_filing_number IS NOT NULL
      AND filing_date IS NOT NULL
      AND borough IS NOT NULL
    -- Deduplicate to keep latest version of each filing
    QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY filing_date DESC) = 1
)

SELECT * FROM cleaned