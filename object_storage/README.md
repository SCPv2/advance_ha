# 고가용성 구현을 위한 Object Storage 구성

## 실행 환경 요구사항

### 필수 시스템 환경

- **운영체제**: Windows 10/11 또는 Windows Server 2019/2022
- **PowerShell 버전**: 5.1 이상 (권장: 7.x)

  ```powershell
  # PowerShell 버전 확인
  $PSVersionTable.PSVersion
  ```

### 필수 도구 설치

1. **Samsung Cloud Platform v2 CLI**

   ```powershell
   # SCP CLI 버전 확인 및 설치 상태 점검
   scpcli --version
   
   # 인증 상태 확인
   scpcli auth token show
   ```

2. **Terraform** (선택사항 - IaC 배포 시)

   ```powershell
   # Terraform 설치 확인
   terraform --version
   ```

### PowerShell 실행 정책 설정

배포 스크립트 실행을 위해 PowerShell 실행 정책 설정이 필요합니다:

```powershell
# 현재 사용자 수준에서 실행 정책 변경 (권장)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# 또는 현재 세션에서만 임시 허용
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 네트워크 요구사항

- **방화벽**: 방화벽 등으로 포트 차단이 없는 인터넷 환경
- **Public IP**: 실습 중 인터넷 접근 Public IP 주소의 변경이 없는 환경

### 실행 전 점검

```powershell
# 환경 점검 스크립트
Write-Host "=== 환경 점검 ==="
Write-Host "PowerShell 버전: $($PSVersionTable.PSVersion)"
Write-Host "실행 정책: $(Get-ExecutionPolicy -Scope CurrentUser)"

try {
    $scpVersion = scpcli --version
    Write-Host "SCP CLI: 설치됨 ($scpVersion)"
} catch {
    Write-Host "SCP CLI: 설치되지 않음 - 설치 필요"
}

try {
    scpcli auth token show | Out-Null
    Write-Host "SCP 인증: 정상"
} catch {
    Write-Host "SCP 인증: 로그인 필요 - scpcli auth login 실행"
}
```

## 선행 실습

### 필수 '[Database 서비스 구성](../database_service/README.md)'

### 선택 '[고가용성 구현을 위한 File Storage 구성](../file_storage/README.md)'

## DNS 설정

- Hosted Zone (Private)

| 유형 | 이름 | 값 | TTL|
|----|----|----|----|
|A|www|10.1.1.100|300|
|A|app|10.1.2.100|300|
|A|db|10.1.3.100|300|

- Hosted Zone (Public)

| 유형 | 이름 | 값 | TTL|
|----|----|----|----|
|A|www|Your Public IP|300|

## Object Storage 생성

- 버킷명 : ceweb

생성 후 점검할 항목

- Account ID : 버킷 스트링
- Public URL
- Private URL

## 실습 환경 배포

**&#128906; Terraform 배포 스크립트 실행**

```powershell
cd C:\scpv2advance\advance_ha\object_storage\

Set_ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

