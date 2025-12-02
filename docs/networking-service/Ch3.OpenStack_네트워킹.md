# Ch3. OpenStack 네트워킹

## 📋 개요

OpenStack Neutron은 클라우드 네트워킹의 핵심 서비스로, Software-Defined Networking (SDN)을 통해 가상 네트워크 인프라를 제공합니다. Neutron은 다양한 네트워킹 기술을 지원하며, ML2 (Modular Layer 2) 플러그인을 통해 유연한 네트워크 구성을 가능하게 합니다.

2025년 현재, OpenStack Epoxy (2025.1)에서는 LinuxBridge 드라이버가 제거되고 OVN (Open Virtual Network)으로의 전환이 가속화되고 있습니다. OVN은 stateless NAT, 향상된 L3 라우팅, 그리고 DPDK 기반 고성능 네트워킹을 지원합니다.

이 챕터에서는 Neutron 아키텍처, ML2 플러그인 메커니즘, OVN 마이그레이션, 그리고 커스텀 플러그인 개발까지 OpenStack 네트워킹의 모든 측면을 다룹니다.

---

## 🎯 학습 목표

이 챕터를 완료하면 다음을 할 수 있습니다:

- Neutron 아키텍처의 핵심 컴포넌트 이해
- ML2 플러그인의 Type/Mechanism Driver 구조 파악
- OVN vs OVS 차이점 이해 및 마이그레이션 수행
- Neutron API를 활용한 네트워크 리소스 관리
- L2/L3 에이전트의 동작 원리 이해
- Security Groups 및 FWaaS 구현
- 커스텀 ML2 Mechanism Driver 개발

---

## Part 1: Neutron 아키텍처

### 1-1. Neutron 핵심 컴포넌트

**Neutron 아키텍처 (2025):**

```
┌──────────────────────────────────────────────────────────────┐
│                    Neutron API Server                         │
│  - RESTful API                                                │
│  - RBAC (Role-Based Access Control)                          │
│  - Request Validation & Authentication                        │
└────────────────────────┬─────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
┌───────▼──────┐  ┌──────▼─────┐  ┌─────▼────────┐
│   ML2 Plugin │  │ L3 Plugin  │  │ Other Plugins│
│              │  │            │  │ (LBaaS,FWaaS)│
└───────┬──────┘  └──────┬─────┘  └──────────────┘
        │                │
┌───────▼──────────────────────────────────────────────┐
│             Message Queue (RabbitMQ/AMQP)            │
└───────┬──────────────────────────────────────────────┘
        │
        ├──────────┬──────────┬──────────┐
        │          │          │          │
┌───────▼──┐  ┌───▼─────┐ ┌──▼──────┐ ┌▼────────┐
│ L2 Agent │  │L3 Agent │ │DHCP     │ │Metadata │
│ (OVN/OVS)│  │         │ │Agent    │ │Agent    │
└───────┬──┘  └───┬─────┘ └──┬──────┘ └┬────────┘
        │         │           │         │
┌───────▼─────────▼───────────▼─────────▼──────────┐
│           Compute/Network Nodes                   │
│   (OVS, Linux Bridge, SR-IOV, etc.)               │
└───────────────────────────────────────────────────┘
```

**핵심 컴포넌트 설명:**

**1. Neutron Server (neutron-server):**

- RESTful API 제공
- 플러그인 관리 및 요청 라우팅
- 데이터베이스 연동 (MySQL/PostgreSQL)
- 인증/인가 (Keystone 통합)

**2. ML2 Plugin:**

- Modular Layer 2 플러그인
- 다양한 네트워크 타입 지원 (VLAN, VXLAN, GRE, Geneve)
- Type Driver: 네트워크 타입 정의
- Mechanism Driver: 실제 네트워크 구현

**3. L3 Agent (neutron-l3-agent):**

- Virtual Router 구현
- Floating IP 관리
- NAT (SNAT/DNAT)
- Network Namespace 기반

**4. DHCP Agent (neutron-dhcp-agent):**

- 가상 네트워크에 DHCP 서비스 제공
- Dnsmasq 프로세스 관리
- Network Namespace 활용

**5. Metadata Agent (neutron-metadata-agent):**

- 인스턴스에 메타데이터 제공
- Nova Metadata API 프록시
- 2025.2에서 OVN Agent로 통합

**6. L2 Agent:**

- **OVN Agent**: OVN 메커니즘 (2025 권장)
- **OVS Agent**: Open vSwitch 메커니즘 (레거시)
- **LinuxBridge Agent**: 2025.1에서 제거됨

### 1-2. Neutron 네트워크 리소스

**네트워크 리소스 계층:**

```
Tenant (Project)
├── Network
│   ├── Subnet
│   │   ├── Allocation Pool
│   │   ├── Gateway IP
│   │   └── DNS Nameservers
│   └── Ports
│       ├── Fixed IP
│       ├── MAC Address
│       ├── Security Groups
│       └── Device (VM, Router, LB, etc.)
├── Router
│   ├── Internal Interfaces (Subnets)
│   ├── External Gateway
│   └── Floating IPs
└── Security Groups
    └── Rules (Ingress/Egress)
```

**네트워크 타입:**

| 타입 | 설명 | 사용 사례 |
|------|------|----------|
| **Local** | 단일 호스트 네트워크 | 테스트 |
| **Flat** | 태그 없는 네트워크 | Provider 네트워크 |
| **VLAN** | 802.1Q VLAN 태깅 | 레거시 환경 |
| **VXLAN** | L3 오버 L2 터널 | 멀티테넌트 (권장) |
| **GRE** | Generic Routing Encapsulation | 레거시 오버레이 |
| **Geneve** | Generic Network Virtualization | 차세대 캡슐화 |

### 1-3. Neutron API 사용

**OpenStack CLI를 통한 네트워크 관리:**

```bash
# 네트워크 생성
openstack network create \
  --project demo \
  --provider-network-type vxlan \
  demo-network

# 서브넷 생성
openstack subnet create \
  --network demo-network \
  --subnet-range 192.168.100.0/24 \
  --gateway 192.168.100.1 \
  --dns-nameserver 8.8.8.8 \
  --allocation-pool start=192.168.100.10,end=192.168.100.200 \
  demo-subnet

# 라우터 생성
openstack router create demo-router

# 라우터에 서브넷 연결
openstack router add subnet demo-router demo-subnet

# 외부 게이트웨이 설정
openstack router set \
  --external-gateway public-network \
  demo-router

# 포트 생성 (특정 IP 지정)
openstack port create \
  --network demo-network \
  --fixed-ip subnet=demo-subnet,ip-address=192.168.100.50 \
  demo-port

# Floating IP 생성
openstack floating ip create public-network

# Floating IP 연결
openstack server add floating ip <instance-id> <floating-ip>
```

