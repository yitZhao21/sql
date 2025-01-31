/* ASSIGNMENT 2 */
/* SECTION 2 */

-- COALESCE
/* 1. Our favourite manager wants a detailed long list of products, but is afraid of tables! 
We tell them, no problem! We can produce a list with all of the appropriate details. 

Using the following syntax you create our super cool and not at all needy manager a list:

SELECT 
product_name || ', ' || product_size|| ' (' || product_qty_type || ')'
FROM product

But wait! The product table has some bad data (a few NULL values). 
Find the NULLs and then using COALESCE, replace the NULL with a 
blank for the first problem, and 'unit' for the second problem. 

HINT: keep the syntax the same, but edited the correct components with the string. 
The `||` values concatenate the columns into strings. 
Edit the appropriate columns -- you're making two edits -- and the NULL rows will be fixed. 
All the other rows will remain the same.) */

SELECT 
product_name, product_size, product_qty_type
FROM product
WHERE NULLIF(product_size, '') IS NULL;

SELECT 
product_name || ', ' || IFNULL(product_size,' ')|| ' (' || IFNULL(product_qty_type,'Unit') || ')'
FROM product;

--Windowed Functions
/* 1. Write a query that selects from the customer_purchases table and numbers each customer’s  
visits to the farmer’s market (labeling each market date with a different number). 
Each customer’s first visit is labeled 1, second visit is labeled 2, etc. 

You can either display all rows in the customer_purchases table, with the counter changing on
each new market date for each customer, or select only the unique market dates per customer 
(without purchase details) and number those visits. 
HINT: One of these approaches uses ROW_NUMBER() and one uses DENSE_RANK(). */

SELECT DISTINCT *,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY market_date, transaction_time ASC) as num_visit
FROM customer_purchases;

/* 2. Reverse the numbering of the query from a part so each customer’s most recent visit is labeled 1, 
then write another query that uses this one as a subquery (or temp table) and filters the results to 
only the customer’s most recent visit. */

DROP TABLE IF EXISTS temp.customer_Visits; 
CREATE TEMP TABLE customer_Visits AS
SELECT DISTINCT *,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY market_date, transaction_time DESC) as num_visit
FROM customer_purchases;

SELECT * FROM customer_Visits WHERE num_visit=1;

/* 3. Using a COUNT() window function, include a value along with each row of the 
customer_purchases table that indicates how many different times that customer has purchased that product_id. */

SELECT DISTINCT customer_id, product_id, COUNT(product_id) OVER(PARTITION BY customer_id ORDER BY market_date DESC) as quantity 
FROM customer_purchases;

-- how many products per product_qty_type AND per their product_size

SELECT DISTINCT IFNULL(product_size, 'missing'), IFNULL(product_qty_type, 'missing'), COUNT(product_id) OVER(PARTITION BY product_size, product_qty_type ORDER BY product_name ASC) as product_quantity 
FROM product;


-- String manipulations
/* 1. Some product names in the product table have descriptions like "Jar" or "Organic". 
These are separated from the product name with a hyphen. 
Create a column using SUBSTR (and a couple of other commands) that captures these, but is otherwise NULL. 
Remove any trailing or leading whitespaces. Don't just use a case statement for each product! 

| product_name               | description |
|----------------------------|-------------|
| Habanero Peppers - Organic | Organic     |

Hint: you might need to use INSTR(product_name,'-') to find the hyphens. INSTR will help split the column. */

SELECT *,
SUBSTR(product_name,INSTR(product_name,'-')+2)
FROM product;

SELECT *, 
CASE WHEN SUBSTR(product_name,INSTR(product_name,'-')+2) = 'Organic' 
		THEN 'Organic'
	WHEN SUBSTR(product_name,INSTR(product_name,'-')+2) = 'Jar'
		THEN 'Jar'
	ELSE 'NULL'
	   END as description
FROM product;

/* 2. Filter the query to show any product_size value that contain a number with REGEXP. */
SELECT * FROM product
WHERE product_size REGEXP '\d';

-- UNION
/* 1. Using a UNION, write a query that displays the market dates with the highest and lowest total sales.

HINT: There are a possibly a few ways to do this query, but if you're struggling, try the following: 
1) Create a CTE/Temp Table to find sales values grouped by dates; 
2) Create another CTE/Temp table with a rank windowed function on the previous query to create 
"best day" and "worst day"; 
3) Query the second temp table twice, once for the best day, once for the worst day, 
with a UNION binding them. */

CREATE TEMP TABLE Daily_Sales AS
SELECT DISTINCT *,SUM(quantity*cost_to_customer_per_qty) OVER(PARTITION BY market_date) as DailySales
FROM customer_purchases;


