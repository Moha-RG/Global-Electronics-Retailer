
USE electronics_retailer;




					-- (( exploring the data and take quick look at columns data type )) --


SELECT * FROM fact_sales ;
SELECT * FROM dim_customers ;
SELECT * FROM dim_stores ;
SELECT * FROM dim_products ;

describe fact_sales;
describe dim_customers ;
describe dim_stores ;
describe dim_products ;


--------------------------------------------------------------------------------------------------------------


					-- (( CLEAN DATA )) -- (one table for instance)


-- ( check if there are any null values in the tables )

SELECT 
  SUM(Order_id IS NULL) ,
  SUM(Order_Date IS NULL) ,
  SUM(Customer_id IS NULL) ,
  SUM(Store_id IS NULL) ,
  SUM(Product_id IS NULL) ,
  SUM(Quantity IS NULL)
FROM fact_sales;


-- ( check if there are any duplicate values in unique columns )

select customer_id, count(customer_id)
from dim_customers
group by customer_id
having count(*) > 1 ;

-- check if there is any wrong date
SELECT Order_id, Order_Date FROM fact_sales
WHERE  Order_Date > CURDATE();


-- ( check if there are any outliers (by analyzing the quantity and price for the maximum value and checking for any potential errors )

select fs.Quantity,dp.Unit_Price, (fs.Quantity*dp.Unit_Price)
from fact_sales fs
inner join dim_products dp
on fs.Product_id = dp.Product_id
where (fs.Quantity*dp.Unit_Price) =
 (select max(fs.Quantity*dp.Unit_Price)
	from fact_sales fs
	inner join dim_products dp
	on fs.Product_id = dp.Product_id) ;


--------------------------------------------------------------------------------------------------------------


					-- (( KPIs )) --


-- ( total revenue, cost and gross profit )

select
  sum(fs.Quantity * dp.Unit_Price) as total_revenue,
  sum(fs.Quantity * dp.Unit_Cost) as total_cost,
  sum(fs.Quantity * (dp.Unit_Price - dp.Unit_Cost)) as gross_profit
from fact_sales fs
join dim_products dp on fs.Product_id = dp.Product_id;

										-- total revenue = 670793.78  |  total cost = 398918.05  |  total gross profit = 271875.73


-- ( each month revenue, cost and profit )

select
  date_format(Order_Date, '%Y-%m') as month,
  sum(fs.Quantity * dp.Unit_Price) as total_revenue,
  sum(fs.Quantity * dp.Unit_Cost) as total_cost,
  sum(fs.Quantity * (dp.Unit_Price - dp.Unit_Cost)) as gross_profit
from fact_sales fs
join dim_products dp on fs.Product_id = dp.Product_id
group by month
order by month;
									  
										-- (2016-01) -->  r= 444180.20 	c= 243643.08	p= 200537.12
										-- (2016-02) -->  r= 226613.58 	c= 155274.97	p= 71338.61


-- ( total of orders )

select count(distinct order_id) as total_orders
from fact_sales;             
   
										-- total orders = 419


-- ( number of customers )

select count( customer_id) as number_customers
from dim_customers;

										-- number of customers = 411


--------------------------------------------------------------------------------------------------------------


					-- (( ANALYSIS )) --
                    
                    
-- ( top 5 customers in terms of spending )

select
  dc.name as customer_name,
  dc.customer_id,
 sum(fs.quantity * dp.unit_price) as total_spent
from fact_sales fs
join dim_customers dc on fs.customer_id = dc.customer_id
join dim_products dp on fs.product_id = dp.product_id
group by dc.name, dc.customer_id
order by total_spent desc
limit 5;

										-- 1) Anita Hunt         -->  15180.33
										-- 2) Callisto Lo Duca   -->  12121.06
										-- 3) Dee Pickens        -->  9890.40
										-- 4) Katie Albright     -->  8990.00
										-- 5) Mae Lemons         -->  8924.40


-- ( top 5 earning products )

select
  dp.product_name,
  dp.Category,
  sum(fs.quantity * dp.unit_Price) as revenue
