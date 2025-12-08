# Week 9: INSERT/UPDATE/DELETE & DDL - 답변

## A1. INSERT 최적화

**1. 벌크 INSERT 사용**
```sql
-- Bad: 개별 INSERT
INSERT INTO t VALUES (1, 'a');
INSERT INTO t VALUES (2, 'b');
INSERT INTO t VALUES (3, 'c');

-- Good: 벌크 INSERT
INSERT INTO t VALUES (1, 'a'), (2, 'b'), (3, 'c');
```

**2. 트랜잭션 활용**
```sql
START TRANSACTION;
INSERT INTO t VALUES (1, 'a');
INSERT INTO t VALUES (2, 'b');
-- ... 많은 INSERT
COMMIT;
```

**3. LOAD DATA 사용**
```sql
LOAD DATA INFILE '/path/to/data.csv'
INTO TABLE t
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n';
```

**4. 인덱스 비활성화 (MyISAM)**
```sql
ALTER TABLE t DISABLE KEYS;
-- INSERT ...
ALTER TABLE t ENABLE KEYS;
```

**5. 설정 조정**
```sql
SET autocommit = 0;
SET unique_checks = 0;
SET foreign_key_checks = 0;
```

**6. 정렬된 데이터 INSERT**
- PK 순서대로 INSERT → 페이지 분할 최소화

---

## A2. INSERT ... ON DUPLICATE KEY UPDATE

**동작 방식**
```sql
INSERT INTO users (id, name, visit_count)
VALUES (1, 'Kim', 1)
ON DUPLICATE KEY UPDATE visit_count = visit_count + 1;

-- id=1이 없으면: INSERT
-- id=1이 있으면: UPDATE visit_count
```

**주의사항**

1. **영향 받은 행 수**
   - INSERT: 1
   - UPDATE: 2 (기존 행 삭제 + 새 행 추가로 계산)
   - 변경 없음: 0

2. **AUTO_INCREMENT 증가**
   - UPDATE되어도 AUTO_INCREMENT 값 증가

3. **유니크 키 충돌 시**
```sql
-- 여러 유니크 키가 있을 때 첫 번째 충돌에서 UPDATE
INSERT INTO t (id, email, name)
VALUES (1, 'a@a.com', 'Kim')
ON DUPLICATE KEY UPDATE name = 'Lee';
-- id와 email 모두 유니크일 때 주의
```

4. **VALUES() 함수 (MySQL 8.0.20 이전)**
```sql
INSERT INTO t (id, val)
VALUES (1, 10)
ON DUPLICATE KEY UPDATE val = VALUES(val);

-- MySQL 8.0.20+: alias 사용 권장
INSERT INTO t (id, val)
VALUES (1, 10) AS new
ON DUPLICATE KEY UPDATE val = new.val;
```

---

## A3. REPLACE vs INSERT ... ON DUPLICATE KEY UPDATE

| 구분 | REPLACE | INSERT ... ON DUPLICATE KEY UPDATE |
|------|---------|-----------------------------------|
| 동작 | DELETE + INSERT | UPDATE |
| 트리거 | DELETE + INSERT 트리거 | UPDATE 트리거 |
| AUTO_INCREMENT | 새 값 생성 | 유지 |
| 컬럼 값 | 명시 안 하면 기본값 | 명시 안 하면 유지 |

**예시**
```sql
-- 기존 데이터: (1, 'Kim', 100)

REPLACE INTO users (id, name) VALUES (1, 'Lee');
-- 결과: (1, 'Lee', NULL) - point 컬럼 기본값

INSERT INTO users (id, name) VALUES (1, 'Lee')
ON DUPLICATE KEY UPDATE name = 'Lee';
-- 결과: (1, 'Lee', 100) - point 컬럼 유지
```

**권장**
- 대부분 `INSERT ... ON DUPLICATE KEY UPDATE` 사용
- REPLACE는 전체 행 교체가 필요할 때만

---

## A4. UPDATE 조인

```sql
UPDATE users u
JOIN (
  SELECT user_id, COUNT(*) as cnt
  FROM orders
  GROUP BY user_id
) o ON u.id = o.user_id
SET u.order_count = o.cnt;
```

**또는 서브쿼리 방식**
```sql
UPDATE users u
SET order_count = (
  SELECT COUNT(*)
  FROM orders o
  WHERE o.user_id = u.id
);
```

**성능 비교**
- JOIN 방식: 한 번에 처리, 효율적
- 서브쿼리 방식: 행마다 서브쿼리 실행, 비효율

**주의사항**
```sql
-- 주문이 없는 사용자는 업데이트 안 됨 (JOIN 방식)
-- 해결: LEFT JOIN + COALESCE
UPDATE users u
LEFT JOIN (
  SELECT user_id, COUNT(*) as cnt
  FROM orders
  GROUP BY user_id
) o ON u.id = o.user_id
SET u.order_count = COALESCE(o.cnt, 0);
```

