# 클라우드 교육 자료 재구성 및 작성 계획

## 📋 프로젝트 개요

기존 스터디 플랜 문서들을 포지션별 폴더로 재구성하고, 각 주제에 대한 상세한 학습 자료를 작성하는 프로젝트입니다.

**목표:** 41개의 상세 학습 자료 작성
**방법:** 웹 검색을 통한 자료 조사, 정리, 작성

---

## 📊 전체 진행 상황

- [x] **1단계:** 실행 계획 문서 작성
- [x] **2단계:** 폴더 구조 생성 (4개)
- [x] **3단계:** 기존 스터디 플랜 이동
- [ ] **4단계:** 상세 학습 자료 작성 (41개)
  - [x] Common Skills (5개)
  - [x] Computing Service (7개)
  - [x] Infrastructure Platform (6개)
  - [x] Networking Service (7개)
  - [ ] IAM/Storage Service (12개)
- [ ] **5단계:** 최상위 README.md 업데이트

---

## 📁 폴더 구조

```
docs/
├── README.md (업데이트 필요)
├── IMPLEMENTATION_PLAN.md (이 파일)
├── common-skills/
│   ├── README.md (common-skills.md 이동)
│   └── [5개 Chapter 파일]
├── computing-service/
│   ├── README.md (computing-service-study.md 이동)
│   └── [7개 Chapter 파일]
├── infrastructure-platform/
│   ├── README.md (infrastructure-platform-study.md 이동)
│   └── [6개 Chapter 파일]
├── networking-service/
│   ├── README.md (networking-service-study.md 이동)
│   └── [7개 Chapter 파일]
└── iam-storage-service/
    ├── README.md (새로 작성)
    └── [12개 Chapter 파일]
```

---

## ✅ 세부 작업 체크리스트

### 1단계: 기반 작업

- [x] IMPLEMENTATION_PLAN.md 작성
- [x] 폴더 생성: `common-skills/`
- [x] 폴더 생성: `computing-service/`
- [x] 폴더 생성: `infrastructure-platform/`
- [x] 폴더 생성: `networking-service/`
- [x] 폴더 생성: `iam-storage-service/`

### 2단계: 스터디 플랜 이동

- [x] `common-skills.md` → `common-skills/README.md`
- [x] `computing-service-study.md` → `computing-service/README.md`
- [x] `infrastructure-platform-study.md` → `infrastructure-platform/README.md`
- [x] `networking-service-study.md` → `networking-service/README.md`

---

## 📚 학습 자료 작성 체크리스트

### Common Skills (공통 역량) - 5개 파일

- [x] **Ch1.Linux_운영.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Linux 시스템 관리, Shell 스크립팅, 성능 분석

- [x] **Ch2.Python_GO.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Python (FastAPI/Flask, asyncio), GO (Goroutines, gRPC)

- [x] **Ch3.Cloud_Native.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Docker 기초, Kubernetes 기초, 12-Factor App

- [x] **Ch4.DevOps.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Git, CI/CD, GitOps, 모니터링

- [x] **Ch5.시스템_설계.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Scalability, 분산 시스템, 마이크로서비스

---

### Computing Service (컴퓨팅 서비스) - 7개 파일

- [x] **Ch1.OpenStack.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Nova, Cinder, Glance, Ironic

- [x] **Ch2.가상화_기술.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: KVM/QEMU, Linux Kernel 가상화, 성능 최적화

- [x] **Ch3.스케줄링.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: 스케줄링 알고리즘, 리소스 할당, Overcommit

- [x] **Ch4.Cloud_Native_컴퓨팅.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Kubernetes Operator 패턴, CRD, Controller

- [x] **Ch5.클라우드_인프라_설계.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Multi-level 아키텍처, HA, Scalability

- [x] **Ch6.Kubernetes_Operator.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Controller 패턴, Operator SDK, CRD 개발

- [x] **Ch7.Cloud_Network_CNI.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Kubernetes 네트워킹, CNI 플러그인, Service Mesh

---

### Infrastructure Platform (인프라 플랫폼) - 6개 파일

- [x] **Ch1.Kubernetes_심화.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Kubernetes 아키텍처, Controller 개발, CRD, Operator

- [x] **Ch2.ClusterAPI_Ironic.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: ClusterAPI 아키텍처, Kubernetes 프로비저닝, Ironic

