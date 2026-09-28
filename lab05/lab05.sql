-- ФИО: Мнацаканян Артем Андреевич
-- Группа: ИНБО-20-23
-- Вариант: 5 (S = {ES, RJ, MG})
--
-- lab05: кванторы, EXISTS и реляционное деление.
-- Задача: найти категории товаров (product_category_name), которые
-- встречались в доставленных заказах покупателей КАЖДОГО штата из S.
--
-- Выполняется сверху вниз без ручного редактирования отдельных строк.

-- =====================================================================
-- 1. CTE target_states из трёх значений варианта.
-- =====================================================================
-- (используется во всех последующих запросах в виде VALUES-списка)

-- Вспомогательное отношение-делимое: различающиеся пары (категория, штат),
-- в которых категория продавалась в доставленном заказе покупателя из
-- этого штата. NULL-категории исключены.
-- sold_pairs = π_{category, state} (
--     order_items ⋈ orders ⋈ customers ⋈ products
-- ), с σ_{order_status='delivered' ∧ category IS NOT NULL}

-- =====================================================================
-- 2. Категория продавалась во ВСЕХ штатах S — через двойной NOT EXISTS
-- («не существует штата из S, для которого не существует продажи
-- этой категории в этом штате»).
-- =====================================================================
WITH target_states(state) AS (
    VALUES ('ES'), ('RJ'), ('MG')
), sold_pairs AS (
    SELECT DISTINCT p.product_category_name AS category, c.customer_state AS state
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered' AND p.product_category_name IS NOT NULL
)
SELECT DISTINCT sp.category
FROM sold_pairs sp
WHERE NOT EXISTS (
    SELECT 1 FROM target_states ts
    WHERE NOT EXISTS (
        SELECT 1 FROM sold_pairs sp2
        WHERE sp2.category = sp.category AND sp2.state = ts.state
    )
)
ORDER BY 1;

-- =====================================================================
-- 3. То же самое через GROUP BY / HAVING COUNT(DISTINCT customer_state):
-- категория подходит, если среди её продаж в целевых штатах встретились
-- ровно все |S| различных штатов.
-- =====================================================================
WITH target_states(state) AS (
    VALUES ('ES'), ('RJ'), ('MG')
), sold_pairs AS (
    SELECT DISTINCT p.product_category_name AS category, c.customer_state AS state
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered' AND p.product_category_name IS NOT NULL
)
SELECT sp.category
FROM sold_pairs sp
WHERE sp.state IN (SELECT state FROM target_states)
GROUP BY sp.category
HAVING count(DISTINCT sp.state) = (SELECT count(*) FROM target_states)
ORDER BY 1;

-- =====================================================================
-- 4. То же самое через EXCEPT и NOT EXISTS: категория подходит, если
-- множество (target_states EXCEPT штаты, где категория продавалась)
-- пусто.
-- =====================================================================
WITH target_states(state) AS (
    VALUES ('ES'), ('RJ'), ('MG')
), sold_pairs AS (
    SELECT DISTINCT p.product_category_name AS category, c.customer_state AS state
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered' AND p.product_category_name IS NOT NULL
)
SELECT DISTINCT sp.category
FROM sold_pairs sp
WHERE NOT EXISTS (
    SELECT state FROM target_states
    EXCEPT
    SELECT state FROM sold_pairs sp2 WHERE sp2.category = sp.category
)
ORDER BY 1;

