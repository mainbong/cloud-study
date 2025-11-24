# Ch2. 가상화 기술 - KVM/QEMU 심화

## 📋 개요

가상화는 클라우드 컴퓨팅의 핵심 기술로, 물리 하드웨어를 추상화하여 여러 가상 머신이 하나의 물리 서버에서 독립적으로 실행될 수 있도록 합니다. 본 장에서는 Linux 커널 기반의 가상화 솔루션인 KVM(Kernel-based Virtual Machine)과 QEMU의 아키텍처를 심층 분석하고, CPU, 메모리, I/O 가상화 메커니즘을 이해하며, 프로덕션 환경에서의 성능 최적화 기법을 학습합니다.

2025년 현재, **QEMU 10.2**와 **KVM**은 Intel TDX, AMD SEV를 통한 기밀 컴퓨팅(Confidential Computing), ARM 중첩 가상화 개선, RISC-V 지원 등 최신 기능을 제공하고 있습니다.

## 🎯 학습 목표

1. **KVM/QEMU 아키텍처 이해**
   - KVM과 QEMU의 역할 및 상호작용
   - 하드웨어 가상화 확장 (Intel VT-x, AMD-V)
   - Libvirt를 통한 관리 계층

2. **CPU 가상화 마스터하기**
   - vCPU 스케줄링 및 오버커밋
   - CPU 피닝 및 NUMA 인식
   - CPU 모델 및 기능 플래그

3. **메모리 가상화 심화**
   - EPT/NPT를 통한 2단계 페이지 테이블
   - Huge Pages (2MB, 1GB)
   - Memory Ballooning 및 KSM

4. **I/O 가상화 및 성능 최적화**
   - VirtIO 드라이버 (virtio-blk, virtio-scsi, virtio-net)
   - VFIO 및 SR-IOV for PCI 패스스루
   - 디스크 I/O 스케줄러 튜닝

5. **NUMA 아키텍처 및 최적화**
   - NUMA 노드 및 메모리 지역성
   - vCPU와 메모리의 NUMA 정렬
   - 성능 영향 분석

6. **프로덕션 성능 튜닝**
   - 벤치마킹 및 모니터링
   - 실전 튜닝 체크리스트
   - 트러블슈팅

---

## Part 1: KVM/QEMU 아키텍처

### 1.1 KVM과 QEMU의 역할

**KVM (Kernel-based Virtual Machine):**

- Linux 커널 모듈 (`kvm.ko`, `kvm-intel.ko`, `kvm-amd.ko`)
- 하드웨어 가상화 확장 활용 (Intel VT-x, AMD-V)
- CPU와 메모리 가상화 제공
- Type-1 Hypervisor로 동작

**QEMU (Quick Emulator):**

- 사용자 공간 프로세스
- I/O 장치 에뮬레이션 (디스크, 네트워크, GPU 등)
- 동적 바이너리 변환 (TCG - Tiny Code Generator)
- KVM과 함께 사용 시 하드웨어 가속 활용

**통합 아키텍처:**
```
┌─────────────────────────────────────────────────────────┐
│                    Guest VM (Virtual Machine)           │
│  ┌──────────────────────────────────────────────────┐   │
│  │   Guest OS (Linux/Windows)                       │   │
│  │   Applications                                   │   │
│  └──────────────────────────────────────────────────┘   │
│         │                                                │
│         ├─ vCPU ──┐                                      │
│         ├─ vMem ──┼─ Virtualized Hardware              │
│         └─ vI/O ──┘                                      │
└─────────┬───────────────────────────────┬───────────────┘
          │                               │
┌─────────▼────────────┐       ┌──────────▼──────────────┐
│  KVM (Kernel Space)  │       │   QEMU (User Space)     │
│  - CPU virtualization│       │  - Device emulation     │
│  - Memory management │◄──────┤  - I/O handling         │
│  - /dev/kvm interface│ ioctl │  - VM process           │
└──────────┬───────────┘       └─────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────────┐
│              Linux Kernel (Host OS)                      │
│  - Process Scheduler                                     │
│  - Memory Manager                                        │
│  - Hardware Drivers                                      │
└──────────┬───────────────────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────────┐
│            Physical Hardware                             │
│  - CPU (Intel VT-x / AMD-V)                              │
│  - Memory (RAM)                                          │
│  - I/O Devices (NIC, Disk, GPU)                          │
└──────────────────────────────────────────────────────────┘
```

### 1.2 하드웨어 가상화 확장

**Intel VT-x (Virtualization Technology):**

- **VMX (Virtual Machine Extensions)**: Root 모드와 Non-root 모드
- **EPT (Extended Page Tables)**: 2단계 주소 변환
- **VPID (Virtual Processor ID)**: TLB 태깅으로 컨텍스트 스위칭 최적화
- **VT-d (I/O Virtualization)**: IOMMU를 통한 DMA 리매핑

**AMD-V (AMD Virtualization):**

- **SVM (Secure Virtual Machine)**: Host 모드와 Guest 모드
- **NPT (Nested Page Tables)**: EPT와 동일한 2단계 페이지 테이블
- **ASID (Address Space Identifier)**: VPID와 동일
- **AMD-Vi (IOMMU)**: VT-d와 동일

**하드웨어 지원 확인:**
```bash
# Intel VT-x 지원 확인
grep -E 'vmx' /proc/cpuinfo

# AMD-V 지원 확인
grep -E 'svm' /proc/cpuinfo

# KVM 모듈 로드 확인
lsmod | grep kvm
# kvm_intel (Intel)
# kvm_amd (AMD)

# /dev/kvm 장치 파일 확인
ls -l /dev/kvm
# crw-rw-rw- 1 root kvm 10, 232 Nov 24 10:00 /dev/kvm
```

### 1.3 Libvirt 관리 계층

