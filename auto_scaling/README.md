# Auto-Scaling 및 정책 구성

## Image 생성

- Web Server image : `web_image`

- APP Server image : `app_image`

## Launch Configuration 생성

### Web Server

- Custom : `web_image`

- Launch Configuration명 : `weblc`
- 서버 타입 : Standard-1 / s1v1m2
- Block Storage / 기본 OS :  SSD / 2 Units / 16GB
- Keypair : `mykey`

### App Server

- Custom : `app_image`

- Launch Configuration명 : `applc`
- 서버 타입 : Standard-1 / s1v1m2
- Block Storage / 기본 OS :  SSD / 2 Units / 16GB
- Keypair : `mykey`
- Init script

```bash
#!/bin/bash
set -e

APP_USER="rocky"
APP_DIR="/home/$APP_USER/ceweb/app-server"

if [ -d "$APP_DIR" ]; then
    chown -R $APP_USER:$APP_USER $APP_DIR && chmod -R 755 $APP_DIR
    AUDITION_DIR="/home/$APP_USER/ceweb/files/audition"
    if [ -d "$AUDITION_DIR" ]; then
        chown -R $APP_USER:$APP_USER "$AUDITION_DIR" && chmod -R 755 "$AUDITION_DIR"
    fi
else
    exit 1
fi

if ! command -v node >/dev/null || ! command -v pm2 >/dev/null; then
    exit 1
fi

ENV_FILE="$APP_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    chown $APP_USER:$APP_USER "$ENV_FILE" && chmod 600 "$ENV_FILE"
else
    exit 1
fi

REQUIRED_FILES=("server.js" "package.json" "ecosystem.config.js")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$APP_DIR/$file" ]; then
        exit 1
    fi
done

sudo -u $APP_USER bash -c "cd $APP_DIR && pm2 delete creative-energy-api >/dev/null 2>&1 || true"
sudo -u $APP_USER bash -c "cd $APP_DIR && pm2 kill >/dev/null 2>&1 || true"

sleep 5

for i in {1..15}; do
    if ! ss -tlnp | grep -q ':3000'; then
        break
    fi
    sleep 2
done

sudo -u $APP_USER bash -c "cd $APP_DIR && pm2 start ecosystem.config.js"
sudo -u $APP_USER bash -c "cd $APP_DIR && pm2 save"

for i in {1..30}; do
    if ss -tlnp | grep -q ':3000'; then
        break
    fi
    sleep 2
done

for i in {1..15}; do
    if curl -f -s http://localhost:3000/health >/dev/null 2>&1; then
        break
    fi
    sleep 3
done

VM_INFO_FILE="/home/$APP_USER/ceweb/app-server/vm-info.json"
PM2_STATUS=$(sudo -u $APP_USER pm2 jlist | jq -r '.[0].pm2_env.status' 2>/dev/null || echo "unknown")
VM_NUMBER="1"
VM_HOSTNAME=$(hostname)
if [[ $VM_HOSTNAME == *"121"* ]] || [[ $VM_HOSTNAME == *"app1"* ]]; then
    VM_NUMBER="1"
elif [[ $VM_HOSTNAME == *"122"* ]] || [[ $VM_HOSTNAME == *"app2"* ]]; then
    VM_NUMBER="2"
fi
INTERNAL_IP=$(hostname -I | awk '{print $1}')

sudo -u $APP_USER bash -c "cat > '$VM_INFO_FILE' << 'EOF'
{
    \\\"vm_type\\\": \\\"app\\\",
    \\\"vm_number\\\": \\\"$VM_NUMBER\\\",
    \\\"hostname\\\": \\\"$VM_HOSTNAME\\\",
    \\\"internal_ip\\\": \\\"$INTERNAL_IP\\\",
    \\\"startup_time\\\": \\\"$(date -Iseconds)\\\",
    \\\"app_status\\\": \\\"$PM2_STATUS\\\",
    \\\"app_port\\\": \\\"3000\\\",
    \\\"node_version\\\": \\\"$(node --version)\\\",
    \\\"pm2_version\\\": \\\"$(pm2 --version)\\\",
    \\\"load_balancer\\\": {
        \\\"name\\\": \\\"app.${private_domain_name}\\\",
        \\\"ip\\\": \\\"10.1.2.100\\\",
        \\\"policy\\\": \\\"Round Robin\\\",
        \\\"pool\\\": [\\\"appvm121r (10.1.2.121)\\\", \\\"appvm122r (10.1.2.122)\\\"]
    },
    \\\"architecture\\\": {
        \\\"tier\\\": \\\"App Server\\\",
        \\\"role\\\": \\\"API Processing + Business Logic\\\",
        \\\"database\\\": \\\"db.${private_domain_name}:2866\\\"
    },
    \\\"region\\\": \\\"samsung-cloud\\\",
    \\\"last_health_check\\\": \\\"$(date -Iseconds)\\\",
    \\\"bootstrap_completed\\\": true
}
EOF"

APP_STATUS=$(sudo -u $APP_USER pm2 list | grep -c "online" 2>/dev/null || echo "0")
PORT_STATUS=$(ss -tlnp | grep :3000 | wc -l)

if [ "$APP_STATUS" -gt 0 ] && [ "$PORT_STATUS" -gt 0 ]; then
    echo "SUCCESS - $(date)" > "/home/$APP_USER/APPLICATION_STATUS"
    chown $APP_USER:$APP_USER "/home/$APP_USER/APPLICATION_STATUS"
    exit 0
else
    echo "FAILED - $(date)" > "/home/$APP_USER/APPLICATION_STATUS"
    chown $APP_USER:$APP_USER "/home/$APP_USER/APPLICATION_STATUS"
    exit 1
fi
```