**Neutron REST API 직접 호출 (Python):**

```python
# neutron_api.py
import requests
from keystoneauth1 import session
from keystoneauth1.identity import v3
from neutronclient.v2_0 import client

# Keystone 인증
auth = v3.Password(
    auth_url='http://controller:5000/v3',
    username='admin',
    password='secret',
    project_name='admin',
    user_domain_id='default',
    project_domain_id='default'
)

sess = session.Session(auth=auth)
neutron = client.Client(session=sess)

# 네트워크 생성
network_body = {
    'network': {
        'name': 'api-network',
        'admin_state_up': True,
        'shared': False,
        'provider:network_type': 'vxlan',
    }
}

network = neutron.create_network(body=network_body)
network_id = network['network']['id']

print(f"Network created: {network_id}")

# 서브넷 생성
subnet_body = {
    'subnet': {
        'network_id': network_id,
        'cidr': '10.0.1.0/24',
        'ip_version': 4,
        'gateway_ip': '10.0.1.1',
        'dns_nameservers': ['8.8.8.8', '8.8.4.4'],
        'allocation_pools': [
            {'start': '10.0.1.10', 'end': '10.0.1.200'}
        ]
    }
}

subnet = neutron.create_subnet(body=subnet_body)
print(f"Subnet created: {subnet['subnet']['id']}")

# 포트 생성 및 보안 그룹 적용
port_body = {
    'port': {
        'network_id': network_id,
        'name': 'vm-port-1',
        'admin_state_up': True,
        'fixed_ips': [
            {'subnet_id': subnet['subnet']['id'], 'ip_address': '10.0.1.50'}
        ],
        'security_groups': ['default']
    }
}

port = neutron.create_port(body=port_body)
print(f"Port created: {port['port']['id']}")

# 네트워크 목록 조회
networks = neutron.list_networks()
for net in networks['networks']:
    print(f"Network: {net['name']} ({net['id']})")
```

---

## Part 2: ML2 플러그인

### 2-1. ML2 아키텍처

**ML2 (Modular Layer 2) 개념:**

ML2는 OpenStack Neutron의 플러그인 프레임워크로, 다양한 Layer 2 네트워킹 기술을 동시에 활용할 수 있게 합니다.

**ML2 구조:**

```
┌──────────────────────────────────────────────────────┐
│              Neutron API Server                       │
└────────────────────┬─────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────┐
│              ML2 Plugin                               │
│  ┌────────────────────────────────────────────────┐  │
│  │          Type Drivers                          │  │
│  │  ┌──────┬──────┬──────┬──────┬────────┐       │  │
│  │  │Local │ Flat │ VLAN │VXLAN │Geneve  │       │  │
│  │  └──────┴──────┴──────┴──────┴────────┘       │  │
│  └────────────────────────────────────────────────┘  │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │        Mechanism Drivers                       │  │
│  │  ┌──────┬──────┬──────┬──────┬────────┐       │  │
│  │  │ OVN  │ OVS  │L2Pop │SR-IOV│ Vendor │       │  │
│  │  └──────┴──────┴──────┴──────┴────────┘       │  │
│  └────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘
```

**Type Driver:**

- 네트워크 세그먼트 타입 정의
- VLAN ID, VNI 등 세그먼트 할당
- 리소스 풀 관리

**Mechanism Driver:**

- 실제 네트워크 구현 방식
- 에이전트와 통신
- 네트워크 설정 적용

### 2-2. Type Drivers

**ML2 설정 (/etc/neutron/plugins/ml2/ml2_conf.ini):**

```ini
[ml2]
# Type Drivers
type_drivers = flat,vlan,vxlan,geneve
tenant_network_types = vxlan,geneve

# Mechanism Drivers (2025 권장)
mechanism_drivers = ovn

# Extension Drivers
extension_drivers = port_security,qos,dns_domain_ports

[ml2_type_flat]
# Flat 네트워크 (Provider)
flat_networks = provider

[ml2_type_vlan]
# VLAN 범위
network_vlan_ranges = provider:1:1000,physnet2:2000:2999

[ml2_type_vxlan]
# VXLAN VNI 범위
vni_ranges = 1:1000000

# Multicast 그룹 (레거시, OVN에서는 불필요)
# vxlan_group = 239.1.1.1

[ml2_type_geneve]
# Geneve VNI 범위
vni_ranges = 1:1000000
max_header_size = 38
```

**VLAN Type Driver 상세:**

```python
# neutron/plugins/ml2/drivers/type_vlan.py (개념 설명용)

class VlanTypeDriver(helpers.SegmentTypeDriver):
    def __init__(self):
        super(VlanTypeDriver, self).__init__(VlanAllocation)

    def get_type(self):
        return p_const.TYPE_VLAN

    def initialize(self):
        """VLAN 범위 초기화"""
        self._parse_network_vlan_ranges()
        self._sync_vlan_allocations()

    def reserve_provider_segment(self, context, segment):
        """Provider 네트워크용 VLAN 예약"""
        physical_network = segment.get(api.PHYSICAL_NETWORK)
        vlan_id = segment.get(api.SEGMENTATION_ID)

        # VLAN ID 유효성 검사
        if not vlan_id or vlan_id < 1 or vlan_id > 4094:
            raise ValueError("Invalid VLAN ID")

        # 데이터베이스에 할당 기록
        with db_api.CONTEXT_WRITER.using(context):
            alloc = VlanAllocation(
                physical_network=physical_network,
                vlan_id=vlan_id,
                allocated=True
            )
            context.session.add(alloc)

    def allocate_tenant_segment(self, context):
        """Tenant 네트워크용 VLAN 자동 할당"""
        with db_api.CONTEXT_WRITER.using(context):
            # 사용 가능한 VLAN ID 조회
            alloc = context.session.query(VlanAllocation).filter_by(
                allocated=False
            ).first()

            if not alloc:
                raise exc.NoNetworkAvailable()

            # VLAN 할당
            alloc.allocated = True

            return {
                api.NETWORK_TYPE: self.get_type(),
                api.PHYSICAL_NETWORK: alloc.physical_network,
                api.SEGMENTATION_ID: alloc.vlan_id
            }

    def release_segment(self, context, segment):
        """VLAN ID 반환"""
        physical_network = segment[api.PHYSICAL_NETWORK]
        vlan_id = segment[api.SEGMENTATION_ID]

        with db_api.CONTEXT_WRITER.using(context):
            alloc = context.session.query(VlanAllocation).filter_by(
                physical_network=physical_network,
                vlan_id=vlan_id
            ).first()

            if alloc:
                alloc.allocated = False
```

**VXLAN Type Driver:**

