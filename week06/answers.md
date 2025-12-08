# Week 6: 실행 계획 ⭐ - 답변

## A1. EXPLAIN 기본

| 컬럼 | 설명 |
|------|------|
| **id** | SELECT 식별자, 쿼리 내 SELECT 순번 |
| **select_type** | SELECT 유형 (SIMPLE, PRIMARY, SUBQUERY 등) |
| **table** | 접근하는 테이블명 |
| **partitions** | 접근하는 파티션 |
| **type** | 접근 방식 (ALL, index, range, ref 등) |
| **possible_keys** | 사용 가능한 인덱스 목록 |
| **key** | 실제 사용된 인덱스 |
| **key_len** | 사용된 인덱스 길이 (바이트) |
| **ref** | 인덱스 비교에 사용된 컬럼/상수 |
| **rows** | 예상 검색 행 수 |
| **filtered** | 조건에 의해 필터링되는 비율 (%) |
| **Extra** | 추가 정보 |

---

## A2. type 컬럼

**성능 순서 (좋음 → 나쁨)**

| type | 설명 | 성능 |
|------|------|------|
| **system** | 테이블에 레코드가 1개 | 최상 |
| **const** | PK/Unique로 1건 조회 | 최상 |
| **eq_ref** | 조인에서 PK/Unique로 1건 매칭 | 매우 좋음 |
| **ref** | 인덱스로 여러 건 조회 | 좋음 |
| **range** | 인덱스 범위 스캔 | 양호 |
| **index** | 인덱스 풀 스캔 | 나쁨 |
| **ALL** | 테이블 풀 스캔 | 최악 |

**추가 type 값들**
- `fulltext`: 전문 검색 인덱스 사용
- `ref_or_null`: ref + NULL 검색
- `index_merge`: 여러 인덱스 병합
- `unique_subquery`: IN 서브쿼리 최적화
- `index_subquery`: 서브쿼리 인덱스 사용

---

## A3. key_len 분석

**계산 방법**
```
INT: 4 bytes
VARCHAR(n): n * 문자셋 바이트 + 2 bytes (길이 저장)
NULLABLE: +1 byte
```

**utf8mb4에서 VARCHAR(100)**
- 100 * 4 = 400 bytes
- 길이 저장: +2 bytes
- NULLABLE: +1 byte
- 합계: 403 bytes

**쿼리: WHERE a = 1 AND b = 'hello'**
```
a (INT, nullable): 4 + 1 = 5 bytes
b (VARCHAR(100), nullable): 400 + 2 + 1 = 403 bytes
총 key_len: 5 + 403 = 408 bytes
```

**key_len의 중요성**
- 복합 인덱스에서 실제 사용된 컬럼 수 파악 가능
- key_len이 작으면 인덱스 일부만 사용됨

---

## A4. Extra 컬럼 - 좋은 신호

| 값 | 의미 |
|------|------|
| **Using index** | 커버링 인덱스 (테이블 접근 불필요) |
| **Using index condition** | 인덱스 조건 푸시다운 (ICP) |
| **Using where; Using index** | 커버링 인덱스 + WHERE 필터링 |
| **Using index for skip scan** | 인덱스 스킵 스캔 |
| **Using MRR** | Multi-Range Read 최적화 |
| **Using join buffer (hash join)** | 해시 조인 사용 |

---

## A5. Extra 컬럼 - 나쁜 신호

| 값 | 의미 | 개선 방안 |
|------|------|----------|
| **Using filesort** | 별도 정렬 필요 | ORDER BY 인덱스 추가 |
| **Using temporary** | 임시 테이블 사용 | 쿼리 구조 개선 |
| **Using where** | 스토리지 엔진에서 필터링 못함 | 인덱스 개선 |
| **Full scan on NULL key** | NULL 비교 시 풀 스캔 | 쿼리 구조 변경 |
| **Range checked for each record** | 매 레코드마다 범위 검사 | 조인 조건 개선 |

