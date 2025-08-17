# 고가용성을 위한 File Storage 구성

## 실습 준비
'[고가용성 3계층 아키텍처 구성](../3_tier_architecture/README.md)' 에서 이어지는 실습입니다.

## File Storage 생성
```console
볼륨명 : cefs
디스크 유형 : HDD
프로토콜 : NFS
```

## 


### Public Domain Name 확인
```
등록할 Hosted Zone명 : your.domain.name.net    # 과정소개에서 생성한 Public Domain명
www                 : A 레코드, web server 또는 web load balancer IP 주소, 300 
```

## 기본 구성된 통신제어 규칙

### Firewall
|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|IGW|10.1.1.110, 10.1.1.111,<br> 10.1.2.121, 10.1.3.131|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vms to Internet|
|Terraform|IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Add|IGW|Your Public IP|10.1.1.111|TCP 80|Allow|Inbound|HTTP inbound to web vm|

### Security Group
|Deployment|Security Group|Direction|Target Address<br>Remote SG|Service|Description|
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

## Bastion Host에 RDP 접속

 - Putty 설치(install_putty.ps1) 및 구성(Pageant에 키 로드, Connection>SSH>Auth>Allow agent Forwarding 체크)
 - 인증키(mykey.ppk)를 bastion으로 복사
 - web, app, db vm에 SSH 접속을 위한 Security Group 구성

## 데이터베이스 서버 설치 (PostgreSQL 16.8)
```bash
sudo dnf update -y
sudo dnf install git -y
cd /home/rocky/
git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/db-server/vm_db/
sudo bash install_postgresql_vm.sh
```

## 애플리케이션 서버 설치 (node.js 2.0)

```bash
sudo dnf update -y
sudo dnf install git -y
cd /home/rocky/
git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/app-server/
sudo bash install_app_server.sh
```

## 웹 서버 설치 (Nginx)

```bash
sudo dnf update -y
sudo dnf install git -y
cd /home/rocky/
git clone https://github.com/SCPv2/ceweb.git
cd /home/rocky/ceweb/web-server/
sudo bash install_web_server.sh
```

# 고가용성  서버 구성 작업

## webvm, appvm 이미지 생성 및 서버 생성
```
webvm image : webvm111r-img
appvm image : appvm121r-img
```
## web Load Balancer 생성

```
Load Balancer명: weblb
서비스 구분 :  L4
VPC : VPC1
Service Subnet : Subnet11
Sevice IP      : 10.1.1.100
Public NAT IP  : 사용
Firewall 사용   : 사용
Firewall 로그 저장 여부 : 사용
```
## web LB 서버 그룹 생성
```
LB 서버 그룹명 : weblbgrp
VPC           : VPC1
Service Subnet : Subnet11
부하 분산 : Round Robin
프로토콜 : TCP
LB 헬스 체크 : HTTP_Default_Port80

연결된 자원 : webvm111r, webvm112r
가중치 : 1
```
## web Listener 생성
```
Listener명 : weblistener
프로토콜 : TCP
서비스 포트 : 80
LB 서버 그룹 : weblbgrp
세션 유지 시간 : 120초
지속성 : 소스 IP
Insert Client IP : 미사용
```

## app Load Balancer 생성
```
Load Balancer명 : applb
서비스 구분 :  L4
VPC : VPC1
Service Subnet : Subnet12
Sevice IP : 10.1.2.100
Public NAT IP : 사용 안함
Firewall 사용 : 사용
Firewall 로그 저장 여부 : 사용
```
## app 헬스 체크 생성
```
LB 헬스 체크명: app_healthcheck
VPC : VPC1
Service Subnet : Subnet12
헬스 체크 방식 
프로토콜 : TCP
헬스 체크 포트 : 3000
주기 : 5
대기 시간 : 5
탐지 횟수 : 3
```
## app LB 서버 그룹
```
LB 서버 그룹명 : applbgrp
VPC           : VPC1
Service Subnet : Subnet12
부하 분산 : Round Robin
프로토콜 : TCP
LB 헬스 체크 : Happ_healthcheck

연결된 자원 : appvm121r, appvm122r
가중치 : 1
```
## web Listener 생성
```
Listener명 : applistener
프로토콜 : TCP
서비스 포트 : 3000
LB 서버 그룹 : applbgrp
세션 유지 시간 : 120초
지속성 : 소스 IP
Insert Client IP : 미사용
```


## Firewall 구성
|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Delete|IGW|Your Public IP|10.1.1.111|TCP 80|Allow|Inbound|HTTP inbound to web vm|
|Add|IGW|Your Public IP|10.1.1.100<br>(Service IP)|TCP 80|Allow|Inbound|클라이언트 → LB 연결|
|Add|web Load Balancer|Your Public IP|10.1.1.100<br>(Service IP)|TCP 80|Allow|Outbound|클라이언트 → LB 연결|
|Add|web Load Balancer|webLB Source NAT IP|10.1.1.111, 10.1.1.112<br>(webvm IP)|TCP 80|Allow|Inbound|LB → 멤버 연결|
|Add|web Load Balancer|webLB 헬스 체크 IP|10.1.1.111, 10.1.1.112<br>(webvm IP)|TCP 80|Allow|Inbound|LB → 멤버 헬스 체크|
|Add|app Load Balancer|10.1.1.111, 10.1.1.112<br>(webvm IP)|10.1.2.100<br>(Service IP)|3000|Allow|Outbound|클라이언트 → LB 연결|
|Add|app Load Balancer|appLB Source NAT IP|10.1.2.121, 10.1.2.122<br>(appvm IP)|3000|Allow|Inbound|LB → 멤버 연결|
|Add|app Load Balancer|appLB 헬스 체크 IP|10.1.2.121, 10.1.2.122<br>(appvm IP)|3000|Allow|Inbound|LB → 멤버 헬스 체크|

## Security Group 구성
|Deployment|Security Group|Direction|Target Address<br>Remote SG|Service|Description|
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
```
www : 10.1.1.100 (webLB Service IP)
app : 10.1.2.100 (appLB Service IP)
```