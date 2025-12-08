# Week 8: SELECT 쿼리 작성 (2) - 답변

## A1. GROUP BY 최적화

**인덱스 사용 조건**

1. **GROUP BY 컬럼이 인덱스 선두에 위치**
```sql
-- 인덱스: (user_id, status)
SELECT user_id, COUNT(*) FROM orders GROUP BY user_id;  -- 인덱스 사용 O
SELECT status, COUNT(*) FROM orders GROUP BY status;     -- 인덱스 사용 X
```

2. **WHERE 조건과 GROUP BY 컬럼이 인덱스에 연속**
```sql
-- 인덱스: (status, user_id)
SELECT user_id, COUNT(*)
FROM orders
WHERE status = 'completed'
GROUP BY user_id;  -- 인덱스 사용 O
```

3. **루스 인덱스 스캔 (Loose Index Scan)**
```sql
-- 인덱스: (dept_id, salary)
SELECT dept_id, MAX(salary)
FROM employees
GROUP BY dept_id;
-- MIN/MAX만 조회 시 인덱스 스킵 스캔 가능
```

**인덱스 사용 불가 케이스**
- GROUP BY 컬럼에 함수 적용
- 인덱스 컬럼 순서와 불일치
- 집계 함수가 복잡한 경우

---

## A2. ORDER BY 최적화

```sql
SELECT * FROM orders
WHERE user_id = 100
ORDER BY created_at DESC, id DESC;
```

**필요한 인덱스**: `(user_id, created_at DESC, id DESC)`

**이유**
1. WHERE user_id = 100 → 동등 조건
2. ORDER BY created_at DESC, id DESC → 정렬 순서
3. 인덱스로 정렬된 상태로 읽으면 filesort 불필요

**MySQL 8.0 내림차순 인덱스**
```sql
CREATE INDEX idx_order ON orders(user_id, created_at DESC, id DESC);
```

**주의사항**
- 정렬 방향이 혼합되면 별도 인덱스 필요
- ASC/DESC 혼합 시 MySQL 8.0 이전은 filesort 발생

---

## A3. GROUP BY + ORDER BY

```sql
SELECT user_id, COUNT(*) as cnt
FROM orders
GROUP BY user_id
ORDER BY user_id;
```

**filesort 없이 실행되는 조건**

1. **GROUP BY와 ORDER BY 컬럼 동일**
   - 위 쿼리는 둘 다 user_id → 추가 정렬 불필요

2. **인덱스가 GROUP BY 컬럼 커버**
```sql
CREATE INDEX idx_user_id ON orders(user_id);
```

3. **인덱스 정렬 순서 일치**
   - ORDER BY user_id ASC → 인덱스 순방향
   - ORDER BY user_id DESC → 인덱스 역방향 (Backward index scan)

**filesort 발생하는 경우**
```sql
SELECT user_id, COUNT(*) as cnt
FROM orders
GROUP BY user_id
ORDER BY cnt DESC;  -- 집계 결과로 정렬 → filesort 필요
```

---

## A4. DISTINCT 최적화

**DISTINCT vs GROUP BY**

| 구분 | DISTINCT | GROUP BY |
|------|----------|----------|
| 용도 | 중복 제거 | 그룹화 + 집계 |
| 집계 함수 | 불필요 | 주로 함께 사용 |
| 내부 처리 | 유사 | 유사 |

**사용 시나리오**

**DISTINCT 사용**
```sql
-- 단순 중복 제거
SELECT DISTINCT status FROM orders;
SELECT DISTINCT user_id, status FROM orders;
```

**GROUP BY 사용**
```sql
-- 집계 필요
SELECT status, COUNT(*) FROM orders GROUP BY status;
-- HAVING 조건 필요
SELECT user_id FROM orders GROUP BY user_id HAVING COUNT(*) > 5;
```

**성능 비교**
```sql
-- 동일한 결과, 유사한 성능
SELECT DISTINCT user_id FROM orders;
SELECT user_id FROM orders GROUP BY user_id;

-- 실행 계획에서 둘 다 인덱스 사용 가능
```

---

## A5. 윈도우 함수 기본

**예시 데이터**
| name | score |
|------|-------|
| A | 100 |
| B | 90 |
| C | 90 |
| D | 80 |

**함수별 결과**