**Libvirt 아키텍처:**
```
┌──────────────────────────────────────────┐
│    Management Tools                       │
│  - virsh (CLI)                            │
│  - virt-manager (GUI)                     │
│  - OpenStack Nova                         │
└──────────────┬───────────────────────────┘
               │ API
┌──────────────▼───────────────────────────┐
│          libvirtd (Daemon)                │
│  - VM lifecycle management                │
│  - XML-based configuration                │
│  - Storage/Network pools                  │
└──────────────┬───────────────────────────┘
               │ Driver Interface
    ┌──────────┼──────────┬──────────┐
    │          │          │          │
┌───▼──┐  ┌───▼───┐  ┌───▼───┐  ┌──▼────┐
│ QEMU │  │  LXC  │  │  Xen  │  │ VMware│
│Driver│  │Driver │  │Driver │  │Driver │
└──────┘  └───────┘  └───────┘  └───────┘
```

**Libvirt XML 도메인 정의:**
```xml
<domain type='kvm'>
  <name>test-vm</name>
  <memory unit='GiB'>4</memory>
  <vcpu placement='static'>2</vcpu>

  <!-- CPU 설정 -->
  <cpu mode='host-passthrough' check='none'>
    <topology sockets='1' dies='1' cores='2' threads='1'/>
    <numa>
      <cell id='0' cpus='0-1' memory='4' unit='GiB'/>
    </numa>
  </cpu>

  <!-- OS 부팅 -->
  <os>
    <type arch='x86_64' machine='pc-q35-7.2'>hvm</type>
    <boot dev='hd'/>
  </os>

  <!-- 디스크 -->
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native'/>
      <source file='/var/lib/libvirt/images/test-vm.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>

    <!-- 네트워크 -->
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>

    <!-- VNC 콘솔 -->
    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'/>
  </devices>
</domain>
```

---

## Part 2: CPU 가상화

### 2.1 vCPU와 물리 CPU 매핑

**vCPU 스케줄링:**
KVM에서 각 vCPU는 Linux 커널의 일반 프로세스 스레드로 구현됩니다. CFS (Completely Fair Scheduler)가 vCPU 스레드를 스케줄링합니다.

```bash
# QEMU 프로세스 및 vCPU 스레드 확인
ps -eLf | grep qemu-system-x86_64

# 예시 출력:
# qemu      1234  1233  1234  ... qemu-system-x86_64 (main thread)
# qemu      1234  1233  1235  ... CPU 0/KVM          (vCPU 0)
# qemu      1234  1233  1236  ... CPU 1/KVM          (vCPU 1)
```

### 2.2 CPU 오버커밋

**오버커밋 비율:**
```
vCPU 오버커밋 비율 = (총 vCPU 수) / (물리 CPU 코어 수)

예시:

- 물리 CPU: 32 cores
- VM 1: 8 vCPUs
- VM 2: 8 vCPUs
- VM 3: 8 vCPUs
- VM 4: 8 vCPUs
- 오버커밋 비율 = 32 / 32 = 1:1 (이상적)

오버커밋 (aggressive):

- 물리 CPU: 32 cores
- VM 10개 x 8 vCPUs = 80 vCPUs
- 오버커밋 비율 = 80 / 32 = 2.5:1
```

**권장사항:**

- **프로덕션**: 1:1 ~ 2:1
- **개발/테스트**: 4:1 ~ 8:1
- **VDI (Virtual Desktop)**: 8:1 ~ 16:1 (CPU idle이 높음)

### 2.3 CPU 피닝 (Pinning)

**CPU 피닝의 장점:**

- L1/L2/L3 캐시 지역성 향상
- NUMA 노드 경계 교차 방지
- 예측 가능한 성능

**Libvirt를 통한 CPU 피닝:**
```xml
<domain type='kvm'>
  <vcpu placement='static'>4</vcpu>
  <cputune>
    <!-- vCPU 0 → Physical CPU 4 -->
    <vcpupin vcpu='0' cpuset='4'/>
    <!-- vCPU 1 → Physical CPU 5 -->
    <vcpupin vcpu='1' cpuset='5'/>
    <!-- vCPU 2 → Physical CPU 6 -->
    <vcpupin vcpu='2' cpuset='6'/>
    <!-- vCPU 3 → Physical CPU 7 -->
    <vcpupin vcpu='3' cpuset='7'/>

    <!-- Emulator 스레드 피닝 -->
    <emulatorpin cpuset='0-1'/>

    <!-- I/O 스레드 피닝 -->
    <iothreadpin iothread='1' cpuset='2-3'/>
  </cputune>
</domain>
```

**virsh를 통한 동적 피닝:**
```bash
# vCPU 0을 물리 CPU 4에 피닝
virsh vcpupin test-vm 0 4

# 현재 피닝 상태 확인
virsh vcpuinfo test-vm
```

### 2.4 CPU 모델 및 기능 플래그

**CPU 모드:**

- **host-passthrough**: 호스트 CPU 그대로 노출 (마이그레이션 제약)
- **host-model**: 호스트 CPU와 유사한 모델 (마이그레이션 가능)
- **custom**: 특정 CPU 모델 지정

```xml
<!-- host-passthrough: 최고 성능 -->
<cpu mode='host-passthrough' check='none'/>

<!-- host-model: 균형 -->
<cpu mode='host-model' check='partial'>
  <feature policy='require' name='vmx'/>  <!-- Nested virtualization -->
</cpu>

<!-- custom: 호환성 -->
<cpu mode='custom' match='exact' check='partial'>
  <model fallback='allow'>Skylake-Server</model>
  <feature policy='require' name='avx2'/>
  <feature policy='disable' name='mpx'/>
</cpu>
```

**사용 가능한 CPU 모델 확인:**
```bash
# QEMU가 지원하는 모든 CPU 모델
qemu-system-x86_64 -cpu help

# Libvirt가 인식하는 CPU 모델
virsh cpu-models x86_64
```

