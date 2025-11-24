# Ch5. 클라우드 인프라 설계

## 📋 개요

확장 가능하고 안정적인 클라우드 인프라를 설계하는 것은 현대 애플리케이션의 성공을 위한 핵심 요소입니다. 본 장에서는 고가용성(HA), 확장성(Scalability), 장애 복구(Fault Tolerance)를 보장하는 아키텍처 패턴과 설계 원칙을 학습하고, 실제 프로덕션 환경에서 적용 가능한 Multi-tier 아키텍처와 분산 시스템 설계 기법을 다룹니다.

2025년 현재, **AI 기반 자동 스케일링**, **Platform Engineering**, 그리고 **Multi-zone/Multi-region 배포**가 클라우드 아키텍처의 표준이 되었습니다.

## 🎯 학습 목표

1. **고가용성(HA) 설계**
   - 단일 장애점(SPOF) 제거
   - 리던던시 및 복제
   - 자동 장애 조치(Failover)
   - Zone 및 Region 분산

2. **확장성(Scalability) 패턴**
   - 수평 확장(Scale-out) vs 수직 확장(Scale-up)
   - 스테이트리스 설계
   - 데이터베이스 샤딩 및 파티셔닝
   - 캐싱 전략

3. **Multi-tier 아키텍처**
   - 프레젠테이션 계층
   - 애플리케이션 계층
   - 데이터 계층
   - 계층 간 통신 최적화

4. **복원력(Resilience) 패턴**
   - Circuit Breaker
   - Retry & Timeout
   - Bulkhead
   - Rate Limiting

5. **비용 최적화**
   - Right-sizing
   - Reserved Instances vs Spot
   - Auto-scaling 정책
   - FinOps 실천

6. **보안 아키텍처**
   - Zero Trust 모델
   - Network Segmentation
   - Secrets Management
   - 보안 모니터링

---

## Part 1: 고가용성(HA) 설계

### 1.1 HA 기본 원칙

**고가용성의 3대 요소:**
```
1. Redundancy (리던던시)
   └─ 중복 구성요소로 장애 대비

2. Monitoring (모니터링)
   └─ 장애 감지 및 알림

3. Failover (장애 조치)
   └─ 자동 복구 메커니즘
```

**가용성 계산:**
```
Availability % = (Total Time - Downtime) / Total Time × 100

예시:
- 99.9% (Three Nines):  43.2분 다운타임/월
- 99.99% (Four Nines):  4.32분 다운타임/월
- 99.999% (Five Nines): 25.9초 다운타임/월
```

### 1.2 단일 장애점(SPOF) 제거

**SPOF 식별 및 제거:**
```
❌ Bad Architecture (SPOF 존재):

Internet
   │
   ▼
Single Load Balancer  ← SPOF!
   │
   ▼
Single Web Server     ← SPOF!
   │
   ▼
Single Database       ← SPOF!


✅ Good Architecture (SPOF 제거):

Internet
   │
   ▼
┌──────────────────────────────┐
│  Multi-AZ Load Balancer      │  ← HA
│  (ALB/NLB with 2+ zones)     │
└──────────┬───────────────────┘
           │
    ┌──────┴──────┐
    │             │
┌───▼────┐   ┌───▼────┐
│ Web    │   │ Web    │          ← Auto Scaling Group
│ Zone A │   │ Zone B │
└───┬────┘   └───┬────┘
    │             │
    └──────┬──────┘
           ▼
    ┌─────────────┐
    │   Database  │
    │   Primary   │              ← Multi-AZ RDS
    │  (Zone A)   │
    └──────┬──────┘
           │ (Sync Replication)
    ┌──────▼──────┐
    │  Database   │
    │  Standby    │
    │  (Zone B)   │
    └─────────────┘
```

### 1.3 Multi-Zone & Multi-Region 배포

**Zone vs Region:**
| 개념 | 정의 | 장애 격리 | 지연시간 | 비용 |
|------|------|----------|---------|------|
| **Availability Zone** | 데이터센터 클러스터 | 물리적 장애 | <2ms | 낮음 |
| **Region** | 지리적으로 분리된 위치 | 재해 수준 | 50-300ms | 높음 |

