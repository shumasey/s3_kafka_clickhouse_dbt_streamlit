{{
    config(
        materialized='incremental',
        incremental_strategy='append'
    )
}}

SELECT
    transaction_id,
    user_id,
    user_uuid,
    amount,
    currency,
    transaction_type,
    promo_code_id,
    status,
    created_at,
    'S3-backet' AS scr,
    now() AS created_dttm
FROM {{ source('s3_sources', 'lab08_transactions_s3') }}

{% if is_incremental() %}
-- Фильтр берет только новые транзакции, которых еще нет в raw-слое
WHERE created_at > (SELECT max(created_at) FROM {{ this }})
{% endif %}
