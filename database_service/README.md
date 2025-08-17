# 고가용성 Database 서비스 구성

## 선행 실습
이 실습은 아래의 실습에 이어 수행해야 합니다. 이 실습을 시작하기 전에 아래 실습을 완료하십시오.

### 필수 '[고가용성 3계층 아키텍처 구성](../3_tier_architecture/README.md)'

### 선택 '[고가용성을 위한 File Storage 구성](../file_storage/README.md)'

## File Storage 생성
```
볼륨명 : cefs
디스크 유형 : HDD
프로토콜 : NFS

<생성 후>
Mount명 : (예시) 10.10.10.10:/fie_storage       # 마운트 사용을 위해 기록
연결 자원 : webvm111r, webvm112r, appvm121r, appvm122r
```