**Multi-Zone 배포 (기본):**
```yaml
# Kubernetes Deployment with Multi-Zone
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 6
  template:
    spec:
      # Zone 분산 배치
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web-app
      containers:
        - name: app
          image: myapp:v1
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"

# 결과: 각 Zone에 2개씩 Pod 분산
# Zone A: 2 Pods
# Zone B: 2 Pods
# Zone C: 2 Pods
```

**Multi-Region 배포 (고급):**
```
Global Load Balancer (DNS-based)
    │
    ├─── Region: us-east-1 (Primary)
    │    └─ Multi-AZ Deployment
    │
    ├─── Region: eu-west-1 (Secondary)
    │    └─ Multi-AZ Deployment
    │
    └─── Region: ap-northeast-2 (Tertiary)
         └─ Multi-AZ Deployment

Database Replication:
  Primary (us-east-1)
      │ Async Replication
      ├─→ Replica (eu-west-1)
      └─→ Replica (ap-northeast-2)
```

### 1.4 Health Checks & Auto-Recovery

**Kubernetes Probes:**
```yaml
containers:
  - name: app
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3  # 3번 실패 시 재시작

    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
      successThreshold: 1
      failureThreshold: 3  # 3번 실패 시 트래픽 차단

    startupProbe:  # 초기 시작 시간이 긴 앱
      httpGet:
        path: /started
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 10
      failureThreshold: 30  # 최대 5분 대기
```

---

## Part 2: 확장성(Scalability) 패턴

### 2.1 수평 확장 vs 수직 확장

**비교:**
| 특징 | 수평 확장 (Scale-out) | 수직 확장 (Scale-up) |
|------|----------------------|---------------------|
| **방법** | 인스턴스 수 증가 | CPU/메모리 증가 |
| **한계** | 거의 무제한 | 하드웨어 한계 |
| **비용** | 선형 증가 | 비선형 증가 (고성능 비쌈) |
| **장애 복구** | 쉬움 (분산) | 어려움 (단일 인스턴스) |
| **적용** | 웹 앱, API, 스테이트리스 | DB, 캐시, 스테이트풀 |

**2025 Best Practice:**
> 수평 확장을 기본으로, 데이터베이스와 같이 불가피한 경우에만 수직 확장 사용

### 2.2 스테이트리스 설계

**스테이트리스 원칙:**
```python
# ❌ Stateful (나쁜 예)
class UserSession:
    def __init__(self):
        self.logged_in_users = {}  # 메모리에 세션 저장

    def login(self, user_id, token):
        self.logged_in_users[user_id] = token

    def is_logged_in(self, user_id):
        return user_id in self.logged_in_users

# 문제: 인스턴스가 재시작되면 세션 소실
# 문제: 로드 밸런서가 다른 인스턴스로 요청 보내면 인증 실패


# ✅ Stateless (좋은 예)
import redis

class UserSession:
    def __init__(self):
        self.redis_client = redis.Redis(host='redis-cluster')

    def login(self, user_id, token):
        # 외부 저장소에 세션 저장
        self.redis_client.setex(f"session:{user_id}", 3600, token)

    def is_logged_in(self, user_id):
        return self.redis_client.exists(f"session:{user_id}")

# 장점: 어떤 인스턴스가 요청을 처리해도 동일한 결과
# 장점: 인스턴스 재시작/추가/삭제가 자유로움
```

### 2.3 Auto-scaling 전략

**Horizontal Pod Autoscaler (HPA) - Kubernetes:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 3
  maxReplicas: 100
  metrics:
    # CPU 기반
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70  # 70% 이상 시 스케일 아웃

    # 메모리 기반
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

    # 커스텀 메트릭 (RPS - Requests Per Second)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"  # Pod당 1000 RPS 초과 시 스케일

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5분 안정화
      policies:
        - type: Percent
          value: 50  # 한 번에 50%만 축소
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0  # 즉시 확장
      policies:
        - type: Percent
          value: 100  # 한 번에 100% 확장 가능
          periodSeconds: 15
