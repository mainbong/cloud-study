# Ch4. 네트워크 가상화

## 📋 개요

네트워크 가상화는 물리적 네트워크 장비의 기능을 소프트웨어로 구현하여 유연성, 확장성, 비용 효율성을 제공합니다. NFV (Network Functions Virtualization)와 SDN (Software-Defined Networking)은 현대 클라우드 네트워킹의 핵심 기술로, 통신 사업자와 엔터프라이즈 모두에게 혁신적인 네트워크 관리 방식을 제공합니다.

2025년 현재, ETSI NFV Release 5는 6G 네트워크 지원과 AI 기반 자율 네트워크 오케스트레이션을 도입했으며, CNF (Container Network Functions)가 기존 VNF를 대체하는 추세입니다. SDN 컨트롤러는 성능과 확장성이 크게 개선되어 대규모 프로덕션 환경에서 안정적으로 운영되고 있습니다.

이 챕터에서는 NFV/SDN 아키텍처, VNF 오케스트레이션, Service Function Chaining, 그리고 주요 SDN 컨트롤러 비교까지 네트워크 가상화의 모든 측면을 다룹니다.

---

## 🎯 학습 목표

이 챕터를 완료하면 다음을 할 수 있습니다:

- NFV와 SDN의 차이점 및 상호 보완성 이해
- ETSI MANO 아키텍처 및 2025 업데이트 파악
- VNF vs CNF 비교 및 마이그레이션 전략 수립
- Service Function Chaining (SFC) 설계 및 구현
- SDN 컨트롤러 (OpenDaylight, ONOS, Ryu) 선택 및 배포
- NFV 오케스트레이션 도구 활용

---

## Part 1: NFV (Network Functions Virtualization)

### 1-1. NFV 개요

**NFV란?**

NFV는 라우터, 방화벽, 로드 밸런서 등의 네트워크 기능을 전용 하드웨어 대신 소프트웨어로 구현하여 상용 서버에서 실행하는 기술입니다.

**전통적인 네트워크 vs NFV:**

```
전통적인 네트워크:
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  전용 방화벽 │  │  전용 라우터 │  │  전용 LB    │
│  (하드웨어)  │→│  (하드웨어)  │→│  (하드웨어)  │
│  $50,000    │  │  $100,000   │  │  $30,000    │
└─────────────┘  └─────────────┘  └─────────────┘

문제점:
- 높은 CAPEX (자본 지출)
- 긴 배포 시간 (주/월 단위)
- 확장성 제한
- 벤더 종속


NFV 네트워크:
┌────────────────────────────────────────────┐
│        상용 서버 (x86/ARM)                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │vFirewall │  │ vRouter  │  │   vLB    │ │
│  │   (VM)   │→ │   (VM)   │→ │   (VM)   │ │
│  └──────────┘  └──────────┘  └──────────┘ │
│        Hypervisor (KVM, ESXi)              │
└────────────────────────────────────────────┘

장점:
✓ 낮은 CAPEX (1/5~1/10 수준)
✓ 빠른 배포 (분/시간 단위)
✓ 탄력적 확장
✓ 멀티 벤더 지원
✓ 자동화 가능
```

**NFV 사용 사례:**

- **Telco (통신 사업자)**:
  - vEPC (Virtual Evolved Packet Core)
  - vIMS (Virtual IP Multimedia Subsystem)
  - vCPE (Virtual Customer Premises Equipment)

- **Enterprise**:
  - Virtual Firewall
  - Virtual Load Balancer
  - Virtual WAN Optimizer

### 1-2. ETSI MANO 아키텍처

**ETSI (European Telecommunications Standards Institute)**는 NFV의 표준을 정의하며, MANO (Management and Orchestration)는 NFV 관리 프레임워크입니다.

**ETSI NFV-MANO 아키텍처 (2025):**

