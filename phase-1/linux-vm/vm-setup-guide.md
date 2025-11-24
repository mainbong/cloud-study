# 리눅스 VM 구축 실습 가이드

## 사전 준비

### 1. UTM 설치 확인 및 설치

```bash
# UTM 설치 확인
which utm || brew list --cask utm

# UTM 설치 (Homebrew 필요)
brew install --cask utm

# 또는 UTM 공식 사이트에서 다운로드
# https://mac.getutm.app/
```

### 2. Ubuntu 이미지 다운로드

**중요: 아키텍처 선택**
- **ARM64 VM 사용 시**: ARM64 버전의 Ubuntu를 다운로드해야 합니다
- **x86_64 에뮬레이션 사용 시**: AMD64 버전의 Ubuntu를 다운로드할 수 있습니다

#### 옵션 1: ARM64 버전 (권장 - 네이티브 성능)
```bash
# 다운로드 디렉토리 생성
mkdir -p ~/Downloads/ubuntu-vm

# Ubuntu 24.04.3 LTS Server (ARM64) 다운로드
cd ~/Downloads/ubuntu-vm
curl -O https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04.3-live-server-arm64.iso
```

#### 옵션 2: AMD64 버전 (x86_64 에뮬레이션 필요)
```bash
# 다운로드 디렉토리 생성
mkdir -p ~/Downloads/ubuntu-vm

# Ubuntu 24.04.3 LTS Server (AMD64) 다운로드
cd ~/Downloads/ubuntu-vm
curl -O https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso
```

**참고**: AMD64 버전을 사용하려면 VM 생성 시 "Emulate" 모드를 선택해야 합니다.

## VM 생성 단계

### 1. UTM 실행 및 새 VM 생성

1. UTM 앱 실행
2. "Create a New Virtual Machine" 클릭
3. **아키텍처 선택** (중요!)
   - **ARM64 ISO 사용 시**: "Virtualize" 선택 (네이티브 성능, 빠름)
   - **AMD64 ISO 사용 시**: "Emulate" 선택 (x86_64 에뮬레이션, 느림)

### 2. 운영체제 선택

- "Linux" 선택
- "Use an existing boot ISO image" 선택
- 다운로드한 Ubuntu 24.04.3 ISO 파일 선택
- **중요**: ISO 파일의 아키텍처와 VM 아키텍처가 일치해야 합니다!

### 2-1. 드라이브 설정 (중요!)

**CD/DVD 드라이브 설정:**
- 드라이브 타입: **CD/DVD** 선택 (USB가 아님!)
- 인터페이스: IDE 또는 SATA
- ISO 이미지 파일 선택

**USB 드라이브로 설정하면 부팅이 안 될 수 있습니다!**

### 3. 하드웨어 설정

- **Memory**: 최소 2GB (권장: 4GB)
- **CPU Cores**: 최소 2코어 (권장: 4코어)
- **Storage**: 최소 20GB (권장: 40GB)

### 4. 네트워크 설정

#### 네트워크 모드 선택

**"Shared Network" (NAT 모드) - 기본값**

**작동 방식:**
- VM은 호스트의 가상 네트워크 인터페이스를 통해 연결됩니다
- UTM이 내부적으로 NAT(Network Address Translation)를 수행합니다
- VM은 사설 IP 주소를 받습니다 (예: 192.168.64.x)
- 호스트가 VM과 외부 네트워크 간의 게이트웨이 역할을 합니다

**네트워크 구조:**
```
인터넷
  ↓
호스트 Mac (공인 IP)
  ↓
UTM 가상 스위치 (192.168.64.1)
  ↓
VM (192.168.64.2, 192.168.64.3, ...)
```

**특징:**
- ✅ 보안: VM이 호스트 네트워크에 직접 노출되지 않음
- ✅ 간편: 추가 설정 불필요
- ✅ 여러 VM이 독립적으로 동작 가능
- ❌ 외부에서 VM으로 직접 접근 어려움 (포트 포워딩 필요)
- ❌ 호스트와 동일한 네트워크 세그먼트에 있지 않음