```python
# neutron/plugins/ml2/drivers/type_vxlan.py (개념)

class VxlanTypeDriver(helpers.SegmentTypeDriver):
    def __init__(self):
        super(VxlanTypeDriver, self).__init__(VxlanAllocation)

    def get_type(self):
        return p_const.TYPE_VXLAN

    def get_mtu(self, physical_network=None):
        """VXLAN MTU 계산"""
        # 기본 MTU (1500) - VXLAN 오버헤드 (50)
        return 1450

    def allocate_tenant_segment(self, context):
        """VNI 자동 할당"""
        with db_api.CONTEXT_WRITER.using(context):
            alloc = context.session.query(VxlanAllocation).filter_by(
                allocated=False
            ).with_for_update().first()

            if not alloc:
                raise exc.NoNetworkAvailable()

            alloc.allocated = True

            return {
                api.NETWORK_TYPE: p_const.TYPE_VXLAN,
                api.SEGMENTATION_ID: alloc.vxlan_vni,
                api.PHYSICAL_NETWORK: None
            }
```

### 2-3. Mechanism Drivers

**주요 Mechanism Drivers (2025):**

**1. OVN (Open Virtual Network) - 권장:**

```ini
[ml2]
mechanism_drivers = ovn

[ovn]
# OVN Northbound Database
ovn_nb_connection = tcp:192.168.1.10:6641
ovn_nb_private_key = /etc/neutron/ovn-privkey.pem
ovn_nb_certificate = /etc/neutron/ovn-cert.pem
ovn_nb_ca_cert = /etc/neutron/ovn-cacert.pem

# OVN Southbound Database
ovn_sb_connection = tcp:192.168.1.10:6642
ovn_sb_private_key = /etc/neutron/ovn-privkey.pem
ovn_sb_certificate = /etc/neutron/ovn-cert.pem
ovn_sb_ca_cert = /etc/neutron/ovn-cacert.pem

# L3 설정
ovn_l3_scheduler = leastloaded
enable_distributed_floating_ip = True

# OVN Metadata (2025.2 신규)
ovn_metadata_enabled = True

# Stateless NAT (2025.2 신규)
stateless_nat_enabled = True

# DPDK 지원
ovn_emit_need_to_frag = False
```

**OVN 장점 (vs OVS):**

- 중앙화된 제어 플레인 (Northbound/Southbound DB)
- 에이전트리스 아키텍처 (L2/L3 Agent 불필요)
- 향상된 성능 (DPDK 지원)
- Stateless NAT (2025.2 신규)
- 간소화된 운영

**2. Open vSwitch (OVS) - 레거시:**

```ini
[ml2]
mechanism_drivers = openvswitch,l2population

[ovs]
# Integration Bridge
integration_bridge = br-int

# Tunnel Bridge
tunnel_bridge = br-tun

# Local IP (VXLAN Tunnel Endpoint)
local_ip = 192.168.1.20

# Bridge Mappings (Provider 네트워크)
bridge_mappings = provider:br-provider

# Tunnel Types
tunnel_types = vxlan

[agent]
# ARP Responder (L2 Population 필요)
arp_responder = True

# Prevent ARP Spoofing
prevent_arp_spoofing = True

# VXLAN UDP Port
vxlan_udp_port = 4789

[securitygroup]
# Firewall Driver
firewall_driver = openvswitch
enable_security_group = True
```

**3. LinuxBridge - 2025.1에서 제거됨:**

```
경고: LinuxBridge 드라이버는 OpenStack Epoxy (2025.1)에서 제거되었습니다.
OVS 또는 OVN으로 마이그레이션 필요.
```

### 2-4. L2 Population

**L2 Population (L2pop) 개념:**

L2 Population은 VXLAN/GRE 오버레이 네트워크에서 BUM (Broadcast, Unknown unicast, Multicast) 트래픽을 최적화하는 메커니즘 드라이버입니다.

**문제점 (L2pop 없이):**

```
VXLAN without L2pop:

VM1 (Host A)가 VM3 (Host C)의 MAC를 모를 때:
1. VM1이 ARP Request 전송 (Broadcast)
2. Host A는 모든 VTEP에 BUM 트래픽 전송
   └─> Host B, Host C, Host D, Host E, ...
3. 모든 호스트가 ARP Request 수신
4. Host C의 VM3만 ARP Reply

문제: 불필요한 네트워크 트래픽 증가
```

**해결책 (L2pop 사용):**

```
VXLAN with L2pop:

1. Neutron Server가 모든 (MAC, IP, VTEP) 매핑 추적
2. 새 포트 생성 시 모든 에이전트에 정보 전파
3. 각 호스트의 OVS FDB에 원격 MAC 등록

VM1이 VM3으로 통신:
1. VM1이 ARP Request (로컬 OVS가 가로챔)
2. OVS FDB에서 VM3의 MAC 확인
3. ARP Reply 위조 (Proxy ARP)
4. VM1이 VM3으로 직접 유니캐스트

결과: BUM 트래픽 제거, 네트워크 효율성 대폭 향상
```

**L2pop 설정:**

```ini
[ml2]
mechanism_drivers = openvswitch,l2population

[agent]
l2_population = True
arp_responder = True
```

---

## Part 3: OVN (Open Virtual Network)

### 3-1. OVN 아키텍처

**OVN vs OVS 비교:**

```
OVS 기반 아키텍처:
┌────────────────────────────────────────┐
│       Neutron Server + ML2 Plugin      │
└───────────────┬────────────────────────┘
                │
    ┌───────────┼───────────┐
    │           │           │
┌───▼────┐  ┌──▼────┐  ┌───▼────┐
│L2 Agent│  │L3 Agnt│  │DHCP Ag │  (각 컴퓨트 노드)
└───┬────┘  └──┬────┘  └───┬────┘
    │          │           │
┌───▼──────────▼───────────▼────┐
│      Open vSwitch (OVS)        │
└────────────────────────────────┘

문제점:
- 각 노드에 여러 에이전트 필요
- RabbitMQ를 통한 느린 동기화
- 복잡한 디버깅


OVN 기반 아키텍처:
┌────────────────────────────────────────┐
│    Neutron Server + ML2/OVN Plugin     │
└───────────────┬────────────────────────┘
                │
┌───────────────▼────────────────────────┐
│      OVN Northbound Database           │  (논리적 네트워크)
│  - 논리적 스위치, 라우터, ACL           │
└───────────────┬────────────────────────┘
                │
┌───────────────▼────────────────────────┐
│           ovn-northd                   │  (변환 계층)
└───────────────┬────────────────────────┘
                │
┌───────────────▼────────────────────────┐
│      OVN Southbound Database           │  (물리적 바인딩)
│  - 포트 바인딩, 터널, Flow              │
└───────────────┬────────────────────────┘
                │
        ┌───────┼───────┐
        │       │       │
┌───────▼──┐ ┌──▼────┐ ┌▼───────┐
│OVN Agent │ │OVN Agt│ │OVN Agt │  (각 컴퓨트 노드)
│+ Metadata│ │       │ │        │
└───┬──────┘ └──┬────┘ └┬───────┘
    │           │        │
┌───▼───────────▼────────▼────┐
│         OVS + OVN           │
└─────────────────────────────┘

장점:
- 단일 OVN Agent
- 중앙화된 데이터베이스
- 빠른 동기화
- 간편한 디버깅
```

