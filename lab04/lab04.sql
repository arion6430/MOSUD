-- ФИО: Мнацаканян Артем Андреевич
-- Группа: ИНБО-20-23
-- Вариант: 5 (Оплаты и категории)
--
-- lab04: соединения отношений и сложные JOIN.
-- Маршрут: orders -> order_payments (агрегированы), orders -> order_items
-- + products + product_category_name_translation (агрегированы до одной
-- строки на заказ, чтобы избежать размножения строк).
--
-- Выполняется сверху вниз без ручного редактирования отдельных строк.

-- =====================================================================
-- 1. Основной запрос: для каждого доставленного заказа — сумма оплат,
--    способы оплаты и «основная» категория товара (категория позиции
--    с наибольшей ценой в заказе).
-- =====================================================================
WITH items_agg AS (
    -- Предварительная агрегация: одна строка на заказ (иначе JOIN с
    -- order_payments размножит строки, см. пункт 5).
    SELECT oi.order_id,
           sum(oi.price) AS items_total,
           count(*) AS items_count,
           count(DISTINCT p.product_category_name) AS category_count
    FROM olist.order_items oi
    JOIN olist.products p ON p.product_id = oi.product_id
    GROUP BY oi.order_id
),
main_category AS (
    -- Категория самой дорогой позиции заказа: DISTINCT ON гарантирует
    -- одну строку на order_id.
    SELECT DISTINCT ON (oi.order_id)
           oi.order_id,
           COALESCE(t.product_category_name_english, p.product_category_name) AS main_category
    FROM olist.order_items oi
    JOIN olist.products p ON p.product_id = oi.product_id
    LEFT JOIN olist.product_category_name_translation t
           ON t.product_category_name = p.product_category_name
    ORDER BY oi.order_id, oi.price DESC
),
payments_agg AS (
    -- Предварительная агрегация оплат: одна строка на заказ.
    SELECT order_id,
           sum(payment_value) AS payments_total,
           count(*) AS payments_count,
           string_agg(DISTINCT payment_type, ', ' ORDER BY payment_type) AS payment_types
    FROM olist.order_payments
    GROUP BY order_id
)
SELECT o.order_id,
       o.order_status,
       mc.main_category,
       ia.items_total,
       ia.items_count,
       ia.category_count,
       pa.payments_total,
       pa.payments_count,
       pa.payment_types
FROM olist.orders o
JOIN items_agg ia ON ia.order_id = o.order_id                 -- 1:1 после агрегации (было 1:N)
JOIN main_category mc ON mc.order_id = o.order_id             -- 1:1 (одна строка на заказ по построению)
LEFT JOIN payments_agg pa ON pa.order_id = o.order_id         -- 1:1 после агрегации, LEFT — см. пункт 3
WHERE o.order_status = 'delivered'
ORDER BY o.order_id;

-- =====================================================================
-- 2. Кратность связей основного запроса (до предварительной агрегации):
--   orders -> order_items          : 1:N  (один заказ — несколько позиций)
--   order_items -> products        : N:1  (товар встречается во многих позициях)
--   products -> category_translation: N:1 (много товаров — одна категория)
--   orders -> order_payments       : 1:N  (один заказ — несколько платежей,
--                                          например рассрочка или оплата
--                                          несколькими способами)
-- После агрегации в items_agg/main_category/payments_agg каждая связь с
-- orders становится 1:1, что и позволяет соединить их без размножения.
-- =====================================================================

-- =====================================================================
-- 3. LEFT JOIN уже встроен в основной запрос (payments_agg): не у всех
-- заказов есть строка оплаты, и LEFT JOIN сохраняет такой заказ с NULL
-- в полях payments_total/payments_count/payment_types вместо того,
-- чтобы исключить его из результата (как сделал бы INNER JOIN).
-- Пример конкретного заказа без оплаты:
WITH items_agg AS (
    SELECT oi.order_id, sum(oi.price) AS items_total
    FROM olist.order_items oi
    GROUP BY oi.order_id
), payments_agg AS (
    SELECT order_id, sum(payment_value) AS payments_total
    FROM olist.order_payments
    GROUP BY order_id
)
SELECT o.order_id, o.order_status, ia.items_total, pa.payments_total
FROM olist.orders o
JOIN items_agg ia ON ia.order_id = o.order_id
LEFT JOIN payments_agg pa ON pa.order_id = o.order_id
WHERE pa.order_id IS NULL;