**사용 시나리오:**
- 일반적인 개발/학습 환경
- 인터넷 접속만 필요한 경우
- 보안이 중요한 환경

---

**"Bridged" (브리지 모드)**

**작동 방식:**
- VM이 호스트의 물리적 네트워크 어댑터에 직접 연결됩니다
- VM은 호스트와 동일한 네트워크 세그먼트에 있습니다
- VM이 물리적 네트워크에서 직접 IP 주소를 받습니다 (DHCP 또는 수동 설정)
- VM이 호스트와 같은 네트워크에 있는 것처럼 동작합니다

**네트워크 구조:**
```
인터넷
  ↓
라우터 (192.168.1.1)
  ↓
  ├─ 호스트 Mac (192.168.1.100)
  └─ VM (192.168.1.101) ← 같은 네트워크 세그먼트
```

**특징:**
- ✅ 외부에서 VM으로 직접 접근 가능
- ✅ 호스트와 동일한 네트워크 환경
- ✅ 네트워크 성능이 더 좋을 수 있음
- ❌ 호스트 네트워크에 직접 노출됨 (보안 고려 필요)
- ❌ 라우터의 DHCP 서버가 IP를 할당해야 함
- ❌ 일부 네트워크 환경에서는 작동하지 않을 수 있음

**사용 시나리오:**
- 서버로 사용할 VM
- 외부에서 접근이 필요한 경우
- 네트워크 테스트/개발 환경
- 호스트와 동일한 네트워크가 필요한 경우

---

---

**"Emulated VLAN" (에뮬레이트된 VLAN 모드)**

**작동 방식:**
- UTM이 가상 VLAN을 에뮬레이트합니다
- VM은 가상 네트워크 스위치를 통해 연결됩니다
- 포트 포워딩 기능을 사용할 수 있습니다
- 호스트의 특정 포트를 VM의 포트로 전달할 수 있습니다

**특징:**
- ✅ 포트 포워딩 지원 (UTM UI에서 설정 가능)
- ✅ 호스트의 포트를 VM 포트로 매핑 가능
- ✅ 여러 VM 간 네트워크 격리 가능
- ✅ 네트워크 설정이 유연함

**사용 시나리오:**
- 포트 포워딩이 필요한 경우
- 호스트의 특정 포트를 VM으로 전달하고 싶은 경우
- 네트워크 격리가 필요한 경우

---

**비교표:**

| 항목 | Shared Network (NAT) | Bridged | Emulated VLAN |
|------|---------------------|---------|---------------|
| IP 주소 | 사설 IP (192.168.64.x) | 물리 네트워크 IP | 가상 네트워크 IP |
| 네트워크 세그먼트 | 호스트와 분리 | 호스트와 동일 | 가상 VLAN |
| 포트 포워딩 | UI에서 불가능 | 불필요 | UI에서 가능 |
| 외부 접근 | 직접 접근 어려움 | 직접 접근 가능 | 포트 포워딩으로 가능 |
| 보안 | 높음 (격리됨) | 낮음 (노출됨) | 중간 (가상 격리) |
| 설정 | 간단 | 복잡할 수 있음 | 중간 |
| 성능 | 보통 | 좋음 | 보통 |

**SSH 접속 관점:**
- **Shared Network**: VM IP로 직접 접속 (포트 포워딩 UI 없음)
- **Bridged**: 네트워크의 다른 기기에서도 접근 가능
- **Emulated VLAN**: 포트 포워딩으로 호스트 포트를 VM 포트로 전달

**권장:**
- 학습/실습 목적 (포트 포워딩 불필요): **Shared Network** (기본값)
- 포트 포워딩 필요: **Emulated VLAN**
- 서버 운영/외부 접근 필요: **Bridged**

#### 포트 포워딩 설정 (Emulated VLAN 모드)

**중요:** 포트 포워딩 기능을 사용하려면 네트워크 모드를 **"Emulated VLAN"**으로 설정해야 합니다.

**설정 방법:**

