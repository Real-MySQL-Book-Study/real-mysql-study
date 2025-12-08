# Week 7: SELECT 쿼리 작성 (1) - 답변

## A1. NULL 비교

```sql
SELECT * FROM users WHERE age = NULL;
-- 결과: 항상 빈 결과 (NULL = NULL은 NULL 반환)

SELECT * FROM users WHERE age IS NULL;
-- 결과: age가 NULL인 행 반환 (올바른 방법)

SELECT * FROM users WHERE age <=> NULL;
-- 결과: age가 NULL인 행 반환 (NULL-safe 비교)
```

**설명**
- `=` 연산자는 NULL과 비교하면 항상 NULL(UNKNOWN) 반환
- `IS NULL`은 NULL 체크를 위한 전용 구문
- `<=>`는 NULL-safe 동등 비교 연산자
  - NULL <=> NULL은 TRUE
  - 값 <=> NULL은 FALSE

---

## A2. LIKE vs REGEXP

| 구분 | LIKE | REGEXP |
|------|------|--------|
| 패턴 문법 | 간단 (%, _) | 정규식 (복잡) |
| 인덱스 | 앞부분 일치 시 사용 가능 | 사용 불가 |
| 성능 | 빠름 | 느림 |
| 용도 | 단순 패턴 | 복잡한 패턴 |

**예시**
```sql
-- LIKE: 인덱스 사용 가능
SELECT * FROM users WHERE name LIKE 'Kim%';

-- LIKE: 인덱스 사용 불가
SELECT * FROM users WHERE name LIKE '%Kim';

-- REGEXP: 항상 인덱스 사용 불가
SELECT * FROM users WHERE name REGEXP '^Kim[0-9]+$';
```

**권장**
- 단순 패턴은 LIKE 사용
- 복잡한 패턴이 필요하면 REGEXP
- 성능이 중요하면 LIKE + 앞부분 일치

---

## A3. BETWEEN vs IN

```sql
-- IN: 동등 비교 여러 개
SELECT * FROM orders WHERE status IN ('pending', 'processing', 'shipped');
-- status = 'pending' OR status = 'processing' OR status = 'shipped'

-- BETWEEN: 범위 비교
SELECT * FROM orders WHERE status BETWEEN 'pending' AND 'shipped';
-- status >= 'pending' AND status <= 'shipped'
```

**차이점**
- IN: 지정한 값들만 정확히 일치
- BETWEEN: 사전순 범위의 모든 값 포함

**성능**
- 둘 다 인덱스 사용 가능
- IN: 여러 등가 비교로 최적화
- BETWEEN: 범위 스캔

**주의**
- 문자열 BETWEEN은 의도와 다른 결과 가능
- 숫자/날짜에는 BETWEEN이 적합
- 이산적인 값은 IN 사용

---

## A4. 날짜/시간 함수

| 함수 | 특징 |
|------|------|
| **NOW()** | 쿼리 시작 시점 고정, 캐싱됨 |
| **SYSDATE()** | 함수 호출 시점의 시간, 매번 다름 |
| **CURRENT_TIMESTAMP** | NOW()와 동일 (표준 SQL) |

**예시**
```sql
SELECT NOW(), SLEEP(2), NOW();
-- 결과: 같은 시간, 같은 시간 (2초 차이 없음)

SELECT SYSDATE(), SLEEP(2), SYSDATE();
-- 결과: 첫 번째 시간, 두 번째 시간 (2초 차이 있음)
```

**권장 사용**
- 일반적인 경우: `NOW()` 사용
- 실제 호출 시점 시간 필요: `SYSDATE()`
- 표준 SQL 호환: `CURRENT_TIMESTAMP`

**주의**
- SYSDATE()는 복제에서 문제 발생 가능
- 인덱스 최적화에 영향

---

## A5. 문자열 함수와 인덱스

**문제점**
```sql
SELECT * FROM users WHERE SUBSTRING(phone, 1, 3) = '010';
```
- 컬럼에 함수 적용 → 인덱스 사용 불가
- 테이블 풀 스캔 발생

**개선 방법**

**방법 1: LIKE 사용**
```sql
SELECT * FROM users WHERE phone LIKE '010%';
-- 인덱스 레인지 스캔 가능
```

