-- =====================================================================
-- S02: Bases de datos relacionales en MySQL
-- El esquema (base de datos "transactions") y los datos ya vienen dados
-- por el curso en recursos/N1-Ex.1__estructura_dades.sql y
-- recursos/N1-Ex.1__dades_introduir.sql -- ejecutar esos primero, y
-- luego USE transactions; a continuación. Este archivo contiene
-- únicamente las consultas de los ejercicios.
-- =====================================================================

USE transactions;

-- =====================================================================
-- NIVEL 1
-- =====================================================================

-- --- Ejercicio 1 -------------------------------------------------------
-- A partir de los documentos adjuntos (estructura_dades y
-- dades_introduir), importa las dos tablas. Muestra las características
-- principales del esquema creado y explica las diferentes tablas y
-- variables que existen. Asegúrate de incluir un diagrama que ilustre
-- la relación entre las diferentes tablas y variables.
-- (diagrama -> diagramas/)


-- --- Ejercicio 2 -------------------------------------------------------
-- Utilizando JOIN realizarás las siguientes consultas:
-- - Listado de los países que están generando ventas.
SELECT DISTINCT `company`.`country`
FROM `company`
INNER JOIN `transaction` ON `transaction`.`company_id` = `company`.`id`;

-- - Desde cuántos países se generan las ventas.
SELECT COUNT(DISTINCT `company`.`country`) AS `countries_with_transaction`
FROM `company`
INNER JOIN `transaction` ON `transaction`.`company_id` = `company`.`id`;

-- - Identifica la compañía con la media más grande de ventas.
SELECT `company`.`id`,
		`company`.`company_name`
FROM `company`
INNER JOIN `transaction` ON `transaction`.`company_id` = `company`.`id`
GROUP BY `company`.`id`
ORDER BY AVG(`transaction`.`amount`) DESC
LIMIT 1;

-- --- Ejercicio 3 -------------------------------------------------------
-- Utilizando únicamente subconsultas (sin utilizar JOIN):
-- - Muestra todas las transacciones realizadas por empresas de Alemania.
SELECT *
FROM `transaction`
WHERE `transaction`.`company_id` IN (SELECT `id`
									FROM `company`
									WHERE `country` = "Germany");

-- - Lista las empresas que han realizado transacciones por un amount
--   superior a la media de todas las transacciones.
SELECT *
FROM `company`
WHERE `company`.`id` IN (SELECT DISTINCT `company_id`
						FROM `transaction`
                        WHERE `amount` > (SELECT AVG(`amount`) FROM `transaction`));
                        
-- - Eliminarán del sistema las empresas que no tienen transacciones
--   registradas, entrega el listado de estas empresas.
SELECT *
FROM `company`
WHERE `company`.`id` NOT IN (SELECT DISTINCT `company_id`
							FROM `transaction`);

-- --- Ejercicio 4 -------------------------------------------------------
-- Tu tarea es diseñar y crear una tabla llamada "credit_card" que
-- almacene detalles cruciales sobre las tarjetas de crédito. La nueva
-- tabla debe ser capaz de identificar de manera única cada tarjeta y
-- establecer una relación adecuada con las otras dos tablas
-- ("transaction" y "company"). Después de crear la tabla será necesario
-- que ingreses la información del documento denominado
-- "dades_introduir_credit". Recuerda mostrar el diagrama y realizar una
-- breve descripción de este.
CREATE TABLE `credit_card` (
	`id` VARCHAR(15) PRIMARY KEY,
    `iban` VARCHAR(34) NOT NULL,
    `pan` VARCHAR(19) NOT NULL,
    `pin` VARCHAR(4),
    `cvv` VARCHAR(3),
    `expiring_date` VARCHAR(10)
);

-- Cargar los datos:
-- -> recursos/N1-Ex.4__dades_introduir_credit.sql

-- El archivo dades_introduir_credit carga las fechas en formato mm/dd/yy;
-- hay que convertirlas al formato de fecha de MySQL.
-- NOTA: el LIMIT (igual al total de filas de la tabla) es necesario para
-- pasar el modo seguro (SQL_SAFE_UPDATES) sin tener que desactivarlo,
-- ya que esta actualización no tiene una condición WHERE restrictiva
-- (se aplica a todas las filas).
UPDATE `credit_card`
SET `expiring_date` = STR_TO_DATE(`expiring_date`, '%m/%d/%y')
LIMIT 5000;