1. **VM 종료**
   - VM이 실행 중이면 완전히 종료합니다

2. **VM 설정 열기**
   - UTM에서 해당 VM 선택
   - 설정 버튼 클릭

3. **Network 탭으로 이동**
   - 왼쪽 메뉴에서 "Network" 선택

4. **네트워크 모드 변경**
   - 네트워크 모드를 **"Emulated VLAN"**으로 변경
   - 이제 "Port Forwarding" 섹션이 나타납니다

5. **포트 포워딩 추가**
   - "Port Forwarding" 섹션에서 "+" 버튼 또는 "Add" 버튼 클릭

6. **포트 포워딩 규칙 입력**
   - **Guest Port**: `22` (VM의 SSH 포트)
   - **Host Port**: `2222` (호스트에서 사용할 포트)
   - **Protocol**: `TCP` 선택
   - **Name** (선택사항): 규칙 이름 (예: "SSH")

7. **저장 및 VM 재시작**
   - 설정 저장
   - VM 재시작

**포트 포워딩 설정 후 SSH 접속:**

```bash
# 호스트에서 실행
ssh -p 2222 <username>@localhost
# 또는
ssh -p 2222 <username>@127.0.0.1

# 예시
ssh -p 2222 cloud-user@localhost
```

**포트 포워딩 규칙 예시:**

| 용도 | Guest Port | Host Port | Protocol |
|------|-----------|-----------|----------|
| SSH | 22 | 2222 | TCP |
| HTTP | 80 | 8080 | TCP |
| HTTPS | 443 | 8443 | TCP |
| 웹 서버 | 3000 | 3000 | TCP |

**포트 포워딩 규칙 예시:**

| 용도 | Guest Port | Host Port | Protocol |
|------|-----------|-----------|----------|
| SSH | 22 | 2222 | TCP |
| HTTP | 80 | 8080 | TCP |
| HTTPS | 443 | 8443 | TCP |
| 웹 서버 | 3000 | 3000 | TCP |

**참고:**
- 포트 포워딩은 Emulated VLAN 모드에서만 사용 가능합니다
- 호스트의 포트가 이미 사용 중이면 다른 포트를 선택해야 합니다
- 포트 사용 여부 확인: `lsof -i :2222` (호스트에서 실행)

#### Shared Network 모드에서 SSH 접속 방법

Shared Network 모드에서는 포트 포워딩 UI가 제공되지 않지만, **호스트에서 VM의 IP 주소로 직접 접속**할 수 있습니다.

1. **VM 내부에서 IP 주소 확인**
   ```bash
   # VM 내부에서 실행
   hostname -I
   # 또는
   ip addr show | grep "inet "
   ```
   - 일반적으로 `192.168.64.x` 대역의 IP를 받습니다
   - 예: `192.168.64.2`

2. **호스트에서 VM IP로 SSH 접속**
   ```bash
   # 호스트에서 실행
   ssh <username>@<VM_IP_ADDRESS>
   # 예시
   ssh cloud-user@192.168.64.2
   ```

**참고:** 포트 포워딩이 필요하다면 네트워크 모드를 **Emulated VLAN**으로 변경하세요.

**참고:**
- 포트 포워딩은 Shared Network 모드에서만 필요합니다
- Bridged 모드에서는 VM이 직접 IP를 받으므로 포트 포워딩이 필요 없습니다
- 호스트의 포트가 이미 사용 중이면 다른 포트를 선택해야 합니다

**호스트 포트 사용 여부 확인:**

```bash
# 호스트에서 실행
lsof -i :2222
# 또는
netstat -an | grep 2222
```

### 5. VM 저장 및 시작

- VM 이름 설정 (예: "Ubuntu-24.04-Server")
- "Save" 클릭
- VM 시작

## Ubuntu 설치 과정

### 1. 설치 시작

1. VM이 시작되면 Ubuntu 설치 화면이 나타남
2. **부팅 옵션 선택** (중요!)

#### 부팅 옵션 설명

