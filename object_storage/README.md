# 고가용성을 위한 Object Storage 구성

## 선행 실습
이 실습은 아래의 실습에 이어 수행해야 합니다. 이 실습을 시작하기 전에 아래 실습을 완료하십시오.

### 필수 '[고가용성 3계층 아키텍처 구성](../3_tier_architecture/README.md)'  ,  '[고가용성을 위한 File Storage 구성](../file_storage/README.md)'
### 선택 '[고가용성 Database 서비스 구성](../database_service/README.md)

인증키 생성

## Object Storage 생성
```
버킷명 : ceweb


<생성 후>
SRN 문자열   :  문자열 기록
Public  URL :  주소 기록
Private URL :  주소 기록
```

- appvm121에 SSH 접속
```
cd ~/ceweb/web-server/
vi credentials.json
```
아래의 내용을 복사해서 붙여넣습니다.
```
{
  "accessKeyId": "your-access-key-here",
  "secretAccessKey": "your-secret-key-here",
  "region": "kr-west1",
  "bucketName": "ceweb",
  "bucketString": "버킷의 SRN 문자열",
  "privateEndpoint": "버킷의 Private URL",
  "publicEndpoint": "버킷의 Public  URL",
  "folders": {
    "media": "media/img",
    "audition": "files/audition"
  }
}
```