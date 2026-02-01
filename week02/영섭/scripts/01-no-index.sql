-- ===========================================
-- 실습 1: 인덱스 없을 때의 락 범위
-- ===========================================

USE hospital;

-- 사전 준비
-- 인덱스 확인 (PRIMARY만 있어야 함)
SHOW INDEX FROM reservations;

-- 데이터 확인
SELECT COUNT(*) as total_count FROM reservations;
SELECT COUNT(*) as target_date_count
FROM reservations
WHERE exam_date = '2024-12-20';

-- ===========================================
-- 실행 계획 확인
-- ===========================================

-- SELECT로 확인 (더 명확함)
EXPLAIN
SELECT * FROM reservations
WHERE exam_date = '2024-12-20'
  AND user_id = 1001;

/*
예상 결과:
+----+------+--------------+------+------+--------+-------------+
| id | type | table        | key  | rows | Extra       |
+----+------+--------------+------+------+--------+-------------+
|  1 | ALL  | reservations | NULL | ~100k| Using where |
+----+------+--------------+------+------+--------+-------------+

✅ type: ALL (테이블 풀 스캔)
✅ key: NULL (인덱스 미사용)
✅ rows: ~100000 (전체 스캔)
*/

-- UPDATE로도 확인 (참고용)
EXPLAIN
UPDATE reservations
SET status = 'CANCELLED'
WHERE exam_date = '2024-12-20'
  AND user_id = 1001;

/*
결과:
type: index (PRIMARY KEY 인덱스 스캔)
key: PRIMARY
rows: ~100000 (여전히 전체 스캔!)

💡 type은 다르지만 rows가 많으면 동일하게 비효율적
*/


-- ===========================================
-- [터미널 1] 트랜잭션 A - SELECT FOR UPDATE
-- ===========================================

-- 세션 ID 확인
SELECT CONNECTION_ID() as my_session_id;

START TRANSACTION;

-- SELECT FOR UPDATE 사용 (UPDATE 대신)
SELECT * FROM reservations
WHERE exam_date = '2024-12-20'
  AND user_id = 1001
    FOR UPDATE;

-- ⏸️ 여기서 대기 (COMMIT 하지 않음)


-- ===========================================
-- [터미널 2] 트랜잭션 B - 다른 날짜 조회
-- ===========================================

SELECT CONNECTION_ID() as my_session_id;

START TRANSACTION;

-- 다른 날짜 조회 시도
SELECT * FROM reservations
WHERE exam_date = '2024-12-25'
  AND user_id = 2001
    FOR UPDATE;

-- ⏳ 대기 발생!
-- 💡 다른 날짜인데도 락 때문에 대기


-- ===========================================
-- [터미널 3] 락 상태 모니터링
-- ===========================================

-- 활성 트랜잭션 확인
SELECT * FROM v_active_transactions;

-- 락 상태 확인
SELECT * FROM v_lock_status;

-- 락 대기 상황 확인
SELECT 
    OBJECT_NAME,
    INDEX_NAME,
    LOCK_TYPE,
    LOCK_MODE,
    COUNT(*) as lock_count
FROM performance_schema.data_locks
WHERE OBJECT_SCHEMA = 'hospital'
GROUP BY OBJECT_NAME, INDEX_NAME, LOCK_TYPE, LOCK_MODE;

-- InnoDB 상태 확인
SHOW ENGINE INNODB STATUS\G

/*
주목할 부분:
- "N row lock(s)" → 많은 수의 레코드 락
- "lock_mode X" → 배타 락
- "index PRIMARY" → PRIMARY KEY 전체 스캔
*/


-- ===========================================
-- [정리] 모든 터미널
-- ===========================================

-- 각 터미널에서 COMMIT
COMMIT;


-- ===========================================
-- 📊 결과 분석
-- ===========================================

/*
문제점:
1. ❌ 인덱스 없음 → 전체 레코드 스캔
2. ❌ 전체 스캔 → 모든 레코드에 락
3. ❌ 다른 날짜 조회도 블로킹
4. ❌ 시스템 전체 동시성 저하

EXPLAIN 결과:
- SELECT: type = ALL (명확한 풀 스캔)
- UPDATE: type = index (인덱스 통한 풀 스캔)
- 둘 다 rows ~ 100000 → 비효율적

Real MySQL 5장 핵심:
"InnoDB는 인덱스를 통해 검색한 레코드에 잠금을 건다"
→ 인덱스가 없으면 전체를 스캔하고, 전체에 락을 건다!
*/