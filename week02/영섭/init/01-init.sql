-- 데이터베이스 및 테이블 초기화 스크립트

USE hospital;

-- 검진 예약 테이블
CREATE TABLE IF NOT EXISTS reservations (
                                            id BIGINT PRIMARY KEY AUTO_INCREMENT,
                                            user_id BIGINT NOT NULL,
                                            exam_date DATE NOT NULL,
                                            exam_type VARCHAR(50) NOT NULL,
    hospital_code VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'CONFIRMED',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    cancelled_at DATETIME DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 초기 샘플 데이터 (소량)
INSERT INTO reservations (user_id, exam_date, exam_type, hospital_code, status) VALUES
                                                                                    (1001, '2024-12-20', '종합검진', 'H001', 'CONFIRMED'),
                                                                                    (1002, '2024-12-20', '종합검진', 'H001', 'CONFIRMED'),
                                                                                    (1003, '2024-12-21', '암검진', 'H001', 'CONFIRMED'),
                                                                                    (1004, '2024-12-21', '종합검진', 'H002', 'CONFIRMED'),
                                                                                    (1005, '2024-12-22', '뇌검진', 'H001', 'CONFIRMED');

-- 락 모니터링용 뷰 (시스템 변수 제거)
CREATE OR REPLACE VIEW v_lock_status AS
SELECT
    l.ENGINE_TRANSACTION_ID as trx_id,
    l.OBJECT_NAME as table_name,
    l.INDEX_NAME as index_name,
    l.LOCK_TYPE as lock_type,
    l.LOCK_MODE as lock_mode,
    l.LOCK_STATUS as lock_status,
    l.LOCK_DATA as lock_data,
    t.trx_mysql_thread_id as thread_id,
    t.trx_query as query_text
FROM performance_schema.data_locks l
         LEFT JOIN information_schema.INNODB_TRX t
                   ON l.ENGINE_TRANSACTION_ID = t.trx_id
WHERE l.OBJECT_SCHEMA = 'hospital'
ORDER BY l.ENGINE_TRANSACTION_ID;

-- 트랜잭션 모니터링용 뷰
CREATE OR REPLACE VIEW v_active_transactions AS
SELECT
    trx_id,
    trx_state,
    trx_started,
    trx_mysql_thread_id as thread_id,
    trx_query as current_query,
    trx_rows_locked as rows_locked,
    trx_rows_modified as rows_modified,
    TIMESTAMPDIFF(SECOND, trx_started, NOW()) as duration_sec
FROM information_schema.INNODB_TRX
ORDER BY trx_started;

COMMIT;