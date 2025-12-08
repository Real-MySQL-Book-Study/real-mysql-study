# Week 9: INSERT/UPDATE/DELETE & DDL - 문제

## 📚 학습 범위
- 11.5-11.6장: DML 최적화
- 11.7장: 테이블/칼럼/인덱스 변경, 온라인 DDL

---

## 문제

### Q1. INSERT 최적화
대량 데이터 INSERT 시 성능을 높이는 방법들을 설명하세요.

### Q2. INSERT ... ON DUPLICATE KEY UPDATE
INSERT ... ON DUPLICATE KEY UPDATE의 동작 방식과 사용 시 주의사항을 설명하세요.

### Q3. REPLACE vs INSERT ... ON DUPLICATE KEY UPDATE
REPLACE와 INSERT ... ON DUPLICATE KEY UPDATE의 차이점을 설명하세요.

### Q4. UPDATE 조인
다음 요구사항을 UPDATE 문으로 작성하세요:
"users 테이블의 order_count 컬럼을 orders 테이블의 실제 주문 수로 업데이트"

### Q5. DELETE와 TRUNCATE
DELETE와 TRUNCATE의 차이점을 설명하고, 각각 언제 사용해야 하는지 설명하세요.

### Q6. 온라인 DDL
MySQL 온라인 DDL의 ALGORITHM과 LOCK 옵션을 설명하세요.

### Q7. ALTER TABLE 성능
대용량 테이블에 컬럼을 추가할 때 주의해야 할 점과 최적화 방법을 설명하세요.

### Q8. 실무/면접 질문
"운영 중인 서비스에서 대용량 테이블에 인덱스를 추가해야 합니다. 서비스 영향을 최소화하면서 인덱스를 추가하는 방법을 설명해주세요."
