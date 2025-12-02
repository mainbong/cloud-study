# Ch5. 네트워크 어플라이언스

## 📋 개요

네트워크 어플라이언스는 방화벽, 로드 밸런서, VPN 게이트웨이 등 네트워크 인프라의 핵심 기능을 제공하는 특수 목적 시스템입니다. 전통적으로 전용 하드웨어로 제공되었지만, 가상화 기술의 발전으로 가상 어플라이언스(Virtual Appliance)가 주류가 되었습니다.

2025년 현재, pfSense와 OPNsense는 가장 인기 있는 오픈소스 방화벽이며, HAProxy와 Nginx는 고성능 로드 밸런서의 표준입니다. Envoy와 Traefik은 클라우드 네이티브 환경에서 Service Mesh와 Ingress Controller로 널리 사용되고 있습니다.

이 챕터에서는 주요 네트워크 어플라이언스의 설치, 구성, 성능 최적화, 그리고 실무 활용 방법을 다룹니다.

---

## 🎯 학습 목표

이 챕터를 완료하면 다음을 할 수 있습니다:

- pfSense와 OPNsense 비교 및 적절한 선택
- Virtual Firewall 설치 및 고급 기능 설정
- HAProxy, Nginx, Envoy, Traefik 성능 비교 및 선택
- 고가용성(HA) 로드 밸런서 구성
- SSL/TLS Termination 및 HTTP/3 설정
- 로드 밸런싱 알고리즘 선택 및 최적화
- 네트워크 어플라이언스 모니터링 및 트러블슈팅

---

## Part 1: Virtual Firewall

### 1-1. pfSense vs OPNsense (2025)

**개요:**

pfSense와 OPNsense는 모두 FreeBSD 기반의 오픈소스 방화벽/라우터 플랫폼입니다. OPNsense는 2015년 pfSense에서 포크되어 나왔으며, 진정한 오픈소스 철학을 추구합니다.

**주요 차이점 (2025):**

| 특성 | pfSense | OPNsense |
|------|---------|----------|
| **UI/UX** | 구식, 덜 직관적 | 모던, 터치스크린 지원 |
| **업데이트 모델** | 메이저 릴리스 | 롤링 릴리스 (잦은 업데이트) |
| **롤백 기능** | 제한적 | 전체 롤백 지원 ⭐ |
| **VPN** | IPsec, OpenVPN | IPsec, OpenVPN, WireGuard ⭐ |
| **2FA** | 플러그인 필요 | 내장 ⭐ |
| **가상화 지원** | 보통 | 우수 (VM 최적화) ⭐ |
| **하드웨어 중심** | Netgate 장비 | 소프트웨어 중심 |
| **오픈소스 철학** | 제한적 | 완전 오픈소스 ⭐ |
| **커뮤니티** | 크고 성숙 | 성장 중 |
| **기업 지원** | Netgate | Deciso |

**선택 가이드:**

- **pfSense 선택**:
  - Netgate 하드웨어 사용
  - 안정성 최우선
  - 큰 커뮤니티 필요

- **OPNsense 선택**: ⭐ 2025 권장
  - 가상 환경 (VM/Cloud)
  - WireGuard VPN 필요
  - 자주 업데이트 선호
  - 진정한 오픈소스 원함
  - 모던 UI 선호

### 1-2. OPNsense 설치 및 기본 설정

**시스템 요구사항 (2025):**

```
최소:
- CPU: 1 GHz (x86-64)
- RAM: 1 GB
- Disk: 8 GB
- NIC: 2개 (WAN, LAN)

권장 (프로덕션):
- CPU: 4 cores
- RAM: 4 GB
- Disk: 40 GB SSD
- NIC: 2-4개
```

**가상 환경 설치 (KVM/QEMU):**

