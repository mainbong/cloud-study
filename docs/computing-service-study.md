# 컴퓨팅 서비스 개발자 스터디 가이드

KakaoCloud 컴퓨팅 서비스 개발자 포지션을 위한 스터디 가이드입니다.

## 포지션 개요

KakaoCloud의 핵심인 IaaS 컴퓨팅 서비스(Beyond Computing Service)를 개발합니다.
- OpenStack + Cloud-Native 기술로 대규모 IaaS 컴퓨팅 서비스 개발
- Virtual Machine, Bare Metal, Volume, Image 등 컴퓨팅 서비스 핵심 기능 개발
- 가상화 및 스케줄링 최적화
- Region/Availability Zone/Cell/Rack 단위의 클라우드 인프라 설계

## 필수 역량

### 1. OpenStack 컴퓨팅 서비스

**학습 목표:**
- OpenStack을 이용한 클라우드 서비스 개발/운영
- 퍼블릭/프라이빗 클라우드 서비스 개발/운영

**학습 내용:**
- [ ] OpenStack 기초
  - OpenStack 아키텍처 이해
  - 주요 서비스 컴포넌트
  - OpenStack API 사용법
- [ ] Nova (Compute Service)
  - Nova 아키텍처
  - 인스턴스 생성 및 관리
  - 하이퍼바이저 통합 (KVM, QEMU 등)
  - 스케줄러 (Filter Scheduler, Chance Scheduler 등)
  - Nova API 확장
- [ ] Cinder (Block Storage Service)
  - 볼륨 생성 및 관리
  - 스토리지 백엔드 (LVM, Ceph 등)
  - 볼륨 스냅샷 및 백업
- [ ] Glance (Image Service)
  - 이미지 업로드 및 관리
  - 이미지 포맷 (QCOW2, RAW 등)
  - 이미지 메타데이터 관리
- [ ] Ironic (Bare Metal Provisioning)
  - Bare Metal 서버 프로비저닝
  - PXE Boot 구성
  - 하드웨어 인벤토리 관리

**실습 프로젝트:**
- OpenStack 환경 구축
- Nova API를 활용한 인스턴스 관리 도구 개발
- 커스텀 스케줄러 개발