**특히 주의할 조합**
```
Using temporary; Using filesort  -- GROUP BY + ORDER BY 최적화 필요
```

---

## A6. EXPLAIN ANALYZE

**차이점**

| 구분 | EXPLAIN | EXPLAIN ANALYZE |
|------|---------|-----------------|
| 실행 | 계획만 보여줌 | 실제 실행 후 통계 |
| 정보 | 예상 rows | 실제 rows, 실행 시간 |
| 성능 | 빠름 | 쿼리 실행 시간만큼 소요 |

**출력 해석**
```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE status = 'active';

-> Filter: (users.status = 'active')  (cost=10.5 rows=100) (actual time=0.05..1.2 rows=95 loops=1)
    -> Table scan on users  (cost=10.5 rows=1000) (actual time=0.03..0.8 rows=1000 loops=1)
```

| 항목 | 설명 |
|------|------|
| cost | 예상 비용 |
| rows (첫 번째) | 예상 행 수 |
| actual time | 실제 실행 시간 (첫 번째 행..마지막 행) |
| rows (두 번째) | 실제 반환 행 수 |
| loops | 반복 실행 횟수 |

---

## A7. 실행 계획 개선

**문제 분석**
```
type: ALL           → 테이블 풀 스캔
key: NULL           → 인덱스 미사용
rows: 100000        → 전체 테이블 스캔
Extra: Using where  → 스토리지 엔진 레벨 필터링 못함
```

**개선 방안**

1. **WHERE 조건 컬럼에 인덱스 추가**
```sql
-- 예: WHERE email = 'test@example.com' 쿼리라면
CREATE INDEX idx_email ON users(email);
```

2. **복합 조건이면 복합 인덱스 고려**
```sql
-- WHERE status = 'active' AND created_at > '2024-01-01'
CREATE INDEX idx_status_created ON users(status, created_at);
```

3. **개선 후 예상 실행 계획**
```
type: ref 또는 range
key: idx_email
rows: 1~10 (대폭 감소)
```

---

## A8. 실무/면접 질문 답변

**슬로우 쿼리 분석 및 최적화 절차**

**1단계: 슬로우 쿼리 확인**
```sql
-- 슬로우 쿼리 로그 확인
SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;

-- 또는 Performance Schema
SELECT * FROM performance_schema.events_statements_summary_by_digest
ORDER BY avg_timer_wait DESC LIMIT 10;
```

**2단계: EXPLAIN 분석**
```sql
EXPLAIN SELECT ...;
```

**체크 포인트**
| 항목 | 확인 내용 |
|------|----------|
| type | ALL, index면 개선 필요 |
| key | NULL이면 인덱스 추가 검토 |
| rows | 예상 행 수가 많으면 문제 |
| Extra | filesort, temporary 확인 |

**3단계: EXPLAIN ANALYZE로 실제 성능 확인**
```sql
EXPLAIN ANALYZE SELECT ...;
```
- 예상과 실제 rows 비교
- 실제 실행 시간 확인

**4단계: 개선 적용**
1. **인덱스 추가/수정**
2. **쿼리 리팩토링**
   - 서브쿼리 → 조인 변환
   - 불필요한 컬럼 제거
3. **조인 순서 변경** (STRAIGHT_JOIN)
4. **인덱스 힌트** (최후 수단)

**5단계: 개선 효과 검증**
```sql
-- 개선 전후 EXPLAIN 비교
-- 실제 실행 시간 측정
SET profiling = 1;
SELECT ...;
SHOW PROFILES;
```

**예시 분석**
```sql
-- 문제 쿼리
SELECT * FROM orders WHERE DATE(created_at) = '2024-01-01';
-- type: ALL (인덱스 사용 불가, 컬럼 가공)

-- 개선 쿼리
SELECT * FROM orders
WHERE created_at >= '2024-01-01' AND created_at < '2024-01-02';
-- type: range (인덱스 사용 가능)
```
