# 고가용성을 위한 File Storage 구성

## 선행 실습

이 실습은 아래의 실습에 이어 수행해야 합니다. 이 실습을 시작하기 전에 아래 실습을 완료하십시오.

### 필수 : '[고가용성 3계층 아키텍처 구성](../3_tier_architecture/README.md)'

## File Storage 생성

- 볼륨명 : cefs
- 디스크 유형 : HDD
- 프로토콜 : NFS

<생성 후>

- Mount명 : (예시) 10.10.10.10:/fie_storage       # 마운트 사용을 위해 기록

- 연결 자원 : webvm111r, webvm112r, appvm121r, appvm122r

## File Storage 연결

- 애플리케이션 서버1(appvm121r)

```bash
# 스토리지 마이그레이션 준비
cd ~/ceweb         
mv files files_temp                              # 기존 데이터를 임시 장소로 이동(rocky로 실행)

# 마운트를 위한 설정
cd ~/ceweb
mkdir files                                      # File Storage를 마운트할 새 폴더(rocky로 실행)
sudo dnf install nfs-utils -y                    # nfs-uil 설치 
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo vi /etc/fstab                               # vi에디터에서 i를 누르고, 아래 설정 입력

10.10.10.10:/filestorage /home/rocky/ceweb/files nfs defaults,vers=3,_netdev,noresvport 0 0    
# 10.10.10.10:/file_storage는 위에서 기록한 마운트명으로 대체
# vi 에디터에서 빠져 나올 때는 esc를 누르고, :wq! 타이핑 후 엔터

# 마운트 실행
cd ~/ceweb
sudo systemctl daemon-reload
sudo mount -t nfs -o vers=3,noresvport 198.19.64.7:/scp_cefs__8i9uf files

# 마운트 상태 확인
df -h                                            # 마운트 상태 확인 : 마운트명 과 /home/rocky/ceweb/files가 매핑되어 있어야 함.

# 기존 데이터 마이그레이션
cd ~/ceweb
sudo sudo rsync -a files_temp/ files/
sudo rm -r files_temp                            # 임시 폴더 삭제
```

- 애플리케이션 서버2(appvm122r)

```bash
# 스토리지 마이그레이션 준비
cd ~/ceweb         
mv files files_temp                              # 기존 데이터를 임시 장소로 이동(rocky로 실행)

# 마운트를 위한 설정
cd ~/ceweb
mkdir files                                      # File Storage를 마운트할 새 폴더(rocky로 실행)
sudo dnf install nfs-utils -y                    # nfs-uil 설치 
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo vi /etc/fstab                               # vi에디터에서 # vi에디터에서 아래 설정 입력

10.10.10.10:/filestorage /home/rocky/ceweb/files nfs defaults,vers=3,_netdev,noresvport 0 0                  
# 10.10.10.10:/file_storage는 위에서 기록한 마운트명으로 대체

# 마운트 실행
cd ~/ceweb
sudo systemctl daemon-reload
sudo mount -t nfs -o vers=3,noresvport 198.19.64.7:/scp_cefs__8i9uf files

# 마운트 상태 확인
df -h                                            # 마운트 상태 확인 : 마운트명 과 /home/rocky/ceweb/files가 매핑되어 있어야 함.

# 기존 데이터 마이그레이션
cd ~/ceweb
sudo sudo rsync -a --dry-run files_temp/ files/  # 애플리케이션 서버2의 데이터가 파일 스토리지 데이터와 충돌하는지 사전 체크
sudo sudo rsync -a --update files_temp/ files/   # Files Storage 데이터와 충돌할 경우 서버 데이터가 더 최신일 경우에만 덮어씀
sudo rm -r files_temp                            # 임시 폴더 삭제
```

- 웹 서버1(webvm111r)

```bash
# 스토리지 마이그레이션 준비
cd ~/ceweb
mv media media_temp                              # 기존 데이터를 임시 장소로 이동(rocky로 실행)

# 마운트를 위한 설정
cd ~/ceweb
mkdir media                                      # File Storage를 마운트할 새 폴더(rocky로 실행)
sudo dnf install nfs-utils -y                    # nfs-uil 설치 
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo vi /etc/fstab                               # vi에디터에서 아래 설정 입력

10.10.10.10:/filestorage /home/rocky/ceweb/media nfs defaults,vers=3,_netdev,noresvport 0 0           
# 10.10.10.10:/file_storage는 위에서 기록한 마운트명으로 대체

# 마운트 실행
cd ~/ceweb
sudo systemctl daemon-reload
sudo mount -t nfs -o vers=3,noresvport 10.10.10.10:/filestorage media

# 마운트 상태 확인
df -h                                            # 마운트 상태 확인 : 마운트명 과 /home/rocky/ceweb/media가 매핑되어 있어야 함.

# 기존 데이터 마이그레이션
cd ~/ceweb
sudo sudo rsync -a media_temp/ media/
sudo rm -r media_temp                            # 임시 폴더 삭제
```

- 웹 서버2(webvm112r)

```bash
# 스토리지 마이그레이션 준비
cd ~/ceweb
mv media media_temp                              # 기존 데이터를 임시 장소로 이동(rocky로 실행)

# 마운트를 위한 설정
cd ~/ceweb
mkdir media                                      # File Storage를 마운트할 새 폴더(rocky로 실행)
sudo dnf install nfs-utils -y                    # nfs-uil 설치 
sudo systemctl enable rpcbind.service
sudo systemctl start rpcbind.service
sudo vi /etc/fstab                               # vi에디터에서 아래 설정 입력

10.10.10.10:/filestorage /home/rocky/ceweb/media nfs defaults,vers=3,_netdev,noresvport 0 0           
# 10.10.10.10:/file_storage는 위에서 기록한 마운트명으로 대체

# 마운트 실행
cd ~/ceweb
sudo systemctl daemon-reload
sudo mount -t nfs -o vers=3,noresvport 198.19.64.7:/scp_cefs__8i9uf media

# 마운트 상태 확인
df -h                                            # 마운트 상태 확인 : 마운트명 과 /home/rocky/ceweb/media가 매핑되어 있어야 함.

# 기존 데이터 마이그레이션
cd ~/ceweb
sudo sudo rsync -a --dry-run media_temp/ media/  # App 서버2의 데이터가 파일 스토리지 데이터와 충돌하는지 사전 체크
sudo sudo rsync -a --update media_temp/ media/   # Files Storage 데이터와 충돌할 경우 서버 데이터가 더 최신일 경우에만 덮어씀
sudo rm -r media_temp                            # 임시 폴더 삭제
```
