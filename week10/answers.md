# Week 10: 데이터 타입 - 답변

## A1. CHAR vs VARCHAR

| 구분 | CHAR | VARCHAR |
|------|------|---------|
| 저장 방식 | 고정 길이 | 가변 길이 |
| 공간 | 항상 n바이트 | 실제 길이 + 1~2바이트 |
| 패딩 | 공백으로 채움 | 없음 |
| 비교 시 | 후행 공백 무시 | 후행 공백 유지 |

**CHAR 사용**
```sql
-- 고정 길이 데이터
country_code CHAR(2)        -- 'KR', 'US'
gender CHAR(1)              -- 'M', 'F'
yn_flag CHAR(1)             -- 'Y', 'N'
```

**VARCHAR 사용**
```sql
-- 가변 길이 데이터
name VARCHAR(100)
email VARCHAR(255)
address VARCHAR(500)
```

**성능 차이**
- CHAR: 업데이트 시 길이 변경 없음 → 제자리 업데이트
- VARCHAR: 길이 변경 시 행 이동 가능

---

## A2. VARCHAR 최대 길이

**길이 저장 바이트**
| 최대 길이 | 길이 저장 |
|----------|----------|
| 0~255 | 1 byte |
| 256~65535 | 2 bytes |

**예시**
```sql
VARCHAR(255)  -- 최대 255 + 1 = 256 bytes
VARCHAR(256)  -- 최대 256 + 2 = 258 bytes
```

**실무 고려사항**
```sql
-- 불필요하게 큰 VARCHAR 정의 피하기
-- Bad
email VARCHAR(65535)  -- 너무 큼

-- Good
email VARCHAR(255)    -- 적절한 크기
```

**행 크기 제한**
- InnoDB 최대 행 크기: 65,535 bytes (페이지 크기에 따라 다름)
- VARCHAR 합계가 이를 초과하면 에러

---

## A3. 숫자 타입 선택

**정수 타입**
| 타입 | 크기 | 범위 (SIGNED) |
|------|------|--------------|
| TINYINT | 1 byte | -128 ~ 127 |
| SMALLINT | 2 bytes | -32,768 ~ 32,767 |
| MEDIUMINT | 3 bytes | -8M ~ 8M |
| INT | 4 bytes | -2.1B ~ 2.1B |
| BIGINT | 8 bytes | -9.2E ~ 9.2E |

**사용 시나리오**

```sql
-- INT 사용
user_id INT UNSIGNED        -- 최대 42억
order_count INT             -- 일반적인 카운트

-- BIGINT 사용
id BIGINT UNSIGNED          -- 대규모 시스템 PK
total_revenue BIGINT        -- 큰 금액

-- DECIMAL 사용 (정밀 계산)
price DECIMAL(10, 2)        -- 금액 (소수점 2자리)
interest_rate DECIMAL(5, 4) -- 이자율 (0.0000 ~ 9.9999)
```

**FLOAT/DOUBLE vs DECIMAL**
```sql
-- FLOAT/DOUBLE: 근사값, 빠른 연산
SELECT 0.1 + 0.2;  -- 0.30000000000000004 (부동소수점 오차)

-- DECIMAL: 정확한 값, 금융 계산에 필수
SELECT CAST(0.1 AS DECIMAL(10,2)) + CAST(0.2 AS DECIMAL(10,2));
-- 0.30
```

---

## A4. 날짜/시간 타입

| 구분 | DATETIME | TIMESTAMP |
|------|----------|-----------|
| 크기 | 8 bytes | 4 bytes |
| 범위 | 1000-01-01 ~ 9999-12-31 | 1970-01-01 ~ 2038-01-19 |
| 타임존 | 저장된 값 그대로 | UTC 변환 저장/조회 |
| NULL | 기본 NULL | 기본 CURRENT_TIMESTAMP |

**DATETIME 사용**
```sql
-- 타임존 무관한 날짜
birth_date DATETIME
event_date DATETIME
reservation_time DATETIME
```

**TIMESTAMP 사용**
```sql
-- 생성/수정 시간 (자동 갱신)
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

-- 글로벌 서비스에서 시간 동기화
```

**2038년 문제**
```sql
-- TIMESTAMP 한계: 2038-01-19 03:14:07 UTC
-- 장기 데이터는 DATETIME 사용 권장
```

---

## A5. ENUM과 SET

**ENUM**
```sql
CREATE TABLE users (
  status ENUM('active', 'inactive', 'pending')
);
-- 하나의 값만 선택
INSERT INTO users (status) VALUES ('active');
```