```
┌────────────────────────────────────────────────────────────┐
│                      OSS/BSS                               │
│         (운영 지원 시스템 / 비즈니스 지원 시스템)            │
└────────────────────────┬───────────────────────────────────┘
                         │ Or-Or (Orchestration)
┌────────────────────────▼───────────────────────────────────┐
│              NFV Orchestrator (NFVO)                       │
│  - Network Service Lifecycle Management                   │
│  - VNF Package Onboarding                                 │
│  - Resource Orchestration                                 │
│  - 2025: AI-driven Autonomous Orchestration (Release 5)   │
└─────────┬──────────────────────────────────┬───────────────┘
          │ Or-Vnfm                          │ Or-Vi
          │                                  │
┌─────────▼──────────────┐        ┌──────────▼──────────────┐
│  VNF Manager (VNFM)    │        │ VIM (Virtualized        │
│  - VNF Lifecycle Mgmt  │        │ Infrastructure Manager) │
│  - VNF Configuration   │        │ - Compute/Storage/Net   │
│  - Fault Management    │        │ - Resource Management   │
│  - 2025: Intent-based  │        │ - 2025: Multi-VIM       │
└─────────┬──────────────┘        └──────────┬──────────────┘
          │ Ve-Vnfm                          │ Vi-Vnfm
          │                                  │
┌─────────▼──────────────────────────────────▼───────────────┐
│              NFVI (NFV Infrastructure)                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Virtual Compute (VMs/Containers)           │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │           Virtual Storage (Block/Object)             │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │           Virtual Network (Neutron/OVN)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │      Hardware Resources (Compute/Storage/Network)    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**핵심 컴포넌트:**

**1. NFVO (NFV Orchestrator):**

- 네트워크 서비스 전체 생명주기 관리
- VNF 온보딩 및 카탈로그 관리
- 리소스 오케스트레이션 (VIM 조율)
- 서비스 체이닝 (SFC) 관리

**2. VNFM (VNF Manager):**

- 개별 VNF 생명주기 관리:
  - Instantiation (인스턴스화)
  - Scaling (확장/축소)
  - Healing (자동 복구)
  - Termination (종료)
- VNF 설정 관리
- 성능/장애 모니터링

**3. VIM (Virtualized Infrastructure Manager):**

- 가상 인프라 리소스 관리
- 주요 구현체:
  - OpenStack (가장 널리 사용)
  - VMware vCloud Director
  - Kubernetes (CNF용)

**2025 NFV Release 5 주요 업데이트:**

- **AI 기반 자율 오케스트레이션**: 자동화된 VNF 배치, 스케일링
- **6G 네트워크 지원**: Telco Cloud 아키텍처
- **Intent-based Management**: 선언적 정책 기반 관리
- **Certificate Management Function (CMF)**: 보안 강화
- **Multi-VIM 지원**: 여러 클라우드 동시 관리

### 1-3. VNF (Virtual Network Function)

**VNF 아키텍처:**

```
┌──────────────────────────────────────────────────────────┐
│                    VNF Package                           │
│  ┌────────────────────────────────────────────────────┐  │
│  │  VNF Descriptor (VNFD)                             │  │
│  │  - VNF 메타데이터                                   │  │
│  │  - VNFC (VNF Component) 정의                       │  │
│  │  - Virtual Link 정의                               │  │
│  │  - 리소스 요구사항 (vCPU, Memory, Disk)            │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  VM Images / Container Images                      │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │  Configuration Scripts                             │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘

배포 후:
┌──────────────────────────────────────────────────────────┐
│                   VNF Instance                           │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐           │
│  │  VNFC 1   │  │  VNFC 2   │  │  VNFC 3   │           │
│  │  (VM/Pod) │─→│  (VM/Pod) │─→│  (VM/Pod) │           │
│  └───────────┘  └───────────┘  └───────────┘           │
│       ↑              ↑              ↑                    │
│       └──────────────┴──────────────┘                    │
│           Virtual Network Links                         │
└──────────────────────────────────────────────────────────┘
```

**VNF Descriptor (VNFD) 예제 (TOSCA):**

```yaml
tosca_definitions_version: tosca_simple_yaml_1_2

description: Virtual Firewall VNF

metadata:
  template_name: vFirewall
  template_version: 1.0.0
  vendor: Example Corp

topology_template:
  node_templates:
    VNF:
      type: tosca.nodes.nfv.VNF
      properties:
        descriptor_id: vfirewall-1.0
        descriptor_version: 1.0.0
        provider: Example Corp
        product_name: Virtual Firewall
        software_version: 2.5.0
        vnfm_info:
          - Tacker

    VNFC_Firewall:
      type: tosca.nodes.nfv.Vdu.Compute
      properties:
        name: firewall-instance
        description: Firewall VM
        vdu_profile:
          min_number_of_instances: 1
          max_number_of_instances: 5
      capabilities:
        virtual_compute:
          properties:
            virtual_memory:
              virtual_mem_size: 4 GB
            virtual_cpu:
              num_virtual_cpu: 2
            virtual_local_storage:
              - size_of_storage: 40 GB

    CP_external:
      type: tosca.nodes.nfv.VduCp
      properties:
        order: 0
        vnic_type: normal
      requirements:
        - virtual_binding: VNFC_Firewall
        - virtual_link: VL_external

    CP_internal:
      type: tosca.nodes.nfv.VduCp
      properties:
        order: 1
        vnic_type: normal
      requirements:
        - virtual_binding: VNFC_Firewall
        - virtual_link: VL_internal

    VL_external:
      type: tosca.nodes.nfv.VnfVirtualLink
      properties:
        connectivity_type:
          layer_protocols:
            - ipv4

    VL_internal:
      type: tosca.nodes.nfv.VnfVirtualLink
      properties:
        connectivity_type:
          layer_protocols:
            - ipv4

  policies:
    - scaling_aspects:
        type: tosca.policies.nfv.ScalingAspects
        properties:
          aspects:
            firewall_scale:
              name: Firewall Scaling
              description: Scale firewall instances
              max_scale_level: 4
              step_deltas:
                - delta_1

    - firewall_scale_delta:
        type: tosca.policies.nfv.VduScalingAspectDeltas
        properties:
          aspect: firewall_scale
          deltas:
            delta_1:
              number_of_instances: 1
        targets: [ VNFC_Firewall ]
```

### 1-4. VNF vs CNF

**2025 트렌드: VNF에서 CNF로 전환**

```
VNF (Virtual Network Function):
┌────────────────────────────────┐
│         VM-based VNF           │
│  ┌──────────────────────────┐  │
│  │   Application            │  │
│  ├──────────────────────────┤  │
│  │   Guest OS (Linux)       │  │  부팅 시간: 2-5분
│  └──────────────────────────┘  │  메모리: 2-8 GB
│         Hypervisor             │  디스크: 20-100 GB
└────────────────────────────────┘

