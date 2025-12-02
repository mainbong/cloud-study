# Ch1. 네트워크 프로토콜

## 📋 개요

네트워크 프로토콜은 클라우드 인프라의 근간이 되는 핵심 기술입니다. TCP/IP부터 BGP, OSPF와 같은 라우팅 프로토콜, VLAN/VXLAN을 활용한 네트워크 가상화, 그리고 SDN(Software Defined Networking)까지 현대 클라우드 환경에서 필수적인 네트워킹 기술을 다룹니다.

2025년 현재, BBRv3 혼잡 제어, P4 프로그래머블 데이터 플레인, VXLAN EVPN 패브릭이 데이터센터 표준으로 자리잡았으며, 이러한 기술들을 이해하는 것은 클라우드 네트워킹 엔지니어에게 필수적입니다.

---

## 🎯 학습 목표

이 챕터를 완료하면 다음을 할 수 있습니다:

- TCP/IP 스택의 동작 원리와 BBR 혼잡 제어 알고리즘 이해
- BGP와 OSPF의 차이점과 적절한 사용 시나리오 판단
- VXLAN 오버레이 네트워크 설계 및 구현
- SDN 아키텍처와 OpenFlow/P4 프로토콜 활용
- 대규모 클라우드 환경에서의 라우팅 전략 수립

---

## Part 1: TCP/IP 기초 및 최적화

### 1-1. TCP/IP 스택 구조

**OSI 7계층 vs TCP/IP 4계층**

```
OSI 7계층              TCP/IP 4계층
─────────────────────  ─────────────────
Application            Application
Presentation           (애플리케이션)
Session
─────────────────────  ─────────────────
Transport              Transport
                       (전송)
─────────────────────  ─────────────────
Network                Internet
                       (인터넷)
─────────────────────  ─────────────────
Data Link              Network Access
Physical               (네트워크 액세스)
```

**핵심 프로토콜**

- **IP (Internet Protocol)**: 패킷 라우팅 및 주소 지정
- **TCP (Transmission Control Protocol)**: 신뢰성 있는 연결 지향 통신
- **UDP (User Datagram Protocol)**: 비연결형 고속 통신
- **ICMP (Internet Control Message Protocol)**: 에러 보고 및 진단

### 1-2. TCP 혼잡 제어의 진화

**전통적인 혼잡 제어 알고리즘**

**Loss-based 알고리즘 (Reno, CUBIC):**

```
처리량
  ▲
  │     ┌─────┐
  │    ╱       ╲      패킷 손실 발생
  │   ╱         ╲    ┌─────┐
  │  ╱           ╲  ╱       ╲
  │ ╱             ╲╱         ╲
  └──────────────────────────────► 시간

  문제점:
  - 패킷 손실이 발생해야만 대역폭 인지
  - 버퍼 블로트(Bufferbloat) 문제
  - 랜덤 손실에 취약
```

**BBR (Bottleneck Bandwidth and RTT)**

Google이 개발한 BBR은 패킷 손실이 아닌 **실제 대역폭과 RTT 측정**을 기반으로 동작합니다.

**BBR 버전별 발전사항 (2025):**

- **BBRv1 (2016)**: 초기 버전, loss-based 대비 4% 처리량 증가, RTT 33% 감소
- **BBRv2 (2018)**: 공정성 개선, 하지만 대역폭 활용률은 감소
- **BBRv3 (2023)**: BBRv2의 두 가지 버그 수정
  - 대역폭 프로빙 조기 종료 문제
  - 대역폭 수렴 문제
  - 초기 전송 공정성 개선

**2025년 최신 연구:**

TCP QtColFair 알고리즘이 BBR을 능가하는 성능을 보여줍니다:

- TCP QtColFair: 약 96% 대역폭 활용
- TCP BBR: 약 94% 대역폭 활용
- TCP CUBIC: 약 93% 대역폭 활용

**BBR 동작 원리:**

```python
# BBR 핵심 상태 머신
class BBRState:
    STARTUP = 0      # 최대 대역폭 탐색
    DRAIN = 1        # 큐 드레인
    PROBE_BW = 2     # 대역폭 프로빙 (주 상태)
    PROBE_RTT = 3    # RTT 프로빙

# BBR 핵심 변수
class BBRConnection:
    def __init__(self):
        self.btlbw = 0          # Bottleneck bandwidth
        self.rtprop = float('inf')  # Round-trip propagation time
        self.pacing_rate = 0    # 전송 속도
        self.cwnd = 0           # 혼잡 윈도우

    def update_model(self, delivered, rtt):
        # 최대 대역폭 추정
        self.btlbw = max(self.btlbw, delivered / rtt)

        # 최소 RTT 추정 (10초 윈도우)
        if rtt < self.rtprop:
            self.rtprop = rtt

    def set_pacing_rate(self):
        # 전송 속도 = BtlBw × pacing_gain
        self.pacing_rate = self.btlbw * self.pacing_gain

    def set_cwnd(self):
        # cwnd = BDP × cwnd_gain
        bdp = self.btlbw * self.rtprop
        self.cwnd = bdp * self.cwnd_gain
```

### 1-3. Linux에서 BBR 활성화

**시스템 설정:**

```bash
# BBR 사용 가능 확인 (커널 4.9 이상)
modprobe tcp_bbr

# sysctl 설정
cat >> /etc/sysctl.conf << EOF
# BBR 혼잡 제어 활성화
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# TCP 버퍼 크기 최적화
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864

# TCP 성능 튜닝
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
EOF

sysctl -p

# 확인
sysctl net.ipv4.tcp_congestion_control
# 출력: net.ipv4.tcp_congestion_control = bbr

sysctl net.core.default_qdisc
# 출력: net.core.default_qdisc = fq
```

**BBR 성능 측정:**

```bash
#!/bin/bash
# bbr-test.sh - BBR vs CUBIC 성능 비교

test_throughput() {
    local cc_algo=$1
    local server=$2

    # 혼잡 제어 알고리즘 변경
    sysctl -w net.ipv4.tcp_congestion_control=$cc_algo

    echo "Testing $cc_algo..."

    # iperf3로 처리량 측정
    iperf3 -c $server -t 60 -P 4 --json > result_${cc_algo}.json

    # 결과 파싱
    throughput=$(jq '.end.sum_received.bits_per_second' result_${cc_algo}.json)
    echo "$cc_algo: $(echo "scale=2; $throughput / 1000000000" | bc) Gbps"
}

# 테스트 실행
test_throughput "cubic" "test-server.example.com"
sleep 10
test_throughput "bbr" "test-server.example.com"
```

---

## Part 2: 라우팅 프로토콜 (BGP vs OSPF)

### 2-1. OSPF (Open Shortest Path First)

**OSPF 개요:**

- **타입**: IGP (Interior Gateway Protocol), Link State 라우팅
- **알고리즘**: Dijkstra's Shortest Path First
- **메트릭**: Cost (대역폭 기반)
- **적용 범위**: Autonomous System 내부
- **수렴 속도**: 매우 빠름 (초 단위)

**OSPF 동작 원리:**

```
1. 이웃 발견 (Neighbor Discovery)
   └─> Hello 패킷 교환 (10초마다)

2. 데이터베이스 동기화 (Database Synchronization)
   └─> LSA (Link State Advertisement) 교환

3. 최단 경로 계산 (SPF Calculation)
   └─> Dijkstra 알고리즘으로 SPF 트리 생성

4. 라우팅 테이블 업데이트
   └─> 최적 경로를 라우팅 테이블에 설치
```

**OSPF Area 설계:**

```
           ┌─────────────────────────────┐
           │      Area 0 (Backbone)       │
           │  ┌──┐    ┌──┐    ┌──┐       │
           │  │R1├────┤R2├────┤R3│       │
           │  └──┘    └──┘    └──┘       │
           └───┬────────┬────────┬────────┘
               │        │        │
     ┌─────────┴──┐  ┌──┴─────┐  └───────────┐
     │  Area 1    │  │ Area 2 │  │  Area 3   │
     │  (일반)     │  │(Stub)  │  │  (NSSA)   │
     └────────────┘  └────────┘  └───────────┘

Area 타입:
- Backbone (Area 0): 모든 area의 중심
- Standard Area: 일반 영역
- Stub Area: 외부 LSA 차단
- NSSA: Stub + 제한적 외부 라우트 허용
```

