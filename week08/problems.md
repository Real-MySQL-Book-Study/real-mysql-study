# Week 8: SELECT 쿼리 작성 (2) - 문제

## 📚 학습 범위
- 11.4장: GROUP BY, ORDER BY 최적화
- 11.4.12장: 윈도우 함수 (ROW_NUMBER, RANK 등)

---

## 문제

### Q1. GROUP BY 최적화
GROUP BY 절에서 인덱스를 사용할 수 있는 조건을 설명하세요.

### Q2. ORDER BY 최적화
다음 쿼리에서 추가 정렬이 발생하지 않으려면 어떤 인덱스가 필요한가요?
```sql
SELECT * FROM orders
WHERE user_id = 100
ORDER BY created_at DESC, id DESC;
```

### Q3. GROUP BY + ORDER BY
다음 쿼리가 filesort 없이 실행되려면 어떤 조건이 필요한가요?
```sql
SELECT user_id, COUNT(*) as cnt
FROM orders
GROUP BY user_id
ORDER BY user_id;
```

### Q4. DISTINCT 최적화
DISTINCT와 GROUP BY의 차이점과 각각의 사용 시나리오를 설명하세요.

### Q5. 윈도우 함수 기본
ROW_NUMBER(), RANK(), DENSE_RANK()의 차이점을 예시와 함께 설명하세요.

### Q6. 윈도우 함수 활용
다음 요구사항을 윈도우 함수로 구현하세요:
"각 사용자별로 최근 주문 3건만 조회"

### Q7. PARTITION BY vs GROUP BY
윈도우 함수의 PARTITION BY와 GROUP BY의 차이점을 설명하세요.

### Q8. 실무/면접 질문
"페이지네이션을 구현할 때 OFFSET 방식과 커서 기반 방식의 차이점과 각각의 장단점을 설명해주세요."
