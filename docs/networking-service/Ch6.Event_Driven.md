# Ch6. Event-Driven Architecture

## 📋 개요

Event-Driven Architecture (EDA)는 이벤트의 생성, 감지, 소비, 반응을 중심으로 설계된 소프트웨어 아키텍처 패턴입니다. 마이크로서비스 시대에 EDA는 느슨한 결합(Loose Coupling), 확장성(Scalability), 탄력성(Resilience)을 제공하는 핵심 아키텍처로 자리잡았습니다.

2025년 현재, Event Sourcing과 CQRS는 금융, 전자상거래, 헬스케어 등 감사 추적이 중요한 도메인에서 표준 패턴이 되었습니다. Kafka는 100만 메시지/초의 처리량으로 대규모 스트리밍 플랫폼의 표준이며, RabbitMQ는 낮은 지연시간과 복잡한 라우팅이 필요한 환경에서 여전히 선호됩니다.

이 챕터에서는 Event Sourcing, CQRS, Message Brokers, Event Streaming까지 이벤트 기반 아키텍처의 모든 측면을 다룹니다.

---

## 🎯 학습 목표

이 챕터를 완료하면 다음을 할 수 있습니다:

- Event-Driven Architecture의 핵심 개념 이해
- Event Sourcing 패턴 설계 및 구현
- CQRS 패턴 적용 시기 및 방법 파악
- RabbitMQ vs Kafka 선택 기준 이해
- Message Broker 설치 및 운영
- Event Streaming 아키텍처 설계
- Eventual Consistency 처리 전략 수립

---

## Part 1: Event-Driven Architecture 개요

### 1-1. EDA 핵심 개념

**전통적인 아키텍처 vs Event-Driven:**

```
전통적인 동기 아키텍처:
Client → [API Gateway] → [Service A] → [Service B] → [Service C]
         (동기 호출 체인)

문제점:
- 강한 결합 (Tight Coupling)
- 단일 실패 지점 (Single Point of Failure)
- 확장성 제한
- 높은 지연시간 (누적)


Event-Driven 아키텍처:
                    ┌─────────────┐
         ┌─────────→│ Event Bus   │←──────────┐
         │          │ (Kafka/MQ)  │           │
         │          └─────────────┘           │
         │                 │                  │
    (Publish)          (Subscribe)       (Subscribe)
         │                 │                  │
    ┌────┴────┐      ┌────▼────┐       ┌────▼────┐
    │Service A│      │Service B│       │Service C│
    └─────────┘      └─────────┘       └─────────┘

장점:
✓ 느슨한 결합 (Loose Coupling)
✓ 독립적 확장 (Independent Scaling)
✓ 탄력성 (Resilience)
✓ 비동기 처리 (Async Processing)
```

**이벤트 타입:**

```
1. Event Notification (이벤트 알림)
   - 단순 알림
   - 최소한의 데이터
   - 예: "주문이 생성되었습니다" (OrderID만 포함)

2. Event-Carried State Transfer (상태 전달 이벤트)
   - 전체 상태 포함
   - 수신자가 자체 캐시 구축
   - 예: "주문 생성" (전체 Order 객체 포함)

3. Event Sourcing (이벤트 소싱)
   - 상태 변경을 이벤트로 저장
   - 이벤트 재생으로 상태 재구성
   - 예: "OrderCreated" → "OrderPaid" → "OrderShipped"
```

### 1-2. Event Sourcing 패턴

**Event Sourcing이란?**

애플리케이션의 상태를 변경하는 모든 이벤트를 순서대로 저장하고, 이벤트 재생(Replay)을 통해 현재 상태를 재구성하는 패턴입니다.

**전통적인 CRUD vs Event Sourcing:**

