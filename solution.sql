

--Этап 1. СОЗДАНИЕ И ЗАПОЛНЕНИЕ БД

--1.	Создадим схему raw_data и таблицу sales в этой схеме.

create schema raw_data;
create table raw_data.sales (
id int PRIMARY KEY,
auto VARCHAR,
gasoline_consumption numeric(3,1),
price numeric(9,2),
date DATE,
person_name	VARCHAR,
phone VARCHAR,
discount SMALLINT,
brand_origin VARCHAR
);
 
--Заполняем таблицу sales данными:
\copy raw_data.sales(id, auto, color, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) from 'd:\SQL\Project\cars.csv' csv null 'null' header;


--2.1 СОЗДАНИЕ СХЕМЫ car_shop И НОРМАЛИЗОВАННЫХ ТАБЛИЦ
--Для оптимальной реализации связи многие-ко-многим для атрибута color решено завести отдельную таблицу(cars), в которую войдёт бренд+модель и цвет (всё в виде ссылок, конечно). Для пар бренд-модель и для цветов будут созданы отдельные родительские таблицы brand_models и colors соответственно. 
--Этот ход позволит сэкономить суммарное место в памяти, поскольку с ростом числа продаже объём памяти, связанный именно с цветом проданной машины расти не будет. Всё, что связано с цветом, занимает постоянный объём в двух небольших таблицах (colors - для имён и ключей, 8 записей - varchar(15), int2; cars - для ключей, 158 записей, int4, int2, int2). 

--Создаём схему:
create schema car_shop;

--Создаём таблицу 1 - clients.
--Клиенты:Имя, Фамилия, телефон

create table car_shop.clients (
client_id serial primary key, /*первичный ключ с автоинкрементом, число клиентов может стать большим, поэтому не укорачиваем ключ до int2*/
first_name    VARCHAR(20) NOT NULL, /*текст с ограничением длины строки в 20 символов, пустые значения не допускаются*/
last_name   VARCHAR(20) NOT NULL, /*текст с ограничением длины строки в 20 символов, пустые значения не допускаются */
phone VARCHAR(30)  UNIQUE, /*поскольку номер телефона содержит не только цифры, используем текст с ограничением длины строки в 30 символов, не допускаем дублирование */
constraint first_last_names_unique UNIQUE(first_name, last_name) /*не допускаем дублирование комбинации имени и фамилии клиента*/
);

--Создаём таблицу 2 - brands:
--Бренд: список марок(брендов) машин выделен и стран происхождения;
-- выделен в отдельную таблицу, поскольку 
-- страна происхождения одна и та же для всех моделей каждой марки.
-- Марки с моделями будут связаны в дочерней таблице brand_models,
-- в которую войдёт также расход топлива каждой модели

create table car_shop.brands (
brand_id serial2 PRIMARY KEY, /*первичный ключ с автоинкрементом, int2 вполне достаточно*/
brand_name VARCHAR(15) unique not null, /*в названии бренда могут быть и цифры, и буквы, поэтому выбираем varchar, 15 символов достаточно для всех марок, повторяться они должны, поэтому unique; пустые значения не допускамем, поэтому not null*/
brand_origin VARCHAR(40) /*для названия страны отведём 40 символов*/
);

--Создаём таблицу 3 - colors:
--Цвета. Отдельный список всех вариантов цвета - colors. Это одна из двух родительских таблиц 
-- для реализации связи многие-ко-многим. 
-- (Вторая родительская таблица brand_models, дочерняя – cars)

create table car_shop.colors (
color_id serial2 PRIMARY KEY, /*первичный ключ с автоинкрементом*/
color_name VARCHAR(15) unique NOT NULL /*название цвета - текст с ограничением длины строки в 15 символов, должно быть уникальным и не пустым значением*/
);


--Создаём таблицу 4 - brand_models:
--Комбинация бренда и модели(ссылки), расход топлива

