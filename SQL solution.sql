# Answers to 10 Ad-Hoc Requests Using SQL Queries

-- 1) Provide the list of markets in which customer Atliq Exclusive operates its business in the APAC region.

select distinct(market)
from dim_customer
where customer ="AtliQ Exclusive" and region="APAC";

-- 2) What is the percentage of unique product increase in 2021 vs. 2020?

with unique_products_20 as (
select count(distinct(product_code)) as unique_products_2020 
from fact_sales_monthly
where fiscal_year = 2020),

unique_products_21 as (
select count(distinct(product_code)) as unique_products_2021 
from fact_sales_monthly
where fiscal_year = 2021)

select 
	unique_products_2020, 
	unique_products_2021, 
	round(((unique_products_2021-unique_products_2020)/unique_products_2020)*100,2) as pecentage_chg
from unique_products_20, unique_products_21;

-- 3) Provide a report with all the unique product counts for each segment.

SELECT segment, 
 COUNT(DISTINCT product_code) AS product_count
from dim_product
group by segment 
order by product_count desc;
    
-- 4) Which segment had the most increase in unique products in 2021 vs 2020?

WITH unique_products_2020 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT p.product_code) AS unique_product_count,  -- Added alias
        s.fiscal_year
    FROM fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2020  -- Added filter for 2020
    GROUP BY p.segment, s.fiscal_year
),
unique_products_2021 AS (  -- Added CTE for 2021
    SELECT 
        p.segment,
        COUNT(DISTINCT p.product_code) AS unique_products_count, -- Added alias
        s.fiscal_year
    FROM fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2021  -- Added filter for 2021
    GROUP BY p.segment, s.fiscal_year
)
SELECT 
    up20.segment,
    up20.unique_product_count AS product_count_2020,
    up21.unique_products_count AS product_count_2021,
    (up21.unique_products_count - up20.unique_product_count) AS difference
FROM unique_products_2020 up20
JOIN unique_products_2021 up21 ON up20.segment = up21.segment
ORDER BY difference DESC;


-- 5) Get the products that have the highest and lowest manufacturing costs

select 
	p.product_code, 
	product, segment, 
	manufacturing_cost 
from fact_manufacturing_cost mc
join dim_product p using(product_code)
where manufacturing_cost in (
	(select max(manufacturing_cost) from fact_manufacturing_cost),
	(select min(manufacturing_cost) from fact_manufacturing_cost)
)
order by manufacturing_cost desc;

-- 6) Generate a report which contains the top 5 customers who received an average high Pre Invoice Discount %  for the fiscal year 2021 and in the Indian market.

SELECT c.customer_code,
       c.customer,
       ROUND(AVG(pd.pre_invoice_discount_pct), 4) AS avg_discount_percentage
FROM dim_customer c
JOIN fact_pre_invoice_deductions pd 
  ON c.customer_code = pd.customer_code
WHERE c.market = "India"  -- Changes can be happened  to reference market in dim_customer
  AND pd.fiscal_year = 2021  -- can be changed based on the request
GROUP BY c.customer_code, c.customer
ORDER BY avg_discount_percentage DESC
LIMIT 5;


-- 7) Get the complete report of the Gross sales amount for the customer Atliq Exclusive for each month. 

SELECT 
    MONTHNAME(date) AS month,
    YEAR(date) AS year,
    ROUND(SUM(gross_price * sold_quantity)/1000000, 3) AS gross_sales_amt
FROM fact_gross_price
JOIN fact_sales_monthly USING (product_code, fiscal_year)
JOIN dim_customer 
  ON dim_customer.customer_code = fact_sales_monthly.customer_code
WHERE dim_customer.customer = "AtliQ Exclusive"
GROUP BY month, year
ORDER BY year;

-- 8) In which quarter of 2020, got the maximum total sold quantity?

with qtrly_sales as (
select 
	date, 
	concat("Q",ceil(month(adddate(date, interval 4 month))/3)) as qtr, 
	sold_quantity
from fact_sales_monthly
where fiscal_year = 2020)

select 
	qtr as Quarter,
    round(sum(sold_quantity)/1000000,2) as Total_sold_quantity 
from qtrly_sales
group by qtr
order by Total_sold_quantity desc;

-- 9) Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?

WITH channel_gs AS (
    SELECT 
        channel,
        SUM(gross_price * sold_quantity) AS gross_sales
    FROM fact_gross_price
    JOIN fact_sales_monthly USING(product_code, fiscal_year)
    JOIN dim_customer USING(customer_code)
    WHERE fiscal_year = 2021
    GROUP BY channel
)
SELECT 
    channel,
    ROUND(SUM(gross_sales) / 1000000, 2) AS gross_sales_mln,  -- Sales in millions
    ROUND((SUM(gross_sales) / (SELECT SUM(gross_sales) FROM channel_gs)) * 100, 2) AS pct
FROM channel_gs
GROUP BY channel
ORDER BY pct DESC;


-- 10) Get the Top 3 products in each division that have a high total sold quantity in the fiscal year 2021?
WITH div_sales AS (
    SELECT
        p.division,
        p.product_code,
        CONCAT(p.product, " ", p.variant) AS product_name,
       	sum(sold_quantity) as total_sold_quantity,
        RANK() OVER (PARTITION BY p.division ORDER BY SUM(s.sold_quantity) DESC) AS rank_order
    FROM fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code  -- More explicit JOIN condition
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, p.product_code, p.product, p.variant -- Include individual product and variant in GROUP BY
)
SELECT *
FROM div_sales
WHERE rank_order <= 3;

