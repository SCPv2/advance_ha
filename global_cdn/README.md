# 고성능 웹서비스 구현

## Global CDN 구성

- CDN명 : `cecdn`

- CDN 도메인 : `ceweb'
- 원본 위치 >  
  - IP : your_public_ip.name  
  - 프로토콜 : HTTP
  - Port 번호 : 80
  
- 원본 경로 : 
- Forward host header	: Incoming host header
- Cache key hostname	: Incoming host header
- Custom header (요청) : 사용 안함

- 캐싱 옵션 : Honor origin cache-control and expires
- 컨텐츠 전송 정책 : 유효한 콘텐츠만 제공
- Cache 만료시간 : 3,600
- Ignore query string	: 사용 안함
- Range request : 사용 안함
- Custom header : 사용 안함
