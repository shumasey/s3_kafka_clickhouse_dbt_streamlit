{{
    config(
        materialized='incremental',
        incremental_strategy='append'
    )
}}

SELECT
    cancellation_id,
    original_transaction_id,
    reason,
    cancelled_at,
    refund_amount,
    'S3-backet' AS scr,
    now() AS created_dttm
FROM {{ source('s3_sources', 'lab08_cancellations_s3') }}

{% if is_incremental() %}
-- Используем parseDateTimeBestEffort для сравнения дат с нестандартным форматом
WHERE parseDateTimeBestEffort(cancelled_at) > (SELECT max(parseDateTimeBestEffort(cancelled_at)) FROM {{ this }})
{% endif %}
