create table retail_database (
 "order_id" TEXT,
 "product_code" TEXT,
 "product_name" TEXT,
 "quantity" FLOAT,
 "order_date" DATE, 
 "price" FLOAT,
 "customer_id" TEXT
);

select * from retail_database;

--cek duplicate
SELECT order_id, product_code, product_name, quantity, order_date, price, customer_id, count(*)
From 
	retail_database
GROUP BY 
	order_id, product_code, product_name, quantity, order_date, price, customer_id
HAVING COUNT(*) > 1;

--menghapus data duplicate
WITH duplicates AS (
    SELECT 
        order_id, product_code, product_name, quantity, order_date, price, customer_id,
        ROW_NUMBER() OVER (PARTITION BY 
		product_code, product_name, quantity, order_date, price, customer_id ORDER BY order_id) AS row_num
    FROM 
        retail_database
)
DELETE FROM retail_database
WHERE order_id IN (SELECT order_id FROM duplicates WHERE row_num > 1);


--cek apakah benar data yang di tampilakan memiliki data duplicate
select * from retail_database
where order_id = '494676' and product_name = 'POTTING SHED TEA MUG';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'retail_database';

select * from retail_database
limit 10;

--cek missing value/ nilai is null
select 
	count(*) as total_rows,
	sum(case when order_id is null then 1 else 0 end) as order_id_nulls,
	sum(case when product_code is null then 1 else 0 end) as product_code_nulls,
	sum(case when Product_name is null then 1 else 0 end) as Product_name_nulls,
	sum(case when quantity is null then 1 else 0 end) as quantity_nulls,
	sum(case when order_date is null then 1 else 0 end) as order_date_nulls,
	sum(case when price is null then 1 else 0 end) as price_nulls,
	sum(case when customer_id is null then 1 else 0 end) as customer_id_nulls
from 
	retail_database;

--menghapus nilai null
delete from retail_database
where customer_id is null or product_name is null;

--problem statements

-- 1 produk terlaris berdasarkan jumlah penjualan/quantity
select product_code, 
	product_name, 
	sum(quantity) as total_quantity, 
	sum(quantity * price) as total_quantity
from
	retail_database
group by
	product_code,
	product_name
order by
	4 desc
limit 
	5;

WITH product_stats AS (
    SELECT 
        product_code,
        product_name,
        SUM(quantity) AS total_quantity_sold,
        SUM(quantity * price) AS total_revenue,
        COUNT(DISTINCT order_id) AS total_orders
    FROM retail_database
    GROUP BY product_code, product_name
)

SELECT 
    product_code,
    product_name,
    total_quantity_sold,
    total_revenue,
    total_orders,
    RANK() OVER (ORDER BY total_quantity_sold DESC) AS rank_by_quantity,
    RANK() OVER (ORDER BY total_revenue DESC) AS rank_by_revenue
FROM product_stats
ORDER BY total_quantity_sold DESC, total_revenue DESC
LIMIT 10;

--tren penjualan dari waktu ke waktu(harian)
SELECT 
    DATE(order_date) AS day,
    SUM(quantity) AS total_quantity_sold,
    SUM(quantity * price) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM retail_database
GROUP BY DATE(order_date)
ORDER BY day;

select * from retail_database;

--tren penjualan (bulanan)
SELECT 
    TO_CHAR(order_date, 'MON') AS month,
    SUM(quantity) AS total_quantity_sold,
    SUM(quantity * price) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM retail_database
GROUP BY 1
ORDER BY 2 DESC;

--tren penjualan (tahunan)
SELECT 
    EXTRACT(YEAR FROM order_date) AS year,
    SUM(quantity) AS total_quantity_sold,
    SUM(quantity * price) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM retail_database
GROUP BY 1
ORDER BY year;

--analisis perubahan bulanan
WITH monthly_product_sales AS (
    SELECT 
        product_code,
        product_name,
        TO_CHAR(order_date, 'MON') AS month,
        SUM(quantity) AS monthly_quantity,
        SUM(quantity * price) AS monthly_revenue,
        LAG(SUM(quantity), 1) OVER (PARTITION BY product_code ORDER BY TO_CHAR(order_date, 'MON')) AS prev_month_quantity,
        LAG(SUM(quantity * price), 1) OVER (PARTITION BY product_code ORDER BY TO_CHAR(order_date, 'MON')) AS prev_month_revenue
    FROM retail_database
    GROUP BY product_code, product_name, TO_CHAR(order_date, 'MON')
),

product_growth AS (
    SELECT 
        product_code,
        product_name,
        month,
        monthly_quantity,
        monthly_revenue,
        prev_month_quantity,
        prev_month_revenue,
        (monthly_quantity - prev_month_quantity) / NULLIF(prev_month_quantity, 0) * 100 AS quantity_growth_pct,
        (monthly_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0) * 100 AS revenue_growth_pct
    FROM monthly_product_sales
)

SELECT 
    product_code,
    product_name,
    month,
    monthly_quantity,
    monthly_revenue,
    quantity_growth_pct,
    revenue_growth_pct,
    CASE 
        WHEN quantity_growth_pct > 50 THEN 'Significant Increase'
        WHEN quantity_growth_pct < -50 THEN 'Significant Decrease'
        WHEN quantity_growth_pct > 20 THEN 'Moderate Increase'
        WHEN quantity_growth_pct < -20 THEN 'Moderate Decrease'
        ELSE 'Stable'
    END AS sales_trend
FROM product_growth
WHERE prev_month_quantity IS NOT NULL
ORDER BY ABS(quantity_growth_pct) DESC
LIMIT 20;

--tampilkan 5 pelanggan yang paling sering melakukan pembelian
SELECT customer_id,
	COUNT(DISTINCT order_id) as total_orders
FROM 
	retail_database
GROUP BY
	customer_id
ORDER BY 
	total_orders DESC
LIMIT 5;

WITH sales_by_day_type AS (
    SELECT
        CASE 
            WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN 'Weekend'
            ELSE 'Weekday'
        END AS day_type,
        SUM(quantity) AS total_quantity,
        SUM(quantity * price) AS total_revenue,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM
        retail_database
    WHERE
        order_date >= CURRENT_DATE - INTERVAL '1 year'
    GROUP BY
        CASE 
            WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN 'Weekend'
            ELSE 'Weekday'
        END
)

SELECT
    day_type,
    total_quantity,
    total_revenue,
    total_orders,
    unique_customers,
    ROUND(total_revenue::numeric / total_orders, 2) AS avg_order_value,
    ROUND(total_quantity::numeric / total_orders, 2) AS avg_items_per_order,
    ROUND(total_revenue::numeric / unique_customers, 2) AS revenue_per_customer
FROM
    sales_by_day_type
ORDER BY
    total_revenue DESC;

select * from retail_database;