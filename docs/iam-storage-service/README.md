# IAM/Storage 서비스 개발자 스터디 가이드

KakaoCloud IAM/Storage 서비스 개발자 포지션을 위한 스터디 가이드입니다.

## 포지션 개요

KakaoCloud의 핵심인 IaaS IAM 및 Storage 서비스를 개발합니다.

- 클라우드 인증/인가 시스템(IAM) 설계 및 개발
- OAuth2/OIDC 기반 현대적인 인증 시스템 구현
- 분산 스토리지 시스템(Swift, Ceph) 운영 및 최적화
- 대용량 오브젝트 스토리지 및 블록 스토리지 서비스 제공
- 멀티 테넌트 환경에서 보안과 격리 보장
- Storage lifecycle 정책을 통한 비용 최적화

## 필수 역량

### 공통 스킬 (Prerequisites)

IAM/Storage 서비스 개발자는 다음 공통 역량을 갖추어야 합니다:

- [공통 역량 스터디 가이드](../common-skills/README.md) 참고
  - Linux 시스템 운영
  - **Go 언어** (Primary), Python (Secondary)
  - Cloud Native 기초
  - DevOps 파이프라인
  - 시스템 설계

---

## IAM (Identity & Access Management) - 6개 챕터

### 1. OpenStack Keystone

**학습 목표:**

- OpenStack Keystone을 활용한 클라우드 IAM 시스템 개발
- 멀티 테넌트 인증/인가 아키텍처 설계

**학습 내용:**

- [ ] Keystone 아키텍처
  - Identity, Resource, Assignment, Token, Catalog 서비스
  - Fernet/JWS/JWT 토큰 포맷
  - Domain, Project, User, Role 계층 구조
- [ ] Identity 백엔드
  - SQL 백엔드
  - LDAP/Active Directory 통합
  - Federation (SAML, OIDC)
- [ ] 정책 관리
  - policy.json 설정
  - RBAC 정책 엔진
  - 커스텀 정책 개발
- [ ] Keystone API v3
  - 토큰 발급 및 검증
  - 서비스 카탈로그 관리
  - 프로젝트/도메인 관리

**실습 프로젝트:**

- Keystone 기반 멀티 테넌트 IAM 시스템 구축
- LDAP Federation 구성
- 커스텀 인증 플러그인 개발

---

### 2. OAuth 2.0 / OIDC / JWT

**학습 목표:**

- OAuth 2.0 / OIDC 프로토콜 구현
- JWT 기반 토큰 인증 시스템 개발

**학습 내용:**

- [ ] OAuth 2.0 흐름
  - Authorization Code Flow
  - Client Credentials Flow
  - Refresh Token Rotation
  - PKCE (Proof Key for Code Exchange)
- [ ] OpenID Connect (OIDC)
  - ID Token 구조
  - UserInfo Endpoint
  - Discovery 메커니즘
- [ ] JWT (JSON Web Token)
  - JWT 구조 (Header, Payload, Signature)
  - 서명 알고리즘 (RS256, ES256)
  - 토큰 검증 및 만료 처리
- [ ] Go 구현
  - go-oidc 라이브러리
  - golang-jwt 활용
  - 토큰 미들웨어 개발

**실습 프로젝트:**

- OAuth 2.0 Authorization Server 구현
- OIDC Provider 개발
- JWT 기반 API 인증 시스템

---

### 3. RBAC & ABAC

**학습 목표:**

- RBAC/ABAC 접근 제어 모델 설계
- Casbin을 활용한 정책 엔진 구현

**학습 내용:**

- [ ] RBAC (Role-Based Access Control)
  - Role, Permission 모델링
  - 계층적 역할 구조
  - 동적 역할 할당
- [ ] ABAC (Attribute-Based Access Control)
  - Subject, Resource, Action, Environment 속성
  - 정책 평가 엔진
  - 복합 조건 처리
- [ ] RBAC vs ABAC 비교
  - 사용 사례별 적합성
  - 성능 및 확장성 고려사항
- [ ] Casbin 정책 프레임워크
  - 모델 정의 (PERM, ACL)
  - 정책 파일 관리
  - Go 통합

**실습 프로젝트:**