---

## Part 3: 메모리 가상화

### 3.1 2단계 페이지 테이블 (EPT/NPT)

**전통적인 Shadow Page Table vs EPT/NPT:**

**Shadow Page Table (하드웨어 가상화 이전):**
```
Guest Virtual Address (GVA)
    │
    ▼ (Guest Page Table - 소프트웨어 관리)
Guest Physical Address (GPA)
    │
    ▼ (Shadow Page Table - Hypervisor 관리)
Host Physical Address (HPA)

문제점: 매 Guest 페이지 테이블 변경 시 VM Exit 발생 → 성능 저하
```

**EPT/NPT (하드웨어 2단계 변환):**
```
Guest Virtual Address (GVA)
    │
    ▼ (Guest Page Table - Guest OS 관리)
Guest Physical Address (GPA)
    │
    ▼ (EPT/NPT - 하드웨어 MMU)
Host Physical Address (HPA)

장점: VM Exit 감소, 하드웨어 가속 변환
```

### 3.2 Huge Pages

**Huge Pages의 이점:**

- **TLB Miss 감소**: 더 많은 메모리를 더 적은 TLB 엔트리로 커버
- **페이지 테이블 오버헤드 감소**: 페이지 테이블 크기 축소
- **성능 향상**: 대용량 메모리 워크로드에서 5-20% 성능 향상

**Huge Pages 타입:**

- **2MB Huge Pages**: 일반적으로 사용
- **1GB Huge Pages**: 대용량 메모리 (128GB+) VM에 권장

**호스트 설정:**
```bash
# 1. Huge Pages 할당 (2MB)
# 총 메모리의 80-90% 할당 권장
echo 20480 > /proc/sys/vm/nr_hugepages  # 20480 * 2MB = 40GB

# 영구 설정 (재부팅 후에도 유지)
cat >> /etc/sysctl.conf <<EOF
vm.nr_hugepages = 20480
vm.hugetlb_shm_group = 36  # kvm 그룹 GID
EOF

sysctl -p

# 2. 1GB Huge Pages 할당 (부팅 시)
# /etc/default/grub 수정
GRUB_CMDLINE_LINUX="default_hugepagesz=1G hugepagesz=1G hugepages=32"

# GRUB 업데이트
update-grub
reboot

# 3. Huge Pages 확인
cat /proc/meminfo | grep -i huge
# HugePages_Total:   20480
# HugePages_Free:    18432
# HugePages_Rsvd:        0
# HugePages_Surp:        0
# Hugepagesize:       2048 kB

# 4. Huge Pages 마운트
mkdir -p /dev/hugepages
mount -t hugetlbfs hugetlbfs /dev/hugepages

# /etc/fstab에 추가
echo "hugetlbfs /dev/hugepages hugetlbfs defaults 0 0" >> /etc/fstab
```

**Libvirt에서 Huge Pages 사용:**
```xml
<domain type='kvm'>
  <memory unit='GiB'>16</memory>
  <memoryBacking>
    <!-- 2MB Huge Pages -->
    <hugepages>
      <page size='2' unit='M'/>
    </hugepages>

    <!-- 1GB Huge Pages -->
    <!-- <page size='1' unit='G'/> -->

    <!-- Memory 잠금 (swap 방지) -->
    <locked/>
  </memoryBacking>
</domain>
```

### 3.3 Memory Ballooning

**Ballooning 개념:**
호스트가 메모리 압박을 받을 때, Guest에게 메모리 반환을 요청하는 메커니즘입니다.

```bash
# virtio-balloon 드라이버 확인 (Guest)
lsmod | grep virtio_balloon

# 동적 메모리 조정 (Host)
virsh setmem test-vm 2G --live

# 현재 메모리 사용량 확인
virsh dominfo test-vm | grep -i memory
```

**Libvirt 설정:**
```xml
<devices>
  <memballoon model='virtio'>
    <stats period='10'/>  <!-- 10초마다 통계 수집 -->
  </memballoon>
</devices>
```

### 3.4 KSM (Kernel Same-page Merging)

**KSM 동작:**
동일한 내용의 메모리 페이지를 하나로 합쳐 메모리 절약 (Copy-on-Write).

**KSM 활성화:**
```bash
# KSM 활성화
echo 1 > /sys/kernel/mm/ksm/run

# 스캔 파라미터 조정
echo 100 > /sys/kernel/mm/ksm/sleep_millisecs  # 스캔 간격
echo 1000 > /sys/kernel/mm/ksm/pages_to_scan   # 스캔할 페이지 수

# KSM 통계
cat /sys/kernel/mm/ksm/pages_sharing
cat /sys/kernel/mm/ksm/pages_shared
```

**주의사항:**

- CPU 오버헤드 발생 (스캔 비용)
- 보안 고려사항 (side-channel 공격 가능성)
- 프로덕션 환경에서는 신중하게 사용

---

## Part 4: I/O 가상화

### 4.1 VirtIO 아키텍처

**VirtIO란?**
KVM 환경에서 최적화된 반가상화(Paravirtualization) I/O 드라이버입니다.

**VirtIO 구조:**
```
┌──────────────────────────────────────┐
│        Guest OS                       │
│  ┌────────────────────────────────┐  │
│  │  VirtIO Frontend Driver        │  │
│  │  (virtio-blk, virtio-net, ...) │  │
│  └────────────┬───────────────────┘  │
│               │ virtqueue             │
└───────────────┼───────────────────────┘
                │ (Shared Memory)
┌───────────────▼───────────────────────┐
│  QEMU (Host)                          │
│  ┌────────────────────────────────┐  │
│  │  VirtIO Backend                │  │
│  │  (handles I/O requests)        │  │
│  └────────────┬───────────────────┘  │
└───────────────┼───────────────────────┘
                │
┌───────────────▼───────────────────────┐
│  Physical Device (Disk/NIC)           │
└───────────────────────────────────────┘
```