**"Try or Install Ubuntu Server"** (기본 옵션)
- 표준 Ubuntu Server 설치
- LTS 버전의 기본 커널 사용
- 안정적이고 검증된 커널
- 일반적인 서버 환경에 적합
- **권장**: 대부분의 경우 이 옵션 선택

**"Ubuntu Server with the HWE kernel"** (Hardware Enablement)
- HWE (Hardware Enablement) 커널 사용
- 더 최신 하드웨어 지원
- 최신 GPU, 네트워크 카드 등 최신 하드웨어 드라이버 포함
- LTS 버전이지만 더 최신 커널 버전 제공
- **사용 시기**: 
  - 최신 하드웨어를 사용하는 경우
  - 최신 드라이버가 필요한 경우
  - 가상화 환경에서는 일반적으로 필요 없음

**권장**: 일반적인 학습/실습 목적이라면 **"Try or Install Ubuntu Server"** 선택

3. 언어 선택: English (또는 원하는 언어)
4. 키보드 레이아웃 선택

#### "Display output is not active" 화면이 나타나는 경우

이 메시지는 설치 프로그램이 텍스트 모드로 전환되었거나 디스플레이 출력이 일시적으로 비활성화된 상태입니다.

**해결 방법:**

1. **키보드 입력 시도**
   - `Enter` 키를 여러 번 눌러보기
   - `Tab` 키로 메뉴 탐색 시도
   - `Ctrl+Alt+F1` ~ `F7` 키 조합으로 터미널 전환 시도

2. **잠시 대기**
   - 설치가 백그라운드에서 진행 중일 수 있음
   - 1-2분 정도 대기 후 다시 시도

3. **VM 재시작**
   - VM을 종료하고 다시 시작
   - 부팅 옵션에서 다시 선택

4. **텍스트 모드 설치 사용**
   - UTM 설정에서 그래픽 출력 대신 텍스트 모드 사용
   - 또는 시리얼 콘솔 활성화

5. **다른 설치 옵션 시도**
   - "Ubuntu Server with the HWE kernel" 옵션 시도
   - 또는 다른 Ubuntu 버전 시도

**일반적으로**: `Enter` 키를 누르거나 잠시 기다리면 설치가 계속 진행됩니다.

### 2. 네트워크 설정

- 호스트 이름 설정 (예: ubuntu-server)
- 네트워크 설정 확인

### 3. 사용자 계정 생성

- 사용자 이름: `cloud-user` (또는 원하는 이름)
- 비밀번호 설정
- SSH 설치 선택: ✅ Install OpenSSH server

### 4. 디스크 파티션

- "Use an entire disk" 선택 (초보자용)
- 또는 "Custom storage layout" 선택 (고급)

### 5. 설치 완료

- 설치 진행 대기 (약 10-15분)
- 설치 완료 후 재부팅

## 초기 설정

### 1. SSH 접속 설정

VM이 시작되면 IP 주소를 확인합니다:

```bash
# VM 내부에서 실행
ip addr show
# 또는
hostname -I
```

### 1-1. OpenSSH Server 상태 확인 (VM 내부에서 실행)

SSH 접속이 안 될 때 다음 명령어로 확인합니다:

```bash
# 1. SSH 서비스 상태 확인
sudo systemctl status ssh
# 또는 (일부 시스템에서는 sshd)
sudo systemctl status sshd

# 2. SSH 서비스가 실행 중인지 확인
sudo systemctl is-active ssh

# 3. SSH 서비스가 부팅 시 자동 시작되도록 설정되어 있는지 확인
sudo systemctl is-enabled ssh

# 4. SSH 포트(22)가 열려있는지 확인
sudo netstat -tlnp | grep :22
# 또는
sudo ss -tlnp | grep :22

# 5. SSH 프로세스가 실행 중인지 확인
ps aux | grep sshd

# 6. 방화벽 상태 확인 (UFW 사용 시)
sudo ufw status
```

**SSH 서비스가 실행되지 않은 경우:**

