view: order_items {
  sql_table_name: looker-private-demo.ecomm.order_items ;;
  ########## IDs, Foreign Keys, Counts ###########

  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}.id ;;
  }

  dimension: inventory_item_id {
    type: number
    hidden: yes
    sql: ${TABLE}.inventory_item_id ;;
  }

  dimension: user_id {
    type: number
    hidden: yes
    sql: ${TABLE}.user_id ;;
  }

  measure: count {
    label: "商品数"
    type: count_distinct
    sql: ${id} ;;
    drill_fields: [detail*]
  }

  measure: order_count {
    view_label: "オーダー"
    label: "オーダー数"
    type: count_distinct
    drill_fields: [detail*]
    sql: ${order_id} ;;
  }


  measure: count_last_28d {
    label: "直近28日内受注商品数"
    description: "受注日付が直近28日以内となっている商品数"
    type: count_distinct
    sql: ${id} ;;
#     hidden: yes
    filters:
    {field:created_date
      value: "28 days"
    }}

  dimension: order_id {
    label: "オーダーID"
    type: number
    sql: ${TABLE}.order_id ;;


    action: {
      label: "スラックへ送信"
      url: "https://hooks.zapier.com/hooks/catch/1662138/tvc3zj/"

      param: {
        name: "user_dash_link"
        value: "/dashboards/thelook_japanese_bq::user_lookup_dashboard?Email={{ users.email._value}}"
      }

      form_param: {
        name: "メッセージ"
        type: textarea
        default: "Hey,
        Could you check out order #{{value}}. It's saying its {{status._value}},
        but the customer is reaching out to us about it.
        "
      }
# ~{{ _user_attributes.first_name}}
      form_param: {
        name: "受信ユーザ"
        type: select
        default: "zevl"
        option: {
          name: "zevl"
          label: "Zev"
        }
        option: {
          name: "slackdemo"
          label: "Slack Demo User"
        }

      }

      form_param: {
        name: "Channel"
        type: select
        default: "cs"
        option: {
          name: "cs"
          label: "Customer Support"
        }
        option: {
          name: "general"
          label: "General"
        }

      }


    }



  }

  ########## Time Dimensions ##########

  dimension_group: returned {
    label: "返品"
    type: time
    timeframes: [time, date, week, month, raw]
    sql: ${TABLE}.returned_at ;;
  }

  dimension_group: shipped {
    label: "出荷"
    type: time
    timeframes: [date, week, month, raw]
    sql: CAST(${TABLE}.shipped_at AS TIMESTAMP) ;;
  }

  dimension_group: delivered {
    label: "到着"
    type: time
    timeframes: [date, week, month, raw]
    sql: CAST(${TABLE}.delivered_at AS TIMESTAMP) ;;
  }

  dimension_group: created {
    #X# group_label:"Order Date"
    label: "受注"
    type: time
    timeframes: [time, hour, date, week, month, year, hour_of_day, day_of_week, month_num, raw, week_of_year]
    sql: ${TABLE}.created_at ;;
  }

  dimension: reporting_period {
    group_label: "Order Date"
    label: "レポート期間"
    sql: CASE
        WHEN EXTRACT(YEAR from ${created_raw}) = EXTRACT(YEAR from CURRENT_TIMESTAMP())
        AND ${created_raw} < CURRENT_TIMESTAMP()
        THEN 'This Year to Date'

      WHEN EXTRACT(YEAR from ${created_raw}) + 1 = EXTRACT(YEAR from CURRENT_TIMESTAMP())
      AND CAST(FORMAT_TIMESTAMP('%j', ${created_raw}) AS INT64) <= CAST(FORMAT_TIMESTAMP('%j', CURRENT_TIMESTAMP()) AS INT64)
      THEN 'Last Year to Date'

      END
      ;;
  }

  dimension: days_since_sold {
    hidden: yes
    sql: TIMESTAMP_DIFF(${created_raw},CURRENT_TIMESTAMP(), DAY) ;;
  }

  dimension: months_since_signup {
    view_label: "オーダー"
    label: "登録から注文までの月数"
    type: number
    sql: CAST(FLOOR(TIMESTAMP_DIFF(${created_raw}, ${users.created_raw}, DAY)/30) AS INT64) ;;
  }

