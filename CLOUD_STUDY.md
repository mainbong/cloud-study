# 클라우드 개발자 학습 커리큘럼 (6개월)

## 학습 목표

- IaaS 컴퓨팅/네트워킹 서비스 개발 및 운영 역량 습득
- Cloud-native Datacenter (K8s) 운영 역량 습득
- OpenStack 기반 인프라 운영 및 SRE 역량 습득
- DevOps 실무 역량 습득

## 전체 일정 (6개월, 주당 20시간, 총 480시간)

### Phase 1: 기초 준비 (1-2주, 40시간)

**목표**: 리눅스, 네트워킹, 가상화 기초 이해

#### Week 1-2: 리눅스 & 네트워킹 기초

- [ ] 리눅스 시스템 관리
  - [ ] 파일 시스템, 권한 관리
  - [ ] 프로세스 관리, 서비스 관리
  - [ ] 쉘 스크립팅 기초
  - [ ] 실습: 로컬 Mac에서 리눅스 VM 구축 (UTM/QEMU)
- [ ] 네트워킹 기초
  - [ ] OSI 7계층, TCP/IP
  - [ ] 서브넷팅, 라우팅
  - [ ] DNS 동작 원리
  - [ ] 실습: 로컬 네트워크 구성 및 패킷 분석

### Phase 2: 가상화 & 컨테이너 기초 (3-4주, 40시간)

**목표**: 가상화 기술과 컨테이너 기술 이해

#### Week 3-4: 가상화 기술

- [ ] 가상화 개념 (VM, Hypervisor)
  - [ ] Type 1/Type 2 Hypervisor
  - [ ] CPU 가상화, 메모리 가상화
  - [ ] 실습: VirtualBox/UTM으로 VM 생성 및 관리
- [ ] 컨테이너 기초
  - [ ] Docker 기초
  - [ ] 이미지 빌드, 컨테이너 실행
  - [ ] Docker Compose
  - [ ] 실습: Docker로 애플리케이션 컨테이너화

### Phase 3: IaaS 기초 - 컴퓨팅 (5-8주, 80시간)

**목표**: Virtual Machine, Bare Metal, GPU 서비스 이해 및 구현

#### Week 5-6: Virtual Machine 서비스

- [ ] VM 서비스 아키텍처
  - [ ] VM 생성, 관리, 모니터링
  - [ ] 이미지 관리, 스냅샷
  - [ ] 실습: AWS EC2로 VM 생성 및 관리
  - [ ] 실습: 로컬에서 간단한 VM 관리 API 개발 (Python/Go)
- [ ] VM 라이프사이클 관리
  - [ ] 시작, 중지, 재시작
  - [ ] 리소스 할당 및 스케일링
  - [ ] 실습: VM 자동화 스크립트 작성

#### Week 7-8: Bare Metal & GPU

- [ ] Bare Metal 서비스
  - [ ] Bare Metal vs VM 차이
  - [ ] PXE 부팅, IPMI
  - [ ] 실습: AWS EC2 Bare Metal 인스턴스 실습
- [ ] GPU 서비스
  - [ ] GPU 가상화 기술
  - [ ] CUDA, GPU 할당
  - [ ] 실습: GPU 인스턴스에서 딥러닝 워크로드 실행

### Phase 4: IaaS 기초 - 네트워킹 (9-12주, 80시간)

**목표**: VPC, TGW, Load Balancer, DNS 서비스 이해 및 구현

#### Week 9-10: VPC (Virtual Private Cloud)

- [ ] VPC 개념 및 아키텍처
  - [ ] 서브넷, 라우팅 테이블
  - [ ] 인터넷 게이트웨이, NAT 게이트웨이
  - [ ] 보안 그룹, 네트워크 ACL
  - [ ] 실습: AWS VPC 구성 및 관리
  - [ ] 실습: 간단한 VPC 관리 도구 개발

#### Week 11: TGW (Transit Gateway) & Load Balancer

- [ ] Transit Gateway
  - [ ] Hub-and-Spoke 아키텍처
  - [ ] VPC 피어링
  - [ ] 실습: AWS Transit Gateway 구성
- [ ] Load Balancer
  - [ ] L4/L7 로드밸런싱
  - [ ] Health Check, Auto Scaling 연동
  - [ ] 실습: AWS ALB/NLB 구성 및 테스트

#### Week 12: DNS 서비스

- [ ] DNS 서비스 운영
  - [ ] DNS 레코드 타입 (A, AAAA, CNAME, MX)
  - [ ] DNS 라운드로빈, 헬스체크
  - [ ] 실습: AWS Route 53 구성
  - [ ] 실습: DNS 모니터링 도구 개발