```sql
SELECT name, score,
  ROW_NUMBER() OVER (ORDER BY score DESC) as row_num,
  RANK() OVER (ORDER BY score DESC) as rank_val,
  DENSE_RANK() OVER (ORDER BY score DESC) as dense_rank_val
FROM students;
```

| name | score | ROW_NUMBER | RANK | DENSE_RANK |
|------|-------|------------|------|------------|
| A | 100 | 1 | 1 | 1 |
| B | 90 | 2 | 2 | 2 |
| C | 90 | 3 | 2 | 2 |
| D | 80 | 4 | 4 | 3 |

**차이점**
- **ROW_NUMBER**: 순차 번호 (중복 없음)
- **RANK**: 동일 값은 같은 순위, 다음 순위 건너뜀
- **DENSE_RANK**: 동일 값은 같은 순위, 다음 순위 연속

---

## A6. 윈도우 함수 활용

**"각 사용자별로 최근 주문 3건만 조회"**

```sql
WITH ranked_orders AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY user_id
      ORDER BY created_at DESC
    ) as rn
  FROM orders
)
SELECT *
FROM ranked_orders
WHERE rn <= 3;
```

**또는 LATERAL JOIN (MySQL 8.0.14+)**
```sql
SELECT o.*
FROM (SELECT DISTINCT user_id FROM orders) u
JOIN LATERAL (
  SELECT * FROM orders
  WHERE user_id = u.user_id
  ORDER BY created_at DESC
  LIMIT 3
) o ON TRUE;
```

**성능 고려**
- 인덱스: `(user_id, created_at DESC)`
- 대용량 테이블은 LATERAL JOIN이 효율적

---

## A7. PARTITION BY vs GROUP BY

| 구분 | GROUP BY | PARTITION BY |
|------|----------|--------------|
| 결과 행 수 | 그룹당 1행 | 원본 행 유지 |
| 집계 방식 | 행 축소 | 각 행에 집계값 추가 |
| 상세 데이터 | 접근 불가 | 접근 가능 |

**예시**

```sql
-- GROUP BY: 그룹당 1행
SELECT user_id, SUM(amount)
FROM orders
GROUP BY user_id;
-- 결과: user_id별 1행

-- PARTITION BY: 모든 행 유지
SELECT user_id, amount,
  SUM(amount) OVER (PARTITION BY user_id) as user_total
FROM orders;
-- 결과: 모든 주문 행 + 사용자별 합계 컬럼
```

**활용 사례**

```sql
-- 각 주문의 사용자 전체 주문 대비 비율
SELECT
  order_id,
  user_id,
  amount,
  amount / SUM(amount) OVER (PARTITION BY user_id) * 100 as percentage
FROM orders;
```

---

## A8. 실무/면접 질문 답변

**OFFSET 방식**
```sql
SELECT * FROM orders ORDER BY id LIMIT 10 OFFSET 1000;
```

| 장점 | 단점 |
|------|------|
| 구현 간단 | OFFSET이 커지면 느림 |
| 페이지 번호 지원 | 데이터 변경 시 중복/누락 |
| 직관적 | 1000번째부터 읽고 버림 |

**커서 기반 방식**
```sql
SELECT * FROM orders WHERE id > 1000 ORDER BY id LIMIT 10;
```

| 장점 | 단점 |
|------|------|
| 일관된 성능 | 구현 복잡 |
| 데이터 변경에 강함 | 페이지 번호 지원 어려움 |
| 인덱스 효율적 사용 | 이전 페이지 이동 어려움 |

**성능 비교**

```sql
-- OFFSET 방식: 100만번째 페이지
SELECT * FROM orders ORDER BY id LIMIT 10 OFFSET 10000000;
-- 10000010개 행 읽고 10개만 반환 → 매우 느림

-- 커서 방식: 마지막 id 이후
SELECT * FROM orders WHERE id > 10000000 ORDER BY id LIMIT 10;
-- 인덱스로 바로 접근 → 빠름
```

**권장 사항**
- 적은 데이터: OFFSET 방식 OK
- 대용량 데이터: 커서 기반 방식
- 무한 스크롤: 커서 기반 필수
- 페이지 점프 필요: 하이브리드 (OFFSET + 커서)

**하이브리드 예시**
```sql
-- 1~100 페이지: 직접 계산
-- 101+ 페이지: 100페이지 기준점에서 커서 방식
```
