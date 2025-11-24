# Ch1. OpenStack - 오픈소스 클라우드 플랫폼

## 📋 개요

OpenStack은 가장 널리 사용되는 오픈소스 클라우드 인프라 플랫폼으로, 컴퓨팅(Nova), 블록 스토리지(Cinder), 이미지(Glance), 베어메탈(Ironic) 등 다양한 서비스를 제공합니다. 본 장에서는 OpenStack의 핵심 아키텍처를 이해하고, 각 컴포넌트의 동작 원리를 학습하며, Kolla-Ansible을 활용한 프로덕션 환경 배포 방법을 다룹니다.

2025년 현재, OpenStack은 **2025.1 Epoxy 릴리즈**를 통해 컨테이너 기반 배포, 향상된 베어메탈 프로비저닝, 그리고 멀티 클라우드 통합 기능을 강화하고 있습니다.

## 🎯 학습 목표

1. **OpenStack 아키텍처 이해**
   - 핵심 서비스 컴포넌트 (Nova, Cinder, Glance, Neutron, Keystone)
   - 서비스 간 상호작용 및 메시지 큐 아키텍처
   - API 기반 통신 구조

2. **Nova 컴퓨팅 서비스 마스터하기**
   - Nova 아키텍처 및 컴포넌트 (API, Scheduler, Compute, Conductor)
   - 인스턴스 생성 플로우 및 스케줄링 알고리즘
   - Hypervisor 통합 (KVM, QEMU, VMware)

3. **Cinder 블록 스토리지 관리**
   - Cinder 아키텍처 및 볼륨 타입
   - 백엔드 스토리지 드라이버 (LVM, Ceph, NFS)
   - 볼륨 스냅샷 및 백업

4. **Glance 이미지 서비스**
   - 이미지 저장소 백엔드 (Swift, Ceph, Cinder)
   - 이미지 캐싱 및 성능 최적화
   - 멀티 스토어 설정

5. **Ironic 베어메탈 프로비저닝**
   - Ironic 아키텍처 및 Nova 통합
   - IPMI/Redfish를 활용한 하드웨어 관리
   - 프로비저닝 네트워크 설계

6. **Kolla-Ansible 프로덕션 배포**
   - 컨테이너 기반 OpenStack 배포
   - HA 구성 및 스케일링
   - 모니터링 및 운영

---

## Part 1: OpenStack 아키텍처

### 1.1 OpenStack 개요

**OpenStack이란?**
OpenStack은 가상 머신, 스토리지, 네트워크를 관리하는 오픈소스 클라우드 운영체제입니다. 2010년 NASA와 Rackspace가 시작했으며, 현재 OpenStack Foundation에서 관리합니다.

**핵심 서비스:**
```
┌─────────────────────────────────────────────────────────────┐
│                      OpenStack Services                      │
├─────────────────────────────────────────────────────────────┤
│  Horizon (Dashboard) - 웹 기반 관리 인터페이스               │
├─────────────────────────────────────────────────────────────┤
│  Keystone (Identity) - 인증 및 서비스 카탈로그               │
├──────────────┬──────────────┬──────────────┬────────────────┤
│  Nova        │  Neutron     │  Cinder      │  Glance        │
│  (Compute)   │  (Network)   │  (Block      │  (Image)       │
│              │              │   Storage)   │                │
├──────────────┼──────────────┴──────────────┴────────────────┤
│  Ironic      │  Swift (Object Storage)                      │
│  (Bare Metal)│                                              │
├──────────────┴──────────────────────────────────────────────┤
│  Placement - 리소스 인벤토리 및 할당                         │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 서비스 간 통신 아키텍처

**메시지 큐 기반 통신:**
```
┌──────────┐      REST API       ┌──────────────┐
│  Client  │ ───────────────────> │  Nova API    │
└──────────┘                      └──────┬───────┘
                                         │ RPC via RabbitMQ
                      ┌──────────────────┼──────────────────┐
                      │                  │                  │
                ┌─────▼──────┐   ┌──────▼─────┐   ┌────────▼──────┐
                │   Nova     │   │   Nova     │   │    Nova       │
                │  Scheduler │   │  Conductor │   │   Compute     │
                └────────────┘   └────────────┘   └───────┬───────┘
                                                           │
                                                   ┌───────▼────────┐
                                                   │   Hypervisor   │
                                                   │   (KVM/QEMU)   │
                                                   └────────────────┘
```

**주요 통신 메커니즘:**

- **REST API**: 외부 클라이언트와 OpenStack 서비스 간
- **RPC (oslo.messaging)**: 서비스 내부 컴포넌트 간 (RabbitMQ/AMQP)
- **Database**: 상태 저장 (MariaDB/MySQL)

### 1.3 Keystone - Identity Service

**Keystone의 역할:**

- 사용자 인증 (Authentication)
- 서비스 카탈로그 관리
- 토큰 발급 및 검증
- 권한 관리 (RBAC)

**인증 플로우:**
```python
# Python으로 Keystone 인증
from keystoneauth1 import session
from keystoneauth1.identity import v3
from novaclient import client as nova_client

# 1. Keystone 인증
auth = v3.Password(
    auth_url='http://controller:5000/v3',
    username='admin',
    password='secret',
    project_name='admin',
    user_domain_id='default',
    project_domain_id='default'
)

