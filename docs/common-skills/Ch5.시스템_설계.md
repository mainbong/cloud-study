# Ch5. 시스템 설계 및 아키텍처

## 📋 개요

확장 가능하고 안정적인 시스템을 설계하는 능력은 클라우드 엔지니어의 핵심 역량입니다. 이 장에서는 대규모 분산 시스템의 설계 원칙과 마이크로서비스 아키텍처 패턴을 다룹니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:
- 확장성, 가용성, 일관성을 고려한 시스템 설계
- CAP 정리와 분산 시스템의 트레이드오프 이해
- 마이크로서비스 아키텍처 설계 및 패턴 적용
- 서비스 메시를 활용한 서비스 간 통신 관리

---

## 🏗️ Part 1: 시스템 설계 기초

### 1. Scalability (확장성)

#### 수직 확장 (Vertical Scaling)

기존 서버의 성능을 높이는 방식입니다.

**장점:**

- 구현이 간단
- 데이터 일관성 유지 용이
- 네트워크 지연 없음

**단점:**

- 물리적 한계 존재
- 단일 장애점 (Single Point of Failure)
- 비용 비효율적 (하드웨어 성능이 2배 높아지면 비용은 3-4배)

```
[Before]          [After]
2 CPU             8 CPU
4GB RAM    →      32GB RAM
100GB Disk        1TB Disk
```

#### 수평 확장 (Horizontal Scaling)

서버의 수를 늘리는 방식입니다.

**장점:**

- 이론적으로 무한 확장 가능
- 고가용성 (한 서버 장애 시 다른 서버가 처리)
- 비용 효율적

**단점:**

- 구현 복잡도 증가
- 데이터 일관성 문제
- 네트워크 지연

```
[Before]          [After]
Server 1          Server 1
                  Server 2
        →         Server 3
                  Server 4
                  Load Balancer
```

#### 로드 밸런싱

```yaml
# Kubernetes Service (LoadBalancer 타입)
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

**로드 밸런싱 알고리즘:**

- **Round Robin**: 순환 방식
- **Least Connections**: 연결 수가 적은 서버 우선
- **IP Hash**: 클라이언트 IP 기반 해싱
- **Weighted**: 서버 성능에 따라 가중치 부여

---

### 2. Availability (가용성)

**가용성 계산:**
```
Availability = (Total Time - Downtime) / Total Time × 100

99.9% (Three Nines)  = 8.76 hours/year downtime
99.99% (Four Nines)  = 52.56 minutes/year downtime
99.999% (Five Nines) = 5.26 minutes/year downtime
```

#### 고가용성 설계 패턴

**1. Redundancy (중복성):**
```
[Active-Active]
┌─────────┐    ┌─────────┐
│ Server 1│    │ Server 2│
└─────────┘    └─────────┘
      ↑              ↑
      └──── LB ──────┘

[Active-Passive]
┌─────────┐    ┌─────────┐
│ Primary │    │ Standby │
└─────────┘    └─────────┘
      ↑              ↑
  (Active)      (Failover)
```

**2. Health Checks:**
```yaml
# Kubernetes Liveness & Readiness Probes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**3. Circuit Breaker (서킷 브레이커):**
```python
# Python 예제
from circuitbreaker import circuit

@circuit(failure_threshold=5, recovery_timeout=60)
def call_external_service():
    response = requests.get('https://api.example.com/data')
    return response.json()

# 5번 실패 시 Circuit이 Open되고 60초 동안 요청 차단
# 이후 Half-Open 상태로 전환하여 복구 시도
```

**Circuit Breaker 상태:**
```
[Closed] → (실패 임계치 초과) → [Open] → (타임아웃) → [Half-Open]
   ↑                                                          ↓
   └──────────────── (성공) ────────────────────────────────┘
```

---

### 3. Consistency (일관성)

#### 일관성 모델

**1. Strong Consistency (강한 일관성):**

- 모든 읽기 작업이 가장 최근 쓰기 결과를 반환
- RDBMS, Zookeeper
- 지연 시간 증가, 가용성 감소

**2. Eventual Consistency (최종 일관성):**

- 일정 시간 후 모든 복제본이 일치
- DynamoDB, Cassandra
- 높은 가용성, 낮은 지연 시간

**3. Causal Consistency (인과 일관성):**

- 인과 관계가 있는 작업은 순서 보장
- 중간 수준의 일관성

```python
# Eventual Consistency 예제
# Write to primary
db.users.insert({'id': 1, 'name': 'Alice'})

# Read from replica (might not be updated yet)
user = replica_db.users.find_one({'id': 1})
# user might be None or outdated

# After some time (eventual)
user = replica_db.users.find_one({'id': 1})
# user is now up-to-date
```

---

## 🔄 Part 2: 분산 시스템