```bash
# OPNsense ISO 다운로드
wget https://mirror.ams1.nl.leaseweb.net/opnsense/releases/25.1/OPNsense-25.1-dvd-amd64.iso.bz2
bunzip2 OPNsense-25.1-dvd-amd64.iso.bz2

# VM 생성 (virt-install)
virt-install \
  --name opnsense \
  --ram 4096 \
  --vcpus 4 \
  --disk path=/var/lib/libvirt/images/opnsense.qcow2,size=40 \
  --network bridge=br-wan \
  --network bridge=br-lan \
  --cdrom /path/to/OPNsense-25.1-dvd-amd64.iso \
  --graphics vnc \
  --os-variant freebsd13.0

# VNC로 접속하여 설치 진행
# root / opnsense (기본 비밀번호)
```

**초기 설정 (콘솔):**

```
OPNsense 콘솔 메뉴:

1) Assign interfaces
2) Set interface IP address
3) Reset webConfigurator password
4) Reset to factory defaults
5) Power off system
6) Reboot system
7) Ping host
8) Shell
9) pfTop
10) Firewall log
11) Reload all services
12) Update from console
13) Restore configuration
14) Restart SSH

초기 설정:
1. 인터페이스 할당 (WAN: em0, LAN: em1)
2. LAN IP 설정 (192.168.1.1/24)
3. DHCP 서버 활성화
4. WebGUI 비밀번호 변경
```

**웹 인터페이스 접속:**

```
URL: https://192.168.1.1
Username: root
Password: opnsense (변경 필요)

초기 마법사:
1. General Information
   - Hostname: firewall
   - Domain: example.local
   - Primary/Secondary DNS

2. Time Server Information
   - Timezone: Asia/Seoul
   - NTP Server: pool.ntp.org

3. WAN Interface Configuration
   - Type: DHCP / Static / PPPoE
   - IPv4 Address / Gateway

4. LAN Interface Configuration
   - IP: 192.168.1.1/24

5. Root Password
   - 강력한 비밀번호 설정

6. Reload configuration
```

### 1-3. OPNsense 고급 기능

**1. 방화벽 규칙 (Firewall Rules):**

```
Firewall → Rules → LAN

규칙 예제:

# HTTP/HTTPS 허용 (인터넷)
Action: Pass
Interface: LAN
Protocol: TCP
Source: LAN net
Destination: any
Destination Port: 80,443
Description: Allow web browsing

# SSH 허용 (관리용, 특정 IP만)
Action: Pass
Interface: LAN
Protocol: TCP
Source: 192.168.1.100
Destination: any
Destination Port: 22
Description: Allow SSH from admin PC

# 기본 차단 (Implicit Deny)
모든 규칙 아래에 자동으로 적용됨
```

**2. NAT (Network Address Translation):**

```
Firewall → NAT → Port Forward

포트 포워딩 예제:

# 웹 서버 (80 → 192.168.1.10:80)
Interface: WAN
Protocol: TCP
Destination: WAN address
Destination Port: 80
Redirect target IP: 192.168.1.10
Redirect target port: 80
Description: Web Server

# SSH 서버 (2222 → 192.168.1.20:22)
Interface: WAN
Protocol: TCP
Destination: WAN address
Destination Port: 2222
Redirect target IP: 192.168.1.20
Redirect target port: 22
Description: SSH Server
```

**3. WireGuard VPN (2025 권장):**

```
VPN → WireGuard

# 1. Local 인스턴스 생성
Name: wg0
Listen Port: 51820
Tunnel Address: 10.10.10.1/24
Private Key: (자동 생성)

# 2. Endpoint (피어) 추가
Name: mobile-client
Public Key: <클라이언트 공개키>
Allowed IPs: 10.10.10.2/32
Endpoint Address: (비워둠 - 클라이언트가 연결)
Endpoint Port: (비워둠)

# 3. 클라이언트 설정 파일 생성
[Interface]
PrivateKey = <클라이언트 개인키>
Address = 10.10.10.2/24
DNS = 192.168.1.1

[Peer]
PublicKey = <서버 공개키>
Endpoint = <서버 WAN IP>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25

# 4. 방화벽 규칙 추가
Interface: WireGuard (wg0)
Action: Pass
Protocol: any
Source: 10.10.10.0/24
Destination: LAN net
```

