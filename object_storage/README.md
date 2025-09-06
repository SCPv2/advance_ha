# 고가용성을 위한 Object Storage 구성

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

### 필수 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 필수 '[Database 서비스 구성](../database_service/README.md)'

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

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
|Terraform|IGW|10.1.1.110, 10.1.1.111, 10.1.1.112, 10.1.2.121, 10.1.2.122|0.0.0.0/0|TCP 80, 443|Allow|Outbound|HTTP/HTTPS outbound from vms to Internet|
|Terraform|IGW|Your Public IP|10.1.1.110|TCP 3389|Allow|Inbound|RDP inbound to bastion|
|Terraform|IGW|Your Public IP|10.1.1.111|TCP 80|Allow|Inbound|HTTP inbound to web vm|
|Terraform|web Load Balancer|Your Public IP|10.1.1.100 (Service IP)|TCP 80|Allow|Outbound|클라이언트 → LB 연결|
|Terraform|web Load Balancer|webLB Source NAT IP|10.1.1.111, 10.1.1.112 (webvm IP)|TCP 80|Allow|Inbound|LB → 멤버 연결|
|Terraform|web Load Balancer|webLB 헬스 체크 IP|10.1.1.111, 10.1.1.112 (webvm IP)|TCP 80|Allow|Inbound|LB → 멤버 헬스 체크|
|Terraform|app Load Balancer|10.1.1.111, 10.1.1.112 (webvm IP)|10.1.2.100 (Service IP)|3000|Allow|Outbound|클라이언트 → LB 연결|
|Terraform|app Load Balancer|appLB Source NAT IP|10.1.2.121, 10.1.2.122 (appvm IP)|3000|Allow|Inbound|LB → 멤버 연결|
|Terraform|app Load Balancer|appLB 헬스 체크 IP|10.1.2.121, 10.1.2.122 (appvm IP)|3000|Allow|Inbound|LB → 멤버 헬스 체크|

### Security Group

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terraform|bastionSG|Inbound|Your Public IP|TCP 3389|RDP inbound to bastion VM|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|bastionSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Add|bastionSG|Outbound|webSG|TCP 22|SSH outbound to web vm |
|Add|bastionSG|Outbound|appSG|TCP 22|SSH outbound to app vm |
|||||||
|Terraform|webSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|webSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|webSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Terraform|webSG|Inbound|bastionSG|TCP 80|HTTP inbound from bastion|
|Terraform|webSG|Inbound|webLB Source NAT IP|TCP 80|HTTP inbound from Load Balancer|
|Terraform|webSG|Inbound|webLB Healthcheck IP|TCP 80|Healthcheck HTTP inbound from Load Balancer|
|Terraform|webSG|Outbound|appLB Service IP|3000|API connection outbound to app LB|
|||||||
|Terraform|appSG|Outbound|0.0.0.0/0|TCP 80|HTTP outbound to Internet|
|Terraform|appSG|Outbound|0.0.0.0/0|TCP 443|HTTPS outbound to Internet|
|Terraform|appSG|Inbound|bastionSG|TCP 22|SSH inbound from bastion|
|Terraform|appSG|Inbound|appLB Source NAT IP|3000|API connection inbound from Load Balancer|
|Terraform|webSG|Inbound|appLB Healthcheck IP|3000|Healthcheck 3000 inbound from Load Balancer|
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

* 기존에 443 Outbound to Internet(0.0.0.0/0) 규칙이 있을 경우 생략

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











**Object Storage 기능:**

- Samsung Cloud Platform Object Storage 연동
- 미디어 파일 및 업로드 파일 저장
- 퍼블릭 엔드포인트를 통한 정적 파일 서빙
- 프라이빗 엔드포인트를 통한 업로드 처리

## 아키텍처 구성 변경사항

### 기존 database_service와의 차이점

**제거된 구성 요소:**

- ❌ DB VM (dbvm311r) - PostgreSQL DBaaS로 대체
- ❌ DB VM 관련 Port, Security Group 규칙
- ❌ DB VM UserData 스크립트
- ❌ pip4 (DB VM용 Public IP) - 3개 Public IP로 감소

**추가된 구성 요소:**

- ✅ PostgreSQL DBaaS 클러스터 (자동 HA 구성)
- ✅ DBaaS 접근 제어 규칙 (App subnet + Bastion 허용)
- ✅ 앱 서버 UserData에 DBaaS 스키마 초기화 로직
- ✅ Object Storage 연동 준비 (변수 설정)

### 인프라 구성

- **Web Tier**: 2대의 웹 서버 (Load Balancer 구성)
- **App Tier**: 2대의 앱 서버 (Load Balancer 구성)  
- **Database Tier**: PostgreSQL DBaaS (관리형 서비스, HA 구성)
- **File Storage**: NFS 공유 볼륨 (웹/앱 서버 간 파일 공유)
- **Object Storage**: 미디어 파일 및 정적 자산 저장 (연동 준비)
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
# 변수 파일 설정 (Object Storage 정보 포함)
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

### 2. 인프라 배포

```bash
terraform init
terraform plan
terraform apply
```

