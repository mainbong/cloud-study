# Ch1. Linux 기반 환경 운영

## 📋 개요

Linux는 클라우드 인프라의 기반이 되는 운영체제입니다. 대규모 클라우드 환경에서 Linux 시스템을 효과적으로 관리하고 운영하는 능력은 모든 클라우드 엔지니어에게 필수적인 역량입니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:
- 대규모 Linux 환경에서 서비스를 안정적으로 운영
- Linux 시스템 관리 및 트러블슈팅 수행
- Shell 스크립트를 활용한 반복 작업 자동화
- 시스템 성능 분석 및 최적화

---

## 🎯 핵심 개념 및 이론

### 1. Linux 시스템 관리 기초

#### 파일시스템 관리

Linux 파일시스템은 계층적 구조로 되어 있으며, 모든 것이 파일로 표현됩니다.

**주요 디렉토리 구조:**

- `/` - 루트 디렉토리 (모든 파일시스템의 시작점)
- `/bin`, `/sbin` - 필수 시스템 바이너리
- `/etc` - 시스템 설정 파일
- `/var` - 가변 데이터 (로그, 캐시 등)
- `/home` - 사용자 홈 디렉토리
- `/tmp` - 임시 파일
- `/usr` - 사용자 프로그램 및 데이터

**파일시스템 작업:**
```bash
# 디스크 사용량 확인
df -h

# 디렉토리 크기 확인
du -sh /var/log

# 마운트된 파일시스템 확인
mount | column -t

# 파일시스템 마운트
mount /dev/sdb1 /mnt/data

# /etc/fstab에 영구 마운트 설정
echo "/dev/sdb1  /mnt/data  ext4  defaults  0  2" >> /etc/fstab
```

**스토리지 관리 Best Practices (2025):**

- **RAID (Redundant Array of Independent Disks)**: 데이터 중복성 확보
- **LVM (Logical Volume Manager)**: 유연한 스토리지 관리

```bash
# LVM 볼륨 생성 예제
pvcreate /dev/sdb1                    # Physical Volume 생성
vgcreate vg_data /dev/sdb1            # Volume Group 생성
lvcreate -L 100G -n lv_app vg_data   # Logical Volume 생성
mkfs.ext4 /dev/vg_data/lv_app         # 파일시스템 생성
```

#### 프로세스 관리

프로세스는 실행 중인 프로그램의 인스턴스입니다.

**프로세스 확인 및 관리:**
```bash
# 실행 중인 프로세스 확인
ps aux
ps -ef

# 특정 프로세스 찾기
ps aux | grep nginx

# 프로세스 트리 확인
pstree

# 프로세스 종료
kill <PID>           # SIGTERM (graceful shutdown)
kill -9 <PID>        # SIGKILL (강제 종료)
killall nginx        # 프로세스 이름으로 종료

# 백그라운드 작업 관리
command &            # 백그라운드 실행
jobs                 # 백그라운드 작업 목록
fg %1                # 작업을 포그라운드로 가져오기
bg %1                # 일시정지된 작업을 백그라운드로 재개
```

**Systemd 서비스 관리:**
```bash
# 서비스 상태 확인
systemctl status nginx

# 서비스 시작/중지/재시작
systemctl start nginx
systemctl stop nginx
systemctl restart nginx
systemctl reload nginx    # 설정 재로드 (무중단)

# 부팅 시 자동 시작
systemctl enable nginx
systemctl disable nginx

# 서비스 로그 확인
journalctl -u nginx -f    # 실시간 로그
journalctl -u nginx --since "1 hour ago"
```

**프로세스 모니터링 Best Practice (2025):**

**Monit** - 무료 오픈소스 프로세스 감시 유틸리티:
```bash
# Monit 설치
apt install monit

# /etc/monit/monitrc 설정 예제
check process nginx with pidfile /var/run/nginx.pid
    start program = "/usr/bin/systemctl start nginx"
    stop program = "/usr/bin/systemctl stop nginx"
    if failed host localhost port 80 protocol http then restart
    if 5 restarts within 5 cycles then timeout
```

#### 네트워크 설정

