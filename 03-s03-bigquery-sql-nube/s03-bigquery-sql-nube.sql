-- =====================================================================
-- S03: Introducción a BigQuery y SQL en la nube
-- Proyecto: sprint3-analytics-hisamitsu
-- Los pasos hechos por UI o Cloud Shell van documentados en comentario.
-- =====================================================================

-- =====================================================================
-- NIVEL 1: Entorno e ingesta híbrida (Code-First)
-- =====================================================================

-- --- Ejercicio 1 --------------------------------------------------------
-- Tres datasets (Medallion), cada uno con un método distinto:
--   sprint3_bronze -> UI
--   sprint3_silver -> CREATE SCHEMA (abajo)
--   sprint3_gold   -> bq / Cloud Shell (abajo, en comentario)
-- Misma región (EU) en los tres, para no pagar transferencia entre ellos.

-- sprint3_bronze: UI (Add data -> Create dataset), región EU. El label no
-- se puede poner desde el diálogo de creación; se añade después editando
-- el dataset, con la descripción "Raw data as ingested from the Data
-- Lake (Bronze layer)".

-- sprint3_silver: label y descripción van directo en el CREATE SCHEMA.
CREATE SCHEMA IF NOT EXISTS `sprint3-analytics-hisamitsu.sprint3_silver`
OPTIONS (
    location = 'EU',
    labels = [('layer', 'silver')],
    description = 'Cleaned and typed data (Silver layer)'
);

-- sprint3_gold: crear desde Cloud Shell con bq (no es SQL):
-- bq mk --location=EU --label=layer:gold --description="Business-ready aggregated data (Gold layer)" --dataset sprint3-analytics-hisamitsu:sprint3_gold