-- =====================================================================
-- 5. Проверка эквивалентности трёх реализаций: разность результатов
-- в обе стороны должна быть пустой для каждой пары запросов.
-- =====================================================================
WITH target_states(state) AS (
    VALUES ('ES'), ('RJ'), ('MG')
), sold_pairs AS (
    SELECT DISTINCT p.product_category_name AS category, c.customer_state AS state
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered' AND p.product_category_name IS NOT NULL
), result_double_not_exists AS (
    SELECT DISTINCT sp.category
    FROM sold_pairs sp
    WHERE NOT EXISTS (
        SELECT 1 FROM target_states ts
        WHERE NOT EXISTS (
            SELECT 1 FROM sold_pairs sp2
            WHERE sp2.category = sp.category AND sp2.state = ts.state
        )
    )
), result_group_having AS (
    SELECT sp.category
    FROM sold_pairs sp
    WHERE sp.state IN (SELECT state FROM target_states)
    GROUP BY sp.category
    HAVING count(DISTINCT sp.state) = (SELECT count(*) FROM target_states)
), result_except_not_exists AS (
    SELECT DISTINCT sp.category
    FROM sold_pairs sp
    WHERE NOT EXISTS (
        SELECT state FROM target_states
        EXCEPT
        SELECT state FROM sold_pairs sp2 WHERE sp2.category = sp.category
    )
)
SELECT
    (SELECT count(*) FROM (SELECT * FROM result_double_not_exists EXCEPT SELECT * FROM result_group_having) d1) AS diff_1_minus_2,
    (SELECT count(*) FROM (SELECT * FROM result_group_having EXCEPT SELECT * FROM result_double_not_exists) d2) AS diff_2_minus_1,
    (SELECT count(*) FROM (SELECT * FROM result_double_not_exists EXCEPT SELECT * FROM result_except_not_exists) d3) AS diff_1_minus_3,
    (SELECT count(*) FROM (SELECT * FROM result_except_not_exists EXCEPT SELECT * FROM result_double_not_exists) d4) AS diff_3_minus_1;
-- Все четыре разности должны быть равны 0 — три реализации эквивалентны.

-- =====================================================================
-- 6. Диагностическая таблица для одной найденной категории:
-- категория -> штат -> число заказов в этом штате.
-- =====================================================================
WITH target_states(state) AS (
    VALUES ('ES'), ('RJ'), ('MG')
)
SELECT p.product_category_name AS category,
       c.customer_state AS state,
       count(DISTINCT o.order_id) AS orders_count
FROM olist.order_items oi
JOIN olist.orders o ON o.order_id = oi.order_id
JOIN olist.customers c ON c.customer_id = o.customer_id
JOIN olist.products p ON p.product_id = oi.product_id
JOIN target_states ts ON ts.state = c.customer_state
WHERE o.order_status = 'delivered'
  AND p.product_category_name = 'beleza_saude'
GROUP BY p.product_category_name, c.customer_state
ORDER BY c.customer_state;

-- =====================================================================
-- 7. Поведение при пустом target_states: универсальное условие «для
-- всех x из S выполняется P(x)» истинно тривиально (vacuously true),
-- если S пусто — некого проверять, значит условие не нарушено ни для
-- одного x. Поэтому деление на пустое множество возвращает ВСЕ
-- категории из делимого (а не ни одной).
-- =====================================================================
WITH target_states(state) AS (
    SELECT NULL::text WHERE false   -- пустое множество делителя
), sold_pairs AS (
    SELECT DISTINCT p.product_category_name AS category, c.customer_state AS state
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    JOIN olist.products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered' AND p.product_category_name IS NOT NULL
)
SELECT count(*) AS categories_when_divisor_is_empty
FROM (
    SELECT DISTINCT sp.category
    FROM sold_pairs sp
    WHERE NOT EXISTS (
        SELECT 1 FROM target_states ts
        WHERE NOT EXISTS (
            SELECT 1 FROM sold_pairs sp2
            WHERE sp2.category = sp.category AND sp2.state = ts.state
        )
    )
) all_categories;
-- Результат равен общему числу различных категорий, встречавшихся в
-- доставленных заказах вообще (проверено: 73) — подтверждает
-- вырожденную истинность условия «для всех» на пустом множестве.

-- =====================================================================
-- 8. Дополнительно: продавцы, которые продавали товары покупателям
-- КАЖДОГО из трёх штатов S (то же деление, делимое — пары продавец/штат).
-- =====================================================================
WITH target_states(state) AS (
    VALUES ('ES'), ('RJ'), ('MG')
), seller_state_pairs AS (
    SELECT DISTINCT oi.seller_id, c.customer_state AS state
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
)
SELECT ssp.seller_id
FROM seller_state_pairs ssp
WHERE NOT EXISTS (
    SELECT 1 FROM target_states ts
    WHERE NOT EXISTS (
        SELECT 1 FROM seller_state_pairs ssp2
        WHERE ssp2.seller_id = ssp.seller_id AND ssp2.state = ts.state
    )
)
GROUP BY ssp.seller_id
ORDER BY 1;