CNF (Container Network Function):
┌────────────────────────────────┐
│      Container-based CNF       │
│  ┌──────────────────────────┐  │
│  │   Application            │  │  부팅 시간: 1-10초
│  └──────────────────────────┘  │  메모리: 100-500 MB
│     Container Runtime          │  디스크: 100-500 MB
│     (containerd/CRI-O)         │
│  Host OS (Linux)               │
└────────────────────────────────┘
```

**VNF vs CNF 비교표:**

| 특성 | VNF | CNF |
|------|-----|-----|
| **배포 속도** | 느림 (분 단위) | 빠름 (초 단위) |
| **리소스 효율** | 낮음 | 높음 (10배 이상) |
| **확장성** | 제한적 | 매우 높음 |
| **오케스트레이터** | OpenStack | Kubernetes |
| **관리 복잡도** | 높음 | 중간 |
| **성능** | 좋음 | 우수 |
| **성숙도** | 매우 높음 | 높음 (성장 중) |
| **마이그레이션** | 어려움 | 쉬움 |

**VNF to CNF 마이그레이션 전략:**

```
Phase 1: 평가 (1-2개월)
├─ 현재 VNF 인벤토리 조사
├─ CNF 호환성 분석
├─ ROI 계산
└─ 우선순위 결정

Phase 2: Stateless VNF 우선 전환 (3-6개월)
├─ vRouter → CNF Router
├─ vLoad Balancer → CNF LB
└─ vDNS → CNF DNS

Phase 3: Stateful VNF 전환 (6-12개월)
├─ vFirewall → CNF Firewall
├─ vNAT → CNF NAT
└─ 데이터 마이그레이션 전략

Phase 4: Legacy VNF 유지/공존 (진행 중)
├─ CNF와 VNF 하이브리드 운영
└─ 점진적 VNF 폐기
```

---

## Part 2: SDN (Software-Defined Networking)

### 2-1. SDN 아키텍처 (복습 및 심화)

**NFV와 SDN의 관계:**

```
┌─────────────────────────────────────────────────────────┐
│                    OSS/BSS                              │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│            NFV Orchestrator (NFVO)                      │
│         - VNF 배치, Service Chaining                    │
└────────┬───────────────────────────────────┬────────────┘
         │                                   │
┌────────▼─────────┐              ┌──────────▼────────────┐
│  VNF Manager     │              │   SDN Controller      │
│  (VNFM)          │◄─────────────┤  (ONOS/ODL/Ryu)       │
│                  │  VNF-SDN     │                       │
│  - VNF 관리      │  Coordination │  - Flow 관리         │
└────────┬─────────┘              └──────────┬────────────┘
         │                                   │
         │ VNF Control                       │ OpenFlow/P4
┌────────▼───────────────────────────────────▼────────────┐
│              Data Plane (OVS, Hardware Switches)        │
└─────────────────────────────────────────────────────────┘

역할 분리:
- NFV: "무엇을" (Which VNF to deploy, where)
- SDN: "어떻게" (How to route traffic)
```

### 2-2. 주요 SDN 컨트롤러 비교 (2025)

**OpenDaylight (ODL):**

```
특징:
- Java 기반 모듈러 플랫폼
- Linux Foundation Networking 프로젝트
- 가장 큰 커뮤니티
- 엔터프라이즈 및 Service Provider 네트워크 중심

아키텍처:
┌──────────────────────────────────────────┐
│        Northbound APIs (REST)            │
├──────────────────────────────────────────┤
│  Service Abstraction Layer (SAL)         │
├──────────────────────────────────────────┤
│  Plugins (OpenFlow, NETCONF, BGP, ...)   │
├──────────────────────────────────────────┤
│  Controller Core (MD-SAL)                │
└──────────────────────────────────────────┘

장점:
✓ 매우 풍부한 기능 (50+ 프로젝트)
✓ 엔터프라이즈급 안정성
✓ 최고의 보안성
✓ 멀티 프로토콜 지원

단점:
✗ 복잡한 설정
✗ 무거움 (Java)
✗ 학습 곡선 높음
```

**ONOS (Open Network Operating System):**

```
특징:
- Java 기반 분산 SDN OS
- Service Provider 네트워크 중심
- "Brown Field" → "Green Field" 전환 지원

아키텍처:
┌──────────────────────────────────────────┐
│     Applications (Routing, FWD, ...)     │
├──────────────────────────────────────────┤
│  Northbound APIs (REST, gRPC)            │
├──────────────────────────────────────────┤
│  Distributed Core (Atomix/Raft)          │
│  - Topology, Host, Flow, Intent Services │
├──────────────────────────────────────────┤
│  Southbound (OpenFlow, P4, gNMI)         │
└──────────────────────────────────────────┘

장점:
✓ 분산 아키텍처 (HA 기본)
✓ 높은 처리량 (79.2 Mbits 벤치마크)
✓ 낮은 지터 (0.022 ms)
✓ Service Provider 최적화

단점:
✗ ODL보다 적은 플러그인
✗ 엔터프라이즈 기능 부족
```

**Ryu:**

```
특징:
- Python 기반 경량 컨트롤러
- "도구 상자" 접근법
- 연구 및 프로토타이핑 최적

아키텍처:
┌──────────────────────────────────────────┐
│   Ryu Applications (Python 앱)           │
├──────────────────────────────────────────┤
│  Ryu Libraries (OpenFlow, OVSDB, ...)    │
├──────────────────────────────────────────┤
│  Ryu Base (Event-driven Framework)       │
└──────────────────────────────────────────┘

장점:
✓ 매우 가벼움
✓ 최저 지연시간 (벤치마크 1위)
✓ Python - 쉬운 개발
✓ 빠른 프로토타이핑

