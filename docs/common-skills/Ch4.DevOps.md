# Ch4. DevOps 도구 및 실무

## 📋 개요

DevOps는 개발(Development)과 운영(Operations)을 통합하여 소프트웨어 전달 속도와 품질을 향상시키는 문화이자 실천 방법입니다. 자동화, 모니터링, 지속적 통합/배포가 핵심입니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:
- Git을 사용한 효과적인 버전 관리 및 협업
- CI/CD 파이프라인 구축 및 운영
- GitOps를 통한 선언적 배포 자동화
- Prometheus와 Grafana를 활용한 모니터링 시스템 구축

---

## 🔀 Part 1: Git & 버전 관리

### 1. Git Workflow

#### Git Flow

대규모 프로젝트에 적합한 브랜치 전략입니다.

```bash
# 브랜치 구조
main (production)
├── develop (development)
│   ├── feature/user-authentication
│   ├── feature/payment-integration
│   └── feature/new-dashboard
├── release/v1.2.0
└── hotfix/critical-bug-fix
```

**워크플로우:**
```bash
# 1. Feature 개발 시작
git checkout develop
git pull origin develop
git checkout -b feature/user-auth

# 2. 개발 및 커밋
git add .
git commit -m "Add user authentication"

# 3. Feature 브랜치 푸시
git push origin feature/user-auth

# 4. Pull Request 생성 (GitHub/GitLab)

# 5. 코드 리뷰 후 develop에 머지

# 6. Release 준비
git checkout -b release/v1.2.0 develop

# 7. 버그 수정 후 main과 develop에 머지
git checkout main
git merge release/v1.2.0
git tag v1.2.0

# 8. Hotfix (긴급 버그 수정)
git checkout -b hotfix/critical-bug main
# 수정 후
git checkout main
git merge hotfix/critical-bug
git checkout develop
git merge hotfix/critical-bug
```

#### GitHub Flow (간소화된 방식)

소규모 팀이나 지속적 배포에 적합합니다.

```bash
# 브랜치 구조 (단순)
main
├── feature/add-logging
├── fix/api-timeout
└── update/dependencies
```

**워크플로우:**
```bash
# 1. Feature 브랜치 생성
git checkout -b feature/add-logging

# 2. 개발 및 푸시
git add .
git commit -m "Add logging middleware"
git push origin feature/add-logging

# 3. Pull Request → 리뷰 → Merge → Deploy
```

### 2. Git 고급 기능

#### Interactive Rebase

```bash
# 최근 3개 커밋 정리
git rebase -i HEAD~3

# 에디터에서:
# pick abc123 Add feature A
# squash def456 Fix typo
# squash ghi789 Update docs
# → 3개 커밋을 1개로 합침
```

#### Cherry-pick

```bash
# 특정 커밋만 현재 브랜치에 적용
git cherry-pick abc123
```

#### Stash

```bash
# 작업 중인 변경사항 임시 저장
git stash

# 다른 브랜치로 이동 후 작업

# 임시 저장한 변경사항 복원
git stash pop
```

---

## 🔄 Part 2: CI/CD 파이프라인

### 1. GitHub Actions

#### 기본 워크플로우

```.github/workflows/ci.yml
name: CI Pipeline

# 트리거 조건
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # 테스트 Job
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Cache dependencies
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('requirements.txt') }}

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov

      - name: Run tests
        run: pytest --cov=app tests/

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: ./coverage.xml

  # 빌드 및 푸시 Job
  build:
    runs-on: ubuntu-latest
    needs: test  # test가 성공해야 실행

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            myapp:latest
            myapp:${{ github.sha }}
```

#### CD 파이프라인 (Kubernetes 배포)

```.github/workflows/cd.yml
name: CD Pipeline

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBE_CONFIG }}

      - name: Update deployment image
        run: |
          kubectl set image deployment/myapp \
            myapp=myapp:${{ github.sha }} \
            --record

      - name: Check rollout status
        run: kubectl rollout status deployment/myapp

      - name: Notify Slack
        if: success()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ Deployment successful: ${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### 2. GitLab CI/CD

#### .gitlab-ci.yml

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

# 변수 정의
variables:
  DOCKER_IMAGE: registry.gitlab.com/myproject/myapp
  KUBE_NAMESPACE: production

# 테스트 스테이지
test:
  stage: test
  image: python:3.11
  before_script:
    - pip install -r requirements.txt
  script:
    - pytest --cov=app tests/
    - flake8 app/
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

# 빌드 스테이지
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $DOCKER_IMAGE:$CI_COMMIT_SHA .
    - docker build -t $DOCKER_IMAGE:latest .
    - docker push $DOCKER_IMAGE:$CI_COMMIT_SHA
    - docker push $DOCKER_IMAGE:latest
  only:
    - main

# 배포 스테이지
deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl config use-context $KUBE_CONTEXT
    - kubectl set image deployment/myapp myapp=$DOCKER_IMAGE:$CI_COMMIT_SHA -n $KUBE_NAMESPACE
    - kubectl rollout status deployment/myapp -n $KUBE_NAMESPACE
  environment:
    name: production
    url: https://myapp.example.com
  only:
    - main
  when: manual  # 수동 승인 필요
```

