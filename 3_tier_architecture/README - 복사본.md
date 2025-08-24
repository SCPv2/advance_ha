# 기본 3계층 아키텍처 구성

## 실습 개요

이 실습은 Samsung Cloud Platform v2에서 기본 3계층 아키텍처(Web-App-DB)를 배포하여 Infrastructure as Code의 기본 개념을 학습하고, 향후 고가용성 구성으로 확장할 수 있는 기반을 마련하는 것을 목표로 합니다.

### 아키텍처 특징
- **기본 구성**: 각 계층당 1대씩 구성 (단일 서버)
- **수동 설치**: 교육적 가치를 위한 단계별 수동 설치 방식
- **중앙화된 설정**: master_config.json을 통한 설정 관리
- **확장성**: file_storage 템플릿으로 고가용성 구성 업그레이드 가능

## 선행 실습

### 필수 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair 생성 및 다운로드
- Private DNS Hosted Zone 등록
- 사용자 PC Public IP 확인
- (선택사항) Public DNS Hosted Zone 등록

### 권장 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습
- Infrastructure as Code 개념 이해

## 실습 환경 배포

**&#128906; 사용자 변수 입력 (variables.tf)**

반드시 다음 변수들을 실제 값으로 수정해야 합니다:

```hcl
# 필수 수정 항목
variable "user_public_ip" {
  default = "x.x.x.x"        # 사용자 PC의 Public IP 주소
}

variable "keypair_name" {
  default = "mykey"          # 생성한 Key Pair 이름
}

variable "private_domain_name" {
  default = "cesvc.net"      # Private DNS 도메인명
}

variable "private_hosted_zone_id" {
  default = "9fa4151c-0dc8-4397-a22c-9797c3026cd2"  # Private Hosted Zone ID
}

# 선택 수정 항목 (Public 도메인 사용시)
variable "public_domain_name" {
  default = "cosmetic-evolution.net"  # Public DNS 도메인명 (선택사항)
}
```

**💡 참고사항:**
- Object Storage 관련 변수는 기본 3-tier에서 불필요하므로 생략
- 모든 파일은 로컬 디렉토리(`/home/rocky/ceweb/media/`)에 저장
- Public 도메인은 외부 접근이 필요한 경우에만 설정

**&#128906; PowerShell 자동 배포 스크립트 실행 (권장)**

```powershell
cd C:\Users\dion\.local\bin\scpv2\advance_ha\3_tier_architecture\
.\terraform_deploy_safe.ps1
```

**&#128906; 수동 Terraform 명령어 실행 (대안)**

```bash
cd C:\Users\dion\.local\bin\scpv2\advance_ha\3_tier_architecture\
terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

**&#128906; 배포 진행 상황 확인**

- PowerShell 스크립트는 자동으로 master_config.json을 생성합니다
- 약 10-15분 소요됩니다 (VM 생성 및 초기화 시간 포함)
- 각 VM에서 userdata 실행 로그는 `/var/log/userdata_*.log`에서 확인 가능

## 환경 검토

- Architectuer Diagram
- VPC CIDR
- Subnet CIDR
- Virtual Server OS, Public IP, Private IP
- Firewall 규칙
- Security Group 규칙

### Firewall

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|IGW|10.1.1.110, 10.1.1.111, 10.1.2.121, 10.1.3.131|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vms to Internet|
|Terraform|IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Add|IGW|Your Public IP|10.1.1.111|TCP 80|Allow|Inbound|HTTP inbound to web vm|

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
|Add|webSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Add|webSG|Inbound|Your Public IP|TCP 80|HTTP inbound from your PC|
|Add|webSG|Outbound|appSG|TCP 3000|API outbound to app vm |
|Add|webSG|Inbound|bastionSG|TCP 80|HTTP inbound from bastion|
|||||||
|Terrafom|appSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|appSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Add|appSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Add|appSG|Outbound|dbSG|TCP 2866|db connection outbound to db vm |
|Add|appSG|Inbound|webSG|TCP 3000|API inbound from web vm |
|||||||
|Terrafom|dbSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|dbSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Add|dbSG|Inbound|appSG|TCP 2866|db connection inbound from app vm |
|Add|dbSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|

### Load Balancer용 Public IP 예약

- 구분 : Internet Gateway

### Private DNS 확인 - VPC1에 연결

- Private DNS Name : cesvc
- VPC              : VPC1
- Hosted Zone      : cesvc.net
- www              : A 레코드, 10.1.1.111, 300
- app              : A 레코드, 10.1.2.121, 300
- db               : A 레코드, 10.1.3.131, 300

### Public Domian Name 확인

- Public Domain Name: '[과정소개](https://github.com/SCPv2/advance_introduction)'에서 등록한 도메인명
- Hosted Zone       : '[과정소개](https://github.com/SCPv2/advance_introduction)'에서 등록한 도메인명
- www               : A 레코드, 바로 앞에서 만든 Public IP, 300

## 서버 구성

### &#128906; VM 접속 및 Ready 파일 확인

**1. Bastion Host RDP 접속**
- Public IP를 통해 Windows RDP 접속 (3389 포트)
- terraform 실행 결과에서 Bastion Public IP 확인

**2. Linux VM들 SSH 접속 (Bastion을 통해)**
```bash
# Bastion에서 각 Linux VM으로 SSH 접속
ssh -i your-key.pem rocky@10.1.3.131  # DB 서버
ssh -i your-key.pem rocky@10.1.2.121  # App 서버
ssh -i your-key.pem rocky@10.1.1.111  # Web 서버
```

**3. Ready 파일 확인**
각 서버에서 설치 준비 상태 확인:
```bash
# 각 서버에서 ready 파일 확인
cat /home/rocky/z_ready2install_go2*-server

