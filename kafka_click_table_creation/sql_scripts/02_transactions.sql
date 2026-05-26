CREATE TABLE IF NOT EXISTS $click_user.lab08_transactions_raw
(
  transaction_id UInt32,
  user_id UInt16 DEFAULT 0,
  user_uuid UUID DEFAULT '00000000-0000-0000-0000-000000000000',
  amount Int32,
  currency Enum8('RUB' =1, 'TGRK' = 2, 'PUNK' = 3),
  transaction_type Enum8('purchase' = 1, 'transfer' = 2, 'refund' = 3),
  promo_code_id UInt8 Default 0,
  status Enum('completed' = 1, 'failed' = 2),
  created_at Datetime('UTC'),
  _source LowCardinality(String),
  version UInt16
) ENGINE = ReplacingMergeTree(version)
  PARTITION BY toStartOfDay(created_at)
  ORDER BY (transaction_id, user_id, promo_code_id, created_at)
  SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW IF NOT EXISTS $click_user.lab08_mv_stream_transactions_raw
TO $click_user.lab08_transactions_raw AS
SELECT toUInt32(JSONExtractUInt(raw, 'transaction_id'))             AS transaction_id,
       toUInt16OrZero(JSONExtractString(raw, 'user_id')) 	        AS user_id,
       coalesce(
       		toUUIDOrZero(JSONExtractString(raw, 'user_uuid')),
       		toUUID('00000000-0000-0000-0000-000000000000'))         AS user_uuid,
       toInt32(JSONExtractUInt(raw, 'amount'))                      AS amount,
       CAST(JSONExtractString(raw, 'currency') 
            AS Enum8('RUB' = 1, 'TGRK' = 2, 'PUNK' = 3))            AS currency,
       CAST(JSONExtractString(raw, 'transaction_type') 
            AS Enum8('purchase' = 1, 'transfer' = 2, 'refund' = 3)) AS transaction_type,
       toUInt8(coalesce(
                JSONExtract(raw, 'promo_code_id','Nullable(UInt8)')
                ,0))                               			        AS promo_code_id,
       CAST(JSONExtractString(raw, 'status') 
            AS Enum8('completed' = 1, 'failed' = 2)) 			    AS status,
       toDateTime(JSONExtractUInt(raw, 'created_at'), 0)            AS created_at,
       'kafka'		                                                AS _source,
       toUInt16(1) 					          						AS version
FROM $click_user.lab08_stream_raw
WHERE JSONExtractString(raw, '_source') = 'transaction';

CREATE MATERIALIZED VIEW IF NOT EXISTS $click_user.lab08_mv_s3_transactions_raw
TO $click_user.lab08_transactions_raw AS
SELECT toUInt32(transaction_id)                                                                    AS transaction_id,
       toUInt16OrZero(user_id)                                                                     AS user_id,
       toUUIDOrZero(nullIf(nullIf(nullIf(trimBoth(user_uuid, ' '), 'null'), 'undefined'), 'None')) AS user_uuid,
       amount,
       CAST(currency AS Enum8('RUB' = 1, 'TGRK' = 2, 'PUNK' = 3))                                  AS currency,
       CAST(transaction_type AS Enum8('purchase' = 1, 'transfer' = 2, 'refund' = 3))               AS transaction_type,
       toUInt8(coalesce(promo_code_id, 0))                                                         AS promo_code_id,
       CAST(status AS Enum8('completed' = 1, 'failed' = 2))                                        AS status,
       toDateTime(created_at, 'UTC')                                                               AS created_at,
       's3'                                                                                        AS _source,
       toUInt16(2)                                                                                 AS version
FROM $click_user.lab08_transactions_s3;


