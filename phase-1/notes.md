# Phase 1: 기초 준비 학습 노트

## 학습 기간
- 시작일: 2025-01-27
- 목표 완료일: 2025-02-09
- 실제 완료일: 

## 학습 목표
- 리눅스 시스템 관리 기초 이해
- 네트워킹 기초 개념 이해
- 실습 환경 구축

## 학습 내용

### Week 1-2: 리눅스 & 네트워킹 기초

#### 리눅스 시스템 관리

**파일 시스템, 권한 관리**

- 학습 내용:
  - **리눅스 파일 시스템 구조**
    - `/` (루트): 최상위 디렉토리
    - `/bin`, `/sbin`: 실행 파일 (시스템 필수 명령어)
    - `/usr`: 사용자 프로그램 및 데이터
    - `/etc`: 시스템 설정 파일
    - `/var`: 변하는 데이터 (로그, 캐시 등)
    - `/home`: 사용자 홈 디렉토리
    - `/tmp`: 임시 파일
    - `/dev`: 장치 파일
    - `/proc`, `/sys`: 가상 파일 시스템 (커널 정보)
  
  - **파일 시스템 타입**
    - ext4: 리눅스 표준 파일 시스템
    - XFS: 대용량 파일에 적합
    - Btrfs: 스냅샷, 압축 기능 제공
  
  - **파일 권한 (Permission)**
    - 3가지 권한: 읽기(r), 쓰기(w), 실행(x)
    - 3가지 대상: 소유자(owner), 그룹(group), 기타(others)
    - 숫자 표현: r=4, w=2, x=1 (예: 755 = rwxr-xr-x)
    - 문자 표현: `chmod u+x file` (소유자에게 실행 권한 추가)
  
  - **파일 소유권**
    - `chown`: 파일 소유자 변경
    - `chgrp`: 파일 그룹 변경
    - `chown user:group file`: 소유자와 그룹 동시 변경
  
  - **특수 권한**
    - SUID (Set User ID): 실행 시 소유자 권한으로 실행
    - SGID (Set Group ID): 실행 시 그룹 권한으로 실행
    - Sticky Bit: 디렉토리에 설정 시 소유자만 삭제 가능 (예: /tmp)
  
  - **디스크 관리**
    - `df -h`: 파일 시스템 사용량 확인
    - `du -sh *`: 디렉토리별 사용량 확인
    - `fdisk`, `parted`: 파티션 관리
    - `mount`, `umount`: 파일 시스템 마운트/언마운트

- 실습 결과:
  - **실습 스크립트**: `phase-1/linux-vm/practice-filesystem.sh` 실행 완료
  - **주요 실습 내용**:
    - 파일 생성 및 권한 확인 (`ls -la`)
    - `chmod` 명령어로 권한 변경 (755, 644)
    - 디렉토리 사용량 확인 (`du -sh`)
    - 파일 시스템 사용량 확인 (`df -h`)
    - 실행 권한 추가 및 스크립트 실행 테스트
    - SUID 권한 확인 (예: `/usr/bin/passwd`)
  - **학습한 명령어**:
    - `chmod 755 file`, `chmod 644 file`: 권한 변경
    - `chmod +x script.sh`: 실행 권한 추가
    - `df -h`: 파일 시스템 사용량
    - `du -sh *`: 디렉토리별 사용량
    - `ls -l`: 상세 파일 정보 (권한 포함)

- 참고 자료:
  - Linux Filesystem Hierarchy Standard (FHS)
  - `man chmod`, `man chown`, `man mount`

**프로세스 관리, 서비스 관리**

