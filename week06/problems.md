# Week 6: 실행 계획 ⭐ - 문제

## 📚 학습 범위
- 10장: EXPLAIN 완벽 분석, type/Extra 컬럼 해석

---

## 문제

### Q1. EXPLAIN 기본
EXPLAIN 명령어의 출력 컬럼들을 나열하고, 각각이 의미하는 바를 간략히 설명하세요.

### Q2. type 컬럼
EXPLAIN의 type 컬럼에서 다음 값들의 의미와 성능 순서를 설명하세요:
- system, const, eq_ref, ref, range, index, ALL

### Q3. key_len 분석
복합 인덱스 (a INT, b VARCHAR(100), c INT)에서 다음 쿼리의 key_len은 얼마일까요?
```sql
SELECT * FROM t WHERE a = 1 AND b = 'hello';
```
(문자셋: utf8mb4, nullable 컬럼)

### Q4. Extra 컬럼 - 좋은 신호
Extra 컬럼에서 성능에 긍정적인 값들을 나열하고 설명하세요.

### Q5. Extra 컬럼 - 나쁜 신호
Extra 컬럼에서 성능에 부정적인 값들을 나열하고 설명하세요.

### Q6. EXPLAIN ANALYZE
EXPLAIN ANALYZE의 출력을 해석하는 방법을 설명하세요. EXPLAIN과 차이점은 무엇인가요?

### Q7. 실행 계획 개선
다음 실행 계획을 보고 개선 방안을 제시하세요:
```
+----+-------------+-------+------+---------------+------+---------+------+--------+-------------+
| id | select_type | table | type | possible_keys | key  | key_len | ref  | rows   | Extra       |
+----+-------------+-------+------+---------------+------+---------+------+--------+-------------+
|  1 | SIMPLE      | users | ALL  | NULL          | NULL | NULL    | NULL | 100000 | Using where |
+----+-------------+-------+------+---------------+------+---------+------+--------+-------------+
```

### Q8. 실무/면접 질문
"운영 중인 서비스에서 슬로우 쿼리가 발생했습니다. EXPLAIN을 통해 어떻게 분석하고 최적화하시겠습니까?"