**4. IDS/IPS (Intrusion Detection/Prevention):**

```
Services → Intrusion Detection

설정:
☑ Enabled
☑ IPS mode (차단 모드)
Interfaces: WAN, LAN
Pattern matcher: Hyperscan (고성능)
Rulesets:
  ☑ abuse.ch
  ☑ ET open/emerging-threats
  ☑ OPNsense specific rules

규칙 업데이트:
- 자동 업데이트: 매일 03:00
- 수동 업데이트: Download & Update Rules

로그 확인:
Services → Intrusion Detection → Alerts
```

**5. 고가용성 (HA) 구성:**

```
System → High Availability → Settings

CARP 설정:
☑ Enable CARP
Synchronize Config to IP: <백업 방화벽 IP>
Remote System Username: root
Remote System Password: <비밀번호>

Synchronize:
☑ Synchronize rules
☑ Synchronize NAT
☑ Synchronize DHCP
☑ Synchronize Virtual IPs

가상 IP 설정 (Firewall → Virtual IPs):
Type: CARP
Interface: LAN
Address: 192.168.1.254/24
VHID Group: 1
Advertising Frequency: Base 1 / Skew 0
Password: (강력한 비밀번호)

백업 방화벽에서:
동일한 설정, 단 Skew를 100으로 설정
```

---

## Part 2: Load Balancer

### 2-1. Load Balancer 비교 (2025)

**HAProxy:**

```
특징:
- 전용 로드 밸런서 (단일 목적)
- 최고 성능 (50,000+ req/s)
- 복잡한 라우팅 규칙 우수
- TCP/HTTP/HTTPS 지원
- 레거시 배포 최적

아키텍처:
┌──────────────────────────────────┐
│         HAProxy Process          │
│  ┌────────────────────────────┐  │
│  │  Frontend (Listen)         │  │
│  │  - bind :80, :443          │  │
│  └────────────┬───────────────┘  │
│               │                  │
│  ┌────────────▼───────────────┐  │
│  │  Backend (Servers)         │  │
│  │  - server1 192.168.1.10:80 │  │
│  │  - server2 192.168.1.11:80 │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘

성능:
- 처리량: ⭐⭐⭐⭐⭐ (최고)
- 지연시간: < 1ms
- 동시 연결: 수십만
```

**Nginx:**

```
특징:
- 웹 서버 + 로드 밸런서 (다목적)
- 정적 콘텐츠 서빙 우수
- HTTP/2, HTTP/3 지원 우수
- 많은 동시 연결 처리 우수
- 모던 웹 애플리케이션 최적

아키텍처:
┌──────────────────────────────────┐
│       Nginx Master Process       │
│  ┌────────────────────────────┐  │
│  │  Worker Processes (N)      │  │
│  │  - Event-driven            │  │
│  │  - Non-blocking I/O        │  │
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │  Upstream Servers          │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘

성능:
- 처리량: ⭐⭐⭐⭐
- 지연시간: < 2ms
- 동시 연결: 수십만
- 정적 파일: ⭐⭐⭐⭐⭐
```

**Envoy:**

```
특징:
- Service Mesh 프록시
- xDS API (동적 설정)
- 고급 관찰성 (Observability)
- gRPC 네이티브 지원
- 클라우드 네이티브 최적

아키텍처:
┌──────────────────────────────────┐
│         Envoy Proxy              │
│  ┌────────────────────────────┐  │
│  │  Listeners                 │  │
│  ├────────────────────────────┤  │
│  │  Filters (HTTP, TCP, ...)  │  │
│  ├────────────────────────────┤  │
│  │  Clusters (Upstreams)      │  │
│  ├────────────────────────────┤  │
│  │  xDS APIs (동적 설정)       │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘

성능:
- 처리량: ⭐⭐⭐⭐
- 지연시간: < 5ms
- Service Mesh: ⭐⭐⭐⭐⭐
- 관찰성: ⭐⭐⭐⭐⭐
```

