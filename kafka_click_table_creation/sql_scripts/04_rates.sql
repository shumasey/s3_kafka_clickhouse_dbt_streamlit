CREATE TABLE IF NOT EXISTS $click_user.lab08_exchange_rates_raw
(
  update_id UInt64,
  timestamp Datetime,
  rate_tgrk_punk Float32,
  rate_tgrk_rub Float32,
  _source LowCardinality(String),
  version UInt16
) ENGINE = ReplacingMergeTree(version)
  PARTITION BY toStartOfDay(timestamp)
  ORDER BY (update_id, timestamp, rate_tgrk_punk, rate_tgrk_rub)
  SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW IF NOT EXISTS $click_user.lab08_mv_exchange_rates_stream
TO $click_user.lab08_exchange_rates_raw AS
SELECT toInt64(JSONExtractInt(raw, 'update_id')) AS update_id,
       toDateTime(JSONExtractUInt(raw, 'timestamp'),0) AS timestamp,
       toFloat32(JSONExtractFloat(raw, 'rate_tgrk_punk')) AS rate_tgrk_punk,
       toFloat32(JSONExtractFloat(raw, 'rate_tgrk_rub')) AS rate_tgrk_rub,
       'kafka' AS _source,
        toUInt16(1) As version
  FROM $click_user.lab08_stream_raw
 WHERE JSONExtractString(raw, '_source') = 'exchange_rate';

CREATE MATERIALIZED VIEW IF NOT EXISTS $click_user.lab08_mv_exchange_rates_s3
TO $click_user.lab08_exchange_rates_raw AS
SELECT update_id,
       toDateTime(timestamp,0) AS timestamp,
       rate_tgrk_punk,
       rate_tgrk_rub,
       's3' AS _source,
        toUInt16(2) As version
  FROM $click_user.lab08_raw_exchange_rates;