# 예시 출력:
# DB Server preparation completed: 2025-08-22
# Next step: Run 'sudo bash install_postgresql_vm.sh' in /home/rocky/ceweb/db-server/vm_db/
```

### &#128906; 순차적 서비스 설치 (수동)

**중요**: 반드시 DB → App → Web 순서로 설치해야 합니다.

**1. 데이터베이스 서버 설치 (PostgreSQL 16.8)**

```bash
# DB 서버 (10.1.3.131)에 SSH 접속 후
cd /home/rocky/ceweb/db-server/vm_db/
sudo bash install_postgresql_vm.sh

# 설치 완료 확인
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"
```

**2. 애플리케이션 서버 설치 (Node.js 20.x)**

```bash
# App 서버 (10.1.2.121)에 SSH 접속 후
cd /home/rocky/ceweb/app-server/
sudo bash install_app_server.sh

# 설치 완료 확인
curl http://localhost:3000/health
pm2 list
```

**3. 웹 서버 설치 (Nginx)**

```bash
# Web 서버 (10.1.1.111)에 SSH 접속 후
cd /home/rocky/ceweb/web-server/
sudo bash install_web_server.sh

# 설치 완료 확인
sudo systemctl status nginx
curl http://localhost/health
```

### &#128906; 서비스 접속 확인

**웹 애플리케이션 접속:**
- **직접 접속**: http://10.1.1.111/ (Web 서버 IP)
- **브라우저 테스트**: 사용자 PC에서 Web 서버로 직접 접속 가능
- **API 테스트**: http://10.1.1.111/api/orders/products

## 고가용성을 위한 확장 (선택사항)

이 기본 3-tier 아키텍처를 고가용성 구성으로 확장하는 방법을 안내합니다.

### &#128906; 1단계: 추가 서버 생성

**VM 이미지 생성:**
- Web 서버 이미지: webvm111r-img (webvm111r 기반)
- App 서버 이미지: appvm121r-img (appvm121r 기반)

**추가 VM 생성:**
- Web 서버 2호기: webvm112r (10.1.1.112)
- App 서버 2호기: appvm122r (10.1.2.122)

### &#128906; 2단계: Web Load Balancer 생성

**Load Balancer 기본 설정:**
- Load Balancer명: weblb
- 서비스 구분: L4
- VPC: VPC1
- Service Subnet: Subnet11 (10.1.1.0/24)
- Service IP: 10.1.1.100
- Public NAT IP: 사용
- Firewall 사용: 사용
- Firewall 로그 저장: 사용

### web LB 서버 그룹 생성

- LB 서버 그룹명 : weblbgrp
- VPC           : VPC1
- Service Subnet : Subnet11
- 부하 분산 : Round Robin
- 프로토콜 : TCP
- LB 헬스 체크 : HTTP_Default_Port80

- 연결된 자원 : webvm111r, webvm112r
- 가중치 : 1

### web Listener 생성

- Listener명 : weblistener

- 프로토콜 : TCP
- 서비스 포트 : 80
- LB 서버 그룹 : weblbgrp
- 세션 유지 시간 : 120초
- 지속성 : 소스 IP
- Insert Client IP : 미사용

### app Load Balancer 생성

- Load Balancer명 : applb

- 서비스 구분 :  L4
- VPC : VPC1
- Service Subnet : Subnet12
- Sevice IP : 10.1.2.100
- Public NAT IP : 사용 안함
- Firewall 사용 : 사용
- Firewall 로그 저장 여부 : 사용

### app 헬스 체크 생성

- LB 헬스 체크명: app_healthcheck
- VPC : VPC1
- Service Subnet : Subnet12
- 헬스 체크 방식
- 프로토콜 : TCP
- 헬스 체크 포트 : 3000
- 주기 : 5
- 대기 시간 : 5
- 탐지 횟수 : 3

### app LB 서버 그룹

- LB 서버 그룹명 : applbgrp
- VPC           : VPC1
- Service Subnet : Subnet12
- 부하 분산 : Round Robin
- 프로토콜 : TCP
- LB 헬스 체크 : Happ_healthcheck

- 연결된 자원 : appvm121r, appvm122r
- 가중치 : 1

### app Listener 생성

- Listener명 : applistener

- 프로토콜 : TCP
- 서비스 포트 : 3000
- LB 서버 그룹 : applbgrp
- 세션 유지 시간 : 120초
- 지속성 : 소스 IP
- Insert Client IP : 미사용

## 통신 제어 규칙 추가

### Firewall 구성

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Delete|IGW|Your Public IP|10.1.1.111|TCP 80|Allow|Inbound|HTTP inbound to web vm|
|Add|IGW|Your Public IP|10.1.1.100 (Service IP)|TCP 80|Allow|Inbound|클라이언트 → LB 연결|
|Add|web Load Balancer|Your Public IP|10.1.1.100 (Service IP)|TCP 80|Allow|Outbound|클라이언트 → LB 연결|
|Add|web Load Balancer|webLB Source NAT IP|10.1.1.111, 10.1.1.112 (webvm IP)|TCP 80|Allow|Inbound|LB → 멤버 연결|
|Add|web Load Balancer|webLB 헬스 체크 IP|10.1.1.111, 10.1.1.112 (webvm IP)|TCP 80|Allow|Inbound|LB → 멤버 헬스 체크|
|Add|app Load Balancer|10.1.1.111, 10.1.1.112 (webvm IP)|10.1.2.100 (Service IP)|3000|Allow|Outbound|클라이언트 → LB 연결|
|Add|app Load Balancer|appLB Source NAT IP|10.1.2.121, 10.1.2.122 (appvm IP)|3000|Allow|Inbound|LB → 멤버 연결|
|Add|app Load Balancer|appLB 헬스 체크 IP|10.1.2.121, 10.1.2.122 (appvm IP)|3000|Allow|Inbound|LB → 멤버 헬스 체크|

### Security Group 구성

|Deployment|Security Group|Direction|Target Address / Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Delete|webSG|Inbound|Your Public IP|TCP 80|HTTP inbound from your PC|
|Add|webSG|Inbound|webLB Source NAT IP|TCP 80|HTTP inbound from Load Balancer|
|Add|webSG|Inbound|webLB 헬스 체크 IP|TCP 80|Healthcheck HTTP inbound from Load Balancer|
|Delete|webSG|Outbound|appSG|3000|API connection outbound to app vm|
|Add|webSG|Outbound|appLB Service IP|3000|API connection outbound to app LB|
|||||||
|Delete|appSG|Inbound|webSG|3000|API connection inbound from web vm|
|Add|appSG|Inbound|appLB Source NAT IP|3000|API connection inbound from Load Balancer|
|Add|webSG|Inbound|appLB 헬스 체크 IP|3000|Healthcheck 3000 inbound from Load Balancer|

## DNS 변경

- www : 10.1.1.100 (webLB Service IP)
- app : 10.1.2.100 (appLB Service IP)

# appvm212r vm 애플리케이션 재기동 명령
```
cd /home/rocky/ceweb/app-server
pm2 start ecosystem.config.js
```

## 자원 삭제

실습 완료 후 비용 절약을 위해 생성된 자원을 정리합니다.

### &#128906; PowerShell 자동 삭제 (권장)

```powershell
cd C:\Users\dion\.local\bin\scpv2\advance_ha\3_tier_architecture\
terraform destroy --auto-approve
```

### &#128906; 수동 삭제 순서 (콘솔에서 수행시)

**고가용성 확장 구성이 있는 경우:**
1. Load Balancer 삭제 (weblb, applb)
2. 추가 VM 삭제 (webvm112r, appvm122r)
3. 추가 Public IP 삭제

**기본 자원 삭제:**
4. Virtual Servers 삭제 (bastionvm110w, webvm111r, appvm121r, dbvm131r)
5. NAT Gateway 삭제
6. Public IP 삭제
7. Security Group 삭제
8. VPC 삭제

### &#128906; 삭제 확인

```bash
# terraform state 확인
terraform show

# 삭제 완료 후 state 파일 정리
rm -f terraform.tfstate*
rm -f tfplan
rm -f master_config.json
```

### 학습 완료 및 다음 단계

**완료된 학습 목표:**
- ✅ Infrastructure as Code 기본 개념
- ✅ 3계층 아키텍처 구성 및 이해
- ✅ 중앙화된 설정 관리 (master_config.json)
- ✅ 단계별 서비스 설치 및 연동

**다음 단계 학습:**
- `file_storage` 템플릿을 통한 완전 자동화 및 고가용성 구성
- CI/CD 파이프라인 구축
- 모니터링 및 로그 관리
- 보안 강화 및 SSL 인증서 적용