```
전통적인 CRUD (상태 저장):
┌──────────────────────────────────┐
│        Orders Table              │
├──────────────────────────────────┤
│ ID │ Status   │ Amount │ Updated │
├────┼──────────┼────────┼─────────┤
│ 1  │ Shipped  │ $100   │ 10:30   │ ← 최종 상태만 저장
└──────────────────────────────────┘

히스토리 손실:
- 언제 생성?
- 누가 결제?
- 언제 배송?
→ 별도 감사 로그 필요


Event Sourcing (이벤트 저장):
┌─────────────────────────────────────────────────────┐
│             Event Store (Append-Only)               │
├─────────────────────────────────────────────────────┤
│ OrderCreated   │ OrderID=1  │ Amount=$100 │ 09:00  │
│ OrderPaid      │ OrderID=1  │ Method=Card │ 09:05  │
│ OrderShipped   │ OrderID=1  │ Carrier=DHL │ 10:30  │
└─────────────────────────────────────────────────────┘
               ↓ (Replay/Project)
┌──────────────────────────────────┐
│     Current State (Read Model)   │
├──────────────────────────────────┤
│ ID │ Status   │ Amount │         │
├────┼──────────┼────────┼─────────┤
│ 1  │ Shipped  │ $100   │         │
└──────────────────────────────────┘

장점:
✓ 완전한 감사 추적 (Full Audit Trail)
✓ 시점 복원 (Point-in-Time Recovery)
✓ 이벤트 재생 (Replay)
✓ 디버깅 용이
```

**Event Sourcing 구현 (Python 예제):**

```python
# event_sourcing.py
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Dict, Any
from enum import Enum

# 이벤트 베이스 클래스
@dataclass
class Event:
    event_id: str
    aggregate_id: str
    timestamp: datetime = field(default_factory=datetime.now)
    version: int = 1

# 도메인 이벤트
@dataclass
class OrderCreated(Event):
    customer_id: str
    items: List[Dict[str, Any]]
    total_amount: float

@dataclass
class OrderPaid(Event):
    payment_method: str
    transaction_id: str

@dataclass
class OrderShipped(Event):
    carrier: str
    tracking_number: str

# Aggregate (주문)
class OrderStatus(Enum):
    CREATED = "created"
    PAID = "paid"
    SHIPPED = "shipped"
    DELIVERED = "delivered"

class Order:
    def __init__(self, order_id: str):
        self.order_id = order_id
        self.customer_id = None
        self.items = []
        self.total_amount = 0.0
        self.status = None
        self.payment_method = None
        self.tracking_number = None
        self.version = 0
        self.changes: List[Event] = []

    def create_order(self, customer_id: str, items: List[Dict], total: float):
        """주문 생성 커맨드"""
        event = OrderCreated(
            event_id=f"evt-{self.order_id}-1",
            aggregate_id=self.order_id,
            customer_id=customer_id,
            items=items,
            total_amount=total,
            version=self.version + 1
        )
        self._apply(event)
        self.changes.append(event)

    def pay_order(self, method: str, transaction_id: str):
        """결제 커맨드"""
        if self.status != OrderStatus.CREATED:
            raise ValueError("Order must be in CREATED status to pay")

        event = OrderPaid(
            event_id=f"evt-{self.order_id}-2",
            aggregate_id=self.order_id,
            payment_method=method,
            transaction_id=transaction_id,
            version=self.version + 1
        )
        self._apply(event)
        self.changes.append(event)

    def ship_order(self, carrier: str, tracking: str):
        """배송 커맨드"""
        if self.status != OrderStatus.PAID:
            raise ValueError("Order must be PAID to ship")

        event = OrderShipped(
            event_id=f"evt-{self.order_id}-3",
            aggregate_id=self.order_id,
            carrier=carrier,
            tracking_number=tracking,
            version=self.version + 1
        )
        self._apply(event)
        self.changes.append(event)

    def _apply(self, event: Event):
        """이벤트 적용 (상태 변경)"""
        if isinstance(event, OrderCreated):
            self.customer_id = event.customer_id
            self.items = event.items
            self.total_amount = event.total_amount
            self.status = OrderStatus.CREATED

        elif isinstance(event, OrderPaid):
            self.payment_method = event.payment_method
            self.status = OrderStatus.PAID

        elif isinstance(event, OrderShipped):
            self.tracking_number = event.tracking_number
            self.status = OrderStatus.SHIPPED

        self.version = event.version

    @classmethod
    def from_events(cls, events: List[Event]) -> 'Order':
        """이벤트로부터 Aggregate 재구성"""
        if not events:
            raise ValueError("No events to replay")

        order = cls(events[0].aggregate_id)
        for event in events:
            order._apply(event)
        return order

# Event Store
class EventStore:
    def __init__(self):
        self.events: Dict[str, List[Event]] = {}

    def save_events(self, aggregate_id: str, events: List[Event], expected_version: int):
        """이벤트 저장 (Optimistic Concurrency)"""
        if aggregate_id not in self.events:
            self.events[aggregate_id] = []

        current_version = len(self.events[aggregate_id])
        if current_version != expected_version:
            raise ValueError(f"Concurrency conflict: expected {expected_version}, got {current_version}")

        self.events[aggregate_id].extend(events)

    def get_events(self, aggregate_id: str) -> List[Event]:
        """이벤트 조회"""
        return self.events.get(aggregate_id, [])

# 사용 예제
if __name__ == "__main__":
    store = EventStore()

    # 주문 생성
    order = Order("order-123")
    order.create_order(
        customer_id="cust-456",
        items=[{"product": "Laptop", "price": 1000}],
        total=1000.0
    )

    # 결제
    order.pay_order(method="CreditCard", transaction_id="txn-789")

    # 배송
    order.ship_order(carrier="DHL", tracking="DHL-123456")

    # 이벤트 저장
    store.save_events(order.order_id, order.changes, 0)

    print(f"Saved {len(order.changes)} events")

    # 이벤트 재생으로 주문 복원
    events = store.get_events("order-123")
    restored_order = Order.from_events(events)

    print(f"Restored Order: {restored_order.order_id}")
    print(f"Status: {restored_order.status}")
    print(f"Amount: ${restored_order.total_amount}")
    print(f"Tracking: {restored_order.tracking_number}")
```

