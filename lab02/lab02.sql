-- ФИО: Мнацаканян Артем Андреевич
-- Группа: ИНБО-20-23
-- Вариант: 5 (штат X = GO, штат Y = DF)
--
-- lab02: множества и мультимножества в SQL.
-- A = product_id товаров, купленных клиентами штата GO (заказы delivered)
-- B = product_id товаров, купленных клиентами штата DF (заказы delivered)
-- Выполняется сверху вниз без ручного редактирования отдельных строк.

-- 1a. Множество A: мощность и число различных product_id
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO'
      AND o.order_status = 'delivered'
)
SELECT count(*) AS total_rows, count(DISTINCT product_id) AS distinct_products
FROM a;

-- 1b. Множество B: мощность и число различных product_id
WITH b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF'
      AND o.order_status = 'delivered'
)
SELECT count(*) AS total_rows, count(DISTINCT product_id) AS distinct_products
FROM b;

-- 2a. A ∪ B через UNION (дубликаты между A и B и внутри них удаляются)
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT count(*) AS union_rows FROM (
    SELECT product_id FROM a
    UNION
    SELECT product_id FROM b
) u;

-- 2b. A ∪ B через UNION ALL (дубликаты сохраняются)
-- Разница union_rows (2a) и union_all_rows (2b) равна количеству "лишних"
-- повторов: как повторов product_id внутри A и B по отдельности
-- (несколько позиций заказа с одним товаром), так и пересечения A∩B,
-- которое при UNION ALL считается дважды.
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT count(*) AS union_all_rows FROM (
    SELECT product_id FROM a
    UNION ALL
    SELECT product_id FROM b
) u;

-- 3. A ∩ B через INTERSECT (товары, купленные в обоих штатах)
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT count(*) as a_intersect_b FROM(
	SELECT product_id FROM a
	INTERSECT
	SELECT product_id FROM b
	ORDER BY product_id
);

-- 4a. A − B через EXCEPT (товары только штата GO)
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT count(*) AS a_minus_b FROM (
    SELECT product_id FROM a
    EXCEPT
    SELECT product_id FROM b
) d;

-- 4b. B − A через EXCEPT (товары только штата DF)
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT count(*) AS b_minus_a FROM (
    SELECT product_id FROM b
    EXCEPT
    SELECT product_id FROM a
) d;

-- 5. Коммутативность объединения и пересечения: симметрическая разность
-- (A∪B) с (B∪A) и (A∩B) с (B∩A) должна быть пустой — 0 строк в обоих
-- случаях подтверждает коммутативность на данных.
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT
    (SELECT count(*) FROM (
        (SELECT product_id FROM a UNION SELECT product_id FROM b)
        EXCEPT
        (SELECT product_id FROM b UNION SELECT product_id FROM a)
    ) x) AS union_diff,
    (SELECT count(*) FROM (
        (SELECT product_id FROM a INTERSECT SELECT product_id FROM b)
        EXCEPT
        (SELECT product_id FROM b INTERSECT SELECT product_id FROM a)
    ) y) AS intersect_diff;

-- 6. Некоммутативность разности: A−B и B−A имеют разную мощность
-- (см. пункты 4a и 4b) и разный состав — симметрическая разность
-- между (A−B) и (B−A) не пуста, если множества сами не равны.
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT
    (SELECT count(*) FROM (SELECT product_id FROM a EXCEPT SELECT product_id FROM b) t1) AS a_minus_b,
    (SELECT count(*) FROM (SELECT product_id FROM b EXCEPT SELECT product_id FROM a) t2) AS b_minus_a,
    (SELECT count(*) FROM (SELECT product_id FROM a EXCEPT SELECT product_id FROM b) t1) <>
    (SELECT count(*) FROM (SELECT product_id FROM b EXCEPT SELECT product_id FROM a) t2) AS is_noncommutative;

-- 7. Пересечение A ∩ B без INTERSECT, через EXISTS
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT DISTINCT a.product_id
FROM a
WHERE EXISTS (SELECT 1 FROM b WHERE b.product_id = a.product_id)
ORDER BY a.product_id;

-- 8. Тот же запрос без DISTINCT: продукт, купленный в GO несколько раз,
-- размножает строку результата, хотя множество product_id одно и то же —
-- наглядная демонстрация мультимножественной природы SQL-таблиц.
WITH a AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'GO' AND o.order_status = 'delivered'
), b AS (
    SELECT oi.product_id
    FROM olist.order_items oi
    JOIN olist.orders o ON o.order_id = oi.order_id
    JOIN olist.customers c ON c.customer_id = o.customer_id
    WHERE c.customer_state = 'DF' AND o.order_status = 'delivered'
)
SELECT
    (SELECT count(*) FROM a WHERE EXISTS (SELECT 1 FROM b WHERE b.product_id = a.product_id)) AS rows_without_distinct,
    (SELECT count(DISTINCT a.product_id) FROM a WHERE EXISTS (SELECT 1 FROM b WHERE b.product_id = a.product_id)) AS rows_with_distinct;

-- 9. Множество или мультимножество:
--   UNION, INTERSECT, EXCEPT (без ALL)       -> результат-множество (без повторов).
--   UNION ALL, INTERSECT ALL, EXCEPT ALL,
--   обычный SELECT без DISTINCT              -> результат-мультимножество (повторы возможны).
