# 공통 역량 스터디 가이드

모든 포지션에서 공통적으로 요구되는 역량들을 학습하는 가이드입니다.

## 기본 요구사항

- 컴퓨터 관련 전공 + 1년 이상의 경력 또는 관련 분야 3년 이상의 경력

## 공통 역량 목록

### 1. Linux 기반 환경 운영

**학습 목표:**
- 대규모 Linux 환경에서의 서비스 운영 능력
- Linux 시스템 관리 및 트러블슈팅

**학습 내용:**
- [ ] Linux 시스템 관리 기초
  - 파일시스템 관리
  - 프로세스 관리
  - 네트워크 설정
  - 시스템 모니터링
- [ ] Shell Scripting
  - Bash 스크립트 작성
  - 자동화 스크립트 개발
- [ ] 시스템 성능 분석
  - CPU, Memory, I/O 모니터링
  - 로그 분석 및 디버깅

**실습 자료:**
- `phase-1/linux-vm/` 디렉토리 참고

**추가 학습 자료:**
- [Linux System Administration Guide](https://www.tldp.org/LDP/sag/html/)
- [Advanced Bash Scripting Guide](https://tldp.org/LDP/abs/html/)

---

### 2. 프로그래밍 언어 (Python/GO)

**학습 목표:**
- Python 또는 GO 언어를 활용한 API 백엔드 설계 및 개발 역량

#### Python

**학습 내용:**
- [ ] Python 기초 문법
- [ ] 객체지향 프로그래밍
- [ ] 비동기 프로그래밍 (asyncio)
- [ ] API 프레임워크
  - FastAPI 또는 Flask
  - RESTful API 설계
- [ ] 테스트 작성
  - pytest
  - 단위 테스트, 통합 테스트

**실습 프로젝트:**
- 간단한 REST API 서버 구현
- Kubernetes API 클라이언트 개발

**추가 학습 자료:**
- [Python 공식 문서](https://docs.python.org/3/)
- [FastAPI 공식 문서](https://fastapi.tiangolo.com/)

#### GO

**학습 내용:**
- [ ] Go 기초 문법
- [ ] Goroutine 및 Channel
- [ ] gRPC 서버/클라이언트 개발
- [ ] RESTful API 개발
  - Gin, Echo 등 프레임워크
- [ ] 테스트 작성
  - Go testing 패키지

**실습 프로젝트:**
- gRPC 서비스 구현
- Kubernetes Controller 개발

**추가 학습 자료:**
- [Go 공식 문서](https://go.dev/doc/)
- [Effective Go](https://go.dev/doc/effective_go)

---

### 3. Cloud-native 환경

**학습 목표:**
- Cloud-native 환경에서의 개발 및 운영 능력
- 컨테이너 기반 마이크로서비스 아키텍처 이해

**학습 내용:**
- [ ] 컨테이너 기초
  - Docker 기초
  - 컨테이너 이미지 빌드 및 관리
  - 멀티 스테이지 빌드
- [ ] Kubernetes 기초
  - Kubernetes 아키텍처 이해
  - Pod, Service, Deployment 등 기본 리소스
  - ConfigMap, Secret 관리
- [ ] Cloud-native 개발 패턴
  - 12-Factor App
  - Stateless 애플리케이션 설계
  - Health Check 및 Liveness/Readiness Probe

**실습 자료:**
- `phase-2/containers/` 디렉토리 참고

**추가 학습 자료:**
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [CNCF Cloud Native Landscape](https://landscape.cncf.io/)

---

### 4. DevOps 도구 및 실무

**학습 목표:**
- DevOps 파이프라인 구축 및 운영 능력
- CI/CD 도구 활용

**학습 내용:**
- [ ] 버전 관리
  - Git 기초 및 고급 사용법
  - Git Workflow (Git Flow, GitHub Flow)
- [ ] CI/CD 파이프라인
  - Jenkins 또는 GitLab CI
  - GitHub Actions
- [ ] GitOps
  - ArgoCD 또는 Flux
  - 선언적 애플리케이션 배포
- [ ] 모니터링 및 로깅
  - Prometheus, Grafana
  - ELK Stack 또는 Loki

**실습 프로젝트:**
- 간단한 CI/CD 파이프라인 구축
- GitOps를 통한 애플리케이션 배포

**추가 학습 자료:**
- [GitOps 공식 문서](https://www.gitops.tech/)
- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)

---

### 5. 시스템 설계 및 아키텍처

**학습 목표:**
- 확장 가능하고 안정적인 시스템 설계 능력
- 분산 시스템 이해

**학습 내용:**
- [ ] 시스템 설계 기초
  - 확장성 (Scalability)
  - 가용성 (Availability)
  - 일관성 (Consistency)
- [ ] 분산 시스템
  - 분산 시스템의 도전 과제
  - CAP 정리
  - 분산 트랜잭션
- [ ] 마이크로서비스 아키텍처
  - 서비스 분해 전략
  - 서비스 간 통신
  - 서비스 메시 (Service Mesh)

**추가 학습 자료:**
- [Designing Data-Intensive Applications](https://www.oreilly.com/library/view/designing-data-intensive-applications/9781491903063/)
- [Microservices Patterns](https://microservices.io/patterns/)

---

## 학습 로드맵

### 초급 (1-3개월)
1. Linux 시스템 관리 기초
2. Python 또는 GO 언어 기초
3. Docker 및 Kubernetes 기초
4. Git 및 기본 DevOps 도구

### 중급 (4-6개월)
1. 고급 Linux 운영
2. API 설계 및 개발
3. Kubernetes 심화
4. CI/CD 파이프라인 구축

### 고급 (7개월 이상)
1. 시스템 아키텍처 설계
2. 분산 시스템 운영
3. 성능 최적화 및 트러블슈팅

---

## 체크리스트

각 역량별로 학습 완료 여부를 체크하세요:

- [ ] Linux 시스템 관리 능숙
- [ ] Python 또는 GO로 API 개발 가능
- [ ] Docker 및 Kubernetes 기본 사용 가능
- [ ] CI/CD 파이프라인 구축 경험
- [ ] 시스템 설계 기초 이해
- [ ] 분산 시스템 기본 개념 이해

---

## 다음 단계

공통 역량을 학습한 후, 관심 있는 포지션별 스터디 가이드를 참고하세요:

- [Infrastructure Platform 개발자 스터디 가이드](./infrastructure-platform-study.md)
- [네트워킹 서비스 개발자 스터디 가이드](./networking-service-study.md)
- [컴퓨팅 서비스 개발자 스터디 가이드](./computing-service-study.md)

