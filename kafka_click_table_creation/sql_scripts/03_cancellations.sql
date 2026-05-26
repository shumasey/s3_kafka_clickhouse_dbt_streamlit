CREATE TABLE IF NOT EXISTS $click_user.lab08_cancellations_raw
(
    original_transaction_id UInt32 DEFAULT 0,
    reason                  Enum8('insufficient_funds' = 1, 'user_request' = 2, 'fraud_detected' = 3),
    cancelled_at            DateTime('UTC'),
    refund_amount           UInt32 DEFAULT 0,
    _source                 LowCardinality(String),
    version		            UInt16
) Engine = ReplacingMergeTree(version)
PARTITION BY toStartOfDay(cancelled_at)
ORDER BY (reason, original_transaction_id, cancelled_at)
SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW IF NOT EXISTS $click_user.lab08_mv_stream_cancellations_raw
TO $click_user.lab08_cancellations_raw AS
SELECT JSONExtractUInt(raw, 'original_transaction_id')                   AS original_transaction_id,
       JSONExtractString(raw, 'reason')                                  AS reason,
       parseDateTime64BestEffort(JSONExtractString(raw, 'cancelled_at')) AS cancelled_at,
       JSONExtractUInt(raw, 'refund_amount')                             AS refund_amount,
       'kafka'             		                                         AS _source,
       1					 		 	                                 AS version
FROM $click_user.lab08_stream_raw
WHERE JSONExtractString(raw, '_source') = 'cancellation';

CREATE MATERIALIZED VIEW IF NOT EXISTS $click_user.lab08_mv_s3_cancellations_raw
TO $click_user.lab08_cancellations_raw AS
SELECT toUInt32(original_transaction_id)          AS original_transaction_id,
       CAST(reason AS Enum8('insufficient_funds' = 1, 
                            'user_request' = 2,
                            'fraud_detected' = 3)) AS reason,
       parseDateTimeBestEffort(cancelled_at)      AS cancelled_at,
       toUInt32(refund_amount)                    AS refund_amount,
       's3'                                       AS _source,
       toUInt16(2)                                AS version
FROM $click_user.lab08_cancellations_s3;