**OSPF 설정 예제 (FRRouting):**

```bash
# FRR 설정
vtysh

configure terminal

# OSPF 프로세스 시작
router ospf
  ospf router-id 1.1.1.1

  # 네트워크 선언
  network 10.0.1.0/24 area 0
  network 10.0.2.0/24 area 1

  # Area 설정
  area 1 stub

  # 인터페이스 타이머 조정
  interface eth0
    ip ospf hello-interval 5
    ip ospf dead-interval 20
    ip ospf cost 10
  exit

  # 수동 경로 재분배
  redistribute connected

  # 최대 경로 수
  maximum-paths 4

  exit

# 저장 및 적용
write memory
exit
```

### 2-2. BGP (Border Gateway Protocol)

**BGP 개요:**

- **타입**: EGP (Exterior Gateway Protocol), Path Vector 라우팅
- **메트릭**: AS Path, Local Preference, MED 등 다양한 속성
- **적용 범위**: Autonomous System 간
- **수렴 속도**: 상대적으로 느림 (분 단위)

**BGP의 핵심 개념:**

**AS (Autonomous System):**

```
AS 64512 (Private)          AS 64513 (Private)
┌─────────────┐             ┌─────────────┐
│   ┌──┐      │             │      ┌──┐   │
│   │R1│      │   eBGP      │      │R3│   │
│   └┬─┘      │◄───────────►│      └─┬┘   │
│    │ iBGP   │             │  iBGP  │    │
│   ┌▼─┐      │             │      ┌▼┐   │
│   │R2│      │             │      │R4│   │
│   └──┘      │             │      └──┘   │
└─────────────┘             └─────────────┘

- eBGP: AS 간 BGP (외부)
- iBGP: AS 내부 BGP (내부)
```

**BGP Path Selection Process:**

```
BGP Best Path Selection (순서대로 평가):

1. Weight (Cisco 전용, 높을수록 선호)
2. Local Preference (높을수록 선호)
3. Locally Originated (로컬 우선)
4. AS Path Length (짧을수록 선호)
5. Origin Code (IGP > EGP > Incomplete)
6. MED (Multi-Exit Discriminator, 낮을수록 선호)
7. eBGP > iBGP
8. IGP Metric to Next Hop (낮을수록 선호)
9. Oldest Route (안정성)
10. Router ID (낮을수록 선호)
```

**BGP 설정 예제 (FRRouting):**

```bash
vtysh

configure terminal

# BGP 프로세스 시작
router bgp 64512
  bgp router-id 1.1.1.1

  # eBGP 피어 설정
  neighbor 192.168.1.2 remote-as 64513
  neighbor 192.168.1.2 description "ISP-1"
  neighbor 192.168.1.2 password secretpass

  # iBGP 피어 설정
  neighbor 10.0.0.2 remote-as 64512
  neighbor 10.0.0.2 update-source lo0
  neighbor 10.0.0.2 next-hop-self

  # Address Family 설정
  address-family ipv4 unicast
    # 네트워크 광고
    network 10.0.0.0/8

    # 이웃별 정책
    neighbor 192.168.1.2 route-map ISP1-IN in
    neighbor 192.168.1.2 route-map ISP1-OUT out

    # 최대 경로 수
    maximum-paths 4
    maximum-paths ibgp 4
  exit-address-family

  exit

# Route Map 설정
route-map ISP1-IN permit 10
  set local-preference 200
  exit

route-map ISP1-OUT permit 10
  match ip address prefix-list ADVERTISE
  exit

# Prefix List
ip prefix-list ADVERTISE seq 5 permit 10.0.0.0/8
ip prefix-list ADVERTISE seq 10 deny any

write memory
exit
```

### 2-3. BGP vs OSPF 비교 및 사용 시나리오

**프로토콜 비교표:**

| 특성 | OSPF | BGP |
|------|------|-----|
| **라우팅 타입** | Link State | Path Vector |
| **적용 범위** | AS 내부 (IGP) | AS 간 (EGP) |
| **수렴 속도** | 빠름 (초 단위) | 느림 (분 단위) |
| **확장성** | 중간 (~200 라우터) | 매우 높음 (인터넷 전체) |
| **메트릭** | Cost (단일) | 다중 속성 |
| **CPU/메모리** | 높음 (SPF 계산) | 중간 |
| **주 사용처** | 데이터센터, LAN | WAN, 인터넷, 클라우드 간 연결 |

**2025 Best Practices (중요!):**

**절대 금지 사항:**

- **절대 BGP 프리픽스를 IGP로 재분배하지 마세요** - 네트워크가 확장되지 않습니다
- **IGP 라우트를 BGP로 재분배할 때** 적절한 RPL(Route Policy Language) 없이 하지 마세요
- **고객 프리픽스를 IGP로 전달하지 마세요** - 라우터 리소스 고갈 발생

**권장 사항:**

- **OSPF 사용 시나리오**:
  - 데이터센터 코어
  - 기업 LAN
  - 네트워크 성능 기반 경로 선택 필요 시

- **BGP 사용 시나리오**:
  - 인터넷 이중화
  - WAN 환경
  - IaaS/멀티 클라우드 환경
  - AS 간 연결

- **BGP 최적화**:
  - Route Summarization으로 라우팅 테이블 크기 감소
  - Route Filtering으로 효율적인 광고/수신
  - Route Reflector/Confederation으로 확장성 확보

**클라우드 환경에서의 선택:**

```
시나리오별 프로토콜 선택 가이드:

1. 프라이빗 데이터센터 내부
   └─> OSPF (빠른 수렴, 성능 기반 라우팅)

2. 멀티 데이터센터 연결
   └─> BGP (유연한 정책, 확장성)

3. 클라우드-온프레미스 하이브리드
   └─> BGP (AS 분리, 독립적인 관리)

4. VXLAN EVPN Underlay
   └─> OSPF, IS-IS, 또는 eBGP 중 선택

5. VXLAN EVPN Overlay
   └─> iBGP 또는 eBGP
```

**하이브리드 접근법:**

```bash
# OSPF를 Underlay로, BGP를 Overlay로 사용하는 예제

# 1. Underlay: OSPF로 기본 연결성 제공
router ospf
  network 10.0.0.0/8 area 0
  passive-interface default
  no passive-interface eth1
  no passive-interface eth2
  exit

# 2. Overlay: BGP EVPN으로 L2/L3 서비스 제공
router bgp 64512
  neighbor SPINE peer-group
  neighbor SPINE remote-as 64512
  neighbor SPINE update-source lo0

  neighbor 10.0.1.1 peer-group SPINE
  neighbor 10.0.1.2 peer-group SPINE

  address-family l2vpn evpn
    neighbor SPINE activate
    advertise-all-vni
  exit-address-family

  exit
```

---

## Part 3: VLAN/VXLAN 네트워크 가상화

### 3-1. VLAN의 한계와 VXLAN의 등장

**전통적인 VLAN:**

```
┌─────────────────────────────────┐
│   802.1Q VLAN Tag (4 bytes)     │
├────┬────┬───────┬────────────────┤
│TPID│PCP│ CFI   │   VLAN ID      │
│2B  │3b │ 1b    │   12 bits      │
└────┴────┴───────┴────────────────┘

- VLAN ID: 12비트 = 4,094개 네트워크 (0, 4095 예약)
- Layer 2 도메인에 제한
- 멀티테넌트 클라우드에 부족
```

**VXLAN (Virtual Extensible LAN):**

```
VXLAN 헤더 구조:

┌──────────────────────────────────────┐
│        Outer Ethernet Header          │  ← L2
├──────────────────────────────────────┤
│         Outer IP Header               │  ← L3
├──────────────────────────────────────┤
│         Outer UDP Header              │  ← L4
│         (Dest Port: 4789)             │
├──────────────────────────────────────┤
│    VXLAN Header (8 bytes)             │
│  ┌────────────┬──────────────┐       │
│  │   Flags    │   Reserved   │       │
│  ├────────────┴──────────────┤       │
│  │   VNI (24 bits)           │       │  ← 16M 네트워크
│  └───────────────────────────┘       │
├──────────────────────────────────────┤
│     Inner Ethernet Frame              │  ← 원본 프레임
└──────────────────────────────────────┘

VNI (VXLAN Network Identifier):
- 24비트 = 16,777,216개 네트워크
- VLAN의 4,094배 확장성
```