단점:
✗ 단일 노드 (분산 X)
✗ 프로덕션 기능 부족
✗ 작은 커뮤니티
```

**2025 성능 벤치마크 비교:**

```
처리량 (Throughput):
ONOS:  79.2 Mbits/sec   ⭐⭐⭐⭐⭐
ODL:   65.3 Mbits/sec   ⭐⭐⭐⭐
Ryu:   최고 (연구에서)   ⭐⭐⭐⭐⭐

지연시간 (Latency):
Ryu:   최저             ⭐⭐⭐⭐⭐
ONOS:  0.117 ms         ⭐⭐⭐⭐⭐
ODL:   중간             ⭐⭐⭐⭐

지터 (Jitter):
ONOS:  0.022 ms         ⭐⭐⭐⭐⭐
ODL:   약간 높음         ⭐⭐⭐⭐
Ryu:   낮음             ⭐⭐⭐⭐⭐

보안:
ODL:   최고             ⭐⭐⭐⭐⭐
ONOS:  우수             ⭐⭐⭐⭐
Ryu:   기본             ⭐⭐⭐

확장성:
ONOS:  분산 (최고)       ⭐⭐⭐⭐⭐
ODL:   클러스터 지원     ⭐⭐⭐⭐
Ryu:   단일 노드         ⭐⭐

커뮤니티:
ODL:   가장 큼          ⭐⭐⭐⭐⭐
ONOS:  중간             ⭐⭐⭐⭐
Ryu:   작음             ⭐⭐
```

**선택 가이드:**

- **OpenDaylight**: 대규모 엔터프라이즈, 멀티 프로토콜, 최고 보안 필요
- **ONOS**: Service Provider, 분산 환경, 높은 처리량 필요
- **Ryu**: 연구, 프로토타이핑, 빠른 개발 필요

### 2-3. OpenDaylight 설치 및 설정

**Docker로 빠른 설치:**

```bash
# OpenDaylight 컨테이너 실행
docker run -d \
  --name opendaylight \
  -p 8181:8181 \
  -p 8101:8101 \
  -p 6633:6633 \
  opendaylight/opendaylight:latest

# Web UI 접속
# http://localhost:8181/index.html
# Username: admin
# Password: admin

# REST API 테스트
curl -u admin:admin \
  http://localhost:8181/restconf/operational/network-topology:network-topology

# Karaf CLI 접속
ssh -p 8101 karaf@localhost
# Password: karaf
```

**Feature 설치:**

```bash
# Karaf CLI에서
feature:install odl-restconf
feature:install odl-l2switch-switch
feature:install odl-mdsal-apidocs
feature:install odl-dlux-all
feature:install odl-openflowplugin-all

# Feature 목록 확인
feature:list | grep odl
```

**OpenFlow 스위치 연결:**

```bash
# OVS를 ODL에 연결
ovs-vsctl set-controller br0 tcp:localhost:6633

# 연결 확인
ovs-vsctl show

# ODL에서 스위치 확인 (REST API)
curl -u admin:admin \
  http://localhost:8181/restconf/operational/opendaylight-inventory:nodes | jq
```

**Flow 추가 (REST API):**

```bash
# Flow 추가 요청
curl -u admin:admin \
  -H "Content-Type: application/json" \
  -X PUT \
  http://localhost:8181/restconf/config/opendaylight-inventory:nodes/node/openflow:1/table/0/flow/1 \
  -d '{
    "flow": [{
      "id": "1",
      "table_id": 0,
      "priority": 100,
      "match": {
        "ethernet-match": {
          "ethernet-type": {
            "type": 2048
          }
        },
        "ipv4-destination": "192.168.1.0/24"
      },
      "instructions": {
        "instruction": [{
          "order": 0,
          "apply-actions": {
            "action": [{
              "order": 0,
              "output-action": {
                "output-node-connector": "2"
              }
            }]
          }
        }]
      }
    }]
  }'
```

### 2-4. ONOS 설치 및 설정

**Docker Compose로 설치:**

```yaml
# docker-compose.yml
version: '3'
services:
  onos:
    image: onosproject/onos:latest
    container_name: onos
    ports:
      - "8181:8181"   # REST API
      - "8101:8101"   # SSH CLI
      - "6653:6653"   # OpenFlow
      - "9876:9876"   # gRPC
    environment:
      - ONOS_APPS=drivers,openflow,fwd,proxyarp
```

```bash
# 실행
docker-compose up -d

# Web UI 접속
# http://localhost:8181/onos/ui
# Username: onos
# Password: rocks

# CLI 접속
ssh -p 8101 onos@localhost
# Password: rocks
```

**ONOS CLI 명령어:**

```bash
# 애플리케이션 활성화
onos> app activate org.onosproject.openflow
onos> app activate org.onosproject.fwd

# 디바이스 확인
onos> devices

# 링크 확인
onos> links

# Flow 확인
onos> flows

# 호스트 확인
onos> hosts

# Intent 생성 (선언적 트래픽 정책)
onos> add-host-intent <host1> <host2>

# Topology 요약
onos> summary
```

**ONOS REST API:**

```bash
# 디바이스 목록
curl -u onos:rocks \
  http://localhost:8181/onos/v1/devices | jq

# Flow 추가
curl -u onos:rocks \
  -H "Content-Type: application/json" \
  -X POST \
  http://localhost:8181/onos/v1/flows \
  -d '{
    "deviceId": "of:0000000000000001",
    "treatment": {
      "instructions": [{
        "type": "OUTPUT",
        "port": "2"
      }]
    },
    "selector": {
      "criteria": [{
        "type": "ETH_DST",
        "mac": "00:00:00:00:00:01"
      }]
    },
    "priority": 100
  }'
