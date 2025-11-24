# Ch4. Cloud-Native 플랫폼 구성 도구

## 📋 개요

Cloud-Native 플랫폼을 구축하려면 다양한 도구가 필요합니다. Helm, ArgoCD, Harbor, Keycloak, GitLab 등은 Kubernetes 생태계에서 표준으로 자리잡은 도구들입니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:

- Helm으로 Kubernetes 애플리케이션 패키징 및 배포
- ArgoCD로 GitOps 파이프라인 구축
- Harbor로 컨테이너 레지스트리 운영
- Keycloak으로 통합 인증/인가 관리
- GitLab CI/CD 파이프라인 구성

---

## ⎈ Part 1: Helm

### 1. Helm Chart 구조

```
mychart/
├── Chart.yaml          # Chart 메타데이터
├── values.yaml         # 기본 설정 값
├── charts/             # 의존성 Chart
├── templates/          # Kubernetes 매니페스트 템플릿
│   ├── NOTES.txt      # 설치 후 메시지
│   ├── _helpers.tpl   # 템플릿 헬퍼
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── tests/         # 헬스 체크 테스트
└── .helmignore        # 패키징 시 제외할 파일
```

### 2. Chart 작성

**Chart.yaml:**
```yaml
apiVersion: v2
name: myapp
description: A Helm chart for my application
type: application
version: 1.0.0        # Chart 버전
appVersion: "2.1.0"   # 애플리케이션 버전

keywords:
  - web
  - application

maintainers:
  - name: DevOps Team
    email: devops@example.com

dependencies:
  - name: postgresql
    version: 12.1.0
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
```

**values.yaml:**
```yaml
# values.yaml
replicaCount: 3

image:
  repository: myregistry/myapp
  pullPolicy: IfNotPresent
  tag: "2.1.0"

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.example.com

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

postgresql:
  enabled: true
  auth:
    username: myapp
    password: changeme
    database: myappdb
```

**templates/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: http
        readinessProbe:
          httpGet:
            path: /ready
            port: http
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
        env:
        - name: DB_HOST
          value: {{ include "myapp.postgresql.fullname" . }}
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: {{ include "myapp.postgresql.fullname" . }}
              key: username