########## Logistics ##########

  dimension: status {
    label: "ステータス"
    description: "発送ステータス：プロセス中, 出荷, 完了, 返品, キャンセル"
    type: string
    sql:
      CASE
        WHEN ${TABLE}.status = 'Processing' THEN 'プロセス中'
        WHEN ${TABLE}.status = 'Shipped' THEN '出荷'
        WHEN ${TABLE}.status = 'Complete' THEN '完了'
        WHEN ${TABLE}.status = 'Returned' THEN '返品'
        WHEN ${TABLE}.status = 'Cancelled' THEN 'キャンセル'
        ELSE null
      END ;;
  }

  parameter: days_to_process_sensitivity {
    label: "プロセス期間上限"
    type: number
    default_value: "10"
  }

  dimension: days_to_process {
    label: "プロセス期間（日）"
    description: "受注から発送するまでに掛かった日数 (発送日 - 受注日)"
    type: number
    sql: CASE
        WHEN ${status} = 'プロセス中' THEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), ${created_raw}, DAY)*1.0
        WHEN ${status} IN ('出荷', '完了', '返品') THEN TIMESTAMP_DIFF(${shipped_raw}, ${created_raw}, DAY)*1.0
        WHEN ${status} = 'キャンセル' THEN NULL
      END
       ;;
  }

  dimension: shipping_time {
    label: "発送期間（日）"
    description: "発送してから到着までに掛かった日数 (到着日 - 発送日)"
    type: number
    sql: TIMESTAMP_DIFF(${delivered_raw}, ${shipped_raw}, DAY)*1.0 ;;
  }

  measure: average_days_to_process {
    label: "平均プロセス期間（日）"
    type: average
    value_format_name: decimal_2
    sql: ${days_to_process} ;;
    html:
      {% assign var=_filters['order_items.days_to_process_sensitivity'] | plus:0 %}
      {% if var < order_items.average_days_to_process._value %}
      <div style="color: black; background-color: red; font-size:100%; text-align:center">{{ rendered_value }}</div>
      {% else %}
      {{rendered_value}}
      {% endif %} ;;
  }

  measure: average_shipping_time {
    label: "平均発送期間（日）"
    type: average
    value_format_name: decimal_2
    sql: ${shipping_time} ;;
  }

########## Financial Information ##########

  dimension: sale_price {
    label: "売上"
    type: number
    value_format_name: usd
    sql: ${TABLE}.sale_price;;
  }

  dimension: gross_margin {
    label: "商品別粗利益"
    description: "売上 - コスト"
    type: number
    value_format_name: usd
    sql: ${sale_price} - ${inventory_items.cost} ;;
  }

  dimension: item_gross_margin_percentage {
    label: "商品別粗利益率"
    description: "商品別粗利益 / 売上"
    type: number
    value_format_name: percent_2
    sql: 1.0 * ${gross_margin}/NULLIF(${sale_price},0) ;;
  }

  dimension: item_gross_margin_percentage_tier {
    label: "商品別粗利益率層"
    description: "商品別粗利益率を10%刻みでバケット化"
    type: tier
    sql: 100*${item_gross_margin_percentage} ;;
    tiers: [0, 10, 20, 30, 40, 50, 60, 70, 80, 90]
    style: interval
  }

  measure: total_sale_price {
    label: "総売上"
    description: "売上をSUMしたもの"
    type: sum
    value_format_name: usd
    sql: ${sale_price} ;;
    drill_fields: [detail*]
  }

  measure: total_gross_margin {
    label: "粗利益"
    description: "(売上 - コスト)をSUMしたもの"
    type: sum
    value_format_name: usd
    sql: ${gross_margin} ;;
    drill_fields: [detail*]
  }

  measure: average_sale_price {
    label: "平均売上"
    description: "売上の平均をとったもの"
    type: average
    value_format_name: usd
    sql: ${sale_price} ;;
    drill_fields: [detail*]
  }

  measure: median_sale_price {
    label: "中央価格値"
    description: "売上の中央値をとったもの"
    type: median
    value_format_name: usd
    sql: ${sale_price} ;;
    drill_fields: [detail*]
  }

  measure: average_gross_margin {
    label: "平均商品別粗利益"
    type: average
    value_format_name: usd
    sql: ${gross_margin} ;;
    drill_fields: [detail*]
  }

  measure: total_gross_margin_percentage {
    label: "平均商品別粗利率"
    description: "(粗利 / 売上)"
    type: number
    value_format_name: percent_2
    sql: 1.0 * ${total_gross_margin}/ NULLIF(${total_sale_price},0) ;;
  }

  measure: average_spend_per_user {
    label: "ユーザー平均消費額"
    description: "(売上 / ユーザー数)"
    type: number
    value_format_name: usd
    sql: 1.0 * ${total_sale_price} / NULLIF(${users.count},0) ;;
    drill_fields: [detail*]
  }