- Casbin 기반 멀티 테넌트 권한 관리 시스템
- ABAC 정책 엔진 개발
- 역할 계층 구조 설계

---

### 4. Policy Engine (OPA)

**학습 목표:**

- Open Policy Agent(OPA)를 활용한 정책 기반 접근 제어
- Rego 언어로 정책 작성 및 테스트

**학습 내용:**

- [ ] OPA 아키텍처
  - Policy Decision Point (PDP)
  - Policy Enforcement Point (PEP)
  - Policy Information Point (PIP)
- [ ] Rego 정책 언어
  - 규칙 작성
  - 데이터 쿼리
  - 함수 정의
- [ ] OPA 통합 패턴
  - Kubernetes Admission Control
  - API Gateway 통합
  - 마이크로서비스 인가
- [ ] 정책 테스트 및 디버깅
  - OPA Test Framework
  - Policy Bundle 관리
  - 성능 최적화

**실습 프로젝트:**

- OPA 기반 Kubernetes Admission Controller
- API 인가 정책 개발
- 멀티 테넌트 리소스 격리 정책

---

### 5. Secrets Management (Vault)

**학습 목표:**

- HashiCorp Vault를 활용한 시크릿 관리
- 동적 시크릿 생성 및 암호화 서비스 구현

**학습 내용:**

- [ ] Vault 아키텍처
  - Storage Backend (Consul, etcd)
  - Seal/Unseal 메커니즘
  - HA 구성
- [ ] Secrets Engines
  - KV (Key-Value) v2
  - Database (동적 자격증명)
  - PKI (인증서 발급)
  - Transit (암호화 as a Service)
- [ ] 인증 메서드
  - Kubernetes Auth
  - AppRole
  - JWT/OIDC
- [ ] Vault Agent
  - 자동 토큰 갱신
  - 템플릿 렌더링
  - Sidecar 인젝션
- [ ] Go SDK 통합
  - vault/api 패키지
  - 동적 시크릿 관리
  - 암호화/복호화

**실습 프로젝트:**

- Vault 기반 시크릿 관리 시스템
- 데이터베이스 동적 자격증명
- PKI 인증서 자동화

---

### 6. Service Mesh Security

**학습 목표:**

- mTLS를 활용한 서비스 간 인증
- SPIFFE/SPIRE 기반 Identity 관리

**학습 내용:**

- [ ] mTLS (mutual TLS)
  - 인증서 기반 인증
  - 자동 인증서 로테이션
  - Envoy proxy 통합
- [ ] SPIFFE (Secure Production Identity Framework for Everyone)
  - SPIFFE ID 구조
  - SVID (SPIFFE Verifiable Identity Document)
  - Trust Bundle 관리
- [ ] SPIRE (SPIFFE Runtime Environment)
  - Workload API
  - Attestation 메커니즘
  - Federation
- [ ] Zero Trust 네트워킹
  - 서비스 간 인증
  - 최소 권한 원칙
  - 트래픽 암호화
- [ ] Go gRPC mTLS
  - 인증서 로딩
  - TLS 설정
  - 클라이언트/서버 구현

**실습 프로젝트:**

- SPIRE 기반 서비스 Identity 관리
- mTLS gRPC 서비스 개발
- Istio 보안 정책 구성

---

## Storage - 6개 챕터

### 7. OpenStack Swift

**학습 목표:**

- OpenStack Swift 오브젝트 스토리지 아키텍처 이해
- 대규모 분산 스토리지 운영

**학습 내용:**

- [ ] Swift 아키텍처
  - Proxy Server
  - Account/Container/Object Server
  - Ring과 일관된 해싱
- [ ] 데이터 복제 및 내구성
  - Replication
  - Erasure Coding
  - Consistency 모델
- [ ] Swift API
  - 오브젝트 업로드/다운로드
  - Container ACL
  - Large Object Support (SLO, DLO)
- [ ] 미들웨어 커스터마이징
  - Custom Middleware 개발
  - 인증/인가 통합
- [ ] 성능 튜닝
  - 네트워크 최적화
  - 디스크 I/O 튜닝
  - 캐싱 전략

**실습 프로젝트:**

- Swift 클러스터 구축
- 커스텀 미들웨어 개발
- 성능 벤치마킹

---

