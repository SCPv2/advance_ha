# Auto-Scaling 적용을 위한 과업 내역서

## 개요
현재 Single Server 배포 아키텍처에서 Auto-Scaling을 적용하여 동적 확장 가능한 시스템으로 전환하기 위한 상세 과업 내역서입니다.

## 현재 아키텍처 상태
- **Web Tier**: 1대 (webvm111r)
- **App Tier**: 1대 (appvm121r) 
- **DB Tier**: PostgreSQL DBaaS 1 클러스터
- **Load Balancer**: Web LB, App LB 구성 완료
- **Storage**: Shared NFS Volume 구성 완료

## Auto-Scaling 적용 과업

### 1. Infrastructure as Code (IaC) 재구성

#### 1.1 Terraform 모듈화
- [ ] **과업**: `D:\scpv2\advance_ha\object_storage\main.tf`를 모듈 기반으로 재구성
- [ ] **상세**: 
  - Web Tier 모듈 분리 (`modules/web/`)
  - App Tier 모듈 분리 (`modules/app/`)
  - Load Balancer 모듈 분리 (`modules/loadbalancer/`)
  - Auto-Scaling Group 모듈 생성 (`modules/autoscaling/`)
- [ ] **예상 소요시간**: 8시간
- [ ] **담당자**: Infrastructure Engineer

#### 1.2 Auto-Scaling Group 리소스 정의
- [ ] **과업**: Samsung Cloud Platform v2 Auto-Scaling Group 리소스 추가
- [ ] **상세**:
  ```hcl
  # Web Tier Auto-Scaling Group
  resource "samsungcloudplatformv2_autoscaling_group" "web_asg" {
    name                = "web-asg"
    vpc_id              = var.vpc_id
    subnet_ids          = [var.web_subnet_id]
    target_group_id     = samsungcloudplatformv2_loadbalancer_lb_server_group.web_server_group.id
    min_size            = 1
    max_size            = 4
    desired_capacity    = 2
    launch_template_id  = samsungcloudplatformv2_launch_template.web_template.id
  }
  ```
- [ ] **예상 소요시간**: 4시간
- [ ] **담당자**: Cloud Architect

### 2. Launch Template 구성

#### 2.1 Web Tier Launch Template
- [ ] **과업**: Web 서버용 Launch Template 생성
- [ ] **상세**:
  - Base AMI: 현재 webvm111r과 동일한 이미지
  - User Data Script: Nginx + Static Files 자동 배포
  - Security Group: 기존 web_sg 활용
  - Instance Type: 현재와 동일한 spec 유지
- [ ] **예상 소요시간**: 6시간
- [ ] **담당자**: DevOps Engineer

#### 2.2 App Tier Launch Template  
- [ ] **과업**: App 서버용 Launch Template 생성
- [ ] **상세**:
  - Base AMI: 현재 appvm121r과 동일한 이미지
  - User Data Script: Node.js Application 자동 배포
  - Database 연결 설정 자동화
  - Security Group: 기존 app_sg 활용
- [ ] **예상 소요시간**: 8시간
- [ ] **담당자**: Application Developer

### 3. Auto-Scaling Policies 설정

#### 3.1 Scaling Metrics 정의
- [ ] **과업**: CloudWatch 메트릭 기반 스케일링 정책 수립
- [ ] **상세**:
  - **Scale Out 조건**: CPU > 70% (5분간 지속)
  - **Scale In 조건**: CPU < 30% (10분간 지속) 
  - **추가 메트릭**: Memory Utilization, Request Count
- [ ] **예상 소요시간**: 3시간
- [ ] **담당자**: Monitoring Engineer

#### 3.2 Web Tier Scaling Policy
- [ ] **과업**: Web 서버 스케일링 정책 구현
- [ ] **상세**:
  ```hcl
  resource "samsungcloudplatformv2_autoscaling_policy" "web_scale_out" {
    name                = "web-scale-out"
    autoscaling_group_id = samsungcloudplatformv2_autoscaling_group.web_asg.id
    policy_type         = "TargetTrackingScaling"
    target_value        = 70.0
    metric_name         = "CPUUtilization"
  }
  ```
- [ ] **예상 소요시간**: 4시간
- [ ] **담당자**: Cloud Engineer

#### 3.3 App Tier Scaling Policy
- [ ] **과업**: App 서버 스케일링 정책 구현  
- [ ] **상세**: Web Tier와 유사하나 Database Connection Pool 고려
- [ ] **예상 소요시간**: 4시간
- [ ] **담당자**: Cloud Engineer

### 4. Application 레벨 수정사항

#### 4.1 Database Connection Pool 최적화
- [ ] **과업**: PostgreSQL 연결 풀 동적 관리 로직 구현
- [ ] **상세**:
  - 현재 `db_pool_max: 100` → 인스턴스 수에 따른 동적 할당
  - Connection Pool Health Check 구현
  - Dead Connection 자동 정리 로직
- [ ] **위치**: `D:\scpv2\ceweb\app-server\config\database.js`
- [ ] **예상 소요시간**: 6시간
- [ ] **담당자**: Backend Developer

#### 4.2 Session 관리 개선
- [ ] **과업**: 현재 세션 관리를 Redis 기반으로 전환
- [ ] **상세**:
  - Memory 기반 세션 → Redis 클러스터 세션
  - Session Sticky 제거를 통한 완전한 Stateless 구현
- [ ] **위치**: `D:\scpv2\ceweb\app-server\config\session.js`
- [ ] **예상 소요시간**: 8시간
- [ ] **담당자**: Backend Developer