########## Return Information ##########

  dimension: is_returned {
    type: yesno
    label: "返品商品ラベル"
    description: "返却日時が入っている場合にYesを返す"
    sql: ${returned_raw} IS NOT NULL ;;
  }

  measure: returned_count {
    label: "返品商品数"
    description: "返品商品ラベル=Yes の商品数"
    type: count_distinct
    sql: ${id} ;;
    filters: {
      field: is_returned
      value: "yes"
    }
    drill_fields: [detail*]
  }

  measure: returned_total_sale_price {
    label: "返品額"
    description: "返品商品ラベル=Yes の売上"
    type: sum
    value_format_name: usd
    sql: ${sale_price} ;;
    filters: {
      field: is_returned
      value: "yes"
    }
  }

  measure: return_rate {
    label: "返品率"
    description: "(返品商品数 / 全商品数)"
    type: number
    value_format_name: percent_2
    sql: 1.0 * ${returned_count} / nullif(${count},0) ;;
  }




########## Parameter Aggregation Examples ##########
#   parameter: category_to_count_1 {
#     type: string
#     suggest_dimension: products.category
#   }
#
#   measure: category_count_1 {
#     type: sum
#     sql:
#       CASE
#         WHEN ${products.category} = {% parameter category_to_count_1 %}
#           THEN 1
#         ELSE 0
#       END ;;
#   }
#
#   parameter: category_to_count_2 {
#     type: string
#     suggest_dimension: products.category
#   }
#
#   measure: category_count_2 {
#     type: sum
#     sql:
#     CASE
#       WHEN ${products.category} = {% parameter category_to_count_2 %}
#         THEN 1
#       ELSE 0
#     END ;;
#   }
#
#   measure: accessory_count {
#     label: "アクセサリー数"
#     type: count
#     filters: {
#       field: products.category
#       value: "Accessories"
#     }
#   }
#
#   measure: jeans_count {
#     label: "ジーンズ数"
#     type: count
#     filters: {
#       field: products.category
#       value: "Jeans"
#     }
#   }
#
#   measure: sweaters_count {
#     label: "セーター数"
#     type: count
#     filters: {
#       field: products.category
#       value: "Sweaters"
#     }
#   }

########## Parameter Date Examples ##########
  parameter: time_period {
    label: "指定期間"
    allowed_value: {value: "Date"}
    allowed_value: {value: "Week"}
    allowed_value: {value: "Month"}
    allowed_value: {value: "Year"}
  }

  dimension: cohort_time_period {
    label: "コホート期間"
    sql:
    CASE
      WHEN {% parameter time_period %} = 'Date' THEN ${created_date}::varchar
      WHEN {% parameter time_period %} = 'Week' THEN ${created_week}::varchar
      WHEN {% parameter time_period %} = 'Month' THEN ${created_month}::varchar
      WHEN {% parameter time_period %} = 'Year' THEN ${created_year}::varchar
      ELSE ${created_date}::varchar
    END ;;
  }




########## Sets ##########

  set: detail {
    fields: [id, order_id, status, created_date, sale_price, products.brand, products.item_name, users.portrait, users.name, users.email]
  }
  set: return_detail {
    fields: [id, order_id, status, created_date, returned_date, sale_price, products.brand, products.item_name, users.portrait, users.name, users.email]
  }
}