### Phase 5: Kubernetes (13-18주, 120시간)

**목표**: Kubernetes 클러스터 운영 및 관리

#### Week 13-14: Kubernetes 기초

- [ ] Kubernetes 개념
  - [ ] Pod, Service, Deployment
  - [ ] Namespace, ConfigMap, Secret
  - [ ] 실습: 로컬에서 minikube/k3s로 클러스터 구축
  - [ ] 실습: 간단한 애플리케이션 배포

#### Week 15-16: Kubernetes 심화

- [ ] 고급 리소스
  - [ ] StatefulSet, DaemonSet, Job, CronJob
  - [ ] Ingress, Service Mesh (Istio 기초)
  - [ ] 실습: Stateful 애플리케이션 배포
- [ ] 스토리지 관리
  - [ ] PV, PVC, StorageClass
  - [ ] 실습: 영구 스토리지 구성

#### Week 17-18: Kubernetes 운영

- [ ] 클러스터 관리
  - [ ] 노드 관리, 스케줄링
  - [ ] 리소스 할당 (Requests/Limits)
  - [ ] 실습: AWS EKS 클러스터 구축 및 운영
- [ ] 모니터링 & 로깅
  - [ ] Prometheus, Grafana
  - [ ] ELK Stack 기초
  - [ ] 실습: K8s 클러스터 모니터링 구축

### Phase 6: OpenStack (19-22주, 80시간)

**목표**: OpenStack 컴포넌트 이해 및 운영

#### Week 19-20: OpenStack 기초

- [ ] OpenStack 아키텍처
  - [ ] 핵심 컴포넌트 (Nova, Neutron, Cinder, Glance, Keystone)
  - [ ] OpenStack 설치 및 구성
  - [ ] 실습: DevStack으로 로컬 OpenStack 환경 구축
- [ ] Nova (Compute)
  - [ ] VM 생성 및 관리
  - [ ] Flavors, Images
  - [ ] 실습: Nova API를 통한 VM 관리

#### Week 21: Neutron (Networking) & Cinder (Storage)

- [ ] Neutron 네트워킹
  - [ ] 네트워크, 서브넷, 라우터 구성
  - [ ] 실습: Neutron으로 네트워크 구성
- [ ] Cinder 스토리지
  - [ ] 볼륨 생성 및 관리
  - [ ] 스냅샷, 백업
  - [ ] 실습: Cinder 볼륨 관리

#### Week 22: OpenStack 운영 & SRE

- [ ] OpenStack 모니터링
  - [ ] Ceilometer, Gnocchi
  - [ ] 로그 관리
  - [ ] 실습: OpenStack 모니터링 구축
- [ ] 문제 해결 및 트러블슈팅
  - [ ] 일반적인 이슈 및 해결 방법
  - [ ] 실습: 실제 문제 시나리오 해결

### Phase 7: DevOps & SRE (23-24주, 40시간)

**목표**: DevOps 파이프라인 및 SRE 실무

#### Week 23: DevOps 파이프라인

- [ ] CI/CD
  - [ ] Jenkins, GitLab CI, GitHub Actions
  - [ ] 실습: CI/CD 파이프라인 구축
- [ ] Infrastructure as Code
  - [ ] Terraform 기초
  - [ ] Ansible 기초
  - [ ] 실습: Terraform으로 인프라 자동화

#### Week 24: SRE 실무

- [ ] 모니터링 & 알림
  - [ ] Prometheus, Alertmanager
  - [ ] 실습: 종합 모니터링 시스템 구축
- [ ] 로깅 & 추적
  - [ ] ELK Stack, Jaeger
  - [ ] 실습: 분산 추적 시스템 구축
- [ ] 인시던트 관리
  - [ ] Runbook 작성
  - [ ] 실습: 인시던트 대응 시뮬레이션

### Phase 8: 종합 프로젝트 (25-26주, 40시간)

**목표**: 학습한 기술을 종합한 실전 프로젝트

#### Week 25-26: 종합 프로젝트

- [ ] 프로젝트 주제: 간단한 IaaS 플랫폼 구축
  - [ ] VM 서비스 API 개발
  - [ ] 네트워킹 서비스 연동
  - [ ] Kubernetes 클러스터 운영
  - [ ] 모니터링 및 로깅 구축
  - [ ] CI/CD 파이프라인 구성
- [ ] 문서화 및 발표 준비

## 학습 방법론

1. **이론 학습**: 각 주제별 개념 이해 (30%)
2. **커맨드 실습**: CLI를 통한 실제 작업 (40%)
3. **개발 실습**: 간단한 도구/API 개발 (30%)

## 추천 학습 자료

