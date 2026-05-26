CREATE TABLE $click_user.lab08_transactions_deduped
(
    transaction_id   UInt32,
    user_id          UInt16,
    user_uuid        UUID,
    amount           Int32,
    currency         Enum8('RUB' = 1, 'TGRK' = 2, 'PUNK' = 3),
    transaction_type Enum8('purchase' = 1, 'transfer' = 2, 'refund' = 3),
    promo_code_id    UInt8,
    status           Enum8('completed' = 1, 'failed' = 2),
    created_at       DateTime('UTC'),
    _source          LowCardinality(String)
)
ENGINE = MergeTree PARTITION BY toStartOfDay(created_at)
ORDER BY (transaction_id, user_id, promo_code_id, created_at)
SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW $click_user.lab08_mv_transactions_deduped
TO $click_user.lab08_transactions_deduped AS
SELECT DISTINCT transaction_id,
                user_id,
                argMax(user_uuid, version)        AS user_uuid,
                argMax(amount, version)           AS amount,
                argMax(currency, version)         AS currency,
                argMax(transaction_type, version) AS transaction_type,
                promo_code_id,
                argMax(status, version)           AS status,
                created_at,
                argMax(_source, version)          AS _source
FROM $click_user.lab08_transactions_raw
GROUP BY transaction_id,
         user_id,
         promo_code_id,
         created_at;

CREATE TABLE $click_user.lab08_cancellations_deduped
(
    original_transaction_id UInt32,
    reason                  Enum8('insufficient_funds' = 1, 'fraud_detected' = 3, 'user_request' = 2),
    cancelled_at            DateTime('UTC'),
    refund_amount           UInt32,
    _source                 LowCardinality(String)
)
ENGINE = MergeTree PARTITION BY toStartOfDay(cancelled_at)
ORDER BY (reason, original_transaction_id, cancelled_at)
SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW $click_user.lab08_mv_cancellations_deduped 
TO $click_user.lab08_cancellations_deduped AS
SELECT DISTINCT original_transaction_id,
                reason,
                cancelled_at,
                argMax(refund_amount, version) AS refund_amount,
                argMax(_source, version)       AS _source
FROM $click_user.lab08_cancellations_raw
GROUP BY reason,
         original_transaction_id,
         cancelled_at;

CREATE TABLE $click_user.lab08_exchange_rates_deduped
(
    update_id      UInt64,
    timestamp      DateTime,
    rate_tgrk_punk Float32,
    rate_tgrk_rub  Float32,
    _source        LowCardinality(String)
)
ENGINE = MergeTree PARTITION BY toStartOfDay(timestamp)
ORDER BY (update_id, timestamp)
SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW $click_user.lab08_mv_rates_deduped
TO $click_user.lab08_exchange_rates_deduped AS
SELECT DISTINCT update_id,
                timestamp,
                argMax(rate_tgrk_punk, version) AS rate_tgrk_punk,
                argMax(rate_tgrk_rub, version)  AS rate_tgrk_rub,
                argMax(_source, version)        AS _source
FROM $click_user.lab08_exchange_rates_raw
GROUP BY update_id,
         timestamp;