### 8. Object Storage & S3 API

**학습 목표:**

- S3 호환 API 구현
- MinIO를 활용한 오브젝트 스토리지 운영

**학습 내용:**

- [ ] S3 API 호환성
  - Bucket/Object 작업
  - Multipart Upload
  - Presigned URL
  - Versioning
- [ ] MinIO 아키텍처
  - 분산 모드
  - Erasure Coding
  - BitRot Protection
- [ ] 버킷 정책 및 CORS
  - IAM 정책
  - Bucket Policy
  - CORS 설정
- [ ] Go SDK
  - aws-sdk-go-v2
  - minio-go
  - 클라이언트 구현

**실습 프로젝트:**

- MinIO 분산 클러스터 구축
- S3 호환 스토리지 서비스 개발
- Lifecycle 정책 구현

---

### 9. Ceph 아키텍처

**학습 목표:**

- Ceph 분산 스토리지 시스템 이해
- CRUSH 알고리즘 및 데이터 배치

**학습 내용:**

- [ ] Ceph 컴포넌트
  - MON (Monitor)
  - OSD (Object Storage Daemon)
  - MDS (Metadata Server)
  - MGR (Manager)
  - RGW (RADOS Gateway)
- [ ] RADOS (Reliable Autonomic Distributed Object Store)
  - CRUSH 알고리즘
  - Placement Group (PG)
  - Pool 관리
- [ ] Ceph 스토리지 타입
  - RBD (RADOS Block Device)
  - CephFS (File System)
  - RGW (Object Storage)
- [ ] 데이터 보호
  - Replication
  - Erasure Coding
  - Scrubbing

**실습 프로젝트:**

- Ceph 클러스터 구축
- CRUSH Map 커스터마이징
- RBD/CephFS/RGW 설정

---

### 10. Ceph 운영 & 성능

**학습 목표:**

- Ceph 클러스터 운영 및 모니터링
- 성능 최적화 및 트러블슈팅

**학습 내용:**

- [ ] 클러스터 배포
  - cephadm 활용
  - Rook Operator (Kubernetes)
  - 노드 추가/제거
- [ ] 모니터링
  - Prometheus/Grafana 통합
  - Ceph Dashboard
  - 성능 메트릭
- [ ] 성능 최적화
  - BlueStore 튜닝
  - Network 최적화 (public/cluster 분리)
  - OSD 최적화
- [ ] 트러블슈팅
  - OSD 복구
  - PG 불균형 해결
  - 네트워크 문제 진단
- [ ] Erasure Coding vs Replication
  - 성능 비교
  - 비용 분석
  - 사용 사례

**실습 프로젝트:**

- Ceph 성능 벤치마킹
- Prometheus 모니터링 구축
- OSD 장애 복구 시나리오

---

### 11. Block Storage (Cinder)

**학습 목표:**

- OpenStack Cinder 블록 스토리지 심화
- 다양한 스토리지 백엔드 통합

**학습 내용:**

- [ ] Cinder 아키텍처
  - cinder-api, cinder-scheduler
  - cinder-volume
  - Volume Driver 모델
- [ ] 볼륨 드라이버
  - LVM Driver
  - Ceph RBD Driver
  - 커스텀 드라이버 개발
- [ ] 볼륨 타입 및 QoS
  - Volume Type 설정
  - QoS Spec
  - 성능 제한
- [ ] 스냅샷 및 백업
  - 스냅샷 전략
  - 백업 서비스
  - 볼륨 마이그레이션
- [ ] Multi-backend 구성
  - 여러 스토리지 백엔드 관리
  - Volume Type 기반 스케줄링

**실습 프로젝트:**

- Cinder + Ceph 통합
- 커스텀 볼륨 드라이버 개발
- QoS 정책 구현

---

### 12. Storage Lifecycle & Optimization

**학습 목표:**

- 스토리지 계층화 및 라이프사이클 관리
- 비용 최적화 및 용량 계획

**학습 내용:**

- [ ] Storage Tiering
  - Hot/Warm/Cold/Archive 계층
  - 자동 티어링 정책
  - 데이터 이동 전략
- [ ] Lifecycle 정책
  - 자동 삭제 규칙
  - Versioning 관리
  - Transition 정책