### 1. CAP 정리 (CAP Theorem)

**CAP 정리:** 분산 시스템은 다음 세 가지 중 최대 두 가지만 동시에 보장할 수 있습니다.

- **C (Consistency)**: 모든 노드가 동일한 데이터를 봄
- **A (Availability)**: 모든 요청이 응답을 받음
- **P (Partition Tolerance)**: 네트워크 분할에도 시스템이 동작

```
        C (Consistency)
           /\
          /  \
         /    \
        /  CA  \
       /        \
      /          \
     /            \
    /      CAP     \
   /                \
  /__________________\
 P                    A
(Partition)      (Availability)

CP: Consistency + Partition (예: MongoDB, HBase)
AP: Availability + Partition (예: Cassandra, DynamoDB)
CA: 이론적으로만 가능 (네트워크 분할 불가능)
```

#### 실제 시스템 예제

**CP Systems (MongoDB):**
```python
# MongoDB - Strong Consistency
from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017/',
                     readPreference='primary')  # 항상 primary에서 읽기

# Write
db.users.insert_one({'name': 'Alice'})

# Read (항상 최신 데이터, 하지만 partition 시 unavailable)
user = db.users.find_one({'name': 'Alice'})
```

**AP Systems (Cassandra):**
```python
# Cassandra - High Availability
from cassandra.cluster import Cluster

cluster = Cluster(['node1', 'node2', 'node3'])
session = cluster.connect('mykeyspace')

# Write with replication
session.execute(
    "INSERT INTO users (id, name) VALUES (%s, %s)",
    (1, 'Alice')
)

# Read (항상 응답, 하지만 최신 데이터 아닐 수 있음)
result = session.execute("SELECT * FROM users WHERE id = 1")
```

### 2. PACELC 정리

CAP 정리의 확장으로, 파티션이 없는 경우의 트레이드오프를 설명합니다.

**PACELC:**

- **P**artition이 발생하면: **A**vailability vs **C**onsistency
- **E**lse (정상 상태): **L**atency vs **C**onsistency

```
Examples:
- MongoDB: PC/EC (Consistency 우선)
- Cassandra: PA/EL (Availability & Low Latency 우선)
- DynamoDB: PA/EL
```

### 3. 분산 트랜잭션

#### Two-Phase Commit (2PC)

```
Coordinator              Participant 1         Participant 2
    |                         |                      |
    |----Prepare------------>|                      |
    |----Prepare----------------------------->|
    |                         |                      |
    |<---Vote: Commit---------|                      |
    |<---Vote: Commit--------------------------|
    |                         |                      |
    |----Commit------------->|                      |
    |----Commit---------------------------->|
    |                         |                      |
    |<---Ack------------------|                      |
    |<---Ack------------------------------------|
```

**단점:**

- 블로킹 프로토콜 (coordinator 실패 시 대기)
- 높은 지연 시간
- 확장성 제한

#### Saga Pattern

마이크로서비스에서 분산 트랜잭션을 처리하는 패턴입니다.

```python
# Choreography-based Saga
class OrderService:
    def create_order(self, order_data):
        # 1. 주문 생성
        order = self.db.orders.insert(order_data)

        # 2. 이벤트 발행
        self.event_bus.publish('OrderCreated', order)

        return order

class PaymentService:
    def on_order_created(self, order):
        try:
            # 결제 처리
            payment = self.process_payment(order)
            self.event_bus.publish('PaymentCompleted', payment)
        except PaymentError:
            # 보상 트랜잭션
            self.event_bus.publish('PaymentFailed', order)

class InventoryService:
    def on_payment_completed(self, payment):
        # 재고 차감
        self.reserve_inventory(payment.order_id)
        self.event_bus.publish('InventoryReserved', payment)

    def on_payment_failed(self, order):
        # 보상: 필요 없음 (재고 차감 전)
        pass
```

---

## 🏢 Part 3: 마이크로서비스 아키텍처

### 1. 마이크로서비스 vs 모놀리식

```
[Monolithic]                   [Microservices]
┌─────────────────┐           ┌──────┐ ┌──────┐ ┌──────┐
│                 │           │User  │ │Order │ │Pay   │
│  All-in-One     │           │Service│ │Service│ │Service│
│  Application    │           └──────┘ └──────┘ └──────┘
│                 │                ↓        ↓        ↓
│ - User Module   │           ┌──────┐ ┌──────┐ ┌──────┐
│ - Order Module  │           │  DB  │ │  DB  │ │  DB  │
│ - Payment Module│           └──────┘ └──────┘ └──────┘
└─────────────────┘
        ↓
   ┌────────┐
   │   DB   │
   └────────┘
```

**마이크로서비스 장점:**

- 독립적인 배포 및 확장
- 기술 스택 자유도
- 팀 자율성
- 장애 격리

