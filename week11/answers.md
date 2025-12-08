# Week 11: 복제(Replication) & 종합 리뷰 - 답변

## Part 1: 복제(Replication)

## A1. 복제 아키텍처

**기본 구조**
```
[Primary/Master]           [Replica/Slave]
     │                          │
  Binary Log ──────────→ IO Thread
     │                          │
     │                     Relay Log
     │                          │
     └──────────────────→ SQL Thread
                                │
                           데이터 적용
```

**구성요소 역할**

| 구성요소 | 역할 |
|---------|------|
| **Binary Log** | Primary에서 모든 변경 사항 기록 |
| **IO Thread** | Replica에서 Binary Log 읽어 Relay Log에 저장 |
| **Relay Log** | Replica에서 받은 이벤트 임시 저장 |
| **SQL Thread** | Relay Log의 이벤트를 실제 적용 |

**복제 과정**
1. Primary: 트랜잭션 커밋 → Binary Log 기록
2. Replica IO Thread: Binary Log 이벤트 요청
3. Primary: 이벤트 전송
4. Replica: Relay Log에 저장
5. Replica SQL Thread: 이벤트 읽어 실행

---

## A2. 복제 방식

**비동기 복제 (Asynchronous)**
```
Primary: 커밋 → 완료 (Replica 확인 안 함)
Replica: 나중에 적용
```
- 장점: 빠른 응답
- 단점: 데이터 유실 가능성

**반동기 복제 (Semi-Synchronous)**
```
Primary: 커밋 → Replica ACK 대기 → 완료
Replica: 수신 확인 (ACK) → 적용
```
- 장점: 최소 1개 Replica에 전달 보장
- 단점: 지연 시간 증가
- 설정: `rpl_semi_sync_master_wait_point`

**그룹 복제 (Group Replication)**
```
Primary: 커밋 → 그룹 합의 (다수결) → 완료
모든 노드: 동시 적용
```
- 장점: 높은 가용성, 자동 페일오버
- 단점: 복잡한 구성, 오버헤드

---

## A3. 바이너리 로그 포맷

| 포맷 | 저장 내용 | 장점 | 단점 |
|------|----------|------|------|
| **STATEMENT** | SQL 문장 | 로그 크기 작음 | 비결정적 함수 문제 |
| **ROW** | 변경된 행 데이터 | 정확한 복제 | 로그 크기 큼 |
| **MIXED** | 상황에 따라 선택 | 균형적 | 예측 어려움 |

**STATEMENT 문제 예시**
```sql
-- 비결정적 결과
UPDATE users SET updated_at = NOW() WHERE id = 1;
DELETE FROM logs ORDER BY id LIMIT 100;
```

**ROW 포맷 권장 상황**
- 정확한 복제 필요
- 트리거 사용
- 비결정적 함수 사용

**설정**
```sql
SET GLOBAL binlog_format = 'ROW';
```

---

## A4. 읽기/쓰기 분리

**구현 방식**
```
[Application]
     │
[Proxy/Router] ──── 쓰기 ──→ [Primary]
     │
     └─────────── 읽기 ──→ [Replica 1]
                         [Replica 2]
```

**고려사항**

**1. 복제 지연 처리**
```sql
-- 중요 읽기는 Primary에서
SELECT * FROM orders WHERE id = @last_inserted_id;

-- 일반 조회는 Replica에서
SELECT * FROM products WHERE category = 'books';
```

**2. 세션 일관성**
- 쓰기 후 읽기는 같은 Primary에서
- GTID로 복제 완료 확인 후 Replica 읽기

**3. 라우팅 전략**
```python
# 예시: 애플리케이션 레벨 분리
def get_connection(read_only=False):
    if read_only:
        return replica_pool.get()
    return primary_pool.get()
```

**4. 프록시 도구**
- ProxySQL
- MySQL Router
- MaxScale

---

## A5. Replication Lag

**발생 원인**

| 원인 | 설명 |
|------|------|
| 네트워크 지연 | Primary-Replica 간 네트워크 |
| Replica 부하 | 읽기 쿼리 과부하 |
| 대량 트랜잭션 | 큰 UPDATE/DELETE |
| 단일 SQL Thread | 직렬 처리 병목 |

**확인 방법**
```sql
SHOW SLAVE STATUS\G
-- Seconds_Behind_Master: 지연 시간 (초)
```

**해결 방법**

**1. 병렬 복제 활성화 (MySQL 5.7+)**
```sql
SET GLOBAL slave_parallel_workers = 4;
SET GLOBAL slave_parallel_type = 'LOGICAL_CLOCK';
```

**2. 대량 작업 분할**
```sql
-- Bad
DELETE FROM logs WHERE created_at < '2023-01-01';

-- Good: 배치 처리
DELETE FROM logs WHERE created_at < '2023-01-01' LIMIT 10000;
-- 반복 실행
```

**3. Replica 성능 향상**
- 더 빠른 디스크 (SSD)
- 충분한 버퍼 풀

**4. 모니터링**
```sql
-- Performance Schema
SELECT * FROM performance_schema.replication_applier_status;
```