**Traefik:**

```
특징:
- 클라우드 네이티브 프록시
- Kubernetes/Docker 네이티브
- 자동 서비스 디스커버리
- Let's Encrypt 자동 인증서
- 개발자 친화적

아키텍처:
┌──────────────────────────────────┐
│         Traefik Proxy            │
│  ┌────────────────────────────┐  │
│  │  Providers (K8s, Docker)   │  │
│  │  - 자동 설정 감지           │  │
│  ├────────────────────────────┤  │
│  │  Routers (라우팅 규칙)      │  │
│  ├────────────────────────────┤  │
│  │  Services (백엔드)          │  │
│  ├────────────────────────────┤  │
│  │  Middlewares (인증, CORS)  │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘

성능:
- 처리량: ⭐⭐⭐
- 지연시간: < 10ms
- 자동화: ⭐⭐⭐⭐⭐
- K8s 통합: ⭐⭐⭐⭐⭐
```

**2025 성능 벤치마크:**

```
HTTP/1.1 (50,000 req/s 부하):
┌──────────┬───────────┬──────────┬──────────┐
│ Proxy    │ Latency   │ CPU (%)  │ Memory   │
├──────────┼───────────┼──────────┼──────────┤
│ HAProxy  │  0.8 ms   │   45%    │  150 MB  │⭐
│ Nginx    │  1.2 ms   │   52%    │  180 MB  │
│ Envoy    │  2.5 ms   │   68%    │  320 MB  │
│ Traefik  │  4.1 ms   │   75%    │  280 MB  │
└──────────┴───────────┴──────────┴──────────┘

HTTP/2:
Nginx, Envoy 우수 (네이티브 지원)

HTTP/3 (QUIC):
Nginx > Envoy > HAProxy (실험적)

gRPC:
Envoy ⭐⭐⭐⭐⭐
Traefik ⭐⭐⭐⭐
Nginx ⭐⭐⭐
HAProxy ⭐⭐

Service Mesh:
Envoy ⭐⭐⭐⭐⭐ (Istio 백본)
```

**선택 가이드:**

| 시나리오 | 추천 |
|---------|------|
| **최고 성능 필요** | HAProxy |
| **정적 콘텐츠 + LB** | Nginx |
| **HTTP/3 필요** | Nginx |
| **Microservices/gRPC** | Envoy |
| **Service Mesh** | Envoy (Istio) |
| **Kubernetes** | Traefik / Nginx Ingress |
| **자동 설정** | Traefik |

### 2-2. HAProxy 설치 및 설정

**설치:**

```bash
# Ubuntu/Debian
apt-get install haproxy

# CentOS/RHEL
yum install haproxy

# 최신 버전 (PPA)
add-apt-repository ppa:vbernat/haproxy-2.9
apt-get update
apt-get install haproxy=2.9.\*
```

**기본 설정 (/etc/haproxy/haproxy.cfg):**

```bash
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

    # 성능 튜닝
    maxconn 50000
    nbthread 4
    cpu-map auto:1/1-4 0-3

    # SSL 설정
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

# 통계 페이지
listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats auth admin:password

# HTTP Frontend
frontend http_front
    bind *:80
    mode http

    # ACL (Access Control List)
    acl is_api path_beg /api
    acl is_admin path_beg /admin
    acl is_static path_end .jpg .png .css .js

    # 라우팅
    use_backend api_backend if is_api
    use_backend admin_backend if is_admin
    use_backend static_backend if is_static
    default_backend web_backend

# HTTPS Frontend (SSL Termination)
frontend https_front
    bind *:443 ssl crt /etc/haproxy/certs/example.com.pem
    mode http

    # HSTS
    http-response set-header Strict-Transport-Security "max-age=31536000"

    # HTTP/2
    bind *:443 ssl crt /etc/haproxy/certs/example.com.pem alpn h2,http/1.1

    default_backend web_backend

# Web Backend (Round Robin)
backend web_backend
    mode http
    balance roundrobin
    option httpchk GET /health

    server web1 192.168.1.10:8080 check
    server web2 192.168.1.11:8080 check
    server web3 192.168.1.12:8080 check backup

# API Backend (Least Connections)
backend api_backend
    mode http
    balance leastconn
    option httpchk GET /api/health

    server api1 192.168.1.20:3000 check maxconn 100
    server api2 192.168.1.21:3000 check maxconn 100

# Static Content Backend
backend static_backend
    mode http
    balance roundrobin

    server cdn1 192.168.1.30:80 check
    server cdn2 192.168.1.31:80 check
```

