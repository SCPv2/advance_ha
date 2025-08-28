# 고가용성 Database 서비스 구성

## 선행 실습

### 필수 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 필수 '[고가용성 3계층 아키텍처 구성](../3_tier_architecture/README.md)

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

### 선택 '[고가용성 구현을 위한 File Storage 구성](../file_storage/README.md)'

## 실습 환경 배포

**&#128906; Terraform 배포 스크립트 실행**

```powershell

cd C:\scpv2advance\advance_ha\database_service\

Set_ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

.\deploy_scp_lab_environment.ps1

```

- keypair_name: mykey ........................................# 기본 키페어 값, 다른 키페어 사용시 입력

- object_storage_access_key_id: .......................# 입력 없이 엔터(이번 차시 사용 안함)

- object_storage_bucket_string: ........................# 입력 없이 엔터(이번 차시 사용 안함)
- object_storage_secret_access_key: ................# 입력 없이 엔터(이번 차시 사용 안함)
- private_domain_name: ......................................# 과정 소개에서 만든 프라이빗 도메인 이름
- private_hosted_zone_id: ....................................# 과정 소개에서 만든 프라이빗 도메인의 Hosted Zone ID
- public_domain_name: .........................................# 과정 소개에서 만든 퍼블릭 도메인 이름
- user_public_ip: ........................................................# 현재 실습을 수행하고 있는 PC의 퍼블릭 IP 주소

## 환경 검토

- Architectuer Diagram
- VPC CIDR
- Subnet CIDR
- Virtual Server OS, Public IP, Private IP
- Firewall 규칙
- Security Group 규칙

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|IGW|10.1.1.110, 10.1.1.111, 10.1.1.112, 10.1.2.121, 10.1.2.122, 10.1.3.131|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vms to Internet|
|Terraform|IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Terraform|IGW|Your Public IP|10.1.1.111|TCP 80|Allow|Inbound|HTTP inbound to web vm|
|Terraform|web Load Balancer|Your Public IP|10.1.1.100 (Service IP)|TCP 80|Allow|Outbound|클라이언트 → LB 연결|
|Terraform|web Load Balancer|webLB Source NAT IP|10.1.1.111, 10.1.1.112 (webvm IP)|TCP 80|Allow|Inbound|LB → 멤버 연결|
|Terraform|web Load Balancer|webLB 헬스 체크 IP|10.1.1.111, 10.1.1.112 (webvm IP)|TCP 80|Allow|Inbound|LB → 멤버 헬스 체크|
|Terraform||app Load Balancer|10.1.1.111, 10.1.1.112 (webvm IP)|10.1.2.100 (Service IP)|3000|Allow|Outbound 클라이언트 → LB 연결|
|Terraform|app Load Balancer|appLB Source NAT IP|10.1.2.121, 10.1.2.122 (appvm IP)|3000|Allow|Inbound|LB → 멤버 연결|
|Terraform|app Load Balancer|appLB 헬스 체크 IP|10.1.2.121, 10.1.2.122 (appvm IP)|3000|Allow|Inbound|LB → 멤버 헬스 체크|

### Security Group

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terrafom|bastionSG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terrafom|bastionSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|bastionSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Add|bastionSG|Outbound|dbSG|TCP 22|SSH outbound to db vm |
|Add|bastionSG|Outbound|webSG|TCP 22|SSH outbound to web vm |
|Add|bastionSG|Outbound|appSG|TCP 22|SSH outbound to app vm |
|||||||
|Terrafom|webSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|webSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|webSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Terrafom|webSG|Inbound|bastionSG|TCP 80|HTTP inbound from bastion|
|Terrafom|webSG|Inbound|webLB Source NAT IP|TCP 80|HTTP inbound from Load Balancer|
|Terrafom|webSG|Inbound|webLB Healthcheck IP|TCP 80|Healthcheck HTTP inbound from Load Balancer|
|Terrafom|webSG|Outbound|appLB Service IP|3000|API connection outbound to app LB|
|||||||
|Terrafom|appSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|appSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|appSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Terrafom|appSG|Outbound|dbSG|TCP 2866|db connection outbound to db vm|
|Terrafom|appSG|Inbound|appLB Source NAT IP|3000|API connection inbound from Load Balancer|
|Terrafom|webSG|Inbound|appLB Healthcheck IP|3000|Healthcheck 3000 inbound from Load Balancer|
|||||||
|Terrafom|dbSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|dbSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|dbSG|Inbound|appSG|TCP 2866|db connection inbound from app vm|
|Terrafom|dbSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|

