-- ===========================================
-- 실습 3: 복합 인덱스로 락 범위 최소화
-- ===========================================

USE hospital;

-- ===========================================
-- 준비: 복합 인덱스 생성
-- ===========================================

-- 현재 상태 확인
SHOW INDEX FROM reservations;

-- 기존 단일 인덱스 삭제
DROP INDEX idx_exam_date ON reservations;

-- 복합 인덱스 생성 (exam_date, user_id)
CREATE INDEX idx_exam_date_user
    ON reservations(exam_date, user_id);

-- 인덱스 확인
SHOW INDEX FROM reservations;
/*
+--------------+--------------------+--------------+--------------+
| Table        | Key_name           | Seq_in_index | Column_name  |
+--------------+--------------------+--------------+--------------+
| reservations | PRIMARY            |            1 | id           |
| reservations | idx_exam_date_user |            1 | exam_date    | 👈
| reservations | idx_exam_date_user |            2 | user_id      | 👈 복합!
+--------------+--------------------+--------------+--------------+
*/

-- 통계 업데이트
ANALYZE TABLE reservations;


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
+----+------+--------------+--------------------+------+-------+
| id | type | table        | key                | rows | Extra |
+----+------+--------------+--------------------+------+-------+
|  1 | ref  | reservations | idx_exam_date_user | 1    | NULL  |
+----+------+--------------+--------------------+------+-------+

🎉 type: ref (동등 조건 검색, range보다 효율적!)
🎉 key: idx_exam_date_user (복합 인덱스 사용!)
🎉 rows: 1 (정확히 1개 레코드만!)
*/

-- UPDATE로도 확인
EXPLAIN
UPDATE reservations
SET status = 'CANCELLED'
WHERE exam_date = '2024-12-20'
  AND user_id = 1001;

/*
type: ref
key: idx_exam_date_user
rows: 1
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

-- ⏸️ 대기


-- ===========================================
-- [터미널 2] 같은 날짜 다른 사용자
-- ===========================================

SELECT CONNECTION_ID() as my_session_id;

START TRANSACTION;

-- 같은 날짜(2024-12-20), 다른 사용자(2002)
SELECT * FROM reservations
WHERE exam_date = '2024-12-20'
  AND user_id = 2002
    FOR UPDATE;

-- ✅ 즉시 실행됨!
-- 🎉 복합 인덱스 덕분에 다른 user_id는 블로킹 안 됨!


-- ===========================================
-- [터미널 3] 다른 날짜
-- ===========================================

START TRANSACTION;

-- 다른 날짜
SELECT * FROM reservations
WHERE exam_date = '2024-12-25'
  AND user_id = 3001
    FOR UPDATE;

-- ✅ 당연히 즉시 실행됨


-- ===========================================
-- [터미널 4] 동일한 레코드 시도
-- ===========================================

START TRANSACTION;

-- 완전히 같은 조건 (exam_date = 2024-12-20, user_id = 1001)
SELECT * FROM reservations
WHERE exam_date = '2024-12-20'
  AND user_id = 1001
    FOR UPDATE;

-- ⏳ 대기 발생!
-- 💡 같은 레코드는 당연히 블로킹


-- ===========================================
-- [터미널 5] 락 모니터링
-- ===========================================

-- 락 상태 상세 확인
SELECT 
    INDEX_NAME,
    LOCK_TYPE,
    LOCK_MODE,
    LOCK_DATA,
    ENGINE_TRANSACTION_ID
FROM performance_schema.data_locks
WHERE OBJECT_SCHEMA = 'hospital'
  AND OBJECT_NAME = 'reservations'
ORDER BY INDEX_NAME, LOCK_DATA;

/*
예상 결과:
+--------------------+-----------+-----------+---------------------------+
| INDEX_NAME         | LOCK_TYPE | LOCK_MODE | LOCK_DATA                 |
+--------------------+-----------+-----------+---------------------------+
| idx_exam_date_user | RECORD    | X         | '2024-12-20', 1001, 12345 | 👈 정확히 1개!
| PRIMARY            | RECORD    | X         | 12345                     | 👈 실제 레코드
+--------------------+-----------+-----------+---------------------------+

딱 2개의 락만!
*/

-- 잠긴 레코드 통계
SELECT
    OBJECT_NAME,
    INDEX_NAME,
    COUNT(*) as lock_count
FROM performance_schema.data_locks
WHERE OBJECT_SCHEMA = 'hospital'
GROUP BY OBJECT_NAME, INDEX_NAME;

/*
+---------------+--------------------+------------+
| OBJECT_NAME   | INDEX_NAME         | lock_count |
+---------------+--------------------+------------+
| reservations  | idx_exam_date_user | 1          | 👈 복합 인덱스 1개
| reservations  | PRIMARY            | 1          | 👈 실제 레코드 1개
+---------------+--------------------+------------+
*/

-- InnoDB 상태
SHOW ENGINE INNODB STATUS\G

/*
주목:
- "1 row lock(s)" → 최소!
- "index idx_exam_date_user" → 복합 인덱스
*/


-- ===========================================
-- [정리]
-- ===========================================

COMMIT;  -- 모든 터미널에서


-- ===========================================
-- 📊 최종 비교
-- ===========================================

/*
┌─────────────────┬──────────────┬──────────────┬──────────────┐
│  구분           │ 인덱스 없음  │ 단일 인덱스  │ 복합 인덱스  │
├─────────────────┼──────────────┼──────────────┼──────────────┤
│ EXPLAIN type    │ ALL          │ range        │ ref          │
│ 사용 인덱스     │ NULL         │ idx_exam_date│ idx_exam_~   │
│ 스캔 레코드     │ 100,000      │ 1,161        │ 1            │
│ 잠긴 레코드     │ ~50,000      │ ~1,000       │ 1            │
│ 다른 날짜 접근  │ ❌ 블로킹    │ ✅ 가능      │ ✅ 가능      │
│ 같은 날짜 접근  │ ❌ 블로킹    │ ❌ 블로킹    │ ✅ 가능      │
│ 동시성          │ ⭐           │ ⭐⭐⭐       │ ⭐⭐⭐⭐⭐   │
│ 효율성          │ 0.001%       │ 0.1%         │ 100%         │
└─────────────────┴──────────────┴──────────────┴──────────────┘

Real MySQL 5장 핵심:
"InnoDB는 인덱스를 잠근다"
- 인덱스 없음: 전체 레코드 스캔 → 전체 잠금
- 단일 인덱스: 날짜 범위 스캔 → 날짜별 잠금
- 복합 인덱스: 정확한 레코드 → 최소 잠금!

WHERE 절의 모든 컬럼을 복합 인덱스로 만들면,
정확히 필요한 레코드만 잠글 수 있다!
*/


-- ===========================================
-- 💡 복합 인덱스 컬럼 순서의 중요성
-- ===========================================

-- 현재: (exam_date, user_id) ✅

-- 만약 순서가 반대라면?
-- CREATE INDEX idx_wrong ON reservations(user_id, exam_date);

-- WHERE exam_date = ? 단독 사용 시
-- → 인덱스 사용 불가! (첫 번째 컬럼이 없음)

-- WHERE user_id = ? 단독 사용 시
-- → 인덱스 사용 가능

-- 💡 쿼리 패턴에 맞춰 인덱스 순서 결정!
-- 우리 쿼리: WHERE exam_date = ? AND user_id = ?
-- → (exam_date, user_id) 순서가 적절!