**마이크로서비스 단점:**

- 높은 복잡도
- 분산 시스템 문제 (네트워크 지연, 장애 등)
- 데이터 일관성 문제
- 운영 오버헤드

### 2. 마이크로서비스 패턴

#### API Gateway 패턴

```
Client
  ↓
┌─────────────┐
│ API Gateway │
└─────────────┘
  ↓    ↓    ↓
Service Service Service
  A      B      C
```

```yaml
# Kong API Gateway 설정 예제
services:
  - name: user-service
    url: http://user-service:8080
    routes:
      - name: user-route
        paths:
          - /api/users

  - name: order-service
    url: http://order-service:8080
    routes:
      - name: order-route
        paths:
          - /api/orders

plugins:
  - name: rate-limiting
    config:
      minute: 100
  - name: jwt
  - name: cors
```

#### Service Mesh (서비스 메시)

```
┌────────┐     ┌────────┐     ┌────────┐
│Service │◄───►│Service │◄───►│Service │
│   A    │     │   B    │     │   C    │
└────────┘     └────────┘     └────────┘
    ↕              ↕              ↕
┌────────┐     ┌────────┐     ┌────────┐
│Sidecar │◄───►│Sidecar │◄───►│Sidecar │
│ Proxy  │     │ Proxy  │     │ Proxy  │
└────────┘     └────────┘     └────────┘
    ↕              ↕              ↕
┌──────────────────────────────────────┐
│        Control Plane (Istio)         │
└──────────────────────────────────────┘
```

**Istio 예제:**
```yaml
# VirtualService - Traffic Routing
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: user-service
spec:
  hosts:
    - user-service
  http:
    - match:
        - headers:
            canary:
              exact: "true"
      route:
        - destination:
            host: user-service
            subset: v2
          weight: 100
    - route:
        - destination:
            host: user-service
            subset: v1
          weight: 90
        - destination:
            host: user-service
            subset: v2
          weight: 10  # Canary 배포: 10% 트래픽
---
# DestinationRule
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: user-service
spec:
  host: user-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

#### Event-Driven Architecture

```python
# Event Producer
class OrderService:
    def create_order(self, order_data):
        order = self.save_order(order_data)

        # 이벤트 발행
        event = {
            'event_type': 'OrderCreated',
            'order_id': order.id,
            'user_id': order.user_id,
            'amount': order.amount,
            'timestamp': datetime.now().isoformat()
        }

        self.kafka_producer.send('order-events', value=event)
        return order

# Event Consumer
class NotificationService:
    def __init__(self):
        self.consumer = KafkaConsumer(
            'order-events',
            group_id='notification-service',
            value_deserializer=lambda m: json.loads(m.decode('utf-8'))
        )

    def consume_events(self):
        for message in self.consumer:
            event = message.value

            if event['event_type'] == 'OrderCreated':
                self.send_notification(
                    user_id=event['user_id'],
                    message=f"Your order {event['order_id']} has been created"
                )
```

#### CQRS (Command Query Responsibility Segregation)

```python
# Command Model (Write)
class CreateOrderCommand:
    def __init__(self, user_id, items):
        self.user_id = user_id
        self.items = items

class OrderCommandHandler:
    def handle(self, command: CreateOrderCommand):
        # 주문 생성 (Write DB)
        order = Order(
            user_id=command.user_id,
            items=command.items
        )
        self.write_db.save(order)

        # 이벤트 발행 (Read Model 업데이트용)
        self.event_bus.publish('OrderCreated', order)

# Query Model (Read)
class OrderQueryService:
    def get_user_orders(self, user_id):
        # Read-optimized DB에서 조회
        return self.read_db.query(
            "SELECT * FROM order_view WHERE user_id = %s",
            user_id
        )

    def on_order_created(self, event):
        # Read Model 업데이트
        self.read_db.execute(
            "INSERT INTO order_view (order_id, user_id, ...) VALUES (...)"
        )
```

### 3. 서비스 간 통신

#### Synchronous Communication (동기)

**REST API:**
```python
# Service A
import requests

response = requests.post(
    'http://service-b:8080/api/process',
    json={'data': 'value'},
    timeout=5
)
result = response.json()
```

**gRPC:**
```python
# Service A (Client)
import grpc
from proto import service_pb2, service_pb2_grpc

channel = grpc.insecure_channel('service-b:50051')
stub = service_pb2_grpc.ProcessorStub(channel)

response = stub.Process(
    service_pb2.Request(data='value')
)
```

#### Asynchronous Communication (비동기)

**Message Queue (RabbitMQ):**
```python
# Producer
import pika

connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost')
)
channel = connection.channel()
channel.queue_declare(queue='tasks')

