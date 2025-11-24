# 네트워킹 서비스 개발자 스터디 가이드

KakaoCloud 네트워킹 서비스 개발자 포지션을 위한 스터디 가이드입니다.

## 포지션 개요

KakaoCloud의 핵심인 IaaS 네트워킹 서비스(Beyond Networking Service)를 개발합니다.
- Public Cloud 환경에서 확장 가능하고 안정적인 네트워크 시스템 설계
- API 기반 가상화된 언더레이 네트워크 설계
- Network Function 개발 및 조합을 통한 새로운 네트워크 서비스 구현

## 필수 역량

### 1. 네트워크 프로토콜 및 시스템 설계

**학습 목표:**
- 시스템 구조와 네트워크 프로토콜에 대한 깊은 이해
- 안정적이고 확장 가능한 시스템 설계 능력

**학습 내용:**

- [ ] 네트워크 프로토콜 심화
  - TCP/IP 스택 심화 이해
  - BGP, OSPF 등 라우팅 프로토콜
  - VLAN, VXLAN 등 가상화 기술
  - SDN (Software Defined Networking) 개념
- [ ] 네트워크 아키텍처 설계
  - 스케일 아웃 vs 스케일 업
  - 로드 밸런싱 전략
  - 고가용성 설계
  - 네트워크 분할 및 격리
- [ ] 분산 시스템 설계
  - 마이크로서비스 아키텍처
  - 서비스 간 통신 패턴
  - 이벤트 기반 아키텍처

**실습 프로젝트:**
- 네트워크 토폴로지 설계
- 분산 네트워크 서비스 아키텍처 설계