```

**AI 기반 Predictive Scaling (2025):**
```yaml
# KEDA (Kubernetes Event-driven Autoscaling) + AI
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: web-app-ai-scaler
spec:
  scaleTargetRef:
    name: web-app
  minReplicaCount: 5
  maxReplicaCount: 200
  triggers:
    # AI 예측 기반 스케일링
    - type: cron
      metadata:
        timezone: Asia/Seoul
        start: 00 18 * * 1-5    # 평일 저녁 6시
        end: 00 23 * * 1-5      # 평일 밤 11시
        desiredReplicas: "50"   # 트래픽 급증 예상 시간

    # 프로메테우스 메트릭 기반
    - type: prometheus
      metadata:
        serverAddress: http://prometheus:9090
        metricName: http_requests_per_second
        threshold: '1000'
        query: sum(rate(http_requests_total[2m]))
```

### 2.4 데이터베이스 확장

**읽기 복제본 (Read Replicas):**
```
┌─────────────────┐
│  Application    │
└────────┬────────┘
         │
    ┌────┴─────────────────────────┐
    │                              │
┌───▼─────────┐          ┌─────────▼─────┐
│  Write      │          │  Read         │
│  (Primary)  │─────────▶│  (Replica 1)  │
└─────────────┘  Async   └───────────────┘
                 Replication
                          ┌───────────────┐
                          │  Read         │
                          │  (Replica 2)  │
                          └───────────────┘

Application Logic:
  - Write: Primary DB
  - Read:  Replicas (Load Balanced)
```

**샤딩 (Sharding):**
```python
# User ID 기반 샤딩
def get_shard(user_id):
    shard_count = 4
    shard_id = user_id % shard_count
    return f"db-shard-{shard_id}"

# 예시:
# user_id=1 → db-shard-1
# user_id=2 → db-shard-2
# user_id=3 → db-shard-3
# user_id=4 → db-shard-0 (4 % 4 = 0)

# Shard 0: users 0, 4, 8, 12, ...
# Shard 1: users 1, 5, 9, 13, ...
# Shard 2: users 2, 6, 10, 14, ...
# Shard 3: users 3, 7, 11, 15, ...
```

---

## Part 3: Multi-tier 아키텍처

### 3.1 3-Tier 아키텍처

**전통적인 3-Tier:**
```
┌──────────────────────────────────────────────┐
│         Presentation Tier (프론트엔드)        │
│  - Web UI (React, Vue, Angular)              │
│  - Mobile App (iOS, Android)                 │
│  - CDN으로 정적 컨텐츠 제공                   │
└──────────────┬───────────────────────────────┘
               │ HTTP/REST
┌──────────────▼───────────────────────────────┐
│         Application Tier (백엔드)             │
│  - API Gateway                                │
│  - Microservices (Node.js, Python, Go)       │
│  - Business Logic                             │
│  - Auto Scaling Group                         │
└──────────────┬───────────────────────────────┘
               │ SQL/NoSQL
┌──────────────▼───────────────────────────────┐
│         Data Tier (데이터)                    │
│  - Primary Database (RDS/Aurora)              │
│  - Read Replicas                              │
│  - Cache (Redis/Memcached)                    │
│  - Object Storage (S3)                        │
└───────────────────────────────────────────────┘
```

### 3.2 현대적 Multi-tier 아키텍처 (2025)

```
┌─────────────────────────────────────────────────────┐
│              Edge Tier (CDN + WAF)                   │
│  - CloudFlare / Fastly / CloudFront                  │
│  - DDoS Protection                                   │
│  - SSL/TLS Termination                               │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│         API Gateway Tier                             │
│  - Kong / Ambassador / AWS API Gateway               │
│  - Rate Limiting                                     │
│  - Authentication (OAuth2, JWT)                      │
│  - Request Routing                                   │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│         Service Mesh Tier                            │
│  - Istio / Linkerd                                   │
│  - Traffic Management                                │
│  - Observability                                     │
│  - mTLS                                              │
└─────────────────────┬───────────────────────────────┘
                      │
        ┌─────────────┼─────────────┬──────────────┐
        │             │             │              │
┌───────▼────┐ ┌──────▼─────┐ ┌────▼──────┐ ┌────▼──────┐
│ User       │ │ Order      │ │ Payment   │ │ Inventory │
│ Service    │ │ Service    │ │ Service   │ │ Service   │
└───────┬────┘ └──────┬─────┘ └────┬──────┘ └────┬──────┘
        │             │             │              │
