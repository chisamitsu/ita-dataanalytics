-- =====================================================================
-- S04: BigQuery Avanzado y Analytics Engineering
-- Proyecto: sprint3-analytics-hisamitsu
-- Los pasos hechos por UI o Cloud Shell van documentados en comentario.
-- =====================================================================

-- =====================================================================
-- NIVEL 1: Entorno e ingesta hibrida (Code-First)
-- =====================================================================

-- --- Ejercicio 1: Diagnostico sobre tabla no optimizada -----------------
-- JOIN transactions_clean + companies_clean, filtrado por 12-03-2022 y
-- pais Germany. Solo Dry Run, no se ejecuta.
SELECT
    t.transaction_id,
    t.timestamp,
    t.amount,
    c.company_name,
    c.country
FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean` AS t
JOIN `sprint3-analytics-hisamitsu.sprint3_silver.companies_clean` AS c
    ON t.business_id = c.company_id
WHERE DATE(t.timestamp) = '2022-03-12'
    AND c.country = 'Germany';


-- --- Ejercicio 2: Partition & Cluster ------------------------------------
-- Paso 1: transactions_recent a partir de transactions_clean, con el
-- timestamp movido a los ultimos 50 dias para que no caduque la
-- particion del sandbox (60 dias).
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_silver.transactions_recent` AS
SELECT
    * EXCEPT(`timestamp`),
    TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL CAST(RAND() * 50 AS INT64) DAY) AS `timestamp`
FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean`;

-- Paso 2: fact_transactions_optimized a partir de transactions_recent,
-- particionada por DATE(timestamp) y clusterizada por business_id.
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_gold.fact_transactions_optimized`
PARTITION BY DATE(`timestamp`)
CLUSTER BY business_id AS
SELECT *
FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_recent`;


-- --- Ejercicio 3: Benchmark (Dry Run) ------------------------------------
-- Misma consulta (ultimos 30 dias, SELECT *) contra transactions_recent y
-- contra fact_transactions_optimized. Solo Dry Run, no ejecutar.

-- Paso 1: tabla no optimizada.
SELECT *
FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_recent`
WHERE DATE(`timestamp`) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);

-- Paso 2: tabla particionada y clusterizada.
SELECT *
FROM `sprint3-analytics-hisamitsu.sprint3_gold.fact_transactions_optimized`
WHERE DATE(`timestamp`) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);


-- --- Ejercicio 4: Smart Caching (Vista Materializada) --------------------
-- mv_daily_sales: ventas totales por dia, sobre fact_transactions_optimized.
-- Sin declined, como siempre.
CREATE MATERIALIZED VIEW `sprint3-analytics-hisamitsu.sprint3_gold.mv_daily_sales` AS
SELECT
    DATE(`timestamp`) AS sales_date,
    SUM(amount) AS total_sales
FROM `sprint3-analytics-hisamitsu.sprint3_gold.fact_transactions_optimized`
WHERE declined = '0'
GROUP BY sales_date;

-- Consulta de entrega.
SELECT *
FROM `sprint3-analytics-hisamitsu.sprint3_gold.mv_daily_sales`
ORDER BY sales_date;


-- =====================================================================
-- NIVEL 2: SQL Analitico Avanzado
-- =====================================================================

-- --- Ejercicio 1: Perfilado de clientes VIP (CTE) ------------------------
-- VIP_Stats agrupa por usuario: gasto total, numero de transacciones,
-- ticket medio (2 decimales), compra maxima. Filtro de 500 de gasto
-- acumulado, cruzado con users_combined, ordenado por gasto desc.
-- Fuente: transactions_clean, no fact_transactions_optimized (esa es del
-- benchmark de particionado del Nivel 1).
WITH VIP_Stats AS (
    SELECT
        user_id,
        SUM(amount) AS total_gastat,
        COUNT(*) AS num_compres,
        ROUND(AVG(amount), 2) AS tiquet_mig,
        MAX(amount) AS max_compra
    FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean`
    WHERE declined = '0'
    GROUP BY user_id
    HAVING total_gastat > 500
)
SELECT
    users.user_id,
    CONCAT(users.name, ' ', users.surname) AS nom_complet,
    users.email,
    VIP_Stats.num_compres,
    VIP_Stats.tiquet_mig,
    VIP_Stats.max_compra,
    VIP_Stats.total_gastat
FROM `sprint3-analytics-hisamitsu.sprint3_silver.users_combined` AS users
INNER JOIN VIP_Stats
    ON VIP_Stats.user_id = users.user_id
ORDER BY VIP_Stats.total_gastat DESC;

-- --- Ejercicio 2: Tendencias (Window Functions sobre mv_daily_sales) -----
-- LAG() para ventas de ayer, variacion % respecto al dia anterior
-- (2 decimales). Diff_Percentual = (hoy - ayer) / ayer.
SELECT
    sales_date AS Data,
    total_sales AS Vendes_Avui,
    LAG(total_sales) OVER (ORDER BY sales_date) AS Vendes_Ahir,
    ROUND(
        SAFE_DIVIDE(total_sales - LAG(total_sales) OVER (ORDER BY sales_date),
                    LAG(total_sales) OVER (ORDER BY sales_date)) * 100,
        2
    ) AS Diff_Percentual
FROM `sprint3-analytics-hisamitsu.sprint3_gold.mv_daily_sales`
ORDER BY Data;

-- --- Ejercicio 3: Totales acumulados YTD (sobre mv_daily_sales) ---------
-- SUM() OVER (PARTITION BY EXTRACT(YEAR FROM fecha) ORDER BY fecha
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2 decimales.
SELECT
    sales_date AS Data,
    ROUND(total_sales, 2) AS `Vendes del Dia`,
    ROUND(
        SUM(total_sales) OVER (
            PARTITION BY EXTRACT(YEAR FROM sales_date)
            ORDER BY sales_date ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS `Vendes Acumulades YTD`
FROM `sprint3-analytics-hisamitsu.sprint3_gold.mv_daily_sales`
ORDER BY sales_date;

-- --- Ejercicio 4: Fidelizacion (ROW_NUMBER + QUALIFY) --------------------
-- Usuarios que llegaron a su 3a compra, con fecha e importe de esa
-- compra y la media de las 3 primeras. QUALIFY filtra antes de agregar.
-- El HAVING COUNT(*) = 3 descarta a quien tiene menos de 3 compras.
WITH numbered_transactions AS (
    SELECT
        user_id,
        `timestamp`,
        amount,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY `timestamp`) AS row_num
    FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean`
    WHERE declined = '0'
    QUALIFY row_num <= 3
)
SELECT
    transactions.user_id,
    CONCAT(users.name, ' ', users.surname) AS nom_complet,
    users.email,
    MAX(IF(transactions.row_num = 3, transactions.timestamp, NULL)) AS data_3a_compra,
    MAX(IF(transactions.row_num = 3, transactions.amount, NULL)) AS import_3a_compra,
    ROUND(AVG(transactions.amount), 2) AS import_mitjana_3_compres
