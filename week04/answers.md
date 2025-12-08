# Week 4: 인덱스 (2) ⭐ - 답변

## A1. 복합 인덱스 컬럼 순서

복합 인덱스 (a, b, c) 기준:

| 쿼리 | 인덱스 사용 | 설명 |
|------|-----------|------|
| `WHERE a = 1` | ✅ 효율적 | 선행 컬럼 사용 |
| `WHERE b = 1` | ❌ 불가 | 선행 컬럼 a 누락 |
| `WHERE a = 1 AND c = 1` | ⚠️ 부분 | a만 인덱스 사용, c는 필터링 |
| `WHERE a = 1 AND b = 1 AND c = 1` | ✅ 최적 | 모든 컬럼 사용 |
| `WHERE a = 1 ORDER BY b` | ✅ 효율적 | a로 검색, b로 정렬 (추가 정렬 불필요) |
| `WHERE b = 1 ORDER BY a` | ❌ 불가 | 선행 컬럼 a 누락 |

**핵심 규칙**
- 복합 인덱스는 왼쪽부터 순서대로 사용
- 중간 컬럼 누락 시 그 이후 컬럼은 인덱스로 사용 불가

---

## A2. 복합 인덱스 설계

```sql
SELECT * FROM orders
WHERE user_id = 100
  AND status = 'completed'
ORDER BY created_at DESC
LIMIT 10;
```

**최적 인덱스**: `(user_id, status, created_at)`

**이유**
1. `user_id`: 동등 조건 (=), 가장 선택도 높음
2. `status`: 동등 조건 (=)
3. `created_at`: ORDER BY에 사용, 추가 정렬 불필요

**대안 검토**
- `(user_id, created_at, status)`: status가 범위 조건 뒤로 가서 정렬 이점 유지
- 실제 데이터 분포와 쿼리 패턴에 따라 선택

---

## A3. 커버링 인덱스

**정의**
- 쿼리에 필요한 모든 컬럼이 인덱스에 포함된 경우
- 테이블(클러스터링 인덱스) 접근 없이 인덱스만으로 결과 반환

**장점**
1. 디스크 I/O 감소 (테이블 접근 불필요)
2. 랜덤 I/O → 순차 I/O
3. 실행 계획에서 `Using index` 표시

**예시**
```sql
-- 인덱스: (user_id, status, created_at)
SELECT user_id, status, created_at
FROM orders
WHERE user_id = 100;
-- 커버링 인덱스 적용 (인덱스만으로 결과 반환)

SELECT *
FROM orders
WHERE user_id = 100;
-- 커버링 인덱스 미적용 (테이블 접근 필요)
```

---

## A4. 인덱스 조건 푸시다운 (ICP)

**정의**
- MySQL 5.6에서 도입
- 인덱스 조건을 스토리지 엔진 레벨에서 먼저 평가
- 불필요한 레코드 접근 감소

**동작 방식**

| 구분 | ICP 미적용 | ICP 적용 |
|------|----------|---------|
| 1단계 | 인덱스로 레코드 찾기 | 인덱스로 레코드 찾기 |
| 2단계 | 테이블에서 레코드 읽기 | 인덱스에서 조건 평가 |
| 3단계 | WHERE 조건 평가 | 조건 만족 시에만 테이블 접근 |

**예시**
```sql
-- 인덱스: (last_name, first_name)
SELECT * FROM employees
WHERE last_name = 'Kim' AND first_name LIKE '%min';

-- ICP 적용: first_name LIKE 조건을 인덱스 레벨에서 평가
-- 실행 계획: Using index condition
```

---

## A5. 인덱스 머지

**정의**
- 여러 인덱스를 동시에 사용하여 결과를 병합

**종류**

**1. index_merge_intersection (교집합)**
```sql
-- 인덱스: idx_a(a), idx_b(b)
SELECT * FROM t WHERE a = 1 AND b = 2;
-- 두 인덱스 결과의 교집합
```

**2. index_merge_union (합집합)**
```sql
SELECT * FROM t WHERE a = 1 OR b = 2;
-- 두 인덱스 결과의 합집합
```

**3. index_merge_sort_union (정렬 후 합집합)**
```sql
SELECT * FROM t WHERE a < 10 OR b < 20;
-- 범위 조건의 결과를 정렬 후 합집합
```

**주의**
- 인덱스 머지보다 복합 인덱스가 대체로 효율적
- 인덱스 머지가 자주 발생하면 인덱스 설계 재검토 필요

---

## A6. 인덱스 힌트

**종류**

| 힌트 | 설명 |
|------|------|
| `USE INDEX` | 해당 인덱스 사용을 권장 (강제 아님) |
| `FORCE INDEX` | 해당 인덱스 사용을 강제 |
| `IGNORE INDEX` | 해당 인덱스 사용 금지 |

**예시**
```sql
SELECT * FROM orders USE INDEX (idx_user_id)
WHERE user_id = 100;

SELECT * FROM orders FORCE INDEX (idx_created_at)
WHERE created_at > '2024-01-01';

SELECT * FROM orders IGNORE INDEX (idx_status)
WHERE status = 'pending';
```

**주의사항**
1. 데이터 분포가 변하면 힌트가 오히려 성능 저하 유발
2. 옵티마이저를 신뢰하는 것이 기본 원칙
3. 힌트 사용 시 정기적인 검토 필요
4. 가능하면 `USE INDEX`보다 `FORCE INDEX` 자제

---

## A7. 유니크 인덱스 vs 일반 인덱스

**읽기 성능**
- 거의 차이 없음
- 유니크 인덱스: 1건 찾으면 검색 종료
- 일반 인덱스: 다음 레코드까지 확인 후 종료

**쓰기 성능**
| 구분 | 유니크 인덱스 | 일반 인덱스 |
|------|-------------|------------|
| INSERT | 중복 체크 필요 | 체인지 버퍼 활용 가능 |
| 버퍼링 | 불가 | 가능 |
| 성능 | 상대적으로 느림 | 빠름 |

**권장 사항**
- 비즈니스적으로 유니크해야 하면 유니크 인덱스 사용
- 단순 성능 목적이면 일반 인덱스 사용
- 불필요한 유니크 제약은 피하기

---

## A8. 실무/면접 질문 답변

**인덱스의 단점**

1. **저장 공간 증가**
   - 각 인덱스는 별도 저장 공간 필요
   - 세컨더리 인덱스는 PK도 포함

2. **쓰기 성능 저하**
   - INSERT: 모든 인덱스에 새 키 추가
   - UPDATE: 인덱스 키 변경 시 삭제 + 삽입
   - DELETE: 모든 인덱스에서 삭제

3. **인덱스 유지 비용**
   - 더티 페이지 증가
   - 버퍼 풀 효율 감소

**적정 개수 결정 기준**

1. **쿼리 패턴 분석**
   - 자주 사용되는 WHERE, ORDER BY, GROUP BY 조건
   - 슬로우 쿼리 로그 분석

2. **읽기/쓰기 비율**
   - 읽기 위주: 인덱스 많이 생성 가능
   - 쓰기 위주: 인덱스 최소화

3. **일반적인 가이드라인**
   - 테이블당 3~5개 이내 권장
   - 사용되지 않는 인덱스는 제거
   - 복합 인덱스로 여러 쿼리 커버

4. **인덱스 사용률 모니터링**
```sql
SELECT * FROM sys.schema_unused_indexes;
SELECT * FROM sys.schema_redundant_indexes;
```
