{{
    config(
        materialized='table',
        engine='MergeTree()',
        order_by='transaction_id',
        settings={
            'index_granularity': 8192
        }
    )
}}

WITH transformed_data AS (
    SELECT
        transaction_id,
        -- Если пустое или не парсится, возвращаем 0
        coalesce(toInt64OrZero(user_id), 0) AS user_id,
        -- Если пустое, подставляем нулевой UUID
        coalesce(toUUIDOrZero(user_uuid), toUUID('00000000-0000-0000-0000-000000000000')) AS user_uuid,
        -- Все числа делаем положительными
        amount,
        currency,
        transaction_type,
        promo_code_id,
        status,
        created_at,
        -- Новые поля времени из created_at (Unix-timestamp)
        toDate(toDateTime(created_at)) AS transaction_date,
        toDayOfWeek(toDateTime(created_at)) AS transaction_day_of_week,
        toHour(toDateTime(created_at)) AS transaction_hour,
        scr,
        -- Считаем порядковый номер для удаления полных дубликатов строк
        row_number() OVER (
            PARTITION BY 
                transaction_id, 
                user_id, 
                user_uuid, 
                amount, 
                currency, 
                transaction_type, 
                promo_code_id, 
                status, 
                created_at
            ORDER BY created_dttm DESC
        ) AS row_num
    FROM {{ ref('lab08_raw_transactions') }}
)

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
    transaction_date,
    transaction_day_of_week,
    transaction_hour,
    scr,
    now() AS created_dttm
FROM transformed_data
-- Оставляем только уникальные строки
WHERE row_num = 1
