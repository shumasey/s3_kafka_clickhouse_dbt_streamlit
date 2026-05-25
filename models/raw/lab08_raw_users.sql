{{ config(materialized='table') }}

SELECT
    user_id,
    user_uuid,
    is_test_user,
    'S3-backet' AS scr,
    now() AS created_dttm
FROM {{ source('s3_sources', 'lab08_users') }}