**고급 기능:**

```bash
# Stick Tables (세션 지속성)
backend web_backend
    stick-table type ip size 200k expire 30m
    stick on src

    server web1 192.168.1.10:8080 check
    server web2 192.168.1.11:8080 check

# Rate Limiting
frontend http_front
    # 클라이언트당 10 req/s 제한
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny if { sc_http_req_rate(0) gt 10 }

# Circuit Breaker
backend api_backend
    option httpchk GET /health

    # 3번 연속 실패 시 5초간 비활성화
    server api1 192.168.1.20:3000 check inter 2s fall 3 rise 2 on-error mark-down
    server api2 192.168.1.21:3000 check inter 2s fall 3 rise 2 on-error mark-down

# Content Switching (호스트 기반)
frontend http_front
    acl host_api hdr(host) -i api.example.com
    acl host_www hdr(host) -i www.example.com

    use_backend api_backend if host_api
    use_backend web_backend if host_www
```

**HAProxy 재시작:**

```bash
# 설정 검증
haproxy -c -f /etc/haproxy/haproxy.cfg

# 무중단 재시작 (Graceful Reload)
systemctl reload haproxy

# Stats 확인
curl http://localhost:8404/stats
```

### 2-3. Nginx 로드 밸런서 설정

**설치:**

```bash
# Ubuntu/Debian
apt-get install nginx

# 최신 버전 (공식 저장소)
curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
add-apt-repository "deb http://nginx.org/packages/ubuntu $(lsb_release -sc) nginx"
apt-get update
apt-get install nginx
```

**기본 설정 (/etc/nginx/nginx.conf):**

```nginx
user nginx;
worker_processes auto;
worker_rlimit_nofile 100000;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 10000;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 로그 포맷
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    # 성능 최적화
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
    reset_timedout_connection on;
    client_body_timeout 10;
    send_timeout 2;

    # Gzip 압축
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss;

    # Upstream (백엔드 서버)
    upstream web_backend {
        least_conn;  # 로드 밸런싱 알고리즘

        server 192.168.1.10:8080 weight=3 max_fails=3 fail_timeout=30s;
        server 192.168.1.11:8080 weight=2 max_fails=3 fail_timeout=30s;
        server 192.168.1.12:8080 backup;

        # Keepalive 연결
        keepalive 32;
    }

    upstream api_backend {
        # IP Hash (세션 지속성)
        ip_hash;

        server 192.168.1.20:3000;
        server 192.168.1.21:3000;
    }

    # 헬스 체크 (Nginx Plus 전용, OSS는 passive만)
    # upstream api_backend {
    #     zone api_backend 64k;
    #     server 192.168.1.20:3000;
    #     server 192.168.1.21:3000;
    # }
    #
    # match api_health {
    #     status 200;
    #     body ~ "OK";
    # }

    # HTTP Server (포트 80)
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name example.com www.example.com;

        # HTTP → HTTPS 리다이렉트
        return 301 https://$server_name$request_uri;
    }

    # HTTPS Server (포트 443)
    server {
        listen 443 ssl http2 default_server;
        listen [::]:443 ssl http2 default_server;
        server_name example.com www.example.com;

        # SSL 인증서
        ssl_certificate /etc/nginx/ssl/example.com.crt;
        ssl_certificate_key /etc/nginx/ssl/example.com.key;

        # SSL 설정
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # HSTS
        add_header Strict-Transport-Security "max-age=31536000" always;

        # 루트 위치
        location / {
            proxy_pass http://web_backend;
            proxy_http_version 1.1;

            # 헤더 전달
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Keepalive
            proxy_set_header Connection "";

            # 타임아웃
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # API 엔드포인트
        location /api/ {
            proxy_pass http://api_backend;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Connection "";
        }

        # 정적 파일 (Nginx가 직접 서빙)
        location /static/ {
            alias /var/www/static/;
            expires 30d;
            add_header Cache-Control "public, immutable";
        }

        # Rate Limiting
        location /login {
            limit_req zone=login_limit burst=5 nodelay;
            proxy_pass http://web_backend;
        }

        # Status 페이지
        location /nginx_status {
            stub_status on;
            access_log off;
            allow 127.0.0.1;
            deny all;
        }
    }

    # Rate Limit Zone
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=1r/s;
}
```