sess = session.Session(auth=auth)

# 2. 토큰 획득
token = sess.get_token()

# 3. Nova 클라이언트 생성 (토큰 사용)
nova = nova_client.Client('2.1', session=sess)

# 4. 인스턴스 목록 조회
servers = nova.servers.list()
for server in servers:
    print(f"{server.name}: {server.status}")
```

---

## Part 2: Nova - 컴퓨팅 서비스

### 2.1 Nova 아키텍처

**Nova 컴포넌트:**

| 컴포넌트 | 역할 | 실행 위치 |
|----------|------|-----------|
| nova-api | REST API 제공, 요청 검증 | Controller |
| nova-scheduler | 인스턴스를 배치할 호스트 선택 | Controller |
| nova-conductor | DB 접근 프록시, 장기 실행 작업 조율 | Controller |
| nova-compute | Hypervisor 관리, 인스턴스 라이프사이클 | Compute Node |
| nova-novncproxy | VNC 콘솔 프록시 | Controller |
| placement-api | 리소스 인벤토리 및 할당 추적 | Controller |

**Nova Architecture (2025.1):**
```
┌─────────────────────────────────────────────────────────────┐
│                      Controller Node                         │
├─────────────┬──────────────┬──────────────┬─────────────────┤
│  nova-api   │ nova-        │ nova-        │ placement-api   │
│             │ scheduler    │ conductor    │                 │
└─────┬───────┴──────┬───────┴──────┬───────┴─────────┬───────┘
      │              │              │                 │
      └──────────────┴──────────────┴─────────────────┘
                     │ (RabbitMQ + MariaDB)
      ┌──────────────┴──────────────┬─────────────────┐
      │                             │                 │
┌─────▼──────────┐         ┌────────▼────────┐  ┌────▼──────────┐
│ Compute Node 1 │         │ Compute Node 2  │  │ Compute Node N│
├────────────────┤         ├─────────────────┤  ├───────────────┤
│ nova-compute   │         │ nova-compute    │  │ nova-compute  │
│ libvirt/KVM    │         │ libvirt/KVM     │  │ libvirt/KVM   │
└────────────────┘         └─────────────────┘  └───────────────┘
```

### 2.2 인스턴스 생성 플로우

**전체 프로세스 (2025.1 기준):**

```
1. Client → nova-api
   POST /v2.1/servers
   {
     "server": {
       "name": "test-vm",
       "flavorRef": "2",
       "imageRef": "uuid-of-image"
     }
   }

2. nova-api → Keystone
   토큰 검증 및 권한 확인

3. nova-api → Database
   인스턴스 레코드 생성 (status: BUILD)

4. nova-api → nova-conductor (RPC)
   build_instances 요청

5. nova-conductor → nova-scheduler (RPC)
   select_destinations 요청

6. nova-scheduler → placement-api
   리소스 가용성 확인
   GET /allocation_candidates?resources=VCPU:2,MEMORY_MB:4096,DISK_GB:20

7. nova-scheduler
   필터링 및 가중치 계산
   - 사용 가능한 호스트 필터링
   - 최적 호스트 선택

8. nova-scheduler → nova-conductor
   선택된 호스트 정보 반환

9. nova-conductor → nova-compute@host (RPC)
   build_and_run_instance 요청

10. nova-compute
    - Glance에서 이미지 다운로드
    - Neutron에 네트워크 요청
    - Cinder에 볼륨 연결 (필요시)
    - libvirt XML 생성
    - KVM으로 VM 생성

11. nova-compute → Database
    인스턴스 상태 업데이트 (status: ACTIVE)
```

### 2.3 Nova Scheduler

**Filtering (필터링):**
```python
# /etc/nova/nova.conf
[filter_scheduler]
enabled_filters = AvailabilityZoneFilter,
                  ComputeFilter,
                  ComputeCapabilitiesFilter,
                  ImagePropertiesFilter,
                  ServerGroupAntiAffinityFilter,
                  ServerGroupAffinityFilter
```

**주요 필터:**

- **AvailabilityZoneFilter**: 가용 영역 기반 필터링
- **ComputeFilter**: 활성 상태의 컴퓨트 노드만 선택
- **ComputeCapabilitiesFilter**: CPU, RAM, Disk 요구사항 충족 확인
- **ImagePropertiesFilter**: 이미지 속성과 호스트 capabilities 매칭
- **ServerGroupAntiAffinityFilter**: 인스턴스를 서로 다른 호스트에 배치

**Weighting (가중치 계산):**
```python
[filter_scheduler]
weight_classes = nova.scheduler.weights.all_weighers

# RAM Weigher: 가용 RAM이 많은 호스트 선호
ram_weight_multiplier = 1.0

# Disk Weigher: 가용 디스크가 많은 호스트 선호
disk_weight_multiplier = 1.0

# I/O operations Weigher
io_ops_weight_multiplier = -1.0  # I/O가 적은 호스트 선호
```

### 2.4 Placement Service

**리소스 추적:**
```bash
# Placement API를 통한 리소스 조회
curl -H "X-Auth-Token: $TOKEN" \
  http://controller:8778/placement/resource_providers

# 특정 리소스 프로바이더의 인벤토리
curl -H "X-Auth-Token: $TOKEN" \
  http://controller:8778/placement/resource_providers/{uuid}/inventories
