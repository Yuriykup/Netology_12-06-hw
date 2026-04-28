# Домашнее задание к занятию «Репликация и масштабирование. Часть 1»

---

### Задание 1

На лекции рассматривались режимы репликации master-slave, master-master, опишите их различия.

*Ответить в свободной форме.*

---
## ОТВЕТ на задание 1.


#### Master‑Slave репликация
Суть: один главный сервер (Master) и один или несколько подчинённых (Slave).

Как работает:
- Все операции записи (INSERT, UPDATE, DELETE) выполняются только на Master.
- Master записывает изменения в бинарный журнал (бинарлог / WAL).
- Slave‑серверы асинхронно (или полусинхронно) копируют и применяют эти изменения.
- Операции чтения (SELECT) могут выполняться как на Master, так и на Slave (часто чтение распределяют на Slave, чтобы разгрузить Master).

Плюсы:
- Разгрузка Master: чтение распределяется по Slave, повышая общую производительность.
- Резервирование: если Master выходит из строя, один из Slave может быть повышен до нового Master (с потерей части последних данных при асинхронной репликации).
- Масштабируемость по чтению: можно добавлять новые Slave для обслуживания растущей нагрузки на чтение.
- Аналитика и бэкапы: Slave можно использовать для ресурсоёмких отчётов или создания резервных копий без влияния на работу основного сервера.
- Простота настройки и мониторинга: архитектура относительно проста.

Минусы:
- Единая точка отказа: Master — это «бутылочное горлышко». Его отказ останавливает запись в систему.
- Ограниченная масштабируемость по записи: все записи идут через один узел.
- Задержка репликации (replication lag): данные на Slave могут отставать от Master.
- Ручное переключение при сбое: требуется вмешательство администратора или специальные механизмы (например, MHA для MySQL) для выбора нового Master.

![Скриншот-1](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img1.png)

#### Master‑Master репликация
Суть: два или более сервера, каждый из которых может принимать и операции записи, и операции чтения. Данные синхронизируются между ними.

Как работает:
- Клиент может отправлять запросы на запись на любой из Master‑серверов.
- Каждый Master записывает изменения в свой бинарный журнал.
- Серверы обмениваются журналами и применяют изменения друг друга.
- Все серверы стремятся к одинаковому состоянию данных.

Плюсы:
- Высокая отказоустойчивость: при выходе из строя одного Master другой продолжает работать с полной функциональностью.
- Балансировка нагрузки по записи: запросы на запись можно распределять между серверами.
- Географическое распределение: пользователи могут работать с ближайшим к ним сервером, уменьшая задержки.
- Отсутствие единой точки отказа: нет единственного узла, отказ которого парализует запись.

Минусы:
- Конфликты данных: главная проблема. Если два сервера одновременно изменяют одну и ту же строку, возникает конфликт. Требуется механизм разрешения (например, по временной метке, приоритету узла или пользовательской логике).
- Сложность настройки и поддержки: требуются дополнительные механизмы для обеспечения согласованности данных (например, Galera Cluster для MySQL, BDR для PostgreSQL).
- Потенциально более низкая производительность: синхронизация между узлами добавляет накладные расходы.
- Риски потери данных и рассогласования: при сбоях и конфликтах восстановление может быть сложным и требовать ручного вмешательства.
- Не всегда «истинная» Master‑Master: в некоторых реализациях (например, в классической настройке MySQL) один узел всё равно может быть «первичным», а второй — «вторичным» с ограничениями.

![Скриншот-2](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img2.png)

#### Итог.

Master‑Slave подойдет, если:
- в системе преобладают операции чтения;
- нужна простая отказоустойчивость и разгрузка основного сервера;
- не критичеа задержка репликации и единая точка отказа по записи.

Master‑Master подойдет, если:
- критически важна непрерывность операций записи при сбое узла;
- нагрузка на запись распределена между географически удалёнными точками;
- не критична дороговизна и сложность настройки и механизмов разрешения конфликтов.

---
### Задание 2

Выполните конфигурацию master-slave репликации, примером можно пользоваться из лекции.

*Приложите скриншоты конфигурации, выполнения работы: состояния и режимы работы серверов.*

---
## ОТВЕТ на задание 2.


#### 2.1 Конфигурация Master-Slave

2.1.1 Конфигурируем файл `Dockerfile_master` для Master:
```
FROM mysql:9.3
# Копируем файлы конфигурации
COPY ./master.cnf /etc/mysql/conf.d/my.cnf
COPY ./master.sql /docker-entrypoint-initdb.d/start.sql
# Переменные окружения для настройки репликации
ENV MYSQL_ROOT_PASSWORD=kuv042026
# Запускаем сервисы
CMD ["mysqld"]
```

