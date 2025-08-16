# 고가용성 3계층 아키텍처 구성

## 실습 준비
- Key Pair, 인증키, DNS 사전 준비 필요 ([과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md) 참조)
- Terraform을 처음 접하시는 분은 '[Terraform을 이용한 인프라 구성 자동화](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)' 차시 참고
- Terraform으로 실습 환경 구성

```
terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```

## DNS 설정

### Private DNS
```
Private DNS Name : cesvc
VPC              : VPC1
Hosted Zone      : cesvc.net
www              : A 레코드, 10.1.1.111, 300
app              : A 레코드, 10.1.2.121, 300
db               : A 레코드, 10.1.3.131, 300
```
Public Domain Name
```
등록할 Hosted Zone명 : your.domain.name.net    # 과정소개에서 생성한 Public Domain명
www                 : A 레코드, web server 또는 web load balancer IP 주소, 300 
```

## 통신 제어 규칙 구성

### Firewall
|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|IGW|10.1.1.110, 10.1.1.111,<br> 10.1.2.121, 10.1.3.131|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vms to Internet|
|Terraform|IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Manual|IGW|Your Public IP|10.1.1.111|TCP 80|Allow|Inbound|HTTP inbound to web vm|

### Security Group
|Deployment|Security Group|Direction|Target Address<br>Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terrafom|bastionSG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terrafom|bastionSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|bastionSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Manual|bastionSG|Outbound|dbSG|TCP 22|SSH outbound to db vm |
|Manual|bastionSG|Outbound|webSG|TCP 22|SSH outbound to web vm |
|Manual|bastionSG|Outbound|appSG|TCP 22|SSH outbound to app vm |
|||||||
|Terrafom|webSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|webSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Manual|webSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Manual|webSG|Inbound|Your Public IP|TCP 80|HTTP inbound from your PC|
|Manual|webSG|Outbound|appSG|TCP 3000|API outbound to app vm |
|Manual|webSG|Inbound|bastionSG|TCP 80|HTTP inbound from bastion|
|||||||
|Terrafom|appSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terrafom|appSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Manual|appSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Manual|appSG|Outbound|dbSG|TCP 2866|db connection outbound to db vm |
|Manual|appSG|Inbound|webSG|TCP 3000|API inbound from web vm |
|||||||
|Terrafom|dbSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terrafom|dbSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Manual|dbSG|Inbound|appSG|TCP 2866|db connection inbound from app vm |
|Manual|dbSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|

## Bastion Host에 RDP 접속

 - Putty 설치(install_putty.ps1)
 - 인증키(mykey.ppk)를 bastion으로 복사
 - web, app, db vm에 SSH 접속


### Security Group
|Deployment|Security Group|Direction|Target Address<br>Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Manual|bastionSG|Outbound|dbSG|TCP 22|SSH outbound to db vm |
|Manual|bastionSG|Outbound|webSG|TCP 22|SSH outbound to web vm |
|Manual|bastionSG|Outbound|appSG|TCP 22|SSH outbound to app vm |
|||||||
|Manual|webSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|||||||
|Manual|appSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|||||||
|Manual|dbSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|

## 데이터베이스 서버 설치 (PostgreSQL 16.8)
```bash

cd /home/rocky/

git clone https://github.com/SCPv2/ceweb.git

sudo bash /home/rocky/ceweb/db-server/vm_db/install_postgresql_vm.sh

```

## 애플리케이션 서버 설치 (node.js 2.0)

```bash

cd /home/rocky/

git clone https://github.com/SCPv2/ceweb.git

sudo bash /home/rocky/ceweb/app-server/install_app_server.sh

```

## 웹 서버 설치 (Nginx)

```bash

cd /home/rocky/

git clone https://github.com/SCPv2/ceweb.git

sudo bash /home/rocky/ceweb/web-server/install_web_server.sh
```