```

**응답 예시:**
```json
{
  "resource_provider_generation": 5,
  "inventories": {
    "VCPU": {
      "allocation_ratio": 16.0,
      "total": 64,
      "reserved": 0,
      "step_size": 1,
      "min_unit": 1,
      "max_unit": 64
    },
    "MEMORY_MB": {
      "allocation_ratio": 1.5,
      "total": 131072,
      "reserved": 2048,
      "step_size": 1,
      "min_unit": 1,
      "max_unit": 131072
    }
  }
}
```

---

## Part 3: Cinder - 블록 스토리지

### 3.1 Cinder 아키텍처

**Cinder 컴포넌트:**
```
┌──────────────────────────────────────────────┐
│           cinder-api (Controller)            │
│  - REST API                                  │
│  - 볼륨 생성/삭제/연결 요청 처리              │
└────────────────┬─────────────────────────────┘
                 │ (RabbitMQ)
        ┌────────┴────────┬────────────────┐
        │                 │                │
┌───────▼────────┐ ┌──────▼──────┐ ┌──────▼──────────┐
│ cinder-        │ │ cinder-     │ │ cinder-backup   │
│ scheduler      │ │ volume      │ │                 │
└────────────────┘ └─────┬───────┘ └─────────────────┘
                         │
               ┌─────────┴──────────┬──────────┐
               │                    │          │
        ┌──────▼──────┐      ┌──────▼─────┐ ┌─▼─────┐
        │  LVM Driver │      │ Ceph Driver│ │  NFS  │
        └─────────────┘      └────────────┘ └───────┘
```

### 3.2 볼륨 생성 및 연결

**볼륨 생성:**
```bash
# OpenStack CLI
openstack volume create \
  --size 100 \
  --type ssd \
  --availability-zone nova \
  --description "Database volume" \
  db-volume-01

# 결과
+---------------------+--------------------------------------+
| Field               | Value                                |
+---------------------+--------------------------------------+
| id                  | 573e024d-5235-49ce-8332-be1576d323f8 |
| size                | 100                                  |
| availability_zone   | nova                                 |
| status              | creating                             |
| volume_type         | ssd                                  |
+---------------------+--------------------------------------+
```

**볼륨 연결 (Attach):**
```bash
# 인스턴스에 볼륨 연결
openstack server add volume \
  test-vm \
  db-volume-01 \
  --device /dev/vdb

# 인스턴스 내부에서 확인
lsblk
# NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
# vda    252:0    0   20G  0 disk
# └─vda1 252:1    0   20G  0 part /
# vdb    252:16   0  100G  0 disk

# 파티션 생성 및 마운트
sudo mkfs.ext4 /dev/vdb
sudo mkdir /data
sudo mount /dev/vdb /data
```

### 3.3 Cinder 백엔드 설정

**LVM 백엔드 (기본):**
```ini
# /etc/cinder/cinder.conf
[DEFAULT]
enabled_backends = lvm

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
volume_backend_name = LVM
iscsi_protocol = iscsi
iscsi_helper = tgtadm
```

**Ceph 백엔드:**
```ini
[ceph]
volume_driver = cinder.volume.drivers.rbd.RBDDriver
volume_backend_name = ceph
rbd_pool = volumes
rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_flatten_volume_from_snapshot = false
rbd_max_clone_depth = 5
rbd_store_chunk_size = 4
rados_connect_timeout = -1
rbd_user = cinder
rbd_secret_uuid = 457eb676-33da-42ec-9a8c-9293d545c337
```

**멀티 백엔드:**
```ini
[DEFAULT]
enabled_backends = lvm,ceph,nfs

# 볼륨 타입 생성
openstack volume type create lvm-ssd
openstack volume type set lvm-ssd \
  --property volume_backend_name=LVM

openstack volume type create ceph-hdd
openstack volume type set ceph-hdd \
  --property volume_backend_name=ceph
```

### 3.4 볼륨 스냅샷 및 백업

**스냅샷:**
```bash
# 스냅샷 생성 (volume이 attached 상태에서도 가능)
openstack volume snapshot create \
  --volume db-volume-01 \
  --force \
  db-snapshot-20251124

# 스냅샷에서 볼륨 생성
openstack volume create \
  --snapshot db-snapshot-20251124 \
  --size 100 \
  db-volume-02
```

**백업 (Swift/Ceph):**
```bash
# 백업 생성
openstack volume backup create \
  --name db-backup-daily \
  db-volume-01

# 백업에서 복원
openstack volume create \
  --backup db-backup-daily \
  --size 100 \
  restored-volume
```

---

## Part 4: Glance - 이미지 서비스

### 4.1 Glance 아키텍처

**Glance 컴포넌트:**

- **glance-api**: REST API 제공, 이미지 메타데이터 관리
- **glance-registry** (deprecated): 메타데이터 저장 (2025.1에서 제거됨)
- **Backend Store**: 실제 이미지 데이터 저장 (Swift, Ceph, Filesystem, Cinder)

**이미지 저장소 옵션:**
```
┌─────────────────────────────────────────┐
│          glance-api                      │
└────────┬────────────────────────────────┘
         │
    ┌────┴────┬──────────┬──────────┬──────────┐
    │         │          │          │          │