.\env_setup.ps1
```

- keypair_name: mykey .........................................# 기본 키페어 값, 다른 키페어 사용시 입력
- object_storage_access_key_id: ........................# Object Storage 액세스 키 ID
- object_storage_secret_access_key: ...............# Object Storage 시크릿 액세스 키
- object_storage_bucket_string: ........................# Object Storage 버킷 스트링
- private_domain_name: ......................................# 과정 소개에서 만든 프라이빗 도메인 이름
- public_domain_name: .......................................# 과정 소개에서 만든 퍼블릭 도메인 이름
- user_public_ip: .....................................................# 현재 실습을 수행하고 있는 PC의 Public IP 주소

## 환경 검토

- Architecture Diagram
- VPC CIDR
- Subnet CIDR
- Virtual Server OS, Public IP, Private IP
- PostgreSQL DBaaS 엔드포인트
- Firewall 규칙
- Security Group 규칙

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|IGW|10.1.1.110 (bastion), 10.1.1.0/24 (web subnet), 10.1.2.0/24 (app subnet)|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound to Internet|
|Terraform|IGW|Your Public IP|10.1.1.110 (bastion)|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Terraform|IGW|Your Public IP|10.1.1.100 (Web LB Service IP)|TCP 80|Allow|Inbound|HTTP inbound to Web Load Balancer|

### Security Group

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|bastionSG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|bastionSG|Outbound|webSG|TCP 22|SSH outbound to web vm |
|Terraform|bastionSG|Outbound|appSG|TCP 22|SSH outbound to app vm |
|Terraform|bastionSG|Outbound|webSG|TCP 80|HTTP outbound to web vm for monitoring|
|||||||
|Terraform|webSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|webSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|webSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Terraform|webSG|Inbound|bastionSG|TCP 80|HTTP inbound from bastion|
|Terraform|webSG|Outbound|10.1.2.100/32 (appLB Service IP)|TCP 3000|API connection outbound to app LB|
|Terraform|webSG|Outbound|appSG|TCP 3000|Direct API connection outbound to app servers|
|||||||
|Terraform|appSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|appSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|appSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Terraform|appSG|Inbound|webSG|TCP 3000|Direct API connection inbound from web servers|
|||||||
|DBaaS|Internal|Access Rules|10.1.2.0/24, 10.1.1.110/32||App subnet and Bastion access to DBaaS|

## VPC Endpoint Subnet 생성

- Subnet 유형 : VPC Endpoint

- VPC : VPC1
- Subnet명 : Subnet110
- IP 대역 : 10.1.10.0/24

## VPC Endpoint 생성

- VPC : VPC1

- 대상 서비스 : Object Storage
- 연결 자원 : Object Storage Private URL 선택
- VPC Endpoint 명 : CEWEBendpoint
- Subnet : Subnet110
- IP : 10.1.10.10

## Security Group 규칙 구성

- 기존에 443 Outbound to Internet(0.0.0.0/0) 규칙이 있을 경우 생략

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|User Input|appSG|Outbound|10.1.10.10(VPC Endpoint IP)|443|HTTPS Private Outbound to Object Storage Bucket|

## AWS CLI 설치

Object Storage의 [Amazon S3 활용 가이드](https://docs.e.samsungsdscloud.com/userguide/storage/object_storage/overview/amazons3/) 검토

```bash
# 기존 설치 삭제
sudo yum remove awscli

# Object Storage를 위한 AWS CLI 설치
sudo dnf install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.22.35.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# AWS CLI 환경 구성
aws configure

# AWS Access Key ID [None]:                인증키의 Access Key입력
# AWS Secret Access Key [None]:            인증키의 Secret Key입력
# Default region name [None]: kr-west1     kr-west1 입력
# Default output format [None]:            입력없이 엔터
```

## 웹 콘텐츠 마이그레이션

```bash
cd /home/rocky/ceweb/

aws s3 cp media s3://{버킷명}/media --recursive --endpoint-url [Private Endpoint명]

# aws s3 cp media s3://ceweb/media --recursive --endpoint-url https://object-store.private.kr-west1.e.samsungsdscloud.com
```

- 객체의 Public URL, Private URL 구조 확인

## 애플리케이션 저장소 마이그레이션

```bash
cd /home/rocky/ceweb/

aws s3 cp files s3://{버킷명}/files --recursive --endpoint-url [Private Endpoint명]

# aws s3 cp files s3://ceweb/files --recursive --endpoint-url https://object-store.private.kr-west1.e.samsungsdscloud.com
```

- [CEWEB](https://github.com/SCPv2/ceweb) 애플리케이션 구조 확인

- Web 서버 경로 변경
  
  - 기존:  `./media`

  - 변경: `https://object-store.kr-west1.e.samsungsdscloud.com)/{Account_id}:ceweb/media`

- 애플리케이션 전환

```bash
mv index.html index_bk.html
mv index_obj.html index.html
```