- 공식 문서 (AWS, Kubernetes, OpenStack)
- 온라인 강의 (Udemy, Coursera)
- 실습 환경: 로컬 (Docker, minikube) → AWS (Free Tier 활용)

## 진행 상황 체크

- [ ] Phase 1 완료
- [ ] Phase 2 완료
- [ ] Phase 3 완료
- [ ] Phase 4 완료
- [ ] Phase 5 완료
- [ ] Phase 6 완료
- [ ] Phase 7 완료
- [ ] Phase 8 완료

## 참고사항

- Mac M1 Max 환경에 맞춘 실습 가이드 포함
- AWS Free Tier를 최대한 활용하여 비용 절감
- 각 Phase별 실습 결과물을 GitHub에 저장하여 포트폴리오 구성

## 학습 노트

### Phase별 학습 기록

각 Phase를 완료할 때마다 아래에 학습 내용과 실습 결과를 기록하세요.

#### Phase 1 학습 기록
- 시작일: 
- 완료일: 
- 주요 학습 내용:
- 실습 결과물:
- 어려웠던 점:
- 다음 Phase 준비사항:

#### Phase 2 학습 기록
- 시작일: 
- 완료일: 
- 주요 학습 내용:
- 실습 결과물:
- 어려웠던 점:
- 다음 Phase 준비사항:

#### Phase 3 학습 기록
- 시작일: 
- 완료일: 
- 주요 학습 내용:
- 실습 결과물:
- 어려웠던 점:
- 다음 Phase 준비사항:

#### Phase 4 학습 기록
- 시작일: 
- 완료일: 
- 주요 학습 내용:
- 실습 결과물:
- 어려웠던 점:
- 다음 Phase 준비사항:

#### Phase 5 학습 기록
- 시작일: 
- 완료일: 
- 주요 학습 내용:
- 실습 결과물:
- 어려웠던 점:
- 다음 Phase 준비사항:

#### Phase 6 학습 기록
- 시작일: 
- 완료일: 
- 주요 학습 내용:
- 실습 결과물:
- 어려웠던 점:
- 다음 Phase 준비사항:

#### Phase 7 학습 기록
- 시작일: 
- 완료일: 
- 주요 학습 내용:
- 실습 결과물:
- 어려웠던 점:
- 다음 Phase 준비사항:

#### Phase 8 학습 기록
- 시작일: 
- 완료일: 
- 프로젝트 개요:
- 주요 구현 내용:
- 배운 점:
- 개선할 점:

## 유용한 명령어 모음

### 리눅스 기본 명령어
```bash
# 파일 시스템 탐색
ls -la
df -h
du -sh *

# 프로세스 관리
ps aux
top
htop

# 네트워크 확인
ifconfig
ip addr
netstat -tulpn
ss -tulpn
```

### Docker 명령어
```bash
# 이미지 관리
docker images
docker pull <image>
docker build -t <tag> .

# 컨테이너 관리
docker ps -a
docker run -d <image>
docker exec -it <container> /bin/bash
docker logs <container>
```

### Kubernetes 명령어
```bash
# 클러스터 정보
kubectl cluster-info
kubectl get nodes

# 리소스 관리
kubectl get pods
kubectl get services
kubectl apply -f <yaml>
kubectl describe pod <pod-name>
```

### AWS CLI 명령어
```bash
# EC2 인스턴스 관리
aws ec2 describe-instances
aws ec2 start-instances --instance-ids <id>
aws ec2 stop-instances --instance-ids <id>

# VPC 관리
aws ec2 describe-vpcs
aws ec2 create-vpc --cidr-block 10.0.0.0/16
```

## 문제 해결 가이드

### 자주 발생하는 문제와 해결 방법

#### Docker 관련
- **문제**: 컨테이너가 시작되지 않음
- **해결**: `docker logs <container>`로 로그 확인, 포트 충돌 확인

#### Kubernetes 관련
- **문제**: Pod가 Pending 상태
- **해결**: `kubectl describe pod <pod-name>`로 이벤트 확인, 리소스 부족 여부 확인

#### AWS 관련
- **문제**: 인스턴스에 접속 불가
- **해결**: 보안 그룹 규칙 확인, 키 페어 확인

## 추가 학습 리소스

### 공식 문서
- [AWS 공식 문서](https://docs.aws.amazon.com/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [OpenStack 공식 문서](https://docs.openstack.org/)
- [Docker 공식 문서](https://docs.docker.com/)

### 추천 도서
- Kubernetes in Action
- The Kubernetes Book
- Site Reliability Engineering (Google SRE Book)

### 온라인 강의
- AWS Certified Solutions Architect
- Kubernetes for the Absolute Beginners
- Docker and Kubernetes: The Complete Guide