```bash
# 네트워크 인터페이스 확인
ip addr show
ip link show

# IP 주소 설정
ip addr add 192.168.1.100/24 dev eth0

# 라우팅 테이블 확인
ip route show

# 기본 게이트웨이 설정
ip route add default via 192.168.1.1

# 네트워크 연결 테스트
ping 8.8.8.8
traceroute google.com
netstat -tuln          # 리스닝 포트 확인
ss -tuln               # 최신 도구 (netstat 대체)
```

**네트워크 설정 영구화 (Ubuntu/Debian):**
```yaml
# /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

#### 시스템 모니터링

**4가지 주요 성능 영역 (2025 Best Practice):**
1. **CPU** - 처리 능력
2. **Memory** - 메모리 사용량
3. **Disk I/O** - 디스크 입출력
4. **Network** - 네트워크 대역폭

**기본 모니터링 명령어:**
```bash
# CPU 사용률
top              # 실시간 프로세스 모니터
htop             # 향상된 top (설치 필요)
mpstat 1         # CPU 통계 (1초 간격)

# 메모리 사용량
free -h          # 메모리 및 스왑 사용량
vmstat 1         # 가상 메모리 통계

# 디스크 I/O
iostat -x 1      # 디스크 I/O 통계
iotop            # 프로세스별 I/O 사용량

# 종합 모니터링
dstat            # 모든 리소스 통합 뷰
nmon             # 대화형 성능 모니터
glances          # 웹 기반 모니터링 도구
```

---

### 2. Shell 스크립팅

Shell 스크립트는 반복적인 작업을 자동화하는 강력한 도구입니다.

#### Bash 스크립트 기초

**기본 구조:**
```bash
#!/bin/bash
# 스크립트 설명

# 변수 선언
NAME="CloudAdmin"
COUNT=10

# 출력
echo "Hello, $NAME"

# 조건문
if [ $COUNT -gt 5 ]; then
    echo "Count is greater than 5"
else
    echo "Count is 5 or less"
fi

# 반복문
for i in {1..5}; do
    echo "Iteration $i"
done

# 함수
function greet() {
    local name=$1
    echo "Hello, $name!"
}

greet "World"
```

#### 실전 자동화 스크립트

**1. 시스템 백업 스크립트:**
```bash
#!/bin/bash
# backup.sh - 시스템 백업 자동화

BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)
SOURCE_DIRS="/etc /home /var/www"

# 백업 디렉토리 생성
mkdir -p $BACKUP_DIR

# 백업 수행
tar -czf "$BACKUP_DIR/backup_$DATE.tar.gz" $SOURCE_DIRS

# 7일 이상 된 백업 삭제
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: backup_$DATE.tar.gz"
```

**2. 다중 서버 사용자 생성 스크립트:**
```bash
#!/bin/bash
# create_users.sh - 여러 서버에 사용자 생성

SERVERS=(
    "server1.example.com"
    "server2.example.com"
    "server3.example.com"
)

USERNAME="newuser"
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

for server in "${SERVERS[@]}"; do
    echo "Creating user on $server..."

    ssh root@$server << EOF
        # 사용자 생성
        useradd -m -s /bin/bash $USERNAME

        # SSH 키 설정
        mkdir -p /home/$USERNAME/.ssh
        echo "$PUBLIC_KEY" > /home/$USERNAME/.ssh/authorized_keys
        chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
        chmod 700 /home/$USERNAME/.ssh
        chmod 600 /home/$USERNAME/.ssh/authorized_keys

        # sudo 권한 부여
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

        echo "User $USERNAME created successfully"
EOF
done
```

**3. 로그 분석 스크립트:**
```bash
#!/bin/bash
# analyze_logs.sh - 로그 파일 분석 및 요약

LOG_FILE="/var/log/nginx/access.log"
REPORT_FILE="/tmp/log_report_$(date +%Y%m%d).txt"

echo "Log Analysis Report - $(date)" > $REPORT_FILE
echo "================================" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# 총 요청 수
echo "Total Requests: $(wc -l < $LOG_FILE)" >> $REPORT_FILE

# 고유 IP 수
echo "Unique IPs: $(awk '{print $1}' $LOG_FILE | sort -u | wc -l)" >> $REPORT_FILE

# 상위 10개 IP
echo "" >> $REPORT_FILE
echo "Top 10 IPs:" >> $REPORT_FILE
awk '{print $1}' $LOG_FILE | sort | uniq -c | sort -rn | head -10 >> $REPORT_FILE

