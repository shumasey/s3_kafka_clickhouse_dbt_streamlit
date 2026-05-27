basic_transaction_hourly_count = """
select sum(trx_cnt) as cnt
 from alexey_shumakov.lab08_transactions_dm_agg
""" 
transaction_hourly_cnt = """
select trx_hour as `hour`
      , is_real_user
      , sum(trx_cnt) as cnt
  from alexey_shumakov.lab08_transactions_dm_agg
group by trx_hour, is_real_user
order by trx_hour
""" 
purchases_cnt = """
select trx_hour as `hour`
     , is_real_user
     , sum(purchase_cnt) as cnt
  from alexey_shumakov.lab08_transactions_dm_agg
group by trx_hour, is_real_user      
"""
revenue_in_base_ccy = """
select trx_date as `date`
     , is_real_user
     , sum(revenue_tgrk) as amt
 from alexey_shumakov.lab08_transactions_dm_agg
group by trx_date, is_real_user
order by trx_date
""" 
promo_usage = """
with promo_usage as (
    select promo_code_id,
           count() as promo_used_cnt
      from alexey_shumakov.lab08_transactions_deduped
     where promo_code_id <> 0
     group by promo_code_id
)
select promos.promo_code_id
     , promos.max_uses
     , promos.expiry_date
     , promo_usage.promo_used_cnt
     , max_uses - promo_used_cnt as remaining_usage_cnt
     , now() > promos.expiry_date as expired
     , promo_used_cnt >= max_uses as is_overused
     , now() <= expiry_date and promo_used_cnt < max_uses as is_working
  from alexey_shumakov.lab08_promo_codes as promos
       left join promo_usage
           on promos.promo_code_id = promo_usage.promo_code_id
order by promos.promo_code_id
"""
currency_pie = """
select currency
     , sum(purchase_cnt) as trx_count
     , round(sum(revenue_tgrk),2) as base_amt
 from alexey_shumakov.lab08_transactions_dm_agg
group by currency
""" 
currency_daily_distibution = """
select trx_date as `date`
     , currency
     , sum(revenue_tgrk) as amt
 from alexey_shumakov.lab08_transactions_dm_agg
group by trx_date, currency
order by trx_date
"""

currency_hourly_distribution = """
select trx_hour as `hour`
     , currency
     , sum(revenue_tgrk) as amt
 from alexey_shumakov.lab08_transactions_dm_agg
group by trx_hour, currency
"""

real_time_kafka_counter = """
select count() as cnt
  from alexey_shumakov.lab08_kafka_real_time
where created_at >= now() - interval 5 minute
"""

cohort_analysis = """
with first_event as (
    select user_id
         , user_uuid
         , min(trx_date) as first_event_day
      from alexey_shumakov.lab08_transactions_dm
     where user_id <> 0
           and user_uuid <> toUUID('00000000-0000-0000-0000-000000000000')
           and is_purchase = 1
    group by user_id, user_uuid
), cte as (
    select fe.user_id as user_id,
           toStartOfDay(fe.first_event_day) as first_purchase_day,
           toStartOfDay(trx.trx_date) as trx_date,
           dateDiff('day', first_purchase_day, trx_date) days_passed
      from alexey_shumakov.lab08_transactions_dm as trx
           inner join first_event as fe
               on trx.user_id = fe.user_id
               and trx.user_uuid = fe.user_uuid
)
select first_purchase_day
     , days_passed
     , countDistinct(user_id) as users_cnt
  from cte
 where days_passed > 0
group by first_purchase_day, days_passed
order by first_purchase_day, days_passed

"""
cancellation_percentage_query = """
with cte as (
    select transaction_id,
           is_cancelled
      from alexey_shumakov.lab08_dm_base_common
)
select countIf(is_cancelled='ДА') as cancelled_cnt,
       count() as total_cnt,
       round(cancelled_cnt * 100 / total_cnt, 2) as canc_perc
  from cte
"""
cancellation_reasons = """

with canc_cte as (

    select distinct reason
         , count() over(partition by reason) as reason_cnt
         , count()  over() as overall_cnt
      from alexey_shumakov.lab08_core_cancellations
)
select reason
     ,  round(reason_cnt * 100 / overall_cnt, 2) as canc_reason_percentage
  from canc_cte
"""