```

**templates/_helpers.tpl:**
```yaml
{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
{{ include "myapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### 3. Helm 명령어

```bash
# Chart 생성
helm create mychart

# 의존성 업데이트
helm dependency update mychart/

# Lint (검증)
helm lint mychart/

# Dry-run (실제 배포 없이 확인)
helm install myapp mychart/ --dry-run --debug

# Chart 설치
helm install myapp mychart/

# 값 오버라이드
helm install myapp mychart/ \
  --set replicaCount=5 \
  --set image.tag=2.2.0

# values 파일 사용
helm install myapp mychart/ -f values-prod.yaml

# 업그레이드
helm upgrade myapp mychart/

# 롤백
helm rollback myapp 1

# 릴리즈 목록
helm list

# 릴리즈 상태
helm status myapp

# 삭제
helm uninstall myapp
```

### 4. Helm Best Practices (2025)

**1. 환경별 values 파일:**
```
values-dev.yaml
values-staging.yaml
values-prod.yaml
```

**2. Lookup 함수 (동적 리소스 조회):**
```yaml
{{- $secret := lookup "v1" "Secret" .Release.Namespace "mysecret" }}
{{- if not $secret }}
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
data:
  password: {{ randAlphaNum 16 | b64enc }}
{{- end }}
```

**3. Helm Test:**
```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "myapp.fullname" . }}-test"
  annotations:
    "helm.sh/hook": test
spec:
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "myapp.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

```bash
# 테스트 실행
helm test myapp
```

---

## 🚀 Part 2: ArgoCD

### 1. ArgoCD 설치

```bash
# Namespace 생성
kubectl create namespace argocd

# ArgoCD 설치
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ArgoCD UI 포트 포워딩
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 초기 admin 비밀번호
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2. Application 생성

```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/myorg/myapp-config.git
    targetRevision: main
    path: k8s/production
    helm:
      valueFiles:
        - values-prod.yaml
      parameters:
        - name: image.tag
          value: "2.1.0"

  destination:
    server: https://kubernetes.default.svc
    namespace: production

  syncPolicy:
    automated:
      prune: true      # Git에서 삭제된 리소스 제거
      selfHeal: true   # 클러스터 변경 시 자동 복구
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 3. Multi-Cluster 관리

```bash
# 클러스터 추가
argocd cluster add staging-cluster

# ApplicationSet (여러 클러스터에 동시 배포)
```

```yaml
# applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-all-clusters
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: dev
        url: https://dev-cluster.example.com
        namespace: development
      - cluster: staging
        url: https://staging-cluster.example.com
        namespace: staging
      - cluster: prod
        url: https://prod-cluster.example.com
        namespace: production
  template:
    metadata:
      name: '{{cluster}}-myapp'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/myapp-config.git
        targetRevision: main
        path: k8s/{{cluster}}
      destination:
        server: '{{url}}'
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## 🐳 Part 3: Harbor

### 1. Harbor 설치 (Helm)

```bash
# Helm 저장소 추가
helm repo add harbor https://helm.goharbor.io
helm repo update

# Harbor 설치
helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  --set expose.type=ingress \
  --set expose.ingress.hosts.core=harbor.example.com \
  --set externalURL=https://harbor.example.com \
  --set harborAdminPassword=Harbor12345
```

### 2. 프로젝트 및 사용자 관리

```bash
# Harbor CLI 사용
# 프로젝트 생성
harbor project create --name myproject --public false

# 사용자 생성
harbor user create \
  --username developer \
  --password Dev12345 \
  --email dev@example.com

# 프로젝트에 사용자 추가
harbor project-member add myproject \
  --username developer \
  --role developer
```

### 3. 이미지 푸시/풀

```bash
# Docker 로그인
docker login harbor.example.com -u admin -p Harbor12345

# 이미지 태그
docker tag myapp:latest harbor.example.com/myproject/myapp:latest

# 이미지 푸시
docker push harbor.example.com/myproject/myapp:latest

# Kubernetes에서 Harbor 사용
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.example.com \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  --docker-email=admin@example.com
```

### 4. 이미지 스캔 (Trivy)

```yaml
# Harbor에서 자동 스캔 활성화
# Administration → Configuration → System Settings
vulnerability_scanners:
  - name: Trivy
    enabled: true
    scan_on_push: true  # 푸시 시 자동 스캔
```

---

## 🔐 Part 4: Keycloak

### 1. Keycloak 설치

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm install keycloak bitnami/keycloak \
  --namespace keycloak \
  --create-namespace \
  --set auth.adminUser=admin \
  --set auth.adminPassword=admin123
```

### 2. Realm 및 Client 설정

**Realm 생성 (YAML로 선언적 관리):**
```yaml
# realm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-realm
data:
  realm.json: |
    {
      "realm": "production",
      "enabled": true,
      "clients": [
        {
          "clientId": "myapp",
          "enabled": true,
          "publicClient": false,
          "redirectUris": ["https://myapp.example.com/*"],
          "webOrigins": ["https://myapp.example.com"],
          "protocol": "openid-connect",
          "clientAuthenticatorType": "client-secret",
          "secret": "mysecret12345"
        }
      ],
      "users": [
        {
          "username": "testuser",
          "enabled": true,
          "email": "test@example.com",
          "credentials": [
            {
              "type": "password",
              "value": "password123",
              "temporary": false
            }
          ],
          "realmRoles": ["user"]
        }
      ],
      "roles": {
        "realm": [
          {"name": "user"},
          {"name": "admin"}
        ]
      }
    }
```

### 3. OAuth2/OIDC 연동

**Python 예제:**
```python
from flask import Flask, redirect, url_for, session
from authlib.integrations.flask_client import OAuth

app = Flask(__name__)
app.secret_key = 'random-secret-key'

oauth = OAuth(app)
oauth.register(
    name='keycloak',
    client_id='myapp',
    client_secret='mysecret12345',
    server_metadata_url='https://keycloak.example.com/realms/production/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'}
)

@app.route('/login')
def login():
    redirect_uri = url_for('authorize', _external=True)
    return oauth.keycloak.authorize_redirect(redirect_uri)

@app.route('/authorize')
def authorize():
    token = oauth.keycloak.authorize_access_token()
    user_info = oauth.keycloak.userinfo(token=token)
    session['user'] = user_info
    return redirect('/')

@app.route('/')
def index():
    user = session.get('user')
    if user:
        return f'Hello {user["email"]}'
    return 'Not logged in'
```

---

## 🦊 Part 5: GitLab CI/CD

### 1. .gitlab-ci.yml

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_REGISTRY: harbor.example.com
  IMAGE_NAME: myproject/myapp

# Docker 이미지 빌드
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $DOCKER_REGISTRY
  script:
    - docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA .
    - docker build -t $DOCKER_REGISTRY/$IMAGE_NAME:latest .
    - docker push $DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA
    - docker push $DOCKER_REGISTRY/$IMAGE_NAME:latest
  only:
    - main

# 테스트
test:
  stage: test
  image: python:3.11
  script:
    - pip install -r requirements.txt
    - pytest tests/ --cov=app
  coverage: '/TOTAL.*\s+(\d+%)$/'

# Kubernetes 배포
deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    - kubectl set image deployment/myapp myapp=$DOCKER_REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA -n production
    - kubectl rollout status deployment/myapp -n production
  environment:
    name: production
    url: https://myapp.example.com
  only:
    - main
  when: manual  # 수동 승인
```

### 2. GitLab Runner 설정

```bash
# Helm으로 GitLab Runner 설치
helm repo add gitlab https://charts.gitlab.io

helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab \
  --create-namespace \
  --set gitlabUrl=https://gitlab.example.com \
  --set runnerRegistrationToken=$RUNNER_TOKEN \
  --set runners.privileged=true
```

---

## 📚 참고 자료

### Helm

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Artifact Hub](https://artifacthub.io/)

### ArgoCD

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)

### Harbor

- [Harbor Documentation](https://goharbor.io/docs/)
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)

### Keycloak

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak on Kubernetes](https://www.keycloak.org/operator/installation)

### GitLab

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab Runner Helm Chart](https://docs.gitlab.com/runner/install/kubernetes.html)

---

## ✅ 학습 체크리스트

- [ ] Helm Chart 작성 및 템플릿 사용
- [ ] Helm Chart 의존성 관리
- [ ] 환경별 values 파일 관리
- [ ] ArgoCD Application 정의
- [ ] GitOps 파이프라인 구축
- [ ] Harbor 프로젝트 및 사용자 관리
- [ ] Harbor 이미지 스캔 설정
- [ ] Keycloak Realm/Client 설정
- [ ] OAuth2/OIDC 통합
- [ ] GitLab CI/CD 파이프라인 작성
- [ ] GitLab Runner 설정 및 관리

---

## 🎓 다음 단계

Cloud-Native 플랫폼 도구를 마스터한 후:

- [Ch5. 모니터링 및 가시성](./Ch5.모니터링.md)로 진행
- 또는 [README](./README.md)로 돌아가서 학습 로드맵 확인