```

---

## Part 3: Service Function Chaining (SFC)

### 3-1. SFC 개요

**Service Function Chaining이란?**

SFC는 여러 네트워크 기능(Firewall, IDS, NAT, Load Balancer 등)을 논리적인 체인으로 연결하여 트래픽을 순차적으로 처리하는 기술입니다.

**전통적인 방식 vs SFC:**

```
전통적인 방식 (고정 경로):
Client → Router → Firewall → IDS → NAT → Load Balancer → Server

문제점:
- 고정된 경로
- 물리적 배선 필요
- 변경 어려움
- 확장성 제한


SFC (동적 체인):
         ┌────────────────────────────┐
         │    SDN Controller          │
         │  + NFV Orchestrator        │
         └─────────┬──────────────────┘
                   │ (동적 체인 생성)
                   ▼
Client → [Chain 1: FW → IDS → LB] → Server (HTTP)
Client → [Chain 2: FW → NAT] → Internet (일반)
Client → [Chain 3: FW → DPI → IPS → LB] → Server (중요)

장점:
✓ 동적 체인 생성/수정
✓ 서비스별 맞춤 체인
✓ 트래픽 분류 기반 자동 라우팅
✓ VNF 배치 최적화
```

**SFC 아키텍처 (IETF RFC 7665):**

```
┌─────────────────────────────────────────────────────────┐
│           Service Function Chaining (SFC)               │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Classifier (트래픽 분류기)                       │  │
│  │  - HTTP → Chain A                                │  │
│  │  - HTTPS → Chain B                               │  │
│  │  - SSH → Chain C                                 │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                     │
│  ┌────────────────▼─────────────────────────────────┐  │
│  │  Service Function Path (SFP)                     │  │
│  │                                                   │  │
│  │  Chain A: SF1 (Firewall) → SF2 (IDS) → SF3 (LB) │  │
│  │  Chain B: SF1 (Firewall) → SF4 (DPI) → SF3 (LB) │  │
│  │  Chain C: SF1 (Firewall) → SF5 (NAT)            │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                     │
│  ┌────────────────▼─────────────────────────────────┐  │
│  │  Service Functions (SFs)                         │  │
│  │  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐        │  │
│  │  │ FW │  │IDS │  │ LB │  │DPI │  │NAT │        │  │
│  │  └────┘  └────┘  └────┘  └────┘  └────┘        │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 3-2. SFC 구현 (OpenStack Tacker + Networking-SFC)

**OpenStack Networking-SFC 설치:**

```bash
# 컨트롤러 노드
apt-get install python3-networking-sfc

# Neutron 설정 업데이트
cat >> /etc/neutron/neutron.conf <<EOF
[DEFAULT]
service_plugins = router,networking_sfc.services.sfc.plugin.SfcPlugin
EOF

# 데이터베이스 마이그레이션
neutron-db-manage \
  --subproject networking-sfc upgrade head

# Neutron 재시작
systemctl restart neutron-server
```

**SFC 생성 (CLI):**

```bash
# 1. Port Pair 생성 (VNF의 ingress/egress 포트)
openstack sfc port pair create \
  --ingress <firewall-ingress-port> \
  --egress <firewall-egress-port> \
  pp-firewall

openstack sfc port pair create \
  --ingress <ids-ingress-port> \
  --egress <ids-egress-port> \
  pp-ids

# 2. Port Pair Group 생성 (동일 기능의 VNF 그룹)
openstack sfc port pair group create \
  --port-pair pp-firewall \
  ppg-firewall

openstack sfc port pair group create \
  --port-pair pp-ids \
  ppg-ids

# 3. Flow Classifier 생성 (트래픽 매칭 규칙)
openstack sfc flow classifier create \
  --description "HTTP Traffic" \
  --protocol tcp \
  --source-ip-prefix 10.0.1.0/24 \
  --destination-ip-prefix 192.168.1.0/24 \
  --source-port 1024:65535 \
  --destination-port 80:80 \
  fc-http

# 4. Port Chain 생성 (Service Function Path)
openstack sfc port chain create \
  --port-pair-group ppg-firewall \
  --port-pair-group ppg-ids \
  --flow-classifier fc-http \
  pc-web-traffic
```

**SFC VNFD 예제 (Tacker):**

```yaml
# sfc-vnfd.yaml
tosca_definitions_version: tosca_simple_profile_for_nfv_1_0_0

description: SFC with Firewall and IDS

topology_template:
  node_templates:
    VNF_Firewall:
      type: tosca.nodes.nfv.VNF
      requirements:
        - virtualLink1: VL1
        - virtualLink2: VL2

    VNF_IDS:
      type: tosca.nodes.nfv.VNF
      requirements:
        - virtualLink1: VL2
        - virtualLink2: VL3

    VL1:
      type: tosca.nodes.nfv.VL
      properties:
        network_name: net_mgmt
        vendor: Tacker

    VL2:
      type: tosca.nodes.nfv.VL
      properties:
        network_name: net_chain
        vendor: Tacker

    VL3:
      type: tosca.nodes.nfv.VL
      properties:
        network_name: net_out
        vendor: Tacker

    Forwarding_path1:
      type: tosca.nodes.nfv.FP
      description: HTTP traffic chain
      properties:
        id: 1
        policy:
          type: ACL
          criteria:
            - network_src_port_id: <source-port>
            - destination_port_range: 80-80
            - ip_proto: 6  # TCP
        path:
          - forwarder: VNF_Firewall
            capability: CP1
          - forwarder: VNF_IDS
            capability: CP2
```