┌───────▼─────────────▼─────────────▼──────────────▼─────┐
│         Data Tier                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐│
│  │PostgreSQL│  │  MongoDB │  │  Redis   │  │   S3    ││
│  └──────────┘  └──────────┘  └──────────┘  └─────────┘│
└──────────────────────────────────────────────────────────┘
```

### 3.3 Network Segmentation

**보안 영역 분리:**
```
┌─────────────────────────────────────────────────┐
│  Public Subnet (DMZ)                            │
│  - Load Balancer                                │
│  - Bastion Host                                 │
│  CIDR: 10.0.1.0/24                              │
│  Internet Gateway 연결                          │
└────────────────┬────────────────────────────────┘
                 │ Security Group Rules
┌────────────────▼────────────────────────────────┐
│  Private Subnet (Application)                   │
│  - Web Servers                                  │
│  - App Servers                                  │
│  CIDR: 10.0.10.0/24                             │
│  NAT Gateway를 통한 아웃바운드만 허용            │
└────────────────┬────────────────────────────────┘
                 │ Security Group Rules
┌────────────────▼────────────────────────────────┐
│  Private Subnet (Database)                      │
│  - RDS (Primary & Standby)                      │
│  - ElastiCache                                  │
│  CIDR: 10.0.20.0/24                             │
│  외부 접근 완전 차단                             │
└─────────────────────────────────────────────────┘
```

---

## Part 4: 복원력(Resilience) 패턴

### 4.1 Circuit Breaker

**개념:**
서비스 장애 시 연쇄 장애 방지를 위해 호출을 차단하는 패턴

**상태 전이:**
```
Closed (정상) ──── 실패 임계값 초과 ───→ Open (차단)
      ▲                                      │
      │                                      │ 타임아웃 후
      │                                      ▼
      └──── 성공 시 ──────────── Half-Open (시험)
```

**구현 (Python):**
```python
import time
from enum import Enum

class CircuitState(Enum):
    CLOSED = "CLOSED"
    OPEN = "OPEN"
    HALF_OPEN = "HALF_OPEN"

class CircuitBreaker:
    def __init__(self, failure_threshold=5, timeout=60):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED

    def call(self, func, *args, **kwargs):
        if self.state == CircuitState.OPEN:
            if time.time() - self.last_failure_time > self.timeout:
                self.state = CircuitState.HALF_OPEN
                print("Circuit HALF_OPEN - Testing")
            else:
                raise Exception("Circuit OPEN - Request blocked")

        try:
            result = func(*args, **kwargs)
            self.on_success()
            return result
        except Exception as e:
            self.on_failure()
            raise e

    def on_success(self):
        self.failure_count = 0
        self.state = CircuitState.CLOSED
        print("Circuit CLOSED")

    def on_failure(self):
        self.failure_count += 1
        self.last_failure_time = time.time()

        if self.failure_count >= self.failure_threshold:
            self.state = CircuitState.OPEN
            print(f"Circuit OPEN - Too many failures ({self.failure_count})")

# 사용 예시
import requests

breaker = CircuitBreaker(failure_threshold=3, timeout=30)

def call_external_api():
    response = requests.get("https://api.example.com/data", timeout=5)
    response.raise_for_status()
    return response.json()

# Circuit Breaker로 보호
try:
    data = breaker.call(call_external_api)
except Exception as e:
    print(f"Error: {e}")
    # Fallback 로직
    data = get_cached_data()
```

### 4.2 Retry with Exponential Backoff

```python
import time
import random

def retry_with_backoff(func, max_retries=5, base_delay=1, max_delay=60):
    """
    지수 백오프를 사용한 재시도
    """
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise e  # 마지막 시도 실패 시 예외 발생

            # 지수 백오프 계산
            delay = min(base_delay * (2 ** attempt), max_delay)
            # Jitter 추가 (동시 재시도 방지)
            jitter = random.uniform(0, delay * 0.1)
            total_delay = delay + jitter

            print(f"Attempt {attempt + 1} failed. Retrying in {total_delay:.2f}s...")
            time.sleep(total_delay)

