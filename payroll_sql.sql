CREATE DATABASE zenvy;
USE zenvy;
CREATE TABLE employees (
    employee_id     INT PRIMARY KEY,
    employee_name   VARCHAR(100) NOT NULL,
    department      VARCHAR(50),
    designation     VARCHAR(50),
    join_date       DATE,
    status          VARCHAR(20)
);
  select * from employees;
CREATE TABLE payroll (
    payroll_id      INT PRIMARY KEY,
    employee_id     INT,
    pay_period      DATE,
    basic_salary    DECIMAL(10,2),
    overtime_pay    DECIMAL(10,2),
    net_salary      DECIMAL(10,2),
    payment_date    DATE,
    
    FOREIGN KEY (employee_id) 
        REFERENCES employees(employee_id)
);
CREATE TABLE attendance (
    employee_id     INT,
    attendance_date DATE,
    hours_worked     varchar(10)
    
);
CREATE TABLE attendance_std (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT,
    attendance_date DATE,
    hours_worked INT NULL,
    
    FOREIGN KEY (employee_id)
        REFERENCES employees(employee_id)
);
INSERT INTO attendance_std (employee_id, attendance_date, hours_worked)
SELECT
    employee_id,
    attendance_date,
    CASE 
        WHEN hours_worked = 'NULL' OR TRIM(hours_worked) = ''
            THEN NULL
        ELSE CAST(hours_worked AS SIGNED)
    END
FROM attendance;



drop table attendance;

UPDATE attendance
SET hours_worked = '0'
WHERE hours_worked IS NULL
   OR TRIM(hours_worked) = '';
   set sql_safe_updates=0;
   UPDATE attendance
SET hours_worked =
  CASE
    WHEN CAST(hours_worked AS DECIMAL(5,2)) > 12 THEN '12'
    ELSE hours_worked
  END;
UPDATE attendance
SET hours_worked = CAST(CAST(hours_worked AS DECIMAL(5,2)) AS SIGNED);
ALTER TABLE attendance
MODIFY hours_worked INT;
select * from payroll;
# Total Active employees
select count(*) as Active_employees from employees where status="Active";
# total payroll cost
SELECT SUM(net_salary) AS total_payroll_cost FROM payroll;
#Average Salary
select avg(net_salary) as avg_salary from payroll;
# Payroll Cost by Department
select e.department,sum(p.net_salary) as payroll_cost  from employees as e left join payroll as p on e.employee_id=p.employee_id group by e.department;
# Average Salary per Department
select e.department,avg(p.net_salary) as avg_sal from employees as e left join payroll as p on e.employee_id=p.employee_id group by e.department;
# Total Overtime Cost
select sum(overtime_pay) as over_time_cost from payroll;
# Overtime % of Payroll
select concat(sum(overtime_pay)*100/sum(net_salary),"%") as overtime_per_pasyroll from payroll;
# Cost per Employee
select sum(net_salary)/count(distinct(employee_id)) as cost_per_employee from payroll;
#Highest Paid Employee
select employee_id,max(net_salary) as highest_paid from payroll group by employee_id order by highest_paid desc limit 1;
# Lowest Paid Employee
select employee_id,min(net_salary) as lowest_paid from payroll group by employee_id order by lowest_paid desc limit 1;
# Monthly Payroll Trend
select date_format(pay_period,"%y-%m" )as 'month',sum(net_salary) as pay_cost from payroll group by date_format(pay_period,"%y-%m" ) 
order by date_format(pay_period,"%y-%m" );
#Average Working Hours per Employee

select employee_id,round(avg(hours_worked),2) as avg_hrs from attendance where hours_worked is not null group by employee_id;
#Employees with Low Attendance
select employee_id, count(*) as working_days from attendance where hours_worked>0 group by employee_id having count(*)<10;
# Missing Attendance Rate
select round(sum(case when hours_worked is null then 1 else 0 end)*100/count(*),2) as missing_attendance_pct from attendance_std;
# Salary paid but no attendance records
SELECT 
    p.employee_id,
    SUM(p.net_salary) AS salary_paid,
    SUM(COALESCE(a.hours_worked,0)) AS total_hours
FROM payroll p
LEFT JOIN attendance a
  ON p.employee_id = a.employee_id
GROUP BY p.employee_id
HAVING SUM(COALESCE(a.hours_worked,0)) = 0;
# Overtime claimed but attendance is NULL
SELECT 
    p.employee_id,
    SUM(p.overtime_pay) AS overtime_paid,
    MAX(a.hours_worked) AS max_hours
FROM payroll p
LEFT JOIN attendance a
  ON p.employee_id = a.employee_id
GROUP BY p.employee_id
HAVING SUM(p.overtime_pay) > 0
   AND MAX(COALESCE(a.hours_worked,0)) <= 8;
   #Overtime claimed but insufficient working hours
SELECT p.employee_id,
       SUM(p.overtime_pay) AS overtime_paid,
       SUM(a.hours_worked) AS total_hours
FROM payroll p
JOIN attendance a ON p.employee_id = a.employee_id
GROUP BY p.employee_id
HAVING SUM(p.overtime_pay) > 0
   AND SUM(a.hours_worked) < 160;
   #Payroll without employee master data
SELECT DISTINCT p.employee_id
FROM payroll p
LEFT JOIN employees e 
  ON p.employee_id = e.employee_id
WHERE e.employee_id IS NULL;
#Duplicate Salary Credits
SELECT employee_id, pay_period, COUNT(*) AS payment_count
FROM payroll
GROUP BY employee_id, pay_period
HAVING COUNT(*) > 1;
#Active Employees with No Payroll
SELECT e.employee_id
FROM employees e
LEFT JOIN payroll p ON e.employee_id = p.employee_id
WHERE e.status = 'Active'
  AND p.employee_id IS NULL;
  #High Payroll, Low Productivity Departments
 WITH emp_hours AS (
    SELECT employee_id,
           SUM(COALESCE(hours_worked,0)) AS total_hours
    FROM attendance
    GROUP BY employee_id
),
emp_pay AS (
    SELECT employee_id,
           SUM(net_salary) AS total_salary
    FROM payroll
    GROUP BY employee_id
)
SELECT 
    e.department,
    SUM(ep.total_salary) AS payroll_cost,
    SUM(eh.total_hours) AS total_hours
FROM employees e
JOIN emp_pay ep ON e.employee_id = ep.employee_id
LEFT JOIN emp_hours eh ON e.employee_id = eh.employee_id
GROUP BY e.department
HAVING SUM(eh.total_hours) < 1000;

# Employees Paid More Than They Work
SELECT p.employee_id,
       SUM(p.net_salary) AS salary_paid,
       SUM(a.hours_worked) AS total_hours
FROM payroll p
LEFT JOIN attendance a ON p.employee_id = a.employee_id
GROUP BY p.employee_id
HAVING SUM(a.hours_worked) < 100;
# new employees:
SELECT COUNT(employee_id) AS new_employees
FROM employees
WHERE join_date >= (
    SELECT MAX(join_date) FROM employees
) - INTERVAL 30 DAY;