**Event Store 선택 (2025):**

- **EventStoreDB**: 전용 Event Sourcing DB, 고성능, Projections 지원
- **PostgreSQL + JSON**: 범용 DB, 단순한 구현
- **Kafka**: 스트리밍 플랫폼, 대규모 이벤트
- **DynamoDB**: 서버리스, AWS 환경

### 1-3. CQRS 패턴

**CQRS (Command Query Responsibility Segregation):**

읽기(Query)와 쓰기(Command) 모델을 분리하는 패턴입니다.

**전통적인 모델 vs CQRS:**

```
전통적인 모델 (단일 모델):
┌─────────────────────────────────┐
│         Application             │
│  ┌───────────────────────────┐  │
│  │   Domain Model            │  │
│  │  (Read & Write)           │  │
│  └───────────┬───────────────┘  │
└──────────────┼──────────────────┘
               │
        ┌──────▼──────┐
        │  Database   │
        └─────────────┘

문제점:
- 읽기/쓰기 요구사항 충돌
- 복잡한 조인 쿼리
- 확장성 제한


CQRS 모델 (분리):
┌─────────────────────────────────────────────────────┐
│              Application                            │
│  ┌─────────────────┐      ┌─────────────────────┐  │
│  │ Command Model   │      │   Query Model       │  │
│  │ (Write)         │      │   (Read)            │  │
│  │ - Validates     │      │ - Denormalized      │  │
│  │ - Business Rules│      │ - Optimized Views   │  │
│  └────────┬────────┘      └─────────┬───────────┘  │
└───────────┼─────────────────────────┼───────────────┘
            │                         │
     ┌──────▼─────┐           ┌───────▼────────┐
     │  Write DB  │           │   Read DB      │
     │ (Postgres) │ ─Events─→ │ (MongoDB/ES)   │
     └────────────┘           └────────────────┘

장점:
✓ 독립적 최적화
✓ 읽기 확장성 (Read Replicas)
✓ 단순한 쿼리 모델
✓ Polyglot Persistence
```

**CQRS 구현 예제:**