### 3. Jenkins Pipeline

#### Jenkinsfile

```groovy
// Jenkinsfile
pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'myapp'
        REGISTRY = 'docker.io'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/myorg/myapp.git'
            }
        }

        stage('Test') {
            steps {
                sh 'pip install -r requirements.txt'
                sh 'pytest --junitxml=test-results.xml'
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}:${BUILD_NUMBER}")
                }
            }
        }

        stage('Push') {
            steps {
                script {
                    docker.withRegistry("https://${REGISTRY}", 'docker-credentials') {
                        docker.image("${DOCKER_IMAGE}:${BUILD_NUMBER}").push()
                        docker.image("${DOCKER_IMAGE}:${BUILD_NUMBER}").push('latest')
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                kubernetesDeploy(
                    configs: 'k8s/*.yaml',
                    kubeconfigId: 'kubeconfig'
                )
            }
        }
    }

    post {
        success {
            slackSend(color: 'good', message: "Build ${BUILD_NUMBER} succeeded")
        }
        failure {
            slackSend(color: 'danger', message: "Build ${BUILD_NUMBER} failed")
        }
    }
}
```

### 4. CI/CD Best Practices (2025)

**1. 빠른 실패 (Fail Fast):**
```yaml
# 단위 테스트를 먼저 실행
jobs:
  quick-tests:
    runs-on: ubuntu-latest
    steps:
      - run: pytest tests/unit/  # 빠른 단위 테스트

  integration-tests:
    needs: quick-tests  # 단위 테스트 통과 후 실행
    runs-on: ubuntu-latest
    steps:
      - run: pytest tests/integration/  # 느린 통합 테스트
```

**2. 의존성 캐싱:**
```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.cache/pip
      node_modules
    key: ${{ runner.os }}-deps-${{ hashFiles('**/requirements.txt', '**/package-lock.json') }}
```

**3. 시크릿 관리:**
```yaml
# ❌ 하드코딩 (절대 금지)
password: mypassword123

# ✅ GitHub Secrets 사용
password: ${{ secrets.DB_PASSWORD }}
```

**4. 병렬 실행:**
```yaml
jobs:
  test:
    strategy:
      matrix:
        python-version: ['3.9', '3.10', '3.11']
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
```

---

## 🚀 Part 3: GitOps

### 1. GitOps 개념

**GitOps 원칙:**
1. **선언적 명세**: 모든 설정이 Git에 선언적으로 저장
2. **버전 관리**: Git이 단일 진실 공급원 (Single Source of Truth)
3. **자동 배포**: Git 변경 시 자동으로 클러스터에 반영
4. **지속적 동기화**: 클러스터 상태와 Git 저장소 상태 일치

### 2. ArgoCD

#### 설치

```bash
# ArgoCD 네임스페이스 생성
kubectl create namespace argocd

# ArgoCD 설치
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ArgoCD UI 접속
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 초기 admin 비밀번호
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### Application 정의

```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  # 소스 (Git 저장소)
  source:
    repoURL: https://github.com/myorg/myapp-config.git
    targetRevision: main
    path: k8s/production

  # 대상 (Kubernetes 클러스터)
  destination:
    server: https://kubernetes.default.svc
    namespace: production

  # 동기화 정책
  syncPolicy:
    automated:
      prune: true      # Git에서 삭제된 리소스 제거
      selfHeal: true   # 클러스터 변경 시 자동 복구
    syncOptions:
      - CreateNamespace=true

  # 헬스 체크
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # replicas 변경 무시 (HPA 사용 시)
```

```bash
# Application 배포
kubectl apply -f application.yaml

# 동기화 상태 확인
argocd app get my-app

# 수동 동기화
argocd app sync my-app
```

#### ArgoCD vs Flux CD (2025 비교)

**ArgoCD:**

- ✅ 풍부한 웹 UI
- ✅ Multi-tenancy 지원
- ✅ Multi-cluster 관리
- ✅ 직관적인 사용자 경험

**Flux CD:**

- ✅ 경량, CLI 중심
- ✅ Kubernetes-native (CRD 기반)
- ✅ 리소스 효율적
- ✅ GitOps Toolkit으로 확장 가능

**2025년 기준:** 65% 이상의 기업이 GitOps를 도입하고 있으며, ArgoCD와 Flux 모두 널리 사용됩니다.

### 3. Flux CD

#### 설치

```bash
# Flux CLI 설치
curl -s https://fluxcd.io/install.sh | sudo bash

# GitHub Personal Access Token 생성 후
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>

# Flux 부트스트랩
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=fleet-infra \
  --branch=main \
  --path=./clusters/production \
  --personal
```

#### GitRepository 및 Kustomization

```yaml
# gitrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/myorg/myapp-config
  ref:
    branch: main
---
# kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  path: ./k8s/production
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-app
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-app
      namespace: production