### 3-2. VXLAN 동작 원리

**VTEP (VXLAN Tunnel Endpoint):**

```
     Tenant VM 1           Tenant VM 2
     (VLAN 10)             (VLAN 10)
         │                     │
         │                     │
    ┌────▼────┐           ┌────▼────┐
    │  VTEP1  │           │  VTEP2  │
    │10.1.1.1 │           │10.1.1.2 │
    └────┬────┘           └────┬────┘
         │                     │
         │   L3 Network        │
         │   (Underlay)        │
         └─────────────────────┘

프로세스:
1. VM1이 VM2로 프레임 전송
2. VTEP1이 프레임 캡슐화:
   - 원본 프레임에 VXLAN 헤더 추가
   - UDP/IP 헤더 추가 (Dest: VTEP2)
3. L3 네트워크를 통해 전송
4. VTEP2가 디캡슐화 후 VM2에 전달
```

**VXLAN 제어 평면 옵션:**

**1. Multicast 기반 (레거시):**

```bash
# Multicast 그룹 설정
ip link add vxlan10 type vxlan \
  id 10 \
  group 239.1.1.1 \
  dev eth0 \
  dstport 4789

# 문제점:
# - 물리 네트워크에 멀티캐스트 지원 필요
# - 브로드캐스트 트래픽 증가
```

**2. EVPN (Ethernet VPN) - 2025 표준:**

```
BGP EVPN 제어 평면:

           ┌──────────────┐
           │ BGP Route    │
           │ Reflector    │
           └───────┬──────┘
                   │
         ┌─────────┼─────────┐
         │         │         │
    ┌────▼───┐ ┌──▼────┐ ┌──▼────┐
    │ VTEP 1 │ │VTEP 2 │ │VTEP 3 │
    └────────┘ └───────┘ └───────┘

EVPN Route Types:
- Type 2: MAC/IP Advertisement
- Type 3: Inclusive Multicast Ethernet Tag
- Type 5: IP Prefix Route (L3 VPN)

장점:
✓ 멀티캐스트 불필요
✓ 효율적인 MAC 학습
✓ ARP 억제
✓ L2/L3 통합
```

### 3-3. VXLAN 구현 (Linux + FRR)

**기본 VXLAN 인터페이스 생성:**

```bash
#!/bin/bash
# vxlan-setup.sh - VXLAN 인터페이스 설정

VXLAN_ID=100
VXLAN_PORT=4789
VTEP_IP=10.0.1.1
BRIDGE_NAME=br-vxlan100

# VXLAN 인터페이스 생성
ip link add vxlan${VXLAN_ID} type vxlan \
  id ${VXLAN_ID} \
  dstport ${VXLAN_PORT} \
  local ${VTEP_IP} \
  nolearning

# 브리지 생성
ip link add ${BRIDGE_NAME} type bridge

# VXLAN을 브리지에 추가
ip link set vxlan${VXLAN_ID} master ${BRIDGE_NAME}

# 인터페이스 활성화
ip link set vxlan${VXLAN_ID} up
ip link set ${BRIDGE_NAME} up

# VM 연결 (예: tap 인터페이스)
ip link set tap0 master ${BRIDGE_NAME}
```

**EVPN VXLAN 설정 (FRR):**

```bash
# FRRouting 설정
vtysh

configure terminal

# 1. Underlay: OSPF 설정
router ospf
  ospf router-id 10.0.1.1
  network 10.0.0.0/8 area 0
  exit

# 2. Overlay: BGP EVPN 설정
router bgp 64512
  bgp router-id 10.0.1.1
  no bgp default ipv4-unicast

  # Route Reflector와 피어링
  neighbor 10.0.0.1 remote-as 64512
  neighbor 10.0.0.1 update-source lo

  # L2VPN EVPN Address Family
  address-family l2vpn evpn
    neighbor 10.0.0.1 activate
    advertise-all-vni
    advertise-default-gw
  exit-address-family

  exit

# 3. VXLAN 인터페이스를 BGP에 매핑
vrf VRF-TENANT-A
  vni 1000
  exit

interface vxlan100
  vxlan id 100
  vxlan local-tunnelip 10.0.1.1
  bridge-access 100
  exit

write memory
exit
```

**VXLAN 모니터링:**

```bash
# VXLAN 인터페이스 확인
ip -d link show type vxlan

# FDB (Forwarding Database) 확인
bridge fdb show dev vxlan100

# EVPN 라우트 확인
vtysh -c "show bgp l2vpn evpn route"

# VNI 정보 확인
vtysh -c "show evpn vni"

# VTEP 정보 확인
vtysh -c "show evpn vni 100 detail"
```

### 3-4. VXLAN 성능 최적화

**하드웨어 오프로드:**

```bash
# NIC 오프로드 기능 확인
ethtool -k eth0 | grep -E "tx-udp_tnl-segmentation|rx-udp_tnl-port-offload"

# VXLAN 오프로드 활성화
ethtool -K eth0 tx-udp_tnl-segmentation on
ethtool -K eth0 rx-udp_tnl-port-offload on

# RSS (Receive Side Scaling) 설정
ethtool -X eth0 equal $(nproc)

# Ring buffer 크기 증가
ethtool -G eth0 rx 4096 tx 4096
```

**MTU 최적화:**

```bash
# VXLAN 오버헤드 계산
# 원본 프레임: 1500 bytes
# + Outer Ethernet: 14 bytes
# + Outer IP: 20 bytes
# + Outer UDP: 8 bytes
# + VXLAN: 8 bytes
# = 1550 bytes

# 물리 인터페이스 MTU 증가
ip link set dev eth0 mtu 9000  # Jumbo frame

# VXLAN 인터페이스 MTU
ip link set dev vxlan100 mtu 8950

# 브리지 MTU
ip link set dev br-vxlan100 mtu 8950
```

**VXLAN 트래픽 분석:**

```bash
#!/bin/bash
# vxlan-analyze.sh - VXLAN 트래픽 분석

# VXLAN 트래픽 캡처
tcpdump -i eth0 -nn 'udp port 4789' -w vxlan.pcap

# 통계 출력
tcpdump -r vxlan.pcap -nn | \
  awk '{print $3}' | \
  cut -d. -f1-4 | \
  sort | uniq -c | sort -nr

# VXLAN 디캡슐레이션 후 내용 확인
tshark -r vxlan.pcap -Y vxlan -V

# 성능 메트릭
sar -n DEV 1 10 | grep vxlan100
```

---

## Part 4: SDN (Software Defined Networking)

### 4-1. SDN 아키텍처

**전통적인 네트워크 vs SDN:**

```
전통적인 네트워크:
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│  Application   │  │  Application   │  │  Application   │
├────────────────┤  ├────────────────┤  ├────────────────┤
│ Control Plane  │  │ Control Plane  │  │ Control Plane  │
├────────────────┤  ├────────────────┤  ├────────────────┤
│  Data Plane    │  │  Data Plane    │  │  Data Plane    │
└────────────────┘  └────────────────┘  └────────────────┘
     Switch 1            Switch 2            Switch 3

문제점: 분산된 제어, 정책 불일치, 자동화 어려움


SDN 아키텍처:
┌──────────────────────────────────────────────────┐
│         Application Layer                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │Monitoring│  │Firewall  │  │ Load     │       │
│  │          │  │          │  │ Balancer │       │
│  └──────────┘  └──────────┘  └──────────┘       │
└────────────────────┬─────────────────────────────┘
                     │ Northbound API (REST)
┌────────────────────▼─────────────────────────────┐
│         Control Layer (SDN Controller)           │
│  ┌──────────────────────────────────────┐        │
│  │  OpenDaylight / ONOS / Ryu / Floodlight│      │
│  └──────────────────────────────────────┘        │
└────────────────────┬─────────────────────────────┘
                     │ Southbound API (OpenFlow/P4)
┌────────────────────▼─────────────────────────────┐
│         Data Plane Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ Switch 1 │  │ Switch 2 │  │ Switch 3 │       │
│  └──────────┘  └──────────┘  └──────────┘       │
└──────────────────────────────────────────────────┘

장점: 중앙화된 제어, 프로그래머빌리티, 자동화
```

### 4-2. OpenFlow 프로토콜