- 학습 내용:
  - **프로세스 개념**
    - 프로세스: 실행 중인 프로그램의 인스턴스
    - PID (Process ID): 각 프로세스의 고유 식별자
    - PPID (Parent Process ID): 부모 프로세스 ID
    - 프로세스 상태: Running, Sleeping, Stopped, Zombie
  
  - **프로세스 확인 명령어**
    - `ps`: 현재 실행 중인 프로세스 목록
      - `ps aux`: 모든 프로세스 상세 정보
      - `ps -ef`: 프로세스 트리 형태
    - `top`: 실시간 프로세스 모니터링
    - `htop`: 향상된 top (더 나은 UI)
    - `pgrep`: 프로세스 이름으로 검색
    - `pstree`: 프로세스 트리 구조 표시
  
  - **프로세스 제어**
    - `kill`: 프로세스 종료
      - `kill -9 PID`: 강제 종료 (SIGKILL)
      - `kill -15 PID`: 정상 종료 (SIGTERM, 기본값)
      - `kill -HUP PID`: 재시작 신호
    - `killall`: 프로세스 이름으로 종료
    - `pkill`: 패턴으로 프로세스 종료
    - `nohup`: 터미널 종료 후에도 프로세스 유지
    - `&`: 백그라운드 실행
    - `fg`, `bg`: 포그라운드/백그라운드 전환
  
  - **프로세스 우선순위**
    - Nice 값: -20 (최고 우선순위) ~ 19 (최저 우선순위)
    - `nice`: 명령어 실행 시 우선순위 설정
    - `renice`: 실행 중인 프로세스 우선순위 변경
  
  - **시스템 서비스 관리 (systemd)**
    - systemd: 최신 리눅스 배포판의 시스템 및 서비스 관리자
    - Unit 파일: 서비스 설정 파일 (`/etc/systemd/system/`)
    - 주요 명령어:
      - `systemctl status service`: 서비스 상태 확인
      - `systemctl start service`: 서비스 시작
      - `systemctl stop service`: 서비스 중지
      - `systemctl restart service`: 서비스 재시작
      - `systemctl reload service`: 설정만 다시 로드
      - `systemctl enable service`: 부팅 시 자동 시작
      - `systemctl disable service`: 자동 시작 비활성화
      - `systemctl list-units`: 모든 유닛 목록
      - `systemctl list-unit-files`: 유닛 파일 목록
  
  - **서비스 로그 확인**
    - `journalctl`: systemd 로그 확인
      - `journalctl -u service`: 특정 서비스 로그
      - `journalctl -f`: 실시간 로그 확인
      - `journalctl --since today`: 오늘 로그만
    - `/var/log/`: 전통적인 로그 파일 위치

- 실습 결과:
  - **실습 스크립트**: `phase-1/linux-vm/practice-process.sh` 실행 완료
  - **주요 실습 내용**:
    - `ps aux`로 현재 실행 중인 프로세스 확인
    - `ps -ef`로 프로세스 트리 확인
    - `grep`을 사용한 특정 프로세스 검색
    - CPU 사용률 기준 프로세스 정렬 및 확인
    - 백그라운드 프로세스 실행 (`&`) 및 PID 확인
    - `kill` 명령어로 프로세스 종료 테스트
    - Mac 환경에서 `launchctl`로 서비스 확인
    - 프로세스 Nice 값 확인
  - **학습한 명령어**:
    - `ps aux`: 모든 프로세스 상세 정보
    - `ps -ef`: 프로세스 트리 형태
    - `ps -p PID`: 특정 PID 프로세스 확인
    - `kill PID`: 프로세스 종료
    - `launchctl list`: Mac 서비스 목록 (systemd 대체)
    - `ps -o pid,ni,comm`: Nice 값 포함 프로세스 정보

- 참고 자료:
  - `man ps`, `man kill`, `man systemctl`
  - systemd 공식 문서

**쉘 스크립팅 기초**

