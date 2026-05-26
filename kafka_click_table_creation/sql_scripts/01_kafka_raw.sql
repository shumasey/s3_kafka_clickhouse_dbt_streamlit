CREATE TABLE IF NOT EXISTS $click_user.lab08_stream_raw_kafka_queue
( raw String
) ENGINE = Kafka SETTINGS kafka_broker_list = '$kafka_host:$kafka_port',
                          kafka_topic_list = 'lab08_transactions',
                          kafka_group_name = 'lab08_transactions_consumer_group_1',
                          kafka_format = 'RawBLOB';

CREATE TABLE IF NOT EXISTS $click_user.lab08_stream_raw
( raw String
)
ENGINE = MergeTree ORDER BY tuple()
SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW IF NOT EXISTS $click_user.lab08_mv_kafka_queue_raw 
TO $click_user.lab08_stream_raw AS
SELECT * FROM $click_user.lab08_stream_raw_kafka_queue;
