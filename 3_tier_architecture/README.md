# 고가용성 3계층 아키텍처 구성

## 선행 실습

### 선택 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

## 실습 환경 배포

**&#128906; 사용자 변수 입력 (\load_balancing\variables.tf)**

```hcl
variable "user_public_ip" {
  type        = string
  description = "Public IP address of user PC"
  default     = "x.x.x.x"                           # 수강자 PC의 Public IP 주소 입력
}
```

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
cd C:\scpv2advance\advance_ha\3_tier_architecture\
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

### vm 접속

**&#128906; Bastion Host RDP 접속**

**&#128906; web, app, db vm SSH 접속**

### 데이터베이스 서버 설치 (PostgreSQL 16.8)

```bash
sudo dnf update -y
sudo dnf install git -y
cd /home/rocky/
git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/db-server/vm_db/
sudo bash install_postgresql_vm.sh
```

### 애플리케이션 서버 설치 (node.js 2.0)

```bash
sudo dnf update -y
sudo dnf install git -y
cd /home/rocky/
git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/app-server/
sudo bash install_app_server.sh
```

### 웹 서버 설치 (Nginx)

```bash
sudo dnf update -y
sudo dnf install git -y
cd /home/rocky/
git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/web-server/
sudo bash install_web_server.sh
```

## 고가용성을 위한 서버 이중화

### webvm, appvm 이미지 생성 및 서버 생성

- webvm image : webvm111r-img
- appvm image : appvm121r-img

### web Load Balancer 생성

- Load Balancer명: weblb

- 서비스 구분 :  L4
- VPC : VPC1
- Service Subnet : Subnet11
- Sevice IP      : 10.1.1.100
- Public NAT IP  : 사용
- Firewall 사용   : 사용
- Firewall 로그 저장 여부 : 사용

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

## 자원 삭제

이번 Chapter는 차시별 작업이 다음 차시로 계속 이어집니다. 자원 삭제가 필요한 경우 아래 작업을 수행하십시오.

### Load Balancer 삭제

### webvn112r, appvm212r 삭제

### Public IP 삭제

### 자동 배포 자원 삭제

```bash
cd C:\scpv2advance\advance_networking\vpn\scp_deployment
terraform destroy --auto-approve
```