┌───▼──┐ ┌───▼───┐ ┌────▼────┐ ┌───▼────┐ ┌──▼──────┐
│ File │ │ Swift │ │  Ceph   │ │ Cinder │ │  HTTP   │
│System│ │       │ │  (RBD)  │ │        │ │(Read-Only)│
└──────┘ └───────┘ └─────────┘ └────────┘ └─────────┘
```

### 4.2 이미지 업로드 및 관리

**이미지 업로드:**
```bash
# QCOW2 이미지 업로드
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  --file jammy-server-cloudimg-amd64.img \
  ubuntu-22.04

# 이미지 속성 추가
openstack image set ubuntu-22.04 \
  --property os_distro=ubuntu \
  --property os_version=22.04 \
  --property hw_disk_bus=virtio \
  --property hw_vif_model=virtio
```

**멀티 스토어 설정 (2025.1):**
```ini
# /etc/glance/glance-api.conf
[DEFAULT]
enabled_backends = fast:rbd, cheap:file

[glance_store]
default_backend = fast

[fast]
rbd_store_pool = images
rbd_store_user = glance
rbd_store_ceph_conf = /etc/ceph/ceph.conf
store_description = "Fast SSD storage via Ceph"

[cheap]
filesystem_store_datadir = /var/lib/glance/images/
store_description = "Cheap HDD storage"
```

**스토어 선택하여 이미지 업로드:**
```bash
openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --file ubuntu-22.04.qcow2 \
  --store fast \
  ubuntu-22.04-fast
```

### 4.3 Glance Image Cache for Cinder

**이미지 캐싱 활성화 (2025.1 Best Practice):**
```ini
# /etc/glance/glance-api.conf
[DEFAULT]
image_cache_dir = /var/lib/glance/image-cache
image_cache_max_size = 107374182400  # 100GB

[glance_store]
default_store = cinder
cinder_catalog_info = volumev3::internalURL
cinder_volume_type = ssd

# Cinder store specific
cinder_state_transition_timeout = 300
cinder_store_auth_address = http://controller:5000/v3
cinder_store_user_name = cinder
cinder_store_password = secret
cinder_store_project_name = service
```

**성능 향상:**

- 이미지 캐싱 활성화 시 볼륨 생성 시간 **50-70% 단축**
- Glance Image Cache for Cinder는 Pure Storage, NetApp 등 엔터프라이즈 스토리지에서 권장

---

## Part 5: Ironic - 베어메탈 프로비저닝

### 5.1 Ironic 아키텍처

**Ironic의 역할:**
Ironic은 가상 머신 대신 **물리 서버(베어메탈)**를 프로비저닝하는 OpenStack 서비스입니다.

**Ironic 컴포넌트:**
```
┌──────────────────────────────────────────────┐
│              Nova (Compute)                   │
│  - 베어메탈을 VM처럼 관리                     │
└────────────────┬─────────────────────────────┘
                 │ (Ironic virt driver)
┌────────────────▼─────────────────────────────┐
│           ironic-api                          │
│  - REST API                                   │
└────────────────┬─────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼────────┐ ┌──────▼──────────────┐
│ ironic-        │ │ ironic-conductor    │
│ conductor      │ │  - 프로비저닝 로직  │
│  (main)        │ │  - 하드웨어 제어    │
└────────────────┘ └──────┬──────────────┘
                          │
                ┌─────────┴─────────┬──────────┐
                │                   │          │
         ┌──────▼──────┐     ┌──────▼─────┐ ┌─▼────────┐
         │ IPMI Driver │     │   Redfish  │ │  iLO     │
         │             │     │   Driver   │ │  Driver  │
         └──────┬──────┘     └─────┬──────┘ └──┬───────┘
                │                  │           │
         ┌──────▼──────────────────▼───────────▼────┐
         │     Physical Servers (Bare Metal)        │
         └──────────────────────────────────────────┘
```

### 5.2 Ironic + Nova 통합

**Nova에서 베어메탈 사용:**
```bash
# 1. Ironic node 등록
openstack baremetal node create \
  --driver ipmi \
  --name node-01 \
  --driver-info ipmi_address=192.168.1.100 \
  --driver-info ipmi_username=admin \
  --driver-info ipmi_password=secret

# 2. 노드 포트 추가 (MAC 주소)
openstack baremetal port create \
  --node node-01 \
  aa:bb:cc:dd:ee:ff

# 3. 리소스 속성 설정
openstack baremetal node set node-01 \
  --property cpus=32 \
  --property memory_mb=131072 \
  --property local_gb=1000 \
  --property cpu_arch=x86_64

# 4. 노드를 available 상태로 변경
openstack baremetal node manage node-01
openstack baremetal node provide node-01

# 5. Nova flavor 생성 (베어메탈용)
openstack flavor create \
  --ram 131072 \
  --disk 1000 \
  --vcpus 32 \
  --property resources:CUSTOM_BAREMETAL=1 \
  --property resources:VCPU=0 \
  --property resources:MEMORY_MB=0 \
  --property resources:DISK_GB=0 \
  baremetal-large

# 6. 인스턴스 생성 (베어메탈)
openstack server create \
  --flavor baremetal-large \
  --image ubuntu-22.04 \
  --network provisioning-net \
  my-baremetal-server