### 3. 자동 초기화 확인

배포 후 다음 사항들이 자동으로 처리됩니다:

- PostgreSQL DBaaS 클러스터 생성 및 HA 구성
- 앱 서버에서 DBaaS로 자동 연결 및 스키마 초기화
- File Storage NFS 볼륨 자동 마운트
- Load Balancer 헬스 체크 자동 시작

### 4. 배포 검증

```bash
# DBaaS 연결 테스트 (Bastion에서)
psql -h db.${private_domain_name} -U cedbadmin -d cedb

# 앱 서버 API 테스트
curl http://app.${private_domain_name}/api/products

# 웹 서버 테스트
curl http://www.${private_domain_name}
```

## 관리형 서비스 활용 시나리오

### 시나리오 1: 무중단 DBaaS 장애 조치 테스트 (난이도: 초급)

**목표**: PostgreSQL DBaaS의 자동 장애 조치 기능 확인

**실습 단계**:

1. **현재 DBaaS 상태 확인**

   ```bash
   # 포털에서 DBaaS 클러스터 상태 확인
   # Primary/Secondary 노드 식별
   ```

2. **애플리케이션 트래픽 생성**

   ```bash
   # 앱 서버에서 지속적인 데이터베이스 트래픽 생성
   while true; do
     curl http://localhost:3000/api/products
     sleep 1
   done
   ```

3. **강제 장애 조치 실행**
   - 포털에서 Manual Failover 실행
   - 애플리케이션 연결 상태 모니터링

4. **복구 시간 측정**

   ```bash
   # 연결 중단 시간 확인
   # 새로운 Primary 노드로 자동 전환 확인
   ```

### 시나리오 2: Object Storage 연동 구성 (난이도: 중급)

**목표**: 미디어 파일을 Object Storage로 이전

**실습 단계**:

1. **Object Storage 버킷 생성**

   ```bash
   # 포털에서 Object Storage 버킷 생성
   # 액세스 키 생성 및 권한 설정
   ```

2. **애플리케이션 설정 업데이트**

   ```javascript
   // master_config.json 업데이트
   "object_storage_access_key_id": "your_access_key",
   "object_storage_secret_access_key": "your_secret_key",
   "object_storage_bucket_string": "your_bucket_name"
   ```

3. **미디어 파일 업로드 테스트**

   ```bash
   # 앱 서버에서 Object Storage로 파일 업로드
   curl -X POST -F "file=@test.jpg" http://localhost:3000/api/upload
   ```

4. **퍼블릭 엔드포인트 접근 확인**

   ```bash
   # Object Storage 퍼블릭 URL로 파일 접근
   curl https://object-store.kr-west1.e.samsungsdscloud.com/bucket/file.jpg
   ```

### 시나리오 3: 성능 모니터링 및 스케일링 (난이도: 고급)

**목표**: DBaaS 성능 모니터링 및 스케일 아웃

**실습 단계**:

1. **성능 기준선 측정**

   ```bash
   # pgbench로 성능 테스트
   pgbench -h db.${private_domain_name} -U cedbadmin -d cedb -c 10 -T 60
   ```

2. **모니터링 대시보드 확인**
   - 포털에서 DBaaS 모니터링 메트릭 확인
   - CPU, 메모리, I/O 사용률 분석

3. **스케일 업 테스트**

   ```bash
   # 포털에서 DBaaS 서버 타입 변경
   # db1v2m4 → db1v4m8으로 업그레이드
   ```

4. **로드 테스트 재실행**

   ```bash
   # 성능 개선 확인
   pgbench -h db.${private_domain_name} -U cedbadmin -d cedb -c 20 -T 60
   ```

## 관리형 서비스의 장점

### 운영 효율성

1. **자동화된 관리**
   - 백업 및 복원 자동화
   - 패치 관리 자동화
   - 모니터링 및 알림 자동화

2. **고가용성**
   - 자동 장애 조치
   - Multi-AZ 배포
   - 데이터 복제 자동화

3. **보안 강화**
   - 암호화 자동 적용
   - 접근 제어 강화
   - 감사 로그 자동 수집

### 비용 최적화

1. **리소스 효율성**
   - 필요에 따른 스케일링
   - 유휴 리소스 최소화
   - 예약 인스턴스 활용

2. **운영 비용 절감**
   - DBA 업무 자동화
   - 인프라 관리 부담 경감
   - 장애 대응 시간 단축

## 결론

이 실습을 통해 다음과 같은 핵심 개념을 학습할 수 있습니다:

1. **관리형 데이터베이스 서비스 활용**: PostgreSQL DBaaS의 구성과 관리
2. **서비스 마이그레이션**: Self-managed → Managed Service 전환
3. **자동화된 배포**: Infrastructure as Code를 통한 관리형 서비스 배포
4. **Object Storage 연동**: 정적 자산 및 미디어 파일 관리
5. **운영 효율성 향상**: 관리형 서비스를 통한 운영 부담 경감

관리형 서비스 활용을 통해 애플리케이션 개발에 집중하고, 인프라 운영의 복잡성을 크게 줄일 수 있습니다.