### 4.2 Disk I/O - virtio-blk vs virtio-scsi

**비교표 (2025 Best Practice):**

| 특징 | virtio-blk | virtio-scsi |
|------|-----------|-------------|
| 성능 | 높음 (낮은 레이턴시) | 매우 높음 (고부하) |
| Queue Depth | 제한적 | 깊음 (고부하 유리) |
| TRIM/UNMAP | 제한적 | 완전 지원 (SSD 필수) |
| 디스크 수 | 제한 (26개) | 무제한 |
| 사용 사례 | 웹서버, 파일서버 | DB, 메일서버, I/O 집약적 |

**virtio-blk 설정:**
```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
  <source file='/var/lib/libvirt/images/vm.qcow2'/>
  <target dev='vda' bus='virtio'/>
</disk>
```

**virtio-scsi 설정 (권장):**
```xml
<!-- SCSI 컨트롤러 정의 -->
<controller type='scsi' index='0' model='virtio-scsi'>
  <driver queues='4' iothread='1'/>
</controller>

<!-- 디스크 -->
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
  <source file='/var/lib/libvirt/images/vm.qcow2'/>
  <target dev='sda' bus='scsi'/>
</disk>
```

**캐시 모드:**

- **none**: Write-through, O_DIRECT (안전, 성능 양호) ← 권장
- **writethrough**: Write-through, 캐시 사용 (안전, 느림)
- **writeback**: Write-back (빠름, 데이터 손실 위험)
- **directsync**: O_DIRECT + O_SYNC (가장 안전, 느림)

### 4.3 Network I/O - virtio-net

**virtio-net 성능 최적화:**
```xml
<interface type='network'>
  <source network='default'/>
  <model type='virtio'/>

  <!-- Multi-queue 활성화 (vCPU 수만큼) -->
  <driver name='vhost' queues='4' txmode='iothread' ioeventfd='on'/>

  <!-- vhost-net 사용 (커널 공간에서 네트워크 처리) -->
  <backend tap='/dev/net/tun' vhost='/dev/vhost-net'/>
</interface>
```

**Guest 내부 최적화:**
```bash
# Multi-queue 확인 (Guest)
ethtool -l eth0

# IRQ 분산 (각 queue를 다른 vCPU에)
echo 1 > /proc/irq/30/smp_affinity
echo 2 > /proc/irq/31/smp_affinity
echo 4 > /proc/irq/32/smp_affinity
echo 8 > /proc/irq/33/smp_affinity

# TSO/GSO 활성화 (Offload)
ethtool -K eth0 tso on gso on gro on
```

**Jumbo Frames (MTU 9000):**
```bash
# Host 브리지
ip link set br0 mtu 9000

# Guest
ip link set eth0 mtu 9000

# 성능 향상: 3.6 Gbps → 9.4 Gbps (잘못된 설정 vs 올바른 설정)
```

### 4.4 VFIO 및 PCI 패스스루

**VFIO (Virtual Function I/O):**
하드웨어 장치를 직접 Guest에 할당하여 네이티브에 가까운 성능을 얻습니다.

**사용 사례:**

- GPU 패스스루 (NVIDIA, AMD)
- 고성능 NIC (10GbE, 100GbE)
- NVME SSD

**VFIO 설정:**
```bash
# 1. IOMMU 활성화 (/etc/default/grub)
# Intel
GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt"

# AMD
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt"

update-grub
reboot

# 2. IOMMU 그룹 확인
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}
  n=${n%%/*}
  printf 'IOMMU Group %s ' "$n"
  lspci -nns "${d##*/}"
done

# 3. 장치 바인딩
# PCI 주소 확인
lspci | grep -i nvidia
# 01:00.0 VGA compatible controller: NVIDIA Corporation

# vfio-pci 드라이버에 바인딩
echo "10de 1b80" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "0000:01:00.0" > /sys/bus/pci/devices/0000:01:00.0/driver/unbind
echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/bind
```

**Libvirt 설정:**
```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  </source>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
</hostdev>
```

**SR-IOV (Single Root I/O Virtualization):**
```bash
# NIC SR-IOV VF 생성
echo 4 > /sys/class/net/ens1f0/device/sriov_numvfs

# VF 확인
lspci | grep -i virtual
# 01:10.0 Ethernet controller: Intel Corporation 82576 Virtual Function
# 01:10.1 Ethernet controller: Intel Corporation 82576 Virtual Function
```

---

## Part 5: NUMA 아키텍처 및 최적화

### 5.1 NUMA 개념

**NUMA (Non-Uniform Memory Access):**
멀티 소켓 시스템에서 각 CPU가 로컬 메모리에 빠르게 접근하고, 원격 메모리에는 느리게 접근하는 구조입니다.

```
┌─────────────────────────────────────────────────────────┐
│  NUMA Node 0                    NUMA Node 1             │
│  ┌────────────┐                 ┌────────────┐          │
│  │  CPU 0-15  │                 │ CPU 16-31  │          │
│  └──────┬─────┘                 └──────┬─────┘          │
│         │ (Fast - Local)               │                │
│  ┌──────▼─────┐                 ┌──────▼─────┐          │
│  │  Memory    │◄───────────────►│  Memory    │          │
│  │  64GB      │  (Slow - Remote)│  64GB      │          │
│  └────────────┘                 └────────────┘          │
│                                                          │
│  ┌────────────┐                 ┌────────────┐          │
│  │  NIC 0     │                 │   NIC 1    │          │
│  └────────────┘                 └────────────┘          │
└─────────────────────────────────────────────────────────┘

성능 차이:

- 로컬 메모리 접근: 100 ns
- 원격 메모리 접근: 200-300 ns (2-3배 느림)
```

### 5.2 NUMA 토폴로지 확인