**방법 2: 가상 컬럼 + 인덱스 (MySQL 5.7+)**
```sql
ALTER TABLE users ADD phone_prefix VARCHAR(3)
  GENERATED ALWAYS AS (SUBSTRING(phone, 1, 3)) VIRTUAL;
CREATE INDEX idx_phone_prefix ON users(phone_prefix);

SELECT * FROM users WHERE phone_prefix = '010';
```

**방법 3: 함수 기반 인덱스 (MySQL 8.0.13+)**
```sql
CREATE INDEX idx_phone_substr ON users((SUBSTRING(phone, 1, 3)));
```

---

## A6. 조인 알고리즘

**MySQL 8.0 조인 알고리즘**

| 알고리즘 | 조건 | 특징 |
|----------|------|------|
| **Nested Loop Join** | 인덱스 있음 | 인덱스로 효율적 검색 |
| **Hash Join** | 인덱스 없음 | 8.0.18+ 기본 |
| **Block Nested Loop** | 레거시 (8.0.20 이전) | 조인 버퍼 사용 |

**선택 기준**
1. 드리븐 테이블에 적절한 인덱스 → NLJ
2. 인덱스 없음 + 동등 조인 → Hash Join
3. 옵티마이저가 자동 선택

**Hash Join 동작**
```sql
-- 인덱스 없는 조인
SELECT * FROM t1 JOIN t2 ON t1.col = t2.col;

-- 실행 계획에서 확인
Extra: Using join buffer (hash join)
```

---

## A7. OUTER JOIN 주의사항

**문제점**
```sql
SELECT * FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE u.status = 'active';
```
- LEFT JOIN 후 WHERE에서 u.status 조건 → 매칭 안 된 NULL 행 제거
- 실질적으로 INNER JOIN과 동일

**수정 방법**

**방법 1: ON 절에 조건 추가**
```sql
SELECT * FROM orders o
LEFT JOIN users u ON o.user_id = u.id AND u.status = 'active';
-- 모든 orders 유지, active 사용자만 조인
```

**방법 2: NULL 허용 조건**
```sql
SELECT * FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE u.status = 'active' OR u.id IS NULL;
-- 매칭 안 된 orders도 포함
```

**핵심 원칙**
- OUTER JOIN의 드리븐 테이블 조건은 ON 절에
- WHERE 절 조건은 전체 결과 필터링

---

## A8. 실무/면접 질문 답변

**대용량 테이블 조인 최적화**

**1. 적절한 인덱스 설계**
```sql
-- 조인 컬럼에 인덱스
CREATE INDEX idx_user_id ON orders(user_id);

-- 복합 인덱스로 커버링
CREATE INDEX idx_covering ON orders(user_id, status, created_at);
```

**2. 조인 순서 최적화**
- 작은 결과셋이 드라이빙 테이블
- 옵티마이저에 맡기거나 STRAIGHT_JOIN

**3. 필요한 데이터만 조회**
```sql
-- Bad
SELECT * FROM orders o JOIN users u ON ...

-- Good
SELECT o.id, o.amount, u.name FROM orders o JOIN users u ON ...
```

**4. 조인 전 필터링**
```sql
-- 서브쿼리로 먼저 필터링
SELECT * FROM
  (SELECT * FROM orders WHERE created_at > '2024-01-01') o
JOIN users u ON o.user_id = u.id;
```

**5. 배치 처리**
```sql
-- 전체 조인 대신 범위별 처리
SELECT * FROM orders o JOIN users u ON o.user_id = u.id
WHERE o.id BETWEEN 1 AND 10000;
-- 다음 배치: 10001 ~ 20000
```

**6. 조인 버퍼 크기 조정**
```sql
SET join_buffer_size = 256 * 1024 * 1024;  -- 256MB
```

**7. 실행 계획 확인**
```sql
EXPLAIN ANALYZE SELECT ...
-- type, rows, Extra 컬럼 확인
-- Using join buffer (hash join) vs Nested loop
```

**8. 파티셔닝 활용**
- 조인 대상을 파티션 단위로 제한
- 파티션 프루닝으로 스캔 범위 감소