**OVN 데이터베이스 구조:**

```
Northbound DB (논리적 뷰):
┌──────────────────────────────────┐
│ Logical_Switch (네트워크)         │
├──────────────────────────────────┤
│ Logical_Switch_Port (포트)        │
├──────────────────────────────────┤
│ Logical_Router (라우터)           │
├──────────────────────────────────┤
│ Logical_Router_Port (라우터 포트) │
├──────────────────────────────────┤
│ ACL (보안 그룹 규칙)              │
├──────────────────────────────────┤
│ NAT (Floating IP, SNAT)          │
├──────────────────────────────────┤
│ DHCP_Options                     │
└──────────────────────────────────┘

Southbound DB (물리적 바인딩):
┌──────────────────────────────────┐
│ Chassis (호스트)                  │
├──────────────────────────────────┤
│ Port_Binding (포트 → 호스트)      │
├──────────────────────────────────┤
│ Datapath_Binding (네트워크 ID)    │
├──────────────────────────────────┤
│ Encap (터널 설정)                 │
└──────────────────────────────────┘
```

### 3-2. OVN 설치 및 설정

**컨트롤러 노드 (OVN Central):**

```bash
# OVN Central 설치
apt-get install ovn-central

# OVN Northbound DB 시작
ovn-ctl start_nb_ovsdb \
  --db-nb-addr=192.168.1.10 \
  --db-nb-create-insecure-remote=yes

# OVN Southbound DB 시작
ovn-ctl start_sb_ovsdb \
  --db-sb-addr=192.168.1.10 \
  --db-sb-create-insecure-remote=yes

# ovn-northd 시작
ovn-ctl start_northd

# 상태 확인
ovn-nbctl show
ovn-sbctl show
```

**Neutron 서버 설정:**

```ini
# /etc/neutron/neutron.conf
[DEFAULT]
core_plugin = ml2
service_plugins = ovn-router,trunk,qos,segments

[ml2]
mechanism_drivers = ovn
type_drivers = geneve,vlan,flat
tenant_network_types = geneve
extension_drivers = port_security,qos,dns_domain_ports

[ovn]
ovn_nb_connection = tcp:192.168.1.10:6641
ovn_sb_connection = tcp:192.168.1.10:6642
ovn_l3_scheduler = leastloaded
enable_distributed_floating_ip = True

# 2025.2 신규 기능
stateless_nat_enabled = True
ovn_metadata_enabled = True
```

**컴퓨트 노드 설정:**

```bash
# OVN Host 설치
apt-get install ovn-host ovn-common

# OVS 시작
systemctl start openvswitch-switch

# OVN Controller 설정
ovs-vsctl set open . \
  external-ids:ovn-remote=tcp:192.168.1.10:6642 \
  external-ids:ovn-encap-type=geneve \
  external-ids:ovn-encap-ip=192.168.1.20

# Integration Bridge 생성
ovs-vsctl --may-exist add-br br-int \
  -- set bridge br-int fail-mode=secure

# OVN Controller 시작
systemctl start ovn-controller

# OVN Metadata Agent 시작 (2025.2에서는 OVN Agent로 대체)
# 구 방식:
# systemctl start neutron-ovn-metadata-agent

# 신 방식 (2025.2):
systemctl start neutron-ovn-agent
```

**OVN Agent 설정 (2025.2):**

```ini
# /etc/neutron/plugins/ml2/ovn_agent.ini
[DEFAULT]
debug = True

[agent]
# Metadata Extension 활성화
extensions = metadata

[ovs]
ovsdb_connection = unix:/var/run/openvswitch/db.sock

[ovn]
ovn_sb_connection = tcp:192.168.1.10:6642
ovn_sb_private_key = /etc/neutron/ovn-privkey.pem
ovn_sb_certificate = /etc/neutron/ovn-cert.pem
ovn_sb_ca_cert = /etc/neutron/ovn-cacert.pem
```

### 3-3. LinuxBridge에서 OVN으로 마이그레이션

**마이그레이션 개요 (2025년 11월 실제 사례):**

```
Before (LinuxBridge):
mechanism_drivers = linuxbridge,sriovnicswitch

After (OVN):
mechanism_drivers = ovn,sriovnicswitch
```

**마이그레이션 단계:**

```bash
#!/bin/bash
# migrate-to-ovn.sh - LinuxBridge to OVN Migration

set -e

echo "=== OpenStack Neutron Migration: LinuxBridge → OVN ==="

# 1. 현재 상태 백업
echo "[Step 1] Backing up current configuration..."
mysqldump -u root -p neutron > neutron_backup_$(date +%F).sql
cp -r /etc/neutron /etc/neutron.backup.$(date +%F)

# 2. OVN 패키지 설치
echo "[Step 2] Installing OVN packages..."
apt-get update
apt-get install -y ovn-central ovn-host neutron-ovn-metadata-agent

# 3. Neutron 서비스 중지
echo "[Step 3] Stopping Neutron services..."
systemctl stop neutron-server
systemctl stop neutron-linuxbridge-agent
systemctl stop neutron-dhcp-agent
systemctl stop neutron-l3-agent
systemctl stop neutron-metadata-agent

# 4. ML2 설정 변경
echo "[Step 4] Updating ML2 configuration..."
cat > /etc/neutron/plugins/ml2/ml2_conf.ini <<EOF
[ml2]
type_drivers = geneve,vlan,flat
tenant_network_types = geneve
mechanism_drivers = ovn
extension_drivers = port_security,qos

[ml2_type_geneve]
vni_ranges = 1:65536
max_header_size = 38

[ovn]
ovn_nb_connection = tcp:192.168.1.10:6641
ovn_sb_connection = tcp:192.168.1.10:6642
ovn_l3_scheduler = leastloaded
enable_distributed_floating_ip = True
EOF

# 5. 데이터베이스 마이그레이션
echo "[Step 5] Migrating database..."
neutron-db-manage upgrade heads

# 6. OVN 초기화
echo "[Step 6] Initializing OVN..."
ovn-ctl start_nb_ovsdb --db-nb-addr=192.168.1.10
ovn-ctl start_sb_ovsdb --db-sb-addr=192.168.1.10
ovn-ctl start_northd

# 7. 네트워크 동기화
echo "[Step 7] Synchronizing networks to OVN..."
neutron-ovn-db-sync-util \
  --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini \
  --ovn-ovn_nb_connection tcp:192.168.1.10:6641 \
  --ovn-ovn_sb_connection tcp:192.168.1.10:6642

# 8. 각 컴퓨트 노드에서 실행
echo "[Step 8] Configuring compute nodes..."
# (각 컴퓨트 노드에서 실행 필요)
# ovs-vsctl set open . external-ids:ovn-remote=tcp:192.168.1.10:6642
# ovs-vsctl set open . external-ids:ovn-encap-type=geneve
# ovs-vsctl set open . external-ids:ovn-encap-ip=<NODE_IP>

# 9. Neutron 서비스 시작
echo "[Step 9] Starting Neutron with OVN..."
systemctl start neutron-server
systemctl start ovn-controller
systemctl start neutron-ovn-metadata-agent

# 10. 검증
echo "[Step 10] Verifying migration..."
openstack network agent list
ovn-nbctl show
ovn-sbctl show

echo "=== Migration Complete ==="
echo "Please verify all networks and instances are functioning correctly."
```