```bash
# NUMA 노드 확인
numactl --hardware

# 출력 예시:
# available: 2 nodes (0-1)
# node 0 cpus: 0 1 2 3 4 5 6 7 16 17 18 19 20 21 22 23
# node 0 size: 65536 MB
# node 0 free: 45123 MB
# node 1 cpus: 8 9 10 11 12 13 14 15 24 25 26 27 28 29 30 31
# node 1 size: 65536 MB
# node 1 free: 52341 MB
# node distances:
# node   0   1
#   0:  10  21
#   1:  21  10

# lstopo (hwloc)
lstopo --no-io --no-legend
```

### 5.3 VM의 NUMA 정렬 (Best Practice)

**핵심 원칙:**
1. **vCPU와 메모리를 동일한 NUMA 노드에 배치**
2. **물리 NIC도 동일한 NUMA 노드 사용**
3. **NUMA 경계를 절대 넘지 않기**

**Libvirt NUMA 설정:**
```xml
<domain type='kvm'>
  <vcpu placement='static'>8</vcpu>
  <cpu mode='host-passthrough'>
    <numa>
      <!-- VM의 NUMA Node 0 → Host NUMA Node 0 -->
      <cell id='0' cpus='0-7' memory='32' unit='GiB' memAccess='shared'/>
    </numa>
  </cpu>

  <numatune>
    <!-- 메모리를 Host NUMA Node 0에만 할당 -->
    <memory mode='strict' nodeset='0'/>
    <memnode cellid='0' mode='strict' nodeset='0'/>
  </numatune>

  <cputune>
    <!-- vCPU 0-7 → Physical CPU 0-7 (NUMA Node 0) -->
    <vcpupin vcpu='0' cpuset='0'/>
    <vcpupin vcpu='1' cpuset='1'/>
    <vcpupin vcpu='2' cpuset='2'/>
    <vcpupin vcpu='3' cpuset='3'/>
    <vcpupin vcpu='4' cpuset='4'/>
    <vcpupin vcpu='5' cpuset='5'/>
    <vcpupin vcpu='6' cpuset='6'/>
    <vcpupin vcpu='7' cpuset='7'/>
  </cputune>
</domain>
```

**잘못된 예 (NUMA 경계 교차):**
```xml
<!-- ❌ BAD: vCPU가 두 NUMA 노드에 걸쳐 있음 -->
<numa>
  <cell id='0' cpus='0-3' memory='16' unit='GiB'/>
  <cell id='1' cpus='4-7' memory='16' unit='GiB'/>
</numa>

<!-- vCPU 0-3은 NUMA 0, vCPU 4-7은 NUMA 1 → 원격 메모리 접근 발생 -->
```

### 5.4 NUMA 성능 모니터링

```bash
# VM의 NUMA 통계
virsh numatune test-vm

# NUMA 메모리 사용량
numastat

# Per-VM NUMA 통계
numastat -c qemu-system-x86

# 원격 메모리 접근 확인 (numa_miss, numa_foreign)
numastat -p $(pgrep -f test-vm)
```

---

## Part 6: 프로덕션 성능 튜닝

### 6.1 종합 튜닝 체크리스트

**✅ CPU:**

- [ ] CPU 피닝 설정 (vCPU → Physical CPU)
- [ ] Emulator 및 I/O 스레드 전용 CPU 할당
- [ ] NUMA 경계 교차 방지
- [ ] CPU 모델: host-passthrough (성능) 또는 host-model (마이그레이션)
- [ ] 오버커밋 비율: 프로덕션 1:1 ~ 2:1

**✅ Memory:**

- [ ] Huge Pages 활성화 (2MB 또는 1GB)
- [ ] 메모리 잠금 (locked) - swap 방지
- [ ] NUMA 메모리 정렬 (strict mode)
- [ ] Memory Ballooning 비활성화 (성능 중시)
- [ ] KSM 비활성화 (CPU 오버헤드 회피)

**✅ Disk I/O:**

- [ ] virtio-scsi 사용 (DB, I/O 집약적)
- [ ] Cache mode: none + io=native
- [ ] discard=unmap (SSD TRIM 지원)
- [ ] I/O 스레드 활성화 및 피닝
- [ ] 디스크 I/O 스케줄러: none (NVMe) 또는 mq-deadline (SSD/HDD)

**✅ Network:**

- [ ] virtio-net + vhost-net
- [ ] Multi-queue 활성화 (vCPU 수만큼)
- [ ] Jumbo Frames (MTU 9000)
- [ ] TSO/GSO/GRO 활성화
- [ ] NIC와 vCPU를 동일 NUMA 노드에 배치

**✅ 기타:**

- [ ] CPU 절전 기능 비활성화 (C-states, P-states)
- [ ] Transparent Huge Pages (THP) 비활성화
- [ ] SELinux/AppArmor 성능 영향 확인

### 6.2 호스트 커널 튜닝

**CPU 절전 비활성화:**
```bash
# /etc/default/grub
GRUB_CMDLINE_LINUX="intel_pstate=disable processor.max_cstate=1 intel_idle.max_cstate=0"

update-grub
reboot
```

**Transparent Huge Pages 비활성화:**
```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# 영구 설정
cat >> /etc/rc.local <<EOF
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
EOF
```

**I/O 스케줄러:**
```bash
# NVMe: none
echo none > /sys/block/nvme0n1/queue/scheduler

# SSD: mq-deadline
echo mq-deadline > /sys/block/sda/queue/scheduler

# HDD: mq-deadline
echo mq-deadline > /sys/block/sdb/queue/scheduler
```

### 6.3 벤치마킹

**CPU 벤치마크 (sysbench):**
```bash
# Host
sysbench cpu --cpu-max-prime=20000 --threads=8 run

# Guest (비교)
sysbench cpu --cpu-max-prime=20000 --threads=8 run

# 목표: Guest가 Host의 95% 이상 성능
```

