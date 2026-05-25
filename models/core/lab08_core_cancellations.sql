{{
    config(
        materialized='table',
        engine='MergeTree()',
        order_by='cancellation_id',
        settings={
            'index_granularity': 8192
        }
    )
}}

WITH transformed_data AS (
    SELECT
        cancellation_id,
        original_transaction_id,
        reason,
        cancelled_at,
        -- Переводим нестандартную строку в полноценный DateTime (timestamp)
        parseDateTimeBestEffort(cancelled_at) AS cancelled_at_dt,
        refund_amount,
        scr,
        -- Удаление полных дубликатов строк
        row_number() OVER (
            PARTITION BY 
                cancellation_id, 
                original_transaction_id, 
                reason, 
                cancelled_at, 
                refund_amount
            ORDER BY created_dttm DESC
        ) AS row_num
    FROM {{ ref('lab08_raw_cancellations') }}
)

SELECT
    cancellation_id,
    original_transaction_id,
    reason,
    -- Приведение к типу DateTime (выглядит как YYYY-MM-DD HH:MM:SS)
    cancelled_at_dt AS cancelled_at_timestamp,
    -- Отдельное поле даты (тип Date)
    toDate(cancelled_at_dt) AS cancellation_date,
    refund_amount,
    scr,
    now() AS created_dttm
FROM transformed_data
WHERE row_num = 1
