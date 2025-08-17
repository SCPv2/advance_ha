# 고가용성을 위한 File Storage 구성

## 실습 준비
'[고가용성 3계층 아키텍처 구성](../3_tier_architecture/README.md)' 에서 이어지는 실습입니다.

## File Storage 생성
```
볼륨명 : cefs
디스크 유형 : HDD
프로토콜 : NFS

<생성 후>
Mount명 : (예시) 10.10.10.10:/fie_storage       # 마운트 사용을 위해 기록
연결 자원 : webvm111r, webvm112r, appvm121r, appvm122r
```

## File Storage 연결
- 애플리케이션 서버1(appvm121r) 
```bash
# 스토리지 마이그레이션 준비
cd ~/ceweb         
mv files files_temp                         # 기존 데이터를 임시 장소로 이동(rocky로 실행)

# 마운트를 위한 설정
cd ~/ceweb
mkdir files                             # File Storage를 마운트할 새 폴더(rocky로 실행)
sudo dnf install nfs-utils -y           # nfs-uil 설치 
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo vi /etc/fstab                      # vi에디터에서 i를 누르고, 아래 설정 입력

10.10.10.10:/filestorage /home/rocky/ceweb/files nfs defaults,vers=3,_netdev,noresvport 0 0                  # 10.10.10.10:/file_storage는 위에서 기록한 마운트명으로 대체
# vi 에디터에서 빠져 나올 때는 esc를 누르고, :wq! 타이핑 후 엔터

# 마운트 실행
cd ~/ceweb
sudo systemctl daemon-reload
sudo mount -t nfs -o vers=3,noresvport 198.19.64.7:/scp_cefs__8i9uf files

# 마운트 상태 확인
df -h                                  # 마운트 상태 확인 : 마운트명 과 /home/rocky/ceweb/files가 매핑되어 있어야 함.

# 기존 데이터 마이그레이션
cd ~/ceweb
sudo sudo rsync -a files_temp/ files/
sudo rm -r files_temp                       # 임시 폴더 삭제
```
- 애플리케이션 서버2(appvm122r)
```bash
# 스토리지 마이그레이션 준비
cd ~/ceweb         
mv files files_temp                         # 기존 데이터를 임시 장소로 이동(rocky로 실행)

# 마운트를 위한 설정
cd ~/ceweb
mkdir files                             # File Storage를 마운트할 새 폴더(rocky로 실행)
sudo dnf install nfs-utils -y           # nfs-uil 설치 
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo vi /etc/fstab                      # vi에디터에서 # vi에디터에서 아래 설정 입력

10.10.10.10:/filestorage /home/rocky/ceweb/files nfs defaults,vers=3,_netdev,noresvport 0 0                  # 10.10.10.10:/file_storage는 위에서 기록한 마운트명으로 대체

# 마운트 실행
cd ~/ceweb
sudo systemctl daemon-reload
sudo mount -t nfs -o vers=3,noresvport 198.19.64.7:/scp_cefs__8i9uf files

# 마운트 상태 확인
df -h                                     # 마운트 상태 확인 : 마운트명 과 /home/rocky/ceweb/files가 매핑되어 있어야 함.

# 기존 데이터 마이그레이션
cd ~/ceweb
sudo sudo rsync -a --dry-run files_temp/ files/  # 애플리케이션 서버2의 데이터가 파일 스토리지 데이터와 충돌하는지 사전 체크
sudo sudo rsync -a --update files_temp/ files/   # 애플리케이선 서버2의 데이터가 파일 스토리지의 데이터와 충돌할 경우 애플리케이션 서버2의 데이터가 더 최신일 경우만 덮어씀
sudo rm -r files_temp # 임시 폴더 삭제
```

- 웹 서버1(webvm111r)
```bash
# 스토리지 마이그레이션 준비
cd ~/ceweb
mv media media_temp                     # 기존 데이터를 임시 장소로 이동(rocky로 실행)

# 마운트를 위한 설정
cd ~/ceweb
mkdir media                             # File Storage를 마운트할 새 폴더(rocky로 실행)
sudo dnf install nfs-utils -y           # nfs-uil 설치 
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo vi /etc/fstab                      # vi에디터에서 아래 설정 입력

10.10.10.10:/filestorage /home/rocky/ceweb/media nfs defaults,vers=3,_netdev,noresvport 0 0           # 10.10.10.10:/file_storage는 위에서 기록한 마운트명으로 대체

# 마운트 실행
cd ~/ceweb
sudo systemctl daemon-reload
sudo mount -t nfs -o vers=3,noresvport 198.19.64.7:/scp_cefs__8i9uf media

# 마운트 상태 확인
df -h                                      # 마운트 상태 확인 : 마운트명 과 /home/rocky/ceweb/media가 매핑되어 있어야 함.

# 기존 데이터 마이그레이션
cd ~/ceweb
sudo sudo rsync -a media_temp/ media/
sudo rm -r media_temp                       # 임시 폴더 삭제
```
- 웹 서버2(appvm122r)
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