#### 4.3 Static Asset 처리 최적화
- [ ] **과업**: Object Storage 기반 정적 자원 CDN 연계 
- [ ] **상세**:
  - 현재 `/media`, `/files` 경로 → Object Storage URL 직접 연결
  - CloudFront 또는 Samsung Cloud CDN 연계
- [ ] **위치**: `D:\scpv2\ceweb\scripts\master-variables-loader.js`
- [ ] **예상 소요시간**: 4시간
- [ ] **담당자**: Frontend Developer

### 5. Monitoring & Logging 구성

#### 5.1 CloudWatch 대시보드 구성
- [ ] **과업**: Auto-Scaling 전용 모니터링 대시보드 생성
- [ ] **상세**:
  - ASG 인스턴스 상태 모니터링
  - Scaling Event 기록 및 알림
  - Application Health Check 지표
- [ ] **예상 소요시간**: 4시간
- [ ] **담당자**: Monitoring Engineer

#### 5.2 Log Aggregation 구성  
- [ ] **과업**: 다중 인스턴스 로그 중앙 집중화
- [ ] **상세**:
  - ELK Stack 또는 CloudWatch Logs 활용
  - Application Log, Access Log 통합 수집
  - Error Rate 기반 알림 설정
- [ ] **예상 소요시간**: 6시간
- [ ] **담당자**: DevOps Engineer

### 6. Network & Security 업데이트

#### 6.1 Security Group 규칙 업데이트
- [ ] **과업**: Auto-Scaling 환경에 맞는 보안 그룹 규칙 재정의
- [ ] **상세**:
  - 동적 인스턴스 IP 대응을 위한 CIDR 기반 규칙
  - Load Balancer Health Check 허용 규칙
- [ ] **위치**: `D:\scpv2\advance_ha\object_storage\main.tf` (Line 836~967)
- [ ] **예상 소요시간**: 3시간
- [ ] **담당자**: Network Engineer

#### 6.2 NAT Gateway 확장성 검토
- [ ] **과업**: Auto-Scaling 시 Outbound 트래픽 처리 능력 검증
- [ ] **상세**: 
  - 현재 NAT 인스턴스 → NAT Gateway 전환 검토
  - Multi-AZ NAT Gateway 구성 고려
- [ ] **예상 소요시간**: 4시간
- [ ] **담당자**: Network Architect

### 7. Testing & Validation

#### 7.1 Load Testing
- [ ] **과업**: Auto-Scaling 동작 검증을 위한 부하 테스트
- [ ] **상세**:
  - JMeter 또는 Artillery를 이용한 부하 생성
  - Scale Out/In 시나리오 테스트
  - Database 성능 영향도 측정
- [ ] **예상 소요시간**: 8시간
- [ ] **담당자**: QA Engineer

#### 7.2 Disaster Recovery 테스트
- [ ] **과업**: 인스턴스 장애 시 복구 시나리오 검증
- [ ] **상세**:
  - 강제 인스턴스 종료 시 자동 복구 테스트
  - 데이터 정합성 검증
  - RTO/RPO 측정
- [ ] **예상 소요시간**: 6시간
- [ ] **담당자**: Infrastructure Engineer

### 8. 배포 및 롤백 전략

#### 8.1 Blue-Green 배포 전략 수립
- [ ] **과업**: 무중단 배포를 위한 Blue-Green 전략 구현
- [ ] **상세**:
  - 기존 환경 유지하며 신규 ASG 환경 병렬 구축
  - Traffic 점진적 전환 (10% → 50% → 100%)
  - 자동 롤백 조건 및 절차 정의
- [ ] **예상 소요시간**: 12시간
- [ ] **담당자**: DevOps Lead

#### 8.2 Configuration Management
- [ ] **과업**: Infrastructure as Code 버전 관리 및 배포 파이프라인
- [ ] **상세**:
  - Terraform State 파일 원격 백엔드 구성
  - CI/CD 파이프라인 통한 자동 배포
  - Plan/Apply 승인 워크플로우 구성
- [ ] **예상 소요시간**: 6시간
- [ ] **담당자**: Platform Engineer

## 총 예상 소요 시간: 약 104시간 (13일)

## 리스크 및 고려사항

### 고위험 항목
1. **Database Connection Pool**: PostgreSQL 최대 연결 수 제한으로 인한 병목 가능성
2. **Session Management**: Redis 도입으로 인한 아키텍처 복잡도 증가
3. **File Storage**: NFS 공유 볼륨의 동시 접근 성능 이슈

### 중위험 항목
1. **Network Latency**: 다중 인스턴스 간 통신 지연
2. **Cost Management**: 과도한 스케일링으로 인한 비용 급증
3. **Log Volume**: 인스턴스 증가에 따른 로그 저장소 용량 급증

### 대응 방안
1. **사전 성능 테스트**: 각 컴포넌트별 부하 임계점 사전 측정
2. **비용 모니터링**: CloudWatch 비용 알림 및 스케일링 한계 설정
3. **단계별 적용**: Web Tier 우선 적용 후 App Tier 순차 적용

## 성공 기준
1. **가용성**: 99.9% 이상 Uptime 달성
2. **성능**: 평균 응답시간 기존 대비 20% 이내 유지
3. **확장성**: 트래픽 3배 증가 시 자동 대응 가능
4. **비용 효율**: 기존 고정 비용 대비 30% 절감 목표

---
*문서 생성일: 2025-08-30*  
*생성자: Claude Code Assistant*  
*버전: 1.0*