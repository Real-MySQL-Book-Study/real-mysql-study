# Week 5: 옵티마이저 - 답변

## A1. 쿼리 실행 절차

**1단계: SQL 파싱 (Parsing)**
- SQL 문법 검사
- 파스 트리(Parse Tree) 생성

**2단계: 최적화 (Optimization)**
- 옵티마이저가 실행 계획 수립
- 가장 효율적인 방법 선택
- 인덱스 선택, 조인 순서 결정

**3단계: 실행 (Execution)**
- 실행 계획에 따라 스토리지 엔진에 요청
- 결과 반환

```
SQL 문장 → 파서 → 전처리기 → 옵티마이저 → 실행 엔진 → 스토리지 엔진
```

---

## A2. 옵티마이저의 역할

**역할**
- 가장 효율적인 쿼리 실행 방법 결정
- 여러 가능한 실행 계획 중 최적의 계획 선택

**선택 기준**
1. **비용(Cost)** 기반
   - 디스크 I/O 횟수
   - CPU 연산량
   - 메모리 사용량

2. **통계 정보** 활용
   - 테이블 레코드 수
   - 인덱스 카디널리티
   - 데이터 분포

**MySQL 옵티마이저 특징**
- 비용 기반 옵티마이저 (CBO)
- 통계 정보를 기반으로 비용 계산
- 항상 최적의 선택을 하지는 않음 (힌트로 보완)

---

## A3. 비용 기반 최적화

**고려 요소**

| 요소 | 설명 |
|------|------|
| 테이블 크기 | 전체 레코드 수 |
| 인덱스 통계 | 카디널리티, 선택도 |
| I/O 비용 | 디스크 읽기 횟수 |
| CPU 비용 | 비교, 정렬 연산 |
| 메모리 비용 | 임시 테이블, 정렬 버퍼 |

**통계 정보 수집**
```sql
-- 통계 정보 갱신
ANALYZE TABLE table_name;

-- 통계 정보 확인
SHOW INDEX FROM table_name;
SELECT * FROM mysql.innodb_table_stats;
```

**한계**
- 통계 정보가 부정확할 수 있음
- 실제 데이터 분포를 완벽히 반영하지 못함
- 히스토그램으로 일부 보완 (MySQL 8.0)

---

## A4. 조인 최적화

**Nested Loop Join (NLJ)**
- 기본 조인 방식
- 드라이빙 테이블의 각 행마다 드리븐 테이블 검색
- 인덱스가 있을 때 효율적

```
for each row in driving_table:
    for each row in driven_table:
        if join_condition:
            output row
```

**Block Nested Loop Join (BNL)**
- MySQL 8.0.18 이전 사용
- 조인 버퍼에 드라이빙 테이블 로드
- 드리븐 테이블 풀 스캔 횟수 감소

**Hash Join**
- MySQL 8.0.18부터 도입
- 작은 테이블로 해시 테이블 생성
- 큰 테이블 스캔하며 해시 매칭
- 인덱스 없는 조인에 효율적

```
-- 해시 조인 동작
1. Build 단계: 작은 테이블로 해시 테이블 생성
2. Probe 단계: 큰 테이블 스캔하며 해시 조회
```

---

## A5. 조인 순서

**결정 기준**
1. 결과 행 수가 적은 테이블을 드라이빙 테이블로
2. 인덱스를 효율적으로 사용할 수 있는 순서
3. 조인 조건의 선택도

**STRAIGHT_JOIN 사용 시점**
- 옵티마이저의 조인 순서가 비효율적일 때
- 조인 순서를 명시적으로 고정하고 싶을 때

```sql
-- 일반 조인 (옵티마이저가 순서 결정)
SELECT * FROM a JOIN b ON a.id = b.a_id;

-- STRAIGHT_JOIN (작성 순서대로 조인)
SELECT * FROM a STRAIGHT_JOIN b ON a.id = b.a_id;
```

**주의**
- 데이터 분포 변화 시 성능 저하 가능
- 가능하면 옵티마이저에 맡기는 것이 좋음

---

## A6. 서브쿼리 최적화

**서브쿼리 종류**

| 종류 | 위치 | 예시 |
|------|------|------|
| 스칼라 서브쿼리 | SELECT 절 | `SELECT (SELECT MAX(id) FROM b)` |
| 인라인 뷰 | FROM 절 | `SELECT * FROM (SELECT ...) t` |
| 중첩 서브쿼리 | WHERE 절 | `WHERE id IN (SELECT ...)` |

**최적화 방식**

**스칼라 서브쿼리**
- 결과 캐싱으로 반복 실행 방지
- 가능하면 조인으로 변환

**인라인 뷰**
- 뷰 머지(View Merge): 외부 쿼리와 병합
- 파생 테이블 최적화

**중첩 서브쿼리**
- 세미 조인으로 최적화
- EXISTS → IN 변환 등

---

## A7. 세미 조인 최적화

**정의**
- 서브쿼리 결과에 존재하는지만 확인
- 실제 데이터 조인은 하지 않음

**적용되는 쿼리**
```sql
-- IN 서브쿼리
SELECT * FROM employees
WHERE dept_id IN (SELECT id FROM departments WHERE name = 'IT');

-- EXISTS 서브쿼리
SELECT * FROM employees e
WHERE EXISTS (SELECT 1 FROM departments d WHERE d.id = e.dept_id);
```

**최적화 전략**

| 전략 | 설명 |
|------|------|
| Table Pull-out | 서브쿼리를 조인으로 변환 |
| Duplicate Weed-out | 중복 제거 후 조인 |
| First Match | 첫 번째 매칭에서 중단 |
| Loose Scan | 인덱스를 느슨하게 스캔 |
| Materialization | 서브쿼리 결과를 임시 테이블에 저장 |

---

## A8. 실무/면접 질문 답변

**서브쿼리 vs 조인**

```sql
-- 서브쿼리 방식
SELECT * FROM orders
WHERE user_id IN (SELECT id FROM users WHERE status = 'active');

-- 조인 방식
SELECT o.* FROM orders o
JOIN users u ON o.user_id = u.id
WHERE u.status = 'active';
```

**효율성 비교**

| 상황 | 더 효율적인 방식 |
|------|-----------------|
| MySQL 8.0+ | 대체로 비슷 (옵티마이저 최적화) |
| 대용량 데이터 | 조인 (실행 계획 예측 가능) |
| 중복 제거 필요 | 서브쿼리 (DISTINCT 불필요) |
| 복잡한 조건 | 상황에 따라 다름 |

**조인이 유리한 이유**
1. 옵티마이저가 더 많은 최적화 적용 가능
2. 실행 계획 예측이 쉬움
3. 조인 순서 최적화 가능

**서브쿼리가 유리한 경우**
1. 결과에 드라이빙 테이블 컬럼만 필요할 때
2. 서브쿼리 결과가 매우 작을 때
3. 세미 조인 최적화가 잘 적용될 때

**권장 사항**
- 두 방식 모두 작성 후 EXPLAIN으로 비교
- MySQL 8.0에서는 차이가 크지 않음
- 가독성도 고려하여 선택