FROM numbered_transactions AS transactions
INNER JOIN `sprint3-analytics-hisamitsu.sprint3_silver.users_combined` AS users
    ON transactions.user_id = users.user_id
GROUP BY transactions.user_id, nom_complet, users.email
HAVING COUNT(*) = 3
ORDER BY transactions.user_id;


-- =====================================================================
-- NIVEL 3: Analytics Engineering (Arrays & Automatizacion)
-- =====================================================================

-- --- Ejercicio 1: dim_transactions_flat (Unnesting) ----------------------
-- CROSS JOIN UNNEST(product_ids) + JOIN con products_clean, una fila por
-- producto vendido. Sin declined. product_sku usa el valor de
-- product_id, no hay SKU real en los datos.
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_gold.dim_transactions_flat` AS
SELECT
    transactions.transaction_id,
    transactions.timestamp,
    transactions.amount AS total_ticket_global,
    products.product_id AS product_sku,
    products.name AS product_name,
    products.price AS product_price
FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean` AS transactions
CROSS JOIN UNNEST(transactions.product_ids) AS t_product_id
INNER JOIN `sprint3-analytics-hisamitsu.sprint3_silver.products_clean` AS products
    ON t_product_id = products.product_id
WHERE transactions.declined = '0'
ORDER BY transactions.transaction_id, products.product_id;

-- --- Ejercicio 2: Ranking de ventas ---------------------------------------
-- Top 5 productos mas vendidos sobre dim_transactions_flat, agrupado por
-- product_sku (no por nombre). RANK() + QUALIFY en vez de LIMIT 5.
WITH product_counts AS (
    SELECT
        product_sku,
        product_name,
        COUNT(*) AS units_sold
    FROM `sprint3-analytics-hisamitsu.sprint3_gold.dim_transactions_flat`
    GROUP BY product_sku, product_name
)
SELECT
    RANK() OVER (ORDER BY units_sold DESC) AS rank,
    product_sku,
    product_name,
    units_sold
FROM product_counts
QUALIFY rank <= 5
ORDER BY units_sold DESC;

-- --- Ejercicio 3: UDF + automatizacion ------------------------------------
-- a) Funcion persistente calculate_tax(amount), IVA al 21%.
CREATE OR REPLACE FUNCTION `sprint3-analytics-hisamitsu.sprint3_gold.calculate_tax`(amount NUMERIC)
RETURNS NUMERIC
AS (
    ROUND(amount * 1.21, 2)
);


-- b) dim_transactions_flat actualizada con product_price_tax_inc usando
-- calculate_tax. Mismo CTAS del Ejercicio 1, con la columna nueva.
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_gold.dim_transactions_flat` AS
SELECT
    transactions.transaction_id,
    transactions.timestamp,
    transactions.amount AS total_ticket_global,
    products.product_id AS product_sku,
    products.name AS product_name,
    products.price AS product_price,
    `sprint3-analytics-hisamitsu.sprint3_gold.calculate_tax`(products.price) AS product_price_tax_inc
FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean` AS transactions
CROSS JOIN UNNEST(transactions.product_ids) AS t_product_id
INNER JOIN `sprint3-analytics-hisamitsu.sprint3_silver.products_clean` AS products
    ON t_product_id = products.product_id
WHERE transactions.declined = '0'
ORDER BY transactions.transaction_id, products.product_id;

-- c) Scheduled Query sobre el CTAS de arriba, diaria a las 07:00. No se
-- pudo crear, "Billing is disabled for this project" (Sandbox sin
-- billing), igual por UI que por bq.

-- d) Dashboard en Looker Studio conectado a dim_transactions_flat.
-- Sin SQL adicional.
-- https://datastudio.google.com/reporting/f4f4d35b-57f0-4241-9577-624ce4d33bc7