**메모리 벤치마크:**
```bash
# 메모리 대역폭 (stream)
gcc -O3 -fopenmp -DSTREAM_ARRAY_SIZE=100000000 stream.c -o stream
export OMP_NUM_THREADS=8
./stream

# 메모리 레이턴시
lat_mem_rd 1024 128
```

**디스크 I/O 벤치마크 (fio):**
```bash
# 랜덤 읽기 (IOPS)
fio --name=random-read --ioengine=libaio --iodepth=32 --rw=randread --bs=4k --direct=1 --size=4G --numjobs=4 --runtime=60 --group_reporting

# 순차 쓰기 (Throughput)
fio --name=sequential-write --ioengine=libaio --iodepth=32 --rw=write --bs=1m --direct=1 --size=4G --numjobs=1 --runtime=60

# 목표 (virtio-scsi + SSD):
# - Random Read IOPS: 50K+ IOPS
# - Sequential Write: 500+ MB/s
```

**네트워크 벤치마크 (iperf3):**
```bash
# Server (VM1)
iperf3 -s

# Client (VM2)
iperf3 -c <VM1_IP> -t 60 -P 4

# 목표 (10GbE):
# - TCP Throughput: 9+ Gbps
```

---

## 🛠️ 실습 가이드

### 실습 1: 고성능 VM 생성 (모든 최적화 적용)

```bash
# 1. Huge Pages 설정 (2MB, 16GB 할당)
echo 8192 > /proc/sys/vm/nr_hugepages
cat /proc/meminfo | grep -i huge

# 2. VM 생성용 XML 작성
cat > high-perf-vm.xml <<'EOF'
<domain type='kvm'>
  <name>high-perf-vm</name>
  <memory unit='GiB'>16</memory>
  <currentMemory unit='GiB'>16</currentMemory>
  <vcpu placement='static'>8</vcpu>

  <!-- Huge Pages -->
  <memoryBacking>
    <hugepages>
      <page size='2' unit='M'/>
    </hugepages>
    <locked/>
  </memoryBacking>

  <!-- NUMA -->
  <cpu mode='host-passthrough' check='none'>
    <topology sockets='1' dies='1' cores='8' threads='1'/>
    <numa>
      <cell id='0' cpus='0-7' memory='16' unit='GiB'/>
    </numa>
  </cpu>

  <numatune>
    <memory mode='strict' nodeset='0'/>
  </numatune>

  <!-- CPU Pinning -->
  <cputune>
    <vcpupin vcpu='0' cpuset='2'/>
    <vcpupin vcpu='1' cpuset='3'/>
    <vcpupin vcpu='2' cpuset='4'/>
    <vcpupin vcpu='3' cpuset='5'/>
    <vcpupin vcpu='4' cpuset='6'/>
    <vcpupin vcpu='5' cpuset='7'/>
    <vcpupin vcpu='6' cpuset='8'/>
    <vcpupin vcpu='7' cpuset='9'/>
    <emulatorpin cpuset='0-1'/>
  </cputune>

  <os>
    <type arch='x86_64' machine='pc-q35-7.2'>hvm</type>
    <boot dev='hd'/>
  </os>

  <devices>
    <!-- virtio-scsi Controller -->
    <controller type='scsi' index='0' model='virtio-scsi'>
      <driver queues='8' iothread='1'/>
    </controller>

    <!-- Disk with optimal settings -->
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap' iothread='1'/>
      <source file='/var/lib/libvirt/images/high-perf-vm.qcow2'/>
      <target dev='sda' bus='scsi'/>
    </disk>

    <!-- Network with multi-queue -->
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
      <driver name='vhost' queues='8' txmode='iothread'/>
    </interface>

    <console type='pty'/>
    <graphics type='vnc' port='-1'/>
  </devices>
</domain>
EOF

# 3. VM 생성
virsh define high-perf-vm.xml

# 4. 디스크 이미지 생성
qemu-img create -f qcow2 /var/lib/libvirt/images/high-perf-vm.qcow2 100G

# 5. VM 시작
virsh start high-perf-vm

# 6. 설정 확인
virsh vcpuinfo high-perf-vm
virsh numatune high-perf-vm
```

### 실습 2: NUMA 영향 테스트

```bash
# 시나리오 A: NUMA 최적화 (모든 리소스가 NUMA 0)
cat > numa-optimized.xml <<EOF
<numa>
  <cell id='0' cpus='0-7' memory='16' unit='GiB'/>
</numa>
<numatune>
  <memory mode='strict' nodeset='0'/>
</numatune>
EOF

# 시나리오 B: NUMA 미최적화 (NUMA 경계 교차)
cat > numa-bad.xml <<EOF
<numa>
  <cell id='0' cpus='0-3' memory='8' unit='GiB'/>
  <cell id='1' cpus='4-7' memory='8' unit='GiB'/>
</numa>
<!-- numatune 없음 - 자동 할당 -->
EOF

# 벤치마크 비교
# A: sysbench 결과
# B: sysbench 결과
# 기대: A가 B보다 10-20% 빠름
```

### 실습 3: virtio-blk vs virtio-scsi 성능 비교

```bash
# VM 1: virtio-blk
<disk type='file' device='disk'>
  <driver name='qemu' type='raw' cache='none' io='native'/>
  <source file='/data/vm1.raw'/>
  <target dev='vda' bus='virtio'/>
</disk>

# VM 2: virtio-scsi
<controller type='scsi' model='virtio-scsi'>
  <driver queues='4'/>
</controller>
<disk type='file' device='disk'>
  <driver name='qemu' type='raw' cache='none' io='native'/>
  <source file='/data/vm2.raw'/>
  <target dev='sda' bus='scsi'/>
</disk>

# 벤치마크 (fio)
fio --name=test --ioengine=libaio --iodepth=32 --rw=randread --bs=4k --direct=1 --size=10G --runtime=60

# 결과 비교:
# - Low I/O: virtio-blk 근소하게 유리
# - High I/O: virtio-scsi 10-15% 우수
```