- [x] **Ch3.IaC.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Terraform, Ansible, Packer

- [x] **Ch4.Cloud_Native_플랫폼_도구.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Helm, ArgoCD, Prow, Keycloak, Harbor, GitLab

- [x] **Ch5.모니터링.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Prometheus, Grafana, ELK/Loki, OpenTelemetry

- [x] **Ch6.Linux_OS_이미지.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: OS 이미지 구조, Packer 빌드, 디버깅

---

### Networking Service (네트워킹 서비스) - 7개 파일

- [x] **Ch1.네트워크_프로토콜.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: TCP/IP, Routing (BGP, OSPF), VLAN/VXLAN, SDN

- [x] **Ch2.API_설계.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: RESTful API, gRPC, API 성능 최적화

- [x] **Ch3.OpenStack_네트워킹.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Neutron, ML2 플러그인, 커스텀 플러그인 개발

- [x] **Ch4.네트워크_가상화.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: NFV, SDN Controllers, Network Overlays

- [x] **Ch5.네트워크_어플라이언스.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Firewall, Load Balancer, Switch 연동

- [x] **Ch6.Event_Driven.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Event Sourcing, CQRS, Message Brokers

- [x] **Ch7.Cloud_Native_네트워킹.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Kubernetes 네트워킹, CNI, Network Policy, Service Mesh

---

### IAM/Storage Service (IAM/스토리지 서비스) - 12개 파일

- [x] **Ch1.OpenStack_Keystone.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Keystone 아키텍처, Identity 백엔드, Token 관리, Federation

- [x] **Ch2.OAuth_OIDC_JWT.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: OAuth 2.0, OIDC, JWT, Go 구현

- [x] **Ch3.RBAC_ABAC.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: RBAC, ABAC, Casbin, 정책 엔진

- [x] **Ch4.Policy_Engine_OPA.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Open Policy Agent, Rego, Policy-as-Code

- [x] **Ch5.Secrets_Management_Vault.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: HashiCorp Vault, 동적 시크릿, 암호화 서비스

- [x] **Ch6.Service_Mesh_Security.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: mTLS, SPIFFE/SPIRE, Zero Trust, Envoy

- [x] **Ch7.OpenStack_Swift.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Swift 아키텍처, Ring, Replication, 성능 튜닝

- [x] **Ch8.Object_Storage_S3.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: S3 API, MinIO, Bucket 정책, Go SDK

- [x] **Ch9.Ceph_아키텍처.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Ceph 컴포넌트, RADOS, CRUSH, RBD/CephFS/RGW

- [x] **Ch10.Ceph_운영_성능.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: 클러스터 배포, 모니터링, 성능 최적화, 트러블슈팅

- [x] **Ch11.Block_Storage_Cinder.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Cinder 아키텍처, Volume Driver, QoS, Multi-backend

- [x] **Ch12.Storage_Lifecycle.md**
  - 학습 목표, 핵심 개념, 실습 가이드, 예제 코드, 참고 자료
  - 주제: Storage Tiering, Lifecycle 정책, 압축, 비용 최적화

---

## 📝 각 학습 자료의 작성 구조

각 Chapter 파일은 다음 구조로 작성됩니다:

1. **개요 및 학습 목표**
   - 해당 주제의 중요성
   - 학습 후 얻을 수 있는 역량

2. **핵심 개념 및 이론**
   - 웹 검색을 통해 수집한 최신 정보
   - 핵심 개념 설명
   - 아키텍처 및 동작 원리

3. **실습 가이드 (Hands-on)**
   - 단계별 실습 가이드
   - 환경 설정 방법
   - 실제 사용 시나리오

4. **예제 코드**
   - 실무에서 사용 가능한 코드 예제
   - 주석이 포함된 설명

5. **참고 자료**
   - 공식 문서 링크
   - 추천 튜토리얼
   - 관련 블로그/아티클

---

## 🎯 작업 진행 방법

1. 각 Chapter 파일을 작성할 때마다 해당 체크박스를 [x]로 체크
2. 웹 검색을 통해 최신 정보 수집
3. 실무 중심의 내용으로 작성
4. 예제 코드는 실제 동작 가능한 코드로 작성
5. 진행 상황을 이 파일에서 실시간으로 업데이트

---

## 📅 작업 이력

- **2025-11-24**: 프로젝트 시작, IMPLEMENTATION_PLAN.md 작성
