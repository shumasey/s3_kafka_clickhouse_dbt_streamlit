import streamlit as st
import clickhouse_connect
import pandas as pd
import plotly.express as px
import os
import time
import queries

refresh_toggle = st.toggle("Auto_refresh each 5 seconds", value = True)
if refresh_toggle:
    if "last_refresh" not in st.session_state:
        st.session_state.last_refresh = time.time()

    if time.time() - st.session_state.last_refresh > 5:
        st.session_state.last_refresh = time.time()
        st.rerun()

click_user=os.environ["CLICK_USER"]
click_host=os.environ["CLICK_HOST"]
click_port=os.environ["CLICK_PORT"]
click_pass=os.environ["CLICK_PASS"]

client = clickhouse_connect.get_client(
    host=click_host,
    username=click_user,
    port=click_port,
    password=click_pass
)

#weekdays = st.multiselect(
#    "Choose days",
#    ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
#    default = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"] 
#        )
#week_mapping = {
#    "Monday": 1, 
#    "Tuesday": 2, 
#    "Wednesday": 3,
#    "Thursday":4, 
#    "Friday":5, 
#    "Saturday":6,
#    "Sunday":7
#        }
#weekday_chosen = [week_mapping[w] for w in weekdays]
##if weekday_chosen:
#    in_clause = ",".join(str(x) for x in weekday_chosen)
#    where_clause = f"where trx_weekday in ({in_clause})"
#else:
#    where_clause = ""
#
#def apply_where_clause(sql):
#    if not weekday_chosen:
#        return sql
#    sql = sql + f" "

st.set_page_config(layout="wide")
leave_only_real_users = st.toggle("Leave only real users")
st.title("Lab08 - Проект — Транзакционная аналитика")

def toggle_filter(df):
    if leave_only_real_users:
        return df[df["is_real_user"] == 1]
    return df
# -----------------------------
# KPI: total transactions
# -----------------------------
left, right = st.columns(2)
with left:
    st.markdown("Сколько всего было транзакций")
    cnt = client.query_df(queries.basic_transaction_hourly_count)
    st.metric(
        label='trx count',
        value=f"{cnt['cnt'][0]}"
    )
with right:
    kafka_cnt = client.query_df(queries.real_time_kafka_counter)
    st.metric(
            label='kafka last 5 minutes event counter',
            value=f"{kafka_cnt['cnt'].iloc[0]:,}"
            )
# -----------------------------
# Two-column layout
# -----------------------------
left, right = st.columns([1, 1])

# -----------------------------
# LEFT: Bar chart (transactions per hour)
# -----------------------------
with left:
    st.subheader("Распределение транзакций по часам")

    df = client.query_df(queries.transaction_hourly_cnt)
    df = toggle_filter(df)
    df['cnt'] = df['cnt'].astype(float)
    fig_bar = px.bar(
        df,
        x="hour",
        y="cnt",
        labels={"hour": "Hour of Day", "cnt": "Count"},
        title="Transactions per Hour",
        color="cnt",
        color_continuous_scale=px.colors.sequential.Plasma
    )

    st.plotly_chart(fig_bar, width="content", on_select="rerun")

# -----------------------------
# RIGHT: Pie chart (purchases per hour)
# -----------------------------
with right:
    st.subheader("Распределение покупок по часам")

    df = client.query_df(queries.purchases_cnt)
    df = toggle_filter(df)
    df['hour'] = df['hour'].astype(int)

    fig_pie = px.pie(
        df,
        names="hour",
        values="cnt",
        title="Purchases per Hour",
        hole=0.3  # donut style
    )

    st.plotly_chart(fig_pie, width="content", on_select="rerun")

# -----------------------------
# Revenue in base currency (daily)
# -----------------------------
st.subheader("Выручка в базовой валюте")

df_rev = client.query_df(queries.revenue_in_base_ccy)
df_rev = toggle_filter(df_rev)
df_rev['date'] = pd.to_datetime(df_rev['date'])
df_rev['amt'] = df_rev['amt'].astype(float)
fig_rev = px.bar(
    df_rev,
    x="date",
    y="amt",
    labels={"date": "Day", "amt": "Revenue in Base Currency"},
    title="Выручка в TGRK",
    color="amt",
    color_continuous_scale=px.colors.sequential.Sunset_r
)

st.plotly_chart(fig_rev, width="content", on_select="rerun")

left, middle, right = st.columns(3)
promos_df = client.query_df(queries.promo_usage)

with left:
    st.metric("Working promos", 0)

with middle:
    st.metric("Expired promos", promos_df["expired"].sum())

with right:
    st.metric("Overused", promos_df["is_overused"].sum())

st.subheader("Promo usage")
st.dataframe(promos_df)

chart = px.bar(
        promos_df,
        x ="promo_code_id",
        y="remaining_usage_cnt",
        color="remaining_usage_cnt",
        color_continuous_scale=px.colors.sequential.Plasma_r,
        title="How many uses are left for promo"
        )
st.plotly_chart(chart, width="content")

st.subheader("Currency distribution")
left, right = st.columns(2)
with left:
    ccy_df = client.query_df(queries.currency_pie)
    ccy_pie_chart = px.pie(
        ccy_df,
        names="currency",
        values="base_amt",
        title="currency distibution"
            )
    st.plotly_chart(ccy_pie_chart, width="content")

with right:
    ccy_daily = client.query_df(queries.currency_daily_distibution)
    ccy_daily_chart = px.bar(
        ccy_daily,
        x="date",
        y="amt",
        color="currency",
        title="Daily Revenue by ccy"
            )
    st.plotly_chart(ccy_daily_chart, width="content")

ccy_hourly_dist_df = client.query_df(queries.currency_hourly_distribution)
ccy_hourly_dist_chart = px.density_heatmap(
        ccy_hourly_dist_df,
        x="hour",
        y="currency",
        z="amt",
        title="hourly distibution"
        )
st.plotly_chart(ccy_hourly_dist_chart, width="content")

st.subheader("Cohort Analysis")
cohorts = client.query_df(queries.cohort_analysis)
cohort_matrix = cohorts.pivot_table(
    index="first_purchase_day",
    columns="days_passed",
    values="users_cnt",
    fill_value=0
        )
cohort_chart = px.imshow(
        cohort_matrix,
        labels=dict(x="Day",y="First Purchase", color="Active Users"),
        aspect="auto",
        color_continuous_scale="Blues"
        )
st.plotly_chart(cohort_chart, width="content")

st.subheader("Cancellations")
cancellation_percentage = client.query_df(queries.cancellation_percentage_query)
st.metric(
    label="% of cancellations",
    value=f"{cancellation_percentage['canc_perc'][0]}"
        )
