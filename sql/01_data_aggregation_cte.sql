CREATE VIEW vw_customer_analytical_base AS

WITH valid_orders AS (
	SELECT 
		order_id,
		customer_id,
		order_purchase_timestamp,
		order_estimated_delivery_date,
		order_delivered_customer_date
	FROM olist_orders_dataset
	WHERE order_status = 'delivered'
),
logistic_metrics AS (
	SELECT
		v.order_id,
		v.customer_id,
		v.order_purchase_timestamp,
		(julianday(v.order_delivered_customer_date) - julianday(v.order_estimated_delivery_date)) AS delivery_delay_days,
		SUM(p.payment_value) AS order_total_value
	FROM valid_orders v
	JOIN olist_order_payments_dataset p ON v.order_id = p.order_id
	GROUP BY v.order_id
),
financial_metrics AS (
	SELECT
		v.order_id,
		v.customer_id,
		SUM(i.price + i.freight_value) AS total_order_value,
		SUM(i.freight_value) / SUM(i.price + i.freight_value) AS freight_ratio
	FROM valid_orders v
	JOIN olist_order_items_dataset i ON v.order_id = i.order_id
	GROUP BY v.order_id
),
customer_rfm AS (
	SELECT
		c.customer_unique_id,
		COUNT(DISTINCT l.order_id) AS frequency,
		SUM(l.order_total_value) AS lifetime_spend,
		(julianday('2018-10-17') - julianday(MAX(l.order_purchase_timestamp))) AS recency_days,
		
		AVG(l.delivery_delay_days) AS avg_delivery_delay,
		AVG(f.freight_ratio) AS avg_freight_ratio
	FROM logistic_metrics l
	JOIN financial_metrics f ON l.order_id = f.order_id
	JOIN olist_customers_dataset c ON l.customer_id = c.customer_id
	GROUP BY c.customer_unique_id
)

SELECT *
FROM customer_rfm