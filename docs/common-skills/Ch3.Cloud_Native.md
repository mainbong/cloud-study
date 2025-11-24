# Ch3. Cloud-Native 환경

## 📋 개요

Cloud-native는 클라우드 환경에서 애플리케이션을 구축하고 실행하는 현대적인 접근 방식입니다. 컨테이너, 마이크로서비스, 선언적 API, 그리고 자동화를 통해 확장 가능하고 탄력적인 시스템을 만듭니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:
- Docker를 사용한 컨테이너 이미지 빌드 및 관리
- Kubernetes를 사용한 컨테이너 오케스트레이션
- 12-Factor App 방법론을 적용한 클라우드 네이티브 애플리케이션 설계
- 마이크로서비스 아키텍처 이해 및 구현

---

## 🐳 Part 1: Docker 컨테이너

### 1. Docker 기초

#### Docker란?

Docker는 애플리케이션을 컨테이너로 패키징하고 실행하는 플랫폼입니다.

**핵심 개념:**
- **이미지 (Image)**: 애플리케이션 실행에 필요한 모든 것을 포함하는 불변의 템플릿
- **컨테이너 (Container)**: 이미지의 실행 인스턴스
- **Dockerfile**: 이미지를 빌드하기 위한 명령어 스크립트
- **레지스트리 (Registry)**: 이미지를 저장하고 공유하는 저장소 (예: Docker Hub)

#### 기본 Docker 명령어

```bash
# 이미지 관리
docker pull nginx:latest              # 이미지 다운로드
docker images                         # 로컬 이미지 목록
docker rmi nginx:latest               # 이미지 삭제

# 컨테이너 실행
docker run -d -p 8080:80 --name web nginx
# -d: 백그라운드 실행
# -p: 포트 매핑 (호스트:컨테이너)
# --name: 컨테이너 이름

# 컨테이너 관리
docker ps                             # 실행 중인 컨테이너
docker ps -a                          # 모든 컨테이너
docker stop web                       # 컨테이너 중지
docker start web                      # 컨테이너 시작
docker restart web                    # 컨테이너 재시작
docker rm web                         # 컨테이너 삭제
docker logs web                       # 로그 확인
docker logs -f web                    # 실시간 로그
docker exec -it web /bin/bash         # 컨테이너 접속

# 시스템 정보
docker info                           # Docker 시스템 정보
docker stats                          # 리소스 사용량
```

---

### 2. Dockerfile 작성

#### 기본 Dockerfile

```dockerfile
# Python 애플리케이션 예제
FROM python:3.11-slim

# 작업 디렉토리 설정
WORKDIR /app

# 의존성 파일 복사
COPY requirements.txt .

# 의존성 설치
RUN pip install --no-cache-dir -r requirements.txt

# 애플리케이션 코드 복사
COPY . .

# 포트 노출
EXPOSE 8000

# 실행 명령
CMD ["python", "app.py"]
```

#### Multi-Stage Build (2025 Best Practice)

Multi-stage 빌드는 이미지 크기를 60-80% 줄이고 보안을 향상시킵니다.

**Go 애플리케이션 예제:**
```dockerfile
# Stage 1: Build
FROM golang:1.22-alpine AS builder

WORKDIR /app

# 의존성 다운로드
COPY go.mod go.sum ./
RUN go mod download

# 소스 코드 복사 및 빌드
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Stage 2: Runtime
FROM alpine:latest

# 보안을 위한 최소 패키지
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# 빌드 스테이지에서 바이너리만 복사
COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
```

**Node.js 애플리케이션 예제:**
```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Runtime
FROM node:20-alpine

WORKDIR /app

# 빌드 스테이지에서 node_modules와 앱 복사
COPY --from=builder /app/node_modules ./node_modules
COPY . .

EXPOSE 3000

USER node

CMD ["node", "server.js"]
```

**Python 애플리케이션 예제:**
```dockerfile
# Stage 1: Build
FROM python:3.11 AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

WORKDIR /app

# 빌드 스테이지에서 패키지 복사
COPY --from=builder /root/.local /root/.local
COPY . .

# PATH 업데이트
ENV PATH=/root/.local/bin:$PATH

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### Docker Best Practices (2025)

**1. 적절한 베이스 이미지 사용:**
```dockerfile
# ❌ 큰 이미지
FROM ubuntu:latest