**마이그레이션 검증:**

```bash
# Neutron 에이전트 확인
openstack network agent list
# OVN Controller만 표시되어야 함

# OVN Northbound DB 확인
ovn-nbctl show
# 모든 논리적 스위치와 라우터 확인

# OVN Southbound DB 확인
ovn-sbctl show
# 모든 chassis와 port binding 확인

# 네트워크 연결성 테스트
# VM 간 ping 테스트
# Floating IP 접근 테스트
# 외부 네트워크 접근 테스트
```

### 3-4. OVN Stateless NAT (2025.2 신규)

**Stateless NAT 개념:**

전통적인 Stateful NAT는 Connection Tracking (conntrack)을 사용하여 각 연결의 상태를 추적합니다. Stateless NAT는 상태 추적 없이 단순히 IP 주소만 변환합니다.

**장점:**

- DPDK 기반 배포에서 성능 향상
- conntrack 오버헤드 제거
- 높은 PPS (Packets Per Second) 처리

**설정:**

```ini
[ovn]
stateless_nat_enabled = True
```

**Stateful vs Stateless NAT 비교:**

```
Stateful NAT (기존):
VM (10.0.1.5:5000) → NAT → 외부 (203.0.113.10:5000)
                    ↓
              Conntrack Table
         ┌─────────────────────────┐
         │ 10.0.1.5:5000 ←→        │
         │ 203.0.113.10:5000       │
         └─────────────────────────┘

응답 패킷:
외부 (203.0.113.10:5000) → NAT (Conntrack 조회) → VM (10.0.1.5:5000)

오버헤드: Conntrack 테이블 조회, 상태 유지


Stateless NAT (2025.2):
VM (10.0.1.5:5000) → NAT → 외부 (203.0.113.10:5000)
                    (단순 IP 변환)

응답 패킷:
외부 (203.0.113.10:5000) → NAT (역변환) → VM (10.0.1.5:5000)
                          (규칙 기반)

오버헤드: 없음 (DPDK 환경에서 매우 빠름)
```

---

## Part 4: Security Groups 및 방화벽

### 4-1. Security Groups

**Security Group 구조:**

```
Security Group (방화벽 규칙 집합)
├── Ingress Rules (인바운드)
│   ├── Rule 1: Allow TCP 22 from 0.0.0.0/0
│   ├── Rule 2: Allow TCP 80 from 0.0.0.0/0
│   └── Rule 3: Allow ICMP from Security Group "web-sg"
└── Egress Rules (아웃바운드)
    └── Rule 1: Allow All to 0.0.0.0/0 (기본)
```

**Security Group 생성 및 관리:**

```bash
# Security Group 생성
openstack security group create \
  --description "Web Server Security Group" \
  web-sg

# HTTP 허용
openstack security group rule create \
  --protocol tcp \
  --dst-port 80 \
  --remote-ip 0.0.0.0/0 \
  web-sg

# HTTPS 허용
openstack security group rule create \
  --protocol tcp \
  --dst-port 443 \
  --remote-ip 0.0.0.0/0 \
  web-sg

# SSH 허용 (특정 IP만)
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 203.0.113.0/24 \
  web-sg

# ICMP (Ping) 허용
openstack security group rule create \
  --protocol icmp \
  --remote-ip 0.0.0.0/0 \
  web-sg

# Security Group 간 통신 허용
openstack security group rule create \
  --protocol tcp \
  --dst-port 3306 \
  --remote-group web-sg \
  db-sg

# 규칙 목록 확인
openstack security group rule list web-sg
```

**OVN에서 Security Group 구현:**

```
OVN ACL (Access Control List)로 구현:

ovn-nbctl acl-list <logical-switch>

예제 출력:
  from-lport  1002 (inport == "port1" && ip4 && tcp && tcp.dst == 80) allow-related
  from-lport  1002 (inport == "port1" && ip4 && tcp && tcp.dst == 443) allow-related
  from-lport  1002 (inport == "port1" && ip4 && tcp && tcp.dst == 22 && ip4.src == 203.0.113.0/24) allow-related
  from-lport  1001 (inport == "port1" && ip4) drop
  to-lport    1002 (outport == "port1" && ip4.dst == 10.0.1.5) allow-related
```

### 4-2. Firewall as a Service (FWaaS)

**FWaaS v2 개요:**

FWaaS는 라우터 레벨의 방화벽 서비스로, Security Group (VM 레벨)과 달리 라우터에 적용됩니다.

**FWaaS 계층 구조:**

```
Firewall Group
├── Ingress Firewall Policy
│   ├── Rule 1: Allow HTTP (Priority 100)
│   ├── Rule 2: Allow HTTPS (Priority 101)
│   └── Rule 3: Deny All (Priority 1000)
└── Egress Firewall Policy
    └── Rule 1: Allow All (Priority 100)
```

**FWaaS 설정:**

```bash
# Firewall Rule 생성
openstack firewall group rule create \
  --name allow-http \
  --protocol tcp \
  --destination-port 80 \
  --action allow

openstack firewall group rule create \
  --name allow-https \
  --protocol tcp \
  --destination-port 443 \
  --action allow

openstack firewall group rule create \
  --name deny-all \
  --action deny

# Firewall Policy 생성
openstack firewall group policy create \
  --firewall-rule allow-http \
  --firewall-rule allow-https \
  --firewall-rule deny-all \
  web-policy

# Firewall Group 생성 및 라우터에 적용
openstack firewall group create \
  --name web-firewall \
  --ingress-firewall-policy web-policy \
  --port <router-port-id>
```

---

## Part 5: 커스텀 ML2 Mechanism Driver 개발

### 5-1. Mechanism Driver API

**기본 구조:**