```bash
# SSH 서비스 시작
sudo systemctl start ssh

# 부팅 시 자동 시작 설정
sudo systemctl enable ssh

# SSH 서비스 재시작
sudo systemctl restart ssh
```

**방화벽 설정 (필요한 경우):**

```bash
# UFW 방화벽이 활성화되어 있다면 SSH 포트 허용
sudo ufw allow ssh
# 또는
sudo ufw allow 22/tcp

# 방화벽 상태 확인
sudo ufw status
```

### 2. 호스트에서 SSH 접속

```bash
# VM의 IP 주소로 접속 (예: 192.168.64.2)
ssh cloud-user@<VM_IP_ADDRESS>
```

### 3. 기본 패키지 업데이트

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y vim git curl wget
```

## 실습 체크리스트

- [ ] UTM 설치 완료
- [ ] Ubuntu 24.04.3 LTS Server ISO 다운로드
- [ ] VM 생성 완료
- [ ] Ubuntu 설치 완료
- [ ] 사용자 계정 생성 완료
- [ ] SSH 서버 설치 및 접속 확인
- [ ] 기본 패키지 업데이트 완료

## 문제 해결

### UEFI Interface Shell로만 부팅되는 경우

**원인**: 아키텍처 불일치 또는 드라이브 설정 문제

**해결 방법:**

1. **아키텍처 확인**
   - ARM64 VM을 사용 중이라면 ARM64 버전의 Ubuntu ISO를 사용해야 합니다
   - AMD64 ISO를 사용하려면 VM을 "Emulate" 모드로 생성해야 합니다

2. **드라이브 설정 확인**
   - 드라이브 타입을 **CD/DVD**로 설정했는지 확인
   - 인터페이스를 **USB가 아닌 IDE 또는 SATA**로 설정
   - USB 드라이브로 설정하면 부팅이 실패할 수 있습니다

3. **VM 재생성 (권장)**
   ```
   방법 1: ARM64 네이티브 (권장)
   - VM 아키텍처: Virtualize (ARM64)
   - Ubuntu ISO: ubuntu-24.04.3-live-server-arm64.iso
   - 드라이브: CD/DVD (IDE 또는 SATA)
   
   방법 2: x86_64 에뮬레이션
   - VM 아키텍처: Emulate (x86_64)
   - Ubuntu ISO: ubuntu-24.04.3-live-server-amd64.iso
   - 드라이브: CD/DVD (IDE 또는 SATA)
   ```

4. **부팅 순서 확인**
   - VM 설정에서 부팅 순서 확인
   - CD/DVD 드라이브가 첫 번째 부팅 장치인지 확인

### VM이 시작되지 않는 경우
- ISO 파일이 올바른지 확인
- 메모리 할당이 충분한지 확인 (최소 2GB)
- UTM 권한 설정 확인 (시스템 설정 > 개인정보 보호 및 보안)
- 아키텍처와 ISO 버전이 일치하는지 확인

### SSH 접속이 안 되는 경우

**VM 내부에서 확인할 사항:**

1. **SSH 서비스 상태 확인**
   ```bash
   sudo systemctl status ssh
   ```
   - Active: active (running) 상태여야 함
   - 실행되지 않았다면: `sudo systemctl start ssh`

2. **SSH 포트 확인**
   ```bash
   sudo ss -tlnp | grep :22
   ```
   - 포트 22가 LISTEN 상태여야 함

3. **방화벽 확인**
   ```bash
   sudo ufw status
   ```
   - SSH 포트가 허용되어 있는지 확인
   - 필요시: `sudo ufw allow ssh`

4. **IP 주소 확인**
   ```bash
   hostname -I
   ip addr show
   ```

**호스트에서 확인할 사항:**

1. **네트워크 연결 확인**
   ```bash
   # 호스트에서 실행
   ping <VM_IP_ADDRESS>
   ```

2. **SSH 포트 확인**
   ```bash
   # 호스트에서 실행
   telnet <VM_IP_ADDRESS> 22
   # 또는
   nc -zv <VM_IP_ADDRESS> 22
   ```

3. **SSH 접속 시도**
   ```bash
   ssh -v <username>@<VM_IP_ADDRESS>
   ```
   - `-v` 옵션으로 상세 로그 확인

**SSH 연결이 무한 대기 중인 경우 (서비스는 active):**

이 문제는 네트워크 레벨의 문제입니다. 다음을 확인하세요:

1. **호스트에서 VM으로 ping 테스트**
   ```bash
   # 호스트에서 실행
   ping <VM_IP_ADDRESS>
   ```
   - ping이 안 되면 네트워크 연결 자체가 안 된 것
   - UTM 네트워크 설정 확인 필요

2. **호스트에서 SSH 포트 확인**
   ```bash
   # 호스트에서 실행
   nc -zv <VM_IP_ADDRESS> 22
   # 또는
   telnet <VM_IP_ADDRESS> 22
   ```
   - 연결이 안 되면 포트가 차단되었거나 네트워크 문제

3. **UTM 네트워크 설정 확인**
   - VM 설정 → Network
   - "Shared Network" 모드인지 확인
   - "Bridged" 모드로 변경해보기
   - 네트워크 어댑터가 활성화되어 있는지 확인

4. **VM 내부에서 네트워크 확인**
   ```bash
   # VM 내부에서 실행
   # 게이트웨이 확인
   ip route show
   
   # DNS 확인
   cat /etc/resolv.conf
   
   # 외부 연결 테스트
   ping 8.8.8.8
   ```

5. **SSH가 특정 인터페이스만 리스닝하는지 확인**
   ```bash
   # VM 내부에서 실행
   sudo ss -tlnp | grep :22
   ```
   - `0.0.0.0:22` 또는 `:::22`로 표시되어야 함
   - 특정 IP만 리스닝하면 문제일 수 있음

6. **SSH 설정 파일 확인**
   ```bash
   # VM 내부에서 실행
   sudo grep -E "^ListenAddress|^Port" /etc/ssh/sshd_config
   ```
   - ListenAddress가 특정 IP로 제한되어 있는지 확인

**해결 방법:**

1. **UTM 네트워크 모드 변경**
   - "Shared Network" → "Bridged" 또는 그 반대
   - VM 재시작

2. **SSH가 모든 인터페이스에서 리스닝하도록 설정**
   ```bash
   # VM 내부에서 실행
   sudo sed -i 's/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