2.1.2 Конфигурируем файл `Dockerfile_slave` для Slave:
```
FROM mysql:9.3
# Копируем файлы конфигурации
COPY ./slave.cnf /etc/mysql/conf.d/my.cnf
COPY ./slave.sql /docker-entrypoint-initdb.d/start.sql
# Переменные окружения для настройки репликации
ENV MYSQL_ROOT_PASSWORD=kuv042026
# Запускаем сервисы
CMD ["mysqld"]
```

2.1.3 Конфигурируем скрипт `master.sql` создания пользователя для репликации:
```
-- Файл инициализации мастера master.sql:

CREATE USER 'repl'@'%' IDENTIFIED BY 'password'; -- создаём пользователя для реплики
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'; -- выдаём права для репликации новому пользователю
FLUSH PRIVILEGES; -- принудительно применяем изменения
```

2.1.4 Конфигурируем скрипт `slave.sql` для подключения слейва к мастеру:
```
CHANGE REPLICATION SOURCE TO
SOURCE_HOST='mysql_master',
-- Имя хоста мастера
SOURCE_USER='repl',
-- Имя пользователя
SOURCE_PASSWORD='slavepass',
-- Пароль этого пользователя
SOURCE_SSL=1;
START REPLICA;
```

2.1.5 Создаём конфигурационный файл `master.cnf` для мастера:
```
[mysqld]
server-id = 1
log-bin = mysql-bin
binlog-format = ROW
```

2.1.6 Создаём конфигурационный файл `slave.cnf` для слейва:
```
[mysqld]
server-id = 2
read-only = 1
```

2.1.7 Собираем образы:
Сначала из двух Docker-файлов делаем готовые образы для слейва и мастера:
```
$sudo docker build -t mysql_slave -f ./Dockerfile_slave .
$sudo docker build -t mysql_master -f ./Dockerfile_master .
```

2.1.8 Создаём сеть:
```
$sudo docker network create replication .
```

2.1.9. Запускаем контейнеры:
Master и Slave подключаем к кионфиги, пробрасываем разные хост‑порты, указываем пароль и версию SQL:
```
$sudo docker run --name mysql_master -v ./master.cnf:/etc/my.cnf -p 3307:3306 -e MYSQL_ROOT_PASSWORD=kuv042026 -d mysql:8.4
$sudo docker run --name mysql_slave -v ./slave.cnf:/etc/my.cnf -p 3308:3306 -e MYSQL_ROOT_PASSWORD=kuv042026 -d mysql:8.4
```

![Скриншот-3](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img3.png)

2.1.10 Проверка кофигурационных файлов в созданых серверах:
- Master
```
$sudo docker exec -ti mysql_master /bin/bash
bash-5.1# cat /etc/my.cnf
[mysqld]
server-id=1
log-bin = mysql-bin
binlog_format=ROW

bash-5.1# exit
```
- Slave
```
$sudo docker exec -ti mysql_slave /bin/bash
bash-5.1# cat /etc/my
my.cnf    my.cnf.d/ mysql/    
bash-5.1# cat /etc/my.cnf
[mysqld]
server-id=2
read_only = 1
bash-5.1# exit
exit
```

![Скриншот-4](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img4.png)

#### 2.2 Тестирование работы в режиме Master-Slave

2.2.1 Подключаемся к Master и создаем пользователя `repl`

```
mysql> CREATE USER 'repl'@'%' IDENTIFIED BY 'password';
Query OK, 0 rows affected (0.05 sec)

mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
Query OK, 0 rows affected (0.02 sec)

mysql> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.02 sec)

mysql> exit
Bye

```
![Скриншот-5](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img5.png)

2.2.2 Проверяем специфический номер "позиции Master-server"

![Скриншот-7](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img7.png)



2.2.3 На Slave меняем источник репликации, пользователя, пароль и специфический номер "позиции Master-server"

```
mysql> CHANGE REPLICATION SOURCE TO SOURCE_HOST='mysql_master', SOURCE_USER='repl', SOURCE_PASSWORD='password', SOURCE_SSL=1, RELAY_LOG_POS=2618;
```

![Скриншот-6](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img6.png)

2.2.4 Проверяем подключение репликации Slave к Master

```
mysql> SHOW REPLICA STATUS\G
```

![Скриншот-9](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img9.png)

2.2.5 Создаём новую базу и таблицу на Master

```
DROP DATABASE IF EXISTS netology; 
CREATE database netology;
SHOW databases;
USE netology;
CREATE TABLE test_table (id INT PRIMARY KEY, name VARCHAR(50));
INSERT INTO test_table VALUES (1, 'Master Record');
```

![Скриншот-8](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img8.png)

2.2.5 Проверяем создание реплики базы данных на Slave

```
mysql> SHOW databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| netology           |
| performance_schema |
| sys                |
+--------------------+
5 rows in set (0.00 sec)
```

![Скриншот-10](https://github.com/Yuriykup/Netology_12-06-hw/blob/main/img/img10.png)