### 3-3. Dynamic SFC (AI 기반 오케스트레이션)

**2025 트렌드: 강화 학습 기반 동적 SFC:**

```python
# dynamic_sfc_orchestrator.py (개념 코드)
import gym
import numpy as np
from stable_baselines3 import PPO

class SFCEnvironment(gym.Env):
    """SFC 배치 최적화를 위한 RL 환경"""

    def __init__(self, network_topology, vnf_catalog):
        super(SFCEnvironment, self).__init__()
        self.topology = network_topology
        self.vnf_catalog = vnf_catalog

        # Action: (VNF type, Node placement)
        self.action_space = gym.spaces.MultiDiscrete([
            len(vnf_catalog),  # VNF 선택
            len(network_topology.nodes)  # 노드 선택
        ])

        # State: Network 상태 (CPU, Mem, BW, Latency)
        self.observation_space = gym.spaces.Box(
            low=0, high=1, shape=(100,), dtype=np.float32
        )

    def step(self, action):
        """VNF 배치 및 보상 계산"""
        vnf_type, node_id = action

        # VNF 배치
        placement_cost = self._place_vnf(vnf_type, node_id)
        latency = self._calculate_latency()
        throughput = self._calculate_throughput()

        # 보상 함수
        reward = (
            -placement_cost * 0.3
            -latency * 0.4
            +throughput * 0.3
        )

        # 다음 상태
        next_state = self._get_state()
        done = self._is_chain_complete()

        return next_state, reward, done, {}

    def _place_vnf(self, vnf_type, node_id):
        """VNF 배치 및 비용 계산"""
        vnf = self.vnf_catalog[vnf_type]
        node = self.topology.nodes[node_id]

        # 리소스 체크
        if node.available_cpu < vnf.cpu_req:
            return float('inf')  # 불가능한 배치

        # 배치 수행
        node.available_cpu -= vnf.cpu_req
        node.available_mem -= vnf.mem_req

        return vnf.cpu_req + vnf.mem_req

    def _calculate_latency(self):
        """체인 전체 지연시간 계산"""
        total_latency = 0
        for i in range(len(self.chain) - 1):
            src = self.chain[i].node_id
            dst = self.chain[i+1].node_id
            total_latency += self.topology.get_latency(src, dst)
        return total_latency

    def _calculate_throughput(self):
        """체인 처리량 계산"""
        # 가장 느린 VNF가 병목
        return min(vnf.throughput for vnf in self.chain)

# 학습
env = SFCEnvironment(network_topology, vnf_catalog)
model = PPO("MlpPolicy", env, verbose=1)
model.learn(total_timesteps=100000)

# 추론 (최적 SFC 생성)
obs = env.reset()
for _ in range(chain_length):
    action, _states = model.predict(obs)
    obs, reward, done, info = env.step(action)
    if done:
        break

print(f"Optimized SFC: {env.chain}")
print(f"Total Latency: {env._calculate_latency()} ms")
print(f"Throughput: {env._calculate_throughput()} Mbps")
```

---

## 🛠️ 실습 가이드

### 실습 1: OpenStack Tacker로 VNF 배포

**목표**: 간단한 vRouter VNF 배포

**환경 준비:**

```bash
# Tacker 설치
apt-get install python3-tackerclient tacker

# Tacker 서비스 시작
systemctl start tacker
systemctl start tacker-conductor

# VIM 등록 (OpenStack)
tacker vim-register \
  --config-file /etc/tacker/vim-config.yaml \
  --description "OpenStack VIM" \
  openstack-vim
```

**VNFD 작성 (vrouter-vnfd.yaml):**

```yaml
tosca_definitions_version: tosca_simple_profile_for_nfv_1_0_0

description: Simple vRouter VNF

metadata:
  template_name: vRouter

topology_template:
  node_templates:
    VDU1:
      type: tosca.nodes.nfv.VDU.Tacker
      properties:
        image: ubuntu-20.04
        flavor: m1.small
        availability_zone: nova
        config: |
          #!/bin/bash
          apt-get update
          apt-get install -y quagga
          systemctl enable zebra
          systemctl start zebra

      capabilities:
        nfv_compute:
          properties:
            num_cpus: 2
            mem_size: 2 GB
            disk_size: 10 GB

    CP1:
      type: tosca.nodes.nfv.CP.Tacker
      properties:
        management: true
        order: 0
        anti_spoofing_protection: false
      requirements:
        - virtualLink:
            node: VL1
        - virtualBinding:
            node: VDU1

    CP2:
      type: tosca.nodes.nfv.CP.Tacker
      properties:
        order: 1
        anti_spoofing_protection: false
      requirements:
        - virtualLink:
            node: VL2
        - virtualBinding:
            node: VDU1

    VL1:
      type: tosca.nodes.nfv.VL
      properties:
        network_name: net_mgmt
        vendor: Tacker

    VL2:
      type: tosca.nodes.nfv.VL
      properties:
        network_name: net_data
        vendor: Tacker
```

**VNF 배포:**