3. **호스트 방화벽 확인**
   - Mac의 방화벽이 VM과의 연결을 차단하는지 확인
   - 시스템 설정 → 네트워크 → 방화벽

**Shared Network 모드에서 ping이 안 가는 경우:**

이 문제는 UTM의 가상 네트워크 인터페이스 문제일 가능성이 높습니다.

**1단계: VM 내부에서 네트워크 확인**

```bash
# VM 내부에서 실행
# 네트워크 인터페이스 확인
ip addr show

# 네트워크 인터페이스가 UP 상태인지 확인
ip link show

# 라우팅 테이블 확인
ip route show

# DNS 확인
cat /etc/resolv.conf

# 외부 연결 테스트 (8.8.8.8은 Google DNS)
ping -c 3 8.8.8.8
```

**2단계: 호스트에서 UTM 가상 네트워크 확인**

```bash
# 호스트(Mac)에서 실행
# UTM이 생성한 가상 네트워크 인터페이스 확인
ifconfig | grep -A 5 utun

# 또는
networksetup -listallnetworkservices
```

**3단계: 해결 방법**

**방법 1: VM 네트워크 어댑터 재설정**
1. VM 종료
2. UTM에서 VM 설정 열기
3. Network 탭에서:
   - 네트워크 어댑터 제거
   - 새 네트워크 어댑터 추가 (Shared Network)
4. VM 재시작

**방법 2: VM 내부에서 네트워크 재시작**
```bash
# VM 내부에서 실행
sudo systemctl restart networking
# 또는
sudo systemctl restart NetworkManager
```

**방법 3: UTM 재시작**
- UTM 앱 완전 종료 후 재시작
- VM 재시작