- 학습 내용:
  - **쉘 스크립트 기본 구조**
    - Shebang: `#!/bin/bash` (스크립트 실행 인터프리터 지정)
    - 실행 권한 필요: `chmod +x script.sh`
    - 실행 방법: `./script.sh` 또는 `bash script.sh`
  
  - **변수**
    - 변수 선언: `VARIABLE="value"` (공백 없음)
    - 변수 사용: `$VARIABLE` 또는 `${VARIABLE}`
    - 환경 변수: `export VARIABLE="value"`
    - 특수 변수:
      - `$0`: 스크립트 이름
      - `$1, $2, ...`: 위치 매개변수
      - `$#`: 매개변수 개수
      - `$@`: 모든 매개변수
      - `$?`: 마지막 명령어 종료 코드
      - `$$`: 현재 프로세스 PID
  
  - **문자열 처리**
    - 문자열 길이: `${#VARIABLE}`
    - 부분 문자열: `${VARIABLE:start:length}`
    - 문자열 치환: `${VARIABLE/old/new}`
    - 기본값 설정: `${VARIABLE:-default}`
  
  - **조건문**
    ```bash
    if [ condition ]; then
        commands
    elif [ condition ]; then
        commands
    else
        commands
    fi
    ```
    - 조건 연산자:
      - 파일: `-f` (파일), `-d` (디렉토리), `-e` (존재)
      - 문자열: `=`, `!=`, `-z` (빈 문자열)
      - 숫자: `-eq`, `-ne`, `-lt`, `-gt`, `-le`, `-ge`
      - 논리: `-a` (AND), `-o` (OR), `!` (NOT)
  
  - **반복문**
    ```bash
    # for 루프
    for item in list; do
        commands
    done
    
    # while 루프
    while [ condition ]; do
        commands
    done
    
    # until 루프
    until [ condition ]; do
        commands
    done
    ```
  
  - **함수**
    ```bash
    function_name() {
        local variable="value"  # 지역 변수
        commands
        return 0
    }
    ```
  
  - **입출력 리다이렉션**
    - `>`: 표준 출력 덮어쓰기
    - `>>`: 표준 출력 추가
    - `<`: 표준 입력
    - `2>`: 표준 에러 출력
    - `&>`: 표준 출력 + 에러 출력
    - `|`: 파이프 (한 명령어의 출력을 다른 명령어의 입력으로)
  
  - **명령어 치환**
    - `` `command` ``: 백틱 사용 (구식)
    - `$(command)`: 권장 방식
  
  - **에러 처리**
    - `set -e`: 에러 발생 시 스크립트 종료
    - `set -u`: 정의되지 않은 변수 사용 시 에러
    - `set -x`: 명령어 실행 전 출력 (디버깅)
    - `trap`: 시그널 처리

- 실습 결과:
  - **실습 스크립트**: `phase-1/linux-vm/practice-scripting.sh` 실행 완료
  - **주요 실습 내용**:
    - 변수 선언 및 사용 (`$VARIABLE`, `${VARIABLE}`)
    - 특수 변수 활용 (`$0`, `$1`, `$#`, `$@`, `$$`)
    - 문자열 길이 확인 (`${#VARIABLE}`)
    - 조건문을 사용한 파일 존재 여부 확인
    - `for` 루프와 `while` 루프 실습
    - 함수 정의 및 호출
    - 명령어 치환 (`$(command)`)
    - 입출력 리다이렉션 (`>`, `>>`)
    - 에러 처리 모드 설정 (`set -e`)
  - **작성한 스크립트**:
    - `practice-filesystem.sh`: 파일 시스템 및 권한 관리
    - `practice-process.sh`: 프로세스 관리
    - `practice-scripting.sh`: 쉘 스크립팅 기초
  - **핵심 학습 사항**:
    - `>` vs `>>` 차이: 덮어쓰기 vs 추가
    - 파이프(`|`)는 명령어 간 데이터 전달, 리다이렉션(`>`, `>>`)은 파일로 저장

- 참고 자료:
  - Bash 공식 문서
  - `man bash`
  - Advanced Bash-Scripting Guide

**실습: 로컬 Mac에서 리눅스 VM 구축 (UTM/QEMU)**
- 실습 환경:
- 구축 과정:
- 문제 해결:
- 결과:

#### 네트워킹 기초