---

## 💻 예제 코드

### 예제 1: VM 생성 자동화 스크립트 (최적화 적용)

```bash
#!/bin/bash
# create-optimized-vm.sh

set -e

VM_NAME=$1
VCPUS=$2
MEMORY_GB=$3
DISK_SIZE_GB=$4
NUMA_NODE=$5

if [ $# -ne 5 ]; then
  echo "Usage: $0 <vm_name> <vcpus> <memory_gb> <disk_size_gb> <numa_node>"
  exit 1
fi

# Huge Pages 필요량 계산 (2MB pages)
HUGEPAGES_NEEDED=$((MEMORY_GB * 1024 / 2))
CURRENT_HUGEPAGES=$(cat /proc/sys/vm/nr_hugepages)

if [ $CURRENT_HUGEPAGES -lt $HUGEPAGES_NEEDED ]; then
  echo "Allocating Huge Pages: $HUGEPAGES_NEEDED"
  echo $HUGEPAGES_NEEDED > /proc/sys/vm/nr_hugepages
fi

# CPU 피닝 계산 (NUMA 노드 기반)
if [ $NUMA_NODE -eq 0 ]; then
  CPU_START=2
else
  CPU_START=18
fi

# XML 생성
cat > /tmp/${VM_NAME}.xml <<EOF
<domain type='kvm'>
  <name>${VM_NAME}</name>
  <memory unit='GiB'>${MEMORY_GB}</memory>
  <currentMemory unit='GiB'>${MEMORY_GB}</currentMemory>
  <vcpu placement='static'>${VCPUS}</vcpu>

  <memoryBacking>
    <hugepages><page size='2' unit='M'/></hugepages>
    <locked/>
  </memoryBacking>

  <cpu mode='host-passthrough' check='none'>
    <topology sockets='1' dies='1' cores='${VCPUS}' threads='1'/>
    <numa>
      <cell id='0' cpus='0-$((VCPUS-1))' memory='${MEMORY_GB}' unit='GiB'/>
    </numa>
  </cpu>

  <numatune>
    <memory mode='strict' nodeset='${NUMA_NODE}'/>
  </numatune>

  <cputune>
EOF

# vCPU 피닝
for i in $(seq 0 $((VCPUS-1))); do
  echo "    <vcpupin vcpu='$i' cpuset='$((CPU_START+i))'/>" >> /tmp/${VM_NAME}.xml
done

cat >> /tmp/${VM_NAME}.xml <<EOF
    <emulatorpin cpuset='0-1'/>
  </cputune>

  <os>
    <type arch='x86_64' machine='pc-q35-7.2'>hvm</type>
    <boot dev='hd'/>
  </os>

  <devices>
    <controller type='scsi' index='0' model='virtio-scsi'>
      <driver queues='${VCPUS}' iothread='1'/>
    </controller>

    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap' iothread='1'/>
      <source file='/var/lib/libvirt/images/${VM_NAME}.qcow2'/>
      <target dev='sda' bus='scsi'/>
    </disk>

    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
      <driver name='vhost' queues='${VCPUS}' txmode='iothread'/>
    </interface>

    <console type='pty'/>
    <graphics type='vnc' port='-1'/>
  </devices>
</domain>
EOF

# 디스크 생성
qemu-img create -f qcow2 /var/lib/libvirt/images/${VM_NAME}.qcow2 ${DISK_SIZE_GB}G

# VM 정의 및 시작
virsh define /tmp/${VM_NAME}.xml
virsh start ${VM_NAME}

echo "VM ${VM_NAME} created and started successfully!"
virsh vcpuinfo ${VM_NAME}
```

**사용 예:**
```bash
# NUMA 0에 8 vCPU, 16GB RAM, 100GB 디스크 VM 생성
./create-optimized-vm.sh test-vm 8 16 100 0
```

### 예제 2: Python으로 VM 성능 모니터링

```python
#!/usr/bin/env python3
# vm-monitor.py

import libvirt
import time
import sys

def get_vm_stats(conn, vm_name):
    """VM의 CPU, 메모리, 디스크, 네트워크 통계 수집"""
    try:
        domain = conn.lookupByName(vm_name)
    except libvirt.libvirtError:
        print(f"VM {vm_name} not found")
        return None

    # CPU 통계
    cpu_stats = domain.getCPUStats(True)[0]
    cpu_time = cpu_stats['cpu_time'] / 1e9  # nanoseconds to seconds

    # 메모리 통계
    mem_stats = domain.memoryStats()
    mem_total = mem_stats.get('actual', 0) / 1024  # KB to MB
    mem_unused = mem_stats.get('unused', 0) / 1024
    mem_used = mem_total - mem_unused

    # 블록 디스크 통계
    tree = domain.blockStats('vda')  # 또는 'sda'
    rd_bytes = tree[1]
    wr_bytes = tree[3]

    # 네트워크 통계
    iface_stats = domain.interfaceStats('vnet0')  # 인터페이스 이름
    rx_bytes = iface_stats[0]
    tx_bytes = iface_stats[4]

    return {
        'cpu_time': cpu_time,
        'mem_total': mem_total,
        'mem_used': mem_used,
        'disk_rd_bytes': rd_bytes,
        'disk_wr_bytes': wr_bytes,
        'net_rx_bytes': rx_bytes,
        'net_tx_bytes': tx_bytes
    }

def monitor_vm(vm_name, interval=5):
    """VM 성능 지속 모니터링"""
    conn = libvirt.open('qemu:///system')
    if not conn:
        print("Failed to connect to libvirt")
        sys.exit(1)

    prev_stats = None

    try:
        while True:
            stats = get_vm_stats(conn, vm_name)
            if not stats:
                break

            if prev_stats:
                # Delta 계산
                cpu_delta = stats['cpu_time'] - prev_stats['cpu_time']
                disk_rd_delta = (stats['disk_rd_bytes'] - prev_stats['disk_rd_bytes']) / 1024 / 1024  # MB
                disk_wr_delta = (stats['disk_wr_bytes'] - prev_stats['disk_wr_bytes']) / 1024 / 1024
                net_rx_delta = (stats['net_rx_bytes'] - prev_stats['net_rx_bytes']) / 1024 / 1024
                net_tx_delta = (stats['net_tx_bytes'] - prev_stats['net_tx_bytes']) / 1024 / 1024

                print(f"\n{'='*60}")
                print(f"VM: {vm_name} | Interval: {interval}s")
                print(f"{'='*60}")
                print(f"CPU Time:    {cpu_delta:.2f}s ({cpu_delta/interval*100:.1f}% util)")
                print(f"Memory:      {stats['mem_used']:.0f} / {stats['mem_total']:.0f} MB ({stats['mem_used']/stats['mem_total']*100:.1f}%)")
                print(f"Disk Read:   {disk_rd_delta:.2f} MB/s")
                print(f"Disk Write:  {disk_wr_delta:.2f} MB/s")
                print(f"Net RX:      {net_rx_delta:.2f} MB/s")
                print(f"Net TX:      {net_tx_delta:.2f} MB/s")

            prev_stats = stats
            time.sleep(interval)

    except KeyboardInterrupt:
        print("\nMonitoring stopped")
    finally:
        conn.close()

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <vm_name>")
        sys.exit(1)

    monitor_vm(sys.argv[1])
```

