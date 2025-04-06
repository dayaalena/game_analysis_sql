/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
*/
-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
--Рассчитываем количество уникальных пользователей, 
--количество платящих пользователй и долю платящих пользователей об общего числа
SELECT 
	COUNT(id) AS count_users,
	SUM(payer) AS count_payers,
	ROUND(AVG(payer)::numeric, 4) AS payer_part
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
--Рассчитываем количество уникальных пользователей, 
--количество платящих пользователй и долю платящих пользователей об общего числа для каждой расы
SELECT 
	r.race,
	SUM(payer) AS count_payers,
	COUNT(id) AS count_users,
	ROUND(AVG(payer)::NUMERIC, 4) AS payer_part
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING(race_id)
GROUP BY r.race
ORDER BY payer_part DESC;
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Рассчитываем основные статистические показатели по полю amount:
SELECT 
	COUNT(transaction_id) AS count_transaction,--общее количество покупок
	SUM(amount) AS total_amount,--общая стоимость всех покупок
	MIN(amount) AS min_amount,--минимальная стоимость покупки
	MAX(amount) AS max_amount,--максимальная стоимость покупки
	AVG(amount)::numeric(5, 2) AS avg_amount,--средняя стоимость покупки
	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS mediana_amount,--медианная стоимость покупки
	STDDEV(amount)::numeric(6, 2) AS stand_dev_amount--стандартное отклоенение стоимости покупки
FROM fantasy.events;
-- 2.2: Аномальные нулевые покупки:
--Рассчитываем количество покупок с нулевой стоимостью и их долю от общего количества покупок
	SELECT 
		COUNT(CASE WHEN amount = 0 THEN 1 END) AS zero_amount_transaction,
		ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END) / COUNT(transaction_id)::NUMERIC, 5) AS zero_amount_part
	FROM fantasy.events;
--Проверяем, какие предметы и какими игроками были приобретены за 0 у.е.
	SELECT 
		item_code,
		id,
		COUNT(transaction_id)
	FROM fantasy.events
	WHERE amount = 0
	GROUP BY item_code, id
	ORDER BY count DESC;
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
/*
 * Сравниваем платящих и неплатящих игроков
 * В подзпросе рассчитываем количество и общую сумму покупок для каждого игрока
 * В основном запросе выделяем две группы среди пользователей - платящие и неплатящие
 * Для каждой группы рассчитываем количество пользователей, среднее количество покупок и среднюю потраченную сумму для одного пользователя 
 */
WITH count_transactions AS(
	SELECT 
		id, 
		COUNT(DISTINCT transaction_id) AS count_transaction,
		SUM(amount) AS sum_amount
	FROM fantasy.events
	WHERE amount > 0
	GROUP BY id
)
	SELECT
		race,
		CASE
			WHEN payer = 0
				THEN 'неплатящие'
			WHEN payer = 1
				THEN 'платящие'
			ELSE 'неизвестно'
		END AS payer,
		COUNT(id) AS count_users,
		ROUND(AVG(count_transaction)::numeric, 2) AS avg_transactions,
		ROUND(AVG(sum_amount)::numeric, 2) AS avg_amount
	FROM count_transactions 
	NATURAL JOIN fantasy.users
	NATURAL JOIN fantasy.race
	GROUP BY race, payer
	ORDER BY race DESC;
