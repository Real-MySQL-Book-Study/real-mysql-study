# Week 7: SELECT 쿼리 작성 (1) - 문제

## 📚 학습 범위
- 11.3장: MySQL 연산자와 내장 함수
- 11.4장: SELECT, JOIN 최적화

---

## 문제

### Q1. NULL 비교
다음 쿼리들의 결과가 다른 이유를 설명하세요:
```sql
SELECT * FROM users WHERE age = NULL;
SELECT * FROM users WHERE age IS NULL;
SELECT * FROM users WHERE age <=> NULL;
```

### Q2. LIKE vs REGEXP
LIKE와 REGEXP의 차이점과 성능 차이를 설명하세요.

### Q3. BETWEEN vs IN
다음 두 쿼리의 성능 차이를 설명하세요:
```sql
SELECT * FROM orders WHERE status IN ('pending', 'processing', 'shipped');
SELECT * FROM orders WHERE status BETWEEN 'pending' AND 'shipped';
```

### Q4. 날짜/시간 함수
NOW(), SYSDATE(), CURRENT_TIMESTAMP의 차이점을 설명하세요.

### Q5. 문자열 함수와 인덱스
다음 쿼리가 인덱스를 사용하지 못하는 이유와 개선 방법을 설명하세요:
```sql
SELECT * FROM users WHERE SUBSTRING(phone, 1, 3) = '010';
```

### Q6. 조인 알고리즘
MySQL 8.0에서 사용되는 조인 알고리즘들과 각각이 선택되는 상황을 설명하세요.

### Q7. OUTER JOIN 주의사항
다음 쿼리의 문제점을 찾고 수정하세요:
```sql
SELECT * FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE u.status = 'active';
```

### Q8. 실무/면접 질문
"대용량 테이블을 조인할 때 성능을 최적화하는 방법들을 설명해주세요."