```python
# cqrs_example.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List, Optional
import json

# Commands (쓰기)
@dataclass
class Command(ABC):
    pass

@dataclass
class CreateOrderCommand(Command):
    order_id: str
    customer_id: str
    items: List[dict]
    total: float

@dataclass
class UpdateOrderStatusCommand(Command):
    order_id: str
    status: str

# Events
@dataclass
class OrderCreatedEvent:
    order_id: str
    customer_id: str
    items: List[dict]
    total: float

# Command Handler (Write Model)
class OrderCommandHandler:
    def __init__(self, write_repo, event_bus):
        self.write_repo = write_repo
        self.event_bus = event_bus

    def handle_create_order(self, cmd: CreateOrderCommand):
        """주문 생성 처리"""
        # 비즈니스 규칙 검증
        if cmd.total <= 0:
            raise ValueError("Total must be positive")

        # Write DB에 저장 (정규화된 형태)
        order_data = {
            "order_id": cmd.order_id,
            "customer_id": cmd.customer_id,
            "items": cmd.items,
            "total": cmd.total,
            "status": "created"
        }
        self.write_repo.save(order_data)

        # 이벤트 발행
        event = OrderCreatedEvent(
            order_id=cmd.order_id,
            customer_id=cmd.customer_id,
            items=cmd.items,
            total=cmd.total
        )
        self.event_bus.publish(event)

# Query (읽기)
@dataclass
class OrderSummaryQuery:
    customer_id: str

@dataclass
class OrderDetailsQuery:
    order_id: str

# Read Model (비정규화)
@dataclass
class OrderSummaryViewModel:
    customer_id: str
    total_orders: int
    total_spent: float
    recent_orders: List[dict]

# Query Handler (Read Model)
class OrderQueryHandler:
    def __init__(self, read_repo):
        self.read_repo = read_repo  # MongoDB, Elasticsearch 등

    def handle_order_summary(self, query: OrderSummaryQuery) -> OrderSummaryViewModel:
        """고객 주문 요약 조회 (비정규화된 뷰)"""
        summary = self.read_repo.get_customer_summary(query.customer_id)
        return summary

    def handle_order_details(self, query: OrderDetailsQuery) -> dict:
        """주문 상세 조회"""
        return self.read_repo.get_order_details(query.order_id)

# Event Handler (Write → Read 동기화)
class OrderEventHandler:
    def __init__(self, read_repo):
        self.read_repo = read_repo

    def on_order_created(self, event: OrderCreatedEvent):
        """OrderCreated 이벤트 처리 → Read Model 업데이트"""
        # Read DB에 비정규화된 뷰 생성
        order_view = {
            "order_id": event.order_id,
            "customer_id": event.customer_id,
            "total": event.total,
            "items_count": len(event.items),
            "status": "created"
        }
        self.read_repo.upsert_order_view(order_view)

        # 고객 요약 업데이트
        self.read_repo.increment_customer_total(
            customer_id=event.customer_id,
            amount=event.total
        )

# Simple Event Bus (in-memory)
class InMemoryEventBus:
    def __init__(self):
        self.handlers = []

    def subscribe(self, handler):
        self.handlers.append(handler)

    def publish(self, event):
        for handler in self.handlers:
            if isinstance(event, OrderCreatedEvent):
                handler.on_order_created(event)
```

**CQRS 사용 시기 (2025 Best Practices):**

```
✅ CQRS 사용 권장:
- 읽기/쓰기 비율 불균형 (Read-heavy)
- 복잡한 도메인 로직
- 다양한 뷰 필요 (여러 UI)
- 높은 확장성 요구
- Event Sourcing과 함께 사용

❌ CQRS 사용 피해야:
- 단순한 CRUD 애플리케이션
- 작은 규모 프로젝트
- Eventual Consistency 허용 불가
- 팀의 낮은 숙련도
```

---

## Part 2: Message Brokers

### 2-1. RabbitMQ vs Kafka (2025)

**아키텍처 비교:**

```
RabbitMQ (Smart Broker / Dumb Consumer):
┌─────────────────────────────────────┐
│         RabbitMQ Broker             │
│  ┌───────────────────────────────┐  │
│  │  Exchange (Topic/Direct/...)  │  │
│  │  - Routing Logic              │  │
│  │  - 메시지 필터링               │  │
│  └────────────┬──────────────────┘  │
│               │                     │
│  ┌────────────▼──────────────────┐  │
│  │  Queues (Per Consumer)        │  │
│  │  - 메시지 버퍼링               │  │
│  │  - 우선순위                    │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        │        │        │
   Consumer1 Consumer2 Consumer3
   (Pull)     (Pull)     (Pull)

특징:
- Push 모델 (Broker → Consumer)
- 복잡한 라우팅 (Exchange Types)
- Per-Consumer 큐
- 메시지 ACK/NACK


Kafka (Dumb Broker / Smart Consumer):
┌─────────────────────────────────────┐
│         Kafka Cluster               │
│  ┌───────────────────────────────┐  │
│  │  Topic: orders                │  │
│  │  ┌─────────┬─────────┬──────┐ │  │
│  │  │Partition│Partition│Partn │ │  │
│  │  │    0    │    1    │  2   │ │  │
│  │  └─────────┴─────────┴──────┘ │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        │        │        │
   Consumer1 Consumer2 Consumer3
   (Poll)     (Poll)     (Poll)
  (Offset    (Offset    (Offset
   관리)       관리)       관리)

특징:
- Pull 모델 (Consumer → Broker)
- 단순 라우팅 (Topic/Partition)
- Shared Log (모든 Consumer가 동일 로그)
- Consumer가 Offset 관리
```