-- =====================================================================
-- 4. Антисоединение: заказы, для которых нет ни одной строки оплаты
-- (тот же результат, что и в пункте 3, но выражен через NOT EXISTS).
-- =====================================================================
SELECT o.order_id, o.order_status
FROM olist.orders o
WHERE NOT EXISTS (
    SELECT 1 FROM olist.order_payments op WHERE op.order_id = o.order_id
);

-- =====================================================================
-- 5. Ошибочный JOIN: прямое соединение orders -> order_items и
-- orders -> order_payments БЕЗ предварительной агрегации размножает
-- строки (декартово произведение позиций и платежей внутри заказа) и
-- завышает SUM(payment_value) пропорционально числу позиций заказа.
-- =====================================================================
SELECT o.order_id,
       count(*) AS joined_rows,               -- ожидалось бы 4 (число платежей), получили 24 = 6 позиций x 4 платежа
       sum(op.payment_value) AS wrong_sum_payment_value  -- 1333.80 вместо реальных 222.30 (завышено ровно в 6 раз)
FROM olist.orders o
JOIN olist.order_items oi ON oi.order_id = o.order_id
JOIN olist.order_payments op ON op.order_id = o.order_id
WHERE o.order_id = 'a3725dfe487d359b5be08cac48b64ec5'
GROUP BY o.order_id;

-- Для сравнения — реальные значения по отдельности:
SELECT 'items' AS source, count(*) AS rows, sum(price) AS total
FROM olist.order_items WHERE order_id = 'a3725dfe487d359b5be08cac48b64ec5'
UNION ALL
SELECT 'payments', count(*), sum(payment_value)
FROM olist.order_payments WHERE order_id = 'a3725dfe487d359b5be08cac48b64ec5';

-- =====================================================================
-- 6. Исправление: агрегировать order_payments (и отдельно order_items)
-- до одной строки на заказ ПЕРЕД соединением — тогда декартова
-- произведения не возникает и SUM возвращает верное значение.
-- =====================================================================
WITH items_fixed AS (
    SELECT order_id, count(*) AS items_count, sum(price) AS items_total
    FROM olist.order_items
    WHERE order_id = 'a3725dfe487d359b5be08cac48b64ec5'
    GROUP BY order_id
), payments_fixed AS (
    SELECT order_id, count(*) AS payments_count, sum(payment_value) AS payments_total
    FROM olist.order_payments
    WHERE order_id = 'a3725dfe487d359b5be08cac48b64ec5'
    GROUP BY order_id
)
SELECT o.order_id, i.items_count, i.items_total, p.payments_count, p.payments_total
FROM olist.orders o
JOIN items_fixed i ON i.order_id = o.order_id
JOIN payments_fixed p ON p.order_id = o.order_id;

-- =====================================================================
-- 7. Композиция операций реляционной алгебры для основного запроса
-- (после предварительной агрегации γ — группировки с агрегатными
-- функциями, что выходит за рамки чистой алгебры, но обозначается γ):
--
-- items_agg      = γ_{order_id; sum(price)->items_total, count(*)->items_count}
--                    (order_items ⋈_{product_id} products)
-- main_category  = π_{order_id, category} (
--                      order_items ⋈_{product_id} products
--                          ⟕_{product_category_name} category_name_translation
--                  )   -- с последующим выбором строки максимума price по order_id
-- payments_agg   = γ_{order_id; sum(payment_value)->payments_total}
--                    (order_payments)
--
-- результат = σ_{order_status='delivered'} (
--     orders ⋈_{order_id} items_agg ⋈_{order_id} main_category
--             ⟕_{order_id} payments_agg
-- )
-- где ⋈ — эквисоединение (INNER JOIN), ⟕ — левое внешнее соединение (LEFT JOIN).
-- =====================================================================