---

## A5. DELETE와 TRUNCATE

| 구분 | DELETE | TRUNCATE |
|------|--------|----------|
| 문법 | DML | DDL |
| WHERE | 가능 | 불가 |
| 롤백 | 가능 | 불가 |
| 속도 | 느림 (행 단위) | 빠름 (테이블 재생성) |
| AUTO_INCREMENT | 유지 | 초기화 |
| 트리거 | 실행됨 | 실행 안 됨 |
| 락 | 행 락 | 테이블 락 |

**사용 시나리오**

**DELETE 사용**
```sql
-- 조건부 삭제
DELETE FROM logs WHERE created_at < '2023-01-01';
-- 트랜잭션 내 삭제
-- 트리거 필요한 경우
```

**TRUNCATE 사용**
```sql
-- 전체 데이터 삭제
TRUNCATE TABLE temp_data;
-- 테스트 데이터 초기화
-- 빠른 삭제 필요
```

---

## A6. 온라인 DDL

**ALGORITHM 옵션**

| 값 | 설명 | 테이블 복사 |
|------|------|------------|
| INSTANT | 메타데이터만 변경 | X |
| INPLACE | 원본 테이블에서 변경 | 일부 |
| COPY | 새 테이블 생성 후 복사 | O |

**LOCK 옵션**

| 값 | 설명 |
|------|------|
| NONE | 읽기/쓰기 허용 |
| SHARED | 읽기만 허용 |
| EXCLUSIVE | 읽기/쓰기 차단 |
| DEFAULT | 가능한 최소 락 |

**사용 예시**
```sql
-- 컬럼 추가 (INSTANT 가능, MySQL 8.0)
ALTER TABLE t ADD COLUMN col INT,
ALGORITHM=INSTANT, LOCK=NONE;

-- 인덱스 추가 (INPLACE)
ALTER TABLE t ADD INDEX idx_col (col),
ALGORITHM=INPLACE, LOCK=NONE;

-- 컬럼 타입 변경 (COPY 필요)
ALTER TABLE t MODIFY col VARCHAR(200),
ALGORITHM=COPY, LOCK=SHARED;
```

---

## A7. ALTER TABLE 성능

**주의사항**

1. **테이블 크기**
   - 대용량 테이블은 시간 오래 걸림
   - 디스크 공간 2배 필요할 수 있음

2. **락 시간**
   - COPY 알고리즘은 테이블 락 발생
   - 서비스 영향 고려

3. **복제 지연**
   - Primary에서 완료 후 Replica로 전파
   - 복제 지연 발생 가능

**최적화 방법**

**1. pt-online-schema-change (Percona Toolkit)**
```bash
pt-online-schema-change \
  --alter "ADD COLUMN new_col INT" \
  D=mydb,t=mytable \
  --execute
```

**2. gh-ost (GitHub)**
```bash
gh-ost \
  --database=mydb \
  --table=mytable \
  --alter="ADD COLUMN new_col INT" \
  --execute
```

**3. MySQL 8.0 INSTANT 활용**
```sql
-- 테이블 끝에 컬럼 추가
ALTER TABLE t ADD COLUMN col INT, ALGORITHM=INSTANT;
```

**4. 시간대 선택**
- 트래픽 적은 시간대
- 복제 지연 모니터링

---

## A8. 실무/면접 질문 답변

**대용량 테이블 인덱스 추가 전략**

**1. 현재 상황 파악**
```sql
-- 테이블 크기 확인
SELECT
  table_name,
  ROUND(data_length / 1024 / 1024, 2) as data_mb,
  ROUND(index_length / 1024 / 1024, 2) as index_mb,
  table_rows
FROM information_schema.tables
WHERE table_name = 'target_table';
```

**2. 온라인 DDL 가능 여부 확인**
```sql
-- MySQL 8.0: INPLACE + LOCK=NONE 가능
ALTER TABLE target_table
ADD INDEX idx_new (column_name),
ALGORITHM=INPLACE, LOCK=NONE;
```

**3. pt-online-schema-change 사용**
```bash
# 기존 테이블 복사하면서 점진적 인덱스 추가
pt-online-schema-change \
  --alter "ADD INDEX idx_new (column_name)" \
  --chunk-size=1000 \
  --max-lag=1s \
  h=localhost,D=mydb,t=target_table \
  --execute
```

**4. 모니터링**
```sql
-- 진행 상황 확인
SHOW PROCESSLIST;
-- 복제 지연 확인
SHOW SLAVE STATUS\G
```

**5. 롤백 계획**
```sql
-- 문제 발생 시 인덱스 삭제
ALTER TABLE target_table DROP INDEX idx_new;
```

**권장 절차**
1. 개발/스테이징 환경에서 테스트
2. 예상 소요 시간 측정
3. 트래픽 낮은 시간대 선택
4. pt-osc 또는 gh-ost 사용
5. 실시간 모니터링
6. 완료 후 성능 검증