- [ ] 압축 및 중복 제거
  - Inline Compression
  - Deduplication
  - 공간 절약 기법
- [ ] 씬 프로비저닝 (Thin Provisioning)
  - Over-provisioning
  - 용량 모니터링
- [ ] 캐시 계층
  - Write-back vs Write-through
  - Cache Tiering
  - SSD 캐싱
- [ ] 비용 최적화
  - TCO 분석
  - 용량 계획
  - 데이터 마이그레이션
- [ ] 용량 계획 및 예측
  - 성장 추세 분석
  - Capacity Forecasting
  - 확장 계획

**실습 프로젝트:**

- Lifecycle 정책 자동화
- Storage Tiering 구현
- 비용 최적화 시뮬레이션

---

## 학습 로드맵

### Phase 1: IAM 기초 (1-2개월)

1. OpenStack Keystone 이해
2. OAuth 2.0 / OIDC 구현
3. RBAC/ABAC 설계

### Phase 2: IAM 고급 (1-2개월)

4. OPA 정책 엔진
5. Vault Secrets Management
6. Service Mesh Security

### Phase 3: Storage 기초 (1-2개월)

7. OpenStack Swift
8. S3 API & MinIO
9. Ceph 아키텍처

### Phase 4: Storage 운영 (1-2개월)

10. Ceph 운영 & 성능
11. Cinder 블록 스토리지
12. Storage Lifecycle

---

## 추가 학습 자료

### 공식 문서

- [OpenStack Keystone Documentation](https://docs.openstack.org/keystone/latest/)
- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [Open Policy Agent](https://www.openpolicyagent.org/docs/latest/)
- [HashiCorp Vault](https://www.vaultproject.io/docs)
- [SPIFFE/SPIRE](https://spiffe.io/docs/latest/)
- [OpenStack Swift](https://docs.openstack.org/swift/latest/)
- [MinIO Documentation](https://min.io/docs/)
- [Ceph Documentation](https://docs.ceph.com/)

### Go 라이브러리

- [go-oidc](https://github.com/coreos/go-oidc)
- [golang-jwt](https://github.com/golang-jwt/jwt)
- [casbin](https://github.com/casbin/casbin)
- [vault/api](https://pkg.go.dev/github.com/hashicorp/vault/api)
- [aws-sdk-go-v2](https://github.com/aws/aws-sdk-go-v2)
- [minio-go](https://github.com/minio/minio-go)

---

## 프로젝트 아이디어

### IAM 프로젝트

1. **멀티 테넌트 IAM 플랫폼**
   - Keystone 기반 인증/인가
   - OAuth 2.0 / OIDC 통합
   - OPA 정책 엔진

2. **Zero Trust 아키텍처**
   - SPIFFE/SPIRE Identity
   - mTLS 서비스 인증
   - 동적 접근 제어

### Storage 프로젝트

1. **하이브리드 오브젝트 스토리지**
   - Swift + S3 API 호환
   - Multi-backend 지원
   - Lifecycle 자동화

2. **고가용성 블록 스토리지**
   - Ceph RBD 기반
   - QoS 정책
   - 자동 복구

---

## 체크리스트

### IAM 역량

- [ ] Keystone 기반 멀티 테넌트 IAM 구현
- [ ] OAuth 2.0 / OIDC Provider 개발
- [ ] RBAC/ABAC 정책 엔진 설계
- [ ] OPA Rego 정책 작성
- [ ] Vault 기반 시크릿 관리
- [ ] mTLS 서비스 인증 구현
- [ ] SPIFFE/SPIRE Identity 관리

### Storage 역량

- [ ] Swift 클러스터 구축 및 운영
- [ ] S3 호환 API 개발
- [ ] MinIO 분산 스토리지 운영
- [ ] Ceph 클러스터 설계 및 배포
- [ ] Ceph 성능 최적화
- [ ] Cinder 멀티 백엔드 구성
- [ ] Storage Lifecycle 정책 자동화

### Go 개발 역량

- [ ] Go 기반 인증/인가 서비스 개발
- [ ] gRPC + mTLS 구현
- [ ] Kubernetes Operator 패턴
- [ ] Go SDK 활용 (Vault, MinIO, Ceph)