**성능 비교 (2025 벤치마크):**

```
처리량 (Throughput):
┌───────────┬─────────────────┬──────────────┐
│  Broker   │ Messages/Second │ Data Rate    │
├───────────┼─────────────────┼──────────────┤
│ Kafka     │  1,000,000+     │  100 MB/s+   │⭐⭐⭐⭐⭐
│ RabbitMQ  │  4,000-10,000   │  1-5 MB/s    │⭐⭐
└───────────┴─────────────────┴──────────────┘

지연시간 (Latency):
┌───────────┬──────────────┬────────────────┐
│  Broker   │ Small Scale  │ Large Scale    │
├───────────┼──────────────┼────────────────┤
│ RabbitMQ  │  < 5 ms      │  증가          │⭐⭐⭐⭐⭐
│ Kafka     │  < 10 ms     │  일정 유지      │⭐⭐⭐⭐
└───────────┴──────────────┴────────────────┘

확장성:
Kafka ⭐⭐⭐⭐⭐ (Horizontal Scaling)
RabbitMQ ⭐⭐⭐ (Clustering)

메시지 보장:
Kafka ⭐⭐⭐⭐⭐ (At-least-once, Exactly-once)
RabbitMQ ⭐⭐⭐⭐ (At-least-once)

복잡한 라우팅:
RabbitMQ ⭐⭐⭐⭐⭐ (Exchange Types)
Kafka ⭐⭐ (Topic만)

운영 복잡도:
RabbitMQ ⭐⭐⭐ (상대적으로 단순)
Kafka ⭐⭐⭐⭐⭐ (ZooKeeper/KRaft, 복잡)
```

**선택 가이드:**

| 시나리오 | 추천 |
|---------|------|
| **대용량 스트리밍** | Kafka ⭐ |
| **실시간 분석** | Kafka ⭐ |
| **Event Sourcing** | Kafka ⭐ |
| **낮은 지연시간** | RabbitMQ ⭐ |
| **복잡한 라우팅** | RabbitMQ ⭐ |
| **작은 메시지** | RabbitMQ ⭐ |
| **Task Queue** | RabbitMQ ⭐ |
| **Microservices** | 둘 다 가능 |

### 2-2. RabbitMQ 설치 및 사용

**Docker로 설치:**

```bash
docker run -d \
  --name rabbitmq \
  -p 5672:5672 \
  -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=admin \
  -e RABBITMQ_DEFAULT_PASS=secret \
  rabbitmq:3-management

# Management UI: http://localhost:15672
```

**Producer 예제 (Python):**

```python
# rabbitmq_producer.py
import pika
import json

# 연결
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost')
)
channel = connection.channel()

# Exchange 선언 (Topic)
channel.exchange_declare(
    exchange='orders',
    exchange_type='topic',
    durable=True
)

# 메시지 발행
def publish_order_created(order_id, customer_id, total):
    message = {
        "order_id": order_id,
        "customer_id": customer_id,
        "total": total
    }

    channel.basic_publish(
        exchange='orders',
        routing_key='order.created',
        body=json.dumps(message),
        properties=pika.BasicProperties(
            delivery_mode=2,  # Persistent
            content_type='application/json'
        )
    )
    print(f"Published: order.created {order_id}")

# 테스트
publish_order_created("order-123", "cust-456", 100.0)

connection.close()
```

**Consumer 예제:**

```python
# rabbitmq_consumer.py
import pika
import json

connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost')
)
channel = connection.channel()

# Exchange 선언
channel.exchange_declare(
    exchange='orders',
    exchange_type='topic',
    durable=True
)

# Queue 선언
channel.queue_declare(queue='email_notifications', durable=True)

# Binding (Routing Key 패턴)
channel.queue_bind(
    exchange='orders',
    queue='email_notifications',
    routing_key='order.*'  # order.created, order.paid 등 모두 매칭
)

# 메시지 처리
def callback(ch, method, properties, body):
    message = json.loads(body)
    print(f"Received: {method.routing_key} - {message}")

    # 이메일 전송 로직
    send_email(message)

    # ACK
    ch.basic_ack(delivery_tag=method.delivery_tag)

# Consumer 시작
channel.basic_qos(prefetch_count=1)  # Fair Dispatch
channel.basic_consume(
    queue='email_notifications',
    on_message_callback=callback
)

print('Waiting for messages. To exit press CTRL+C')
channel.start_consuming()
```

