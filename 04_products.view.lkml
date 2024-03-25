view: products {
  sql_table_name: looker-private-demo.ecomm.products ;;

  dimension: id {
    primary_key: yes
    type: number
    sql: ${TABLE}.id ;;
  }

  dimension: category {
    label: "カテゴリ"
    sql: TRIM(${TABLE}.category) ;;
    drill_fields: [item_name]
  }

  dimension: item_name {
    label: "商品名"
    sql: TRIM(${TABLE}.name) ;;
  }

  parameter: brand_selector {
    label: "ブランド比較フィルタ"
    suggest_dimension: brand
  }

  dimension: brand_comparitor {
    type: string
    label: "ブランド比較"
    sql:
      CASE
        WHEN {% parameter brand_selector %} = ${brand} THEN '(1) ' || ${brand}
        ELSE '(2) その他'
      END ;;
  }

  dimension: brand {
    label: "ブランド名"
    sql: TRIM(${TABLE}.brand) ;;

    link: {
      label: "Website"
      url: "http://www.google.com/search?q={{ value | encode_uri }}+clothes&btnI"
      icon_url: "http://www.google.com/s2/favicons?domain=www.{{ value | encode_uri }}.com"
    }

    link: {
      label: "Facebook"
      url: "http://www.google.com/search?q=site:facebook.com+{{ value | encode_uri }}+clothes&btnI"
      icon_url: "https://upload.wikimedia.org/wikipedia/commons/c/c2/F_icon.svg"
    }

    link: {
      label: "{{value}} Analytics Dashboard"
      url: "/dashboards/thelook_japanese_bq::brand_analytics_dashboard?ブランド={{ value | encode_uri }}"
      icon_url: "https://www.svgrepo.com/show/354012/looker-icon.svg"
    }

    drill_fields: [category, item_name]
  }

  dimension: retail_price {
    label: "小売価格"
    type: number
    sql: ${TABLE}.retail_price ;;
  }

  dimension: department {
    label: "部門"
    sql: TRIM(${TABLE}.department) ;;
  }

  dimension: sku {
    label: "最小管理単位"
    sql: ${TABLE}.sku ;;
  }

  dimension: distribution_center_id {
    label: "物流センターID"
    type: number
    sql: CAST(${TABLE}.distribution_center_id AS INT64) ;;
  }

  ## MEASURES ##

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  measure: brand_count {
    label: "ブランド数"
    type: count_distinct
    sql: ${brand} ;;
    drill_fields: [brand, detail2*, -brand_count] # show the brand, a bunch of counts (see the set below), don't show the brand count, because it will always be 1
  }

  measure: category_count {
    label: "カテゴリ数"
    alias: [category.count]
    type: count_distinct
    sql: ${category} ;;
    drill_fields: [category, detail2*, -category_count] # don't show because it will always be 1
  }

  measure: department_count {
    label: "部門数"
    alias: [department.count]
    type: count_distinct
    sql: ${department} ;;
    drill_fields: [department, detail2*, -department_count] # don't show because it will always be 1
  }

  set: detail {
    fields: [id, item_name, brand, category, department, retail_price, customers.count, orders.count, order_items.count, inventory_items.count]
  }

  set: detail2 {
    fields: [category_count, brand_count, department_count, count, customers.count, orders.count, order_items.count, inventory_items.count, products.count]
  }
}
