# 고가용성 3계층 아키텍처 구성




## 실습 환경 구성
- Terraform으로 기존 환경 구성
```
terraform init
terraform validate
terraform plan
terraform apply --auto-approve
```


### 1. 3-Tier 분산 환경 구축 (권장 - 운영환경)

```bash
# 1단계: DB 서버 설치
cd deployment/db/standalone/
sudo bash install_postgresql_rocky.sh

# 2단계: App 서버 설치
cd deployment/app/
sudo bash install_app_server.sh

# 3단계: Web 서버 설치
cd deployment/web/
sudo bash install_web_server.sh
```

### 2. 올인원 서버 구축 (개발/테스트 환경)
```bash
cd deployment/etc/
sudo bash install_script.sh
```

### 3. 외부 DB 서버 사용
```bash
# DB 서버에 스키마 설치
cd deployment/db/externaldb/
bash install_schema_remote.sh

# App 서버 설치 (외부 DB 연결)
cd deployment/app/
sudo bash install_app_server.sh
```

### 4. 기존 서버 코드 업데이트
```bash
cd deployment/etc/
bash quick_deploy.sh /path/to/new/code
```

## 📋 각 폴더별 설명

### `/web` - 웹 서버 (Nginx)
- **목적**: 정적 파일 서빙 및 API 프록시 역할
- **포트**: 80 (HTTP), 443 (HTTPS)
- **기능**: HTML/CSS/JS 서빙, `/api/*` 요청을 App 서버로 프록시

### `/app` - 애플리케이션 서버 (Node.js)
- **목적**: API 처리 및 비즈니스 로직 실행
- **포트**: 3000
- **기능**: RESTful API, DB 연결, 주문 처리

### `/db/standalone` - PostgreSQL 단독 설치
- **목적**: 전용 DB 서버 구축
- **포트**: 2866 (커스텀 포트)
- **기능**: 데이터베이스, 사용자 관리, 백업 시스템

### `/db/externaldb` - 외부 DB 연결
- **목적**: 기존 DB 서버 또는 클라우드 DB 사용
- **기능**: 원격 스키마 설치, DB 연결 설정

### `/etc` - 유틸리티 및 가이드
- **목적**: 공통 도구, 통합 설치 스크립트, 아키텍처 문서
- **포함**: JWT 키 생성, 전체 가이드, 빠른 배포 도구

## 🔧 사전 요구사항

- **OS**: Rocky Linux 9.4
- **권한**: sudo/root 권한 필요
- **네트워크**: 서버간 통신 포트 오픈 (80, 3000, 2866)
- **도메인**: www.cesvc.net, app.cesvc.net, db.cesvc.net (선택사항)

## 🔍 트러블슈팅

각 폴더의 가이드 문서 참조:
- 웹 서버: `web/WEB_SERVER_SETUP_GUIDE.md`
- 앱 서버: `app/APP_SERVER_SETUP_GUIDE.md`  
- DB 서버: `db/standalone/postgresql_rocky_linux_install.md`
- 아키텍처: `etc/PORTS_AND_ARCHITECTURE.md`
