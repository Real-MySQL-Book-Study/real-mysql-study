# Week 11: 복제(Replication) & 종합 리뷰 - 문제

## 📚 학습 범위
- 16장: Master-Slave 복제 개념
  - 복제 아키텍처와 동작 원리
  - 읽기/쓰기 분리 전략
  - Replication Lag 문제
- 전체 복습 + 실전 문제 풀이

---

## Part 1: 복제(Replication)

### Q1. 복제 아키텍처
MySQL 복제의 기본 구조와 각 구성요소(Binary Log, Relay Log, IO Thread, SQL Thread)의 역할을 설명하세요.

### Q2. 복제 방식
비동기 복제, 반동기 복제(Semi-Synchronous), 그룹 복제(Group Replication)의 차이점을 설명하세요.

### Q3. 바이너리 로그 포맷
STATEMENT, ROW, MIXED 바이너리 로그 포맷의 차이점과 각각의 장단점을 설명하세요.

### Q4. 읽기/쓰기 분리
읽기/쓰기 분리 전략을 구현할 때 고려해야 할 점들을 설명하세요.

### Q5. Replication Lag
복제 지연(Replication Lag)이 발생하는 원인과 해결 방법을 설명하세요.

### Q6. GTID 기반 복제
GTID(Global Transaction ID) 기반 복제의 장점과 동작 방식을 설명하세요.

---

## Part 2: 종합 리뷰

### Q7. 종합 문제 1
다음 쿼리의 성능을 분석하고 최적화 방안을 제시하세요:
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

### Q8. 종합 문제 2
다음 시나리오에서 발생할 수 있는 문제와 해결 방법을 설명하세요:
"두 개의 트랜잭션이 동시에 같은 계좌에서 출금을 시도합니다. 계좌 잔액이 100만원이고, 각각 80만원을 출금하려고 합니다."

### Q9. 실무/면접 질문
"대규모 트래픽을 처리하는 서비스에서 MySQL을 사용할 때 고려해야 할 아키텍처와 성능 최적화 전략을 설명해주세요."