## Auto-Scaling Group 생성

### Web Server Group

- Launch Configuration : `weblc`

- Auto-Scaling Group명 : `web_asg`
- 서버명 : `webvm`
- 서버 수 :
  - Min : `1`
  - Desired : `1`
  - Max : `3`
- Desired 서버 수 수동 설정 : 사용
- 네트워크 설정
  - VPC : VPC1
  - 일반 Subnet : Subnet11
  - Security Group : webSG

- Load Balancer: 사용
  - LB 서버 그룹 : weblbgrp
  - 포트 : `80`

- Scale-out 정책
  - 정책명 : `web_scale_out`
  - 실행 조건 : Average , CPU Usage, >= , `60` % , `1` 분 동안 발생
  - 실행 단위 : 지정 대수만큼 서버 수 증감 , `1` 대수로 증가
  - 쿨다운 : `60` 초

- Scale-in 정책
  - 정책명 : `web_scale_in`
  - 실행 조건 : Average , CPU Usage, <= , `20` % , `1` 분 동안 발생
  - 실행 단위 : 지정 대수만큼 서버 수 증감 , `1` 대수로 반납
  - 쿨다운 : `60` 초

- 알림 설정 : 나중에 설정

### App Server Group

- Launch Configuration : `applc`

- Auto-Scaling Group명 : `app_asg`
- 서버명 : `appvm`
- 서버 수 :
  - Min : `1`
  - Desired : `1`
  - Max : `3`
- Desired 서버 수 수동 설정 : 사용
- 네트워크 설정
  - VPC : VPC1
  - 일반 Subnet : Subnet12
  - Security Group : appSG

- Load Balancer: 사용
  - LB 서버 그룹 : applbgrp
  - 포트 : `3000`

- Scale-out 정책
  - 정책명 : `app_scale_out`
  - 실행 조건 : Average , CPU Usage, >= , `60` % , `1` 분 동안 발생
  - 실행 단위 : 지정 대수만큼 서버 수 증감 , `1` 대수로 증가
  - 쿨다운 : `60` 초

- Scale-in 정책
  - 정책명 : `app_scale_in`
  - 실행 조건 : Average , CPU Usage, <= , `20` % , `1` 분 동안 발생
  - 실행 단위 : 지정 대수만큼 서버 수 증감 , `1` 대수로 반납
  - 쿨다운 : `60` 초

- 알림 설정 : 나중에 설정

## Stress Test  

Web Server에서 실행

```bash
sudo yum -y install epel-release
sudo yum -y install stress
stress -c 1 &
top
```

App Server에서 실행

```bash
sudo yum -y install epel-release
sudo yum -y install stress
stress -c 1 &
top
```
