CREATE TABLE IF NOT EXISTS ${click_db}.lab08_cancellations_s3
(
    cancellation_id UInt64, 
    original_transaction_id UInt64, 
    reason String, 
    cancelled_at String, 
    refund_amount Int32
)
ENGINE = S3('https://storage.yandexcloud.net/npl-de18-lab8-data/cancellations/day=*/cancellations.jsonl', 'JSONEachRow')
SETTINGS use_hive_partitioning = 0;

CREATE TABLE IF NOT EXISTS ${click_db}.lab08_exchange_rates_s3
(
    update_id UInt64,
    timestamp UInt64,
    rate_tgrk_punk Float32,
    rate_tgrk_rub Float32
)
ENGINE = S3('https://storage.yandexcloud.net/npl-de18-lab8-data/exchange_rates/day=*/rates.jsonl', 'JSONEachRow')
SETTINGS use_hive_partitioning = 0;

CREATE TABLE IF NOT EXISTS ${click_db}.lab08_transactions_s3
(
    transaction_id UInt64,
    user_id String,
    user_uuid String,
    amount Int32,
    currency String,
    transaction_type String,
    promo_code_id Nullable(UInt64),
    status String,
    created_at UInt64
)
ENGINE = S3('https://storage.yandexcloud.net/npl-de18-lab8-data/day=*/slot=*/transactions.jsonl', 'JSONEachRow')
SETTINGS use_hive_partitioning = 0;

CREATE TABLE IF NOT EXISTS ${click_db}.lab08_users
(
    user_id UInt64,
    user_uuid UUID,
    is_test_user Bool
)
ENGINE = S3('https://storage.yandexcloud.net/npl-de18-lab8-data/reference/users.jsonl', 'JSONEachRow');

CREATE TABLE IF NOT EXISTS ${click_db}.lab08_test_users
(
    test_user_uuid UUID
)
ENGINE = S3('https://storage.yandexcloud.net/npl-de18-lab8-data/reference/test_users.jsonl', 'JSONEachRow');

CREATE TABLE IF NOT EXISTS ${click_db}.lab08_promo_codes
(
    promo_code_id UInt8,
    code LowCardinality(String),
    max_uses UInt8,
    expiry_date Date
)
ENGINE = S3('https://storage.yandexcloud.net/npl-de18-lab8-data/reference/promo_codes.jsonl', 'JSONEachRow');
