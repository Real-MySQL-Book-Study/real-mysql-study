-- hospital_user에게 모니터링 권한 부여
GRANT PROCESS ON *.* TO 'hospital_user'@'%';
GRANT PROCESS ON *.* TO 'hospital_user'@'localhost';
GRANT SELECT ON performance_schema.* TO 'hospital_user'@'%';
GRANT SELECT ON performance_schema.* TO 'hospital_user'@'localhost';
GRANT SELECT ON information_schema.* TO 'hospital_user'@'%';
GRANT SELECT ON information_schema.* TO 'hospital_user'@'localhost';

-- 슬로우 쿼리 조회 권한
GRANT SELECT ON mysql.slow_log TO 'hospital_user'@'%';
GRANT SELECT ON mysql.slow_log TO 'hospital_user'@'localhost';

FLUSH PRIVILEGES;