```bash
# VNFD 등록
tacker vnfd-create --vnfd-file vrouter-vnfd.yaml vrouter-vnfd

# VNFD 목록 확인
tacker vnfd-list

# VNF 인스턴스화
tacker vnf-create --vnfd-name vrouter-vnfd my-vrouter

# VNF 상태 확인
tacker vnf-show my-vrouter

# VNF 목록
tacker vnf-list

# VNF 스케일 아웃 (VNFD에 스케일 정의 필요)
tacker vnf-scale --vnf-name my-vrouter \
  --scaling-policy-name SP1 \
  --scaling-type out

# VNF 삭제
tacker vnf-delete my-vrouter
```

### 실습 2: Ryu로 간단한 L2 학습 스위치 구현

**목표**: Ryu 컨트롤러로 OpenFlow 스위치 제어

```python
# l2_switch.py
from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet

class L2Switch(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(L2Switch, self).__init__(*args, **kwargs)
        self.mac_to_port = {}

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """스위치 연결 시 Table-miss Flow 설치"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                         ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)

        self.logger.info("Switch %s connected", datapath.id)

    def add_flow(self, datapath, priority, match, actions):
        """Flow Entry 추가"""
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS,
                                            actions)]
        mod = parser.OFPFlowMod(datapath=datapath, priority=priority,
                               match=match, instructions=inst,
                               idle_timeout=30, hard_timeout=60)
        datapath.send_msg(mod)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        """Packet-In 처리 (MAC 학습 및 포워딩)"""
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

        # MAC 학습
        self.mac_to_port.setdefault(dpid, {})
        self.logger.info("Packet in: dpid=%s src=%s dst=%s in_port=%s",
                        dpid, src, dst, in_port)

        self.mac_to_port[dpid][src] = in_port

        # 출력 포트 결정
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD

        actions = [parser.OFPActionOutput(out_port)]

        # Flow 설치 (Flooding이 아닌 경우)
        if out_port != ofproto.OFPP_FLOOD:
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst)
            self.add_flow(datapath, 1, match, actions)

        # Packet-Out
        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data

        out = parser.OFPPacketOut(datapath=datapath, buffer_id=msg.buffer_id,
                                 in_port=in_port, actions=actions, data=data)
        datapath.send_msg(out)
```

**실행:**

```bash
# Ryu 컨트롤러 시작
ryu-manager l2_switch.py --verbose

# 별도 터미널에서 Mininet 실행
sudo mn --controller=remote,ip=127.0.0.1 --mac --switch=ovsk,protocols=OpenFlow13

# Mininet CLI에서 테스트
mininet> pingall
mininet> h1 ping h2
mininet> iperf h1 h2
```

### 실습 3: Service Function Chaining 구축

**목표**: Firewall → IDS → Load Balancer 체인 구성

```bash
#!/bin/bash
# create-sfc.sh

set -e

echo "=== Creating Service Function Chain ==="

# 1. 네트워크 생성
NET_MGMT=$(openstack network create sfc-mgmt -f value -c id)
NET_IN=$(openstack network create sfc-input -f value -c id)
NET_CHAIN=$(openstack network create sfc-chain -f value -c id)
NET_OUT=$(openstack network create sfc-output -f value -c id)

# 2. 서브넷 생성
openstack subnet create --network $NET_MGMT --subnet-range 192.168.1.0/24 sfc-mgmt-subnet
openstack subnet create --network $NET_IN --subnet-range 10.0.1.0/24 sfc-input-subnet
openstack subnet create --network $NET_CHAIN --subnet-range 10.0.2.0/24 sfc-chain-subnet
openstack subnet create --network $NET_OUT --subnet-range 10.0.3.0/24 sfc-output-subnet

# 3. VNF 인스턴스 생성
# Firewall
FW_PORT_IN=$(openstack port create --network $NET_IN fw-port-in -f value -c id)
FW_PORT_OUT=$(openstack port create --network $NET_CHAIN fw-port-out -f value -c id)

openstack server create \
  --flavor m1.small \
  --image vnf-firewall \
  --port $FW_PORT_IN \
  --port $FW_PORT_OUT \
  vnf-firewall

# IDS
IDS_PORT_IN=$(openstack port create --network $NET_CHAIN ids-port-in -f value -c id)
IDS_PORT_OUT=$(openstack port create --network $NET_CHAIN ids-port-out -f value -c id)

openstack server create \
  --flavor m1.small \
  --image vnf-ids \
  --port $IDS_PORT_IN \
  --port $IDS_PORT_OUT \
  vnf-ids

# Load Balancer
LB_PORT_IN=$(openstack port create --network $NET_CHAIN lb-port-in -f value -c id)
LB_PORT_OUT=$(openstack port create --network $NET_OUT lb-port-out -f value -c id)

openstack server create \
  --flavor m1.small \
  --image vnf-lb \
  --port $LB_PORT_IN \
  --port $LB_PORT_OUT \
  vnf-lb

# 4. Port Pair 생성
openstack sfc port pair create --ingress $FW_PORT_IN --egress $FW_PORT_OUT pp-fw
openstack sfc port pair create --ingress $IDS_PORT_IN --egress $IDS_PORT_OUT pp-ids
openstack sfc port pair create --ingress $LB_PORT_IN --egress $LB_PORT_OUT pp-lb

# 5. Port Pair Group 생성
openstack sfc port pair group create --port-pair pp-fw ppg-fw
openstack sfc port pair group create --port-pair pp-ids ppg-ids
openstack sfc port pair group create --port-pair pp-lb ppg-lb

# 6. Flow Classifier 생성
openstack sfc flow classifier create \
  --description "Web Traffic" \
  --protocol tcp \
  --source-ip-prefix 0.0.0.0/0 \
  --destination-port 80:80 \
  fc-web

# 7. Port Chain 생성
openstack sfc port chain create \
  --port-pair-group ppg-fw \
  --port-pair-group ppg-ids \
  --port-pair-group ppg-lb \
  --flow-classifier fc-web \
  pc-web-service

echo "=== SFC Created Successfully ==="
echo "Chain: Client → Firewall → IDS → Load Balancer → Server"
```