```

### 5.3 프로비저닝 플로우

**Ironic 프로비저닝 단계:**
```
1. Nova → Ironic: 베어메탈 인스턴스 요청
   ↓
2. Ironic: 노드 검증 (validate)
   - Power interface 체크
   - Deploy interface 체크
   ↓
3. Ironic: 노드 전원 켜기 (IPMI/Redfish)
   ↓
4. Ironic: PXE 부팅
   - TFTP 서버에서 커널/ramdisk 로드
   - Provisioning 네트워크로 부팅
   ↓
5. IPA (Ironic Python Agent): 노드에서 실행
   - 디스크 파티셔닝
   - Glance에서 이미지 다운로드
   - 디스크에 이미지 쓰기
   ↓
6. Ironic: 부트로더 설치 (GRUB)
   ↓
7. Ironic: 노드 재부팅
   ↓
8. 노드: 로컬 디스크에서 부팅
   ↓
9. Ironic → Nova: 프로비저닝 완료 알림
```

### 5.4 네트워크 설계 (2025 Best Practice)

**프로비저닝 네트워크 분리:**
```
┌──────────────────────────────────────────────┐
│         Management Network (VLAN 10)         │
│  - Ironic API, Conductor                     │
│  - 관리자 접근                                │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│       Provisioning Network (VLAN 20)         │
│  - PXE/TFTP                                  │
│  - 엔드 유저 접근 불가 (보안)                 │
│  - 인터넷 접근 불가 (권장)                    │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│         Tenant Network (VLAN 30+)            │
│  - 프로비저닝 완료 후 사용                    │
│  - 사용자 워크로드                            │
└──────────────────────────────────────────────┘
```

---

## Part 6: Kolla-Ansible 프로덕션 배포

### 6.1 Kolla-Ansible 개요

**Kolla의 미션 (2025.1):**
> Kolla's mission is to provide production-ready containers and deployment tools for operating OpenStack clouds.

**핵심 특징:**

- **컨테이너 기반**: 모든 OpenStack 서비스를 Docker/Podman 컨테이너로 실행
- **Ansible 자동화**: Playbook을 통한 선언적 배포
- **HA 지원**: HAProxy, Keepalived를 통한 고가용성
- **롤링 업그레이드**: 무중단 업그레이드 지원

### 6.2 하드웨어 요구사항

**최소 요구사항 (개발/테스트):**

- **네트워크 인터페이스**: 2개 (Management, External)
- **메모리**: 8GB
- **디스크**: 40GB

**프로덕션 권장사항:**

- **Controller Node**: 3대 (HA)
  - CPU: 8 cores
  - RAM: 64GB
  - Disk: 500GB SSD (OS + 컨테이너)
- **Compute Node**: N대
  - CPU: 32+ cores
  - RAM: 128GB+
  - Disk: 1TB+ (인스턴스 ephemeral storage)
- **Storage Node**: 3+ 대 (Ceph)
  - CPU: 8 cores
  - RAM: 64GB
  - Disk: 10TB+ HDD (데이터), 100GB SSD (journal)

### 6.3 Kolla-Ansible 설치 및 설정

**Step 1: 환경 준비**
```bash
# 1. 의존성 설치 (배포 서버)
sudo apt update
sudo apt install -y python3-dev libffi-dev gcc libssl-dev python3-venv

# 2. Python 가상환경 생성
python3 -m venv kolla-venv
source kolla-venv/bin/activate

# 3. Kolla-Ansible 설치
pip install -U pip
pip install 'ansible-core>=2.16,<2.17'
pip install kolla-ansible==20.2.0  # 2025.1 Epoxy

# 4. Kolla 설정 디렉토리 생성
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla

# 5. 샘플 설정 복사
cp kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp kolla-venv/share/kolla-ansible/ansible/inventory/* .
```

**Step 2: Inventory 설정**
```ini
# multinode inventory
[control]
controller01 ansible_host=192.168.1.10
controller02 ansible_host=192.168.1.11
controller03 ansible_host=192.168.1.12

[network]
controller[01:03]

[compute]
compute01 ansible_host=192.168.1.21
compute02 ansible_host=192.168.1.22
compute03 ansible_host=192.168.1.23

[storage]
storage01 ansible_host=192.168.1.31
storage02 ansible_host=192.168.1.32
storage03 ansible_host=192.168.1.33

[monitoring]
controller01

[deployment]
localhost ansible_connection=local
```

**Step 3: globals.yml 설정**
```yaml
# /etc/kolla/globals.yml
---
kolla_base_distro: "ubuntu"
kolla_install_type: "source"
openstack_release: "2025.1"

# 네트워크 설정
network_interface: "eth0"           # Management 네트워크
neutron_external_interface: "eth1"  # External 네트워크
kolla_internal_vip_address: "192.168.1.100"  # VIP (HAProxy)

# OpenStack 서비스 활성화
enable_haproxy: "yes"
enable_keepalived: "yes"
enable_mariadb: "yes"
enable_memcached: "yes"
enable_rabbitmq: "yes"

enable_keystone: "yes"
enable_glance: "yes"
enable_nova: "yes"
enable_neutron: "yes"
enable_cinder: "yes"
enable_horizon: "yes"

enable_ironic: "yes"
enable_ironic_neutron_agent: "yes"

# Ceph 백엔드 (선택적)
enable_ceph: "yes"
glance_backend_ceph: "yes"
cinder_backend_ceph: "yes"
nova_backend_ceph: "yes"

# 모니터링
enable_prometheus: "yes"
enable_grafana: "yes"

# 로그 수준
openstack_logging_debug: "False"
```

**Step 4: 배포 실행**
```bash
# 1. Ansible 연결 테스트
ansible -i multinode all -m ping

# 2. 의존성 설치
kolla-ansible -i multinode bootstrap-servers

# 3. 사전 배포 검사
kolla-ansible -i multinode prechecks

# 4. 배포 실행
kolla-ansible -i multinode deploy

# 5. 초기 설정 (admin-openrc.sh 생성)
kolla-ansible -i multinode post-deploy
```

### 6.4 운영 및 유지보수

**컨테이너 상태 확인:**
```bash
# 모든 Kolla 컨테이너 확인
docker ps --format "table {{.Names}}\t{{.Status}}"

# 특정 서비스 로그 확인
docker logs nova_compute

# 컨테이너 재시작
docker restart nova_compute
```

**2025.1 새로운 기능 - kolla-ansible check:**
```bash
# 모든 호스트의 컨테이너 상태 진단
kolla-ansible -i multinode check

# 결과: 누락, 미실행, 비정상 컨테이너 목록 반환
```

**업그레이드:**
```bash
# 1. 백업
kolla-ansible -i multinode mariadb_backup

# 2. 새 버전으로 업그레이드
pip install --upgrade kolla-ansible

# 3. 롤링 업그레이드 실행
kolla-ansible -i multinode upgrade
```

**재구성 (Reconfigure):**
```bash
# globals.yml 수정 후 적용
kolla-ansible -i multinode reconfigure
```

---

## 🛠️ 실습 가이드

### 실습 1: All-in-One OpenStack 배포

**목표:** 단일 서버에 OpenStack 배포 (학습용)

```bash
# 1. 시스템 요구사항 확인
# - Ubuntu 22.04
# - 8GB RAM
# - 40GB Disk
# - 2 Network Interfaces

# 2. Kolla-Ansible 설치 (위의 6.3 Step 1)

# 3. all-in-one inventory 사용
cp kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one .

# 4. globals.yml 설정
cat > /etc/kolla/globals.yml <<EOF
---
kolla_base_distro: "ubuntu"
kolla_install_type: "source"
network_interface: "eth0"
neutron_external_interface: "eth1"
kolla_internal_vip_address: "192.168.1.10"
enable_haproxy: "no"  # Single node
enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"
EOF

# 5. 배포
kolla-ansible -i all-in-one bootstrap-servers
kolla-ansible -i all-in-one prechecks
kolla-ansible -i all-in-one deploy
kolla-ansible -i all-in-one post-deploy

# 6. OpenStack CLI 설정
pip install python-openstackclient
source /etc/kolla/admin-openrc.sh

# 7. 환경 확인
openstack service list
openstack compute service list
openstack network agent list
```

### 실습 2: 인스턴스 생성 워크플로우

```bash
# 1. 네트워크 생성
openstack network create --external \
  --provider-network-type flat \
  --provider-physical-network physnet1 \
  public

openstack subnet create --network public \
  --subnet-range 192.168.100.0/24 \
  --gateway 192.168.100.1 \
  --allocation-pool start=192.168.100.100,end=192.168.100.200 \
  public-subnet

# 2. 프라이빗 네트워크
openstack network create private
openstack subnet create --network private \
  --subnet-range 10.0.0.0/24 \
  --dns-nameserver 8.8.8.8 \
  private-subnet

# 3. 라우터
openstack router create router1
openstack router set --external-gateway public router1
openstack router add subnet router1 private-subnet

# 4. Security Group
openstack security group create web
openstack security group rule create --protocol tcp --dst-port 80 web
openstack security group rule create --protocol tcp --dst-port 443 web
openstack security group rule create --protocol tcp --dst-port 22 web

# 5. Keypair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/openstack_key -N ""
openstack keypair create --public-key ~/.ssh/openstack_key.pub mykey

# 6. Flavor
openstack flavor create --ram 2048 --disk 20 --vcpus 2 m1.small

# 7. 이미지 업로드 (이미 있으면 skip)
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
openstack image create --disk-format qcow2 --file jammy-server-cloudimg-amd64.img ubuntu-22.04

# 8. 인스턴스 생성
openstack server create \
  --flavor m1.small \
  --image ubuntu-22.04 \
  --network private \
  --security-group web \
  --key-name mykey \
  test-vm

# 9. Floating IP 할당
FLOATING_IP=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip test-vm $FLOATING_IP

# 10. SSH 접속
ssh -i ~/.ssh/openstack_key ubuntu@$FLOATING_IP
```

### 실습 3: Cinder 볼륨 및 스냅샷

```bash
# 1. 볼륨 생성
openstack volume create --size 50 data-volume

# 2. 인스턴스에 연결
openstack server add volume test-vm data-volume

# 3. 인스턴스 내부에서 포맷 및 마운트
ssh ubuntu@$FLOATING_IP
sudo mkfs.ext4 /dev/vdb
sudo mkdir /data
sudo mount /dev/vdb /data
echo "Hello from volume" | sudo tee /data/test.txt

# 4. 스냅샷 생성 (attached 상태에서)
openstack volume snapshot create --volume data-volume --force data-snapshot

# 5. 스냅샷에서 새 볼륨 생성
openstack volume create --snapshot data-snapshot --size 50 data-volume-clone

# 6. 백업 (Swift/Ceph 필요)
openstack volume backup create --name data-backup data-volume
```

---

## 💻 예제 코드

### 예제 1: Python으로 OpenStack 자동화

```python
# openstack_automation.py
from openstack import connection
import time

# 연결 생성
conn = connection.Connection(
    auth_url='http://192.168.1.10:5000/v3',
    project_name='admin',
    username='admin',
    password='admin_password',
    user_domain_id='default',
    project_domain_id='default'
)

def create_instance(name, flavor_name, image_name, network_name):
    """인스턴스 생성 및 Floating IP 할당"""

    # 1. Flavor 조회
    flavor = conn.compute.find_flavor(flavor_name)

    # 2. 이미지 조회
    image = conn.compute.find_image(image_name)

    # 3. 네트워크 조회
    network = conn.network.find_network(network_name)

    # 4. 인스턴스 생성
    print(f"Creating instance {name}...")
    server = conn.compute.create_server(
        name=name,
        flavor_id=flavor.id,
        image_id=image.id,
        networks=[{"uuid": network.id}]
    )

    # 5. ACTIVE 상태 대기
    server = conn.compute.wait_for_server(server, status='ACTIVE', wait=300)
    print(f"Instance {name} is ACTIVE")

    # 6. Floating IP 생성 및 할당
    public_network = conn.network.find_network('public')
    floating_ip = conn.network.create_ip(floating_network_id=public_network.id)

    conn.compute.add_floating_ip_to_server(server, floating_ip.floating_ip_address)
    print(f"Assigned Floating IP: {floating_ip.floating_ip_address}")

    return server, floating_ip.floating_ip_address

def create_volume_and_attach(server_id, size, device='/dev/vdb'):
    """볼륨 생성 및 연결"""

    # 1. 볼륨 생성
    volume = conn.block_storage.create_volume(size=size)

    # 2. available 상태 대기
    volume = conn.block_storage.wait_for_status(volume, status='available', wait=120)
    print(f"Volume {volume.id} created")

    # 3. 인스턴스에 연결
    conn.compute.create_volume_attachment(
        server=server_id,
        volume_id=volume.id,
        device=device
    )

    print(f"Volume attached to {server_id} as {device}")
    return volume

# 실행
if __name__ == '__main__':
    # 인스턴스 생성
    server, floating_ip = create_instance(
        name='web-server-01',
        flavor_name='m1.small',
        image_name='ubuntu-22.04',
        network_name='private'
    )

    # 볼륨 생성 및 연결
    volume = create_volume_and_attach(server.id, size=100)

    print(f"\n=== Summary ===")
    print(f"Server ID: {server.id}")
    print(f"Floating IP: {floating_ip}")
    print(f"Volume ID: {volume.id}")
    print(f"SSH: ssh ubuntu@{floating_ip}")
```

### 예제 2: Terraform으로 OpenStack 인프라 구성

```hcl
# main.tf
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
    }
  }
}

provider "openstack" {
  auth_url    = "http://192.168.1.10:5000/v3"
  user_name   = "admin"
  password    = var.admin_password
  tenant_name = "admin"
  domain_name = "Default"
}

# 네트워크
resource "openstack_networking_network_v2" "app_network" {
  name           = "app-network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "app_subnet" {
  name       = "app-subnet"
  network_id = openstack_networking_network_v2.app_network.id
  cidr       = "10.0.1.0/24"
  ip_version = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# 라우터
data "openstack_networking_network_v2" "public" {
  name = "public"
}

resource "openstack_networking_router_v2" "app_router" {
  name                = "app-router"
  external_network_id = data.openstack_networking_network_v2.public.id
}

resource "openstack_networking_router_interface_v2" "app_router_interface" {
  router_id = openstack_networking_router_v2.app_router.id
  subnet_id = openstack_networking_subnet_v2.app_subnet.id
}

# Security Group
resource "openstack_compute_secgroup_v2" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

# Keypair
resource "openstack_compute_keypair_v2" "app_key" {
  name       = "app-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# 인스턴스
resource "openstack_compute_instance_v2" "web_servers" {
  count           = 3
  name            = "web-${count.index + 1}"
  image_name      = "ubuntu-22.04"
  flavor_name     = "m1.small"
  key_pair        = openstack_compute_keypair_v2.app_key.name
  security_groups = [openstack_compute_secgroup_v2.web_sg.name]

  network {
    uuid = openstack_networking_network_v2.app_network.id
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "Hello from web-${count.index + 1}" > /var/www/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF
}

# Floating IP
resource "openstack_networking_floatingip_v2" "web_fip" {
  count = 3
  pool  = "public"
}

resource "openstack_compute_floatingip_associate_v2" "web_fip_assoc" {
  count       = 3
  floating_ip = openstack_networking_floatingip_v2.web_fip[count.index].address
  instance_id = openstack_compute_instance_v2.web_servers[count.index].id
}

# 볼륨
resource "openstack_blockstorage_volume_v3" "web_data" {
  count = 3
  name  = "web-data-${count.index + 1}"
  size  = 100
}

resource "openstack_compute_volume_attach_v2" "web_vol_attach" {
  count       = 3
  instance_id = openstack_compute_instance_v2.web_servers[count.index].id
  volume_id   = openstack_blockstorage_volume_v3.web_data[count.index].id
}

# Output
output "web_server_ips" {
  value = openstack_networking_floatingip_v2.web_fip[*].address
}
```

---

## 📚 참고 자료

### 공식 문서
1. **OpenStack 2025.1 (Epoxy) Documentation**
   - [OpenStack Docs](https://docs.openstack.org/2025.1/)
   - [Nova Documentation](https://docs.openstack.org/nova/latest/)
   - [Cinder Documentation](https://docs.openstack.org/cinder/latest/)
   - [Glance Documentation](https://docs.openstack.org/glance/2025.1/)
   - [Ironic Documentation](https://docs.openstack.org/ironic/latest/)

2. **Kolla-Ansible**
   - [Kolla-Ansible Documentation](https://docs.openstack.org/kolla-ansible/latest/)
   - [2025.1 Release Notes](https://docs.openstack.org/releasenotes/kolla-ansible/2025.1.html)
   - [Quick Start Guide](https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html)

3. **API Reference**
   - [Nova API](https://docs.openstack.org/api-ref/compute/)
   - [Cinder API](https://docs.openstack.org/api-ref/block-storage/)
   - [Glance API](https://docs.openstack.org/api-ref/image/)

### 2025 Best Practices
1. [Ironic Common Considerations](https://docs.openstack.org/ironic/2025.1/install/refarch/common.html)
2. [Pure Storage OpenStack Cinder Driver Best Practices](https://support-be.purestorage.com/bundle/Pure_Storage_OpenStack_2025.1_Epoxy_Cinder_Driver_Best_Practices/)
3. [Glance Image Cache for Cinder](https://pure-storage-openstack-docs.readthedocs.io/en/2025.1/glance/ch_glance-configuration.html)

### 튜토리얼
1. [Deploy Production Ready OpenStack Using Kolla Ansible](https://achchusnulchikam.medium.com/deploy-production-ready-openstack-using-kolla-ansible-9cd1d1f210f1)
2. [Automated Multinode OpenStack Deployment](https://openmetal.io/resources/blog/automated-multinode-openstack-deployment-with-kolla-ansible/)
3. [OpenStack Cinder Comprehensive Guide](https://dev.to/raza_shaikh_eb0dd7d1ca772/openstack-cinder-comprehensive-guide-to-block-storage-management-in-cloud-environments-30cl)

---

## ✅ 학습 체크리스트

### 기본 개념
- [ ] OpenStack 서비스 아키텍처 및 상호작용 이해
- [ ] Keystone 인증 플로우 이해
- [ ] RabbitMQ를 통한 RPC 통신 이해
- [ ] Placement API의 역할 이해

### Nova
- [ ] Nova 컴포넌트 (API, Scheduler, Compute, Conductor) 역할 이해
- [ ] 인스턴스 생성 플로우 (11단계) 이해
- [ ] Nova Scheduler 필터링 및 가중치 계산
- [ ] Placement API를 통한 리소스 추적

### Cinder
- [ ] Cinder 아키텍처 및 볼륨 생성 플로우
- [ ] LVM, Ceph, NFS 백엔드 설정
- [ ] 볼륨 타입 및 멀티 백엔드 구성
- [ ] 볼륨 스냅샷 및 백업

### Glance
- [ ] Glance 스토어 백엔드 (File, Swift, Ceph, Cinder)
- [ ] 멀티 스토어 설정 (2025.1)
- [ ] Glance Image Cache for Cinder 활성화
- [ ] 이미지 메타데이터 관리

### Ironic
- [ ] Ironic 아키텍처 및 Nova 통합 방식
- [ ] IPMI/Redfish 드라이버를 통한 하드웨어 관리
- [ ] 베어메탈 프로비저닝 플로우
- [ ] 프로비저닝 네트워크 설계

### Kolla-Ansible
- [ ] Kolla-Ansible을 활용한 All-in-One 배포
- [ ] 멀티노드 HA 구성
- [ ] globals.yml 및 inventory 설정
- [ ] 롤링 업그레이드 및 재구성

---

## 🎓 다음 단계

1. **[Ch2.가상화_기술.md](./Ch2.가상화_기술.md)**
   - KVM/QEMU 아키텍처 심화
   - Linux Kernel 가상화 메커니즘
   - CPU, 메모리, I/O 가상화
   - 성능 최적화 및 튜닝

2. **심화 주제**
   - **TripleO**: OpenStack on OpenStack 배포
   - **OpenStack Federation**: 멀티 리전 통합
   - **Magnum**: Container Orchestration (Kubernetes) as a Service

3. **실전 프로젝트**
   - 프로덕션 환경 OpenStack 클러스터 구축
   - Ceph 스토리지 백엔드 통합
   - Prometheus + Grafana 모니터링 구성

---

**마지막 업데이트:** 2025-11-24
**다음 챕터:** [Ch2.가상화_기술.md](./Ch2.가상화_기술.md)