# 사용 예시
def unreliable_api_call():
    response = requests.post("https://api.example.com/process")
    response.raise_for_status()
    return response.json()

result = retry_with_backoff(unreliable_api_call, max_retries=5)
```

### 4.3 Bulkhead 패턴

**개념:** 리소스를 격리하여 장애 전파 방지

```python
from concurrent.futures import ThreadPoolExecutor
import threading

class Bulkhead:
    def __init__(self, name, max_workers=10):
        self.name = name
        self.executor = ThreadPoolExecutor(max_workers=max_workers)
        self.semaphore = threading.Semaphore(max_workers)

    def execute(self, func, *args, **kwargs):
        if not self.semaphore.acquire(blocking=False):
            raise Exception(f"Bulkhead {self.name} is full")

        try:
            future = self.executor.submit(func, *args, **kwargs)
            return future.result()
        finally:
            self.semaphore.release()

# 서비스별로 별도의 Thread Pool
payment_bulkhead = Bulkhead("payment", max_workers=20)
notification_bulkhead = Bulkhead("notification", max_workers=5)

# Payment 서비스 호출 (최대 20개 동시)
payment_bulkhead.execute(process_payment, order_id)

# Notification 서비스 호출 (최대 5개 동시)
# 느린 Notification이 Payment를 막지 않음
notification_bulkhead.execute(send_email, user_email)
```

---

## Part 5: 비용 최적화

### 5.1 Right-sizing

**CPU/메모리 사용률 분석:**
```bash
# Prometheus Query
# 지난 7일간 평균 CPU 사용률
avg_over_time(
  container_cpu_usage_seconds_total{pod="my-app"}[7d]
)

# 메모리 사용률
avg_over_time(
  container_memory_working_set_bytes{pod="my-app"}[7d]
) / on(pod) container_spec_memory_limit_bytes
```

**권장사항:**
- CPU 사용률 < 20%: 인스턴스 다운사이징
- CPU 사용률 > 80%: 인스턴스 업사이징 또는 스케일 아웃
- 메모리 사용률 < 50%: 메모리 줄이기
- 메모리 사용률 > 90%: OOM 위험, 증설 필요

### 5.2 Spot Instances 활용

**Kubernetes에서 Spot Instance 사용:**
```yaml
apiVersion: v1
kind: Node
metadata:
  labels:
    node.kubernetes.io/instance-type: spot
    workload-type: batch

# Deployment with Spot Instances
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
spec:
  replicas: 10
  template:
    spec:
      # Spot 인스턴스에 배치
      nodeSelector:
        node.kubernetes.io/instance-type: spot

      # Spot 중단에 대비
      tolerations:
        - key: "spot-instance"
          operator: "Exists"
          effect: "NoSchedule"

      # Pod Disruption Budget
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: batch-processor
                topologyKey: kubernetes.io/hostname
```

---

## 📚 참고 자료

### 2025 Best Practices
1. [Cloud Computing Best Practices 2025](https://distantjob.com/blog/cloud-computing-best-practices/)
2. [How to Design Scalable & Resilient Cloud Infrastructure](https://qentelli.com/thought-leadership/insights/best-practices-for-building-scalable-and-resilient-cloud-infrastructure)
3. [Enterprise Cloud Architecture Best Practices 2025](https://fullscale.io/blog/cloud-architecture-best-practices-2025/)
4. [High Availability in Cloud Computing](https://aerospike.com/blog/what-is-high-availability/)

### 공식 문서
1. [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
2. [Google Cloud Architecture Center](https://cloud.google.com/architecture)
3. [Azure Architecture Center](https://docs.microsoft.com/en-us/azure/architecture/)

---

## ✅ 학습 체크리스트

- [ ] SPOF 제거 및 리던던시 설계
- [ ] Multi-Zone/Region 배포 전략
- [ ] 수평 확장 vs 수직 확장 이해
- [ ] Auto-scaling 정책 설정
- [ ] Circuit Breaker 패턴 구현
- [ ] Network Segmentation 설계
- [ ] 비용 최적화 (Right-sizing, Spot)

---

**마지막 업데이트:** 2025-11-24
**다음 챕터:** [Ch6.Kubernetes_Operator.md](./Ch6.Kubernetes_Operator.md)