---

## 📚 참고 자료

### 공식 문서

**NFV:**

- [ETSI NFV Standards](https://www.etsi.org/technologies/nfv)
- [ETSI NFV Architecture](https://www.etsi.org/committee/nfv)
- [OpenStack Tacker Documentation](https://docs.openstack.org/tacker/latest/)

**SDN Controllers:**

- [OpenDaylight Documentation](https://docs.opendaylight.org/)
- [ONOS Documentation](https://wiki.onosproject.org/)
- [Ryu SDN Framework](https://ryu-sdn.org/)
- [SDN Controller Comparison 2025 (Aptira)](https://aptira.com/sdn-controller-comparison/)

**Service Function Chaining:**

- [IETF RFC 7665 - SFC Architecture](https://datatracker.ietf.org/doc/html/rfc7665)
- [OpenStack Networking-SFC](https://docs.openstack.org/networking-sfc/latest/)
- [Service Function Chain Migration Survey (MDPI, 2025)](https://www.mdpi.com/2073-431X/14/6/203)

### 연구 논문 및 벤치마크

**성능 비교:**

- [Performance Comparison Of SDN Controllers (Research Square, 2025)](https://www.researchsquare.com/article/rs-4826985/v1)
- [A Comparative Evaluation of ODL and ONOS (IEEE, 2025)](https://ieeexplore.ieee.org/document/9870107/)

**보안:**

- [Security Analysis of ODL, ONOS, Ryu (IEEE)](https://ieeexplore.ieee.org/document/7751150/)

**SFC 오케스트레이션:**

- [Dynamic SFC Orchestration Using RL (ScienceDirect, 2025)](https://www.sciencedirect.com/science/article/abs/pii/S1877750324001923)
- [BSec-NFVO: Blockchain Security for NFV (IEEE)](https://ieeexplore.ieee.org/document/8761651/)

### 실무 가이드

- [Red Hat NFV Product Guide](https://docs.redhat.com/en/documentation/red_hat_openstack_platform/16.1/html/network_functions_virtualization_product_guide/)
- [Network Function Virtualization Explained (Medium, Nov 2025)](https://medium.com/@cantechnetworks/network-functions-virtualization-explained-860dfe97e24e)

---

## ✅ 학습 체크리스트

### NFV

- [ ] NFV와 기존 네트워크 장비 차이점 이해
- [ ] ETSI MANO 아키텍처 3계층 (NFVO, VNFM, VIM) 파악
- [ ] VNFD 작성 및 VNF 배포 경험
- [ ] VNF vs CNF 비교 및 마이그레이션 전략 이해
- [ ] 2025 NFV Release 5 신기능 파악

### SDN

- [ ] NFV와 SDN의 관계 및 상호 보완성 이해
- [ ] OpenDaylight, ONOS, Ryu 각각의 장단점 파악
- [ ] SDN 컨트롤러 선택 기준 이해
- [ ] OpenFlow Flow 추가/삭제 경험
- [ ] REST API를 통한 SDN 제어 경험

### Service Function Chaining

- [ ] SFC 개념 및 필요성 이해
- [ ] IETF SFC 아키텍처 파악
- [ ] OpenStack Networking-SFC 사용 경험
- [ ] Port Pair, Port Chain 생성 경험
- [ ] Dynamic SFC 및 AI 기반 최적화 개념 이해

### 종합 역량

- [ ] NFV+SDN 통합 아키텍처 설계 가능
- [ ] VNF 오케스트레이션 도구 선택 및 배포 경험
- [ ] 프로덕션 SFC 구축 및 운영 경험
- [ ] 성능 모니터링 및 최적화 경험

---

## 🎓 다음 단계

Ch4. 네트워크 가상화를 완료했다면, 다음 학습 주제로 진행하세요:

**Ch5. 네트워크 어플라이언스**

- Virtual Firewall (pfsense, OPNsense)
- Virtual Load Balancer (HAProxy, Nginx)
- Network Monitoring (Zabbix, Nagios)
- Traffic Shaping & QoS

**또는 심화 학습:**

- **Kubernetes CNF**: Helm Charts, Operators
- **5G Core Network**: UPF, SMF, AMF (NFV 기반)
- **Edge Computing**: Multi-Access Edge Computing (MEC)
- **Network Slicing**: 5G 네트워크 슬라이싱

**실무 프로젝트 아이디어:**

1. **멀티 VIM NFV 플랫폼**
   - OpenStack + Kubernetes 통합
   - VNF와 CNF 공존
   - 통합 오케스트레이션

2. **AI 기반 SFC 최적화**
   - 강화학습 기반 VNF 배치
   - 실시간 트래픽 분석
   - 동적 체인 재구성

3. **Telco Cloud 5G Core**
   - NFV 기반 5G 네트워크
   - Network Slicing 구현
   - E2E 오케스트레이션

네트워크 가상화는 미래 네트워크의 핵심입니다. 계속해서 학습하고 실습하면서 차세대 네트워크를 설계하고 운영하는 전문가로 성장하세요!
