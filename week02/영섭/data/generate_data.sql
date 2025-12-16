USE hospital;

-- 기존 데이터 삭제 (옵션)
TRUNCATE TABLE reservations;

-- 데이터 생성 프로시저
DELIMITER $$

DROP PROCEDURE IF EXISTS generate_reservation_data$$

CREATE PROCEDURE generate_reservation_data(IN total_records INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE batch_size INT DEFAULT 1000;
    DECLARE user_id_val BIGINT;
    DECLARE exam_date_val DATE;
    DECLARE exam_type_val VARCHAR(50);
    DECLARE hospital_code_val VARCHAR(20);
    DECLARE status_val VARCHAR(20);

    -- 대량 삽입 최적화
    SET autocommit = 0;

    WHILE i < total_records DO
        -- 랜덤 데이터 생성
        SET user_id_val = 1000 + FLOOR(RAND() * 10000);
        SET exam_date_val = DATE_ADD('2024-12-01', INTERVAL FLOOR(RAND() * 90) DAY);
        SET exam_type_val = ELT(FLOOR(1 + RAND() * 5),
            '종합검진', '암검진', '뇌검진', '심장검진', '위내시경');
        SET hospital_code_val = CONCAT('H', LPAD(FLOOR(1 + RAND() * 5), 3, '0'));
        SET status_val = IF(RAND() > 0.1, 'CONFIRMED', 'CANCELLED');

INSERT INTO reservations (user_id, exam_date, exam_type, hospital_code, status)
VALUES (user_id_val, exam_date_val, exam_type_val, hospital_code_val, status_val);

SET i = i + 1;

        -- 배치마다 커밋
        IF i % batch_size = 0 THEN
            COMMIT;
SELECT CONCAT('Inserted ', i, ' / ', total_records, ' records...') AS progress;
END IF;
END WHILE;

COMMIT;
SET autocommit = 1;

SELECT CONCAT('✅ Total ', total_records, ' records inserted successfully!') AS result;
END$$

DELIMITER ;

-- 10만 건 생성 실행
CALL generate_reservation_data(100000);

-- 결과 확인
SELECT COUNT(*) as total_count FROM reservations;
SELECT exam_date, COUNT(*) as count
FROM reservations
GROUP BY exam_date
ORDER BY exam_date
    LIMIT 10;