-- Se cambia el tipo de la columna a DATE.
ALTER TABLE `credit_card`
MODIFY `expiring_date` DATE;

-- FK a credit_card, que no existía cuando se creó transaction.
ALTER TABLE `transaction`
	ADD CONSTRAINT `transaction_credit_card_fk`
    FOREIGN KEY (`credit_card_id`)
    REFERENCES `credit_card`(`id`)
    ON DELETE SET NULL;

-- --- Ejercicio 5 -------------------------------------------------------
-- El departamento de Recursos Humanos ha identificado un error en el
-- número de cuenta asociado a la tarjeta de crédito con ID CcU-2938.
-- La información que debe mostrarse para este registro es:
-- TR323456312213576817699999. Recuerda mostrar que el cambio se realizó.
UPDATE `credit_card`
SET `iban` = 'TR323456312213576817699999'
WHERE `id` = 'CcU-2938';

SELECT *
FROM `credit_card`
WHERE `id` = 'CcU-2938';

-- --- Ejercicio 6 -------------------------------------------------------
-- En la tabla "transaction" ingresa una nueva transacción con la
-- siguiente información:
--   id              108B1D1D-5B23-A76C-55EF-C568E49A99DD
--   credit_card_id  CcU-9999
--   company_id      b-9999
--   user_id         9999
--   lat             829.999
--   longitude       -117.999
--   amount          111.11
--   declined        0
INSERT INTO `transaction` (`id`, `credit_card_id`, `company_id`, `user_id`, `lat`, `longitude`, `amount`, `declined`)
VALUES('108B1D1D-5B23-A76C-55EF-C568E49A99DD', 'CcU-9999', 'b-9999', 9999, 829.999, -117.999, 111.11, 0);

SELECT * FROM `company`
WHERE `id` = 'b-9999';

-- --- Ejercicio 7 -------------------------------------------------------
-- Desde recursos humanos te solicitan eliminar la columna "pan" de la
-- tabla credit_card. Recuerda mostrar el cambio realizado.
DESCRIBE `credit_card`;

ALTER TABLE `credit_card`
DROP COLUMN `pan`;

DESCRIBE `credit_card`;

-- --- Ejercicio 8 -------------------------------------------------------
-- Descarga los archivos CSV que encontrarás en el apartado de recursos:
-- american_users.csv, european_users.csv, companies.csv,
-- credit_cards.csv, transactions.csv (-> recursos/N1-Ex.8__*.csv).
-- Estúdialos y diseña una base de datos con un esquema en estrella que
-- contenga, al menos, 4 tablas con las que puedas realizar las
-- siguientes consultas. La tabla de products.csv la utilizaremos más
-- adelante.

-- Base de datos aparte para el esquema en estrella del ejercicio 8.
-- A partir de aqui (Ej.8 en adelante, incluyendo Nivel 2 y N3-Ej.1) todo
-- corre sobre sales, no sobre transactions: mismos 100 companies /
-- 100000 transactions en ambas bases, pero sales tiene el detalle
-- completo (discount/tax/shipping) que transactions no tiene.
CREATE DATABASE IF NOT EXISTS `sales`;
USE `sales`;

-- Todo VARCHAR de entrada para que el LOAD DATA no falle; el tipo se cambia después.
-- Dimensión de usuarios
CREATE TABLE IF NOT EXISTS `users` (
	`id` VARCHAR(255) NULL,
	`name` VARCHAR(255) NULL,
	`surname` VARCHAR(255) NULL,
	`phone` VARCHAR(255) NULL,
	`email` VARCHAR(255) NULL,
	`birth_date` VARCHAR(255) NULL,
	`country` VARCHAR(255) NULL,
	`city` VARCHAR(255) NULL,
	`postal_code` VARCHAR(255) NULL,
	`address` VARCHAR(255) NULL,
	`signup_date` VARCHAR(255) NULL,
	`user_segment` VARCHAR(255) NULL,
	`income_band` VARCHAR(255) NULL,
	`region` VARCHAR(255) NULL
);

-- Dimensión de empresas
CREATE TABLE IF NOT EXISTS `companies` (
	`company_id` VARCHAR(255) NULL,
	`company_name` VARCHAR(255) NULL,
	`phone` VARCHAR(255) NULL,
	`email` VARCHAR(255) NULL,
	`country` VARCHAR(255) NULL,
	`website` VARCHAR(255) NULL,
	`merchant_category` VARCHAR(255) NULL,
	`merchant_price_position` VARCHAR(255) NULL
);