```python
# my_mechanism_driver.py
from neutron_lib.plugins.ml2 import api
from neutron.plugins.ml2.drivers import mech_agent

class MyMechanismDriver(mech_agent.SimpleAgentMechanismDriverBase):
    """커스텀 ML2 Mechanism Driver"""

    def __init__(self):
        super(MyMechanismDriver, self).__init__(
            agent_type='my-agent',
            vif_type='ovs',
            vif_details={'port_filter': True}
        )

    def get_allowed_network_types(self, agent=None):
        """지원하는 네트워크 타입"""
        return ['vlan', 'vxlan']

    def get_mappings(self, agent):
        """물리적 네트워크 매핑"""
        return agent.get('configurations', {}).get('bridge_mappings', {})

    def create_network_precommit(self, context):
        """네트워크 생성 전 (DB 트랜잭션 내)"""
        network = context.current
        print(f"Creating network: {network['id']}")

    def create_network_postcommit(self, context):
        """네트워크 생성 후 (DB 커밋 완료)"""
        network = context.current
        # 실제 네트워크 설정 수행
        self._provision_network(network)

    def update_network_precommit(self, context):
        """네트워크 업데이트 전"""
        pass

    def update_network_postcommit(self, context):
        """네트워크 업데이트 후"""
        pass

    def delete_network_precommit(self, context):
        """네트워크 삭제 전"""
        pass

    def delete_network_postcommit(self, context):
        """네트워크 삭제 후"""
        network = context.current
        self._cleanup_network(network)

    def create_port_precommit(self, context):
        """포트 생성 전"""
        pass

    def create_port_postcommit(self, context):
        """포트 생성 후"""
        port = context.current
        self._bind_port(port)

    def update_port_precommit(self, context):
        """포트 업데이트 전"""
        pass

    def update_port_postcommit(self, context):
        """포트 업데이트 후"""
        pass

    def delete_port_precommit(self, context):
        """포트 삭제 전"""
        pass

    def delete_port_postcommit(self, context):
        """포트 삭제 후"""
        port = context.current
        self._unbind_port(port)

    def bind_port(self, context):
        """포트 바인딩"""
        for segment in context.segments_to_bind:
            if self._check_segment(segment):
                context.set_binding(
                    segment[api.ID],
                    self.vif_type,
                    self.vif_details
                )
                return

    # 커스텀 메서드
    def _provision_network(self, network):
        """네트워크 프로비저닝 (하드웨어/SDN 설정)"""
        # TODO: 실제 네트워크 장비 설정
        pass

    def _cleanup_network(self, network):
        """네트워크 정리"""
        # TODO: 네트워크 장비에서 설정 제거
        pass

    def _bind_port(self, port):
        """포트 바인딩 (VLAN 할당 등)"""
        # TODO: 포트에 VLAN 할당
        pass

    def _unbind_port(self, port):
        """포트 언바인딩"""
        # TODO: VLAN 할당 해제
        pass

    def _check_segment(self, segment):
        """세그먼트 지원 여부 확인"""
        return segment[api.NETWORK_TYPE] in self.get_allowed_network_types()
```

### 5-2. Entry Point 등록

**setup.cfg:**

```ini
[entry_points]
neutron.ml2.mechanism_drivers =
    my_driver = my_neutron_plugin.mechanism_driver:MyMechanismDriver

neutron.ml2.type_drivers =
    my_type = my_neutron_plugin.type_driver:MyTypeDriver
```

**ml2_conf.ini에 추가:**

```ini
[ml2]
mechanism_drivers = ovn,my_driver
```

### 5-3. 에이전트와 통신

**RPC 기반 통신 (OVS 스타일):**

```python
# mechanism_driver.py
from neutron.plugins.ml2.drivers import mech_agent

class MyDriver(mech_agent.SimpleAgentMechanismDriverBase):

    def update_port_postcommit(self, context):
        """포트 업데이트를 에이전트에 통지"""
        port = context.current

        # RPC Cast (비동기)
        self.notifier.port_update(
            context._plugin_context,
            port,
            context.network.current,
            context.host
        )
```

**에이전트 측 수신:**

```python
# my_agent.py
from neutron.agent import rpc as agent_rpc

class MyNeutronAgent(object):

    def __init__(self):
        self.setup_rpc()

    def setup_rpc(self):
        """RPC 설정"""
        self.endpoints = [self]
        self.topic = 'my-agent'

        self.connection = agent_rpc.create_consumers(
            self.endpoints,
            self.topic,
            [[topics.PORT, topics.UPDATE]]
        )

    def port_update(self, context, **kwargs):
        """포트 업데이트 수신"""
        port = kwargs.get('port')
        print(f"Received port update: {port['id']}")

        # 실제 포트 설정 수행
        self._configure_port(port)

    def _configure_port(self, port):
        """포트 설정 (OVS, VLAN 등)"""
        # TODO: 실제 포트 설정
        pass
```

---

## 🛠️ 실습 가이드

### 실습 1: Neutron 네트워크 생성 및 VM 연결

**목표**: Neutron API로 완전한 네트워크 환경 구성

```bash
#!/bin/bash
# create-network-env.sh

set -e

PROJECT="demo"

echo "=== Creating Network Environment ==="

# 1. Internal 네트워크 생성
echo "[1] Creating internal network..."
NET_ID=$(openstack network create \
  --project $PROJECT \
  demo-network \
  -f value -c id)

echo "Network created: $NET_ID"

# 2. 서브넷 생성
echo "[2] Creating subnet..."
SUBNET_ID=$(openstack subnet create \
  --network $NET_ID \
  --subnet-range 192.168.100.0/24 \
  --gateway 192.168.100.1 \
  --dns-nameserver 8.8.8.8 \
  --allocation-pool start=192.168.100.10,end=192.168.100.200 \
  demo-subnet \
  -f value -c id)

echo "Subnet created: $SUBNET_ID"

# 3. 라우터 생성
echo "[3] Creating router..."
ROUTER_ID=$(openstack router create demo-router -f value -c id)

# 4. 라우터에 서브넷 연결
echo "[4] Connecting subnet to router..."
openstack router add subnet $ROUTER_ID $SUBNET_ID

# 5. 외부 게이트웨이 설정
echo "[5] Setting external gateway..."
openstack router set --external-gateway public $ROUTER_ID

# 6. Security Group 생성
echo "[6] Creating security group..."
SG_ID=$(openstack security group create \
  --description "Allow SSH and ICMP" \
  demo-sg \
  -f value -c id)

# SSH 허용
openstack security group rule create \
  --protocol tcp \
  --dst-port 22 \
  --remote-ip 0.0.0.0/0 \
  $SG_ID

# ICMP 허용
openstack security group rule create \
  --protocol icmp \
  $SG_ID

# 7. 포트 생성 (특정 IP 지정)
echo "[7] Creating port..."
PORT_ID=$(openstack port create \
  --network $NET_ID \
  --fixed-ip subnet=$SUBNET_ID,ip-address=192.168.100.50 \
  --security-group $SG_ID \
  demo-port \
  -f value -c id)

echo "Port created: $PORT_ID (192.168.100.50)"

# 8. VM 생성
echo "[8] Creating VM..."
openstack server create \
  --flavor m1.small \
  --image ubuntu-22.04 \
  --port $PORT_ID \
  --key-name my-keypair \
  demo-vm

# 9. Floating IP 할당
echo "[9] Allocating floating IP..."
FIP=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip demo-vm $FIP

echo ""
echo "=== Network Environment Created ==="
echo "VM: demo-vm"
echo "Internal IP: 192.168.100.50"
echo "Floating IP: $FIP"
echo ""
echo "Connect via: ssh ubuntu@$FIP"
```