**HTTP/3 (QUIC) 설정 (Nginx 1.25+):**

```nginx
server {
    listen 443 ssl http2;
    listen 443 quic reuseport;  # HTTP/3

    http3 on;

    # Alt-Svc 헤더 (HTTP/3 알림)
    add_header Alt-Svc 'h3=":443"; ma=86400';

    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;

    # QUIC는 TLS 1.3 필수
    ssl_protocols TLSv1.3;
}
```

### 2-4. Traefik (Kubernetes Ingress)

**Traefik 설치 (Kubernetes Helm):**

```bash
# Traefik Helm Chart 추가
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Traefik 설치
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ports.web.redirectTo.port=websecure \
  --set ports.websecure.tls.enabled=true \
  --set ingressRoute.dashboard.enabled=true
```

**Ingress 예제 (traefik-ingress.yaml):**

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: web-app-ingress
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`example.com`) && PathPrefix(`/api`)
      kind: Rule
      services:
        - name: api-service
          port: 3000
      middlewares:
        - name: rate-limit
    - match: Host(`example.com`)
      kind: Rule
      services:
        - name: web-service
          port: 8080
  tls:
    certResolver: letsencrypt

---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
spec:
  rateLimit:
    average: 100
    burst: 50

---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: auth
spec:
  basicAuth:
    secret: auth-secret
```

---

## 🛠️ 실습 가이드

### 실습 1: OPNsense 방화벽 구축

**목표**: 기업 네트워크 방화벽 구성

```bash
# VM 생성 (이전 섹션 참고)
# 웹 GUI 접속 후 설정

네트워크 구성:
- WAN: DHCP (인터넷)
- LAN: 192.168.1.1/24
- DMZ: 192.168.2.1/24 (추가 인터페이스)

방화벽 규칙:
1. LAN → WAN: 모두 허용 (NAT)
2. LAN → DMZ: 특정 포트만 (80, 443, 22)
3. DMZ → LAN: 차단
4. WAN → DMZ: 포트 포워딩 (80, 443만)

IDS/IPS:
- Suricata 활성화
- ET Open 룰셋
- 모든 인터페이스 모니터링
```

### 실습 2: HAProxy 고가용성 로드 밸런서

**목표**: Active-Standby HA 구성

```bash
# 노드 1 (Primary)
apt-get install haproxy keepalived

# /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 101
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass secretpass
    }

    virtual_ipaddress {
        192.168.1.100/24
    }

    track_script {
        chk_haproxy
    }
}

vrrp_script chk_haproxy {
    script "killall -0 haproxy"
    interval 2
    weight 2
}

# 노드 2 (Backup)
# 동일한 설정, state=BACKUP, priority=100

# 테스트
# VIP로 접속하여 failover 확인
curl http://192.168.1.100

# Primary 중지 시 Backup으로 자동 전환
systemctl stop haproxy  # Node 1에서
```

### 실습 3: Nginx + Let's Encrypt 자동 SSL

**목표**: 자동 SSL 인증서 갱신

```bash
# Certbot 설치
apt-get install certbot python3-certbot-nginx