**OpenFlow 개념:**

OpenFlow는 SDN의 초기 southbound 프로토콜로, 제어 평면과 데이터 평면을 분리합니다.

**OpenFlow Switch 구조:**

```
┌──────────────────────────────────────┐
│       OpenFlow Switch                 │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │   Flow Tables                   │ │
│  │  ┌──────────┬────────┬────────┐ │ │
│  │  │ Table 0  │Table 1 │Table N │ │ │
│  │  └──────────┴────────┴────────┘ │ │
│  └─────────────────────────────────┘ │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │   Group Table                   │ │
│  └─────────────────────────────────┘ │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │   Meter Table                   │ │
│  └─────────────────────────────────┘ │
│                                       │
│  ┌─────────────────────────────────┐ │
│  │   OpenFlow Channel              │ │
│  │   (TLS Connection to Controller)│ │
│  └─────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Flow Entry 구조:**

```
┌────────────┬──────────┬──────────┬──────────┬───────────┬────────┐
│   Match    │ Priority │ Counters │ Instructions│ Timeouts│ Cookie │
│   Fields   │          │          │  Actions  │          │        │
└────────────┴──────────┴──────────┴──────────┴───────────┴────────┘

Match Fields (예):
- Ingress Port
- Ethernet Src/Dst
- VLAN ID
- IP Src/Dst
- TCP/UDP Port
- MPLS Label
- etc...

Actions (예):
- OUTPUT: 특정 포트로 전송
- DROP: 패킷 폐기
- SET_FIELD: 헤더 필드 수정
- PUSH_VLAN: VLAN 태그 추가
- POP_VLAN: VLAN 태그 제거
```

**OpenFlow 컨트롤러 예제 (Ryu):**

```python
# simple_switch.py - 간단한 L2 스위치

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet

class SimpleSwitch(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(SimpleSwitch, self).__init__(*args, **kwargs)
        # MAC 주소 테이블: {dpid: {mac: port}}
        self.mac_to_port = {}

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """스위치 연결 시 초기 설정"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        # Table-miss flow entry 설치
        # 매칭되는 flow가 없으면 컨트롤러로 전송
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                         ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)

    def add_flow(self, datapath, priority, match, actions, buffer_id=None):
        """Flow entry 추가"""
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS,
                                            actions)]

        if buffer_id:
            mod = parser.OFPFlowMod(datapath=datapath, buffer_id=buffer_id,
                                   priority=priority, match=match,
                                   instructions=inst)
        else:
            mod = parser.OFPFlowMod(datapath=datapath, priority=priority,
                                   match=match, instructions=inst,
                                   idle_timeout=30, hard_timeout=60)

        datapath.send_msg(mod)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        """Packet-In 메시지 처리"""
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']

        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocols(ethernet.ethernet)[0]

        dst = eth.dst
        src = eth.src
        dpid = datapath.id

        # MAC 주소 학습
        self.mac_to_port.setdefault(dpid, {})
        self.mac_to_port[dpid][src] = in_port

        # 목적지 포트 결정
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD

        actions = [parser.OFPActionOutput(out_port)]

        # Flow entry 설치 (flooding이 아닌 경우)
        if out_port != ofproto.OFPP_FLOOD:
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst)
            self.add_flow(datapath, 1, match, actions, msg.buffer_id)

            if msg.buffer_id != ofproto.OFP_NO_BUFFER:
                return

        # Packet-Out
        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data

        out = parser.OFPPacketOut(datapath=datapath, buffer_id=msg.buffer_id,
                                 in_port=in_port, actions=actions, data=data)
        datapath.send_msg(out)
```

**OpenFlow 스위치 설정 (Open vSwitch):**

```bash
# Open vSwitch 설치
apt-get install openvswitch-switch

# 브리지 생성
ovs-vsctl add-br br0

# OpenFlow 1.3 사용
ovs-vsctl set bridge br0 protocols=OpenFlow13

# 컨트롤러 연결
ovs-vsctl set-controller br0 tcp:192.168.1.100:6653

# 포트 추가
ovs-vsctl add-port br0 eth1
ovs-vsctl add-port br0 eth2

# 설정 확인
ovs-vsctl show

# Flow 확인
ovs-ofctl -O OpenFlow13 dump-flows br0

# 포트 통계
ovs-ofctl -O OpenFlow13 dump-ports br0
```

### 4-3. P4 (Programming Protocol-independent Packet Processors)

**OpenFlow의 한계:**

- 고정된 헤더 필드만 지원
- 새로운 프로토콜 추가 어려움
- 파싱 로직 변경 불가

**P4의 혁신:**

P4는 데이터 플레인을 완전히 프로그래밍 가능하게 만듭니다.

**P4 아키텍처:**

```
P4 프로그램 구조:

┌──────────────────────────────────────┐
│         Headers 정의                  │
│  (패킷의 어떤 필드를 파싱할지)         │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│         Parser                        │
│  (패킷을 어떻게 파싱할지)              │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│    Match-Action Tables                │
│  (패킷을 어떻게 처리할지)              │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│         Deparser                      │
│  (패킷을 어떻게 재조합할지)            │
└──────────────────────────────────────┘
```

**P4 코드 예제 - 간단한 L3 포워딩:**

```p4
/* simple_l3_forwarding.p4 */

#include <core.p4>
#include <v1model.p4>

/* 헤더 정의 */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

/* 메타데이터 */
struct metadata {
    bit<9> egress_port;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t     ipv4;
}

/* Parser */
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

/* Ingress Processing */
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* IPv4 라우팅 테이블 */
    action drop() {
        mark_to_drop(standard_metadata);
    }

    action ipv4_forward(bit<48> dstAddr, bit<9> port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;  // Longest Prefix Match
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
    }
}

/* Egress Processing */
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/* Checksum Verification */
control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {
        verify_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/* Checksum Computation */
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/* Deparser */
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

/* Switch 인스턴스 */
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
```

**P4 vs OpenFlow 비교:**

| 특성 | OpenFlow | P4 |
|------|----------|-----|
| **헤더 필드** | 고정 | 프로그래밍 가능 |
| **프로토콜 지원** | 사전 정의된 것만 | 임의 프로토콜 |
| **파서** | 하드코딩 | 프로그래밍 가능 |
| **유연성** | 낮음 | 매우 높음 |
| **성능** | 하드웨어 가속 | 하드웨어 가속 |
| **학습 곡선** | 낮음 | 높음 |
| **현 상태** | 성숙 | 성장 중 |

**2025년 P4 활용 사례:**

- **In-Network Computing**: 네트워크에서 직접 연산 수행
- **Telemetry**: INT (In-band Network Telemetry)
- **보안**: DDoS 방어, 이상 탐지
- **최적화**: 커스텀 로드 밸런싱, 트래픽 엔지니어링

### 4-4. 하이브리드 OpenFlow-P4 아키텍처

**사용 사례: SDN-WAN 트래픽 라우팅**

```
┌────────────────────────────────────────────────┐
│         SDN Controller                         │
│  (OpenFlow + P4 Runtime API)                   │
└───────────┬────────────────────────┬───────────┘
            │                        │
    OpenFlow│                        │P4 Runtime
            │                        │
┌───────────▼───────────┐  ┌─────────▼──────────┐
│   P4 Switch (Ingress) │  │ OpenFlow Core      │
│   - 패킷 변환          │  │ - L2/L3 포워딩     │
│   - QoS 마킹          │──>│ - Flow 관리        │──>
│   - Telemetry 삽입    │  │                    │
└───────────────────────┘  └─────────┬──────────┘
                                     │
                          ┌──────────▼──────────┐
                          │ P4 Switch (Egress)  │
                          │ - 패킷 복원         │
                          │ - Telemetry 추출    │
                          └─────────────────────┘

흐름:
1. P4 스위치가 ingress에서 패킷 변환
2. OpenFlow 코어가 표준 L2/L3 포워딩
3. P4 스위치가 egress에서 원래 형태로 복원
```

---

## 🛠️ 실습 가이드

### 실습 1: BBR 혼잡 제어 성능 측정

**목표**: BBR과 CUBIC의 성능 비교

**환경 요구사항:**

- Linux 서버 2대 (커널 4.9 이상)
- iperf3 설치
- 충분한 대역폭 (1Gbps 이상 권장)

**실습 단계:**

```bash
# === 서버 측 (test-server) ===

# 1. BBR 커널 모듈 로드
sudo modprobe tcp_bbr

# 2. iperf3 서버 시작
iperf3 -s -p 5201


# === 클라이언트 측 ===

# 3. CUBIC으로 테스트
sudo sysctl -w net.ipv4.tcp_congestion_control=cubic
iperf3 -c test-server -t 60 -P 4 -i 5 | tee cubic_result.txt

# 30초 대기
sleep 30

# 4. BBR로 테스트
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
iperf3 -c test-server -t 60 -P 4 -i 5 | tee bbr_result.txt

# 5. 결과 비교
echo "=== CUBIC ==="
grep "sender" cubic_result.txt | tail -1

echo "=== BBR ==="
grep "sender" bbr_result.txt | tail -1
```

**예상 결과:**

```
=== CUBIC ===
[SUM]   0.00-60.00  sec  5.12 GBytes   733 Mbits/sec  125    sender

=== BBR ===
[SUM]   0.00-60.00  sec  5.33 GBytes   763 Mbits/sec   42    sender

분석:
- BBR이 약 4% 더 높은 처리량
- 재전송(retransmits) 횟수 감소
- 더 안정적인 성능
```

### 실습 2: VXLAN EVPN 네트워크 구축

**목표**: 3개 노드로 VXLAN EVPN 패브릭 구성

**토폴로지:**

```
        10.0.0.1 (Route Reflector)
             │
    ┌────────┼────────┐
    │        │        │
10.0.1.1  10.0.1.2  10.0.1.3
 VTEP1     VTEP2     VTEP3
   │         │         │
  VM1       VM2       VM3
```

**실습 단계:**

**Node 1 (Route Reflector):**

```bash
# FRR 설정
sudo vtysh

configure terminal

# OSPF Underlay
router ospf
  ospf router-id 10.0.0.1
  network 10.0.0.0/24 area 0
  network 10.0.1.0/24 area 0
  exit

# BGP EVPN
router bgp 64512
  bgp router-id 10.0.0.1
  neighbor VTEPS peer-group
  neighbor VTEPS remote-as 64512
  neighbor VTEPS update-source lo
  bgp listen range 10.0.1.0/24 peer-group VTEPS

  address-family l2vpn evpn
    neighbor VTEPS activate
    neighbor VTEPS route-reflector-client
  exit-address-family

  exit

write memory
exit
```

**Node 2 (VTEP1):**

```bash
# 1. VXLAN 인터페이스 생성
sudo ip link add vxlan100 type vxlan \
  id 100 \
  dstport 4789 \
  local 10.0.1.1 \
  nolearning

sudo ip link add br100 type bridge
sudo ip link set vxlan100 master br100
sudo ip link set vxlan100 up
sudo ip link set br100 up

# VM tap 인터페이스 연결 (가정)
sudo ip link set tap0 master br100

# 2. FRR 설정
sudo vtysh

configure terminal

router ospf
  ospf router-id 10.0.1.1
  network 10.0.0.0/24 area 0
  network 10.0.1.0/24 area 0
  exit

router bgp 64512
  bgp router-id 10.0.1.1
  neighbor 10.0.0.1 remote-as 64512
  neighbor 10.0.0.1 update-source lo

  address-family l2vpn evpn
    neighbor 10.0.0.1 activate
    advertise-all-vni
  exit-address-family

  exit

write memory
exit
```

**Node 3, 4 (VTEP2, VTEP3):**

Node 2와 동일하게 설정 (IP 주소만 변경)

**확인:**

```bash
# EVPN 라우트 확인
sudo vtysh -c "show bgp l2vpn evpn"

# VNI 정보 확인
sudo vtysh -c "show evpn vni"

# VTEP 피어 확인
sudo vtysh -c "show evpn vni 100 detail"

# MAC 주소 확인
sudo bridge fdb show dev vxlan100

# 연결성 테스트 (VM1에서 VM2로)
ping <VM2-IP>
```

### 실습 3: Ryu로 간단한 SDN 컨트롤러 구축

**목표**: OpenFlow 기반 L2 학습 스위치 구현

**환경 요구사항:**

- Linux 서버 1대
- Mininet 설치
- Ryu 컨트롤러 설치

**설치:**

```bash
# Ryu 설치
sudo pip3 install ryu

# Mininet 설치
sudo apt-get install mininet
```

**컨트롤러 코드 (위의 simple_switch.py 저장):**

```bash
# simple_switch.py 실행
ryu-manager simple_switch.py
```

**네트워크 토폴로지 생성:**

```bash
# 별도 터미널에서 Mininet 실행
sudo mn --controller=remote,ip=127.0.0.1 --mac --switch=ovsk,protocols=OpenFlow13 --topo=tree,2,2

# Mininet CLI에서:
mininet> pingall    # 연결성 테스트
mininet> h1 ping h4  # 개별 테스트
```

**Flow 확인:**

```bash
# 또 다른 터미널에서
sudo ovs-ofctl -O OpenFlow13 dump-flows s1
sudo ovs-ofctl -O OpenFlow13 dump-flows s2
sudo ovs-ofctl -O OpenFlow13 dump-flows s3
```

**예상 출력:**

```
cookie=0x0, duration=5.123s, table=0, n_packets=10, n_bytes=980, priority=1,in_port=1,dl_dst=00:00:00:00:00:02 actions=output:2
cookie=0x0, duration=5.123s, table=0, n_packets=10, n_bytes=980, priority=1,in_port=2,dl_dst=00:00:00:00:00:01 actions=output:1

분석:
- MAC 주소 기반 포워딩 flow 설치됨
- Packet-In 없이 스위치에서 직접 처리
- 학습 스위치 동작 확인
```

### 실습 4: P4 기본 프로그래밍

**목표**: P4 기본 문법 학습 및 BMv2로 테스트

**환경 요구사항:**

- Ubuntu 20.04 이상
- P4 컴파일러 및 BMv2 설치

**설치:**

```bash
# 의존성 설치
sudo apt-get install -y \
  automake cmake g++ git libgc-dev \
  libgmp-dev libpcap-dev libtool \
  python3 python3-pip

# P4C 컴파일러 설치
git clone https://github.com/p4lang/p4c.git
cd p4c
mkdir build && cd build
cmake ..
make -j4
sudo make install

# Behavioral Model v2 (BMv2) 설치
git clone https://github.com/p4lang/behavioral-model.git
cd behavioral-model
./install_deps.sh
./autogen.sh
./configure
make -j4
sudo make install
```

**P4 프로그램 컴파일 및 실행:**

```bash
# 1. P4 코드 컴파일 (위의 simple_l3_forwarding.p4 사용)
p4c --target bmv2 --arch v1model \
    --p4runtime-files simple_l3.p4info.txt \
    -o simple_l3.json simple_l3_forwarding.p4

# 2. BMv2 스위치 시작
sudo simple_switch_grpc \
    --log-console \
    -i 0@veth0 -i 1@veth2 \
    --no-p4 \
    -- --grpc-server-addr 0.0.0.0:50051

# 3. Runtime CLI로 테이블 엔트리 추가
simple_switch_CLI

# CLI에서:
RuntimeCmd: table_add ipv4_lpm ipv4_forward 10.0.1.0/24 => 00:00:00:00:01:01 1
RuntimeCmd: table_add ipv4_lpm ipv4_forward 10.0.2.0/24 => 00:00:00:00:02:01 2
RuntimeCmd: table_dump ipv4_lpm
```

---

## 💻 예제 코드

### 예제 1: 네트워크 성능 모니터링 스크립트

```python
#!/usr/bin/env python3
# network_monitor.py - 네트워크 성능 실시간 모니터링

import psutil
import time
from datetime import datetime
from collections import defaultdict

class NetworkMonitor:
    def __init__(self, interval=1):
        self.interval = interval
        self.prev_stats = {}

    def get_interface_stats(self):
        """인터페이스별 통계 수집"""
        stats = psutil.net_io_counters(pernic=True)
        return stats

    def calculate_rates(self, current, previous):
        """전송 속도 계산 (bps, pps)"""
        rates = {}

        for iface, curr_stat in current.items():
            if iface not in previous:
                continue

            prev_stat = previous[iface]

            # 바이트 속도 (Mbps)
            bytes_sent = (curr_stat.bytes_sent - prev_stat.bytes_sent) / self.interval
            bytes_recv = (curr_stat.bytes_recv - prev_stat.bytes_recv) / self.interval

            # 패킷 속도 (pps)
            pkts_sent = (curr_stat.packets_sent - prev_stat.packets_sent) / self.interval
            pkts_recv = (curr_stat.packets_recv - prev_stat.packets_recv) / self.interval

            # 에러 및 드롭
            errors = curr_stat.errin + curr_stat.errout
            drops = curr_stat.dropin + curr_stat.dropout

            rates[iface] = {
                'tx_mbps': bytes_sent * 8 / 1_000_000,
                'rx_mbps': bytes_recv * 8 / 1_000_000,
                'tx_pps': pkts_sent,
                'rx_pps': pkts_recv,
                'errors': errors,
                'drops': drops
            }

        return rates

    def print_stats(self, rates):
        """통계 출력"""
        print(f"\n{'='*80}")
        print(f"Network Statistics - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*80}")
        print(f"{'Interface':<15} {'TX Mbps':>10} {'RX Mbps':>10} {'TX pps':>10} {'RX pps':>10} {'Errors':>8} {'Drops':>8}")
        print(f"{'-'*80}")

        for iface, stat in sorted(rates.items()):
            if stat['tx_mbps'] > 0 or stat['rx_mbps'] > 0:
                print(f"{iface:<15} {stat['tx_mbps']:>10.2f} {stat['rx_mbps']:>10.2f} "
                      f"{stat['tx_pps']:>10.0f} {stat['rx_pps']:>10.0f} "
                      f"{stat['errors']:>8} {stat['drops']:>8}")

    def run(self):
        """모니터링 시작"""
        print("Network monitoring started. Press Ctrl+C to stop.")

        try:
            self.prev_stats = self.get_interface_stats()
            time.sleep(self.interval)

            while True:
                current_stats = self.get_interface_stats()
                rates = self.calculate_rates(current_stats, self.prev_stats)
                self.print_stats(rates)

                self.prev_stats = current_stats
                time.sleep(self.interval)

        except KeyboardInterrupt:
            print("\n\nMonitoring stopped.")

if __name__ == "__main__":
    monitor = NetworkMonitor(interval=2)
    monitor.run()
```

**사용법:**

```bash
sudo python3 network_monitor.py
```

### 예제 2: BGP 라우트 분석 도구

```python
#!/usr/bin/env python3
# bgp_route_analyzer.py - BGP 라우트 테이블 분석

import subprocess
import json
from collections import Counter, defaultdict

class BGPRouteAnalyzer:
    def __init__(self):
        self.routes = []

    def fetch_bgp_routes(self):
        """FRR에서 BGP 라우트 가져오기"""
        try:
            cmd = "vtysh -c 'show ip bgp json'"
            output = subprocess.check_output(cmd, shell=True)
            data = json.loads(output)

            if 'routes' in data:
                self.routes = data['routes']

            return len(self.routes)
        except Exception as e:
            print(f"Error fetching BGP routes: {e}")
            return 0

    def analyze_as_paths(self):
        """AS Path 분석"""
        path_lengths = []
        as_counter = Counter()

        for prefix, info in self.routes.items():
            for path_info in info:
                if 'path' in path_info:
                    as_path = path_info['path'].split()
                    path_lengths.append(len(as_path))

                    for asn in as_path:
                        as_counter[asn] += 1

        print("\n=== AS Path Analysis ===")
        print(f"Total Routes: {len(self.routes)}")
        print(f"Average AS Path Length: {sum(path_lengths)/len(path_lengths):.2f}")
        print(f"Max AS Path Length: {max(path_lengths)}")
        print(f"Min AS Path Length: {min(path_lengths)}")

        print("\nTop 10 Transit ASNs:")
        for asn, count in as_counter.most_common(10):
            print(f"  AS{asn}: {count} occurrences")

    def analyze_next_hops(self):
        """Next Hop 분석"""
        next_hop_counter = Counter()

        for prefix, info in self.routes.items():
            for path_info in info:
                if 'nexthops' in path_info:
                    for nh in path_info['nexthops']:
                        if 'ip' in nh:
                            next_hop_counter[nh['ip']] += 1

        print("\n=== Next Hop Analysis ===")
        for nh, count in next_hop_counter.most_common():
            print(f"  {nh}: {count} routes")

    def find_redundant_paths(self):
        """중복 경로 찾기"""
        prefix_count = Counter()

        for prefix in self.routes.keys():
            # /24로 집계
            network = '.'.join(prefix.split('/')[0].split('.')[:3]) + '.0/24'
            prefix_count[network] += 1

        print("\n=== Potential Route Summarization ===")
        candidates = {k: v for k, v in prefix_count.items() if v > 5}

        if candidates:
            print("Networks with many specific routes (summarization candidates):")
            for network, count in sorted(candidates.items(), key=lambda x: x[1], reverse=True)[:10]:
                print(f"  {network}: {count} specific routes")
        else:
            print("No obvious summarization candidates found.")

    def analyze_origin(self):
        """Origin 분석"""
        origin_counter = Counter()

        for prefix, info in self.routes.items():
            for path_info in info:
                if 'origin' in path_info:
                    origin_counter[path_info['origin']] += 1

        print("\n=== Origin Analysis ===")
        for origin, count in origin_counter.items():
            print(f"  {origin}: {count} routes")

    def run_analysis(self):
        """전체 분석 실행"""
        print("Fetching BGP routes...")
        route_count = self.fetch_bgp_routes()

        if route_count == 0:
            print("No BGP routes found.")
            return

        print(f"Analyzing {route_count} BGP routes...\n")

        self.analyze_as_paths()
        self.analyze_next_hops()
        self.find_redundant_paths()
        self.analyze_origin()

if __name__ == "__main__":
    analyzer = BGPRouteAnalyzer()
    analyzer.run_analysis()
```

### 예제 3: VXLAN 터널 상태 모니터링

```bash
#!/bin/bash
# vxlan_monitor.sh - VXLAN 터널 상태 모니터링

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "=========================================="
    echo "  VXLAN Tunnel Monitoring"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
}

check_vxlan_interfaces() {
    echo ""
    echo "=== VXLAN Interfaces ==="

    ip -d link show type vxlan | while read -r line; do
        if [[ $line =~ ^[0-9]+: ]]; then
            iface=$(echo $line | cut -d: -f2 | tr -d ' ')
            echo -e "\n${GREEN}Interface: $iface${NC}"
        elif [[ $line =~ vxlan ]]; then
            echo "  $line"
        fi
    done
}

check_fdb() {
    echo ""
    echo "=== FDB Entries per VXLAN ==="

    for vxlan in $(ip -o link show type vxlan | cut -d: -f2 | tr -d ' '); do
        count=$(bridge fdb show dev $vxlan | grep -v "permanent" | wc -l)
        echo "  $vxlan: $count entries"

        # Top 5 entries
        echo "    Top remote VTEPs:"
        bridge fdb show dev $vxlan | grep -v "permanent" | \
            awk '{print $3}' | sort | uniq -c | sort -rn | head -5 | \
            while read count ip; do
                echo "      $ip: $count MACs"
            done
    done
}

check_evpn_status() {
    echo ""
    echo "=== EVPN Status ==="

    if command -v vtysh &> /dev/null; then
        # VNI 정보
        echo "  VNI Summary:"
        vtysh -c "show evpn vni" 2>/dev/null | grep -E "VNI|Number" || \
            echo "    EVPN not configured or FRR not running"

        # BGP EVPN 피어
        echo ""
        echo "  BGP EVPN Peers:"
        vtysh -c "show bgp l2vpn evpn summary" 2>/dev/null | \
            tail -n +8 || echo "    No EVPN peers"
    else
        echo "  FRR/vtysh not available"
    fi
}

check_traffic() {
    echo ""
    echo "=== VXLAN Traffic Statistics ==="

    for vxlan in $(ip -o link show type vxlan | cut -d: -f2 | tr -d ' '); do
        echo "  $vxlan:"
        ip -s link show $vxlan | grep -A 1 "RX:\|TX:" | \
            awk '/RX:/{rx=1; next} rx{print "    RX: " $0; rx=0} /TX:/{tx=1; next} tx{print "    TX: " $0; tx=0}'
    done
}

check_errors() {
    echo ""
    echo "=== Error Detection ==="

    errors_found=0

    for vxlan in $(ip -o link show type vxlan | cut -d: -f2 | tr -d ' '); do
        # 인터페이스 down 체크
        if ! ip link show $vxlan | grep -q "UP"; then
            echo -e "  ${RED}[ERROR]${NC} $vxlan is DOWN"
            errors_found=1
        fi

        # 에러 카운터 체크
        errors=$(ip -s link show $vxlan | grep "errors" | head -1 | awk '{print $3}')
        if [ "$errors" -gt 0 ]; then
            echo -e "  ${YELLOW}[WARNING]${NC} $vxlan has $errors errors"
            errors_found=1
        fi

        # 드롭 카운터 체크
        drops=$(ip -s link show $vxlan | grep "dropped" | head -1 | awk '{print $4}')
        if [ "$drops" -gt 100 ]; then
            echo -e "  ${YELLOW}[WARNING]${NC} $vxlan has $drops dropped packets"
            errors_found=1
        fi
    done

    if [ $errors_found -eq 0 ]; then
        echo -e "  ${GREEN}[OK]${NC} No errors detected"
    fi
}

check_mtu() {
    echo ""
    echo "=== MTU Configuration ==="

    for vxlan in $(ip -o link show type vxlan | cut -d: -f2 | tr -d ' '); do
        mtu=$(ip link show $vxlan | grep mtu | awk '{print $5}')
        echo "  $vxlan: MTU $mtu"

        if [ "$mtu" -lt 1450 ]; then
            echo -e "    ${YELLOW}[WARNING]${NC} MTU might be too small for VXLAN"
        fi
    done
}

# Main
main() {
    while true; do
        clear
        print_header
        check_vxlan_interfaces
        check_fdb
        check_evpn_status
        check_traffic
        check_errors
        check_mtu

        echo ""
        echo "Press Ctrl+C to stop. Refreshing in 10 seconds..."
        sleep 10
    done
}

# Ctrl+C 핸들러
trap 'echo ""; echo "Monitoring stopped."; exit 0' INT

main
```

**사용법:**

```bash
chmod +x vxlan_monitor.sh
sudo ./vxlan_monitor.sh
```

### 예제 4: OpenFlow Flow 최적화 스크립트

```python
#!/usr/bin/env python3
# flow_optimizer.py - OpenFlow Flow 테이블 최적화

import subprocess
import re
from collections import defaultdict

class FlowOptimizer:
    def __init__(self, bridge='br0'):
        self.bridge = bridge
        self.flows = []

    def fetch_flows(self):
        """OVS에서 flow 가져오기"""
        cmd = f"ovs-ofctl -O OpenFlow13 dump-flows {self.bridge}"
        output = subprocess.check_output(cmd.split()).decode()

        self.flows = []
        for line in output.strip().split('\n'):
            if 'cookie' in line:
                self.flows.append(line)

        return len(self.flows)

    def analyze_utilization(self):
        """Flow 사용률 분석"""
        print("\n=== Flow Utilization Analysis ===")

        total_flows = len(self.flows)
        active_flows = 0
        idle_flows = []

        for flow in self.flows:
            # n_packets 추출
            match = re.search(r'n_packets=(\d+)', flow)
            if match:
                packets = int(match.group(1))
                if packets > 0:
                    active_flows += 1
                else:
                    idle_flows.append(flow)

        print(f"Total Flows: {total_flows}")
        print(f"Active Flows: {active_flows} ({active_flows/total_flows*100:.1f}%)")
        print(f"Idle Flows: {len(idle_flows)} ({len(idle_flows)/total_flows*100:.1f}%)")

        return idle_flows

    def find_overlapping_flows(self):
        """중복/중첩 flow 찾기"""
        print("\n=== Overlapping Flow Detection ===")

        matches = defaultdict(list)

        for flow in self.flows:
            # match 필드 추출
            if 'priority=' in flow:
                match_str = re.search(r'priority=\d+,(.+?)\s+actions=', flow)
                if match_str:
                    match_fields = match_str.group(1)
                    matches[match_fields].append(flow)

        overlaps = {k: v for k, v in matches.items() if len(v) > 1}

        if overlaps:
            print(f"Found {len(overlaps)} overlapping match patterns:")
            for match, flows in list(overlaps.items())[:5]:
                print(f"\n  Match: {match}")
                print(f"  Count: {len(flows)} flows")
        else:
            print("No overlapping flows detected.")

    def suggest_aggregation(self):
        """Flow 집계 제안"""
        print("\n=== Flow Aggregation Suggestions ===")

        # IP prefix별로 그룹화
        ip_flows = defaultdict(list)

        for flow in self.flows:
            # nw_dst 추출
            match = re.search(r'nw_dst=([\d.]+/\d+)', flow)
            if match:
                prefix = match.group(1)
                network = '.'.join(prefix.split('/')[0].split('.')[:3]) + '.0/24'
                ip_flows[network].append(prefix)

        aggregation_candidates = {k: v for k, v in ip_flows.items() if len(v) > 3}

        if aggregation_candidates:
            print("Networks with multiple specific flows (aggregation candidates):")
            for network, prefixes in list(aggregation_candidates.items())[:5]:
                print(f"\n  {network}:")
                print(f"    {len(prefixes)} specific flows can be aggregated")
                print(f"    Examples: {', '.join(prefixes[:3])}")
        else:
            print("No obvious aggregation opportunities found.")

    def check_timeouts(self):
        """Timeout 설정 분석"""
        print("\n=== Timeout Analysis ===")

        idle_timeouts = []
        hard_timeouts = []
        no_timeout = 0

        for flow in self.flows:
            idle_match = re.search(r'idle_timeout=(\d+)', flow)
            hard_match = re.search(r'hard_timeout=(\d+)', flow)

            if idle_match:
                idle_timeouts.append(int(idle_match.group(1)))
            else:
                no_timeout += 1

            if hard_match:
                hard_timeouts.append(int(hard_match.group(1)))

        if idle_timeouts:
            print(f"Flows with idle_timeout: {len(idle_timeouts)}")
            print(f"  Average: {sum(idle_timeouts)/len(idle_timeouts):.0f}s")
            print(f"  Range: {min(idle_timeouts)}-{max(idle_timeouts)}s")

        if hard_timeouts:
            print(f"Flows with hard_timeout: {len(hard_timeouts)}")
            print(f"  Average: {sum(hard_timeouts)/len(hard_timeouts):.0f}s")

        if no_timeout > 0:
            print(f"Permanent flows (no timeout): {no_timeout}")

    def generate_report(self):
        """최적화 리포트 생성"""
        print("\n" + "="*60)
        print("OpenFlow Flow Optimization Report")
        print(f"Bridge: {self.bridge}")
        print("="*60)

        flow_count = self.fetch_flows()
        if flow_count == 0:
            print("No flows found.")
            return

        idle_flows = self.analyze_utilization()
        self.find_overlapping_flows()
        self.suggest_aggregation()
        self.check_timeouts()

        # 최적화 제안
        print("\n=== Optimization Recommendations ===")

        if len(idle_flows) > flow_count * 0.2:
            print("• Consider reducing idle_timeout to remove unused flows faster")

        print("• Review overlapping flows and merge if possible")
        print("• Consider aggregating flows with similar match patterns")
        print("• Use flow priority carefully to avoid conflicts")

        print("\n" + "="*60)

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='OpenFlow Flow Optimizer')
    parser.add_argument('--bridge', default='br0', help='OVS bridge name')
    args = parser.parse_args()

    optimizer = FlowOptimizer(bridge=args.bridge)
    optimizer.generate_report()
```

---

## 📚 참고 자료

### 공식 문서

**TCP/IP 및 혼잡 제어:**

- [BBR: Congestion-Based Congestion Control (ACM Queue)](https://queue.acm.org/detail.cfm?id=3022184)
- [IETF BBR Congestion Control Draft](https://www.ietf.org/archive/id/draft-cardwell-ccwg-bbr-00.html)
- [Google Cloud: TCP BBR Congestion Control](https://cloud.google.com/blog/products/networking/tcp-bbr-congestion-control-comes-to-gcp-your-internet-just-got-faster)
- [TCP Congestion Control Algorithms (F5 Networks)](https://techdocs.f5.com/en-us/bigip-14-1-0/big-ip-tcp-congestion-control-14-1-0/tcp-congestion-control-algorithms.html)

**BGP & OSPF:**

- [BGP Best Current Practices (NSRC, April 2025)](https://nsrc.org/workshops/2025/nsrc-pacnog35-pcio/networking/bgp-deploy/en/presentations/BGP-BCP.pdf)
- [Cisco IOS XR Deployment Best Practices for OSPF/IS-IS and BGP](https://www.cisco.com/c/en/us/support/docs/ios-nx-os-software/ios-xr-software/IOS-XR-Best-Practices/IOSXR-Deployment-BestPractices.html)
- [BGP vs OSPF: Complete Comparison 2025](https://www.nobgp.com/info/bgp-vs-ospf-vs-nobgp-private-networks)

**VXLAN & EVPN:**

- [Cisco Nexus 9000 VXLAN BGP EVPN Design Guide](https://www.cisco.com/c/en/us/td/docs/dcn/whitepapers/cisco-vxlan-bgp-evpn-design-and-implementation-guide.html)
- [Juniper: Understanding VXLANs](https://www.juniper.net/documentation/us/en/software/junos/evpn/topics/topic-map/sdn-vxlan.html)
- [Azure Local: VXLAN Overlay Networking (2025)](https://digitalthoughtdisruption.com/2025/07/07/overlay-networking-azure-local-vxlan/)

**SDN, OpenFlow, P4:**

- [Advancing SDN from OpenFlow to P4: A Survey (ACM)](https://dl.acm.org/doi/10.1145/3556973)
- [A Performance Evaluation for SDN with P4 (MDPI, June 2025)](https://www.mdpi.com/2673-8732/5/2/21)
- [P4 Language Specification](https://p4.org/p4-spec/docs/P4-16-v1.2.4.html)
- [OpenFlow Switch Specification](https://opennetworking.org/software-defined-standards/specifications/)

### 튜토리얼 및 가이드

**실습 자료:**

- [FRRouting Documentation](https://docs.frrouting.org/)
- [Open vSwitch Documentation](https://www.openvswitch.org/support/)
- [Ryu SDN Framework](https://ryu-sdn.org/)
- [P4 Tutorials (P4.org)](https://github.com/p4lang/tutorials)
- [Mininet Walkthrough](http://mininet.org/walkthrough/)

**온라인 강의:**

- [30+ VXLAN Online Courses for 2025 (Class Central)](https://www.classcentral.com/subject/vxlan)
- [NSRC Training: BGP/OSPF Best Practices](https://learn.nsrc.org/bgp/ospf_best_practices)

### 도서

- **TCP/IP Illustrated, Volume 1** - W. Richard Stevens
- **Routing TCP/IP, Volume 1 & 2** - Jeff Doyle
- **Computer Networking: A Top-Down Approach** - Kurose & Ross
- **SDN: Software Defined Networks** - Thomas D. Nadeau

### 블로그 및 아티클

- [Increase Linux Internet Speed with TCP BBR (nixCraft)](https://www.cyberciti.biz/cloud-computing/increase-your-linux-server-internet-speed-with-tcp-bbr-congestion-control/)
- [TCP BBR: Exploring TCP Congestion Control (Medium)](https://atoonk.medium.com/tcp-bbr-exploring-tcp-congestion-control-84c9c11dc3a9)
- [Dynamic Routing in NSX-T: OSPF, BGP (Digital Thought Disruption, 2025)](https://digitalthoughtdisruption.com/2025/07/11/nsx-t-dynamic-routing-ospf-bgp-redistribution/)
- [Can P4 Save Software-Defined Networking? (Net Automated)](https://sdn-lab.com/2017/10/24/can-p4-save-software-defined-networking/)

### 커뮤니티 및 포럼

- [NANOG (North American Network Operators' Group)](https://www.nanog.org/)
- [P4 Community](https://p4.org/community/)
- [OpenFlow Reddit](https://www.reddit.com/r/openflow/)
- [FRRouting Slack](https://frrouting.org/)

---

## ✅ 학습 체크리스트

### TCP/IP 및 혼잡 제어

- [ ] TCP/IP 4계층 구조 이해 및 설명 가능
- [ ] BBR 혼잡 제어 알고리즘의 동작 원리 이해
- [ ] BBRv1, BBRv2, BBRv3의 차이점 설명 가능
- [ ] Linux에서 BBR 활성화 및 성능 측정 경험
- [ ] Loss-based vs Delay-based 혼잡 제어 비교 가능
- [ ] TCP 성능 튜닝 파라미터 이해 및 적용 경험

### 라우팅 프로토콜

- [ ] OSPF의 Link State 라우팅 원리 이해
- [ ] OSPF Area 설계 및 구현 경험
- [ ] BGP Path Selection 프로세스 완전 이해
- [ ] eBGP vs iBGP 차이점 및 사용 시나리오 설명 가능
- [ ] BGP 정책 (Route Map, Prefix List) 구현 경험
- [ ] BGP와 OSPF의 적절한 선택 기준 이해
- [ ] 2025 Best Practices (IGP/EGP 재분배 금지 등) 숙지

### VXLAN 네트워크 가상화

- [ ] VLAN의 한계와 VXLAN의 필요성 이해
- [ ] VXLAN 캡슐화 헤더 구조 설명 가능
- [ ] VTEP 동작 원리 및 역할 이해
- [ ] Multicast vs EVPN 제어 평면 비교 가능
- [ ] Linux에서 VXLAN 인터페이스 생성 및 설정 경험
- [ ] BGP EVPN 설정 및 운영 경험
- [ ] VXLAN 성능 최적화 (MTU, 오프로드) 경험

### SDN (Software Defined Networking)

- [ ] SDN 3계층 아키텍처 이해
- [ ] OpenFlow 프로토콜의 동작 원리 이해
- [ ] OpenFlow Flow Entry 구조 설명 가능
- [ ] Ryu 또는 다른 SDN 컨트롤러 사용 경험
- [ ] Open vSwitch 설정 및 관리 경험
- [ ] P4 언어의 기본 문법 이해
- [ ] OpenFlow vs P4의 차이점 및 장단점 비교 가능
- [ ] SDN 사용 사례 및 실무 적용 가능성 평가 능력

### 종합 역량

- [ ] 대규모 클라우드 환경의 네트워크 아키텍처 설계 가능
- [ ] 성능, 확장성, 가용성을 고려한 프로토콜 선택 가능
- [ ] 네트워크 문제 진단 및 트러블슈팅 경험
- [ ] 네트워크 모니터링 및 성능 분석 도구 활용 경험
- [ ] 자동화 스크립트를 통한 네트워크 운영 효율화 경험

---

## 🎓 다음 단계

Ch1. 네트워크 프로토콜을 완료했다면, 다음 학습 주제로 진행하세요:

**Ch2. API 설계**

- RESTful API 설계 원칙
- gRPC 및 성능 비교
- API Gateway 패턴
- API 버저닝 전략
- 성능 최적화 및 캐싱

**또는 심화 학습:**

- **네트워크 자동화**: Ansible, Nornir, Netmiko
- **고급 BGP**: BGP Communities, AS-Path Filtering, Route Reflection
- **멀티테넌트 네트워킹**: VRF, MPLS L3VPN
- **네트워크 보안**: ACL, 방화벽 정책, DDoS 방어
- **Service Mesh**: Istio, Linkerd (Ch7에서 다룸)

**실무 프로젝트 아이디어:**

1. **VXLAN EVPN 데이터센터 패브릭 구축**
   - 3-Tier (Spine-Leaf) 토폴로지 설계
   - BGP EVPN으로 L2/L3 서비스 제공
   - 모니터링 및 자동화 구현

2. **SDN 기반 트래픽 엔지니어링**
   - Ryu 컨트롤러로 동적 경로 제어
   - QoS 정책 구현
   - 장애 자동 감지 및 우회

3. **네트워크 성능 분석 플랫폼**
   - BBR vs CUBIC 성능 비교 자동화
   - 실시간 대시보드 (Grafana + Prometheus)
   - 알람 및 리포팅 기능

계속해서 학습하고 실습하면서 클라우드 네트워킹 전문가로 성장하세요!
