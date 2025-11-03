-- Q1 Calculate the total hours worked by each employee per week
SELECT r.staff_id,
	s.first_name,
	DATE_TRUNC('week', r.date) AS week,
	SUM(EXTRACT(HOUR FROM sh.end_time) - EXTRACT(HOUR FROM sh.start_time)) AS hours_worked
FROM rota r
JOIN staff s on r.staff_id = s.staff_id
JOIN shift sh on r.shift_id = sh.shift_id
GROUP BY first_name, r.staff_id, week


-- Q2 Rank employees based on hours worked
SELECT *, RANK() OVER(ORDER BY hours_worked DESC) FROM (SELECT r.staff_id,
	s.first_name,
	DATE_TRUNC('week', r.date) AS week,
	SUM(EXTRACT(HOUR FROM sh.end_time) - EXTRACT(HOUR FROM sh.start_time)) AS hours_worked
FROM rota r
JOIN staff s on r.staff_id = s.staff_id
JOIN shift sh on r.shift_id = sh.shift_id
GROUP BY first_name, r.staff_id, week) x

-- Q3 Suggest an optimized shift allocation to balance the workload
with weekly_hours_worked as (
	SELECT r.staff_id,
		s.first_name,
		DATE_TRUNC('week', r.date) AS week,
		SUM(EXTRACT(HOUR FROM sh.end_time) - EXTRACT(HOUR FROM sh.start_time)) AS hours_worked
	FROM rota r
	JOIN staff s on r.staff_id = s.staff_id
	JOIN shift sh on r.shift_id = sh.shift_id
	GROUP BY first_name, r.staff_id, week),
overworked as (
	SELECT * FROM weekly_hours_worked WHERE hours_worked >= 25
),
underworked as (
	SELECT * FROM weekly_hours_worked WHERE hours_worked < 25
)
SELECT  o.staff_id As Overworked_empID, o.first_name as Overwokred_empName,
		o.hours_worked - 24 AS hours_overworked,
		'Suggested employee to add hours to reduce work load as suggestion' AS Suggestion,
		u.staff_id as underworked_empID, u.first_name as underworked_empName,
		25 - u.hours_worked  AS hours_underworked
FROM overworked o
CROSS JOIN underworked u

-- Q4 Detect employees overlapping shifts
SELECT x.*, shift.start_time, shift.end_time FROM (
SELECT s1.shift_id, s1.date, s1.staff_id As employee, s2.staff_id  As employee2, LEAD(s1.staff_id) OVER() AS nextt FROM rota s1
JOIN rota s2 ON s1.date = s2.date AND s1.shift_id = s2.shift_id AND s1.staff_id <> s2.staff_id
) x
JOIN shift ON shift.shift_id = x.shift_id
WHERE nextt <> employee2 OR nextt IS NULL

--Q5 Identify the busiest hour based on sales
SELECT day_hour AS busiest_hour, SUM(quantity * item_price) AS total_sales 
FROM (SELECT o.*, mi.item_price, EXTRACT(HOUR FROM created_at::timestamp) AS day_hour 
	FROM orders o
	JOIN menu_items mi ON o.item_id = mi.item_id) x
GROUP BY day_hour
ORDER BY SUM(quantity * item_price) DESC


-- Q6 Create a view summarizing total revenue per month, orders and avg order value
CREATE VIEW monthly_data AS (SELECT month_num, SUM(item_price * quantity) Revenue_per_month,
COUNT(*) AS total_orders,
ROUND(AVG(item_price * quantity),2) AS AOV
FROM (SELECT o.*, mi.item_price, EXTRACT(MONTH FROM created_at::DATE) AS month_num FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id)x
GROUP BY month_num)

-- Q7 show the different categories on the basis of profit
SELECT mi.item_cat AS profitable_products,
	COUNT(*) AS quantity_sold,
	SUM(o.quantity * mi.item_price) AS total_sales
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY mi.item_cat
ORDER  BY COUNT(*) desc

-- Q8 Suggest whether to keep or reduct the price of each item based on sales
SELECT mi.item_name,
	mi.item_id, 
	COUNT(*) AS quantity_sold,
	SUM(o.quantity * mi.item_price) AS total_revenue,
	CASE 
	WHEN COUNT(*) <= 15 THEN 'Discount'
	ELSE 'Keep' END AS Recommendation,
	CASE WHEN COUNT(*) <= 15 THEN 'Low Sales'
	ELSE 'High sales' END AS Reason
FROM orders o
JOIN menu_items mi ON o.item_id = mi.item_id
GROUP BY mi.item_name, mi.item_id
ORDER BY Reason

-- Q9 Find which items are frequently ordered together
SELECT * FROM
(SELECT mi1.item_name || '->' ||  mi2.item_name AS item_chain, '2' AS chain_length, COUNT(*) AS frequency
FROM orders o1
JOIN orders o2 ON o1.order_id = o2.order_id AND o1.item_id < o2.item_id
JOIN menu_items mi1 on mi1.item_id = o1.item_id
JOIN menu_items mi2 ON mi2.item_id = o2.item_id 
GROUP BY item_chain

UNION ALL

SELECT mi1.item_name || '->' ||  mi2.item_name || '->' || mi3.item_name AS item_chain, '3' AS chain_length, COUNT(*) AS frequency
FROM orders o1
JOIN orders o2 ON o1.order_id = o2.order_id AND o1.item_id < o2.item_id
JOIN orders o3 ON o3.order_id = o1.order_id AND o2.item_id < o3.item_id
JOIN menu_items mi1 on mi1.item_id = o1.item_id
JOIN menu_items mi2 ON mi2.item_id = o2.item_id 
JOIN menu_items mi3 ON mi3.item_id = o3.item_id 
GROUP BY item_chain)
ORDER BY chain_length DESC, frequency DESC 

-- Q10 Which menu item is the most popular by time of day (morning, afternoon, evening)?
with classified AS (SELECT *,
	   CASE WHEN day_hour < 12 THEN 'Morning'
	   WHEN day_hour <= 16 THEN 'Afternoon'
	   ELSE 'Evening' END AS day_time
FROM 
	(SELECT *, EXTRACT(HOUR FROM created_at::TIMESTAMP) AS day_hour FROM orders) x),
ranked AS (
SELECT day_time, item_id, COUNT(*) AS total_orders, ROW_NUMBER() OVER(PARTITION BY day_time ORDER BY COUNT(*) DESC) AS top
FROM classified 
GROUP BY day_time, item_id
ORDER BY 1 DESC, COUNT(*) DESC
)
SELECT day_time, mi.item_name, total_orders, ROW_NUMBER() OVER(PARTITION BY day_time ORDER BY total_orders DESC) FROM ranked r		 
JOIN menu_items mi ON r.item_id = mi.item_id
WHERE top <= 3
ORDER BY day_time DESC


SELECT * FROM orders WHERE EXTRACT(HOUR FROM created_at::TIMESTAMP) >= 17




SELECT * FROM orders