### 2-3. Kafka 설치 및 사용

**Docker Compose로 설치 (KRaft 모드, 2025 권장):**

```yaml
# docker-compose.yml
version: '3'
services:
  kafka:
    image: apache/kafka:latest
    container_name: kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_LOG_DIRS: /tmp/kraft-combined-logs
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
```

```bash
docker-compose up -d
```

**Producer 예제 (Python):**

```python
# kafka_producer.py
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    acks='all',  # 모든 replica 확인
    retries=3
)

# 메시지 전송
def publish_order_created(order_id, customer_id, total):
    message = {
        "order_id": order_id,
        "customer_id": customer_id,
        "total": total
    }

    future = producer.send(
        'orders',
        key=order_id.encode('utf-8'),  # Partition Key
        value=message
    )

    # 동기 대기 (선택적)
    record_metadata = future.get(timeout=10)
    print(f"Published to partition {record_metadata.partition} offset {record_metadata.offset}")

# 테스트
publish_order_created("order-123", "cust-456", 100.0)

producer.flush()
producer.close()
```

**Consumer 예제:**

```python
# kafka_consumer.py
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'orders',
    bootstrap_servers=['localhost:9092'],
    group_id='email-service',
    auto_offset_reset='earliest',
    enable_auto_commit=False,  # 수동 커밋
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)

# 메시지 소비
for message in consumer:
    order = message.value
    print(f"Received: partition={message.partition} offset={message.offset}")
    print(f"Order: {order}")

    # 이메일 전송
    send_email(order)

    # 수동 커밋
    consumer.commit()
```

---

## 🛠️ 실습 가이드

### 실습: Event Sourcing + CQRS + Kafka

**목표**: 완전한 이벤트 기반 시스템 구축

```bash
# Kafka 시작 (위 Docker Compose 사용)
docker-compose up -d

# Topic 생성
docker exec -it kafka kafka-topics.sh \
  --create \
  --topic order-events \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```

**전체 시스템 구현 (event_driven_system.py):**

```python
# event_driven_system.py (전체 통합 예제는 너무 길어서 개념만)

# 1. Command Service (Write)
#    - API로 Command 수신
#    - Event 생성 및 Kafka 발행
#    - Write DB 저장

# 2. Event Processor (Read Model Builder)
#    - Kafka에서 Event 구독
#    - Read Model 업데이트 (MongoDB)
#    - 비정규화된 뷰 생성

# 3. Query Service (Read)
#    - Read Model에서 조회
#    - 빠른 쿼리 응답

# 4. Notification Service
#    - Kafka에서 Event 구독
#    - 이메일/Push 알림 전송
```

---

## 📚 참고 자료

**Event Sourcing & CQRS:**

- [Event Sourcing Pattern (Microservices.io)](https://microservices.io/patterns/data/event-sourcing.html)
- [CQRS Pattern (Microsoft Azure)](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [CQRS and Event Sourcing - When to Use (Useful Functions, Nov 2025)](https://www.usefulfunctions.co.uk/2025/11/06/cqrs-and-event-sourcing-when-to-use/)

**Message Brokers:**

- [Kafka vs RabbitMQ Complete Guide 2025 (DevZery)](https://www.devzery.com/post/kafka-vs-rabbitmq-complete-guide)
- [Kafka vs RabbitMQ Comparison 2025 (ProjectPro)](https://www.projectpro.io/article/kafka-vs-rabbitmq/451)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)

---

## ✅ 학습 체크리스트

- [ ] Event-Driven Architecture 이해
- [ ] Event Sourcing 패턴 구현 경험
- [ ] CQRS 패턴 적용 시기 판단
- [ ] RabbitMQ vs Kafka 선택 능력
- [ ] Kafka Producer/Consumer 구현
- [ ] Eventual Consistency 처리
- [ ] 이벤트 기반 시스템 설계 능력

---

## 🎓 다음 단계

**Ch7. Cloud Native 네트워킹** - Kubernetes Services, Ingress, Network Policies

Event-Driven Architecture는 현대 분산 시스템의 핵심입니다. 계속해서 학습하고 실습하면서 확장 가능하고 탄력적인 시스템을 설계하는 전문가로 성장하세요!