# 상위 10개 요청 URL
echo "" >> $REPORT_FILE
echo "Top 10 URLs:" >> $REPORT_FILE
awk '{print $7}' $LOG_FILE | sort | uniq -c | sort -rn | head -10 >> $REPORT_FILE

# HTTP 상태 코드 분포
echo "" >> $REPORT_FILE
echo "HTTP Status Codes:" >> $REPORT_FILE
awk '{print $9}' $LOG_FILE | sort | uniq -c | sort -rn >> $REPORT_FILE

cat $REPORT_FILE
```

**4. 시스템 헬스 체크 스크립트:**
```bash
#!/bin/bash
# health_check.sh - 시스템 상태 모니터링

# CPU 사용률 체크 (80% 이상 경고)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    echo "WARNING: High CPU usage: $CPU_USAGE%"
fi

# 메모리 사용률 체크 (90% 이상 경고)
MEMORY_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
if (( $(echo "$MEMORY_USAGE > 90" | bc -l) )); then
    echo "WARNING: High memory usage: $MEMORY_USAGE%"
fi

# 디스크 사용률 체크 (90% 이상 경고)
df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{print $5 " " $1}' | while read output;
do
    usage=$(echo $output | awk '{print $1}' | cut -d'%' -f1)
    partition=$(echo $output | awk '{print $2}')
    if [ $usage -ge 90 ]; then
        echo "WARNING: Disk usage on $partition: $usage%"
    fi
done

# 중요 서비스 상태 체크
SERVICES=("nginx" "mysql" "redis")
for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet $service; then
        echo "ERROR: Service $service is not running"
    fi
done
```

#### Cron을 이용한 작업 스케줄링

```bash
# Crontab 편집
crontab -e

# Cron 작업 예제
# 분 시 일 월 요일 명령어
# 매일 오전 2시에 백업
0 2 * * * /usr/local/bin/backup.sh

# 매시간 로그 로테이션
0 * * * * /usr/sbin/logrotate /etc/logrotate.conf

# 5분마다 헬스 체크
*/5 * * * * /usr/local/bin/health_check.sh

# 매주 월요일 오전 3시에 시스템 업데이트
0 3 * * 1 /usr/bin/apt update && /usr/bin/apt upgrade -y
```

---

### 3. 시스템 성능 분석

#### 필수 성능 모니터링 도구

**1. Top / Htop / Atop**

```bash
# top - 기본 프로세스 모니터
top

# 주요 단축키:
# P - CPU 사용률로 정렬
# M - 메모리 사용률로 정렬
# k - 프로세스 종료
# 1 - 개별 CPU 코어 표시

# htop - 향상된 대화형 프로세스 뷰어
htop

# atop - 디스크 I/O 포함
atop
```

**2. Vmstat - 시스템 리소스 통계**

```bash
# 1초 간격으로 통계 출력
vmstat 1

# 출력 필드 설명:
# r: 실행 대기 중인 프로세스
# b: 블록 I/O 대기 중인 프로세스
# swpd: 사용 중인 스왑 메모리
# free: 여유 메모리
# buff/cache: 버퍼와 캐시 메모리
# si/so: 스왑 인/아웃
# bi/bo: 블록 입/출력
# in: 인터럽트 수
# cs: 컨텍스트 스위칭 수
# us/sy/id/wa: CPU 시간 분포
```

**3. Iostat - 디스크 I/O 통계**

```bash
# 확장 통계 표시 (1초 간격)
iostat -x 1

# 주요 메트릭:
# r/s, w/s: 초당 읽기/쓰기 요청
# rkB/s, wkB/s: 초당 읽기/쓰기 KB
# await: 평균 대기 시간 (ms)
# %util: 디스크 사용률
```

**4. Iotop - 프로세스별 I/O 모니터링**

```bash
# 실시간 프로세스별 I/O 모니터링
iotop

# 쓰기 작업만 표시
iotop -o
```

**5. Dstat - 통합 시스템 모니터링**

```bash
# 모든 리소스 모니터링 (컬러 출력)
dstat

# CPU, 디스크, 네트워크, 메모리 통계
dstat -cdnm