/*	
 * Без учёта расы
	SELECT
		CASE
			WHEN payer = 0
				THEN 'неплатящие'
			WHEN payer = 1
				THEN 'платящие'
			ELSE 'неизвестно'
		END AS payer,
		COUNT(id) AS count_users,
		ROUND(AVG(count_transaction)::numeric, 2) AS avg_transactions,
		ROUND(AVG(sum_amount)::numeric, 2) AS avg_amount
	FROM count_transactions 
	NATURAL JOIN fantasy.users
	GROUP BY payer;
*/
-- 2.4: Популярные эпические предметы:
/*
 * Составляем рейтинг эпических предметов по доле их продаж и доле игроков, хотя бы раз купивших этот предмет
 */
	SELECT 
		game_items,
		COUNT(transaction_id) AS count_transactions,--количество продаж предмета
		ROUND(COUNT(transaction_id) / (SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount != 0)::NUMERIC, 7) AS transaction_part,--доля продаж предмета от общего количества продаж
		ROUND(COUNT(DISTINCT id) / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount != 0 )::numeric, 8) AS unique_user_transaction--доля пользователей, хотя бы раз купивших этот предмет
	FROM fantasy.items
	LEFT JOIN fantasy.events USING(item_code)
	WHERE amount > 0
	GROUP BY game_items
	ORDER BY count_transactions DESC;	
	--Заметим, что некоторые предметы записаны под разными item_code, поэтому будем группировать по названию предмета
	SELECT 
	game_items ,
	COUNT(item_code)
	FROM fantasy.items
	GROUP BY game_items 
	ORDER BY count DESC;
	--Рассчитываем количество предметов, которые ни разу не купили
	SELECT 
		game_items,
		COUNT(transaction_id) AS count_transactions--количество продаж предмета	
	FROM fantasy.items 
	LEFT JOIN fantasy.events USING(item_code)
	GROUP BY game_items
	HAVING COUNT(transaction_id) = 0
	ORDER BY count_transactions;
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
--Рассчитываем активность пользователей при покупке эпических предметов в зависимости от расы персонажа
	WITH 
	--Рассчитываем количество уникальных пользователей каждой расы
	count_id AS(
	SELECT 
		race_id,
		COUNT(DISTINCT id) AS count_users
	FROM fantasy.users
	GROUP BY race_id),
	--Рассчитываем количество покупок, среднюю стоимость одной покупки и сумму всех покупок
	race_stat AS(
	SELECT
		race_id,
		COUNT(DISTINCT id) AS buyers_count,
		ROUND(COUNT(DISTINCT id) FILTER(WHERE payer = 1)::NUMERIC / COUNT(DISTINCT id), 5) AS payers_part,
		ROUND(COUNT(transaction_id) / COUNT(DISTINCT id)::NUMERIC, 4) AS avg_transactions,
		ROUND(SUM(amount)::numeric / COUNT(transaction_id), 4) AS avg_purchase,
		ROUND(SUM(amount)::numeric / COUNT(DISTINCT id)::NUMERIC, 4) AS avg_sum
	FROM fantasy.events
	LEFT JOIN fantasy.users USING(id)
	WHERE amount > 0
	GROUP BY race_id)
	--В основном запросе объединяем полученную ранее информацию в разрезе каждой расы
	SELECT 
		race,
		count_users,
		buyers_count,
		ROUND(buyers_count / count_users::NUMERIC, 4) AS buyers_part,-- доля игроков, которые совершают внутриигровые покупки, от общего количества
		payers_part,
		avg_transactions,
		avg_purchase,
		avg_sum
	FROM count_id 
	NATURAL JOIN race_stat 
	NATURAL JOIN fantasy.race
	ORDER BY payers_part DESC;
-- Задача 2: Частота покупок
	--Анализ групп пользователей в зависимости от частоты совершения покупок
	WITH 
	--Рассчитываем количество дней, прошедших с предыдущей покупки, для каждого пользователя и каждой покупки
	days_left AS
	(SELECT 
		*,
		EXTRACT(DAY FROM(date::timestamp - LAG(date) OVER(PARTITION BY id ORDER BY date)::timestamp))AS days_left
	FROM fantasy.events
	WHERE amount > 0),--исключаем покупки с нулевой стоимостью
	--Рассчитываем количество покупок и среднее количество дней между покупками для каждого пользователя
	user_info AS(
	SELECT
		id,
		payer,
		COUNT(transaction_id) AS count_transactions,
		ROUND(AVG(days_left)::NUMERIC, 2) AS avg_time
	FROM days_left
	JOIN fantasy.users USING(id)
	GROUP BY id, payer
	HAVING COUNT(transaction_id) >= 25),--учитываем только тех пользователей, которые совершили 25 и более покупок
	--Делим всех пользователей на 3 равные группы по среднему количеству дней между покупками
	user_rank AS
	(SELECT
		*,
		NTILE(3) OVER(ORDER BY avg_time) AS frequency
	FROM user_info)
	--Присваиваем каждой группе наименование, согласно частоте совершаемых покупок
	--Для каждой группы проводим расчёт статистических показателей
	SELECT 
	CASE
		WHEN frequency = 1
			THEN 'высокая частота'
		WHEN frequency = 2
			THEN 'умеренная частота'
		WHEN frequency = 3
			THEN 'низкая частота'
	END AS frequency,
	COUNT(id) AS count_users,--количество пользователей, совершивших покупки
	SUM(payer) AS payers_count,--количество платящих пользователей, совершивших покупки
	ROUND(SUM(payer) / COUNT(id)::NUMERIC, 4) AS payers_part,--доля платящих пользоваталей от общего количества пользователей, совершивших покупки
	ROUND(AVG(count_transactions), 2) AS avg_transactions_count,--среднее количество покупок на одного игрока
	ROUND(AVG(avg_time), 2) AS avg_time--среднее количество дней между покупками
	FROM user_rank
	GROUP BY frequency
	ORDER BY avg_time;