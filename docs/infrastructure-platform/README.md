# Infrastructure Platform 개발자 스터디 가이드

KakaoCloud Infrastructure Platform 개발자 포지션을 위한 스터디 가이드입니다.

## 포지션 개요

데이터센터 인프라의 모든 요소를 Cloud-native하게 관리하고 자동화하는 것을 목표로 합니다.
- ClusterAPI & Ironic 기반 대규모 Kubernetes Cluster 구축 자동화
- Kubernetes Operator 패턴을 통한 반복 작업 자동화
- IaC를 통한 인프라 코드화 및 선언적 관리
- Cloud-native 플랫폼 구성 도구를 활용한 DevOps 파이프라인 구축

## 필수 역량

### 1. Kubernetes 심화

**학습 목표:**
- 대규모 Kubernetes Cluster 환경에서의 서비스 운영 능력
- Kubernetes Controller와 Operator에 대한 실무적 이해

**학습 내용:**

- [ ] Kubernetes 아키텍처 심화
  - Control Plane 컴포넌트 이해
  - etcd 운영 및 백업
  - API Server 인증/인가
- [ ] Kubernetes Controller 개발
  - Controller 패턴 이해
  - Informer 및 Workqueue
  - Custom Resource Definition (CRD)
- [ ] Kubernetes Operator 개발
  - Operator SDK 사용법
  - Operator 패턴 구현
  - Helm Operator, Ansible Operator
- [ ] Kubernetes 클러스터 운영
  - 클러스터 업그레이드
  - 노드 관리 및 스케줄링
  - 리소스 할당 및 제한

**실습 프로젝트:**
- 간단한 Kubernetes Controller 개발
- Custom Operator 구현
- 클러스터 모니터링 및 관리 도구 개발