# SSL 인증서 발급 (자동 Nginx 설정)
certbot --nginx -d example.com -d www.example.com

# 자동 갱신 테스트
certbot renew --dry-run

# Cron으로 자동 갱신 (매일 2회 체크)
0 0,12 * * * certbot renew --quiet

# Nginx 설정 확인 (/etc/nginx/sites-enabled/default)
# Certbot이 자동으로 SSL 설정 추가함

# 재시작
systemctl reload nginx
```

---

## 📚 참고 자료

**Virtual Firewall:**

- [OPNsense vs pfSense Comparison 2025 (StationX)](https://www.stationx.net/opnsense-vs-pfsense/)
- [OPNsense Documentation](https://docs.opnsense.org/)
- [pfSense Documentation](https://docs.netgate.com/pfsense/)

**Load Balancers:**

- [HAProxy vs Nginx Performance (Last9)](https://last9.io/blog/haproxy-vs-nginx-performance/)
- [HAProxy vs Nginx vs Envoy Benchmark 2025 (Onidel)](https://onidel.com/haproxy-nginx-envoy-benchmark-vps/)
- [Battle of Proxies: Envoy vs Traefik vs HAProxy (AWS Plain English, Oct 2025)](https://aws.plainenglish.io/battle-of-the-proxies-envoy-vs-traefik-vs-haproxy-in-2025-8f0bed6c7a66)
- [HAProxy Documentation](http://www.haproxy.org/#docs)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Envoy Documentation](https://www.envoyproxy.io/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

---

## ✅ 학습 체크리스트

### Virtual Firewall

- [ ] pfSense vs OPNsense 차이점 이해
- [ ] OPNsense 설치 및 초기 설정 경험
- [ ] 방화벽 규칙 작성 및 NAT 설정 경험
- [ ] WireGuard VPN 설정 경험
- [ ] IDS/IPS (Suricata) 설정 경험
- [ ] HA (CARP) 구성 경험

### Load Balancer

- [ ] HAProxy, Nginx, Envoy, Traefik 차이점 이해
- [ ] 로드 밸런싱 알고리즘 선택 능력
- [ ] HAProxy 설정 및 운영 경험
- [ ] Nginx 리버스 프록시 및 LB 설정 경험
- [ ] SSL/TLS Termination 구현 경험
- [ ] HTTP/2, HTTP/3 설정 경험
- [ ] Rate Limiting 및 Circuit Breaker 구현 경험

### 종합 역량

- [ ] 고가용성 네트워크 어플라이언스 설계
- [ ] 성능 모니터링 및 최적화 경험
- [ ] 보안 Best Practices 적용
- [ ] 프로덕션 환경 트러블슈팅 경험

---

## 🎓 다음 단계

Ch5. 네트워크 어플라이언스를 완료했다면, 다음 학습 주제로 진행하세요:

**Ch6. Event-Driven Architecture**

- Event Sourcing
- CQRS (Command Query Responsibility Segregation)
- Message Brokers (RabbitMQ, Kafka)
- Event Streaming

**또는 심화 학습:**

- **WAF (Web Application Firewall)**: ModSecurity, NAXSI
- **DDoS Protection**: Cloudflare, Fastly
- **API Gateway**: Kong, Tyk, AWS API Gateway
- **CDN**: Varnish, Cloudflare, Fastly

**실무 프로젝트 아이디어:**

1. **Multi-Layer 보안 아키텍처**
   - Edge Firewall (OPNsense)
   - WAF (ModSecurity)
   - Application LB (HAProxy/Nginx)

2. **글로벌 로드 밸런싱**
   - GeoDNS
   - Multi-Region LB
   - Failover 자동화

3. **Zero Trust 네트워크**
   - Mutual TLS
   - Identity-based Access
   - Micro-segmentation

네트워크 어플라이언스는 인프라의 첫 번째 방어선이자 성능의 핵심입니다. 계속해서 학습하고 실습하면서 안전하고 고성능인 네트워크를 구축하는 전문가로 성장하세요!