create table car_shop.brand_models (
brand_model_id serial2 PRIMARY KEY, /*первичный ключ с автоинкрементом*/
brand_id int2 REFERENCES car_shop.brands(brand_id), /*внешний ключ бренда, выбираем самый узкий диапозон, тк количество брендов в схеме меньше 10*/
--model_id int2 REFERENCES car_shop.models(model_id), /*внешний ключ модели, int2 вполне достаточно*/
model_name VARCHAR(15) unique NOT null, /в названии модели могут быть и цифры, и буквы, поэтому выбираем varchar с ограничением длины строки в 15 символов, должно быть уникальным и не пустым значением*/
gasoline_consumption numeric(3,1) /*расход топлива: обычно не превышает 100, точность в сырых данных - один знак после запятой, поэтому (3,1)*/
);

--Создаём таблицу 5 - cars:
--Полная комплектация (ссылки): бренд+модель и цвет. Дочерняя таблица для связи brand_models и colors. Содержит внешние ключи на эти таблицы.
create table car_shop.cars (
car_id serial2 PRIMARY KEY, /*первичный ключ с автоинкрементом*/
brand_model_id int2 REFERENCES car_shop.brand_models(brand_model_id), /*внешний ключ бренда и модели, выбираем самый узкий диапозон*/
color_id int2 REFERENCES car_shop.colors(color_id), /*внешний ключ цвета, выбираем самый узкий диапозон, всего 8 цветов*/
constraint brand_model_color_uninque unique (brand_model_id, color_id)/* не допускаем дублирования комбинаций (марка+модель)-цвет  */
);

--Создаём таблицу 6 - purchases:
--Продажи машин. Включает ссылки на полную комплектацию машины ((марка+модель)+цвет) , клиента, дату продажи, цену и скидку
create table car_shop.purchases (
sale_id serial primary key, /*первичный ключ с автоинкрементом*/
car_id int2 REFERENCES car_shop.cars(car_id), /*внешний ключ - id машины, int2 достаточно, комбинаций марка-модель-цвет пока всего 158 и сильно расти это не будте*/
client_id int4 REFERENCES car_shop.clients(client_id), /*внешний ключ - id клиента*/
price NUMERIC(9,2) CHECK(price > 0) NOT NULL, /*цена: целое число с общим количеством значимых цифр 9, и количеством значимых цифр после десятичной точки 2 (цена может содержать только сотые и всегда меньше 10 000 000 руб.), должно быть не пустым значением*/
discount INT2, /*поскольку значение скидки от 0 до 20, достаточно smallint*/
sale_data DATE NOT NULL /*дата покупки: используем тип данных дата без времени, должно быть не пустым значением*/
);
--Возможно, есть смысл вынести список продаж со скидкой в отдельную таблицу, поскольку 85% продаж было без скидки.

--2.2 Заполнение БД

--1. Клиенты:Имя, Фамилия, телефон    clients
INSERT INTO car_shop.clients (first_name, last_name, phone)
SELECT DISTINCT ON (phone) 
	split_part(person_name,' ', -2) first_name, 
	split_part(person_name,' ', -1) last_name,
	phone phone
from raw_data.sales ON CONFLICT DO NOTHING;


--2. Бренд: название и страна происхождения    brands
insert INTO car_shop.brands (brand_name, brand_origin)
SELECT DISTINCT ON (split_part(split_part(auto,', ', 1),' ',1)) 
	split_part(split_part(auto,', ', 1),' ',1) brand_name,
	brand_origin brand_origin
from raw_data.sales;



--3. Цвета  colors
insert INTO car_shop.colors (color_name)
SELECT DISTINCT ON (split_part(s.auto,', ', 2))
	split_part(s.auto,', ', 2) color_name,
from raw_data.sales s  ON CONFLICT DO NOTHING;




--4. Комбинация бренда и модели(ссылки), расход топлива   brand_models

insert INTO car_shop.brand_models (brand_id, model_name, gasoline_consumption)
select DISTINCT ON (split_part(s.auto,', ', 1))
	b.brand_id brand_id,
	--m.model_id mode_id,
	substr(s.auto,strpos(s.auto,' '),strpos(s.auto,',')-strpos(s.auto,' ')) model_name, 
	gasoline_consumption gasoline_consumption
from raw_data.sales s 
--join car_shop.models m on (m.model_name = substr(s.auto,strpos(s.auto,' '),strpos(s.auto,',')-strpos(s.auto,' ')))
join car_shop.brands b on (b.brand_name = split_part(split_part(s.auto,', ', 1),' ',1));



