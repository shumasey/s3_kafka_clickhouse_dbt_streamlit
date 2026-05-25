{{ config(materialized='table') }}

SELECT
    promo_code_id,
    code,
    max_uses,
    expiry_date,
    'S3-backet' AS scr,
    now() AS created_dttm
FROM {{ source('s3_sources', 'lab08_promo_codes') }}
