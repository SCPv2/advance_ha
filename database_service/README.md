# 고가용성 Database 서비스 구성

## 선행 실습

### 필수 '[고가용성 3계층 아키텍처 구성](../3_tier_architecture/README.md)

### 선택 '[고가용성 구현을 위한 File Storage 구성](../file_storage/README.md)'

## 실습 환경 배포

**&#128906; 사용자 환경 구성 (\advance_ha\database_service\env_setup.ps1)**

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

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
- 네트워크 : 서버별 설정
- VPC : VPC1
- VIP : 10.1.3.100
- Subnet : Subnet13
- 서버명 : cedbserver001
  - IP : 10.1.3.132
- 서버명 : cedbserver002
  - IP : 10.1.3.133
- IP 접근 제어 : 10.1.2.0/24, 10.1.1.110   # appVM의 서브넷 대역과 Bastion Host IP
- 유지 관리 기간 : 사용안함
- Database명 : cedb       # 이름 변경 불가
- Database 사용자명 : cedbadmin    # 이름 변경 불가
- Database 비밀번호 : cedbadmin123!   # 가급적 준수 필요
- Database Port번호 : 2866
- 백업 : 사용 안함
- Audit Log 설정 : 사용 안함
- Parameter : PostgreSQL Community 16 PISA Default
- Database Encoding : UTF-8
- DB Locale : C
- 시간대 : ASIA/SEOUL(GMT +9:00)

## 데이터 마이그레이션

- pgAdmin [다운로드](https://www.pgadmin.org/download/)

- 기존 데이터베이스(db.your_private_ip.net 또는 10.1.3.131) 연결 및 백업

- 새 데이터베이스(10.1.3.132) 연결 및 백업 데이터로 복구

## 데이터베이스 장애 테스트