CREATE TEMP TABLE DailySales_Max AS
SELECT *, 
FROM (
	SELECT DISTINCT
	*,
	DENSE_RANK() OVER(ORDER BY DailySales DESC) as Rank_Max
	FROM Daily_Sales
) x
WHERE x.Rank_Max = 1;


CREATE TEMP TABLE DailySales_Min AS
SELECT *
FROM (
	SELECT DISTINCT
	*,
	DENSE_RANK() OVER(ORDER BY DailySales ASC) as Rank_Min
	FROM Daily_Sales
) x
WHERE x.Rank_Min = 1;
	
	
SELECT market_date, DailySales
FROM DailySales_Max

UNION

SELECT market_date, DailySales
FROM DailySales_Min;
	
	
	
/* SECTION 3 */

-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */

SELECT * FROM product;
SELECT * FROM v;

-- grab original price of each product
DROP TABLE IF EXISTS temp.vendor_product;
CREATE TEMP TABLE vendor_product AS
SELECT * FROM vendor_inventory as v
INNER JOIN product as p
ON v. product_id = p.product_id;

-- grab names of each vendor
DROP TABLE IF EXISTS temp.vendor_product_name;
CREATE TEMP TABLE vendor_product_name AS
SELECT * FROM vendor_product as vp
INNER JOIN vendor as v
ON vp.vendor_id = v.vendor_id;

--grab only relevant info
DROP TABLE IF EXISTS temp.vendor_product_needed;
CREATE TEMP TABLE vendor_product_needed AS
SELECT DISTINCT vendor_name, product_name, original_price FROM vendor_product_name;

--grab customer names only
DROP TABLE IF EXISTS temp.customerUnique;
CREATE TEMP TABLE customerUnique AS
SELECT customer_first_name || ' ' || customer_last_name as customer_name FROM customer;

-- Got the final combo before computing prices*quantity
DROP TABLE IF EXISTS temp.final;
CREATE TEMP TABLE final AS
SELECT * FROM vendor_product_needed
CROSS JOIN customerUnique;

-- Compute and group by vendor

SELECT * SUM(5*original_price) as sales_per_product 
FROM final
GROUP BY cp.customer_id, customer_last_name, customer_first_name
HAVING price >= 2000;

--- RESULTS SEE HERE:
SELECT DISTINCT *, SUM(5*original_price) OVER(PARTITION BY vendor_name ORDER BY product_name) as vendor_sales 
FROM final;


-- INSERT
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */

DROP TABLE IF EXISTS temp.unit_product;
CREATE TEMP TABLE IF NOT EXISTS temp.unit_product AS
SELECT *, CURRENT_TIMESTAMP as snapshot_timestamp FROM products WHERE product_qty_type = 'unit';


/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */

INSERT INTO unit_product
VALUES(6, 'Red Pepper Jam', '8 oz', 12, 'unit', CURRENT_TIMESTAMP);
SELECT * FROM unit_product;

-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/

DELETE FROM unit_product -- finally, run with this
WHERE product_id=6;
SELECT * FROM unit_product;


-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax.

ALTER TABLE product_units
ADD current_quantity INT;

Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard. 
First, determine how to get the "last" quantity per product. 
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.) 
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column. 
Finally, make sure you have a WHERE statement to update the right row, 
	you'll need to use product_units.product_id to refer to the correct row within the product_units table. 
When you have all of these components, you can run the update statement. */


ALTER TABLE unit_product
ADD current_quantity INT;

DROP TABLE IF EXISTS all_last_quantity;
CREATE TEMP TABLE all_last_quantity AS
SELECT DISTINCT *,SUM(quantity) OVER(PARTITION BY product_id) as last_quantity
FROM vendor_inventory;

DROP TABLE IF EXISTS uniqe_last_quantity;
CREATE TEMP TABLE uniqe_last_quantity AS
SELECT DISTINCT product_id, last_quantity FROM all_last_quantity;

--coalesce
DROP TABLE IF EXISTS uniqe_last_quantity_new;
CREATE TEMP TABLE uniqe_last_quantity_new AS
SELECT product_id, product_name, product_size, product_category_id, product_qty_type, snapshot_timestamp, coalesce(current_quantity,0) as current_quantity FROM unit_product;

-- add last quantity
DROP TABLE IF EXISTS final_update;
CREATE TEMP TABLE final_update AS
SELECT * FROM uniqe_last_quantity_new as up_new
INNER JOIN uniqe_last_quantity as alq ON up_new.product_id = alq.product_id;

--change the product_size for almonds from 1lb to 1/2kg
SELECT * FROM final_update;
UPDATE final_update
SET current_quantity = last_quantity;

-- updated table where current quantity is the same as last quantity
SELECT * FROM final_update;
