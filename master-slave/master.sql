-- Файл инициализации мастера master.sql:

CREATE USER 'repl'@'%' IDENTIFIED BY 'password'; -- создаём пользователя для реплики
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'; -- выдаём права для репликации новому пользователю
FLUSH PRIVILEGES; -- принудительно применяем изменения