# 특정 디스크 모니터링
dstat -D sda,sdb
```

**6. Sar - 시스템 활동 리포트**

```bash
# CPU 사용률 (1초 간격, 10회)
sar -u 1 10

# 메모리 사용률
sar -r 1 10

# 디스크 I/O
sar -d 1 10

# 네트워크 통계
sar -n DEV 1 10

# 과거 데이터 확인
sar -f /var/log/sysstat/sa$(date +%d)
```

**7. Nmon - 종합 성능 모니터**

```bash
# Nmon 실행
nmon

# 인터랙티브 키:
# c - CPU
# m - Memory
# d - Disk
# n - Network
# t - Top processes
```

**8. Glances - 웹 기반 모니터링**

```bash
# Glances 실행
glances

# 웹 서버 모드
glances -w

# 특정 포트로 웹 서버 실행
glances -w --port 8080
```

**9. Netdata - 실시간 성능 대시보드**

```bash
# Netdata 설치 및 실행
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

# 웹 브라우저에서 접속
# http://localhost:19999
```

#### 성능 병목 현상 식별

**CPU 병목:**
```bash
# CPU 부하 확인
uptime
# load average가 CPU 코어 수보다 높으면 병목

# CPU를 많이 사용하는 프로세스
ps aux --sort=-%cpu | head -10

# 프로세스별 CPU 사용 내역
pidstat -u 1
```

**메모리 병목:**
```bash
# 메모리 사용량 상세
free -m
cat /proc/meminfo

# 메모리를 많이 사용하는 프로세스
ps aux --sort=-%mem | head -10

# 스왑 사용 확인
swapon -s
vmstat 1 | awk '{print $7, $8}'  # si/so 값이 높으면 스왑 병목
```

**디스크 I/O 병목:**
```bash
# I/O 대기 시간 확인
iostat -x 1
# await > 10ms 이면 느림
# %util > 80% 이면 포화 상태

# I/O를 많이 사용하는 프로세스
iotop -o

# 디스크별 I/O 통계
dstat -d -D sda,sdb
```

**네트워크 병목:**
```bash
# 네트워크 대역폭 사용량
iftop

# 연결 상태 통계
ss -s

# 네트워크 오류 확인
netstat -i
ip -s link
```

---

## 🛠️ 실습 가이드

### 실습 1: Linux 시스템 초기 설정

**목표:** 새로운 Linux 서버를 프로덕션 환경에 맞게 설정

```bash
# 1. 시스템 업데이트
apt update && apt upgrade -y

# 2. 필수 패키지 설치
apt install -y \
    vim \
    git \
    curl \
    wget \
    htop \
    iotop \
    net-tools \
    dstat \
    sysstat

# 3. 타임존 설정
timedatectl set-timezone Asia/Seoul

# 4. hostname 설정
hostnamectl set-hostname web-server-01

# 5. swap 설정 (메모리의 2배)
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# 6. 방화벽 설정 (UFW)
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable

# 7. 자동 보안 업데이트 활성화
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

### 실습 2: 로그 관리 및 로테이션

**목표:** 로그 로테이션을 설정하여 디스크 공간 관리

```bash
# /etc/logrotate.d/custom-app 파일 생성
cat > /etc/logrotate.d/custom-app << 'EOF'
/var/log/myapp/*.log {
    daily                    # 매일 로테이션
    rotate 7                 # 7개 보관
    compress                 # 압축
    delaycompress           # 다음 로테이션 시 압축
    missingok               # 파일 없어도 에러 없음
    notifempty              # 빈 파일은 로테이트 안함
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

# 로그 로테이션 테스트
logrotate -d /etc/logrotate.d/custom-app

# 강제 로테이션
logrotate -f /etc/logrotate.d/custom-app
```

### 실습 3: 성능 모니터링 대시보드 구축

**목표:** Netdata를 사용한 실시간 모니터링 환경 구축

```bash
# Netdata 설치
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

# Nginx 리버스 프록시 설정 (선택사항)
cat > /etc/nginx/sites-available/netdata << 'EOF'
upstream netdata {
    server 127.0.0.1:19999;
    keepalive 64;
}

server {
    listen 80;
    server_name monitoring.example.com;

    location / {
        proxy_pass http://netdata;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
EOF

ln -s /etc/nginx/sites-available/netdata /etc/nginx/sites-enabled/
systemctl reload nginx
```

