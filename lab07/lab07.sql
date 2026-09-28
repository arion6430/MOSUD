-- ФИО: Мнацаканян Артем Андреевич
-- Группа: ИНБО-20-23
-- Вариант: - (работа общая для всех студентов, варианты не используются)
--
-- lab07: NULL, трёхзначная логика и качество данных.
-- Выполняется сверху вниз без ручного редактирования отдельных строк.

-- =====================================================================
-- 1. Число NULL по всем потенциально необязательным столбцам
-- orders, products и order_reviews.
-- =====================================================================
SELECT 'orders.order_approved_at' AS column_name,
       count(*) FILTER (WHERE order_approved_at IS NULL) AS null_count
FROM olist.orders
UNION ALL
SELECT 'orders.order_delivered_carrier_date',
       count(*) FILTER (WHERE order_delivered_carrier_date IS NULL)
FROM olist.orders
UNION ALL
SELECT 'orders.order_delivered_customer_date',
       count(*) FILTER (WHERE order_delivered_customer_date IS NULL)
FROM olist.orders
UNION ALL
SELECT 'products.product_category_name',
       count(*) FILTER (WHERE product_category_name IS NULL)
FROM olist.products
UNION ALL
SELECT 'products.product_name_lenght',
       count(*) FILTER (WHERE product_name_lenght IS NULL)
FROM olist.products
UNION ALL
SELECT 'products.product_description_lenght',
       count(*) FILTER (WHERE product_description_lenght IS NULL)
FROM olist.products
UNION ALL
SELECT 'products.product_photos_qty',
       count(*) FILTER (WHERE product_photos_qty IS NULL)
FROM olist.products
UNION ALL
SELECT 'products.product_weight_g',
       count(*) FILTER (WHERE product_weight_g IS NULL)
FROM olist.products
UNION ALL
SELECT 'products.product_length_cm',
       count(*) FILTER (WHERE product_length_cm IS NULL)
FROM olist.products
UNION ALL
SELECT 'products.product_height_cm',
       count(*) FILTER (WHERE product_height_cm IS NULL)
FROM olist.products
UNION ALL
SELECT 'products.product_width_cm',
       count(*) FILTER (WHERE product_width_cm IS NULL)
FROM olist.products
UNION ALL
SELECT 'order_reviews.review_comment_title',
       count(*) FILTER (WHERE review_comment_title IS NULL)
FROM olist.order_reviews
UNION ALL
SELECT 'order_reviews.review_comment_message',
       count(*) FILTER (WHERE review_comment_message IS NULL)
FROM olist.order_reviews
UNION ALL
SELECT 'order_reviews.review_answer_timestamp',
       count(*) FILTER (WHERE review_answer_timestamp IS NULL)
FROM olist.order_reviews;

-- =====================================================================
-- 2. COUNT(*) считает все строки; COUNT(column) считает только строки,
-- где значение столбца НЕ NULL (NULL агрегатными функциями count(col)
-- игнорируется). Разница = число заказов без фактической даты
-- доставки покупателю.
-- =====================================================================
SELECT count(*) AS total_orders,
       count(order_delivered_customer_date) AS orders_with_delivery_date,
       count(*) - count(order_delivered_customer_date) AS difference_is_null_count
FROM olist.orders;

-- =====================================================================
-- 3. "= NULL" и "<> NULL" всегда дают UNKNOWN и поэтому не возвращают
-- ожидаемых строк (0 строк в обоих случаях, хотя нулевые значения
-- есть). Правильный способ — IS NULL / IS NOT NULL.
-- =====================================================================
SELECT count(*) AS wrong_eq_null FROM olist.orders WHERE order_approved_at = NULL;      -- 0 (ошибочно)
SELECT count(*) AS wrong_neq_null FROM olist.orders WHERE order_approved_at <> NULL;    -- 0 (ошибочно)
SELECT count(*) AS correct_is_null FROM olist.orders WHERE order_approved_at IS NULL;         -- верно: 160
SELECT count(*) AS correct_is_not_null FROM olist.orders WHERE order_approved_at IS NOT NULL; -- верно: 99281

-- =====================================================================
-- 4. IS DISTINCT FROM: в отличие от "=", ведёт себя как обычное
-- равенство, но не даёт UNKNOWN на NULL — NULL IS DISTINCT FROM NULL
-- равно FALSE (они "не различаются"), а сравнение значения с NULL
-- всегда TRUE (они "различаются").
-- =====================================================================
SELECT NULL = NULL                 AS eq_null_null,           -- NULL (UNKNOWN)
       NULL IS DISTINCT FROM NULL  AS is_distinct_null_null,   -- false
       5    IS DISTINCT FROM NULL  AS is_distinct_5_null,      -- true
       5    IS DISTINCT FROM 5     AS is_distinct_5_5;         -- false

-- На реальных данных: заказы, у которых дата передачи перевозчику и
-- дата доставки покупателю различаются (учитывая, что любая из них
-- может быть NULL).
SELECT count(*) AS differing_carrier_vs_customer_date
FROM olist.orders
WHERE order_delivered_carrier_date IS DISTINCT FROM order_delivered_customer_date;