from fact_sales fs
join dim_products dp on fs.Product_id = dp.Product_id
group by dp.product_name,dp.Category
order by Revenue desc
limit 5;

										-- 1) Litware Refrigerator 19CuFt M760 Brown		 Home Appliances          -->	 8990.00
										-- 2) Fabrikam Trendsetter 1/3" 8.5mm X200 Blue"	 Cameras and camcorders   -->	 8982.00
										-- 3) Adventure Works Laptop15 M1501 Silver	    	 Computers  			  -->	 8388.00
										-- 4) SV Car Video LCD9.2W X9280 Black	        	 TV and Video 			  -->	 7992.00
										-- 5) WWI Desktop PC2.30 M2300 Black	        	 Computers   			  -->	 7267.00


-- ( top 5 earning stores )

select
  ds.store_id,
  ds.country,
  sum(fs.quantity * dp.unit_Price) as total_revenue
from fact_sales fs
join dim_stores ds on fs.store_id = ds.store_id
join dim_products dp on fs.product_id = dp.product_id
group by ds.store_id, ds.country
order by total_revenue desc
limit 5;

										-- 1) 29	Italy	        -->	39345.81
										-- 2) 61	United States   -->	35578.93
										-- 3) 64	United States	-->	27558.23
										-- 4) 50	United States	-->	26451.69
										-- 5) 8  	Canada	        -->	24796.28


-- ( top 3 earning country )

select
  ds.country,
  count(ds.store_id),
  sum(fs.quantity * dp.unit_Price) as total_revenue
from fact_sales fs
join dim_stores ds on fs.store_id = ds.store_id
join dim_products dp on fs.product_id = dp.product_id
group by ds.country
order by total_revenue desc
limit 3;

										-- 1) United States    358 stores    --> 282642.23
										-- 2) United Kingdom   136 stores    --> 77497.69
										-- 3) Italy	71675.38   74 stores     --> 71675.38
                                        
                                        
                                        
-- ( monthly growth rate from january to february )

with monthly as (
  select
    date_format(order_date, '%Y-%m') as month,
    sum(fs.quantity * dp.unit_Price) as revenue
  from fact_sales fs
  join dim_products dp on fs.product_id = dp.product_id
  group by month
)
select
  month,
  revenue,
  round((revenue - lag(revenue) over (order by month)) / lag(revenue) over (order by month) * 100, 2) AS growth_percent
from monthly;

										-- monthly growth rate = -48.98 %



-- ( Top selling product in each category )  
                             
select
    dp.category,
    dp.product_name,
    sum(fs.quantity) as units_sold
from fact_sales fs
join dim_products dp on fs.product_id = dp.product_id
group by dp.category, dp.product_name
having sum(fs.quantity) = (
    select max(sub_q.total_qty)
    from (
        select
            dp2.category,
            dp2.product_name,
            sum(fs2.quantity) as total_qty
        from fact_sales fs2
        join dim_products dp2 on fs2.product_id = dp2.product_id
        where dp2.category = dp.category
        group by dp2.category, dp2.product_name
    ) as sub_q
);

										-- * Cameras and camcorders :      Contoso General Carrying Case E304 Silver           			    -->	 15
										-- * Cell phones :				   The Phone Company Touch Screen Phones Infrared M901 Grey    	    -->	 13
										-- * Games and Toys :			   MGS Hand Games for kids E300 Black								-->	 16
										-- * Audio :					   NT Wireless Transmitter and Bluetooth Headphones M150 Silver     -->	 18
										-- * ...

										-- ( i know it's better to do this using CTEs but i wanted to use subqueries in the project :) )


--------------------------------------------------------------------------------------------------------------








					-- (( INSIGHTS )) --


-- # the gross profit margin represents approximately 40.5% of revenue, indicating a relatively good profit performance.

-- # there was a sharp decrease in revenue of 48.98% from January to February, which may indicate a seasonal decline or weak sales after a peak period.

-- # the number of orders (419) and the number of customers (411) indicate that most customers placed only one order, which means that the customer retention rate is relatively low.

-- # although the United Kingdom is second in revenue, Italy has almost the same revenue with fewer stores, which indicates the need to open new stores in Italy.

-- # computers and cameras represent the largest source of profits, while Music, Movies and Audio Books are the least profitable source; perhaps some promotions could increase their sales.

-- # customer Anita Hunt's revenue accounts for 2.26% of total revenue, making her a high-value customer.























