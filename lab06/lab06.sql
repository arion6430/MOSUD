-- ФИО: Мнацаканян Артем Андреевич
-- Группа: ИНБО-20-23
-- Вариант: 5
--
-- lab06: подзапросы и логика предикатов.
-- Задача: товары, число продаж которых (число строк order_items с этим
-- product_id) выше среднего числа продаж товара внутри ТОЙ ЖЕ категории
-- (product_category_name). NULL-категории исключены.
--
-- Выполняется сверху вниз без ручного редактирования отдельных строк.
-- Число продаж товара (агрегат по order_items) вычисляется один раз в
-- MATERIALIZED CTE и переиспользуется — без этого коррелированный
-- подзапрос пересчитывал бы JOIN+GROUP BY по всей таблице для каждого
-- из ~33 тыс. товаров.

-- =====================================================================
-- 1-2. Основное решение через подзапросы: скалярный подзапрос
-- (product_sales.sales_count уже посчитан), EXISTS (у товара есть
-- хотя бы одна продажа) и коррелированный скалярный подзапрос
-- (средняя продаваемость внутри категории товара).
-- =====================================================================
WITH sales_per_product AS MATERIALIZED (
    SELECT p.product_id, p.product_category_name, count(*) AS sales_count
    FROM olist.order_items oi
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY p.product_id, p.product_category_name
), category_avg AS MATERIALIZED (
    SELECT product_category_name, avg(sales_count) AS avg_sales
    FROM sales_per_product
    GROUP BY product_category_name
)
SELECT sp.product_id, sp.product_category_name, sp.sales_count
FROM sales_per_product sp
WHERE EXISTS (                                              -- у товара есть хотя бы одна продажа
        SELECT 1 FROM sales_per_product sp0 WHERE sp0.product_id = sp.product_id
      )
  AND sp.sales_count > (                                     -- коррелированный скалярный подзапрос
        SELECT ca.avg_sales FROM category_avg ca             -- средняя продаваемость категории товара
        WHERE ca.product_category_name = sp.product_category_name
      )
ORDER BY sp.product_id;

-- =====================================================================
-- 3. Альтернативная реализация через JOIN (без подзапросов в WHERE):
-- явное соединение товаров с предварительно вычисленной средней
-- продаваемостью категории.
-- =====================================================================
WITH sales_per_product AS (
    SELECT p.product_id, p.product_category_name, count(*) AS sales_count
    FROM olist.order_items oi
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY p.product_id, p.product_category_name
), category_avg AS (
    SELECT product_category_name, avg(sales_count) AS avg_sales
    FROM sales_per_product
    GROUP BY product_category_name
)
SELECT ps.product_id, ps.product_category_name, ps.sales_count
FROM sales_per_product ps
JOIN category_avg ca ON ca.product_category_name = ps.product_category_name
WHERE ps.sales_count > ca.avg_sales
ORDER BY ps.product_id;

-- =====================================================================
-- 4. Сравнение результатов пункта 1-2 и пункта 3 оператором EXCEPT
-- в обе стороны по множеству product_id — обе разности должны быть
-- пустыми (0 строк), что подтверждает эквивалентность решений.
-- =====================================================================
WITH sales_per_product AS MATERIALIZED (
    SELECT p.product_id, p.product_category_name, count(*) AS sales_count
    FROM olist.order_items oi
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY p.product_id, p.product_category_name
), category_avg AS MATERIALIZED (
    SELECT product_category_name, avg(sales_count) AS avg_sales
    FROM sales_per_product
    GROUP BY product_category_name
), main_result AS (
    SELECT sp.product_id
    FROM sales_per_product sp
    WHERE EXISTS (SELECT 1 FROM sales_per_product sp0 WHERE sp0.product_id = sp.product_id)
      AND sp.sales_count > (
            SELECT ca.avg_sales FROM category_avg ca
            WHERE ca.product_category_name = sp.product_category_name
          )
), alt_result AS (
    SELECT ps.product_id
    FROM sales_per_product ps
    JOIN category_avg ca ON ca.product_category_name = ps.product_category_name
    WHERE ps.sales_count > ca.avg_sales
)
SELECT
    (SELECT count(*) FROM (SELECT * FROM main_result EXCEPT SELECT * FROM alt_result) d1) AS main_minus_alt,
    (SELECT count(*) FROM (SELECT * FROM alt_result EXCEPT SELECT * FROM main_result) d2) AS alt_minus_main;

-- =====================================================================
-- 5. Демонстрация ANY и ALL (в финальном решении не понадобились,
-- поэтому вынесены в отдельные запросы на той же предметной области).
-- =====================================================================
-- ANY: товар продаётся лучше, чем ХОТЯ БЫ ОДИН другой товар той же
-- категории (то есть не является худшим по продажам в категории).
WITH sales_per_product AS MATERIALIZED (
    SELECT p.product_id, p.product_category_name, count(*) AS sales_count
    FROM olist.order_items oi
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY p.product_id, p.product_category_name
)
SELECT count(*) AS outsells_at_least_one_in_category
FROM sales_per_product sp
WHERE sp.sales_count > ANY (
    SELECT sp2.sales_count FROM sales_per_product sp2
    WHERE sp2.product_category_name = sp.product_category_name
      AND sp2.product_id <> sp.product_id
);

-- ALL: товар продаётся не хуже, чем ВСЕ товары своей категории —
-- то есть является лидером продаж (или одним из лидеров) в категории.
WITH sales_per_product AS MATERIALIZED (
    SELECT p.product_id, p.product_category_name, count(*) AS sales_count
    FROM olist.order_items oi
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY p.product_id, p.product_category_name
)
SELECT sp.product_id, sp.product_category_name, sp.sales_count
FROM sales_per_product sp
WHERE sp.sales_count >= ALL (
    SELECT sp2.sales_count FROM sales_per_product sp2
    WHERE sp2.product_category_name = sp.product_category_name
)
ORDER BY sp.product_category_name, sp.product_id;
