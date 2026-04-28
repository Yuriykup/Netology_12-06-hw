-- Файл инициализации слейва slave.sql:

-- изменяем источник полученяи данных журнала, в версиях до MySQL 8.0.23 (CHANGE MASTER TO)
CHANGE REPLICATION SOURCE TO
SOURCE_HOST='mysql_master', -- хост мастера
SOURCE_USER='repl', -- пользователь для репликации
SOURCE_PASSWORD='password', -- пароль пользователя для репликации
SOURCE_SSL=1; -- включаем ssl
START REPLICA; -- запускаем реплику