**사용 예:**
```bash
python3 vm-monitor.py test-vm
```

---

## 📚 참고 자료

### 공식 문서
1. **KVM/QEMU**
   - [KVM Official Site](https://www.linux-kvm.org/)
   - [QEMU Documentation](https://www.qemu.org/documentation/)
   - [KVM Forum 2025](https://kvm-forum.qemu.org/2025/)

2. **Libvirt**
   - [Libvirt Domain XML Format](https://libvirt.org/formatdomain.html)
   - [Libvirt Performance Tuning](https://libvirt.org/kbase/launch_security_sev.html)

3. **Red Hat**
   - [Virtualization Tuning and Optimization Guide](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html-single/virtualization_tuning_and_optimization_guide/)

### 2025 Best Practices
1. [Optimizing KVM Disk Performance with Virtio-scsi and Virtio-blk](https://dohost.us/index.php/2025/09/10/optimizing-kvm-disk-performance-with-virtio-scsi-and-virtio-blk/)
2. [Performance Tuning Your KVM Virtual Machines](https://dohost.us/index.php/2025/09/09/performance-tuning-your-kvm-virtual-machines/)
3. [The KVM Memory Model: NUMA and HugePages Explained](https://dohost.us/index.php/2025/09/09/the-kvm-memory-model-numa-and-hugepages-explained/)
4. [Optimizing KVM Performance: Tips and Tricks for 2025](https://toxigon.com/optimizing-kvm-performance)

### 커뮤니티
1. **Proxmox VE Wiki**
   - [Performance Tweaks](https://pve.proxmox.com/wiki/Performance_Tweaks)
   - [Qemu/KVM Virtual Machines](https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines)

---

## ✅ 학습 체크리스트

### 기본 개념

- [ ] KVM과 QEMU의 역할 차이 이해
- [ ] Intel VT-x / AMD-V 하드웨어 가상화 확장 이해
- [ ] EPT/NPT 2단계 페이지 테이블 동작 원리
- [ ] Libvirt 아키텍처 및 XML 구조

### CPU 가상화

- [ ] vCPU 오버커밋 비율 설정
- [ ] CPU 피닝 구성 (vcpupin, emulatorpin)
- [ ] CPU 모델 선택 (host-passthrough vs host-model)
- [ ] CPU 토폴로지 설정 (sockets, cores, threads)

### 메모리 가상화

- [ ] Huge Pages 설정 (2MB, 1GB)
- [ ] Memory Ballooning 동작 이해
- [ ] KSM (Kernel Same-page Merging) 장단점
- [ ] 메모리 잠금 (locked) 설정

### I/O 가상화

- [ ] virtio-blk vs virtio-scsi 선택 기준
- [ ] 디스크 캐시 모드 (none, writethrough, writeback)
- [ ] virtio-net multi-queue 설정
- [ ] VFIO/SR-IOV PCI 패스스루

### NUMA 최적화

- [ ] NUMA 토폴로지 확인 (numactl, lstopo)
- [ ] vCPU와 메모리의 NUMA 정렬
- [ ] NUMA 통계 모니터링 (numastat)
- [ ] NIC와 vCPU의 NUMA 일치

### 성능 튜닝

- [ ] 종합 튜닝 체크리스트 적용
- [ ] 호스트 커널 파라미터 최적화
- [ ] 벤치마킹 (sysbench, fio, iperf3)
- [ ] 성능 모니터링 및 트러블슈팅

---

## 🎓 다음 단계

1. **[Ch3.스케줄링.md](./Ch3.스케줄링.md)**
   - 스케줄링 알고리즘 (CFS, Real-time)
   - 리소스 할당 및 QoS
   - CPU/메모리 오버커밋 전략

2. **심화 주제**
   - **Nested Virtualization**: VM 안에서 VM 실행
   - **Live Migration**: 무중단 VM 마이그레이션
   - **GPU 가상화**: vGPU, GPU 패스스루

3. **실전 프로젝트**
   - 고성능 DB 서버용 VM 최적화
   - OpenStack Nova와 KVM 통합
   - VM 성능 자동 모니터링 시스템

---

**마지막 업데이트:** 2025-11-24
**다음 챕터:** [Ch3.스케줄링.md](./Ch3.스케줄링.md)