channel.basic_publish(
    exchange='',
    routing_key='tasks',
    body='Task data'
)

# Consumer
def callback(ch, method, properties, body):
    print(f"Received: {body}")
    # 작업 처리
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(
    queue='tasks',
    on_message_callback=callback
)
channel.start_consuming()
```

---

## 🎯 Part 4: 시스템 설계 예제

### Example: URL Shortener 설계

#### 요구사항

**Functional:**

- 긴 URL을 짧은 URL로 변환
- 짧은 URL로 원본 URL 리다이렉트
- 통계 수집 (클릭 수, 위치 등)

**Non-Functional:**

- 높은 가용성 (99.99%)
- 낮은 지연 시간 (<100ms)
- 확장 가능 (1B URLs, 10K QPS)

#### 시스템 설계

```
┌──────────┐
│  Client  │
└─────┬────┘
      │
      ↓
┌─────────────┐
│Load Balancer│
└──────┬──────┘
       │
       ↓
┌──────────────────┐
│   API Gateway    │
└────────┬─────────┘
         │
    ┌────┴────┐
    ↓         ↓
┌────────┐ ┌──────────┐
│Shorten │ │Redirect  │
│Service │ │Service   │
└────┬───┘ └────┬─────┘
     │          │
     ↓          ↓
┌─────────────────┐
│  Redis Cache    │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│   PostgreSQL    │
└─────────────────┘
```

#### 구현

```python
# URL 단축 알고리즘
import hashlib
import base62

class URLShortener:
    def __init__(self):
        self.db = PostgreSQL()
        self.cache = Redis()

    def shorten(self, long_url):
        # ID 생성 (Auto-increment or Snowflake)
        url_id = self.db.get_next_id()

        # Base62 인코딩 (62^7 = 3.5 trillion combinations)
        short_code = base62.encode(url_id)

        # 저장
        self.db.insert({
            'id': url_id,
            'short_code': short_code,
            'long_url': long_url,
            'created_at': datetime.now()
        })

        # 캐시
        self.cache.set(short_code, long_url, ex=86400)  # 24시간

        return f"https://short.url/{short_code}"

    def redirect(self, short_code):
        # 캐시 확인
        long_url = self.cache.get(short_code)
        if long_url:
            return long_url

        # DB 조회
        result = self.db.query(
            "SELECT long_url FROM urls WHERE short_code = %s",
            short_code
        )

        if result:
            long_url = result['long_url']
            # 캐시 저장
            self.cache.set(short_code, long_url, ex=86400)
            return long_url

        raise NotFoundException("URL not found")
```

**확장 고려사항:**

- Database Sharding (URL ID 범위 기반)
- CDN for geo-distributed access
- Analytics service (별도 마이크로서비스)
- Rate limiting (남용 방지)

---

## 📚 참고 자료

### 시스템 설계
- [Designing Data-Intensive Applications](https://www.oreilly.com/library/view/designing-data-intensive-applications/9781491903063/)
- [System Design Interview](https://www.amazon.com/System-Design-Interview-insiders-Second/dp/B08CMF2CQF)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### 분산 시스템
- [CAP Theorem - Wikipedia](https://en.wikipedia.org/wiki/CAP_theorem)
- [PACELC Theorem](https://www.cs.umd.edu/~abadi/papers/abadi-pacelc.pdf)
- [Designing Distributed Systems](https://www.oreilly.com/library/view/designing-distributed-systems/9781491983638/)

### 마이크로서비스
- [Microservices Patterns](https://microservices.io/patterns/)
- [Building Microservices](https://www.oreilly.com/library/view/building-microservices-2nd/9781492034018/)
- [Service Mesh Patterns](https://www.manning.com/books/service-mesh-patterns)
- [Istio Documentation](https://istio.io/latest/docs/)

---

## ✅ 학습 체크리스트

- [ ] 수평/수직 확장의 차이 이해
- [ ] 고가용성 설계 패턴 적용 (Redundancy, Circuit Breaker)
- [ ] CAP 정리 및 PACELC 이해
- [ ] 분산 트랜잭션 패턴 (2PC, Saga) 이해
- [ ] 마이크로서비스 아키텍처 설계
- [ ] API Gateway 패턴 적용
- [ ] 서비스 메시 (Istio) 이해 및 사용
- [ ] Event-Driven Architecture 구현
- [ ] CQRS 패턴 이해
- [ ] 실제 시스템 설계 (URL Shortener, Social Network 등)

---

## 🎓 다음 단계

Common Skills 학습을 완료했습니다! 이제 포지션별 심화 학습으로 넘어가세요:
- [Infrastructure Platform 개발자](../infrastructure-platform/README.md)
- [컴퓨팅 서비스 개발자](../computing-service/README.md)
- 또는 [전체 가이드](../README.md)로 돌아가기
