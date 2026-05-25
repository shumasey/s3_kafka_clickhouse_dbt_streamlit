{{
    config(
        materialized='table',
        engine='MergeTree()',
        order_by='valid_from',
        settings={
            'index_granularity': 8192
        }
    )
}}

WITH unique_rates AS (
    SELECT
        update_id,
        toDateTime(timestamp) AS valid_from,
        rate_tgrk_punk,
        rate_tgrk_rub,
        scr,
        row_number() OVER (
            PARTITION BY update_id, timestamp, rate_tgrk_punk, rate_tgrk_rub
            ORDER BY created_dttm DESC
        ) AS row_num
    FROM {{ ref('lab08_raw_exchange_rates') }}
),

ordered_rates AS (
    SELECT
        update_id,
        valid_from,
        rate_tgrk_punk,
        rate_tgrk_rub,
        scr
    FROM unique_rates
    WHERE row_num = 1
),

calculated_intervals AS (
    SELECT
        update_id,
        valid_from,
        -- Берем значение следующей строки стандартным оконным методом
        any(valid_from) OVER (
            ORDER BY valid_from ASC 
            ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING
        ) AS next_valid_from,
        rate_tgrk_punk,
        rate_tgrk_rub,
        scr
    FROM ordered_rates
)

SELECT
    update_id,
    valid_from,
    -- Если следующей строки нет, ClickHouse возвращает '1970-01-01 03:00:00' (зависит от таймзоны).
    -- Проверяем на год: если это 1970 год, значит мы на последней строке и ставим 2050 год.
    CASE 
        WHEN toYear(next_valid_from) = 1970 THEN toDateTime('2050-01-01 00:00:00')
        ELSE next_valid_from
    END AS valid_to,
    rate_tgrk_punk,
    rate_tgrk_rub,
    scr,
    now() AS created_dttm
FROM calculated_intervals
