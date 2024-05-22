connection: "bigquery-handson"
label: "ECサイトデータ_BQ"
include: "/*.view" # include all the views

#datagroup: ecommerce_etl {
#  sql_trigger: SELECT max(created_at) FROM ecomm.events ;;
#  max_cache_age: "24 hours"}

#persist_with: ecommerce_etl
############ Base Explores #############

# FROM
explore: order_items {
  label: "オーダー、アイテム、ユーザー関連"
  view_name: order_items
  view_label: "オーダー"
  always_filter: {
    filters: {
      field: created_date
      value: "last 90 days"
    }
  }

  join: inventory_items {
    view_label: "在庫アイテム"
    #Left Join only brings in items that have been sold as order_item
    type: full_outer
    relationship: one_to_one
    sql_on: ${inventory_items.id} = ${order_items.inventory_item_id} ;;
  }

  join: users {
    view_label: "ユーザー"
    relationship: many_to_one
    sql_on: ${order_items.user_id} = ${users.id} ;;
  }

  join: products {
    view_label: "プロダクト"
    relationship: many_to_one
    sql_on: ${products.id} = ${inventory_items.product_id} ;;
  }

  query: order_last_7days {
    label: "直近7日間の総売上推移"
    dimensions: [created_date]
    measures: [order_count]
    filters: [order_items.created_date: "7 days"]
  }

  query: returned_items {
    label: "返品数の多い商品一覧"
    dimensions: [products.item_name]
    measures: [returned_count]
    filters: [order_items.created_date: "30 days", order_items.returned_count: ">1"]
  }
}