### 실습 4: 자동화된 백업 시스템

**목표:** 자동 백업 및 원격 저장소로 전송

```bash
#!/bin/bash
# /usr/local/bin/automated_backup.sh

BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)
REMOTE_SERVER="backup-server.example.com"
REMOTE_DIR="/backup/web-server"

# 데이터베이스 백업
mysqldump -u root -p$DB_PASSWORD --all-databases | gzip > "$BACKUP_DIR/db_$DATE.sql.gz"

# 파일 백업
tar -czf "$BACKUP_DIR/files_$DATE.tar.gz" /var/www /etc

# 원격 서버로 전송
rsync -avz --delete \
    $BACKUP_DIR/ \
    backup-user@$REMOTE_SERVER:$REMOTE_DIR/

# 로컬 오래된 백업 삭제 (30일)
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete

# 백업 성공 알림
echo "Backup completed at $(date)" | mail -s "Backup Success" admin@example.com
```

```bash
# Cron 작업 등록 (매일 새벽 2시)
echo "0 2 * * * /usr/local/bin/automated_backup.sh" | crontab -
```

---

## 💻 예제 코드

### 종합 시스템 모니터링 스크립트

```bash
#!/bin/bash
# system_monitor.sh - 종합 시스템 모니터링 및 알림

# 설정
ADMIN_EMAIL="admin@example.com"
CPU_THRESHOLD=80
MEMORY_THRESHOLD=90
DISK_THRESHOLD=85

# 로그 파일
LOG_FILE="/var/log/system_monitor.log"

# 함수: 로그 기록
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# 함수: 알림 전송
send_alert() {
    local subject="$1"
    local message="$2"
    echo "$message" | mail -s "$subject" $ADMIN_EMAIL
    log_message "ALERT: $subject"
}

# CPU 모니터링
check_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1)

    if [ $cpu_usage -gt $CPU_THRESHOLD ]; then
        local top_processes=$(ps aux --sort=-%cpu | head -6 | tail -5)
        send_alert "High CPU Usage: ${cpu_usage}%" \
            "CPU usage is at ${cpu_usage}%\n\nTop Processes:\n$top_processes"
    fi
}

# 메모리 모니터링
check_memory() {
    local memory_usage=$(free | grep Mem | awk '{printf("%.0f", ($3/$2) * 100)}')

    if [ $memory_usage -gt $MEMORY_THRESHOLD ]; then
        local top_processes=$(ps aux --sort=-%mem | head -6 | tail -5)
        send_alert "High Memory Usage: ${memory_usage}%" \
            "Memory usage is at ${memory_usage}%\n\nTop Processes:\n$top_processes"
    fi
}

# 디스크 모니터링
check_disk() {
    df -H | grep -vE '^Filesystem|tmpfs|cdrom' | while read output; do
        usage=$(echo $output | awk '{print $5}' | cut -d'%' -f1)
        partition=$(echo $output | awk '{print $1}')

        if [ $usage -gt $DISK_THRESHOLD ]; then
            send_alert "High Disk Usage on $partition: ${usage}%" \
                "Disk usage on $partition is at ${usage}%\n\n$(df -h $partition)"
        fi
    done
}

# 서비스 모니터링
check_services() {
    local services=("nginx" "mysql" "redis-server")

    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet $service 2>/dev/null; then
            send_alert "Service Down: $service" \
                "Service $service is not running\n\n$(systemctl status $service)"
        fi
    done
}

# 네트워크 연결 모니터링
check_network() {
    local test_hosts=("8.8.8.8" "1.1.1.1")
    local failed=0

    for host in "${test_hosts[@]}"; do
        if ! ping -c 2 $host &> /dev/null; then
            ((failed++))
        fi
    done

    if [ $failed -eq ${#test_hosts[@]} ]; then
        send_alert "Network Connectivity Issue" \
            "Unable to reach external hosts\n\n$(ip route show)\n\n$(ip addr show)"
    fi
}

# 메인 실행
main() {
    log_message "Starting system monitoring"

    check_cpu
    check_memory
    check_disk
    check_services
    check_network

    log_message "System monitoring completed"
}

main
```

### 사용자 관리 자동화 스크립트

