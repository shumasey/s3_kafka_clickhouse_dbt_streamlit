{{ config(materialized='table') }}

SELECT
    test_user_uuid,
    'S3-backet' AS scr,
    now() AS created_dttm
FROM {{ source('s3_sources', 'lab08_test_users') }}