```

---

## 📊 Part 4: 모니터링 (Prometheus & Grafana)

### 1. Prometheus

#### Prometheus 아키텍처

**핵심 컴포넌트:**

- **Prometheus Server**: 메트릭 수집 및 저장
- **Exporters**: 메트릭 노출 (Node Exporter, MySQL Exporter 등)
- **Alertmanager**: 알림 관리
- **Pushgateway**: 단기 작업 메트릭 수집

#### 설치 (Helm)

```bash
# Prometheus Stack 설치 (Prometheus + Grafana + Alertmanager)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=15d \
  --set grafana.enabled=true
```

#### Prometheus 설정

```yaml
# prometheus.yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# 알림 규칙 파일
rule_files:
  - "alerts.yml"

# Alertmanager 설정
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

# 메트릭 수집 대상
scrape_configs:
  # Kubernetes API Server
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

  # Node Exporter
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - source_labels: [__address__]
        target_label: __address__
        regex: (.+):10250
        replacement: ${1}:9100

  # 애플리케이션 메트릭
  - job_name: 'my-app'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: my-app
      - source_labels: [__meta_kubernetes_pod_container_port_number]
        action: keep
        regex: "8000"
```

#### PromQL (Prometheus Query Language)

```promql
# CPU 사용률 (최근 5분)
rate(container_cpu_usage_seconds_total[5m])

# 메모리 사용량
container_memory_usage_bytes

# HTTP 요청률 (QPS)
rate(http_requests_total[1m])

# 에러율
rate(http_requests_total{status=~"5.."}[5m])
/ rate(http_requests_total[5m])

# P95 레이턴시
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Pod 재시작 횟수
kube_pod_container_status_restarts_total > 5
```

#### 알림 규칙

```yaml
# alerts.yml
groups:
  - name: kubernetes-alerts
    interval: 30s
    rules:
      # Pod가 재시작을 반복하는 경우
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod {{ $labels.pod }} is crash looping"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting {{ $value }} times per second"

      # 높은 CPU 사용률
      - alert: HighCPUUsage
        expr: |
          100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is {{ $value }}%"

      # 메모리 부족
      - alert: HighMemoryUsage
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ $value }}%"

      # Deployment의 Pod 부족
      - alert: DeploymentReplicasMismatch
        expr: |
          kube_deployment_spec_replicas != kube_deployment_status_replicas_available
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Deployment {{ $labels.deployment }} has mismatched replicas"
```

### 2. Grafana

#### 대시보드 생성

```bash
# Grafana 접속
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# 기본 로그인
# Username: admin
# Password: prom-operator
```

**Kubernetes 클러스터 대시보드 (JSON):**
```json
{
  "dashboard": {
    "title": "Kubernetes Cluster Overview",
    "panels": [
      {
        "title": "CPU Usage",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Memory Usage",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes) by (pod)"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

#### 알림 채널 설정

```yaml
# Slack 알림
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

    route:
      group_by: ['alertname', 'cluster']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack-notifications'

    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - channel: '#alerts'
            title: '{{ .GroupLabels.alertname }}'
            text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

### 3. 애플리케이션 메트릭 (Python 예제)

```python
# app.py
from prometheus_client import Counter, Histogram, generate_latest
from fastapi import FastAPI, Response
import time

app = FastAPI()

# 메트릭 정의
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint']
)

@app.middleware("http")
async def prometheus_middleware(request, call_next):
    start_time = time.time()
    response = await call_next(request)

    # 메트릭 기록
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()

    REQUEST_LATENCY.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(time.time() - start_time)

    return response

@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type="text/plain")

@app.get("/")
def read_root():
    return {"message": "Hello World"}
```

---

## 📚 참고 자료

### Git
- [Pro Git Book](https://git-scm.com/book/ko/v2)
- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)

### CI/CD
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [CI/CD Best Practices 2025](https://www.kunal-chowdhury.com/2025/07/devops-ci-cd-pipelines.html)

### GitOps
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [GitOps Principles](https://www.gitops.tech/)

### 모니터링
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Kubernetes Monitoring Guide 2025](https://linuxcloudservers.com/kubernetes-monitoring/)

---

## ✅ 학습 체크리스트

- [ ] Git Flow/GitHub Flow 이해 및 활용
- [ ] Git 고급 기능 (rebase, cherry-pick, stash) 사용
- [ ] GitHub Actions로 CI/CD 파이프라인 구축
- [ ] GitLab CI 또는 Jenkins 파이프라인 구성
- [ ] ArgoCD 또는 Flux로 GitOps 구현
- [ ] Prometheus로 메트릭 수집 설정
- [ ] PromQL로 쿼리 작성
- [ ] Grafana 대시보드 생성 및 알림 설정
- [ ] 애플리케이션에 메트릭 추가

---

## 🎓 다음 단계

DevOps 도구를 마스터한 후:
- [Ch5. 시스템 설계 및 아키텍처](./Ch5.시스템_설계.md)로 진행
- 또는 [README](./README.md)로 돌아가서 학습 로드맵 확인