```bash
#!/bin/bash
# user_management.sh - 사용자 생성/삭제 자동화

# 사용자 생성
create_user() {
    local username=$1
    local public_key=$2

    # 사용자 생성
    useradd -m -s /bin/bash $username

    # SSH 디렉토리 및 키 설정
    mkdir -p /home/$username/.ssh
    echo "$public_key" > /home/$username/.ssh/authorized_keys
    chown -R $username:$username /home/$username/.ssh
    chmod 700 /home/$username/.ssh
    chmod 600 /home/$username/.ssh/authorized_keys

    # sudo 권한 부여 (선택사항)
    echo "$username ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$username
    chmod 440 /etc/sudoers.d/$username

    echo "User $username created successfully"
}

# 사용자 삭제
delete_user() {
    local username=$1

    # 사용자 삭제 (홈 디렉토리 포함)
    userdel -r $username

    # sudoers 파일 삭제
    rm -f /etc/sudoers.d/$username

    echo "User $username deleted successfully"
}

# 사용자 목록 표시
list_users() {
    echo "System Users:"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd
}

# 메뉴 표시
show_menu() {
    echo "================================"
    echo " User Management Script"
    echo "================================"
    echo "1. Create User"
    echo "2. Delete User"
    echo "3. List Users"
    echo "4. Exit"
    echo "================================"
}

# 메인 루프
while true; do
    show_menu
    read -p "Select option: " option

    case $option in
        1)
            read -p "Enter username: " username
            read -p "Enter SSH public key: " public_key
            create_user "$username" "$public_key"
            ;;
        2)
            read -p "Enter username to delete: " username
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                delete_user "$username"
            fi
            ;;
        3)
            list_users
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac

    echo
done
```

---

## 📚 참고 자료

### 공식 문서
- [Linux Documentation Project](https://tldp.org/)
- [Red Hat Enterprise Linux Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [Arch Linux Wiki](https://wiki.archlinux.org/) (매우 상세한 레퍼런스)

### 학습 자료
- [Linux System Administration Guide](https://www.tldp.org/LDP/sag/html/)
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Linux Performance](https://www.brendangregg.com/linuxperf.html) - Brendan Gregg의 성능 튜닝 가이드
- [Linux Journal](https://www.linuxjournal.com/)

### 도구 문서
- [Systemd Documentation](https://www.freedesktop.org/wiki/Software/systemd/)
- [Netdata Documentation](https://learn.netdata.cloud/)
- [Prometheus Node Exporter](https://github.com/prometheus/node_exporter)

### 온라인 강좌
- [Linux Foundation - Linux System Administration Essentials (LFS207)](https://training.linuxfoundation.org/training/linux-system-administration-essentials-lfs207/)
- [Udemy - Linux Administration Bootcamp](https://www.udemy.com/course/master-linux-administration/)

### 커뮤니티
- [r/linuxadmin](https://www.reddit.com/r/linuxadmin/)
- [Server Fault](https://serverfault.com/)
- [Linux Questions](https://www.linuxquestions.org/)

### 모범 사례 (2025)
- [CyberPanel - 10 Linux System Administration Practices for 2025](https://cyberpanel.net/blog/linux-system-administration)
- [Linux System Administration Best Practices (UPenn)](https://cets.seas.upenn.edu/answers/linux-best-practices.html)

---

## ✅ 학습 체크리스트

- [ ] Linux 파일시스템 구조 이해 및 관리 가능
- [ ] LVM을 사용한 스토리지 관리
- [ ] Systemd를 사용한 서비스 관리
- [ ] 네트워크 설정 및 트러블슈팅
- [ ] Bash 스크립트 작성 능력
- [ ] 반복 작업 자동화 스크립트 개발
- [ ] Cron을 사용한 스케줄링
- [ ] top, htop, vmstat 등 기본 모니터링 도구 사용
- [ ] iostat, iotop으로 디스크 I/O 분석
- [ ] 성능 병목 현상 식별 및 해결
- [ ] 로그 관리 및 분석
- [ ] 시스템 백업 및 복구 전략 수립

---

## 🎓 다음 단계

Linux 운영 기초를 마스터한 후:
- [Ch2. Python/GO 프로그래밍](./Ch2.Python_GO.md)으로 진행
- 또는 [README](./README.md)로 돌아가서 학습 로드맵 확인