### 실습 2: OVN 네트워크 디버깅

**목표**: OVN 논리 네트워크 및 Flow 분석

```bash
#!/bin/bash
# ovn-debug.sh - OVN Network Debugging

set -e

echo "=== OVN Network Debugging ==="

# 1. Logical Switches 확인
echo -e "\n[1] Logical Switches:"
ovn-nbctl ls-list

# 2. Logical Switch Ports 확인
echo -e "\n[2] Logical Switch Ports:"
LS_UUID=$(ovn-nbctl ls-list | head -1 | awk '{print $1}')
ovn-nbctl lsp-list $LS_UUID

# 3. Logical Routers 확인
echo -e "\n[3] Logical Routers:"
ovn-nbctl lr-list

# 4. Router Ports 확인
echo -e "\n[4] Router Ports:"
LR_UUID=$(ovn-nbctl lr-list | head -1 | awk '{print $1}')
ovn-nbctl lrp-list $LR_UUID

# 5. ACLs 확인 (Security Groups)
echo -e "\n[5] ACLs:"
ovn-nbctl acl-list $LS_UUID

# 6. NAT 규칙 확인
echo -e "\n[6] NAT Rules:"
ovn-nbctl lr-nat-list $LR_UUID

# 7. Chassis 확인 (Compute Nodes)
echo -e "\n[7] Chassis:"
ovn-sbctl chassis-list

# 8. Port Bindings 확인
echo -e "\n[8] Port Bindings:"
ovn-sbctl list Port_Binding

# 9. OVS Flows 확인
echo -e "\n[9] OVS Flows (br-int):"
ovs-ofctl dump-flows br-int -O OpenFlow13 | head -20

# 10. Geneve Tunnels 확인
echo -e "\n[10] Geneve Tunnels:"
ovs-vsctl show | grep -A 5 genev_sys

echo -e "\n=== Debugging Complete ==="
```

**OVN 트러블슈팅 체크리스트:**

```bash
# 네트워크 연결 안 됨?

# 1. 포트가 OVN에 등록되었는지 확인
ovn-nbctl show | grep <port-id>

# 2. 포트가 chassis에 바인딩되었는지 확인
ovn-sbctl find Port_Binding logical_port=<port-id>

# 3. OVS에서 포트 확인
ovs-vsctl show | grep <port-id>

# 4. Security Group (ACL) 확인
ovn-nbctl acl-list <logical-switch-uuid>

# 5. OVS Flow 확인
ovs-ofctl dump-flows br-int table=0

# 6. Geneve 터널 확인
ovs-vsctl list Interface genev_sys_6081

# 7. OVN Controller 로그 확인
journalctl -u ovn-controller -f

# 8. Neutron 서버 로그 확인
journalctl -u neutron-server -f
```

### 실습 3: 커스텀 ML2 Mechanism Driver 개발

**목표**: 간단한 로깅 Mechanism Driver 작성

**디렉토리 구조:**

```
my-neutron-plugin/
├── setup.py
├── setup.cfg
└── my_neutron_plugin/
    ├── __init__.py
    └── mechanism_driver.py
```

**setup.py:**

```python
from setuptools import setup, find_packages

setup(
    name='my-neutron-plugin',
    version='1.0.0',
    packages=find_packages(),
    install_requires=[
        'neutron-lib>=2.0.0',
        'oslo.log>=4.0.0',
    ],
)
```

**setup.cfg:**

```ini
[metadata]
name = my-neutron-plugin
summary = Custom Neutron ML2 Mechanism Driver
author = Your Name

[entry_points]
neutron.ml2.mechanism_drivers =
    logging = my_neutron_plugin.mechanism_driver:LoggingMechanismDriver
```

**mechanism_driver.py:**

```python
from neutron_lib.plugins.ml2 import api
from oslo_log import log as logging

LOG = logging.getLogger(__name__)

class LoggingMechanismDriver(api.MechanismDriver):
    """모든 네트워크 이벤트를 로깅하는 Mechanism Driver"""

    def initialize(self):
        """드라이버 초기화"""
        LOG.info("LoggingMechanismDriver initialized")

    def create_network_precommit(self, context):
        network = context.current
        LOG.info(f"[PRECOMMIT] Creating network: {network['id']} "
                 f"name={network['name']} type={network.get('provider:network_type')}")

    def create_network_postcommit(self, context):
        network = context.current
        LOG.info(f"[POSTCOMMIT] Network created: {network['id']}")

    def update_network_precommit(self, context):
        original = context.original
        current = context.current
        LOG.info(f"[PRECOMMIT] Updating network: {current['id']} "
                 f"from {original} to {current}")

    def update_network_postcommit(self, context):
        network = context.current
        LOG.info(f"[POSTCOMMIT] Network updated: {network['id']}")

    def delete_network_precommit(self, context):
        network = context.current
        LOG.info(f"[PRECOMMIT] Deleting network: {network['id']}")

    def delete_network_postcommit(self, context):
        network = context.current
        LOG.info(f"[POSTCOMMIT] Network deleted: {network['id']}")

    def create_subnet_precommit(self, context):
        subnet = context.current
        LOG.info(f"[PRECOMMIT] Creating subnet: {subnet['id']} "
                 f"cidr={subnet['cidr']}")

    def create_subnet_postcommit(self, context):
        subnet = context.current
        LOG.info(f"[POSTCOMMIT] Subnet created: {subnet['id']}")

    def create_port_precommit(self, context):
        port = context.current
        LOG.info(f"[PRECOMMIT] Creating port: {port['id']} "
                 f"device_id={port.get('device_id')}")

    def create_port_postcommit(self, context):
        port = context.current
        LOG.info(f"[POSTCOMMIT] Port created: {port['id']} "
                 f"fixed_ips={port['fixed_ips']}")

    def update_port_precommit(self, context):
        port = context.current
        LOG.info(f"[PRECOMMIT] Updating port: {port['id']}")

    def update_port_postcommit(self, context):
        port = context.current
        LOG.info(f"[POSTCOMMIT] Port updated: {port['id']}")

    def delete_port_precommit(self, context):
        port = context.current
        LOG.info(f"[PRECOMMIT] Deleting port: {port['id']}")

    def delete_port_postcommit(self, context):
        port = context.current
        LOG.info(f"[POSTCOMMIT] Port deleted: {port['id']}")
```

