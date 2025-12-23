-- 성능 비교 테스트
USE hospital;

-- 1. 인덱스 없음
ALTER TABLE reservations DROP INDEX IF EXISTS idx_exam_date;
ALTER TABLE reservations DROP INDEX IF EXISTS idx_exam_date_user;

SET @start_time = NOW(6);
UPDATE reservations
SET status = 'CANCELLED'
WHERE exam_date = '2024-12-20' AND user_id = 1001;
SET @end_time = NOW(6);
SELECT TIMESTAMPDIFF(MICROSECOND, @start_time, @end_time) / 1000 as 'No Index (ms)';

-- 2. 단일 인덱스
CREATE INDEX idx_exam_date ON reservations(exam_date);
ANALYZE TABLE reservations;

SET @start_time = NOW(6);
UPDATE reservations
SET status = 'CONFIRMED'
WHERE exam_date = '2024-12-20' AND user_id = 1001;
SET @end_time = NOW(6);
SELECT TIMESTAMPDIFF(MICROSECOND, @start_time, @end_time) / 1000 as 'Single Index (ms)';

-- 3. 복합 인덱스
ALTER TABLE reservations DROP INDEX idx_exam_date;
CREATE INDEX idx_exam_date_user ON reservations(exam_date, user_id);
ANALYZE TABLE reservations;

SET @start_time = NOW(6);
UPDATE reservations
SET status = 'CANCELLED'
WHERE exam_date = '2024-12-20' AND user_id = 1001;
SET @end_time = NOW(6);
SELECT TIMESTAMPDIFF(MICROSECOND, @start_time, @end_time) / 1000 as 'Composite Index (ms)';