--5. Комбинация (бренд, модель) и цвета (ссылки)   cars
insert INTO car_shop.cars (brand_model_id, color_id)
select DISTINCT ON (auto)
	bm.brand_model_id brand_model_id,
	c.color_id color_id
from raw_data.sales s
join car_shop.brands b on (b.brand_name = split_part(split_part(s.auto,', ', 1),' ',1))--by brand_name
join car_shop.brand_models bm on 
		(bm.brand_id = b.brand_id 
		and bm.model_name = substr(s.auto,strpos(s.auto,' '),strpos(s.auto,',')-strpos(s.auto,' ')))--byymodel_name
join car_shop.colors c on (c.color_name = split_part(s.auto,', ', 2));




-- 6. Финальная таблица - продажи. purchases
-- Комбинация (бренд, модель) и цвета (ссылки)   cars
insert INTO car_shop.purchases (car_id, client_id, price, discount, sale_data)
select DISTINCT ON (id)
	cr.car_id     car_id,
	cl.client_id  client_id,
	price      price,
	discount   discount,
	date 	   sale_data
from raw_data.sales s
join car_shop.brands b on (b.brand_name = split_part(split_part(s.auto,', ', 1),' ',1))--by brand_name
join car_shop.brand_models bm on 
		(bm.brand_id = b.brand_id 
		and bm.model_name = substr(s.auto,strpos(s.auto,' '),strpos(s.auto,',')-strpos(s.auto,' ')))--by model_name
join car_shop.colors c on (c.color_name = split_part(s.auto,', ', 2))
join car_shop.cars cr on (cr.brand_model_id = bm.brand_model_id)
join car_shop.clients cl on (split_part(person_name,' ', -2) = cl.first_name 
							 and split_part(person_name,' ', -1) = cl.last_name);



--Этап 2. СОЗДАНИЕ ВЫБОРОК

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

select 
	COUNT(*) as nulls_percentage_gasoline_consumption
from car_shop.purchases p
left join car_shop.cars c on (c.car_id=p.car_id)
left join car_shop.brand_models bm on (bm.brand_model_id = c.brand_model_id)
where  bm.gasoline_consumption is null;


---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

select 
b.brand_name as brand_name,	
EXTRACT(YEAR FROM sale_data) as year,
ROUND(AVG(price),2) price_avg
from car_shop.purchases p
left join car_shop.cars c on (c.car_id=p.car_id)
left join car_shop.brand_models bm on (bm.brand_model_id = c.brand_model_id)
left join car_shop.brands b on (b.brand_id = bm.brand_id)
group by (brand_name, year)
order by brand_name, year;


---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

select 
EXTRACT(MONTH FROM sale_data) as month,
EXTRACT(YEAR FROM sale_data) as year,
ROUND(AVG(price),2) as price_avg
from car_shop.purchases p
left join car_shop.cars c on (c.car_id=p.car_id)
left join car_shop.brand_models bm on (bm.brand_model_id = c.brand_model_id)
left join car_shop.brands b on (b.brand_id = bm.brand_id)
where EXTRACT(YEAR FROM sale_data)=2022
group by month, year
order by month;



---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

select 
cl.first_name||' '||cl.last_name person,	
string_agg((b.brand_name||' '||bm.model_name),', ') cars
from car_shop.purchases p
left join car_shop.cars c on (c.car_id=p.car_id)
left join car_shop.brand_models bm on (bm.brand_model_id = c.brand_model_id)
left join car_shop.brands b on (b.brand_id = bm.brand_id)
left join car_shop.clients cl on (cl.client_id = p.client_id)
group by (person)
order by person;



---- Задание 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.

select 
b.brand_origin brand_origin,	
ROUND(max(p.price/((100.-discount)/100.)),2)  price_max,
ROUND(min(p.price/((100.-discount)/100.)),2) price_min
from car_shop.purchases p
join car_shop.cars c on (c.car_id=p.car_id)
join car_shop.brand_models bm on (bm.brand_model_id = c.brand_model_id)
join car_shop.brands b on (b.brand_id = bm.brand_id)
where b.brand_origin is not null
group by (brand_origin);


---- Задание 6. Напишите запрос, который покажет количество всех пользователей из США.
select 
count(phone) persons_from_usa_count
from car_shop.clients cl
where substring(cl.phone,1,2)='+1';