**추가 학습 자료:**
- [Kubernetes Controller 개발 가이드](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Operator SDK 공식 문서](https://sdk.operatorframework.io/)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

---

### 2. ClusterAPI & Ironic

**학습 목표:**
- ClusterAPI를 활용한 Kubernetes provisioning 자동화
- OpenStack Ironic(Baremetal) 환경에서의 운영 및 개발

**학습 내용:**

- [ ] ClusterAPI 기초
  - ClusterAPI 아키텍처 이해
  - Cluster, Machine, MachineDeployment 리소스
  - Infrastructure Provider 이해
- [ ] ClusterAPI 실습
  - 클러스터 생성 자동화
  - 노드 추가/제거 자동화
  - 클러스터 업그레이드 자동화
- [ ] OpenStack Ironic
  - Baremetal Provisioning 이해
  - Ironic API 사용법
  - PXE Boot 및 이미지 관리
- [ ] 통합 개발
  - ClusterAPI와 Ironic 연동
  - 자동화 서비스 개발

**실습 프로젝트:**
- ClusterAPI를 사용한 클러스터 자동 생성 도구
- Ironic을 활용한 Baremetal 서버 프로비저닝

**추가 학습 자료:**
- [ClusterAPI 공식 문서](https://cluster-api.sigs.k8s.io/)
- [OpenStack Ironic 공식 문서](https://docs.openstack.org/ironic/latest/)

---

### 3. Infrastructure as Code (IaC)

**학습 목표:**
- Terraform, Ansible, Packer를 활용한 인프라 자동화
- 선언적 인프라 관리

**학습 내용:**

- [ ] Terraform
  - Terraform 기초 문법
  - Provider 이해 및 사용
  - State 관리
  - Module 작성
  - Workspace 활용
- [ ] Ansible
  - Ansible 기초
  - Playbook 작성
  - Role 작성 및 재사용
  - Ansible Vault를 통한 시크릿 관리
- [ ] Packer
  - 이미지 빌드 자동화
  - 다양한 프로비저너 사용
  - 이미지 최적화

**실습 프로젝트:**
- Terraform으로 인프라 구성 정의
- Ansible으로 서버 설정 자동화
- Packer로 커스텀 이미지 생성

**추가 학습 자료:**
- [Terraform 공식 문서](https://www.terraform.io/docs)
- [Ansible 공식 문서](https://docs.ansible.com/)
- [Packer 공식 문서](https://www.packer.io/docs)

---

### 4. Cloud-native 플랫폼 구성 도구

**학습 목표:**
- Helm, ArgoCD, Prow, Keycloak, Harbor, Gitlab 등 도구 활용
- 컨테이너 기반 마이크로서비스 CI/CD 파이프라인 구축

**학습 내용:**

- [ ] Helm
  - Helm Chart 작성
  - Chart 템플릿 문법
  - Chart 배포 및 관리
  - Helm Operator
- [ ] ArgoCD
  - GitOps를 통한 배포
  - Application 정의
  - Multi-cluster 관리
  - Sync Policy 및 Health Check
- [ ] Prow
  - CI/CD 워크플로우 구성
  - PR 검증 자동화
  - 테스트 자동화
- [ ] Keycloak
  - 인증/인가 서비스 구성
  - OAuth2, OIDC 연동
- [ ] Harbor
  - 컨테이너 레지스트리 운영
  - 이미지 스캔 및 보안 정책
- [ ] GitLab
  - GitLab CI/CD 구성
  - Container Registry 활용

**실습 프로젝트:**
- Helm Chart로 애플리케이션 패키징
- ArgoCD로 GitOps 파이프라인 구축
- 전체 CI/CD 파이프라인 구성

**추가 학습 자료:**
- [Helm 공식 문서](https://helm.sh/docs/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [Prow 공식 문서](https://docs.prow.k8s.io/)

---

### 5. 모니터링 및 가시성

**학습 목표:**
- 서비스 장애 감지 및 성능 최적화를 위한 모니터링 환경 구축

**학습 내용:**

- [ ] 메트릭 수집
  - Prometheus 설정 및 운영
  - Exporter 개발
  - 메트릭 쿼리 (PromQL)
- [ ] 시각화
  - Grafana 대시보드 구성
  - 알림 규칙 설정
- [ ] 로깅
  - 중앙화된 로그 수집
  - ELK Stack 또는 Loki
  - 로그 분석 및 검색
- [ ] 분산 추적
  - OpenTelemetry
  - Jaeger 또는 Zipkin

**실습 프로젝트:**
- 모니터링 스택 구축
- 커스텀 메트릭 수집 및 대시보드 구성

**추가 학습 자료:**
- [Prometheus 공식 문서](https://prometheus.io/docs/)
- [Grafana 공식 문서](https://grafana.com/docs/)

---

### 6. Linux OS 이미지 관리

**학습 목표:**
- Linux OS 이미지 디버깅 및 패키징 능력

**학습 내용:**

- [ ] OS 이미지 구조 이해
  - 부팅 프로세스
  - Init 시스템 (systemd)
  - 파일시스템 구조
- [ ] 이미지 빌드
  - Packer를 활용한 이미지 생성
  - 커스텀 패키지 포함
  - 보안 패치 적용
- [ ] 이미지 디버깅
  - 부팅 문제 해결
  - 네트워크 설정 디버깅
  - 서비스 시작 문제 해결

**실습 프로젝트:**
- 커스텀 Linux 이미지 생성
- 이미지 검증 및 테스트 자동화

---

## 우대 역량

### CNCF 오픈소스 프로젝트 기여

**학습 목표:**
- CNCF 오픈소스 프로젝트에 코드 기여 경험

**학습 내용:**

- [ ] 오픈소스 기여 프로세스 이해
  - Issue 생성 및 해결
  - Pull Request 작성
  - 코드 리뷰 프로세스
- [ ] 주요 CNCF 프로젝트 탐색
  - Kubernetes
  - Prometheus
  - Helm
  - ArgoCD
  - ClusterAPI

**실습:**
- 작은 버그 수정부터 시작
- 문서 개선 기여
- 기능 추가 기여

---

## 학습 로드맵

### 1단계: 기초 (1-2개월)
1. Kubernetes 심화 학습
2. Terraform 기초
3. Helm 기초

### 2단계: 중급 (3-4개월)
1. Kubernetes Operator 개발
2. ClusterAPI 학습 및 실습
3. Ansible, Packer 학습
4. ArgoCD를 통한 GitOps 구축

### 3단계: 고급 (5-6개월)
1. 대규모 클러스터 운영
2. Ironic 연동 개발
3. 모니터링 스택 구축
4. OS 이미지 관리

### 4단계: 실무 (7개월 이상)
1. 오픈소스 기여
2. 종합 프로젝트
3. 실제 운영 환경 경험

---

## 체크리스트

- [ ] Kubernetes Controller/Operator 개발 가능
- [ ] ClusterAPI를 활용한 클러스터 자동화 구현 가능
- [ ] Terraform, Ansible, Packer 활용 가능
- [ ] Helm Chart 작성 및 배포 가능
- [ ] ArgoCD를 통한 GitOps 파이프라인 구축 가능
- [ ] 모니터링 스택 구축 및 운영 가능
- [ ] Linux OS 이미지 관리 가능

---

## 관련 자료

- [공통 역량 스터디 가이드](./common-skills.md) - 먼저 학습 권장
- [전체 학습 커리큘럼](../CLOUD_STUDY.md)