**방법 4: 호스트 네트워크 서비스 재시작**
```bash
# 호스트에서 실행 (관리자 권한 필요)
sudo ifconfig utun0 down
sudo ifconfig utun0 up
```

**방법 5: VM 네트워크 설정 수동 확인**
```bash
# VM 내부에서 실행
# 네트워크 인터페이스 이름 확인 (보통 eth0, enp0s1 등)
ip addr show

# 네트워크 인터페이스가 DOWN 상태라면 UP으로 변경
sudo ip link set <interface_name> up

# DHCP로 IP 받기
sudo dhclient <interface_name>
# 또는
sudo dhcpcd <interface_name>
```

**방법 6: UTM 권한 확인**
- 시스템 설정 → 개인정보 보호 및 보안 → 네트워크
- UTM이 네트워크 접근 권한을 가지고 있는지 확인

**방법 7: 호스트 방화벽 확인**
- 시스템 설정 → 네트워크 → 방화벽
- UTM 또는 가상 네트워크 관련 규칙 확인

**Shared Network 모드에서 SSH 접속 성공하는 방법:**

1. **VM의 IP 주소 확인 (VM 내부)**
   ```bash
   hostname -I
   # 또는
   ip addr show | grep "inet "
   ```
   - 일반적으로 192.168.64.x 대역의 IP를 받습니다

2. **호스트에서 VM IP로 접속**
   ```bash
   # 호스트에서 실행
   ssh <username>@<VM_IP>
   # 예: ssh cloud-user@192.168.64.2
   ```

3. **포트 포워딩 사용 (필요한 경우)**
   - UTM 설정에서 포트 포워딩 설정
   - 호스트의 특정 포트를 VM의 22번 포트로 전달

**일반적인 문제:**
- SSH 서비스가 실행되지 않음 → `sudo systemctl start ssh`
- 방화벽이 SSH 포트를 차단 → `sudo ufw allow ssh`
- 네트워크 설정 문제 → UTM의 네트워크 모드 확인 (Shared Network)
- **무한 대기**: 네트워크 연결 문제 → ping 테스트 및 UTM 네트워크 설정 확인
- **ping이 안 감**: UTM 가상 네트워크 인터페이스 문제 → 위의 해결 방법 시도

### 네트워크 연결 문제
- "Shared Network" 모드 확인
- 호스트의 방화벽 설정 확인
- VM과 호스트가 같은 네트워크에 있는지 확인

### "Display output is not active" 문제

**증상**: 부팅 옵션 선택 후 검은 화면에 "Display output is not active" 메시지 표시

**원인**: 
- 설치 프로그램이 텍스트 모드로 전환됨
- 디스플레이 출력이 일시적으로 비활성화됨
- 그래픽 드라이버 문제

**해결 방법**:
1. `Enter` 키를 여러 번 눌러보기
2. 1-2분 대기 (백그라운드 설치 진행 중일 수 있음)
3. `Ctrl+Alt+F1` ~ `F7` 키로 터미널 전환 시도
4. VM 재시작 후 다시 시도
5. UTM 설정에서 시리얼 콘솔 활성화

### 부팅 문제 요약

| 문제 | 원인 | 해결 방법 |
|------|------|----------|
| UEFI Shell로만 부팅 | 아키텍처 불일치 | ARM64 VM → ARM64 ISO 사용 |
| UEFI Shell로만 부팅 | 드라이브 설정 오류 | USB → CD/DVD로 변경 |
| Display output not active | 텍스트 모드 전환 | Enter 키 또는 대기 |
| 부팅 실패 | ISO 파일 손상 | ISO 파일 재다운로드 |
| 부팅 실패 | 메모리 부족 | 메모리 2GB 이상 할당 |

### 성능 문제
- CPU 코어 수 증가
- 메모리 할당 증가
- 디스크 타입: QCOW2 (권장)

## 다음 단계

VM 구축이 완료되면:
1. 리눅스 시스템 관리 실습 진행
2. 네트워킹 실습 진행
3. 실습 결과를 `notes.md`에 기록

