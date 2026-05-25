{{
    config(
        materialized='table',
        engine='MergeTree()',
        order_by='transaction_date',
        settings={
            'index_granularity': 8192
        }
    )
}}

WITH tx AS (
    SELECT *,
        -- Имя поля должно строго совпадать с именем поля в таблице курсов валют
        toDateTime(created_at) AS valid_from,
        -- Фиктивный ключ для соблюдения правила equi-join
        1 AS join_key
    FROM {{ ref('lab08_core_transactions') }}
),

cxl AS (
    SELECT * FROM {{ ref('lab08_core_cancellations') }}
),

rates AS (
    SELECT *,
        -- Фиктивный ключ для соблюдения правила equi-join
        1 AS join_key
    FROM {{ ref('lab08_core_exchange_rates') }}
),

users AS (
    SELECT * FROM {{ ref('lab08_raw_users') }}
),

test_users AS (
    SELECT * FROM {{ ref('lab08_raw_test_users') }}
),

promo AS (
    SELECT * FROM {{ ref('lab08_raw_promo_codes') }}
)

SELECT
    -- Ключевые идентификаторы
    tx.transaction_id,
    tx.user_id,
    tx.user_uuid,
    tx.promo_code_id,

    -- Временные измерения для графиков
    tx.transaction_date,
    tx.transaction_day_of_week,
    tx.transaction_hour,

    -- Метрики сумм
    abs(tx.amount) AS amount, -- Уже abs(amount) из слоя core
    tx.currency,
    
    -- Конвертация в базовую валюту TGRK (используем интервалы курсов)
    -- Если валюта уже TGRK, курс равен 1, иначе берем rate_tgrk_rub (базовый токен к рублю)
    CASE 
        WHEN tx.currency = 'TGRK' THEN abs(tx.amount)
        ELSE abs(tx.amount) * coalesce(r.rate_tgrk_rub, 1.0)
    END AS amount_tgrk,

    -- Флаг покупки (Только тип purchase и статус completed)
    CASE 
        WHEN tx.transaction_type = 'purchase' AND tx.status = 'completed' THEN 1 
        ELSE 0 
    END AS is_purchase,

    -- Определение статуса пользователя (Флаг users)
    CASE 
        -- Если ID равен 0 или UUID является нулевым, это гарантированно фиктивный пользователь
        WHEN tx.user_id = 0 OR tx.user_uuid = toUUID('00000000-0000-0000-0000-000000000000') THEN 'Фиктивный'
        -- Если пользователя нет в справочнике
        WHEN u.user_id IS NULL THEN 'Фиктивный'
        -- Если в справочнике стоит флаг тестового пользователя
        WHEN u.is_test_user = true THEN 'Тестовый'
        -- Во всех остальных случаях пользователь реальный
        ELSE 'Реальный'
    END AS user_category,


    -- Определение отмены (Флаг cancelled)
    -- Условие: совпадение ID, сумм и дата отмены = дата транзакции + 1 день
    CASE 
        WHEN c.cancellation_id IS NOT NULL THEN 'ДА'
        ELSE 'НЕТ'
    END AS is_cancelled,

    -- Словари для фильтров (type, state, promo)
    CASE 
        WHEN tx.transaction_type = 'purchase' THEN 'Покупка'
        WHEN tx.transaction_type = 'refund' THEN 'Возврат'
        WHEN tx.transaction_type = 'transfer' THEN 'Трансфер'
        ELSE tx.transaction_type
    END AS transaction_type_ru,

    CASE 
        WHEN tx.status = 'completed' THEN 'Завершено'
        WHEN tx.status = 'failed' THEN 'Отклонено'
        ELSE tx.status
    END AS status_ru,

    CASE 
        WHEN tx.promo_code_id IS NULL THEN 'НЕТ'
        ELSE 'ЕСТЬ'
    END AS has_promo,

    -- Анализ промокодов (из справочника)
    p.code AS promo_code,
    p.max_uses AS promo_max_uses,
    p.expiry_date AS promo_expiry_date,
    CASE 
        WHEN p.promo_code_id IS NOT NULL AND tx.transaction_date > p.expiry_date THEN 'ДА'
        WHEN p.promo_code_id IS NOT NULL THEN 'НЕТ'
        ELSE 'Не применимо'
    END AS is_promo_expired,

    -- Метаданные
    tx.scr,
    now() AS created_dttm

FROM tx

-- 1. Подключаем курсы валют по интервалам действия
ASOF LEFT JOIN rates AS r 
  ON tx.join_key = r.join_key 
 AND tx.valid_from >= r.valid_from

-- 2. Подключаем отмены по жесткому бизнес-правилу (транзакция + 1 день)
LEFT JOIN cxl AS c
  ON c.original_transaction_id = tx.transaction_id 
 AND c.refund_amount = tx.amount
 AND c.cancellation_date = (tx.transaction_date + INTERVAL 1 DAY)

-- 3. Подключаем справочники пользователей
LEFT JOIN users AS u ON toUInt64(tx.user_id) = u.user_id
LEFT JOIN test_users AS tu ON tx.user_uuid = tu.test_user_uuid

-- 4. Подключаем справочник промокодов
LEFT JOIN promo AS p ON tx.promo_code_id = p.promo_code_id