**OSI 7계층, TCP/IP**

- 학습 내용:
  - **OSI 7계층 모델**
    - 7계층 (Application): 사용자 인터페이스, HTTP, FTP, SMTP
    - 6계층 (Presentation): 데이터 변환, 암호화, 압축
    - 5계층 (Session): 세션 관리, 연결 설정/해제
    - 4계층 (Transport): 데이터 전송, TCP, UDP
    - 3계층 (Network): 라우팅, IP, 라우터
    - 2계층 (Data Link): 프레임 전송, 스위치, MAC 주소
    - 1계층 (Physical): 물리적 전송, 케이블, 허브
  
  - **TCP/IP 모델 (4계층)**
    - Application Layer: OSI 7, 6, 5계층 통합
      - HTTP, HTTPS, FTP, SSH, DNS, SMTP
    - Transport Layer: OSI 4계층
      - TCP (Transmission Control Protocol)
        - 연결 지향형, 신뢰성 보장
        - 3-way handshake (SYN, SYN-ACK, ACK)
        - 흐름 제어, 혼잡 제어
      - UDP (User Datagram Protocol)
        - 비연결형, 빠른 전송
        - 신뢰성 낮음, 오버헤드 적음
    - Internet Layer: OSI 3계층
      - IP (Internet Protocol)
      - ICMP, ARP
      - 라우팅
    - Network Interface Layer: OSI 2, 1계층
      - 이더넷, Wi-Fi
      - 물리적 전송
  
  - **IP 주소**
    - IPv4: 32비트, 4개의 옥텟 (예: 192.168.1.1)
    - IPv6: 128비트, 16진수 표현 (예: 2001:0db8::1)
    - 공인 IP vs 사설 IP
    - NAT (Network Address Translation)

- 핵심 개념:
  - **TCP vs UDP**
    - TCP: 신뢰성 중요 (웹, 이메일, 파일 전송)
    - UDP: 속도 중요 (스트리밍, 게임, DNS)
  
  - **포트 번호**
    - Well-known ports: 0-1023 (시스템 예약)
      - 22: SSH, 80: HTTP, 443: HTTPS, 53: DNS
    - Registered ports: 1024-49151
    - Dynamic/Private ports: 49152-65535
  
  - **3-way Handshake (TCP 연결)**
    1. Client → Server: SYN
    2. Server → Client: SYN-ACK
    3. Client → Server: ACK

- 참고 자료:
  - RFC 793 (TCP), RFC 791 (IP)
  - `man tcp`, `man ip`
  - 네트워크 기초 서적

**서브넷팅, 라우팅**

- 학습 내용:
  - **서브넷팅 (Subnetting)**
    - 네트워크를 작은 단위로 분할
    - IP 주소 공간 효율적 사용
    - 서브넷 마스크: 네트워크 ID와 호스트 ID 구분
      - 예: 255.255.255.0 = /24 (CIDR 표기)
    - CIDR (Classless Inter-Domain Routing)
      - 예: 192.168.1.0/24
      - /24 = 앞 24비트가 네트워크, 뒤 8비트가 호스트
      - 호스트 수: 2^8 - 2 = 254 (네트워크, 브로드캐스트 제외)
  
  - **서브넷 계산**
    - 네트워크 주소: 서브넷의 첫 번째 주소
    - 브로드캐스트 주소: 서브넷의 마지막 주소
    - 사용 가능한 호스트 주소: 네트워크 ~ 브로드캐스트 사이
    - 예: 192.168.1.0/24
      - 네트워크: 192.168.1.0
      - 브로드캐스트: 192.168.1.255
      - 사용 가능: 192.168.1.1 ~ 192.168.1.254
  
  - **라우팅 (Routing)**
    - 패킷을 목적지까지 전달하는 경로 선택
    - 라우터: 서로 다른 네트워크 간 패킷 전달
    - 라우팅 테이블: 목적지 네트워크와 다음 홉 정보
    - 라우팅 프로토콜:
      - 정적 라우팅: 수동으로 라우팅 테이블 설정
      - 동적 라우팅: 자동으로 경로 학습
        - RIP, OSPF, BGP
  
  - **게이트웨이 (Gateway)**
    - 다른 네트워크로 나가는 출구
    - 기본 게이트웨이: 기본 라우트 (0.0.0.0/0)
    - 일반적으로 라우터의 IP 주소