-- Dimensión de tarjetas
CREATE TABLE IF NOT EXISTS `credit_cards` (
	`id` VARCHAR(255) NULL,
	`user_id` VARCHAR(255) NULL,
	`iban` VARCHAR(255) NULL,
	`pan` VARCHAR(255) NULL,
	`pin` VARCHAR(255) NULL,
	`cvv` VARCHAR(255) NULL,
	`track1` VARCHAR(255) NULL,
	`track2` VARCHAR(255) NULL,
	`expiring_date` VARCHAR(255) NULL,
	`card_type` VARCHAR(255) NULL,
	`card_renewal_flag` VARCHAR(255) NULL
);

-- Tabla de hechos: cada fila es una transacción
CREATE TABLE IF NOT EXISTS `transactions` (
	`id` VARCHAR(255) NULL,
	`card_id` VARCHAR(255) NULL,
	`business_id` VARCHAR(255) NULL,
	`timestamp` VARCHAR(255) NULL,
	`amount` VARCHAR(255) NULL,
	`declined` VARCHAR(255) NULL,
	`product_ids` VARCHAR(255) NULL,
	`user_id` VARCHAR(255) NULL,
	`lat` VARCHAR(255) NULL,
	`longitude` VARCHAR(255) NULL,
	`discount_amount` VARCHAR(255) NULL,
	`tax_amount` VARCHAR(255) NULL,
	`shipping_amount` VARCHAR(255) NULL,
	`channel` VARCHAR(255) NULL,
	`campaign_id` VARCHAR(255) NULL,
	`device_type` VARCHAR(255) NULL,
	`is_international` VARCHAR(255) NULL,
	`decline_reason` VARCHAR(255) NULL,
	`distance_km` VARCHAR(255) NULL
);

-- Carga los usuarios de EE.UU.; region no viene en el CSV, la fijamos con SET region = America.
LOAD DATA
INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__american_users.csv'
INTO TABLE `users`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS
(`id`, `name`, `surname`, `phone`, `email`, `birth_date`, `country`, `city`, `postal_code`, `address`, `signup_date`, `user_segment`, `income_band`)
SET `region` = 'America';

-- Carga los usuarios de Europa, marcando region = Europe.
LOAD DATA
INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__european_users.csv'
INTO TABLE `users`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS
(`id`, `name`, `surname`, `phone`, `email`, `birth_date`, `country`, `city`, `postal_code`, `address`, `signup_date`, `user_segment`, `income_band`)
SET `region` = 'Europe';

-- birth_date llega como 'Nov 17, 1985'; se convierte antes de tipar la columna como DATE.
UPDATE `users`
SET `birth_date` = STR_TO_DATE(`birth_date`, '%b %e, %Y')
LIMIT 5000;

-- Tipos reales y PK una vez los datos ya están limpios.
ALTER TABLE `users`
	MODIFY `id` INT PRIMARY KEY,
    MODIFY `name` VARCHAR(255) NOT NULL,
	MODIFY `surname` VARCHAR(255) NOT NULL,
	MODIFY `birth_date` DATE,
	MODIFY `signup_date` DATE;

-- Carga las empresas
LOAD DATA
INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__companies.csv'
INTO TABLE `companies`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS
(`company_id`, `company_name`, `phone`, `email`, `country`, `website`, `merchant_category`, `merchant_price_position`);

-- company_id como PK; el resto se queda como texto.
ALTER TABLE `companies`
	MODIFY `company_id` VARCHAR(10) PRIMARY KEY,
	MODIFY `company_name` VARCHAR(255) NOT NULL;

-- Carga las tarjetas
LOAD DATA
INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__credit_cards.csv'
INTO TABLE `credit_cards`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS
(`id`, `user_id`, `iban`, `pan`, `pin`, `cvv`, `track1`, `track2`, `expiring_date`, `card_type`, `card_renewal_flag`);

-- formato de fecha (mm/dd/yy)
UPDATE `credit_cards`
SET `expiring_date` = STR_TO_DATE(`expiring_date`, '%m/%d/%y')
LIMIT 5000;

-- Se tipan user_id y expiring_date, y se fija id como PK.
ALTER TABLE `credit_cards`
	MODIFY `id` VARCHAR(10) PRIMARY KEY,
	MODIFY `user_id` INT,
	MODIFY `expiring_date` DATE,
	MODIFY `card_renewal_flag` TINYINT;

-- No hay FK directa entre credit_cards y users: enlazaría dos dimensiones
-- entre sí y rompería el esquema en estrella. La relación queda cubierta
-- indirectamente a través de transactions (card_id y user_id).

-- Diferente de los otros archivos, en este el separador es ';'
LOAD DATA
INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__transactions.csv'
INTO TABLE `transactions`
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
IGNORE 1 ROWS
(`id`, `card_id`, `business_id`, `timestamp`, `amount`, `declined`, `product_ids`, `user_id`, `lat`, `longitude`, `discount_amount`, `tax_amount`, `shipping_amount`, `channel`, `campaign_id`, `device_type`, `is_international`, `decline_reason`, `distance_km`);

-- Tipado de la tabla de hechos.
ALTER TABLE `transactions`
	MODIFY `id` VARCHAR(36) PRIMARY KEY,
	MODIFY `card_id` VARCHAR(10),
	MODIFY `business_id` VARCHAR(10),
	MODIFY `timestamp` DATETIME NOT NULL,
	MODIFY `amount` DECIMAL(10,2) NOT NULL,
	MODIFY `declined` TINYINT,
	MODIFY `user_id` INT,
	MODIFY `lat` DOUBLE,
	MODIFY `longitude` DOUBLE,
	MODIFY `discount_amount` DECIMAL(10,2),
	MODIFY `tax_amount` DECIMAL(10,2),
	MODIFY `shipping_amount` DECIMAL(10,2),
	MODIFY `is_international` TINYINT,
	MODIFY `distance_km` DECIMAL(10,2);

-- Conecta la tabla de hechos con la dimensión de tarjetas.
ALTER TABLE `transactions`
	ADD CONSTRAINT `transaction_credit_card_fk`
    FOREIGN KEY (`card_id`)
    REFERENCES `credit_cards`(`id`)
    ON DELETE SET NULL;

-- Conecta la tabla de hechos con la dimensión de empresas.
ALTER TABLE `transactions`
	ADD CONSTRAINT `transaction_company_fk`
    FOREIGN KEY (`business_id`)
    REFERENCES `companies`(`company_id`)
    ON DELETE SET NULL;

-- Conecta la tabla de hechos con la dimensión de usuarios.
ALTER TABLE `transactions`
	ADD CONSTRAINT `transaction_user_fk`
    FOREIGN KEY (`user_id`)
    REFERENCES `users`(`id`)
    ON DELETE SET NULL;

-- --- Ejercicio 9 -------------------------------------------------------
-- Realiza una subconsulta que muestre todos los usuarios con más de 80
-- transacciones utilizando al menos 2 tablas.
SELECT *
FROM `users`
WHERE `id` IN (SELECT `user_id`
				FROM `transactions`
				GROUP BY `user_id`
				HAVING COUNT(*) > 80);

-- --- Ejercicio 10 ------------------------------------------------------
-- Muestra la media de amount por IBAN de las tarjetas de crédito en la
-- compañía Donec Ltd, utiliza al menos 2 tablas.
SELECT `credit_cards`.`iban`, AVG(`transactions`.`amount`) AS `average_amount`
FROM `transactions`
INNER JOIN `credit_cards` ON `credit_cards`.`id` = `transactions`.`card_id`
WHERE `transactions`.`business_id` = (SELECT `company_id`
									FROM `companies`
									WHERE `company_name` = 'Donec Ltd')
GROUP BY `credit_cards`.`iban`;

-- =====================================================================
-- NIVEL 2
-- =====================================================================

-- --- Ejercicio 1 -------------------------------------------------------
-- Identifica los cinco días en que se generó la mayor cantidad de
-- ingresos en la empresa por ventas. Muestra la fecha de cada
-- transacción junto con el total de las ventas.
SELECT DATE(`timestamp`) AS `day`, SUM(`amount`) AS `total_amount`
FROM `transactions`
GROUP BY DATE(`timestamp`)
ORDER BY SUM(`amount`) DESC
LIMIT 5;

-- --- Ejercicio 2 -------------------------------------------------------
-- Presenta el nombre, teléfono, país, fecha y amount, de aquellas
-- empresas que realizaron transacciones con un valor comprendido entre
-- 350 y 400 euros y en alguna de estas fechas: 29 de abril de 2015,
-- 20 de julio de 2018 y 13 de marzo de 2024. Ordena los resultados de
-- mayor a menor cantidad.
SELECT `companies`.`company_name`,
		`companies`.`phone`,
        `companies`.`country`,
        DATE(`transactions`.`timestamp`) AS `date`,
        `transactions`.`amount`
FROM `companies`
INNER JOIN `transactions` ON `transactions`.`business_id` = `companies`.`company_id`
WHERE `transactions`.`amount` BETWEEN 350 AND 400
	AND DATE(`transactions`.`timestamp`) IN ('2015-04-29', '2018-07-20', '2024-03-13')
ORDER BY `transactions`.`amount` DESC;

-- --- Ejercicio 3 -------------------------------------------------------
-- Necesitamos optimizar la asignación de recursos y dependerá de la
-- capacidad operativa que se requiera, por lo que te piden la
-- información sobre la cantidad de transacciones que realizan las
-- empresas, pero el departamento de recursos humanos es exigente y
-- quiere un listado de las empresas donde especifiques si tienen igual
-- o más de 400 transacciones o menos.
WITH `group_transactions` AS (
		SELECT `transactions`.`business_id`,
				COUNT(`transactions`.`id`) AS `count_transactions`,
				(COUNT(`transactions`.`id`) >= 400) AS `exceed_capacity`
		FROM `transactions`
		GROUP BY `transactions`.`business_id`)
SELECT `companies`.`company_id`,
		`companies`.`company_name`,
        `group_transactions`.`count_transactions`,
        `group_transactions`.`exceed_capacity`
FROM `companies`
LEFT JOIN `group_transactions` ON `group_transactions`.`business_id` = `companies`.`company_id`
ORDER BY `group_transactions`.`count_transactions`;

-- --- Ejercicio 4 -------------------------------------------------------
-- Elimina de la tabla transaction el registro con ID
-- 000447FE-B650-4DCF-85DE-C7ED0EE1CAAD de la base de datos.
SELECT *
FROM `transactions`
WHERE `id` = '000447FE-B650-4DCF-85DE-C7ED0EE1CAAD';

DELETE FROM `transactions`
WHERE `id` = '000447FE-B650-4DCF-85DE-C7ED0EE1CAAD';

-- --- Ejercicio 5 -------------------------------------------------------
-- La sección de marketing desea tener acceso a información específica
-- para realizar análisis y estrategias efectivas. Se ha solicitado
-- crear una vista que proporcione detalles clave sobre las compañías y
-- sus transacciones. Será necesario que crees una vista llamada
-- VistaMarketing que contenga la siguiente información: nombre de la
-- compañía, teléfono de contacto, país de residencia, media de compra
-- realizada por cada compañía. Presenta la vista creada, ordenando los
-- datos de mayor a menor media de compra.
CREATE OR REPLACE VIEW `VistaMarketing` AS
WITH `group_transactions` AS (
		SELECT `transactions`.`business_id`,
				ROUND(AVG(`transactions`.`amount`),2) AS `average_amount`
		FROM `transactions`
		GROUP BY `transactions`.`business_id`)
SELECT `companies`.`company_name`,
		`companies`.`phone`,
        `companies`.`country`,
        `group_transactions`.`average_amount`
FROM `companies`
INNER JOIN `group_transactions` ON `group_transactions`.`business_id` = `companies`.`company_id`
ORDER BY `group_transactions`.`average_amount` DESC;

SELECT * FROM `VistaMarketing`;

-- =====================================================================
-- NIVEL 3
-- =====================================================================

-- --- Ejercicio 1 -------------------------------------------------------
-- Crea una nueva tabla que refleje el estado de las tarjetas de crédito
-- basado en si las tres últimas transacciones han sido declinadas
-- entonces está inactiva, si al menos una no ha sido rechazada entonces
-- está activa. Partiendo de esta tabla responde:
-- 👉 ¿Cuántas tarjetas están activas?
CREATE TABLE `credit_card_status` (
	`card_id` VARCHAR(10),
    `is_inactive` TINYINT,
    PRIMARY KEY(`card_id`),
    FOREIGN KEY (`card_id`) REFERENCES `credit_cards`(`id`)
);

INSERT INTO `credit_card_status` (`card_id`, `is_inactive`)
WITH `transaction_status` AS 
	(SELECT ROW_NUMBER() OVER (PARTITION BY `card_id` ORDER BY `timestamp` DESC) AS `row`,
		`card_id`,
		`declined`
	FROM `transactions`)
SELECT `card_id`,
	MIN(`declined`) AS `is_inactive`
