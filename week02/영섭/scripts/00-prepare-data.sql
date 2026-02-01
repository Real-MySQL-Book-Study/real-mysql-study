USE hospital;

SELECT COUNT(*) as total_count FROM reservations;
SELECT '현재 인덱스 확인:' as step;
SHOW INDEX FROM reservations;

-- 실습용 데이터 추가
INSERT IGNORE INTO reservations (user_id, exam_date, exam_type, hospital_code, status)
VALUES
    (1001, '2024-12-20', '종합검진', 'H001', 'CONFIRMED'),
    (2002, '2024-12-20', '종합검진', 'H001', 'CONFIRMED'),
    (3003, '2024-12-20', '암검진', 'H001', 'CONFIRMED'),
    (4004, '2024-12-20', '뇌검진', 'H002', 'CONFIRMED'),
    (2001, '2024-12-25', '암검진', 'H001', 'CONFIRMED'),
    (3001, '2024-12-25', '종합검진', 'H002', 'CONFIRMED');

ANALYZE TABLE reservations;

SELECT '✅ 데이터 준비 완료!' as status;
SELECT '⚠️ 인덱스가 있다면 수동으로 삭제하세요:' as warning;
SELECT 'DROP INDEX idx_exam_date ON reservations;' as command1;
SELECT 'DROP INDEX idx_exam_date_user ON reservations;' as command2;