-- ФИО: Мнацаканян Артем Андреевич
-- Группа: ИНБО-20-23
-- Вариант: 5
--
-- lab03: выборка, проекция, переименование и реляционная алгебра.
-- Отношение: olist.order_payments
-- Предикат: payment_type = 'credit_card' AND payment_installments >= 6
-- Проекция: order_id, payment_installments, payment_value
--
-- Реляционная алгебра:
-- π_{order_id, payment_installments, payment_value} (
--     σ_{payment_type = 'credit_card' ∧ payment_installments ≥ 6} (order_payments)
-- )
--
-- Выполняется сверху вниз без ручного редактирования отдельных строк.

-- 3. SQL-реализация исходного выражения (σ, затем π)
SELECT order_id, payment_installments, payment_value
FROM olist.order_payments
WHERE payment_type = 'credit_card' AND payment_installments >= 6;

-- 4a. Тот же предикат, разбитый на две последовательные выборки:
-- σ_A(σ_B(R)) эквивалентно σ_{A∧B}(R) — выборка коммутативна и
-- допускает разбиение сложного предиката на цепочку фильтров.
WITH step1 AS (
    SELECT * FROM olist.order_payments WHERE payment_type = 'credit_card'
), step2 AS (
    SELECT * FROM step1 WHERE payment_installments >= 6
)
SELECT count(*) AS rows_two_step FROM step2;

-- 4b. Тот же результат с одним составным предикатом — для сравнения
-- количества строк с пунктом 4a (должно совпасть).
SELECT count(*) AS rows_combined_predicate
FROM olist.order_payments
WHERE payment_type = 'credit_card' AND payment_installments >= 6;

-- 5. Второй SQL-вариант: проекция выполняется раньше выборки, лишние
-- столбцы (payment_sequential) не протаскиваются через промежуточное
-- отношение narrowed.
SELECT order_id, payment_installments, payment_value
FROM (
    SELECT order_id, payment_type, payment_installments, payment_value
    FROM olist.order_payments
) narrowed
WHERE payment_type = 'credit_card' AND payment_installments >= 6;

-- 6. Проверка дубликатов в проекции: сравнение общего числа строк и
-- числа различных кортежей (order_id, payment_installments, payment_value).
SELECT count(*) AS total_rows,
       count(DISTINCT (order_id, payment_installments, payment_value)) AS distinct_rows
FROM olist.order_payments
WHERE payment_type = 'credit_card' AND payment_installments >= 6;

-- SELECT без DISTINCT — дубликаты кортежей сохраняются (мультимножество)
SELECT order_id, payment_installments, payment_value
FROM olist.order_payments
WHERE payment_type = 'credit_card' AND payment_installments >= 6;

-- SELECT DISTINCT — дубликаты устранены, результат ближе к
-- математической проекции (строк должно быть меньше, чем в запросе выше)
SELECT DISTINCT order_id, payment_installments, payment_value
FROM olist.order_payments
WHERE payment_type = 'credit_card' AND payment_installments >= 6;