---

## A6. GTID 기반 복제

**GTID (Global Transaction ID)**
```
GTID = source_id:transaction_id
예: 3E11FA47-71CA-11E1-9E33-C80AA9429562:23
```

**장점**
1. 자동 위치 지정 (Binary Log 파일/위치 불필요)
2. 쉬운 페일오버
3. 트랜잭션 추적 용이
4. 일관성 검증 가능

**동작 방식**
```sql
-- Replica가 자동으로 위치 찾음
CHANGE MASTER TO
  MASTER_HOST = 'primary',
  MASTER_AUTO_POSITION = 1;
```

**설정**
```sql
-- my.cnf
gtid_mode = ON
enforce_gtid_consistency = ON
```

**GTID 확인**
```sql
SELECT @@GLOBAL.GTID_EXECUTED;
SHOW MASTER STATUS;
```

---

## Part 2: 종합 리뷰

## A7. 종합 문제 1

**원본 쿼리 분석**
```sql
SELECT u.name, COUNT(o.id) as order_count, SUM(o.amount) as total_amount
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01'
  AND o.status = 'completed'
GROUP BY u.id
HAVING total_amount > 100000
ORDER BY total_amount DESC
LIMIT 10;
```

**문제점**
1. LEFT JOIN + WHERE o.status → INNER JOIN과 동일
2. GROUP BY u.id인데 SELECT u.name → SQL 모드에 따라 에러
3. 인덱스 활용 불명확

**최적화된 쿼리**
```sql
SELECT u.id, u.name, o.order_count, o.total_amount
FROM users u
JOIN (
  SELECT user_id,
         COUNT(*) as order_count,
         SUM(amount) as total_amount
  FROM orders
  WHERE status = 'completed'
  GROUP BY user_id
  HAVING SUM(amount) > 100000
) o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01'
ORDER BY o.total_amount DESC
LIMIT 10;
```

**필요한 인덱스**
```sql
CREATE INDEX idx_users_created ON users(created_at);
CREATE INDEX idx_orders_status_user ON orders(status, user_id, amount);
```

---

## A8. 종합 문제 2

**시나리오**
- 잔액: 100만원
- 트랜잭션 A: 80만원 출금
- 트랜잭션 B: 80만원 출금

**문제점: Lost Update**
```
T1: SELECT balance FROM accounts WHERE id = 1;  -- 100만원
T2: SELECT balance FROM accounts WHERE id = 1;  -- 100만원
T1: UPDATE accounts SET balance = 20 WHERE id = 1;  -- 100-80
T2: UPDATE accounts SET balance = 20 WHERE id = 1;  -- 100-80 (T1 무시됨)
-- 결과: 잔액 20만원, 160만원 출금됨
```

**해결 방법**

**방법 1: 비관적 잠금 (FOR UPDATE)**
```sql
START TRANSACTION;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
-- 잔액 확인 후
UPDATE accounts SET balance = balance - 80 WHERE id = 1;
COMMIT;
```

**방법 2: 낙관적 잠금 (버전 체크)**
```sql
UPDATE accounts
SET balance = balance - 80, version = version + 1
WHERE id = 1 AND balance >= 80 AND version = @expected_version;
-- affected_rows = 0이면 재시도
```

**방법 3: 조건부 UPDATE**
```sql
UPDATE accounts
SET balance = balance - 80
WHERE id = 1 AND balance >= 80;
-- affected_rows 확인
```

---

## A9. 실무/면접 질문 답변

**대규모 트래픽 MySQL 아키텍처**

**1. 복제 구성**
```
[Primary] ──→ [Replica 1] (읽기)
    │    ──→ [Replica 2] (읽기)
    │    ──→ [Replica 3] (백업)
    └──────→ [Replica 4] (분석)
```

**2. 읽기/쓰기 분리**
- ProxySQL 또는 애플리케이션 레벨 라우팅
- 쓰기: Primary
- 읽기: Replica (로드 밸런싱)

**3. 캐싱 전략**
```
[Application]
     │
[Redis/Memcached] ← 캐시 히트
     │
[MySQL] ← 캐시 미스
```

**4. 샤딩 (Sharding)**
```
사용자 1~1000만: Shard 1
사용자 1000만~2000만: Shard 2
...
```

**5. 인덱스 최적화**
- 슬로우 쿼리 모니터링
- 커버링 인덱스 활용
- 불필요한 인덱스 제거

**6. 쿼리 최적화**
- EXPLAIN ANALYZE로 분석
- N+1 문제 해결
- 배치 처리

**7. 커넥션 관리**
- 커넥션 풀 적절한 크기
- 타임아웃 설정

**8. 모니터링**
- Performance Schema
- 슬로우 쿼리 로그
- 복제 지연 모니터링

**체크리스트**
| 항목 | 전략 |
|------|------|
| 읽기 확장 | Replica 추가 |
| 쓰기 확장 | 샤딩 |
| 캐싱 | Redis/Memcached |
| 고가용성 | 복제 + 자동 페일오버 |
| 백업 | Replica에서 백업 |
