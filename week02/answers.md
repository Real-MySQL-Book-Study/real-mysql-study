# Week 2: 트랜잭션과 잠금 ⭐ - 답변

## A1. ACID 속성

| 속성 | 설명 | InnoDB 구현 |
|------|------|------------|
| **Atomicity (원자성)** | 트랜잭션은 전부 실행되거나 전부 취소 | 언두 로그로 롤백 지원 |
| **Consistency (일관성)** | 트랜잭션 전후 데이터 무결성 유지 | 제약조건, 트리거 등 |
| **Isolation (격리성)** | 동시 실행 트랜잭션 간 간섭 방지 | MVCC, 잠금 |
| **Durability (영속성)** | 커밋된 데이터는 영구 보존 | 리두 로그, 더블 라이트 버퍼 |

---

## A2. 트랜잭션 격리 수준

| 격리 수준 | Dirty Read | Non-Repeatable Read | Phantom Read |
|----------|------------|---------------------|--------------|
| READ UNCOMMITTED | O | O | O |
| READ COMMITTED | X | O | O |
| REPEATABLE READ | X | X | O (InnoDB는 X) |
| SERIALIZABLE | X | X | X |

**문제점 설명**
- **Dirty Read**: 커밋되지 않은 데이터 읽기
- **Non-Repeatable Read**: 같은 쿼리가 다른 결과 반환
- **Phantom Read**: 같은 조건 검색 시 새로운 행 발견

---

## A3. REPEATABLE READ와 Phantom Read

InnoDB의 REPEATABLE READ에서 Phantom Read가 발생하지 않는 이유:

1. **MVCC (Multi-Version Concurrency Control)**
   - 트랜잭션 시작 시점의 스냅샷을 읽음
   - 다른 트랜잭션의 INSERT도 보이지 않음

2. **넥스트 키 락 (Next-Key Lock)**
   - SELECT ... FOR UPDATE 시 갭 락 + 레코드 락 적용
   - 새로운 레코드 삽입 방지

---

## A4. InnoDB 잠금 종류

**레코드 락 (Record Lock)**
- 인덱스 레코드에 대한 잠금
- 특정 행 하나만 잠금

**갭 락 (Gap Lock)**
- 레코드와 레코드 사이의 간격 잠금
- 새로운 레코드 삽입 방지
- Phantom Read 방지 목적

**넥스트 키 락 (Next-Key Lock)**
- 레코드 락 + 갭 락의 조합
- InnoDB의 기본 잠금 방식
- 범위: 현재 레코드 + 앞의 갭

```
예: id가 10, 20, 30인 레코드가 있을 때
id=20에 넥스트 키 락 → (10, 20] 범위 잠금
```

---

## A5. 잠금 대기와 타임아웃

**타임아웃 발생 시**
- 대기 중인 쿼리가 에러 반환
- `ERROR 1205 (HY000): Lock wait timeout exceeded`
- 트랜잭션은 자동으로 롤백되지 않음 (해당 쿼리만 실패)

**관련 설정**
```sql
-- 잠금 대기 시간 설정 (기본 50초)
SET innodb_lock_wait_timeout = 50;

-- 타임아웃 시 트랜잭션 롤백 여부
SET innodb_rollback_on_timeout = OFF;
```

---

## A6. 데드락

**정의**
- 두 개 이상의 트랜잭션이 서로의 잠금을 기다리며 무한 대기하는 상태

**MySQL의 처리**
1. InnoDB가 데드락 감지 스레드 운영
2. 데드락 발견 시 하나의 트랜잭션을 선택하여 롤백
3. 언두 로그가 적은(비용이 낮은) 트랜잭션이 롤백 대상
4. `ERROR 1213 (40001): Deadlock found`

**예방 방법**
- 트랜잭션을 짧게 유지
- 동일한 순서로 테이블/레코드 접근
- 적절한 인덱스 사용

---

## A7. 네임드 락과 메타데이터 락

**네임드 락 (Named Lock)**
- 사용자가 지정한 문자열에 대한 잠금
- 애플리케이션 레벨 동기화에 사용

```sql
SELECT GET_LOCK('my_lock', 10);  -- 획득
SELECT RELEASE_LOCK('my_lock');  -- 해제
```

**메타데이터 락 (Metadata Lock)**
- 테이블 구조 변경 시 자동 획득
- DDL과 DML의 동시 실행 방지
- 테이블 이름 변경 시에도 사용

---

## A8. 실무/면접 질문 답변

**SELECT ... FOR UPDATE**
- 배타적 잠금(Exclusive Lock) 획득
- 다른 트랜잭션의 읽기/쓰기 모두 차단
- 사용 시기: 데이터를 읽고 수정할 예정일 때

```sql
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
```

**SELECT ... FOR SHARE (LOCK IN SHARE MODE)**
- 공유 잠금(Shared Lock) 획득
- 다른 트랜잭션의 읽기는 허용, 쓰기는 차단
- 사용 시기: 데이터 무결성 확인만 필요할 때

```sql
SELECT * FROM products WHERE id = 1 FOR SHARE;
-- 재고 확인 후 다른 테이블에 주문 기록
```

**핵심 차이점**
| 구분 | FOR UPDATE | FOR SHARE |
|------|-----------|-----------|
| 잠금 타입 | 배타적 | 공유 |
| 다른 SELECT FOR SHARE | 차단 | 허용 |
| 다른 UPDATE/DELETE | 차단 | 차단 |