-- --- Ejercicio 2 --------------------------------------------------------
-- Tablas externas sobre el Data Lake (gs://bootcamp-data-analytics-public),
-- sin mover datos. Todo STRING: Bronze no tipa nada, eso es cosa de Silver.

-- transactions_raw: CSV con delimitador ";"
CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw` (
    id STRING,
    card_id STRING,
    business_id STRING,
    `timestamp` STRING,
    amount STRING,
    declined STRING,
    product_ids STRING,
    user_id STRING,
    lat STRING,
    longitude STRING
)
OPTIONS (
    format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
    field_delimiter = ';',
    skip_leading_rows = 1
);

-- companies_raw
CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-hisamitsu.sprint3_bronze.companies_raw` (
    company_id STRING,
    company_name STRING,
    phone STRING,
    email STRING,
    country STRING,
    website STRING
)
OPTIONS (
    format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
    field_delimiter = ',',
    skip_leading_rows = 1
);

-- american_users_raw
CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-hisamitsu.sprint3_bronze.american_users_raw` (
    id STRING,
    name STRING,
    surname STRING,
    phone STRING,
    email STRING,
    birth_date STRING,
    country STRING,
    city STRING,
    postal_code STRING,
    address STRING
)
OPTIONS (
    format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv'],
    skip_leading_rows = 1
);

-- european_users_raw: mismo esquema que american_users_raw.
CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-hisamitsu.sprint3_bronze.european_users_raw` (
    id STRING,
    name STRING,
    surname STRING,
    phone STRING,
    email STRING,
    birth_date STRING,
    country STRING,
    city STRING,
    postal_code STRING,
    address STRING
)
OPTIONS (
    format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv'],
    skip_leading_rows = 1
);

-- credit_cards_raw
CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-hisamitsu.sprint3_bronze.credit_cards_raw` (
    id STRING,
    user_id STRING,
    iban STRING,
    pan STRING,
    pin STRING,
    cvv STRING,
    track1 STRING,
    track2 STRING,
    expiring_date STRING
)
OPTIONS (
    format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv'],
    skip_leading_rows = 1
);

-- --- Ejercicio 3 --------------------------------------------------------
-- products.csv no está en el Data Lake: se sube por UI (Create table ->
-- Upload) a sprint3_bronze.products_raw. Esquema manual, todo STRING,
-- Auto detect desactivado (mismo motivo que el Ejercicio 2).
-- Única tabla nativa de Bronze.
-- Origen: 02-s02-bases-de-datos-relacionales-mysql/recursos/N1-Ex.8__products.csv

-- --- Ejercicio 4 --------------------------------------------------------
-- a) Copia nativa de transactions_raw, generada con Gemini.
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw_native` AS
SELECT *
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw`;

-- b) Bytes procesados leyendo una columna, externa vs. nativa (ver Job
-- Information de cada consulta).
SELECT id FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw`;
SELECT id FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw_native`;

-- c) LIMIT no reduce bytes leídos en tablas no clusterizadas. En
-- transactions_raw (externa), sin ORDER BY el lector del CSV para en
-- cuanto tiene 10 filas; con ORDER BY lee el archivo completo igual.
SELECT id FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw` LIMIT 10;
SELECT id FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw_native` LIMIT 10;

SELECT id FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw` ORDER BY id LIMIT 10;
SELECT id FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw_native` ORDER BY id LIMIT 10;

-- --- Ejercicio 5 --------------------------------------------------------
-- Top 5 días de 2021 por ingresos. timestamp/amount/declined son STRING,
-- de ahí PARSE_TIMESTAMP y los SAFE_CAST. declined = 0 porque "ingresos"
-- no debería incluir rechazadas (mismo criterio que en S02).
SELECT
    DATE(PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', `timestamp`)) AS transaction_day,
    SUM(SAFE_CAST(amount AS FLOAT64)) AS daily_income
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw`
WHERE EXTRACT(YEAR FROM PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', `timestamp`)) = 2021
    AND SAFE_CAST(declined AS INT64) = 0
GROUP BY 1
ORDER BY daily_income DESC
LIMIT 5;

-- --- Ejercicio 6 --------------------------------------------------------
-- Nombre, país y fecha de las transacciones de empresas que operaron
-- entre 100 y 200 euros en alguna de estas fechas: 29-04-2015, 20-07-2018
-- o 13-03-2024.
SELECT
    c.company_name,
    c.country,
    EXTRACT(DATE FROM SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', t.timestamp)) AS transaction_date
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw_native` AS t
JOIN `sprint3-analytics-hisamitsu.sprint3_bronze.companies_raw` AS c
    ON t.business_id = c.company_id
WHERE SAFE_CAST(t.amount AS FLOAT64) BETWEEN 100 AND 200
    AND EXTRACT(DATE FROM SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', t.timestamp)) IN ('2015-04-29', '2018-07-20', '2024-03-13');
-- Nota: business_id en transactions_raw, no company_id.

-- =====================================================================
-- NIVEL 2: Limpieza y transformación (ELT)
-- =====================================================================

-- --- Ejercicio 1 --------------------------------------------------------
-- products_clean: product_id a INT64 (cruza con transactions_clean.
-- product_ids en Nivel 3), price/cost sin "$", warehouse_id sin "WH-" a
-- INT64, launch_date a DATE.
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_silver.products_clean` AS
SELECT
    SAFE_CAST(id AS INT64) AS product_id,
    product_name AS name,
    SAFE_CAST(REPLACE(price, '$', '') AS FLOAT64) AS price,
    SAFE_CAST(REPLACE(cost, '$', '') AS FLOAT64) AS cost,
    colour,
    weight,
    SAFE_CAST(REPLACE(warehouse_id, 'WH-', '') AS INT64) AS warehouse_id,
    category,
    brand,
    SAFE_CAST(launch_date AS DATE) AS launch_date
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.products_raw`;

-- --- Ejercicio 2 --------------------------------------------------------
-- transactions_clean: amount/lat/longitude/user_id a número, timestamp
-- parseado, product_ids a ARRAY<INT64>. card_id, business_id y declined,
-- igual.
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean` AS
SELECT
    id AS transaction_id,
    card_id,
    business_id,
    PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', `timestamp`) AS `timestamp`,
    IFNULL(SAFE_CAST(amount AS FLOAT64), 0) AS amount,
    declined,
    ARRAY(
        SELECT SAFE_CAST(TRIM(product_id) AS INT64) AS product_id
        FROM UNNEST(SPLIT(product_ids, ',')) AS product_id
    ) AS product_ids,
    SAFE_CAST(user_id AS INT64) AS user_id,
    SAFE_CAST(lat AS FLOAT64) AS lat,
    SAFE_CAST(longitude AS FLOAT64) AS longitude
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.transactions_raw`;

-- --- Ejercicio 3 --------------------------------------------------------
-- users_combined: UNION ALL de EEUU y Europa + columna origin. id a
-- INT64, birth_date a DATE ("Jul 2, 1980"). postal_code y phone quedan
-- STRING: el postal_code europeo no es numérico (p.ej. "EC1A 1BB").
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_silver.users_combined` AS
SELECT
    SAFE_CAST(id AS INT64) AS user_id,
    name,
    surname,
    phone,
    email,
    SAFE.PARSE_DATE('%b %e, %Y', birth_date) AS birth_date,
    country,
    city,
    postal_code,
    address,
    'US' AS origin
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.american_users_raw`
UNION ALL
SELECT
    SAFE_CAST(id AS INT64) AS user_id,
    name,
    surname,
    phone,
    email,
    SAFE.PARSE_DATE('%b %e, %Y', birth_date) AS birth_date,
    country,
    city,
    postal_code,
    address,
    'EU' AS origin
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.european_users_raw`;

-- --- Ejercicio 4 --------------------------------------------------------
-- companies_clean y credit_cards_clean: copia directa a tabla nativa.
-- companies_raw ya trae la clave como company_id, no hace falta renombrar.
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_silver.companies_clean` AS
SELECT *
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.companies_raw`;

CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_silver.credit_cards_clean` AS
SELECT
    id AS credit_card_id,
    user_id,
    iban,
    pan,
    pin,
    cvv,
    track1,
    track2,
    SAFE.PARSE_DATE('%m/%d/%y', expiring_date) AS expiring_date
FROM `sprint3-analytics-hisamitsu.sprint3_bronze.credit_cards_raw`;

-- =====================================================================
-- NIVEL 3: Presentación de datos y creación de vistas
-- =====================================================================

-- --- Ejercicio 1 --------------------------------------------------------
-- Vista de marketing: nombre, teléfono y país de la compañía, media de
-- compra y clasificación de cliente (Premium si la media > 260€).
CREATE OR REPLACE VIEW `sprint3-analytics-hisamitsu.sprint3_gold.v_marketing_kpis` AS
SELECT
    company.company_name,
    company.phone,
    company.country,
    ROUND(AVG(transactions.amount), 2) AS average_amount,
    IF(AVG(transactions.amount) > 260, 'Premium', 'Standard') AS client_tier
FROM `sprint3-analytics-hisamitsu.sprint3_silver.companies_clean` AS company
INNER JOIN `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean` AS transactions
    ON company.company_id = transactions.business_id
GROUP BY company.company_name, company.phone, company.country;

-- Consulta de entrega. No hace falta ordenar por client_tier: es función
-- directa de average_amount (corte en 260), así que ordenar solo por
-- average_amount ya deja Premium primero.
SELECT *
FROM `sprint3-analytics-hisamitsu.sprint3_gold.v_marketing_kpis`
ORDER BY average_amount DESC;

-- --- Ejercicio 2 --------------------------------------------------------
-- Ranking de productos: aplana product_ids de transactions_clean y
-- cuenta ventas. LEFT JOIN desde products_clean para no perder los
-- productos con 0 ventas.
CREATE OR REPLACE TABLE `sprint3-analytics-hisamitsu.sprint3_gold.product_sales_ranking` AS
WITH products_sold AS (
    SELECT product_id
    FROM `sprint3-analytics-hisamitsu.sprint3_silver.transactions_clean`,
        UNNEST(product_ids) AS product_id
)
SELECT
    products.product_id,
    products.name,
    products.price,
    products.colour,
    COUNT(products_sold.product_id) AS times_sold
FROM `sprint3-analytics-hisamitsu.sprint3_silver.products_clean` AS products
LEFT JOIN products_sold ON products.product_id = products_sold.product_id
GROUP BY products.product_id, products.name, products.price, products.colour;

-- --- Ejercicio 3 --------------------------------------------------------
-- Exportación: tabla product_sales_ranking -> "Open in" -> "Connected
-- Sheets". No requiere SQL adicional.