FROM `transaction_status`
WHERE `row` <= 3
GROUP BY `card_id`
ON DUPLICATE KEY UPDATE `is_inactive` = VALUES(`is_inactive`);

SELECT `is_inactive`,
		COUNT(`card_id`) AS `count_cards`
FROM `credit_card_status`
GROUP BY `is_inactive`;

-- --- Ejercicio 2 -------------------------------------------------------
-- Crea una tabla con la que podamos unir los datos del archivo
-- products.csv con la base de datos creada (ya que hasta ahora no
-- podíamos hacerlo), teniendo en cuenta que desde transaction tienes
-- product_ids. Genera la siguiente consulta:
-- 👉 Necesitamos conocer el número de veces que se ha vendido cada
--    producto.

-- Nueva dimensión: productos.
CREATE TABLE `products` (
	`id` VARCHAR(255),
	`product_name` VARCHAR(255),
	`price` VARCHAR(255),
	`colour` VARCHAR(255),
	`weight` VARCHAR(255),
	`warehouse_id` VARCHAR(255),
	`category` VARCHAR(255),
	`brand` VARCHAR(255),
	`cost` VARCHAR(255),
	`launch_date` VARCHAR(255)
);

-- Carga los productos
LOAD DATA
INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/N1-Ex.8__products.csv'
INTO TABLE `products`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
IGNORE 1 ROWS
(`id`, `product_name`, `price`, `colour`, `weight`, `warehouse_id`, `category`, `brand`, `cost`, `launch_date`);

-- Los precios tienen '$' en el archivo de carga.
UPDATE `products`
SET `price` = REPLACE(`price`, '$', ''),
	`cost` = REPLACE(`cost`, '$', '')
LIMIT 1000;

-- Tipado de la tabla products.
ALTER TABLE `products`
	MODIFY `id` INT PRIMARY KEY,
	MODIFY `price` DECIMAL(10,2),
	MODIFY `weight` DECIMAL(5,2),
	MODIFY `cost` DECIMAL(10,2),
	MODIFY `launch_date` DATE;

-- Tabla puente para la relación N:M entre transactions y products.
CREATE TABLE `product_transaction` (
	`transaction_id` VARCHAR(36),
	`product_id` INT,
	PRIMARY KEY (`transaction_id`, `product_id`),
	FOREIGN KEY (`transaction_id`) REFERENCES `transactions`(`id`),
	FOREIGN KEY (`product_id`) REFERENCES `products`(`id`)
);

-- product_ids es una lista separada por comas; el CTE recursivo la
-- separa en una fila por producto.
INSERT INTO `product_transaction` (`transaction_id`,`product_id`)
WITH RECURSIVE `product_transactions` AS (
		SELECT `id`,
				TRIM(LEFT(`product_ids`, LOCATE(',', `product_ids`) - 1)) AS `product_id`,
				TRIM(RIGHT(`product_ids`, CHAR_LENGTH(`product_ids`) - LOCATE(',', `product_ids`))) AS `remaining_ids`
		FROM `transactions`
		WHERE LOCATE(',', `product_ids`) > 0
	UNION ALL
		SELECT `id`,
				TRIM(`product_ids`),
				NULL
		FROM `transactions`
		WHERE LOCATE(',', `product_ids`) = 0
	UNION ALL
		SELECT `id`,
				TRIM(LEFT(`remaining_ids`, LOCATE(',', `remaining_ids`) - 1)),
				TRIM(RIGHT(`remaining_ids`, CHAR_LENGTH(`remaining_ids`) - LOCATE(',', `remaining_ids`)))
		FROM `product_transactions`
		WHERE `remaining_ids` IS NOT NULL AND LOCATE(',', `remaining_ids`) > 0
	UNION ALL
		SELECT `id`,
				`remaining_ids`,
				NULL
		FROM `product_transactions`
		WHERE `remaining_ids` IS NOT NULL AND LOCATE(',', `remaining_ids`) = 0
)
SELECT `id`, `product_id` FROM `product_transactions` ORDER BY `id`;

-- Ventas por producto
-- LEFT JOIN para incluir productos con 0 ventas.
SELECT `products`.`product_name`,
		COUNT(`product_transaction`.`transaction_id`) AS `count_transactions`
FROM `products`
LEFT JOIN `product_transaction` ON `product_transaction`.`product_id` = `products`.`id`
GROUP BY `products`.`id`;





