# Cloud Study - 클라우드 개발자 학습 프로젝트

6개월간 진행하는 클라우드 개발자 학습 프로젝트입니다.

## 프로젝트 구조

```
cloud-study/
├── CLOUD_STUDY.md          # 전체 학습 커리큘럼
├── phase-1/                # Phase 1: 기초 준비
│   ├── linux-vm/          # 리눅스 VM 실습
│   ├── networking/         # 네트워킹 실습
│   ├── notes.md           # 학습 노트
│   └── README.md          # Phase 1 가이드
├── phase-2/                # Phase 2: 가상화 & 컨테이너
├── scripts/                # 공통 스크립트
├── terraform/              # 인프라 코드
└── docs/                   # 추가 문서
```

## 학습 목표

- IaaS 컴퓨팅/네트워킹 서비스 개발 및 운영 역량 습득
- Cloud-native Datacenter (K8s) 운영 역량 습득
- OpenStack 기반 인프라 운영 및 SRE 역량 습득
- DevOps 실무 역량 습득

## 학습 방법론

1. **이론 학습** (30%): 각 주제별 개념 이해
2. **커맨드 실습** (40%): CLI를 통한 실제 작업
3. **개발 실습** (30%): 간단한 도구/API 개발

## 진행 상황

- [ ] Phase 1: 기초 준비 (1-2주)
- [ ] Phase 2: 가상화 & 컨테이너 기초 (3-4주)
- [ ] Phase 3: IaaS 기초 - 컴퓨팅 (5-8주)
- [ ] Phase 4: IaaS 기초 - 네트워킹 (9-12주)
- [ ] Phase 5: Kubernetes (13-18주)
- [ ] Phase 6: OpenStack (19-22주)
- [ ] Phase 7: DevOps & SRE (23-24주)
- [ ] Phase 8: 종합 프로젝트 (25-26주)

## 직군별 스터디 가이드

모집공고에 명시된 각 포지션별 요구 역량을 기반으로 한 상세한 스터디 가이드가 준비되어 있습니다.

- [공통 역량 스터디 가이드](./docs/common-skills.md) - 모든 포지션에서 공통적으로 요구되는 역량
- [Infrastructure Platform 개발자](./docs/infrastructure-platform-study.md) - Kubernetes, ClusterAPI, IaC 등
- [네트워킹 서비스 개발자](./docs/networking-service-study.md) - OpenStack, NFV, SDN 등
- [컴퓨팅 서비스 개발자](./docs/computing-service-study.md) - OpenStack, 가상화, 스케줄링 등

> 💡 **추천 학습 순서**: 먼저 공통 역량을 학습한 후, 관심 있는 포지션별 가이드를 따라 학습하세요.

## 시작하기

1. `CLOUD_STUDY.md` 파일에서 전체 커리큘럼 확인
2. [공통 역량 스터디 가이드](./docs/common-skills.md)로 공통 역량 학습
3. 관심 있는 포지션의 스터디 가이드 선택
4. 현재 Phase의 `README.md` 확인
5. 각 Phase의 `notes.md`에 학습 내용 기록
6. 실습 결과물을 해당 Phase 폴더에 저장

## 참고 자료

- [AWS 공식 문서](https://docs.aws.amazon.com/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [OpenStack 공식 문서](https://docs.openstack.org/)
- [Docker 공식 문서](https://docs.docker.com/)
