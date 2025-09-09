# 고성능 Database 구현

## PostgeSQL(DBaaS) Replica 구성

- Replica 수 : `1`
- Replica명 : `cedbreplica`
- 서비스 유형 > 서버 타입 : Standard(db1) / db1v2m4
- IP 접근 제어 : 10.1.2.0/24, 10.1.3.0/24

## Replica Private DNS 레코드 등록

| 유형 | 이름 | 값 | TTL|
|----|----|----|----|
|A|replica|Replica IP|300|
|A|cache|10.1.3.200|300|

## PostgeSQL(DBaaS) Replica 적용을 위한 애플리케이션 수정

AS-IS

```md
┌─────────────┐      ┌──────────────────┐
│  앱 서버     │      │   마스터 DB       │
│ (Node.js)   │─────▶│ db.cesvc.net     │ (모든 작업)
│             │      │  Port: 2866      │
└─────────────┘      └──────────────────┘
```

TO-BE

```md
┌─────────────┐      ┌──────────────────┐
│  앱 서버     │      │   마스터 DB       │
│ (Node.js)   │─────▶│ db.cesvc.net     │ (쓰기)
│             │      │  Port: 2866      │
│             │      └──────────────────┘
│             │      
│             │      ┌──────────────────┐
│             │─────▶│   복제 DB        │ (읽기)
└─────────────┘      │ replica.cesvc.net│
                     │  Port: 2866      │
                     └──────────────────┘
```

| Query Type | Destination | Example |
|------------|-------------|---------|
| SELECT | Replica | `SELECT * FROM products` |
| INSERT | Master | `INSERT INTO orders...` |
| UPDATE | Master | `UPDATE inventory SET...` |
| DELETE | Master | `DELETE FROM orders...` |
| Transaction | Master | `BEGIN; ...; COMMIT;` |

- /advance_ha/replica_caching/01_setup_replica.sh

```bash
# 기존 설정 파일 백업 생성
# 연결 풀링이 포함된 `database-replicated.js` 생성
# `.env` 파일에 복제본 설정 추가
# 데이터베이스 연결 테스트

cd /home/rocky

sudo bash 01_setup_replica.sh
```

- /advance_ha/replica_caching/02_apply_replica.sh

```bash
# 라우트 파일 (`orders.js` + `objorders.js`) 자동 업데이트

cd /home/rocky

sudo bash 02_apply_replica.sh
```

- /advance_ha/replica_caching/03_test_replica.sh

```bash
# 애플리케이션 재시작 및 테스트

cd /home/rocky

sudo bash 03_test_replica.sh
```

## CacheStore(DBaaS) 구성

- 이미지 및 버전 선택 : Redis OSS Sentinel 7.2.6

- 서버명 Prefix : `cedbcache`
- 클러스터명 : `cedbcachecluster`
- 서비스 유형 > 서버 타입 : Standard(redis1) / redis1v1m2
- Block Storage > 기본 OS: SSD, DATA: SSD, `56`GB
- 고가용성 : 사용하지 않음
- 네트워크 : 서버별 설정
  - VPC : VPC1
  - Subnet : Subnet13
  - IP :10.1.3.200
- IP 접근 제어 : 10.1.2.0/24, 10.1.3.0/24
- Redis Port 번호 : `6378`
- Redis 비밀 번호 : `cedbadmin123!`
- Parameter : Redis PISA Default
- 시간대 : ASIA/Seoul

## Security Group 규칙

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|User Input|appSG|Outbound|dbSG|TCP 6378| Outbound to CacheStore|

## CacheStore(DBaaS) 적용을 위한 애플리케이션 수정

AS-IS

```md
┌─────────────┐      ┌──────────────────┐
│  앱 서버     │      │   마스터 DB       │
│ (Node.js)   │─────▶│ db.cesvc.net     │ (쓰기)
│             │      │  Port: 2866      │
│             │      └──────────────────┘
│             │      
│             │      ┌──────────────────┐
│             │─────▶│   복제 DB        │ (읽기)
└─────────────┘      │ replica.cesvc.net│
                     │  Port: 2866      │
                     └──────────────────┘
```

TO-BE

```md
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│             │     │    Redis    │     │    읽기      │     │   마스터     │
│ 애플리케이션  │───▶│    캐시      │───▶│   복제 DB    │───▶│  데이터베이스 │
│             │     │cache.cesvc  │     │replica.cesvc│     │ db.cesvc    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
      │                    │                  │                  │
      │            캐시 적중 (빠름)             │                  │
      │◀────────────────────                  │                  │
      │                                       │                  │
      │           캐시 미스 ──────────────────▶│                  │
      │◀──────────────────────────────────────│                  │
      │                                                           │
      │           쓰기 작업 ─────────────────────────────────────▶│
      │◀─────────────────────────────────────────────────────────│
```

| 요청 | 흐름 |
|------|------|
| 읽기 쿼리 | 캐시 → 복제본 → 마스터 (대체) |
| 쓰기 쿼리 | 마스터 → 캐시 무효화 |
| 트랜잭션 | 마스터 (캐시 우회) |

- /advance_ha/replica_caching/04_setup_redis_cache.sh

```bash
# Redis 클라이언트 패키지 설치
# Redis 연결 모듈 생성
# TTL 전략이 포함된 캐싱 서비스 생성
# `.env` 파일에 Redis 설정 추가

cd /home/rocky

sudo bash 04_setup_redis_cache.sh
```

- /advance_ha/replica_caching/05_apply_cache.sh

```bash
# 라우트 핸들러의 캐시 버전 생성
# 자동 캐시 무효화 구현
# 캐싱을 위한 서버 설정 업데이트

cd /home/rocky

sudo bash 05_apply_cache.sh
```

- /advance_ha/replica_caching/06_test_cache_performance.sh

```bash
### 캐시 워밍 및 재시작

node warm_cache.js

pm2 restart creative-energy-api

# 성능 테스트

cd /home/rocky

sudo bash 06_test_cache_performance.sh

```
