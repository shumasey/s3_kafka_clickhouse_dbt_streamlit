create table $click_user.lab08_transactions_dm (
    transaction_id UInt32,
    user_id UInt16,
    user_uuid UUID,
    status Enum8('completed' = 1, 'failed' = 2),
    transaction_type Enum8('purchase' = 1, 'transfer' = 2, 'refund' = 3),
    promo_code_id UInt8,
    trx_datetime DateTime('UTC'),
    trx_date DateTime('UTC'),
    trx_weekday UInt8,
    trx_hour DateTime('UTC'),
    abs_amount UInt32,
    currency Enum8('RUB' = 1, 'TGRK' = 2, 'PUNK' =3),
    amount_tgrk Float64,
    is_purchase UInt8,
    is_real_user UInt8,
    is_cancelled UInt8,
    is_promo_used UInt8,
    expiry_date Date,
    is_promo_expired UInt8
)
engine = MergeTree
partition by trx_date
order by (trx_date, transaction_id, trx_datetime);

create table $click_user.lab08_transactions_dm_agg (
    trx_date DateTime('UTC'),
    trx_weekday UInt8,
    trx_hour UInt8,
    currency Enum8('RUB' = 1, 'TGRK' = 2, 'PUNK' =3),
    is_real_user UInt8,
    trx_cnt UInt64,
    purchase_cnt UInt64,
    revenue_tgrk Float64
)
ENGINE = SummingMergeTree
PARTITION BY trx_date
ORDER BY (trx_date, trx_weekday,trx_hour, currency, is_real_user);

create materialized view $click_user.lab08_mv_transactions_dm
to $click_user.lab08_transactions_dm as
with trx as (
    select *,
           1 as join_key,
           toStartOfDay(created_at) as trx_date,
           toDayOfWeek(created_at) as trx_weekday,
           toStartOfHour(created_at) as trx_hour,
           abs(amount) as abs_amount
      from $click_user.lab08_transactions_deduped
), cnl as (
    select *,
           toStartOfDay(cancelled_at) as cancelled_date
      from $click_user.lab08_cancellations_deduped

), rates as (

    select *
         , 1 as join_key
      from $click_user.lab08_mv_rates_deduped
)
select trx.transaction_id as transaction_id,
       trx.user_id as user_id,
       trx.user_uuid as user_uuid,
       trx.status as status,
       trx.transaction_type as transaction_type,
       trx.promo_code_id as promo_code_id,
       trx.created_at as trx_datetime,
       trx.trx_date as trx_date,
       trx.trx_weekday as trx_weekday,
       trx.trx_hour as trx_hour,
       trx.abs_amount as abs_amount,
       trx.currency as currency,
       case
           when trx.currency = 'TGRK' then trx.abs_amount
           else trx.abs_amount * coalesce(rates.rate_tgrk_rub, 1.0)
       end as amount_tgrk,
       case
           when trx.transaction_type = 'purchase' and trx.status = 'completed' then 1
           else 0
       end as is_purchase,
       case
           when u.is_test_user = 1 then 0
           else 1
       end is_real_user,
       case
           when cnl.original_transaction_id > 0  then 1
           else 0
       end is_cancelled,
       case
           when trx.promo_code_id <> 0 then 1
           else 0
       end as is_promo_used,
       promo.expiry_date,
       case
           when trx.promo_code_id <> 0 and trx.created_at > promo.expiry_date then 1
           else 0
       end as is_promo_expired
  from trx
       asof left join rates
           on trx.join_key = rates.join_key
           and trx.created_at >= rates.timestamp
       left join $click_user.lab08_users as u
           on trx.user_id = u.user_id
       left join cnl
           on trx.transaction_id = cnl.original_transaction_id
           and trx.amount = cnl.refund_amount
           and cnl.cancelled_date = (trx.trx_date + INTERVAL 1 DAY)
       left join $click_user.lab08_promo_codes as promo
           on trx.promo_code_id = promo.promo_code_id
where trx.user_id <> 0
       or trx.user_uuid <> toUUID('00000000-0000-0000-0000-000000000000');

create materialized view $click_user.lab08_mv_transaction_dm_agg
to $click_user.lab08_transactions_dm_agg as
select trx_date,
       toHour(trx_hour) as trx_hour,
       currency,
       is_real_user,
       count() as trx_cnt,
       sum(is_purchase) as purchase_cnt,
       sum(amount_tgrk) as revenue_tgrk
  from $click_user.lab08_transactions_dm
group by trx_date, trx_hour, currency, is_real_user;