**SET**
```sql
CREATE TABLE users (
  permissions SET('read', 'write', 'delete')
);
-- 여러 값 선택 가능
INSERT INTO users (permissions) VALUES ('read,write');
```

**장점**
- 저장 공간 절약 (ENUM: 1-2 bytes, SET: 1-8 bytes)
- 데이터 무결성 (정의된 값만 허용)

**단점 및 주의사항**

1. **값 추가/변경 어려움**
```sql
-- 값 추가 시 테이블 재구성 필요
ALTER TABLE users MODIFY status
  ENUM('active', 'inactive', 'pending', 'deleted');
```

2. **정렬 문제**
```sql
-- ENUM은 정의 순서로 정렬 (알파벳 아님)
ORDER BY status;  -- active, inactive, pending 순
```

3. **권장 대안**
```sql
-- 별도 코드 테이블 사용
CREATE TABLE status_codes (
  code VARCHAR(20) PRIMARY KEY,
  description VARCHAR(100)
);
```

---

## A6. TEXT vs VARCHAR

| 구분 | VARCHAR | TEXT |
|------|---------|------|
| 최대 크기 | 65,535 bytes | 65,535 bytes (MEDIUMTEXT: 16MB) |
| 인덱스 | 전체 가능 | 접두사만 가능 |
| 저장 위치 | 행 내부 | 별도 저장 (길면) |
| 기본값 | 설정 가능 | 불가 |

**VARCHAR 사용**
```sql
-- 짧은 텍스트, 인덱스 필요
title VARCHAR(200)
summary VARCHAR(500)
```

**TEXT 사용**
```sql
-- 긴 텍스트, 인덱스 불필요
content TEXT
description TEXT
json_data TEXT  -- JSON 저장 (또는 JSON 타입)
```

**인덱스 제한**
```sql
-- TEXT 컬럼 인덱스: 접두사 길이 지정 필수
CREATE INDEX idx_content ON articles(content(100));
```

---

## A7. NULL과 저장 공간

**NULL 저장 방식**
- InnoDB: 행 헤더에 NULL 비트맵 저장
- 각 NULL 허용 컬럼당 1비트 사용

**저장 공간 비교**
```sql
-- NOT NULL
col INT NOT NULL
-- 4 bytes 고정

-- NULLABLE
col INT NULL
-- 4 bytes (값 있을 때) 또는 0 bytes (NULL) + 비트맵 1bit
```

**성능 영향**
1. NULL 비트맵 처리 오버헤드 (미미)
2. 인덱스에서 NULL 처리 복잡
3. IS NULL 조건 시 인덱스 사용 가능

**권장 사항**
```sql
-- 명확하게 NOT NULL 정의
created_at DATETIME NOT NULL
user_id INT NOT NULL

-- NULL이 의미 있을 때만 허용
deleted_at DATETIME NULL  -- soft delete
parent_id INT NULL        -- 루트 노드
```

---

## A8. 실무/면접 질문 답변

**데이터 타입 선택 기준**

**1. 저장할 데이터 특성**
```sql
-- 고정 길이 → CHAR
-- 가변 길이 → VARCHAR
-- 큰 텍스트 → TEXT
-- 정수 → INT/BIGINT (범위에 맞게)
-- 금액 → DECIMAL (정밀도 필요)
```

**2. 저장 공간 효율성**
```sql
-- 최소 크기 타입 선택
status TINYINT          -- 0~255면 충분
age TINYINT UNSIGNED    -- 0~255

-- VARCHAR 적절한 크기
email VARCHAR(255)      -- 너무 크게 정의하지 않기
```

**3. 인덱스 고려**
```sql
-- 인덱스 컬럼은 작은 타입
-- PK: INT보다 BIGINT 신중하게
-- 복합 인덱스: 총 크기 고려
```

**4. NULL 허용 여부**
```sql
-- 기본적으로 NOT NULL
-- NULL이 비즈니스 의미가 있을 때만 허용
```

**5. 확장성**
```sql
-- 미래 데이터 증가 고려
-- id: BIGINT 권장 (INT 한계 42억)
-- 날짜: DATETIME 권장 (TIMESTAMP 2038년 한계)
```

**6. 애플리케이션 호환성**
```sql
-- 프로그래밍 언어의 데이터 타입과 매핑
-- JSON 타입 활용 (유연한 스키마)
```

**체크리스트**
| 항목 | 확인 사항 |
|------|----------|
| 범위 | 최대/최소값 수용 가능? |
| 정밀도 | 소수점 필요? 정밀 계산? |
| 인덱스 | 검색/정렬에 사용? |
| NULL | 비어있는 값의 의미? |
| 확장성 | 10년 후에도 충분? |
| 호환성 | 애플리케이션과 호환? |