**설치 및 활성화:**

```bash
# 설치
cd my-neutron-plugin
pip install -e .

# ML2 설정에 추가
cat >> /etc/neutron/plugins/ml2/ml2_conf.ini <<EOF
[ml2]
mechanism_drivers = ovn,logging
EOF

# Neutron 서버 재시작
systemctl restart neutron-server

# 로그 확인
tail -f /var/log/neutron/neutron-server.log | grep LoggingMechanismDriver
```

**테스트:**

```bash
# 네트워크 생성
openstack network create test-network

# 로그 확인 (다음과 같이 출력됨):
# [PRECOMMIT] Creating network: <uuid> name=test-network type=vxlan
# [POSTCOMMIT] Network created: <uuid>
```

---

## 📚 참고 자료

### 공식 문서

**OpenStack Neutron:**

- [Neutron Documentation (2025.1)](https://docs.openstack.org/neutron/latest/)
- [ML2 Plugin Configuration](https://docs.openstack.org/neutron/latest/admin/config-ml2.html)
- [Neutron API Reference](https://docs.openstack.org/api-ref/network/)
- [Neutron Release Notes 2025.2](https://docs.openstack.org/releasenotes/neutron/2025.2.html)

**OVN:**

- [OVN Architecture](https://www.ovn.org/support/dist-docs/ovn-architecture.7.html)
- [OVN Northbound Database Schema](https://www.ovn.org/support/dist-docs/ovn-nb.5.html)
- [OVN Southbound Database Schema](https://www.ovn.org/support/dist-docs/ovn-sb.5.html)

**OpenStack Releases:**

- [Dalmatian Release (2024.2) Highlights](https://releases.openstack.org/dalmatian/highlights.html)
- [Epoxy Release (2025.1) Schedule](https://releases.openstack.org/epoxy/)

### 블로그 및 튜토리얼

**마이그레이션:**

- [Neutron Migration from LinuxBridge to OVN (Medium, Nov 2025)](https://medium.com/@ygk.kmr/openstack-neutron-migration-from-linux-bridge-to-ovn-3b96d26c5cfa)
- [OpenStack Dalmatian: Everything You Need To Know (OpenMetal)](https://openmetal.io/resources/blog/everything-you-need-to-know-about-openstack-dalmatian-2024-2/)

**개발:**

- [Contributing to Neutron](https://docs.openstack.org/neutron/latest/contributor/contribute.html)
- [Creating Custom Neutron Plugins (Alibaba Cloud)](https://www.alibabacloud.com/tech-news/a/neutron/gvjp2lgmt5-creating-custom-neutron-plugins)

### 도서

- **OpenStack Networking Essentials** - James Denton
- **Learning OpenStack Networking** - James Denton, Sriram Subramanian
- **OpenStack in Action** - V. K. Cody Bumgardner

### 커뮤니티

- [OpenStack Neutron Wiki](https://wiki.openstack.org/wiki/Neutron)
- [OpenStack IRC (#openstack-neutron)](https://webchat.oftc.net/)
- [OpenStack Mailing Lists](https://lists.openstack.org/)

---

## ✅ 학습 체크리스트

### Neutron 아키텍처

- [ ] Neutron 핵심 컴포넌트 (Server, ML2, L3, DHCP, Metadata) 이해
- [ ] 네트워크 리소스 계층 (Network, Subnet, Port) 파악
- [ ] Neutron API를 활용한 네트워크 관리 경험
- [ ] Security Groups 설정 및 관리 경험

### ML2 플러그인

- [ ] Type Driver vs Mechanism Driver 차이점 이해
- [ ] VLAN, VXLAN, Geneve 네트워크 타입 이해
- [ ] ML2 설정 파일 작성 및 관리 경험
- [ ] L2 Population 개념 및 BUM 트래픽 최적화 이해

### OVN

- [ ] OVN vs OVS 아키텍처 차이점 이해
- [ ] Northbound/Southbound Database 구조 파악
- [ ] OVN 설치 및 설정 경험
- [ ] LinuxBridge/OVS에서 OVN으로 마이그레이션 경험
- [ ] Stateless NAT 개념 이해 (2025.2 신규)
- [ ] OVN 디버깅 (ovn-nbctl, ovn-sbctl) 경험

### 보안

- [ ] Security Groups 생성 및 규칙 관리
- [ ] FWaaS (Firewall as a Service) 설정 경험
- [ ] Security Group과 FWaaS 차이점 이해

### 플러그인 개발

- [ ] ML2 Mechanism Driver API 이해
- [ ] 커스텀 Mechanism Driver 개발 경험
- [ ] Entry Point 등록 및 설치 경험
- [ ] RPC를 통한 에이전트 통신 이해

### 종합 역량

- [ ] 멀티테넌트 네트워크 환경 설계 가능
- [ ] Neutron 트러블슈팅 및 성능 최적화 경험
- [ ] 프로덕션 환경 OVN 배포 경험
- [ ] Neutron 모니터링 및 로그 분석 경험

---

## 🎓 다음 단계

Ch3. OpenStack 네트워킹을 완료했다면, 다음 학습 주제로 진행하세요:

**Ch4. 네트워크 가상화**

- NFV (Network Functions Virtualization)
- VNF (Virtual Network Functions)
- SDN Controllers (OpenDaylight, ONOS)
- Network Service Chaining
- ETSI MANO 아키텍처

**또는 심화 학습:**

- **Neutron 고급**: DVR (Distributed Virtual Router), L3 HA
- **OpenStack Ironic**: Bare Metal 네트워킹
- **Kuryr**: Kubernetes와 Neutron 통합
- **고급 보안**: Network Segmentation, Micro-segmentation

**실무 프로젝트 아이디어:**

1. **멀티 리전 OpenStack 네트워크**
   - 여러 리전 간 L2/L3 연결
   - VPN 기반 사이트 연결
   - 글로벌 로드 밸런싱

2. **OVN 기반 고성능 클라우드**
   - DPDK + OVN 통합
   - SR-IOV 네트워킹
   - 성능 벤치마크 및 튜닝

3. **Neutron 모니터링 플랫폼**
   - OVN Flow 분석
   - 네트워크 토폴로지 시각화
   - 자동 장애 감지

OpenStack Neutron은 클라우드 네트워킹의 핵심입니다. 계속해서 학습하고 실습하면서 대규모 클라우드 인프라를 설계하고 운영하는 전문가로 성장하세요!
