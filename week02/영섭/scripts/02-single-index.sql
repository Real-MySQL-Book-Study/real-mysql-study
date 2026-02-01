-- ===========================================
-- 실습 2: 단일 인덱스 추가 후 락 범위
-- ===========================================

USE hospital;

-- ===========================================
-- 준비: 단일 인덱스 생성
-- ===========================================

-- 현재 상태 확인
SHOW INDEX FROM reservations;

-- exam_date에 인덱스 추가
CREATE INDEX idx_exam_date ON reservations(exam_date);

-- 인덱스 생성 확인
SHOW INDEX FROM reservations;
/*
+--------------+---------------+-------------+
| Table        | Key_name      | Column_name |
+--------------+---------------+-------------+
| reservations | PRIMARY       | id          |
| reservations | idx_exam_date | exam_date   | 👈 추가됨!
+--------------+---------------+-------------+
*/

-- 통계 정보 업데이트 (중요!)
ANALYZE TABLE reservations;

-- 인덱스 통계 확인
SELECT
    INDEX_NAME,
    CARDINALITY,
    SEQ_IN_INDEX,
    COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'hospital'
  AND TABLE_NAME = 'reservations'
ORDER BY INDEX_NAME, SEQ_IN_INDEX;


-- ===========================================
-- 실행 계획 확인
-- ===========================================

-- SELECT로 확인
EXPLAIN
SELECT * FROM reservations
WHERE exam_date = '2024-12-20'
  AND user_id = 1001;

/*
예상 결과:
+----+-------+--------------+---------------+------+-------------+
| id | type  | table        | key           | rows | Extra       |
+----+-------+--------------+---------------+------+-------------+
|  1 | range | reservations | idx_exam_date | ~1161| Using where |
+----+-------+--------------+---------------+------+-------------+

✅ type: range (인덱스 범위 스캔)
✅ key: idx_exam_date (인덱스 사용!)
✅ rows: ~1161 (해당 날짜만, 100000 → 1161로 감소!)
*/

-- UPDATE로도 확인 (참고)
EXPLAIN
UPDATE reservations
SET status = 'CANCELLED'
WHERE exam_date = '2024-12-20'
  AND user_id = 1001;

/*
type: range (또는 index)
key: idx_exam_date
rows: ~1161 (획기적 개선!)
*/


-- ===========================================
-- [터미널 1] 트랜잭션 A - SELECT FOR UPDATE
-- ===========================================

SELECT CONNECTION_ID() as my_session_id;

START TRANSACTION;

-- SELECT FOR UPDATE 실행
SELECT * FROM reservations
WHERE exam_date = '2024-12-20'
  AND user_id = 1001
    FOR UPDATE;

-- ⏸️ 대기 (COMMIT 하지 않음)


-- ===========================================
-- [터미널 2] 트랜잭션 B - 다른 날짜 조회
-- ===========================================

SELECT CONNECTION_ID() as my_session_id;

START TRANSACTION;

-- 다른 날짜 조회 (2024-12-25)
SELECT * FROM reservations
WHERE exam_date = '2024-12-25'
  AND user_id = 2001
    FOR UPDATE;

-- ✅ 즉시 실행됨!
-- 💡 인덱스 덕분에 다른 날짜는 락이 안 걸림


-- ===========================================
-- [터미널 3] 같은 날짜 다른 사용자
-- ===========================================

SELECT CONNECTION_ID() as my_session_id;

START TRANSACTION;

-- 같은 날짜(2024-12-20), 다른 사용자
SELECT * FROM reservations
WHERE exam_date = '2024-12-20'
  AND user_id = 2002
    FOR UPDATE;

-- ⏳ 대기 발생!
-- 💡 같은 날짜는 여전히 블로킹됨


-- ===========================================
-- [터미널 4] 락 모니터링
-- ===========================================

-- 락 상태 확인
SELECT * FROM v_lock_status;

-- 잠긴 레코드 수와 범위 확인
SELECT 
    INDEX_NAME,
    LOCK_MODE,
    COUNT(*) as lock_count,
    MIN(LOCK_DATA) as min_lock_data,
    MAX(LOCK_DATA) as max_lock_data
FROM performance_schema.data_locks
WHERE OBJECT_SCHEMA = 'hospital'
  AND OBJECT_NAME = 'reservations'
GROUP BY INDEX_NAME, LOCK_MODE;

/*
예상 결과:
+---------------+-----------+------------+
| INDEX_NAME    | LOCK_MODE | lock_count |
+---------------+-----------+------------+
| idx_exam_date | X         | ~1000      | 👈 2024-12-20 날짜만
| PRIMARY       | X         | ~1000      |
+---------------+-----------+------------+
*/

-- InnoDB 상태
SHOW ENGINE INNODB STATUS\G

/*
주목할 부분:
- "~1000 row lock(s)" → 획기적 감소 (100000 → 1000)
- "index idx_exam_date" → 단일 인덱스 사용
*/


-- ===========================================
-- [정리] 모든 터미널
-- ===========================================

-- 각 터미널에서 COMMIT
COMMIT;


-- ===========================================
-- 📊 결과 비교
-- ===========================================

/*
개선 사항:
1. ✅ 인덱스 사용 → Range Scan
2. ✅ 해당 날짜 레코드만 스캔 (100000 → 1161)
3. ✅ 다른 날짜는 락 걸리지 않음
4. ⚠️ 같은 날짜 다른 사용자는 여전히 블로킹

┌──────────────┬────────────┬────────────┐
│ 항목         │ 인덱스없음 │ 단일인덱스 │
├──────────────┼────────────┼────────────┤
│ type         │ ALL        │ range      │
│ key          │ NULL       │ idx_exam_~ │
│ rows         │ 100,000    │ 1,161      │
│ 잠긴 레코드  │ ~50,000    │ ~1,000     │
│ 다른날짜접근 │ ❌ 블로킹  │ ✅ 가능    │
│ 같은날짜접근 │ ❌ 블로킹  │ ❌ 블로킹  │
└──────────────┴────────────┴────────────┘

Real MySQL 5장 연결:
"인덱스를 이용한 범위 스캔 시,
해당 범위의 레코드에만 넥스트 키 락이 걸린다"
*/