# ✅ 슬림 이미지
FROM python:3.11-slim

# ✅ Alpine (가장 작음)
FROM python:3.11-alpine
```

**2. 레이어 최적화:**
```dockerfile
# ❌ 여러 RUN 명령
RUN apt-get update
RUN apt-get install -y package1
RUN apt-get install -y package2

# ✅ 하나의 RUN 명령으로 통합
RUN apt-get update && \
    apt-get install -y \
        package1 \
        package2 && \
    rm -rf /var/lib/apt/lists/*
```

**3. .dockerignore 사용:**
```
# .dockerignore
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.vscode
__pycache__
*.pyc
.pytest_cache
```

**4. 보안 강화:**
```dockerfile
# 루트 사용자 대신 전용 사용자 생성
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

USER appuser

# 읽기 전용 파일시스템
COPY --chown=appuser:appuser . .
```

---

### 3. Docker Compose

여러 컨테이너를 정의하고 실행하기 위한 도구입니다.

```yaml
# docker-compose.yml
version: '3.8'

services:
  # 웹 애플리케이션
  web:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:password@db:5432/mydb
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    volumes:
      - ./app:/app
    networks:
      - app-network

  # PostgreSQL 데이터베이스
  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=mydb
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - app-network

  # Redis 캐시
  redis:
    image: redis:7-alpine
    networks:
      - app-network

volumes:
  postgres-data:

networks:
  app-network:
    driver: bridge
```

**Docker Compose 명령어:**
```bash
# 서비스 시작
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f web

# 서비스 중지
docker-compose down

# 볼륨까지 삭제
docker-compose down -v

# 서비스 재시작
docker-compose restart web
```

---

## ☸️ Part 2: Kubernetes 기초

### 1. Kubernetes 아키텍처

#### 핵심 컴포넌트

**Control Plane (마스터 노드):**
- **API Server**: Kubernetes API의 진입점
- **etcd**: 클러스터 상태를 저장하는 키-값 저장소
- **Scheduler**: Pod를 노드에 할당
- **Controller Manager**: 컨트롤러 실행 (Deployment, ReplicaSet 등)

**Worker Node:**
- **Kubelet**: 각 노드에서 실행되는 에이전트
- **Container Runtime**: 컨테이너 실행 (Docker, containerd 등)
- **Kube-proxy**: 네트워크 프록시

---

### 2. Kubernetes 기본 리소스

#### Pod - 가장 작은 배포 단위

Pod는 하나 이상의 컨테이너 그룹으로, 공유 스토리지와 네트워크를 가집니다.

```yaml
# pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

```bash
# Pod 생성
kubectl apply -f pod.yaml

# Pod 확인
kubectl get pods
kubectl get pods -o wide

# Pod 상세 정보
kubectl describe pod nginx-pod

# Pod 로그
kubectl logs nginx-pod

# Pod 접속
kubectl exec -it nginx-pod -- /bin/bash

# Pod 삭제
kubectl delete pod nginx-pod
```

#### Deployment - 선언적 업데이트

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

```bash
# Deployment 생성
kubectl apply -f deployment.yaml

# Deployment 확인
kubectl get deployments
kubectl get pods

# 스케일 조정
kubectl scale deployment nginx-deployment --replicas=5

# 롤링 업데이트
kubectl set image deployment/nginx-deployment nginx=nginx:1.26

# 롤백
kubectl rollout undo deployment/nginx-deployment

# 업데이트 상태 확인
kubectl rollout status deployment/nginx-deployment

# 업데이트 히스토리
kubectl rollout history deployment/nginx-deployment
```

#### Service - 네트워크 노출

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: LoadBalancer  # ClusterIP, NodePort, LoadBalancer
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80          # Service 포트
    targetPort: 80    # 컨테이너 포트
```

**Service 타입:**
- **ClusterIP** (기본): 클러스터 내부에서만 접근
- **NodePort**: 각 노드의 특정 포트로 노출
- **LoadBalancer**: 클라우드 로드 밸런서 생성

```bash
# Service 생성
kubectl apply -f service.yaml

# Service 확인
kubectl get services
kubectl get svc

# 엔드포인트 확인
kubectl get endpoints nginx-service
```

#### ConfigMap & Secret

**ConfigMap - 설정 데이터:**
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  DATABASE_HOST: "db.example.com"
```

**Secret - 민감한 데이터:**
```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  DATABASE_PASSWORD: "mypassword"
  API_KEY: "secret-key-12345"
```

**사용 예제:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:latest
        env:
        # ConfigMap에서 환경 변수 가져오기
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_ENV
        # Secret에서 환경 변수 가져오기
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: DATABASE_PASSWORD
```

---

### 3. 실전 Kubernetes 예제

#### 완전한 웹 애플리케이션 배포

```yaml
# web-app.yaml
---
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: myapp:1.0
        ports:
        - containerPort: 8000
        env:
        - name: REDIS_HOST
          valueFrom:
            configMapKeyRef:
              name: web-config
              key: REDIS_HOST
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8000
```

---

## 📐 Part 3: 12-Factor App 방법론

### 12-Factor App 개요

2012년 Heroku에서 제안한 SaaS 애플리케이션 개발 방법론으로, 2025년 현재도 클라우드 네이티브 애플리케이션의 표준입니다.

### 12가지 요소

#### 1. Codebase (코드베이스)
**원칙:** 버전 관리되는 하나의 코드베이스, 여러 배포

```bash
# Git으로 관리되는 단일 저장소
my-app/
├── .git/
├── src/
├── Dockerfile
└── k8s/
    ├── dev/
    ├── staging/
    └── production/
```

#### 2. Dependencies (의존성)
**원칙:** 의존성을 명시적으로 선언하고 격리

```python
# requirements.txt (Python)
fastapi==0.104.1
uvicorn==0.24.0
redis==5.0.1
```

```dockerfile
# Dockerfile에서 격리
FROM python:3.11-slim
COPY requirements.txt .
RUN pip install -r requirements.txt
```

#### 3. Config (설정)
**원칙:** 환경 변수로 설정 저장

```python
# ❌ 코드에 하드코딩
DATABASE_URL = "postgresql://localhost/mydb"

# ✅ 환경 변수 사용
import os
DATABASE_URL = os.getenv("DATABASE_URL")
```

```yaml
# Kubernetes ConfigMap 사용
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_URL: "postgresql://db:5432/mydb"
```

#### 4. Backing Services (백엔드 서비스)
**원칙:** 백엔드 서비스를 연결된 리소스로 취급

```python
# 데이터베이스, 캐시, 큐 등을 URL로 접근
database = connect(os.getenv("DATABASE_URL"))
cache = connect(os.getenv("REDIS_URL"))
queue = connect(os.getenv("RABBITMQ_URL"))

# 환경 변수만 변경하면 서비스 교체 가능
```

#### 5. Build, Release, Run (빌드, 릴리스, 실행)
**원칙:** 빌드와 실행 단계를 엄격히 분리

```bash
# Build: 코드를 실행 가능한 번들로 변환
docker build -t myapp:v1.2.3 .

# Release: 빌드와 설정 결합
docker tag myapp:v1.2.3 myapp:production-v1.2.3

# Run: 릴리스 버전 실행
kubectl set image deployment/myapp myapp=myapp:production-v1.2.3
```

#### 6. Processes (프로세스)
**원칙:** 애플리케이션을 무상태 프로세스로 실행

```python
# ❌ 로컬 메모리에 상태 저장
session_data = {}

# ✅ 외부 저장소 사용
import redis
cache = redis.Redis(host=os.getenv("REDIS_HOST"))
```

#### 7. Port Binding (포트 바인딩)
**원칙:** 포트 바인딩을 통해 서비스 노출

```python
# FastAPI 예제
import uvicorn
from fastapi import FastAPI

app = FastAPI()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8000)))
```

#### 8. Concurrency (동시성)
**원칙:** 프로세스 모델을 통한 확장

```yaml
# Kubernetes Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### 9. Disposability (폐기 가능성)
**원칙:** 빠른 시작과 우아한 종료

```python
import signal
import sys

def graceful_shutdown(signum, frame):
    print("Shutting down gracefully...")
    # 진행 중인 요청 완료
    # 연결 종료
    sys.exit(0)

signal.signal(signal.SIGTERM, graceful_shutdown)
```

```yaml
# Kubernetes에서 종료 대기 시간 설정
spec:
  containers:
  - name: app
    image: myapp:latest
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 15"]
  terminationGracePeriodSeconds: 30
```

#### 10. Dev/Prod Parity (개발/프로덕션 일치)
**원칙:** 개발, 스테이징, 프로덕션 환경을 최대한 비슷하게 유지

```yaml
# docker-compose.yml (로컬 개발)
services:
  app:
    image: myapp:latest
    environment:
      - DATABASE_URL=postgresql://db:5432/mydb
  db:
    image: postgres:15

# Kubernetes (프로덕션)
# 동일한 이미지와 서비스 구조 사용
```

#### 11. Logs (로그)
**원칙:** 로그를 이벤트 스트림으로 처리

```python
import logging
import sys

# stdout으로 로그 출력 (파일에 쓰지 않음)
logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)
logger.info("Application started")
```

```bash
# Kubernetes에서 로그 확인
kubectl logs -f deployment/web-app

# 중앙화된 로그 수집 (ELK, Loki 등)
```

#### 12. Admin Processes (관리 프로세스)
**원칙:** 관리 작업을 일회성 프로세스로 실행

```bash
# Kubernetes Job으로 DB 마이그레이션
kubectl run db-migrate \
  --image=myapp:latest \
  --restart=Never \
  --command -- python manage.py migrate
```

```yaml
# Job 정의
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: myapp:latest
        command: ["python", "manage.py", "migrate"]
      restartPolicy: Never
```

---

## 🛠️ 실습 가이드

### 실습 1: Docker 컨테이너화

**목표:** 간단한 FastAPI 애플리케이션을 컨테이너화

```python
# app.py
from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/")
def read_root():
    return {
        "message": "Hello from Docker!",
        "env": os.getenv("APP_ENV", "development")
    }

@app.get("/health")
def health_check():
    return {"status": "healthy"}
```

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

```bash
# 빌드 및 실행
docker build -t my-fastapi-app .
docker run -d -p 8000:8000 -e APP_ENV=production my-fastapi-app

# 테스트
curl http://localhost:8000
```

### 실습 2: Kubernetes 배포

```bash
# 1. Minikube 시작 (로컬 개발)
minikube start

# 2. Deployment 생성
kubectl create deployment hello-app --image=my-fastapi-app:latest

# 3. Service 노출
kubectl expose deployment hello-app --type=LoadBalancer --port=80 --target-port=8000

# 4. 확인
kubectl get pods
kubectl get services
minikube service hello-app --url
```

---

## 📚 참고 자료

### Docker
- [Docker 공식 문서](https://docs.docker.com/)
- [Docker Best Practices 2025](https://docs.docker.com/build/building/best-practices/)
- [Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)

### Kubernetes
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Kubernetes Tutorial for Beginners 2025](https://kodekloud.com/blog/kubernetes-tutorial-for-beginners-2025/)
- [Kubernetes By Example](https://kubernetesbyexample.com/)

### 12-Factor App
- [The Twelve-Factor App](https://12factor.net/)
- [12 Factor App Guide 2025](https://techoral.com/design/12-factor-app-guide.html)
- [Red Hat - 12 Factor App meets Kubernetes](https://www.redhat.com/en/blog/12-factor-app-containers)

### CNCF
- [CNCF Cloud Native Landscape](https://landscape.cncf.io/)
- [Cloud Native Glossary](https://glossary.cncf.io/)

---

## ✅ 학습 체크리스트

- [ ] Docker 컨테이너 이미지 빌드 및 실행
- [ ] Multi-stage 빌드를 사용한 최적화
- [ ] Docker Compose로 다중 컨테이너 관리
- [ ] Kubernetes Pod, Deployment, Service 이해
- [ ] kubectl 기본 명령어 사용
- [ ] ConfigMap과 Secret 관리
- [ ] 12-Factor App 방법론 이해 및 적용
- [ ] Health Check 및 Readiness Probe 구현
- [ ] 무상태(Stateless) 애플리케이션 설계

---

## 🎓 다음 단계

Cloud-Native 기초를 마스터한 후:
- [Ch4. DevOps 도구 및 실무](./Ch4.DevOps.md)로 진행
- 또는 [README](./README.md)로 돌아가서 학습 로드맵 확인