**추가 학습 자료:**
- [Computer Networks: A Systems Approach](https://book.systemsapproach.org/)
- [High Performance Browser Networking](https://hpbn.co/)

---

### 2. API 설계 및 개발

**학습 목표:**
- Stateless한 API 서버 설계 및 구현
- RESTful 또는 gRPC 아키텍처 이해

**학습 내용:**

- [ ] RESTful API 설계
  - REST 원칙 이해
  - 리소스 모델링
  - HTTP 메서드 및 상태 코드
  - API 버전 관리
  - OpenAPI/Swagger 스펙 작성
- [ ] gRPC 개발
  - Protocol Buffers
  - gRPC 서버/클라이언트 개발
  - 스트리밍 (Unary, Server Streaming, Client Streaming, Bidirectional)
  - 인터셉터 및 미들웨어
- [ ] API 성능 최적화
  - 캐싱 전략
  - Rate Limiting
  - Connection Pooling
  - 비동기 처리

**실습 프로젝트:**
- RESTful API 서버 구현
- gRPC 서비스 구현
- API 게이트웨이 구성

**추가 학습 자료:**
- [RESTful API Design Guide](https://restfulapi.net/)
- [gRPC 공식 문서](https://grpc.io/docs/)

---

### 3. OpenStack 기반 서비스 개발

**학습 목표:**
- OpenStack 기반 서비스 개발 주도적 수행
- 퍼블릭 클라우드 환경에서의 네트워크 설계 및 운영

**학습 내용:**

- [ ] OpenStack 기초
  - OpenStack 아키텍처 이해
  - 주요 컴포넌트 (Nova, Neutron, Cinder 등)
  - OpenStack API 사용법
- [ ] Neutron (Networking Service)
  - Neutron 아키텍처
  - 네트워크, 서브넷, 라우터 리소스
  - 플러그인 및 드라이버
  - ML2 (Modular Layer 2) 플러그인
- [ ] OpenStack 개발
  - OpenStack SDK 사용
  - 커스텀 플러그인 개발
  - API 확장 개발
- [ ] 클라우드 네트워크 설계
  - 가상 네트워크 구축
  - 네트워크 격리 및 보안
  - 멀티 테넌트 네트워크

**실습 프로젝트:**
- OpenStack Neutron을 활용한 네트워크 서비스 개발
- 커스텀 네트워크 플러그인 개발

**추가 학습 자료:**
- [OpenStack 공식 문서](https://docs.openstack.org/)
- [Neutron 개발자 가이드](https://docs.openstack.org/neutron/latest/)

---

### 4. 네트워크 가상화 (NFV, SDN)

**학습 목표:**
- 데이터센터 네트워크 및 네트워크 가상화에 대한 깊이 있는 이해
- 복잡한 네트워크 환경에서의 문제 해결 능력

**학습 내용:**

- [ ] NFV (Network Functions Virtualization)
  - NFV 아키텍처
  - VNF (Virtual Network Function) 개발
  - NFV 오케스트레이션
- [ ] SDN (Software Defined Networking)
  - SDN 컨트롤러 (OpenDaylight, ONOS 등)
  - OpenFlow 프로토콜
  - 네트워크 프로그래밍
- [ ] 네트워크 오버레이
  - VXLAN, GRE, Geneve
  - 오버레이 네트워크 설계
  - 언더레이 네트워크 최적화

**실습 프로젝트:**
- 간단한 VNF 개발
- SDN 컨트롤러 연동

**추가 학습 자료:**
- [ETSI NFV 문서](https://www.etsi.org/technologies/nfv)
- [OpenDaylight 공식 문서](https://www.opendaylight.org/)

---

### 5. 네트워크 어플라이언스 연동

**학습 목표:**
- 다양한 네트워크 어플라이언스(FW, LB, Switch)를 내부 시스템과 연동
- 고가용성과 확장성을 고려한 안정적인 통합 서비스 구축

**학습 내용:**

- [ ] 방화벽 (Firewall) 연동
  - 방화벽 API 이해
  - 정책 관리 자동화
  - 방화벽 클러스터링
- [ ] 로드 밸런서 (Load Balancer) 연동
  - 로드 밸런싱 알고리즘
  - Health Check 구성
  - SSL/TLS 종료
  - 고가용성 구성
- [ ] 스위치 (Switch) 연동
  - 관리형 스위치 API
  - VLAN 구성 자동화
  - 스위치 모니터링
- [ ] 통합 서비스 설계
  - 어플라이언스 오케스트레이션
  - 자동 스케일링
  - 장애 복구 자동화

**실습 프로젝트:**
- 방화벽 정책 자동화 도구 개발
- 로드 밸런서 자동 구성 시스템

**추가 학습 자료:**
- [F5 Networks API 문서](https://clouddocs.f5.com/)
- [HAProxy 문서](http://www.haproxy.org/#docs)

---

### 6. Event-driven 아키텍처

**학습 목표:**
- Event-driven 아키텍처 기반 마이크로서비스 설계 및 개발

**학습 내용:**

- [ ] 이벤트 기반 아키텍처 패턴
  - Event Sourcing
  - CQRS (Command Query Responsibility Segregation)
  - Pub/Sub 패턴
- [ ] 메시지 브로커
  - RabbitMQ, Kafka 등
  - 메시지 큐 패턴
  - 이벤트 스트리밍
- [ ] 이벤트 기반 서비스 개발
  - 이벤트 발행 및 구독
  - 이벤트 순서 보장
  - 이벤트 재생 및 복구

**실습 프로젝트:**
- 이벤트 기반 네트워크 서비스 구현
- 메시지 브로커를 활용한 서비스 통신

**추가 학습 자료:**
- [Event-Driven Architecture Patterns](https://www.oreilly.com/library/view/event-driven-architecture/9781492057888/)
- [Apache Kafka 공식 문서](https://kafka.apache.org/documentation/)

---

### 7. Cloud-native 환경 개발

**학습 목표:**
- Cloud-native 환경에서의 개발 및 운영
- Kubernetes, GitOps 등 생산성 도구 활용

**학습 내용:**

- [ ] Kubernetes 네트워킹
  - CNI (Container Network Interface) 이해
  - Service, Ingress 리소스
  - Network Policy
  - Service Mesh (Istio, Linkerd)
- [ ] Kubernetes 네트워크 플러그인
  - Calico, Flannel, Cilium 등
  - 커스텀 CNI 플러그인 개발
- [ ] GitOps를 통한 네트워크 구성 관리
  - ArgoCD를 활용한 네트워크 정책 배포
  - 선언적 네트워크 구성

**실습 프로젝트:**
- Kubernetes 기반 네트워크 서비스 개발
- Service Mesh 구성 및 활용

**추가 학습 자료:**
- [Kubernetes 네트워킹 공식 문서](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Cilium 공식 문서](https://docs.cilium.io/)

---

## 우대 역량

### 퍼블릭 클라우드 네트워크 경험

**학습 목표:**
- 퍼블릭 클라우드 환경에서의 네트워크 설계 및 운영 실무 경험

**학습 내용:**

- [ ] AWS 네트워킹
  - VPC, Subnet, Route Table
  - Security Group, NACL
  - ELB, ALB, NLB
  - Direct Connect, VPN
- [ ] GCP 네트워킹
  - VPC, Subnet
  - Cloud Load Balancing
  - Cloud Interconnect
- [ ] Azure 네트워킹
  - Virtual Network
  - Load Balancer
  - ExpressRoute

**실습:**
- 각 클라우드 플랫폼에서 네트워크 구성 실습

---

## 학습 로드맵

### 1단계: 기초 (1-2개월)
1. 네트워크 프로토콜 심화 학습
2. RESTful API 및 gRPC 개발
3. OpenStack 기초

### 2단계: 중급 (3-4개월)
1. OpenStack Neutron 심화
2. NFV, SDN 학습
3. 네트워크 어플라이언스 연동

### 3단계: 고급 (5-6개월)
1. Event-driven 아키텍처 구현
2. Kubernetes 네트워킹
3. Service Mesh 구성

### 4단계: 실무 (7개월 이상)
1. 대규모 네트워크 시스템 설계
2. 종합 프로젝트
3. 실제 운영 환경 경험

---

## 체크리스트

- [ ] 네트워크 프로토콜 및 시스템 설계 능력 보유
- [ ] RESTful API 및 gRPC 서비스 개발 가능
- [ ] OpenStack 기반 서비스 개발 가능
- [ ] NFV, SDN에 대한 이해
- [ ] 네트워크 어플라이언스 연동 경험
- [ ] Event-driven 아키텍처 구현 가능
- [ ] Kubernetes 네트워킹 이해 및 활용 가능

---

## 관련 자료

- [공통 역량 스터디 가이드](./common-skills.md) - 먼저 학습 권장
- [전체 학습 커리큘럼](../CLOUD_STUDY.md)