-- =====================================================================
-- 5. temp_ids(id text): существующий order_id + NULL. NOT IN ломается
-- при NULL в списке (предикат становится UNKNOWN для КАЖДОЙ строки,
-- результат — 0 строк, хотя ожидались все заказы, кроме одного). NOT
-- EXISTS работает корректно независимо от NULL в проверяемом множестве.
-- =====================================================================
CREATE TEMP TABLE temp_ids(id text);
INSERT INTO temp_ids VALUES ('e481f51cbdc54678b7cc49136f2d6af7'), (NULL);

SELECT count(*) AS not_in_result           -- 0 (ошибочно из-за NULL в подзапросе)
FROM olist.orders o
WHERE o.order_id NOT IN (SELECT id FROM temp_ids);

SELECT count(*) AS not_exists_result       -- верно: 99440 (все заказы, кроме одного)
FROM olist.orders o
WHERE NOT EXISTS (SELECT 1 FROM temp_ids t WHERE t.id = o.order_id);

DROP TABLE temp_ids;

-- =====================================================================
-- 6. Фильтр в ON против фильтра в WHERE при LEFT JOIN.
-- =====================================================================
-- Фильтр в ON: условие проверяется ДО соединения, LEFT JOIN сохраняет
-- ВСЕ заказы (99 441) — для заказов без подходящего отзыва просто
-- получаем NULL в столбцах r.*.
SELECT count(DISTINCT o.order_id) AS orders_filter_in_on
FROM olist.orders o
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id AND r.review_score >= 4;

-- Фильтр в WHERE: условие проверяется ПОСЛЕ соединения и отбрасывает
-- строки, где r.review_score IS NULL (в том числе все "нехватившие"
-- строки внешнего соединения) — LEFT JOIN фактически превращается в
-- INNER JOIN, остаются только заказы с отзывом score >= 4 (76 120).
SELECT count(DISTINCT o.order_id) AS orders_filter_in_where
FROM olist.orders o
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE r.review_score >= 4;

-- =====================================================================
-- 7. COALESCE для текстового комментария и NULLIF для безопасного
-- деления (цена за грамм: защита от деления на NULL/0 в весе товара).
-- =====================================================================
SELECT order_id,
       COALESCE(review_comment_message, '(без комментария)') AS comment_display
FROM olist.order_reviews
ORDER BY order_id
LIMIT 5;

SELECT oi.product_id,
       p.product_weight_g,
       round(oi.price / NULLIF(p.product_weight_g, 0), 4) AS price_per_gram
FROM olist.order_items oi
JOIN olist.products p ON p.product_id = oi.product_id
WHERE p.product_weight_g IS NULL OR p.product_weight_g = 0
LIMIT 5;
-- Без NULLIF деление price/product_weight_g упало бы с ошибкой
-- "division by zero" для товаров с product_weight_g = 0; NULLIF
-- подменяет 0 на NULL, и результат деления корректно становится NULL.

-- =====================================================================
-- 8. Мини-профиль качества данных: доля строк с отсутствующим значением
-- по трём ключевым признакам.
-- =====================================================================
SELECT
    round(100.0 * count(*) FILTER (WHERE order_delivered_customer_date IS NULL) / count(*), 2) AS pct_orders_without_delivery_date
FROM olist.orders;

SELECT
    round(100.0 * count(*) FILTER (WHERE product_category_name IS NULL) / count(*), 2) AS pct_products_without_category
FROM olist.products;

SELECT
    round(100.0 * count(*) FILTER (WHERE review_comment_message IS NULL) / count(*), 2) AS pct_reviews_without_text
FROM olist.order_reviews;

-- =====================================================================
-- 9. Естественный NULL vs признак проблемы качества данных.
--
-- orders.order_delivered_customer_date — NULL здесь ЕСТЕСТВЕНЕН: для
-- заказа, который ещё не доставлен, отменён или потерян в пути, факт
-- доставки покупателю просто ещё не наступил, и колонка обязана быть
-- пустой (2.98% строк, см. пункт 8) — это отражает реальное состояние
-- бизнес-процесса, а не ошибку загрузки.
--
-- products.product_weight_g/length_cm/height_cm/width_cm — NULL здесь
-- СКОРЕЕ УКАЗЫВАЕТ НА ПРОБЛЕМУ КАЧЕСТВА: это физические характеристики
-- товара, обязательные для расчёта доставки любого реального товара в
-- каталоге; у него не может "ещё не наступить" вес. Встречаются они
-- всего в 2 товарах из ~33 тысяч (см. пункт 1) — похоже не на
-- закономерность, а на пропуск при заполнении карточки товара; более
-- того, у части товаров вес указан как 0 (см. пункт 7), что для
-- физического товара тоже нереалистично и говорит о том же дефекте
-- данных, просто замаскированном под "значение", а не под NULL.
-- =====================================================================