**추가 학습 자료:**
- [OpenStack 공식 문서](https://docs.openstack.org/)
- [Nova 개발자 가이드](https://docs.openstack.org/nova/latest/)
- [OpenStack Ironic 문서](https://docs.openstack.org/ironic/latest/)

---

### 2. 가상화 기술 (Linux Kernel / Hypervisor)

**학습 목표:**
- Linux Kernel 및 Hypervisor 기술에 대한 깊은 이해
- 가상화 관련 이슈 발굴 및 해결

**학습 내용:**
- [ ] 가상화 기초
  - 가상화 유형 (Full Virtualization, Para-virtualization)
  - 하이퍼바이저 유형 (Type 1, Type 2)
- [ ] KVM/QEMU
  - KVM 아키텍처
  - QEMU 에뮬레이터
  - libvirt를 통한 가상머신 관리
  - CPU, Memory, I/O 가상화
- [ ] Linux Kernel 가상화
  - Kernel 모듈 이해
  - Namespace 및 Cgroups
  - 가상화 관련 Kernel 기능
- [ ] 성능 최적화
  - CPU 핀닝
  - NUMA 최적화
  - I/O 성능 튜닝
  - 메모리 오버커밋

**실습 프로젝트:**
- KVM 기반 가상머신 생성 및 관리
- 가상머신 성능 모니터링 및 최적화
- 커스텀 가상화 도구 개발

**추가 학습 자료:**
- [KVM 공식 문서](https://www.linux-kvm.org/page/Main_Page)
- [QEMU 공식 문서](https://www.qemu.org/documentation/)
- [Linux Kernel 문서](https://www.kernel.org/doc/html/latest/)

---

### 3. 스케줄링 및 리소스 관리

**학습 목표:**
- 효율적인 리소스 제공을 위한 스케줄링 최적화
- 가상화 관련 이슈 발굴 및 연구/개발

**학습 내용:**
- [ ] 스케줄링 알고리즘
  - CPU 스케줄링 (CFS, Real-time)
  - I/O 스케줄링
  - 가상머신 스케줄링 전략
- [ ] 리소스 할당
  - CPU 할당 및 제한
  - 메모리 할당 및 제한
  - 스토리지 할당
  - 네트워크 대역폭 관리
- [ ] 오버커밋 관리
  - CPU 오버커밋
  - 메모리 오버커밋
  - 리소스 회수 (Reclamation)
- [ ] 스케줄러 개발
  - OpenStack Nova 스케줄러 커스터마이징
  - 커스텀 필터 및 웨이터 개발

**실습 프로젝트:**
- 커스텀 스케줄러 구현
- 리소스 모니터링 및 최적화 도구

**추가 학습 자료:**
- [OpenStack Nova Scheduler 문서](https://docs.openstack.org/nova/latest/admin/scheduler.html)
- [Linux Scheduler 문서](https://www.kernel.org/doc/html/latest/scheduler/)

---

### 4. Cloud-native 컴퓨팅 서비스

**학습 목표:**
- Kubernetes-Native한 선언적 IaaS 서비스 개발
- 모든 마이크로서비스를 컨테이너화하여 운영

**학습 내용:**
- [ ] Kubernetes 기반 서비스 개발
  - Kubernetes Operator 패턴
  - Custom Resource Definition (CRD)
  - Controller 개발
- [ ] 컨테이너화된 서비스 운영
  - 마이크로서비스 아키텍처
  - 서비스 간 통신
  - 서비스 디스커버리
- [ ] 선언적 관리
  - GitOps를 통한 배포
  - Helm Chart 작성
  - ArgoCD를 통한 배포 자동화

**실습 프로젝트:**
- Kubernetes Operator를 활용한 컴퓨팅 서비스 개발
- 컨테이너화된 OpenStack 서비스 배포

**추가 학습 자료:**
- [Kubernetes Operator 패턴](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [Operator SDK](https://sdk.operatorframework.io/)

---

### 5. 클라우드 인프라 설계

**학습 목표:**
- 서비스 확장성을 고려한 Region/Availability Zone/Cell/Rack 단위 인프라 설계

**학습 내용:**
- [ ] 멀티 레벨 아키텍처
  - Region 설계
  - Availability Zone (AZ) 설계
  - Cell 아키텍처
  - Rack 단위 관리
- [ ] 고가용성 설계
  - 장애 격리 (Failure Isolation)
  - 자동 장애 복구
  - 데이터 복제 전략
- [ ] 확장성 설계
  - 수평 확장 (Horizontal Scaling)
  - 수직 확장 (Vertical Scaling)
  - 자동 스케일링
- [ ] 리소스 관리
  - 쿼터 관리
  - 리소스 풀 관리
  - 우선순위 기반 할당

**실습 프로젝트:**
- 멀티 레벨 클라우드 인프라 설계
- 고가용성 구성 구현

**추가 학습 자료:**
- [OpenStack Cells 문서](https://docs.openstack.org/nova/latest/admin/cells.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

### 6. Kubernetes Operator 개발

**학습 목표:**
- Kubernetes Operator(Controller) 관련 개발/운영

**학습 내용:**
- [ ] Kubernetes Controller 패턴
  - Controller 아키텍처
  - Informer 및 Workqueue
  - Reconcile Loop
- [ ] Operator SDK
  - Operator SDK를 사용한 Operator 개발
  - Helm Operator
  - Ansible Operator
  - Go Operator
- [ ] Custom Resource Definition (CRD)
  - CRD 정의
  - Validation 및 Defaulting
  - Finalizer 패턴
- [ ] Operator 배포 및 운영
  - Operator Lifecycle Manager (OLM)
  - Operator 모니터링
  - Operator 업그레이드

**실습 프로젝트:**
- 컴퓨팅 리소스 관리 Operator 개발
- OpenStack 서비스 Operator 개발

**추가 학습 자료:**
- [Kubernetes Controller 개발 가이드](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Operator SDK 공식 문서](https://sdk.operatorframework.io/)

---

### 7. Cloud Network 및 CNI

**학습 목표:**
- Cloud network 혹은 Kubernetes CNI 기술에 대한 깊은 이해

**학습 내용:**
- [ ] Kubernetes 네트워킹
  - Pod 네트워킹
  - Service 네트워킹
  - Network Policy
- [ ] CNI (Container Network Interface)
  - CNI 플러그인 아키텍처
  - 주요 CNI 플러그인 (Calico, Flannel, Cilium 등)
  - 커스텀 CNI 플러그인 개발
- [ ] 네트워크 가상화
  - VXLAN, GRE 등 오버레이 네트워크
  - 언더레이 네트워크 통합
- [ ] 서비스 메시
  - Istio, Linkerd 등
  - 마이크로서비스 네트워킹

**실습 프로젝트:**
- 커스텀 CNI 플러그인 개발
- Service Mesh 구성

**추가 학습 자료:**
- [CNI 공식 문서](https://www.cni.dev/)
- [Cilium 공식 문서](https://docs.cilium.io/)
- [Istio 공식 문서](https://istio.io/latest/docs/)

---

## 우대 역량

### 글로벌 CSP 활용 경험

**학습 목표:**
- AWS, GCP, MS Azure 등 글로벌 CSP 활용 경험

**학습 내용:**
- [ ] AWS
  - EC2, EBS, AMI
  - Auto Scaling
  - Lambda
- [ ] GCP
  - Compute Engine
  - Cloud Storage
  - Cloud Functions
- [ ] Azure
  - Virtual Machines
  - Managed Disks
  - Functions

**실습:**
- 각 CSP에서 컴퓨팅 서비스 사용 경험

### CNCF 오픈소스 기여

**학습 목표:**
- CNCF 오픈소스 코드 기여 경험

**학습 내용:**
- [ ] 오픈소스 기여 프로세스
- [ ] 주요 CNCF 프로젝트 탐색
  - Kubernetes
  - OpenStack (일부 CNCF 프로젝트와 연관)
  - CRI-O, containerd

**실습:**
- 작은 버그 수정부터 시작
- 기능 추가 기여

---

## 학습 로드맵

### 1단계: 기초 (1-2개월)
1. OpenStack 기초 및 Nova 학습
2. KVM/QEMU 가상화 기초
3. Linux Kernel 기초

### 2단계: 중급 (3-4개월)
1. OpenStack 심화 (Cinder, Glance, Ironic)
2. 가상화 성능 최적화
3. 스케줄링 알고리즘 학습

### 3단계: 고급 (5-6개월)
1. Kubernetes Operator 개발
2. 클라우드 인프라 설계
3. CNI 기술 심화

### 4단계: 실무 (7개월 이상)
1. 대규모 IaaS 서비스 개발
2. 종합 프로젝트
3. 실제 운영 환경 경험

---

## 체크리스트

- [ ] OpenStack 기반 컴퓨팅 서비스 개발 가능
- [ ] KVM/QEMU 가상화 기술 이해 및 활용 가능
- [ ] Linux Kernel 가상화 기능 이해
- [ ] 스케줄링 알고리즘 이해 및 커스터마이징 가능
- [ ] Kubernetes Operator 개발 가능
- [ ] 클라우드 인프라 설계 능력 보유
- [ ] CNI 기술 이해 및 활용 가능

---

## 관련 자료

- [공통 역량 스터디 가이드](./common-skills.md) - 먼저 학습 권장
- [전체 학습 커리큘럼](../CLOUD_STUDY.md)




