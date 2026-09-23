-- ФИО: Мнацаканян Артем Андреевич
-- Группа: ИНБО-20-23
-- Вариант: - (работа общая для всех студентов, варианты не используются)
--
-- lab01: контроль количества строк, NULL в ключевых полях и ссылочной
-- целостности. Выполняется сверху вниз без ручного редактирования.

-- 1. Число строк во всех 9 таблицах схемы olist
SELECT 'customers' AS table_name, count(*) FROM olist.customers
UNION ALL SELECT 'geolocation', count(*) FROM olist.geolocation
UNION ALL SELECT 'orders', count(*) FROM olist.orders
UNION ALL SELECT 'order_items', count(*) FROM olist.order_items
UNION ALL SELECT 'order_payments', count(*) FROM olist.order_payments
UNION ALL SELECT 'order_reviews', count(*) FROM olist.order_reviews
UNION ALL SELECT 'products', count(*) FROM olist.products
UNION ALL SELECT 'sellers', count(*) FROM olist.sellers
UNION ALL SELECT 'product_category_name_translation', count(*)
    FROM olist.product_category_name_translation;

-- 2. Количество NULL в ключевых полях (первичные и внешние ключи)
SELECT 'customers.customer_id' AS field, count(*) AS null_count
    FROM olist.customers WHERE customer_id IS NULL
UNION ALL SELECT 'orders.order_id', count(*)
    FROM olist.orders WHERE order_id IS NULL
UNION ALL SELECT 'orders.customer_id', count(*)
    FROM olist.orders WHERE customer_id IS NULL
UNION ALL SELECT 'order_items.order_id', count(*)
    FROM olist.order_items WHERE order_id IS NULL
UNION ALL SELECT 'order_items.product_id', count(*)
    FROM olist.order_items WHERE product_id IS NULL
UNION ALL SELECT 'order_items.seller_id', count(*)
    FROM olist.order_items WHERE seller_id IS NULL
UNION ALL SELECT 'order_payments.order_id', count(*)
    FROM olist.order_payments WHERE order_id IS NULL
UNION ALL SELECT 'order_reviews.order_id', count(*)
    FROM olist.order_reviews WHERE order_id IS NULL
UNION ALL SELECT 'products.product_id', count(*)
    FROM olist.products WHERE product_id IS NULL
UNION ALL SELECT 'sellers.seller_id', count(*)
    FROM olist.sellers WHERE seller_id IS NULL;

-- 3. Проверка на "осиротевшие" ссылки (нарушение ссылочной целостности)
SELECT 'orphan_orders_customer' AS check_name, count(*) AS orphan_count
FROM olist.orders o
LEFT JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL

UNION ALL
SELECT 'orphan_items_order', count(*)
FROM olist.order_items oi
LEFT JOIN olist.orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT 'orphan_items_product', count(*)
FROM olist.order_items oi
LEFT JOIN olist.products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL

UNION ALL
SELECT 'orphan_items_seller', count(*)
FROM olist.order_items oi
LEFT JOIN olist.sellers s ON s.seller_id = oi.seller_id
WHERE s.seller_id IS NULL

UNION ALL
SELECT 'orphan_payments_order', count(*)
FROM olist.order_payments op
LEFT JOIN olist.orders o ON o.order_id = op.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT 'orphan_reviews_order', count(*)
FROM olist.order_reviews r
LEFT JOIN olist.orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;