## PostgreSQL(DBaaS) 생성

- PostgreSQL Community 16.8 선택
- 서버명 prefix : cedbserver
- 클러스터명 : cedbcluster
- 서버 타입 : db1v2m4
- Block Storage : 기본 OS : SSD , DATA : SSD 16GB
- 이중화 구성 : 사용
- 네트워크 : 공통 설정
- VPC : VPC1
- Subnet : Subnet13
- IP : 10.1.3.32
- IP 접근 제어 : 10.1.2.0/24, 10.1.1.110   # appVM의 서브넷 대역과 Bastion Host IP
- 유지 관리 기간 : 사용안함
- Database명 : cedb       # 이름 변경 불가
- Database 사용자명 : cedbadmin    # 이름 변경 불가
- Database 비밀번호 : ceadmin123!   # 가급적 준수 필요
- Database Port번호 : 2866
- 백업 : 사용 안함
- Audit Log 설정 : 사용 안함
- Parameter : PostgreSQL Community 16 PISA Default
- Database Encoding : UTF-8
- DB Locale : C
- 시간대 : ASIA/SEOUL(GMT +9:00)

## 데이터 마이그레이션

- pgAdmin [다운로드](https://www.pgadmin.org/download/)

- 기존 데이터베이스(db.your_private_ip.net 또는 10.1.3.31) 연결 및 백업

- 새 데이터베이스(10.1.3.32) 연결 및 백업 데이터로 복구

## 데이터베이스 장애 테스트


. 

. 

. 

. 

. 

. 

. 

. 

. 

. 

. 

.  

. 

. 

. 

. 

. 

. 


. 
  
   







## 개요

이 템플릿은 기존 file_storage 인프라를 기반으로 File Storage 볼륨을 추가하고, 자체 관리형 PostgreSQL 데이터베이스를 Samsung Cloud Platform v2의 관리형 데이터베이스 서비스로 마이그레이션하는 실습 환경을 제공합니다.

## 아키텍처 구성

### 인프라 구성

- **Web Tier**: 2대의 웹 서버 (Load Balancer 구성)

- **App Tier**: 2대의 앱 서버 (Load Balancer 구성)  
- **Database Tier**: 1대의 PostgreSQL 데이터베이스 서버
- **File Storage**: NFS 공유 볼륨 (웹/앱 서버 간 파일 공유)
- **Network**: 3-tier VPC 구성, DNS Private Zone
- **Management**: Bastion Host (Windows)

### File Storage 구성

- **Protocol**: NFS

- **Type**: HighPerformanceSSD
- **Access Rules**: Web/App 서버 4대에 대한 접근 권한
- **Mount Point**: `/shared` (공유 디렉토리)

## 배포 순서

### 1. 환경 준비

```bash
# 변수 파일 설정
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

### 2. 인프라 배포

```bash
terraform init
terraform plan
terraform apply
```

### 3. File Storage 마운트 설정

배포 후 각 서버에서 NFS 볼륨을 수동으로 마운트해야 합니다:

```bash
# 웹/앱 서버에서 실행
sudo mkdir -p /shared
sudo mount -t nfs <file_storage_ip>:/ /shared
echo "<file_storage_ip>:/ /shared nfs defaults 0 0" >> /etc/fstab
```

## 관리형 데이터베이스 마이그레이션 시나리오

### 시나리오 1: 기본 마이그레이션 실습 (난이도: 초급)

**목표**: 자체 관리형 PostgreSQL을 관리형 DB로 마이그레이션

**실습 단계**:

1. **현재 데이터베이스 상태 확인**

   ```bash
   # 데이터베이스 연결 테스트
   psql -h db.${private_domain_name} -U postgres -d creativity
   
   # 테이블 구조 확인
   \dt
   \d+ users
   \d+ projects
   ```

2. **데이터 백업 생성**

   ```bash
   # 전체 데이터베이스 덤프
   pg_dump -h db.${private_domain_name} -U postgres -d creativity > /shared/backup_before_migration.sql
   
   # 스키마만 백업
   pg_dump -h db.${private_domain_name} -U postgres -d creativity --schema-only > /shared/schema_backup.sql
   
   # 데이터만 백업
   pg_dump -h db.${private_domain_name} -U postgres -d creativity --data-only > /shared/data_backup.sql
   ```

3. **관리형 데이터베이스 생성** (포털에서 수행)
   - Database Type: PostgreSQL
   - Version: 13.x
   - Instance Type: Standard
   - Storage: 100GB SSD
   - Backup: 자동 백업 활성화

4. **데이터 복원 테스트**

   ```bash
   # 관리형 DB에 데이터 복원
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity < /shared/backup_before_migration.sql
   
   # 데이터 무결성 검증
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity -c "SELECT COUNT(*) FROM users;"
   ```

**학습 포인트**:

- PostgreSQL 덤프/복원 명령어 숙련
- 관리형 DB 인스턴스 생성 및 설정
- 데이터 무결성 검증 방법

---

### 시나리오 2: 무중단 마이그레이션 실습 (난이도: 중급)

**목표**: 서비스 중단 없이 점진적으로 데이터베이스 마이그레이션

**실습 단계**:

1. **읽기 전용 복제본 구성**

   ```bash
   # 현재 DB에서 읽기 전용 계정 생성
   psql -h db.${private_domain_name} -U postgres -d creativity
   CREATE USER readonly WITH PASSWORD 'readonly123';
   GRANT CONNECT ON DATABASE creativity TO readonly;
   GRANT USAGE ON SCHEMA public TO readonly;
   GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
   ```

2. **애플리케이션 설정 변경 준비**

   ```javascript
   // /shared/db_config_migration.js
   const dbConfig = {
     primary: {
       host: 'db.${private_domain_name}',
       user: 'postgres',
       database: 'creativity'
     },
     secondary: {
       host: '<managed_db_endpoint>',
       user: '<admin_user>', 
       database: 'creativity'
     },
     migrationMode: 'dual-write' // 'primary-only', 'dual-write', 'secondary-only'
   };
   ```

3. **단계별 전환**
   - **Phase 1**: 읽기 트래픽 일부를 관리형 DB로 이전
   - **Phase 2**: 모든 읽기 트래픽을 관리형 DB로 이전
   - **Phase 3**: 쓰기 트래픽을 관리형 DB로 이전
   - **Phase 4**: 기존 DB 비활성화

4. **트래픽 모니터링**

   ```bash
   # 연결 수 모니터링 스크립트
   cat > /shared/monitor_connections.sh << 'EOF'
   #!/bin/bash
   while true; do
     echo "=== $(date) ==="
     echo "Primary DB connections:"
     psql -h db.${private_domain_name} -U postgres -d creativity -c "SELECT count(*) FROM pg_stat_activity;"
     echo "Managed DB connections:"
     psql -h <managed_db_endpoint> -U <admin_user> -d creativity -c "SELECT count(*) FROM pg_stat_activity;"
     sleep 30
   done
   EOF
   chmod +x /shared/monitor_connections.sh
   ```

**학습 포인트**:

- 단계적 마이그레이션 전략 수립
- 이중 쓰기(Dual Write) 패턴 구현
- 실시간 모니터링 및 롤백 계획

---

### 시나리오 3: 성능 테스트 및 최적화 실습 (난이도: 중급)

**목표**: 마이그레이션 전후 성능 비교 및 최적화

**실습 단계**:

1. **성능 테스트 도구 설치**

   ```bash
   # pgbench 설치 및 설정
   sudo yum install -y postgresql-contrib
   
   # 테스트 데이터 생성
   pgbench -h db.${private_domain_name} -U postgres -d creativity -i -s 10
   ```

2. **기준 성능 측정**

   ```bash
   # 현재 DB 성능 테스트
   pgbench -h db.${private_domain_name} -U postgres -d creativity -c 10 -T 60 > /shared/performance_old_db.txt
   
   # 관리형 DB 성능 테스트  
   pgbench -h <managed_db_endpoint> -U <admin_user> -d creativity -c 10 -T 60 > /shared/performance_managed_db.txt
   ```

3. **상세 성능 분석**

   ```bash
   # 쿼리 성능 분석 스크립트
   cat > /shared/query_performance_test.sql << 'EOF'
   \timing on
   
   -- 복잡한 JOIN 쿼리 테스트
   SELECT u.username, COUNT(p.id) as project_count 
   FROM users u 
   LEFT JOIN projects p ON u.id = p.user_id 
   GROUP BY u.username 
   ORDER BY project_count DESC 
   LIMIT 100;
   
   -- 집계 쿼리 테스트
   SELECT DATE(created_at) as date, COUNT(*) as daily_users 
   FROM users 
   WHERE created_at >= NOW() - INTERVAL '30 days' 
   GROUP BY DATE(created_at) 
   ORDER BY date;
   
   -- 인덱스 스캔 테스트
   SELECT * FROM projects WHERE status = 'active' AND created_at > NOW() - INTERVAL '7 days';
   EOF
   ```

4. **성능 최적화 실습**

   ```sql
   -- 인덱스 최적화
   CREATE INDEX CONCURRENTLY idx_projects_status_created 
   ON projects(status, created_at) 
   WHERE status = 'active';
   
   -- 통계 정보 업데이트
   ANALYZE projects;
   ANALYZE users;
   
   -- 연결 풀 설정 최적화
   SHOW max_connections;
   SHOW shared_buffers;
   ```

**학습 포인트**:

- 성능 벤치마크 도구 사용법
- 쿼리 최적화 기법
- 관리형 DB의 성능 특성 이해

---

### 시나리오 4: 고가용성 및 재해복구 실습 (난이도: 고급)

**목표**: 관리형 DB의 HA/DR 기능 활용

**실습 단계**:

1. **백업 및 복원 정책 설정**

   ```bash
   # 자동 백업 설정 확인
   # (포털에서 백업 정책 확인 및 수정)
   
   # 수동 스냅샷 생성
   # (포털에서 수동 스냅샷 생성 실습)
   
   # Point-in-Time Recovery 테스트 준비
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity -c "
   INSERT INTO test_recovery (created_at, data) VALUES (NOW(), 'Before failure simulation');
   "
   ```

2. **장애 시뮬레이션**

   ```bash
   # 잘못된 데이터 입력 시뮬레이션
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity << 'EOF'
   -- 실수로 중요 데이터 삭제
   DELETE FROM users WHERE created_at > '2024-01-01';
   
   -- 타임스탬프 기록
   INSERT INTO incident_log VALUES (NOW(), 'Accidental data deletion occurred');
   EOF
   ```

3. **Point-in-Time Recovery 실행**

   ```bash
   # 복구 시점 결정 (포털에서 실행)
   # 1. 백업 목록에서 복구 시점 선택
   # 2. 새 인스턴스로 복구 또는 기존 인스턴스 복구 선택
   # 3. 복구 진행 상황 모니터링
   ```

4. **Multi-AZ 설정 및 테스트**

   ```bash
   # Multi-AZ 설정 후 장애 조치 테스트
   # (포털에서 장애 조치 강제 실행)
   
   # 연결 테스트 스크립트
   cat > /shared/connection_test.sh << 'EOF'
   #!/bin/bash
   while true; do
     if psql -h <managed_db_endpoint> -U <admin_user> -d creativity -c "SELECT NOW();" > /dev/null 2>&1; then
       echo "$(date): Connected successfully"
     else
       echo "$(date): Connection failed"
     fi
     sleep 5
   done
   EOF
   ```

**학습 포인트**:

- 자동화된 백업 및 복원 절차
- Point-in-Time Recovery 실행
- Multi-AZ 고가용성 아키텍처 이해

---

### 시나리오 5: 보안 강화 및 모니터링 실습 (난이도: 고급)

**목표**: 관리형 DB의 보안 설정 및 모니터링 구성

**실습 단계**:

1. **네트워크 보안 설정**

   ```bash
   # VPC Security Group 규칙 검토
   # (포털에서 DB 전용 Security Group 생성)
   
   # SSL 연결 강제 설정
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity -c "
   ALTER SYSTEM SET ssl = on;
   ALTER SYSTEM SET ssl_ca_file = '/etc/ssl/certs/ca-certificates.crt';
   "
   ```

2. **사용자 권한 관리**

   ```sql
   -- 역할 기반 접근 제어 설정
   CREATE ROLE app_read;
   GRANT CONNECT ON DATABASE creativity TO app_read;
   GRANT USAGE ON SCHEMA public TO app_read;
   GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_read;
   
   CREATE ROLE app_write;
   GRANT app_read TO app_write;
   GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_write;
   
   -- 애플리케이션별 사용자 생성
   CREATE USER web_user WITH PASSWORD 'web_secure_password' IN ROLE app_read;
   CREATE USER app_user WITH PASSWORD 'app_secure_password' IN ROLE app_write;
   ```

3. **감사 로그 설정**

   ```sql
   -- 감사 대상 설정
   ALTER SYSTEM SET log_statement = 'all';
   ALTER SYSTEM SET log_min_duration_statement = 1000; -- 1초 이상 쿼리만
   ALTER SYSTEM SET log_connections = on;
   ALTER SYSTEM SET log_disconnections = on;
   ```

4. **모니터링 대시보드 구성**

   ```bash
   # 모니터링 스크립트 작성
   cat > /shared/db_monitoring.sh << 'EOF'
   #!/bin/bash
   
   echo "=== Database Monitoring Report $(date) ==="
   
   # 연결 수 확인
   echo "Active connections:"
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity -t -c "
   SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';
   "
   
   # 느린 쿼리 확인
   echo "Long running queries:"
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity -c "
   SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
   FROM pg_stat_activity 
   WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes' 
   AND state = 'active';
   "
   
   # 데이터베이스 크기 확인
   echo "Database size:"
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity -c "
   SELECT pg_size_pretty(pg_database_size('creativity')) as db_size;
   "
   
   # 테이블별 크기 확인
   echo "Top 5 largest tables:"
   psql -h <managed_db_endpoint> -U <admin_user> -d creativity -c "
   SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
   FROM pg_tables 
   WHERE schemaname = 'public'
   ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
   LIMIT 5;
   "
   EOF
   
   chmod +x /shared/db_monitoring.sh
   
   # Cron 작업으로 등록
   echo "*/15 * * * * /shared/db_monitoring.sh >> /shared/db_monitor.log 2>&1" | crontab -
   ```

**학습 포인트**:

- 데이터베이스 보안 모범 사례
- SSL/TLS 연결 설정
- 포괄적인 모니터링 체계 구축

---

### 시나리오 6: 애플리케이션 연동 및 DNS 전환 실습 (난이도: 중급)

**목표**: 애플리케이션 코드 수정 없이 DNS 기반으로 데이터베이스 전환

**실습 단계**:

1. **DNS 레코드 준비**

   ```bash
   # 현재 DNS 레코드 확인
   nslookup db.${private_domain_name}
   
   # 새로운 DNS 레코드 생성 (관리형 DB용)
   # db-new.${private_domain_name} -> <managed_db_endpoint>
   ```

2. **연결 문자열 표준화**

   ```javascript
   // /shared/database_config.js
   const config = {
     development: {
       host: 'db.${private_domain_name}',
       port: 2866,
       database: 'creativity',
       user: process.env.DB_USER,
       password: process.env.DB_PASSWORD,
       ssl: false
     },
     production: {
       host: 'db-new.${private_domain_name}', // 관리형 DB 엔드포인트
       port: 5432,
       database: 'creativity', 
       user: process.env.DB_USER,
       password: process.env.DB_PASSWORD,
       ssl: true,
       sslmode: 'require'
     }
   };
   ```

3. **점진적 DNS 전환**

   ```bash
   # DNS TTL 단축 (사전 작업)
   # 현재: db.${private_domain_name} TTL 300 -> TTL 60으로 변경
   
   # Phase 1: 새 DNS 엔드포인트 생성
   # db-new.${private_domain_name} -> <managed_db_endpoint>
   
   # Phase 2: 애플리케이션에서 새 엔드포인트 테스트
   psql -h db-new.${private_domain_name} -U app_user -d creativity -c "SELECT version();"
   
   # Phase 3: 기존 DNS 레코드 업데이트
   # db.${private_domain_name} -> <managed_db_endpoint>
   
   # Phase 4: 구 DNS 레코드 정리
   # db-old.${private_domain_name} -> 기존 DB (백업 목적)
   ```

4. **연결 테스트 자동화**

   ```bash
   # 전환 중 연결 상태 모니터링
   cat > /shared/dns_switchover_test.sh << 'EOF'
   #!/bin/bash
   
   echo "Testing database connections during DNS switchover..."
   
   # 기존 DB 연결 테스트
   if psql -h db-old.${private_domain_name} -U postgres -d creativity -c "SELECT 'OLD DB CONNECTED' as status;" 2>/dev/null; then
     echo "✓ Old DB connection successful"
   else
     echo "✗ Old DB connection failed"
   fi
   
   # 새 DB 연결 테스트  
   if psql -h db-new.${private_domain_name} -U app_user -d creativity -c "SELECT 'NEW DB CONNECTED' as status;" 2>/dev/null; then
     echo "✓ New DB connection successful"
   else
     echo "✗ New DB connection failed"  
   fi
   
   # 현재 활성 DNS 확인
   echo "Current DNS resolution for db.${private_domain_name}:"
   nslookup db.${private_domain_name}
   
   # 애플리케이션 연결 테스트
   echo "Testing application connectivity..."
   curl -f http://www.${private_domain_name}/api/health 2>/dev/null && echo "✓ App healthy" || echo "✗ App unhealthy"
   EOF
   
   chmod +x /shared/dns_switchover_test.sh
   ```

**학습 포인트**:

- DNS 기반 서비스 전환 전략
- 무중단 서비스 전환 기법
- 롤백 계획 및 실행 방법

---

### 시나리오 7: 데이터 일관성 검증 및 동기화 실습 (난이도: 고급)

**목표**: 마이그레이션 후 데이터 일관성 보장 및 검증

**실습 단계**:

1. **데이터 검증 도구 개발**

   ```bash
   cat > /shared/data_consistency_check.py << 'EOF'
   #!/usr/bin/env python3
   import psycopg2
   import sys
   from datetime import datetime
   
   # 데이터베이스 연결 설정
   old_db_config = {
       'host': 'db-old.${private_domain_name}',
       'port': 2866,
       'database': 'creativity',
       'user': 'postgres',
       'password': 'your_password'
   }
   
   new_db_config = {
       'host': 'db-new.${private_domain_name}', 
       'port': 5432,
       'database': 'creativity',
       'user': 'app_user',
       'password': 'your_password'
   }
   
   def compare_table_counts(table_name):
       """테이블 행 수 비교"""
       try:
           # 기존 DB 연결
           old_conn = psycopg2.connect(**old_db_config)
           old_cur = old_conn.cursor()
           old_cur.execute(f"SELECT COUNT(*) FROM {table_name}")
           old_count = old_cur.fetchone()[0]
           old_conn.close()
           
           # 새 DB 연결  
           new_conn = psycopg2.connect(**new_db_config)
           new_cur = new_conn.cursor()
           new_cur.execute(f"SELECT COUNT(*) FROM {table_name}")
           new_count = new_cur.fetchone()[0]
           new_conn.close()
           
           print(f"Table {table_name}: Old DB = {old_count}, New DB = {new_count}")
           return old_count == new_count
           
       except Exception as e:
           print(f"Error comparing {table_name}: {e}")
           return False
   
   def compare_checksums(table_name, key_column):
       """체크섬 기반 데이터 무결성 검증"""
       try:
           checksum_query = f"SELECT MD5(STRING_AGG(MD5(CAST({key_column} AS TEXT)), '')) FROM {table_name}"
           
           # 기존 DB 체크섬
           old_conn = psycopg2.connect(**old_db_config)
           old_cur = old_conn.cursor()
           old_cur.execute(checksum_query)
           old_checksum = old_cur.fetchone()[0]
           old_conn.close()
           
           # 새 DB 체크섬
           new_conn = psycopg2.connect(**new_db_config)
           new_cur = new_conn.cursor() 
           new_cur.execute(checksum_query)
           new_checksum = new_cur.fetchone()[0]
           new_conn.close()
           
           print(f"Checksum {table_name}: Old = {old_checksum}, New = {new_checksum}")
           return old_checksum == new_checksum
           
       except Exception as e:
           print(f"Error checking checksum for {table_name}: {e}")
           return False
   
   # 메인 검증 로직
   if __name__ == "__main__":
       tables_to_check = ['users', 'projects', 'user_projects']
       
       print(f"=== Data Consistency Check - {datetime.now()} ===")
       
       all_consistent = True
       
       for table in tables_to_check:
           count_match = compare_table_counts(table)
           checksum_match = compare_checksums(table, 'id')
           
           if not (count_match and checksum_match):
               all_consistent = False
               print(f"❌ {table}: Inconsistent data detected")
           else:
               print(f"✅ {table}: Data consistent")
       
       if all_consistent:
           print("\n🎉 All tables are consistent!")
           sys.exit(0)
       else:
           print("\n⚠️  Data inconsistencies found!")
           sys.exit(1)
   EOF
   
   chmod +x /shared/data_consistency_check.py
   ```

2. **실시간 동기화 모니터링**

   ```bash
   # 동기화 지연 모니터링 스크립트
   cat > /shared/sync_lag_monitor.sh << 'EOF'
   #!/bin/bash
   
   # 마지막 업데이트 타임스탬프 비교
   echo "=== Sync Lag Monitoring $(date) ==="
   
   # 기존 DB 최신 레코드
   OLD_LATEST=$(psql -h db-old.${private_domain_name} -U postgres -d creativity -t -c "
   SELECT MAX(updated_at) FROM users;
   " | xargs)
   
   # 새 DB 최신 레코드  
   NEW_LATEST=$(psql -h db-new.${private_domain_name} -U app_user -d creativity -t -c "
   SELECT MAX(updated_at) FROM users; 
   " | xargs)
   
   echo "Old DB latest update: $OLD_LATEST"
   echo "New DB latest update: $NEW_LATEST"
   
   # 시간 차이 계산 (초 단위)
   OLD_EPOCH=$(date -d "$OLD_LATEST" +%s 2>/dev/null || echo 0)
   NEW_EPOCH=$(date -d "$NEW_LATEST" +%s 2>/dev/null || echo 0)
   LAG=$((OLD_EPOCH - NEW_EPOCH))
   
   if [ $LAG -gt 300 ]; then
       echo "⚠️  High sync lag detected: ${LAG} seconds"
   elif [ $LAG -gt 60 ]; then
       echo "⚡ Moderate sync lag: ${LAG} seconds" 
   else
       echo "✅ Sync lag acceptable: ${LAG} seconds"
   fi
   EOF
   
   chmod +x /shared/sync_lag_monitor.sh
   ```

3. **데이터 복구 시뮬레이션**

   ```sql
   -- 복구 테스트 시나리오 생성
   CREATE TABLE migration_test (
       id SERIAL PRIMARY KEY,
       test_data TEXT,
       created_at TIMESTAMP DEFAULT NOW()
   );
   
   -- 테스트 데이터 삽입
   INSERT INTO migration_test (test_data) VALUES 
   ('Test data 1'), ('Test data 2'), ('Test data 3');
   
   -- 'delete_me' 마커로 삭제 대상 표시
   UPDATE migration_test SET test_data = 'delete_me' WHERE id = 2;
   
   -- 복구 검증용 체크포인트 생성
   INSERT INTO migration_checkpoints (checkpoint_name, created_at, description)
   VALUES ('pre_deletion_test', NOW(), 'Before deletion test for recovery validation');
   ```

**학습 포인트**:

- 자동화된 데이터 검증 도구 개발
- 실시간 동기화 상태 모니터링
- 데이터 불일치 감지 및 복구 절차

---

## 추가 실습 시나리오 아이디어

### 시나리오 8: 성능 튜닝 및 최적화 심화 (난이도: 고급)

- **내용**: Connection Pooling, Query 최적화, 인덱스 전략
- **도구**: pgbouncer, pg_stat_statements, EXPLAIN ANALYZE

### 시나리오 9: 멀티 리전 복제 실습 (난이도: 고급)

- **내용**: 지리적 분산 환경에서의 데이터 복제
- **구성**: Primary-Replica 아키텍처, 읽기 분산

### 시나리오 10: 데이터 웨어하우스 통합 (난이도: 중급)

- **내용**: 운영 DB에서 분석 DB로 ETL 파이프라인 구성
- **도구**: Data Pipeline, Scheduled Jobs

### 시나리오 11: 컴플라이언스 및 감사 (난이도: 중급)

- **내용**: 데이터 보호 규정 준수, 접근 로그 분석
- **구성**: 감사 로그 수집, 보고서 자동 생성

### 시나리오 12: 비용 최적화 분석 (난이도: 초급)

- **내용**: 자체 관리 vs 관리형 서비스 비용 분석
- **도구**: 비용 계산 도구, 리소스 사용량 모니터링

## 결론

이 실습 시나리오들을 통해 수강자들은 다음과 같은 핵심 역량을 습득할 수 있습니다:

1. **실무 중심의 마이그레이션 경험**: 실제 운영 환경에서 발생할 수 있는 다양한 상황들을 미리 경험
2. **문제 해결 능력 향상**: 각 시나리오별로 발생할 수 있는 문제점들과 해결 방법 학습
3. **자동화 및 모니터링 기술**: 반복적인 작업의 자동화와 지속적인 모니터링 체계 구축
4. **보안 및 컴플라이언스 이해**: 엔터프라이즈 환경에서 요구되는 보안 요구사항 충족 방법
5. **성능 최적화 기법**: 데이터베이스 성능 분석, 튜닝, 최적화 방법론

각 시나리오는 독립적으로 실행 가능하며, 수강자의 수준과 관심사에 따라 선택적으로 진행할 수 있도록 설계되었습니다.

[//]: # (Current Directory Structure)
[//]: # (D:\scpv2\advance_ha\database_service\)
[//]: # (├── lab_logs\                          # 로그 및 임시 파일 저장소)
[//]: # (│   ├── deployment_YYYYMMDD_HHMMSS.log # 메인 배포 로그)
[//]: # (│   ├── logs.log                       # 변경사항 추적 로그)
[//]: # (│   ├── tf_deployment_XX.log           # Terraform API 로그)
[//]: # (│   └── terraform.tfplan               # Terraform 실행 계획)
[//]: # (├── scripts\                           # 배포 스크립트 모음)
[//]: # (│   ├── variables.json                 # 변수 JSON 파일)
[//]: # (│   ├── install_putty.ps1              # PuTTY 설치 스크립트)
[//]: # (│   ├── variables_manager.ps1          # 변수 관리자)
[//]: # (│   ├── userdata_manager.ps1           # UserData 생성 관리자)
[//]: # (│   ├── terraform_manager.ps1          # Terraform 배포 관리자)
[//]: # (│   ├── userdata_template_base.sh      # UserData 베이스 템플릿)
[//]: # (│   ├── master_config.json.tpl         # 마스터 설정 템플릿)
[//]: # (│   ├── modules\                       # 서버별 설치 모듈)
[//]: # (│   │   ├── web_server_module.sh       # 웹서버 설치 모듈)
[//]: # (│   │   ├── app_server_module.sh       # 앱서버 설치 모듈)
[//]: # (│   │   └── db_server_module.sh        # DB서버 설치 모듈)
[//]: # (│   ├── generated_userdata\            # 생성된 UserData 스크립트)
[//]: # (│   │   ├── userdata_web.sh            # 웹서버 UserData)
[//]: # (│   │   ├── userdata_app.sh            # 앱서버 UserData)
[//]: # (│   │   └── userdata_db.sh             # DB서버 UserData)
[//]: # (│   └── emergency_scripts\             # 응급 복구 스크립트)
[//]: # (│       ├── emergency_web.sh           # 웹서버 응급 복구)
[//]: # (│       ├── emergency_app.sh           # 앱서버 응급 복구)
[//]: # (│       └── emergency_db.sh            # DB서버 응급 복구)
[//]: # (├── deploy_lab_env.ps1                 # 메인 배포 오케스트레이터)
[//]: # (├── main.tf                            # Terraform 메인 구성)
[//]: # (├── variables.tf                       # Terraform 변수 정의)
[//]: # (└── terraform.tfstate                  # Terraform 상태 파일)
