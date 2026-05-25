{{
    config(
        materialized='incremental',
        incremental_strategy='append'
    )
}}

SELECT
    update_id,
    timestamp,
    rate_tgrk_punk,
    rate_tgrk_rub,
    'S3-backet' AS scr,
    now() AS created_dttm
FROM {{ source('s3_sources', 'lab08_exchange_rates_s3') }}

{% if is_incremental() %}
WHERE timestamp > (SELECT max(timestamp) FROM {{ this }})
{% endif %}