- 실습 결과:
  - (실습 진행 후 기록)

- 참고 자료:
  - `man ip`, `man route`
  - 서브넷 계산기 온라인 도구

**DNS 동작 원리**

- 학습 내용:
  - **DNS (Domain Name System)**
    - 도메인 이름을 IP 주소로 변환하는 시스템
    - 사람이 읽기 쉬운 이름 (예: google.com) → IP 주소 (예: 8.8.8.8)
  
  - **DNS 계층 구조**
    - 루트 도메인: `.` (점)
    - 최상위 도메인 (TLD): `.com`, `.org`, `.kr` 등
    - 2차 도메인: `google`, `naver` 등
    - 서브도메인: `www`, `mail` 등
    - 예: `www.google.com.`
      - `.` (루트) → `.com` (TLD) → `google` (2차) → `www` (서브)
  
  - **DNS 레코드 타입**
    - A: IPv4 주소
    - AAAA: IPv6 주소
    - CNAME: 별칭 (다른 도메인으로 리다이렉션)
    - MX: 메일 서버
    - NS: 네임 서버
    - TXT: 텍스트 정보 (SPF, DKIM 등)
    - PTR: 역방향 DNS (IP → 도메인)
  
  - **DNS 쿼리 과정**
    1. 로컬 캐시 확인
    2. 로컬 DNS 서버 (ISP 또는 설정된 DNS)에 질의
    3. 루트 네임 서버에 질의
    4. TLD 네임 서버에 질의
    5. 권한 있는 네임 서버에서 최종 IP 주소 획득
    6. 결과를 캐시에 저장하고 반환
  
  - **DNS 서버 타입**
    - Recursive DNS: 클라이언트의 질의를 대신 처리
    - Authoritative DNS: 특정 도메인의 공식 정보 제공
    - Root DNS: 루트 도메인 정보 제공
  
  - **DNS 캐싱**
    - TTL (Time To Live): 레코드 유효 시간
    - 캐시를 통해 빠른 응답 및 네트워크 부하 감소

- 실습 결과:
  - (실습 진행 후 기록)

- 참고 자료:
  - `man nslookup`, `man dig`, `man host`
  - RFC 1035 (DNS)
  - 공용 DNS 서버: 8.8.8.8 (Google), 1.1.1.1 (Cloudflare)

**실습: 로컬 네트워크 구성 및 패킷 분석**
- 실습 환경:
- 구축 과정:
- 문제 해결:
- 결과:

## 핵심 명령어 모음

### 리눅스 기본 명령어
```bash
# 파일 시스템
ls -la
df -h
du -sh *

# 권한 관리
chmod 755 file
chown user:group file

# 프로세스 관리
ps aux
top
htop
kill -9 PID

# 서비스 관리
systemctl status service
systemctl start service
systemctl stop service
```

### 네트워킹 명령어
```bash
# 네트워크 확인
ifconfig
ip addr show
ip route show

# 연결 테스트
ping hostname
traceroute hostname
nslookup domain

# 패킷 분석
tcpdump -i eth0
wireshark
```

## 문제 해결 기록

### 문제 1
- 문제 상황:
- 원인 분석:
- 해결 방법:
- 참고 자료:

### 문제 2
- 문제 상황:
- 원인 분석:
- 해결 방법:
- 참고 자료:

## 다음 Phase 준비사항
- [ ] Docker 설치 확인
- [ ] 컨테이너 기초 개념 학습
- [ ] 실습 환경 준비

## 회고
- 잘한 점:
- 개선할 점:
- 다음 주 목표:

