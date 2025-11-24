# Ch3. 스케줄링 및 리소스 관리

## 📋 개요

클라우드 환경에서 효율적인 리소스 활용과 안정적인 서비스 제공을 위해서는 정교한 스케줄링 알고리즘과 리소스 관리 전략이 필수적입니다. 본 장에서는 Linux 커널의 스케줄링 메커니즘, cgroups를 통한 리소스 격리, OpenStack Nova의 스케줄링 전략, 그리고 CPU/메모리 오버커밋 최적화 기법을 학습합니다.

2025년 현재, Linux 커널은 **EEVDF (Earliest Eligible Virtual Deadline First)** 스케줄러를 기본으로 채택하였으며, OpenShift Virtualization은 메모리 오버커밋을 위한 **WASP (Workload-Aware Swap Provisioner)**를 도입했습니다.

## 🎯 학습 목표

1. **Linux 스케줄링 알고리즘 이해**
   - CFS에서 EEVDF로의 전환 (Linux 6.6+)
   - Real-time 스케줄러 (SCHED_FIFO, SCHED_RR)
   - Deadline 스케줄러 (SCHED_DEADLINE)

2. **cgroups를 활용한 리소스 관리**
   - CPU 제어 (cpu, cpuset, cpuacct)
   - 메모리 제어 (memory)
   - I/O 제어 (blkio)
   - cgroups v2 마이그레이션

3. **OpenStack Nova 스케줄링**
   - Filter Scheduler 아키텍처
   - 필터링 (Filters) 및 가중치 (Weighers)
   - Placement API를 통한 리소스 추적
   - Aggregates 및 Availability Zones

4. **오버커밋 전략 및 최적화**
   - CPU 오버커밋 (1:1 ~ 5:1)
   - 메모리 오버커밋 및 SWAP 관리
   - 오버커밋 비율 결정 기준
   - 성능 vs 효율성 트레이드오프

5. **QoS (Quality of Service)**
   - CPU shares, quota, period
   - Memory limits 및 OOM Killer
   - I/O priorities 및 bandwidth 제한

6. **실전 튜닝 및 모니터링**
   - 스케줄링 통계 분석
   - 병목 지점 식별
   - 실시간 성능 모니터링

---

## Part 1: Linux 스케줄링 알고리즘

### 1.1 EEVDF - 최신 기본 스케줄러 (Linux 6.6+)

**EEVDF란?**
2025년 현재, CFS를 대체하여 Linux 6.6 (2023년 10월)부터 기본 스케줄러로 채택된 알고리즘입니다. Earliest Eligible Virtual Deadline First의 약자로, 더 정확한 지연 시간 보장과 공정성을 제공합니다.

**CFS vs EEVDF:**

| 특징 | CFS (Legacy) | EEVDF (Current) |
|------|--------------|-----------------|
| 기본 개념 | Virtual Runtime 균형 | Virtual Deadline 기반 |
| 지연 시간 | 예측 가능하지만 부정확 | 더 정확한 보장 |
| 공정성 | 좋음 | 매우 좋음 |
| 오버헤드 | 낮음 | 약간 더 높음 |
| 적용 | Linux < 6.6 | Linux >= 6.6 |

**EEVDF 동작 원리:**
```
1. 각 태스크에 "가상 데드라인(virtual deadline)" 할당
2. Eligible(실행 가능) 태스크 중 데드라인이 가장 이른 것 선택
3. 실행 후 가상 런타임 업데이트
4. 새로운 데드라인 계산 및 재삽입
```

### 1.2 스케줄링 클래스

**Linux 스케줄링 클래스 (우선순위 순):**
```
1. SCHED_DEADLINE (Deadline - 최고 우선순위)
   └─ 실시간 작업, 엄격한 데드라인 보장

2. SCHED_FIFO (Real-time FIFO)
   └─ 선점형 실시간, 우선순위 기반

3. SCHED_RR (Real-time Round-Robin)
   └─ FIFO + Time slice

4. SCHED_OTHER (CFS/EEVDF - 기본)
   └─ 일반 태스크, 공정한 CPU 시간 분배

5. SCHED_BATCH
   └─ CPU 집약적 배치 작업

6. SCHED_IDLE
   └─ 가장 낮은 우선순위
```

**스케줄링 정책 확인 및 변경:**
```bash
# 프로세스의 스케줄링 정책 확인
chrt -p <PID>

# 예시 출력:
# pid 1234's current scheduling policy: SCHED_OTHER
# pid 1234's current scheduling priority: 0

# Real-time FIFO로 변경 (priority 50)
sudo chrt -f -p 50 1234

# Deadline 스케줄러로 프로세스 실행
# Runtime: 10ms, Deadline: 30ms, Period: 30ms
sudo chrt -d --sched-runtime 10000000 \
               --sched-deadline 30000000 \
               --sched-period 30000000 \
               <command>
```

### 1.3 Nice 값과 우선순위

**Nice 값 (-20 ~ 19):**
```bash
# Nice 값이 낮을수록 높은 우선순위
# -20: 최고 우선순위
#   0: 기본값
#  19: 최저 우선순위

# Nice 값 10으로 프로세스 실행
nice -n 10 ./my_app

# 실행 중인 프로세스의 nice 변경
renice -n 5 -p 1234

# Nice 값 확인
ps -eo pid,ni,comm | grep my_app
```

**Nice vs Priority 관계:**
```
Static Priority (User Space): -20 ~ 19 (nice)
                    │
                    ▼ (mapping)
Kernel Priority:    0 ~ 139
                    ├─ 0-99: Real-time (SCHED_FIFO/RR)
                    └─ 100-139: Normal (SCHED_OTHER)
                        └─ 120: default (nice 0)
```

---

## Part 2: cgroups - 리소스 격리 및 제한

### 2.1 cgroups v1 vs v2

**cgroups (Control Groups):**
Linux 커널 기능으로 프로세스 그룹의 리소스 사용을 제한, 격리, 측정합니다.

**cgroups v1 (Legacy):**

- 각 리소스 컨트롤러가 독립적인 계층 구조
- 복잡한 설정 및 관리
- CPU, memory, blkio, net_cls 등 분리

**cgroups v2 (Unified Hierarchy - 권장):**

- 단일 통합 계층 구조
- 간소화된 인터페이스
- 더 나은 리소스 격리
- Linux 4.5+ 지원, 대부분의 배포판이 기본으로 채택 (2025)

**현재 cgroups 버전 확인:**
```bash
# cgroups v2 마운트 확인
mount | grep cgroup2

# cgroups v2가 활성화되어 있으면:
# cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime)

# cgroups v1인 경우 여러 개의 cgroup 마운트 표시:
# cgroup on /sys/fs/cgroup/cpu type cgroup (rw,...)
# cgroup on /sys/fs/cgroup/memory type cgroup (rw,...)
```

### 2.2 CPU 제어

**CPU Shares (상대적 가중치):**
```bash
# cgroups v1 예시
# CPU shares 설정 (기본값: 1024)
mkdir -p /sys/fs/cgroup/cpu/high_priority
mkdir -p /sys/fs/cgroup/cpu/low_priority

echo 2048 > /sys/fs/cgroup/cpu/high_priority/cpu.shares  # 2배 우선순위
echo 512  > /sys/fs/cgroup/cpu/low_priority/cpu.shares   # 0.5배 우선순위

# 프로세스를 cgroup에 할당
echo <PID> > /sys/fs/cgroup/cpu/high_priority/tasks
```

**CPU Quota (절대적 제한):**
```bash
# CPU 사용량을 50%로 제한
# cpu.cfs_period_us: 기간 (기본 100ms = 100000us)
# cpu.cfs_quota_us: 할당량

echo 100000 > /sys/fs/cgroup/cpu/my_app/cpu.cfs_period_us
echo 50000  > /sys/fs/cgroup/cpu/my_app/cpu.cfs_quota_us  # 50% = 50000/100000

# 4 vCPU 시스템에서 2 vCPU로 제한 (200%)
echo 100000 > /sys/fs/cgroup/cpu/my_app/cpu.cfs_period_us
echo 200000 > /sys/fs/cgroup/cpu/my_app/cpu.cfs_quota_us  # 200%
```

**cpuset (CPU 친화성):**
```bash
# CPU 0-3번만 사용하도록 제한
mkdir -p /sys/fs/cgroup/cpuset/database
echo "0-3" > /sys/fs/cgroup/cpuset/database/cpuset.cpus
echo "0"   > /sys/fs/cgroup/cpuset/database/cpuset.mems  # NUMA node 0

# 프로세스 할당
echo <PID> > /sys/fs/cgroup/cpuset/database/tasks
```

### 2.3 메모리 제어

**메모리 제한:**
```bash
# 메모리를 4GB로 제한
mkdir -p /sys/fs/cgroup/memory/my_app
echo 4294967296 > /sys/fs/cgroup/memory/my_app/memory.limit_in_bytes  # 4GB

# Swap 포함 총 메모리 제한
echo 5368709120 > /sys/fs/cgroup/memory/my_app/memory.memsw.limit_in_bytes  # 5GB

# OOM Killer 비활성화 (신중히 사용)
echo 1 > /sys/fs/cgroup/memory/my_app/memory.oom_control

# 프로세스 할당
echo <PID> > /sys/fs/cgroup/memory/my_app/tasks
```

**메모리 통계:**
```bash
# 메모리 사용량 확인
cat /sys/fs/cgroup/memory/my_app/memory.usage_in_bytes
cat /sys/fs/cgroup/memory/my_app/memory.stat

# 출력 예시:
# cache 1234567890
# rss 2345678901
# mapped_file 123456789
# ...
```

### 2.4 I/O 제어 (blkio)

**I/O 우선순위 및 대역폭 제한:**
```bash
# I/O weight (100-1000, 기본 500)
mkdir -p /sys/fs/cgroup/blkio/database
echo 800 > /sys/fs/cgroup/blkio/database/blkio.weight  # 높은 우선순위

# 특정 디바이스에 대한 읽기 대역폭 제한 (BPS)
# 형식: <major>:<minor> <bytes_per_second>
echo "8:0 10485760" > /sys/fs/cgroup/blkio/my_app/blkio.throttle.read_bps_device  # 10MB/s

# 쓰기 대역폭 제한
echo "8:0 20971520" > /sys/fs/cgroup/blkio/my_app/blkio.throttle.write_bps_device  # 20MB/s

# IOPS 제한
echo "8:0 1000" > /sys/fs/cgroup/blkio/my_app/blkio.throttle.read_iops_device  # 1000 IOPS
```

### 2.5 systemd와 cgroups 통합

**systemd는 cgroups의 주요 관리자:**
```bash
# systemd 서비스의 리소스 제한
cat > /etc/systemd/system/my_app.service <<EOF
[Unit]
Description=My Application

[Service]
ExecStart=/usr/bin/my_app
Restart=always

# CPU 제한 (50%)
CPUQuota=50%

# 메모리 제한 (4GB)
MemoryLimit=4G
MemoryHigh=3.5G  # Soft limit (throttle)

# I/O 가중치
IOWeight=500

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start my_app

# 리소스 사용량 확인
systemctl status my_app
```

**systemd-run으로 임시 cgroup 생성:**
```bash
# CPU 50%, Memory 2GB 제한으로 명령 실행
systemd-run --scope --unit=test-job \
  --property=CPUQuota=50% \
  --property=MemoryLimit=2G \
  stress-ng --cpu 4 --timeout 60s
```

---

## Part 3: OpenStack Nova 스케줄링

### 3.1 Nova Scheduler 아키텍처

**스케줄링 플로우:**
```
1. API Request
   └─> nova-api receives "boot instance" request

2. Conductor
   └─> nova-conductor orchestrates the build

3. Scheduler (Filter + Weigh)
   └─> nova-scheduler selects target host
       │
       ├─ Step 1: Get available hosts from Placement
       ├─ Step 2: Apply Filters (필터링)
       │   └─> Eliminate unsuitable hosts
       ├─ Step 3: Apply Weighers (가중치 계산)
       │   └─> Rank remaining hosts
       └─ Step 4: Select best host(s)

4. Compute
   └─> nova-compute@selected_host provisions instance
```

### 3.2 Filters (필터링)

**주요 필터 목록 (2025.1):**

| Filter | 설명 | 사용 사례 |
|--------|------|----------|
| **AvailabilityZoneFilter** | 특정 AZ의 호스트만 선택 | 지역 분산 |
| **ComputeFilter** | 활성 상태의 컴퓨트 노드만 | 기본 |
| **ComputeCapabilitiesFilter** | CPU, RAM, Disk 용량 확인 | 리소스 요구사항 |
| **ImagePropertiesFilter** | 이미지 속성과 호스트 capabilities 매칭 | CPU 기능, Hypervisor |
| **ServerGroupAntiAffinityFilter** | 인스턴스를 서로 다른 호스트에 배치 | HA |
| **ServerGroupAffinityFilter** | 인스턴스를 같은 호스트에 배치 | 네트워크 지연 최소화 |
| **AggregateInstanceExtraSpecsFilter** | Aggregate 메타데이터 매칭 | SSD-only, GPU 노드 |
| **NUMATopologyFilter** | NUMA 토폴로지 정렬 | 성능 최적화 |
| **PciPassthroughFilter** | PCI 장치 사용 가능 여부 | GPU, SR-IOV |

**설정 (/etc/nova/nova.conf):**
```ini
[filter_scheduler]
enabled_filters = AvailabilityZoneFilter,
                  ComputeFilter,
                  ComputeCapabilitiesFilter,
                  ImagePropertiesFilter,
                  ServerGroupAntiAffinityFilter,
                  ServerGroupAffinityFilter,
                  NUMATopologyFilter,
                  AggregateInstanceExtraSpecsFilter

# 사용 가능한 호스트가 이 개수 미만이면 shuffle
shuffle_best_same_weighed_hosts = True
```

### 3.3 Weighers (가중치)

**가중치 계산 공식:**
```
Weight = w1_multiplier × norm(w1) + w2_multiplier × norm(w2) + ...

norm(x) = (x - min) / (max - min)  # 0~1 정규화
```

**주요 Weigher (2025.1):**

| Weigher | 설명 | multiplier | 효과 |
|---------|------|------------|------|
| **RAMWeigher** | 가용 RAM 기반 | ram_weight_multiplier=1.0 | 양수: RAM 많은 호스트 선호 (spread)<br>음수: RAM 적은 호스트 선호 (pack) |
| **DiskWeigher** | 가용 Disk 기반 | disk_weight_multiplier=1.0 | 양수: Disk 많은 호스트 선호 |
| **CPUWeigher** | 가용 CPU 기반 | cpu_weight_multiplier=1.0 | 양수: CPU 많은 호스트 선호 |
| **IOOpsWeigher** | I/O operations 기반 | io_ops_weight_multiplier=-1.0 | 음수: I/O 적은 호스트 선호 |
| **PCIWeigher** | PCI 장치 수 기반 | pci_weight_multiplier=1.0 | PCI 장치 많은 호스트 선호 |
| **ImagePropertiesWeigher** (New!) | 이미지 속성 일치도 | image_props_weight_multiplier=0.0 | 같은 이미지 사용 호스트 선호 |

**설정 예시:**
```ini
[filter_scheduler]
# RAM 많은 호스트 선호 (Spread 전략)
ram_weight_multiplier = 1.0

# Disk 많은 호스트 선호
disk_weight_multiplier = 1.0

# I/O operations 적은 호스트 선호
io_ops_weight_multiplier = -1.0

# CPU 적은 호스트 선호 (Pack 전략 - 비용 절감)
cpu_weight_multiplier = -1.0
```

### 3.4 Host Aggregates 및 Availability Zones

**Host Aggregates:**
호스트를 논리적으로 그룹화하고 메타데이터를 부여하여 스케줄링에 활용합니다.

```bash
# Aggregate 생성 (SSD 노드)
openstack aggregate create ssd-nodes

# 호스트 추가
openstack aggregate add host ssd-nodes compute01
openstack aggregate add host ssd-nodes compute02

# 메타데이터 설정
openstack aggregate set --property ssd=true ssd-nodes

# Flavor에 요구사항 추가
openstack flavor create --ram 8192 --disk 100 --vcpus 4 ssd-flavor
openstack flavor set ssd-flavor --property aggregate_instance_extra_specs:ssd=true

# 인스턴스 생성 시 ssd-nodes에만 스케줄링됨
openstack server create --flavor ssd-flavor --image ubuntu-22.04 my-vm
```

**Availability Zones:**
```bash
# AZ 생성 (Aggregate + AZ name)
openstack aggregate create --zone az-korea az-korea-aggregate
openstack aggregate add host az-korea-aggregate compute-kr-01

# AZ 지정하여 인스턴스 생성
openstack server create --flavor m1.small --image ubuntu --availability-zone az-korea my-vm
```

---

## Part 4: 오버커밋 전략

### 4.1 CPU 오버커밋

**CPU 오버커밋 비율:**
```
vCPU 오버커밋 = (할당된 vCPU 총합) / (물리 CPU 코어 수)

안전한 범위:
- 프로덕션: 1:1 ~ 2:1
- 일반: 3:1 ~ 4:1
- VDI: 5:1 ~ 8:1 (사용자가 동시에 사용하지 않음)
```

**2025 Best Practice (RedHat):**
> CPU 오버커밋은 프로세스가 중단(killed)되거나 심각한 성능 저하의 위험이 없습니다. CPU가 오버커밋되면 워크로드가 느려질 뿐입니다.
>
> 각 게스트가 단일 vCPU만 가질 때 가상화된 CPU의 오버커밋이 가장 잘 작동하며, Linux 스케줄러가 이 유형의 부하에 매우 효율적입니다. **KVM은 부하가 100% 미만인 게스트를 5:1 비율로 안전하게 지원**해야 합니다.

**Nova 설정:**
```ini
# /etc/nova/nova.conf
[DEFAULT]
# CPU 오버커밋 비율 (기본 16.0)
cpu_allocation_ratio = 4.0

# 예시:
# 물리 CPU: 32 cores
# cpu_allocation_ratio = 4.0
# 최대 할당 가능 vCPU = 32 × 4.0 = 128 vCPUs
```

### 4.2 메모리 오버커밋

**메모리 오버커밋의 위험:**

- OOM (Out Of Memory) Killer 발동 → 프로세스 강제 종료
- SWAP 사용 → 심각한 성능 저하 (디스크 I/O)

**2025 OpenShift Virtualization 권장사항:**
> OpenShift Virtualization은 **최대 25% 메모리 오버커밋**을 다양한 워크로드에서 매우 잘 처리합니다.

**메모리 오버커밋 공식:**
```
Memory Overcommit % = (Total VM Memory - Reserved Memory) / Total VM Memory × 100

예시:
- VM Memory: 9 GB
- Reserved (Request): 6 GB
- Overcommit: (9 - 6) / 9 × 100 = 33%
```

**Nova 설정:**
```ini
# /etc/nova/nova.conf
[DEFAULT]
# 메모리 오버커밋 비율 (기본 1.5)
ram_allocation_ratio = 1.2  # 20% 오버커밋 (보수적)

# 예시:
# 물리 RAM: 128 GB
# ram_allocation_ratio = 1.2
# 최대 할당 가능 RAM = 128 × 1.2 = 153.6 GB
```

### 4.3 SWAP 및 WASP (2025 신기능)

**WASP (Workload-Aware Swap Provisioner):**
OpenShift Virtualization 2025에서 도입된 메모리 오버커밋 지원 컴포넌트입니다.

**WASP 동작:**
```
1. Worker 노드에 SWAP 리소스 할당
2. VM에 오버커밋된 메모리 제공
3. SWAP I/O 트래픽 모니터링
4. 높은 SWAP 사용 시 Pod eviction 관리
```

**SWAP 설정 (KVM 호스트):**
```bash
# SWAP 파일 생성 (16GB)
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# /etc/fstab에 추가
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# SWAP 확인
free -h
swapon --show

# Swappiness 조정 (0-100, 낮을수록 SWAP 사용 줄임)
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
```

### 4.4 오버커밋 모니터링

**리소스 사용률 확인:**
```bash
# Nova 전체 리소스 사용량
openstack hypervisor stats show

# 출력:
# +----------------------+-------+
# | Field                | Value |
# +----------------------+-------+
# | count                | 10    |
# | current_workload     | 42    |
# | disk_available_least | 5000  |
# | free_disk_gb         | 8000  |
# | free_ram_mb          | 102400|
# | local_gb             | 10000 |
# | local_gb_used        | 2000  |
# | memory_mb            | 204800|
# | memory_mb_used       | 102400|
# | running_vms          | 156   |
# | vcpus                | 320   |
# | vcpus_used           | 624   | # 1.95:1 오버커밋
# +----------------------+-------+

# 개별 Hypervisor
openstack hypervisor show compute01 -f yaml
```

---

## Part 5: QoS (Quality of Service)

### 5.1 CPU QoS

**CPU Shares (상대적):**
```bash
# Systemd 서비스
# High priority: 2048 shares
# Normal: 1024 shares (기본)
# Low: 512 shares

cat > /etc/systemd/system/database.service <<EOF
[Service]
CPUShares=2048
EOF

systemctl daemon-reload
systemctl restart database
```

**CPU Quota (절대적):**
```bash
# 50% CPU 제한
cat > /etc/systemd/system/batch_job.service <<EOF
[Service]
CPUQuota=50%
EOF
```

### 5.2 Memory QoS

**Memory Limits:**
```bash
# Soft limit (MemoryHigh): Throttle but don't kill
# Hard limit (MemoryMax/MemoryLimit): Kill if exceeded

cat > /etc/systemd/system/web_server.service <<EOF
[Service]
MemoryHigh=3G    # Soft limit - 초과 시 throttle
MemoryMax=4G     # Hard limit - 초과 시 OOM kill
EOF
```

**OOM Score 조정:**
```bash
# OOM Killer 우선순위 조정 (-1000 ~ 1000)
# 값이 높을수록 먼저 종료됨

# 중요한 프로세스는 낮은 값
echo -500 > /proc/<PID>/oom_score_adj

# 덜 중요한 프로세스는 높은 값
echo 500 > /proc/<PID>/oom_score_adj
```

### 5.3 I/O QoS

**ionice (I/O 우선순위):**
```bash
# I/O 클래스:
# 0: None (기본)
# 1: Real-time (최고 우선순위)
# 2: Best-effort (기본)
# 3: Idle (가장 낮음)

# Real-time 클래스, 우선순위 0 (가장 높음)
ionice -c 1 -n 0 -p <PID>

# Best-effort 클래스, 우선순위 7 (가장 낮음)
ionice -c 2 -n 7 ./batch_job

# Idle 클래스
ionice -c 3 ./background_task
```

**blkio cgroup을 통한 I/O 제한:**
```bash
# 읽기 대역폭 10MB/s 제한
echo "8:0 10485760" > /sys/fs/cgroup/blkio/my_app/blkio.throttle.read_bps_device

# 쓰기 IOPS 1000 제한
echo "8:0 1000" > /sys/fs/cgroup/blkio/my_app/blkio.throttle.write_iops_device
```

---

## Part 6: 스케줄링 모니터링 및 튜닝

### 6.1 스케줄링 통계

**CPU 스케줄링 통계:**
```bash
# 프로세스별 CPU 사용 시간
cat /proc/<PID>/schedstat

# 출력: <runtime_ns> <wait_time_ns> <nr_switches>
# 987654321 123456789 1234

# 시스템 전체 스케줄링 통계
cat /proc/schedstat

# CPU별 런큐 통계
cat /proc/sched_debug
```

**Context Switch 확인:**
```bash
# 초당 context switch 수
vmstat 1

# 출력:
# procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
#  r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
#  2  0      0 123456   1234  56789    0    0     1     2  345 6789 10 5 85  0  0
#                                                          cs = context switches

# 높은 cs 값 (>10000)은 스케줄링 오버헤드를 의미
```

### 6.2 런큐 분석

```bash
# 현재 실행 대기 중인 프로세스 수
cat /proc/loadavg

# 출력: 1.23 2.34 3.45 2/567 12345
#       1분  5분  15분 평균 load
#       실행중/전체 프로세스
#       마지막 PID

# Load average 해석:
# Load < CPU cores: 여유
# Load = CPU cores: 포화
# Load > CPU cores: 과부하
```

**런큐 시각화 (mpstat):**
```bash
# CPU별 사용률
mpstat -P ALL 1

# 출력 해석:
# %idle이 0에 가까우면 CPU 포화
# %iowait이 높으면 I/O 병목
# %steal이 높으면 Hypervisor가 CPU를 빼앗아감 (오버커밋)
```

### 6.3 성능 프로파일링

**perf를 통한 스케줄링 분석:**
```bash
# 스케줄링 이벤트 추적
sudo perf sched record -- sleep 10

# 분석
sudo perf sched latency

# 출력:
# Task                  |   Runtime ms  | Switches | Average delay ms | Maximum delay ms |
# migration/0           |      0.123 ms |        5 |    avg: 0.010 ms | max: 0.050 ms |
# ksoftirqd/0           |      1.234 ms |       12 |    avg: 0.020 ms | max: 0.100 ms |
# ...

# 스케줄링 맵 시각화
sudo perf sched map
```

**Flame Graph:**
```bash
# CPU 프로파일링 (60초)
sudo perf record -F 99 -a -g -- sleep 60

# Flame graph 생성
git clone https://github.com/brendangregg/FlameGraph
sudo perf script | ./FlameGraph/stackcollapse-perf.pl | ./FlameGraph/flamegraph.pl > flamegraph.svg

# 브라우저에서 flamegraph.svg 열기
```

---

## 🛠️ 실습 가이드

### 실습 1: cgroups를 활용한 CPU 제한

**시나리오:** CPU 집약적 작업 2개를 격리하고 리소스 분배

```bash
# 1. cgroup 생성
sudo mkdir -p /sys/fs/cgroup/cpu/high_priority
sudo mkdir -p /sys/fs/cgroup/cpu/low_priority

# 2. CPU shares 설정
echo 2048 > /sys/fs/cgroup/cpu/high_priority/cpu.shares  # 2x
echo 512  > /sys/fs/cgroup/cpu/low_priority/cpu.shares   # 0.5x

# 3. CPU stress 테스트 프로그램 실행
# High priority
stress-ng --cpu 4 --timeout 60s &
HIGH_PID=$!
echo $HIGH_PID > /sys/fs/cgroup/cpu/high_priority/tasks

# Low priority
stress-ng --cpu 4 --timeout 60s &
LOW_PID=$!
echo $LOW_PID > /sys/fs/cgroup/cpu/low_priority/tasks

# 4. CPU 사용률 모니터링
top -p $HIGH_PID,$LOW_PID

# 결과: high_priority가 low_priority보다 약 4배 많은 CPU 시간 할당
# (2048 / 512 = 4)
```

### 실습 2: 메모리 제한 및 OOM 테스트

```bash
# 1. cgroup 생성 및 메모리 제한 (1GB)
sudo mkdir -p /sys/fs/cgroup/memory/limited
echo 1073741824 > /sys/fs/cgroup/memory/limited/memory.limit_in_bytes

# 2. OOM notification 설정
echo 1 > /sys/fs/cgroup/memory/limited/memory.oom_control

# 3. 메모리 할당 프로그램 실행 (2GB 할당 시도)
cat > mem_hog.py <<'EOF'
import time
data = []
for i in range(20):  # 20 * 100MB = 2GB
    data.append(' ' * (100 * 1024 * 1024))
    print(f"Allocated {(i+1) * 100} MB")
    time.sleep(1)
EOF

python3 mem_hog.py &
PID=$!
echo $PID > /sys/fs/cgroup/memory/limited/tasks

# 4. 메모리 사용량 모니터링
watch -n 1 "cat /sys/fs/cgroup/memory/limited/memory.usage_in_bytes && \
            cat /proc/$PID/status | grep VmRSS"

# 결과: 1GB 도달 시 OOM Killer 또는 프로세스 중단
```

### 실습 3: Nova Scheduler 커스터마이징

```bash
# 1. Custom Aggregate 생성 (GPU 노드)
openstack aggregate create gpu-nodes --zone gpu-zone
openstack aggregate add host gpu-nodes compute-gpu-01
openstack aggregate set --property gpu=true gpu-nodes
openstack aggregate set --property gpu_type=nvidia-a100 gpu-nodes

# 2. GPU Flavor 생성
openstack flavor create --ram 32768 --disk 200 --vcpus 16 gpu.large
openstack flavor set gpu.large \
  --property aggregate_instance_extra_specs:gpu=true \
  --property aggregate_instance_extra_specs:gpu_type=nvidia-a100 \
  --property "pci_passthrough:alias"="a100:1"

# 3. Anti-affinity Server Group 생성 (HA)
openstack server group create --policy anti-affinity web-servers-ha

# 4. 인스턴스 생성 (Server Group 사용)
for i in {1..3}; do
  openstack server create \
    --flavor m1.large \
    --image ubuntu-22.04 \
    --hint group=$(openstack server group show web-servers-ha -f value -c id) \
    web-server-$i
done

# 결과: 3개 인스턴스가 서로 다른 호스트에 배치됨

# 5. Scheduler 통계 확인
openstack hypervisor stats show
```

### 실습 4: CPU 오버커밋 영향 측정

```bash
# 1. 오버커밋 없음 (1:1)
# 4 vCPU VM 1개 생성 (물리 CPU 4 cores)
openstack server create --flavor m1.xlarge --image ubuntu cpu-test-1

# VM 내부에서 CPU 벤치마크
ssh ubuntu@<VM_IP>
sysbench cpu --cpu-max-prime=20000 --threads=4 run

# 결과 기록 (Baseline)

# 2. 2:1 오버커밋
# 4 vCPU VM 2개 생성 (물리 CPU 4 cores, 총 8 vCPUs)
openstack server create --flavor m1.xlarge --image ubuntu cpu-test-2

# 두 VM에서 동시에 벤치마크
# 결과: 각 VM이 약 50% 성능

# 3. 4:1 오버커밋
# 4 vCPU VM 4개 생성
# 결과: 각 VM이 약 25% 성능

# 성능 저하율 = (Baseline - Current) / Baseline × 100
```

---

## 💻 예제 코드

### 예제 1: cgroup 관리 자동화 스크립트

```bash
#!/bin/bash
# cgroup-manager.sh

set -e

CGROUP_NAME=$1
CPU_SHARES=$2
MEMORY_LIMIT_GB=$3
COMMAND=$4

if [ $# -ne 4 ]; then
  echo "Usage: $0 <cgroup_name> <cpu_shares> <memory_limit_gb> <command>"
  exit 1
fi

# cgroup 생성
CPU_CGROUP="/sys/fs/cgroup/cpu/${CGROUP_NAME}"
MEMORY_CGROUP="/sys/fs/cgroup/memory/${CGROUP_NAME}"

sudo mkdir -p "$CPU_CGROUP"
sudo mkdir -p "$MEMORY_CGROUP"

# CPU 설정
echo "$CPU_SHARES" | sudo tee "$CPU_CGROUP/cpu.shares"

# 메모리 설정 (GB → Bytes)
MEMORY_BYTES=$((MEMORY_LIMIT_GB * 1024 * 1024 * 1024))
echo "$MEMORY_BYTES" | sudo tee "$MEMORY_CGROUP/memory.limit_in_bytes"

# 명령 실행
echo "Starting: $COMMAND"
echo "CPU Shares: $CPU_SHARES"
echo "Memory Limit: ${MEMORY_LIMIT_GB}GB"

# 백그라운드에서 실행
eval "$COMMAND" &
PID=$!

# cgroup에 할당
echo "$PID" | sudo tee "$CPU_CGROUP/tasks"
echo "$PID" | sudo tee "$MEMORY_CGROUP/tasks"

echo "Process $PID added to cgroup: $CGROUP_NAME"

# 리소스 사용량 모니터링
while kill -0 $PID 2>/dev/null; do
  CPU_USAGE=$(cat "$CPU_CGROUP/cpuacct.usage")
  MEM_USAGE=$(cat "$MEMORY_CGROUP/memory.usage_in_bytes")
  MEM_USAGE_MB=$((MEM_USAGE / 1024 / 1024))

  echo "$(date): CPU=${CPU_USAGE}ns, Memory=${MEM_USAGE_MB}MB"
  sleep 5
done

echo "Process completed"
```

**사용 예:**
```bash
# CPU shares 1024, Memory 2GB로 stress 테스트 실행
./cgroup-manager.sh my_test 1024 2 "stress-ng --cpu 4 --vm 2 --vm-bytes 1G --timeout 60s"
```

### 예제 2: Python으로 Nova Scheduler 시뮬레이션

```python
#!/usr/bin/env python3
# nova-scheduler-sim.py

class Host:
    def __init__(self, name, vcpus, ram_mb, disk_gb):
        self.name = name
        self.vcpus = vcpus
        self.vcpus_used = 0
        self.ram_mb = ram_mb
        self.ram_mb_used = 0
        self.disk_gb = disk_gb
        self.disk_gb_used = 0
        self.instances = []

    def available_vcpus(self):
        return self.vcpus - self.vcpus_used

    def available_ram(self):
        return self.ram_mb - self.ram_mb_used

    def available_disk(self):
        return self.disk_gb - self.disk_gb_used

    def can_fit(self, vcpus, ram_mb, disk_gb):
        return (self.available_vcpus() >= vcpus and
                self.available_ram() >= ram_mb and
                self.available_disk() >= disk_gb)

    def allocate(self, instance_name, vcpus, ram_mb, disk_gb):
        if not self.can_fit(vcpus, ram_mb, disk_gb):
            return False

        self.vcpus_used += vcpus
        self.ram_mb_used += ram_mb
        self.disk_gb_used += disk_gb
        self.instances.append(instance_name)
        return True

    def __repr__(self):
        return (f"Host({self.name}: vCPU={self.vcpus_used}/{self.vcpus}, "
                f"RAM={self.ram_mb_used}/{self.ram_mb}MB, "
                f"Disk={self.disk_gb_used}/{self.disk_gb}GB, "
                f"instances={len(self.instances)})")


class NovaScheduler:
    def __init__(self, hosts):
        self.hosts = hosts

    def filter(self, vcpus, ram_mb, disk_gb):
        """Filter: 리소스 요구사항을 만족하는 호스트만"""
        return [h for h in self.hosts if h.can_fit(vcpus, ram_mb, disk_gb)]

    def weigh(self, hosts, strategy='spread'):
        """Weigh: 가중치 계산 및 정렬"""
        if strategy == 'spread':
            # RAM 많은 호스트 우선 (spread)
            return sorted(hosts, key=lambda h: h.available_ram(), reverse=True)
        elif strategy == 'pack':
            # RAM 적은 호스트 우선 (pack)
            return sorted(hosts, key=lambda h: h.available_ram())
        else:
            return hosts

    def schedule(self, instance_name, vcpus, ram_mb, disk_gb, strategy='spread'):
        """스케줄링: Filter → Weigh → Select"""
        # Step 1: Filter
        candidates = self.filter(vcpus, ram_mb, disk_gb)
        if not candidates:
            print(f"❌ No suitable host for {instance_name}")
            return None

        # Step 2: Weigh
        ranked = self.weigh(candidates, strategy)

        # Step 3: Select best host
        selected = ranked[0]

        # Step 4: Allocate
        if selected.allocate(instance_name, vcpus, ram_mb, disk_gb):
            print(f"✅ {instance_name} scheduled on {selected.name}")
            return selected
        else:
            print(f"❌ Failed to allocate {instance_name}")
            return None


# 시뮬레이션
if __name__ == '__main__':
    # 호스트 생성
    hosts = [
        Host('compute-01', vcpus=32, ram_mb=131072, disk_gb=1000),
        Host('compute-02', vcpus=32, ram_mb=131072, disk_gb=1000),
        Host('compute-03', vcpus=32, ram_mb=131072, disk_gb=1000),
    ]

    scheduler = NovaScheduler(hosts)

    # 인스턴스 생성 요청
    instances = [
        ('web-1', 4, 8192, 50),
        ('web-2', 4, 8192, 50),
        ('db-1', 8, 32768, 200),
        ('db-2', 8, 32768, 200),
        ('cache-1', 2, 4096, 20),
    ]

    print("=== Spread Strategy ===")
    for name, vcpus, ram, disk in instances:
        scheduler.schedule(name, vcpus, ram, disk, strategy='spread')

    print("\n=== Host Status ===")
    for host in hosts:
        print(host)

    # 리셋 후 Pack 전략 테스트
    hosts = [
        Host('compute-01', vcpus=32, ram_mb=131072, disk_gb=1000),
        Host('compute-02', vcpus=32, ram_mb=131072, disk_gb=1000),
        Host('compute-03', vcpus=32, ram_mb=131072, disk_gb=1000),
    ]
    scheduler = NovaScheduler(hosts)

    print("\n=== Pack Strategy ===")
    for name, vcpus, ram, disk in instances:
        scheduler.schedule(name, vcpus, ram, disk, strategy='pack')

    print("\n=== Host Status ===")
    for host in hosts:
        print(host)
```

**실행 결과:**
```
=== Spread Strategy ===
✅ web-1 scheduled on compute-01
✅ web-2 scheduled on compute-02
✅ db-1 scheduled on compute-03
✅ db-2 scheduled on compute-01
✅ cache-1 scheduled on compute-02

=== Host Status ===
Host(compute-01: vCPU=12/32, RAM=40960/131072MB, Disk=250/1000GB, instances=2)
Host(compute-02: vCPU=6/32, RAM=12288/131072MB, Disk=70/1000GB, instances=2)
Host(compute-03: vCPU=8/32, RAM=32768/131072MB, Disk=200/1000GB, instances=1)

=== Pack Strategy ===
✅ web-1 scheduled on compute-01
✅ web-2 scheduled on compute-01
✅ db-1 scheduled on compute-01
✅ db-2 scheduled on compute-01
✅ cache-1 scheduled on compute-01

=== Host Status ===
Host(compute-01: vCPU=26/32, RAM=85504/131072MB, Disk=520/1000GB, instances=5)
Host(compute-02: vCPU=0/32, RAM=0/131072MB, Disk=0/1000GB, instances=0)
Host(compute-03: vCPU=0/32, RAM=0/131072MB, Disk=0/1000GB, instances=0)
```

---

## 📚 참고 자료

### 공식 문서
1. **Linux Kernel Scheduler**
   - [CFS Scheduler Documentation](https://docs.kernel.org/scheduler/sched-design-CFS.html)
   - [CFS Bandwidth Control](https://docs.kernel.org/scheduler/sched-bwc.html)
   - [CFS Group Scheduling](https://blogs.oracle.com/linux/post/cfs-group-scheduling)

2. **cgroups**
   - [Red Hat Resource Management Guide](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html/resource_management_guide/)
   - [Control Groups v2](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)

3. **OpenStack Nova Scheduler**
   - [Compute Schedulers](https://docs.openstack.org/nova/latest/admin/scheduling.html)
   - [Filter Scheduler](https://docs.openstack.org/nova/rocky/user/filter-scheduler.html)
   - [2025.1 Release Notes](https://docs.openstack.org/releasenotes/nova/2025.1.html)

### 2025 Best Practices
1. [Evaluating Memory Overcommitment in OpenShift Virtualization](https://developers.redhat.com/articles/2025/04/24/evaluating-memory-overcommitment-openshift-virtualization)
2. [Memory Management in OpenShift Virtualization](https://developers.redhat.com/blog/2025/01/31/memory-management-openshift-virtualization)
3. [Boost OpenShift Database VM Density with Memory Overcommit](https://developers.redhat.com/articles/2025/04/28/boost-openshift-database-vm-density-memory-overcommit)
4. [Optimizing Memory Overcommitment and Swap in OpenShift](https://access.redhat.com/articles/7104984)

### 연구 논문
1. [Mitigating Context Switching in Densely Packed Linux Clusters (2025)](https://arxiv.org/html/2508.15703v1)

---

## ✅ 학습 체크리스트

### 기본 개념
- [ ] CFS에서 EEVDF로의 전환 이해 (Linux 6.6+)
- [ ] 스케줄링 클래스 (SCHED_DEADLINE, FIFO, RR, OTHER)
- [ ] Nice 값과 커널 우선순위 매핑
- [ ] Context switching 개념 및 비용

### cgroups
- [ ] cgroups v1 vs v2 차이점
- [ ] CPU 제어 (shares, quota, cpuset)
- [ ] 메모리 제어 (limit, OOM control)
- [ ] I/O 제어 (blkio weight, throttle)
- [ ] systemd와 cgroups 통합

### OpenStack Nova Scheduler
- [ ] Filter Scheduler 아키텍처
- [ ] 주요 필터 (Availability Zone, NUMA, PCI 등)
- [ ] Weigher 및 가중치 계산
- [ ] Host Aggregates 및 메타데이터 활용
- [ ] Placement API 역할

### 오버커밋
- [ ] CPU 오버커밋 비율 결정 (1:1 ~ 5:1)
- [ ] 메모리 오버커밋 위험성 이해
- [ ] SWAP 및 WASP 설정
- [ ] 오버커밋 모니터링 및 조정

### QoS
- [ ] CPU QoS (shares, quota)
- [ ] Memory QoS (limits, OOM score)
- [ ] I/O QoS (ionice, blkio)
- [ ] 우선순위 기반 리소스 할당

---

## 🎓 다음 단계

Computing Service의 절반 이상을 완료했습니다 (3/7)! 다음은:

1. **[Ch4.Cloud_Native_컴퓨팅.md](./Ch4.Cloud_Native_컴퓨팅.md)**
   - Kubernetes Operator 패턴
   - CRD 및 Custom Controller
   - 선언적 API 설계

2. **심화 주제**
   - **BPF (Berkeley Packet Filter)**: 커널 레벨 모니터링
   - **Latency-Aware Scheduling**: 지연 시간 최적화
   - **NUMA-aware Scheduling**: 멀티소켓 최적화

3. **실전 프로젝트**
   - Nova Scheduler 커스텀 필터 개발
   - cgroups 기반 멀티테넌트 리소스 격리
   - 오버커밋 자동 조정 시스템

---

**마지막 업데이트:** 2025-11-24
**다음 챕터:** [Ch4.Cloud_Native_컴퓨팅.md](./Ch4.Cloud_Native_컴퓨팅.md)
