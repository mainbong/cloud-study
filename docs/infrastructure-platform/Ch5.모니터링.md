# Ch5. 클라우드 인프라 모니터링

## 📋 개요

클라우드 인프라의 안정적인 운영을 위해서는 종합적인 모니터링 시스템이 필수적입니다. 본 장에서는 Prometheus와 Grafana를 중심으로 한 메트릭 수집, Loki를 활용한 로그 관리, OpenTelemetry를 통한 분산 트레이싱까지 통합 Observability 플랫폼을 구축하는 방법을 학습합니다.

2025년 현재, Observability는 더 이상 선택이 아닌 필수입니다. 70% 이상의 기업이 Prometheus와 OpenTelemetry를 함께 사용하며, 통합 텔레메트리 파이프라인을 구축하고 있습니다.

## 🎯 학습 목표

1. **Prometheus 메트릭 수집 시스템 이해 및 구축**
   - Prometheus 아키텍처 및 데이터 모델 이해
   - kube-prometheus-stack을 활용한 Kubernetes 모니터링
   - PromQL을 사용한 고급 쿼리 작성

2. **Grafana 시각화 및 알러팅 구성**
   - 효과적인 대시보드 설계 (3-3-3 Rule)
   - AlertManager를 통한 알러트 관리
   - Runbook 자동화 및 incident response 통합

3. **로그 관리 시스템 구축**
   - Grafana Loki를 활용한 경량 로그 수집
   - LogQL을 통한 로그 분석
   - Promtail을 사용한 로그 수집 파이프라인

4. **분산 트레이싱 구현**
   - OpenTelemetry를 활용한 표준화된 트레이싱
   - Context propagation 및 span 관리
   - Jaeger/Tempo를 활용한 trace 분석

5. **통합 Observability 플랫폼 운영**
   - Metrics, Logs, Traces 통합 분석
   - Storage 및 retention 정책 수립
   - 보안 및 백업 전략

---

## Part 1: Prometheus - 메트릭 수집의 표준

### 1.1 Prometheus 아키텍처

Prometheus는 CNCF 졸업 프로젝트로, 시계열 데이터베이스 기반의 모니터링 시스템입니다.

**핵심 컴포넌트:**

- **Prometheus Server**: 메트릭 수집 및 저장 (TSDB)
- **Exporters**: 다양한 시스템의 메트릭을 Prometheus 형식으로 변환
- **Pushgateway**: 단기 작업의 메트릭 수집
- **AlertManager**: 알러트 라우팅 및 알림 발송

**데이터 모델:**
```
<metric_name>{<label_name>=<label_value>, ...} <value> <timestamp>

예시:
http_requests_total{method="GET", endpoint="/api/users", status="200"} 1027 1732435200
```

### 1.2 Kubernetes 모니터링 - kube-prometheus-stack

2025년 기준, kube-prometheus-stack Helm 차트가 Kubernetes 모니터링의 de facto standard입니다.

**설치:**
```bash
# Helm 레포지토리 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# kube-prometheus-stack 설치
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=100Gi \
  --set grafana.adminPassword=admin123
```

**포함 컴포넌트:**

- Prometheus Operator
- Prometheus Server
- Grafana
- AlertManager
- Node Exporter
- kube-state-metrics
- 다양한 ServiceMonitor 및 PrometheusRule

### 1.3 레이블 설계 Best Practices (2025)

**좋은 레이블 설계:**
```yaml
# ✅ GOOD: 간결하고 의미 있는 레이블
http_requests_total{
  env="prod",              # environment_production (X)
  svc="api",               # service_name (X)
  method="GET",
  status="200"
}

# ❌ BAD: 카디널리티가 높은 레이블 (user_id, timestamp 등)
http_requests_total{
  user_id="12345",         # 수백만 개의 고유 값 생성
  timestamp="1732435200"   # 매 요청마다 새로운 시계열 생성
}
```

**스토리지 효율화:**

- 레이블은 간결하게 (3-5자)
- 카디널리티가 높은 값은 레이블로 사용 금지
- 환경별 retention 정책 분리

---

## Part 2: PromQL - 강력한 쿼리 언어

### 2.1 PromQL 기본

**기본 쿼리:**
```promql
# 특정 메트릭 조회
http_requests_total

# 레이블 필터링
http_requests_total{method="GET", status="200"}

# 정규표현식 사용
http_requests_total{endpoint=~"/api/.*"}

# 레이블 값 제외
http_requests_total{status!="500"}
```

**Range Vector 및 함수:**
```promql
# 최근 5분간 초당 요청률 (Rate)
rate(http_requests_total[5m])

# 5분간 평균 증가량
increase(http_requests_total[5m])

# 순간 벡터의 합계
sum(rate(http_requests_total[5m]))

# 레이블별 그룹화
sum by (status) (rate(http_requests_total[5m]))
```

### 2.2 실전 PromQL 쿼리

**CPU 사용률 계산:**
```promql
# 컨테이너 CPU 사용률 (%)
100 * (
  sum by (pod, namespace) (rate(container_cpu_usage_seconds_total[5m]))
  /
  sum by (pod, namespace) (container_spec_cpu_quota / container_spec_cpu_period)
)

# Node CPU 사용률
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**메모리 사용률:**
```promql
# 컨테이너 메모리 사용률
100 * (
  container_memory_working_set_bytes
  /
  container_spec_memory_limit_bytes
)

# Node 메모리 사용률
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
```

**디스크 사용량 예측:**
```promql
# 현재 추세로 디스크가 가득 찰 시간 (시간 단위)
predict_linear(node_filesystem_avail_bytes{mountpoint="/"}[1h], 4*3600) < 0
```

**HTTP 에러율:**
```promql
# 5분간 5xx 에러율 (%)
100 * (
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
)
```

### 2.3 Four Golden Signals 모니터링

**1. Latency (지연시간):**
```promql
# P95 레이턴시
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

**2. Traffic (트래픽):**
```promql
# 초당 요청 수
sum(rate(http_requests_total[5m]))
```

**3. Errors (에러):**
```promql
# 에러율
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

**4. Saturation (포화도):**
```promql
# CPU 포화도
avg(node_load5) / count(node_cpu_seconds_total{mode="idle"})
```

---

## Part 3: Grafana - 시각화 및 알러팅

### 3.1 Grafana 대시보드 설계 - 3-3-3 Rule (2025)

2025년 best practice로 자리잡은 **3-3-3 Rule**:
- **3 rows** of panels
- **3 panels** per row
- **3 key metrics** per panel

**대시보드 구성 예시:**
```
Row 1: Overview
├── Panel 1: Total Requests (current, trend)
├── Panel 2: Error Rate (current, threshold)
└── Panel 3: Avg Response Time (P50, P95, P99)

Row 2: Resource Usage
├── Panel 1: CPU Usage (by pod)
├── Panel 2: Memory Usage (by pod)
└── Panel 3: Network I/O (ingress/egress)

Row 3: Application Metrics
├── Panel 1: Active Connections
├── Panel 2: Database Query Time
└── Panel 3: Cache Hit Rate
```

### 3.2 대시보드 as Code

**Grafana Dashboard JSON:**
```json
{
  "dashboard": {
    "title": "Kubernetes Cluster Overview",
    "tags": ["kubernetes", "infrastructure"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      }
    ]
  }
}
```

**Terraform으로 대시보드 배포:**
```hcl
resource "grafana_dashboard" "kubernetes_overview" {
  config_json = file("${path.module}/dashboards/k8s-overview.json")

  folder = grafana_folder.infrastructure.id
}

resource "grafana_folder" "infrastructure" {
  title = "Infrastructure"
}
```

### 3.3 AlertManager 설정

**PrometheusRule CRD:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-alerts
  namespace: monitoring
spec:
  groups:
    - name: kubernetes.rules
      interval: 30s
      rules:
        - alert: PodCrashLooping
          expr: |
            rate(kube_pod_container_status_restarts_total[15m]) > 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
            description: "Pod has restarted {{ $value }} times in the last 15 minutes"
            runbook_url: "https://runbooks.example.com/pod-crash-loop"

        - alert: HighMemoryUsage
          expr: |
            100 * (container_memory_working_set_bytes / container_spec_memory_limit_bytes) > 90
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Container memory usage is above 90%"
            description: "Container {{ $labels.pod }}/{{ $labels.container }} memory usage is {{ $value }}%"
            runbook_url: "https://runbooks.example.com/high-memory"

        - alert: DiskSpaceLow
          expr: |
            100 * (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) < 10
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Disk space is below 10%"
            description: "Node {{ $labels.instance }} has only {{ $value }}% disk space remaining"
```

**AlertManager 라우팅:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'https://hooks.slack.com/services/xxx'

    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
      routes:
        - match:
            severity: critical
          receiver: 'pagerduty'
          continue: true

        - match:
            severity: warning
          receiver: 'slack'

    receivers:
      - name: 'default'
        slack_configs:
          - channel: '#alerts'
            title: '{{ .GroupLabels.alertname }}'
            text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

      - name: 'pagerduty'
        pagerduty_configs:
          - service_key: 'YOUR_PAGERDUTY_KEY'

      - name: 'slack'
        slack_configs:
          - channel: '#warnings'
```

---

## Part 4: Grafana Loki - 로그 관리

### 4.1 Loki 아키텍처

Grafana Loki는 "Prometheus for logs"로 설계된 경량 로그 집계 시스템입니다.

**Loki vs ELK Stack (2025):**
| 특징 | Loki | ELK Stack |
|------|------|-----------|
| 인덱싱 | 레이블만 인덱싱 | 전체 로그 인덱싱 |
| 스토리지 | 낮음 (50% 절약) | 높음 |
| 쿼리 속도 | 빠름 (레이블 기반) | 매우 빠름 (전문 검색) |
| 설정 복잡도 | 낮음 | 높음 |
| Grafana 통합 | 네이티브 | 플러그인 필요 |

**Loki 설치:**
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=100Gi
```

### 4.2 Promtail 설정

**Promtail ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      # Kubernetes pod logs
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod

        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: node
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container

        pipeline_stages:
          # JSON 로그 파싱
          - json:
              expressions:
                level: level
                msg: message
                timestamp: time

          # 타임스탬프 파싱
          - timestamp:
              source: timestamp
              format: RFC3339

          # 레이블 추출
          - labels:
              level:
```

### 4.3 LogQL 쿼리

**기본 쿼리:**
```logql
# 특정 namespace의 로그
{namespace="production"}

# 여러 조건
{namespace="production", container="api"}

# 정규표현식
{pod=~"api-.*"}

# 로그 내용 필터링
{namespace="production"} |= "error"

# 정규표현식 필터
{namespace="production"} |~ "error|ERROR|Error"
```

**고급 쿼리:**
```logql
# JSON 필드 추출 및 필터링
{namespace="production"}
  | json
  | level="error"
  | line_format "{{.timestamp}} {{.message}}"

# 메트릭 생성 - 초당 에러 로그 수
sum(rate({namespace="production"} |= "error" [5m])) by (pod)

# Quantile 계산
quantile_over_time(0.99,
  {namespace="production"}
    | json
    | unwrap duration [5m]
) by (endpoint)
```

**통합 쿼리 (Metrics + Logs):**
```logql
# Grafana에서 메트릭과 로그 함께 보기
# Panel 1: Error rate (Prometheus)
sum(rate(http_requests_total{status="500"}[5m]))

# Panel 2: Error logs (Loki)
{namespace="production", status="500"} | json
```

---

## Part 5: OpenTelemetry - 분산 트레이싱

### 5.1 OpenTelemetry 아키텍처

OpenTelemetry는 2025년 현재 Observability의 표준으로 자리잡았습니다. CNCF의 두 번째로 활발한 프로젝트입니다.

**핵심 컴포넌트:**

- **SDK**: 애플리케이션 계측 (12+ 언어 지원)
- **Collector**: 텔레메트리 데이터 수집/처리/전송
- **Exporter**: 다양한 백엔드로 데이터 전송

**데이터 타입:**

- **Traces**: 분산 트랜잭션 추적
- **Metrics**: 시계열 데이터 (Prometheus 호환)
- **Logs**: 구조화된 로그

### 5.2 OpenTelemetry Collector 배포

**Kubernetes DaemonSet:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.91.0
          ports:
            - containerPort: 4317  # OTLP gRPC
            - containerPort: 4318  # OTLP HTTP
            - containerPort: 8888  # Prometheus metrics
          volumeMounts:
            - name: config
              mountPath: /etc/otel-collector-config.yaml
              subPath: otel-collector-config.yaml
      volumes:
        - name: config
          configMap:
            name: otel-collector-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: monitoring
data:
  otel-collector-config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      prometheus:
        config:
          scrape_configs:
            - job_name: 'otel-collector'
              scrape_interval: 10s
              static_configs:
                - targets: ['0.0.0.0:8888']

    processors:
      batch:
        timeout: 10s
        send_batch_size: 1024

      memory_limiter:
        check_interval: 1s
        limit_mib: 512

      # Sampling (10% of traces)
      probabilistic_sampler:
        sampling_percentage: 10

    exporters:
      prometheus:
        endpoint: "0.0.0.0:8889"

      jaeger:
        endpoint: jaeger-collector:14250
        tls:
          insecure: true

      loki:
        endpoint: http://loki:3100/loki/api/v1/push

      logging:
        loglevel: debug

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch, probabilistic_sampler]
          exporters: [jaeger, logging]

        metrics:
          receivers: [otlp, prometheus]
          processors: [memory_limiter, batch]
          exporters: [prometheus]

        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [loki]
```

### 5.3 애플리케이션 계측

**Python (FastAPI) 예제:**
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from fastapi import FastAPI

# Resource 정의
resource = Resource(attributes={
    "service.name": "api-service",
    "service.version": "1.0.0",
    "deployment.environment": "production"
})

# Tracer Provider 설정
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# OTLP Exporter 설정
otlp_exporter = OTLPSpanExporter(
    endpoint="http://otel-collector:4317",
    insecure=True
)

# Span Processor 추가
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

app = FastAPI()

# FastAPI 자동 계측
FastAPIInstrumentor.instrument_app(app)

@app.get("/users/{user_id}")
async def get_user(user_id: int):
    # Custom span 생성
    with tracer.start_as_current_span("fetch_user_from_db") as span:
        span.set_attribute("user.id", user_id)
        span.set_attribute("db.system", "postgresql")

        # DB 조회 로직
        user = await fetch_user_from_db(user_id)

        span.set_attribute("user.found", user is not None)

        if not user:
            span.set_status(Status(StatusCode.ERROR, "User not found"))

        return user

async def fetch_user_from_db(user_id: int):
    # Nested span
    with tracer.start_as_current_span("db_query") as span:
        span.set_attribute("db.statement", f"SELECT * FROM users WHERE id = {user_id}")
        # ... DB 쿼리 실행
        return {"id": user_id, "name": "John Doe"}
```

**Go 예제:**
```go
package main

import (
    "context"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
    "go.opentelemetry.io/otel/trace"
    "google.golang.org/grpc"
)

func initTracer() (*sdktrace.TracerProvider, error) {
    ctx := context.Background()

    // OTLP exporter
    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint("otel-collector:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        return nil, err
    }

    // Resource
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceName("go-service"),
            semconv.ServiceVersion("1.0.0"),
        ),
    )
    if err != nil {
        return nil, err
    }

    // TracerProvider
    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.TraceIDRatioBased(0.1)), // 10% sampling
    )

    otel.SetTracerProvider(tp)
    return tp, nil
}

func processOrder(ctx context.Context, orderID string) error {
    tracer := otel.Tracer("order-processor")

    ctx, span := tracer.Start(ctx, "processOrder")
    defer span.End()

    span.SetAttributes(
        attribute.String("order.id", orderID),
    )

    // Nested span
    if err := validateOrder(ctx, orderID); err != nil {
        span.RecordError(err)
        return err
    }

    if err := chargePayment(ctx, orderID); err != nil {
        span.RecordError(err)
        return err
    }

    return nil
}

func validateOrder(ctx context.Context, orderID string) error {
    _, span := otel.Tracer("order-processor").Start(ctx, "validateOrder")
    defer span.End()

    // Validation logic
    return nil
}
```

### 5.4 Context Propagation

**HTTP Headers (W3C Trace Context):**
```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
tracestate: congo=t61rcWkgMzE,rojo=00f067aa0ba902b7
```

**분산 트레이싱 플로우:**
```
Client Request
    └─> API Gateway (Span 1)
        ├─> Auth Service (Span 2)
        │   └─> Database (Span 3)
        └─> Order Service (Span 4)
            ├─> Payment Service (Span 5)
            │   └─> External API (Span 6)
            └─> Inventory Service (Span 7)
                └─> Cache (Span 8)
```

---

## Part 6: 통합 Observability 전략

### 6.1 Layered Monitoring Architecture (2025 Best Practice)

```
┌─────────────────────────────────────────────────┐
│           Global Prometheus                      │
│  (Aggregated critical metrics across clusters)  │
└─────────────────────────────────────────────────┘
                      ▲
                      │
        ┌─────────────┴──────────────┐
        │                            │
┌───────────────────┐      ┌────────────────────┐
│ Cluster Prometheus│      │ Cluster Prometheus │
│   (Cluster A)     │      │   (Cluster B)      │
└───────────────────┘      └────────────────────┘
        ▲                            ▲
        │                            │
┌───────┴────────┐          ┌────────┴───────┐
│ App Prometheus │          │ App Prometheus │
│ (Business Logic)│         │ (Business Logic)│
└────────────────┘          └────────────────┘
```

### 6.2 Storage & Retention 전략

**Prometheus Retention:**
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# TSDB 설정
storage:
  tsdb:
    retention.time: 15d        # 15일 보관
    retention.size: 50GB       # 최대 50GB

    # Compaction 설정
    min-block-duration: 2h
    max-block-duration: 36h

# Remote Write (장기 저장)
remote_write:
  - url: "http://thanos-receive:19291/api/v1/receive"
    queue_config:
      capacity: 10000
      max_shards: 50
```

**Thanos를 활용한 장기 저장:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: thanos-store
spec:
  serviceName: thanos-store
  replicas: 1
  template:
    spec:
      containers:
        - name: thanos
          image: quay.io/thanos/thanos:v0.33.0
          args:
            - store
            - --data-dir=/var/thanos/store
            - --objstore.config-file=/etc/thanos/objstore.yml
          volumeMounts:
            - name: object-storage-config
              mountPath: /etc/thanos
      volumes:
        - name: object-storage-config
          secret:
            secretName: thanos-objstore-config
---
apiVersion: v1
kind: Secret
metadata:
  name: thanos-objstore-config
stringData:
  objstore.yml: |
    type: S3
    config:
      bucket: "thanos-metrics"
      endpoint: "s3.amazonaws.com"
      access_key: "XXX"
      secret_key: "YYY"
```

### 6.3 보안 설정

**Prometheus TLS 및 인증:**
```yaml
# prometheus-additional-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: prometheus-additional-config
  namespace: monitoring
stringData:
  prometheus-additional.yaml: |
    # Basic Auth
    basic_auth_users:
      admin: $2y$10$...  # bcrypt hash

    # TLS 설정
    tls_server_config:
      cert_file: /etc/prometheus/tls/tls.crt
      key_file: /etc/prometheus/tls/tls.key
      client_ca_file: /etc/prometheus/tls/ca.crt
      client_auth_type: RequireAndVerifyClientCert
```

**Grafana OAuth 통합 (Keycloak):**
```ini
# grafana.ini
[auth.generic_oauth]
enabled = true
name = Keycloak
allow_sign_up = true
client_id = grafana
client_secret = YOUR_SECRET
scopes = openid profile email
auth_url = https://keycloak.example.com/auth/realms/master/protocol/openid-connect/auth
token_url = https://keycloak.example.com/auth/realms/master/protocol/openid-connect/token
api_url = https://keycloak.example.com/auth/realms/master/protocol/openid-connect/userinfo
role_attribute_path = contains(roles[*], 'admin') && 'Admin' || contains(roles[*], 'editor') && 'Editor' || 'Viewer'
```

---

## 🛠️ 실습 가이드

### 실습 1: kube-prometheus-stack 배포 및 커스터마이징

**목표:** Kubernetes 클러스터에 완전한 모니터링 스택 배포

**단계:**
```bash
# 1. Helm 차트 values 파일 준비
cat <<EOF > values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

    # 외부 레이블 추가
    externalLabels:
      cluster: prod-cluster-01
      region: ap-northeast-2

    # ServiceMonitor 자동 발견
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

grafana:
  adminPassword: "ChangeMe123!"
  persistence:
    enabled: true
    size: 10Gi

  # 플러그인 설치
  plugins:
    - grafana-piechart-panel
    - grafana-clock-panel

  # 데이터소스 자동 구성
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://kube-prometheus-prometheus:9090
          isDefault: true
        - name: Loki
          type: loki
          url: http://loki:3100

alertmanager:
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname']
      receiver: 'slack'
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'YOUR_SLACK_WEBHOOK'
            channel: '#alerts'
EOF

# 2. 설치
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -f values.yaml \
  --namespace monitoring \
  --create-namespace

# 3. Port-forward로 접속 확인
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# http://localhost:3000 (admin/ChangeMe123!)
```

### 실습 2: 커스텀 메트릭 수집 (ServiceMonitor)

**시나리오:** FastAPI 애플리케이션의 메트릭 수집

```python
# app.py
from fastapi import FastAPI
from prometheus_client import Counter, Histogram, generate_latest
from fastapi.responses import Response
import time

app = FastAPI()

# 메트릭 정의
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

@app.middleware("http")
async def metrics_middleware(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time

    http_requests_total.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()

    http_request_duration_seconds.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)

    return response

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type="text/plain")

@app.get("/api/users")
def get_users():
    return {"users": []}
```

**ServiceMonitor 생성:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fastapi-app
  namespace: default
  labels:
    app: fastapi
spec:
  selector:
    matchLabels:
      app: fastapi
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### 실습 3: Grafana Loki + Promtail 로그 수집

```bash
# Loki Stack 설치
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true

# Grafana에 Loki 데이터소스 추가 (이미 values에 있으면 skip)
# Grafana UI -> Configuration -> Data Sources -> Add Loki
# URL: http://loki:3100

# 로그 쿼리 테스트
# Grafana Explore에서:
{namespace="default"} |= "error" | json | line_format "{{.level}} {{.msg}}"
```

### 실습 4: OpenTelemetry로 마이크로서비스 트레이싱

**1. Jaeger 설치:**
```bash
kubectl create namespace observability
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/crds/jaegertracing.io_jaegers_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/role.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/role_binding.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/operator.yaml

# Jaeger 인스턴스 생성
cat <<EOF | kubectl apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: observability
spec:
  strategy: allInOne
  allInOne:
    image: jaegertracing/all-in-one:latest
    options:
      log-level: info
  storage:
    type: memory
  ingress:
    enabled: false
  ui:
    options:
      dependencies:
        menuEnabled: true
EOF
```

**2. OpenTelemetry Collector 배포:** (위의 Part 5.2 YAML 사용)

**3. 애플리케이션 배포:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traced-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: traced-app
  template:
    metadata:
      labels:
        app: traced-app
    spec:
      containers:
        - name: app
          image: your-traced-app:latest
          env:
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4317"
            - name: OTEL_SERVICE_NAME
              value: "traced-app"
            - name: OTEL_TRACES_SAMPLER
              value: "parentbased_traceidratio"
            - name: OTEL_TRACES_SAMPLER_ARG
              value: "0.1"
```

---

## 💻 예제 코드

### 예제 1: 종합 모니터링 대시보드 (Terraform)

```hcl
# grafana.tf
terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 2.0"
    }
  }
}

provider "grafana" {
  url  = "http://grafana.example.com"
  auth = var.grafana_api_key
}

# 폴더 생성
resource "grafana_folder" "kubernetes" {
  title = "Kubernetes"
}

# Prometheus 데이터소스
resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "Prometheus"
  url  = "http://prometheus:9090"

  json_data_encoded = jsonencode({
    httpMethod    = "POST"
    timeInterval  = "30s"
  })
}

# 대시보드
resource "grafana_dashboard" "cluster_overview" {
  folder      = grafana_folder.kubernetes.id
  config_json = file("${path.module}/dashboards/cluster-overview.json")
}

# Alert 룰
resource "grafana_rule_group" "kubernetes_alerts" {
  name             = "kubernetes-alerts"
  folder_uid       = grafana_folder.kubernetes.uid
  interval_seconds = 60

  rule {
    name      = "PodCrashLooping"
    condition = "C"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = grafana_data_source.prometheus.uid

      model = jsonencode({
        expr = "rate(kube_pod_container_status_restarts_total[15m]) > 0"
      })
    }

    data {
      ref_id = "C"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = "-100"

      model = jsonencode({
        conditions = [
          {
            evaluator = {
              params = [0]
              type   = "gt"
            }
            operator = {
              type = "and"
            }
            query = {
              params = ["A"]
            }
            type = "query"
          }
        ]
      })
    }

    no_data_state  = "NoData"
    exec_err_state = "Alerting"
    for            = "5m"

    annotations = {
      description = "Pod has restarted multiple times"
      runbook_url = "https://runbooks.example.com/pod-crash"
    }

    labels = {
      severity = "critical"
    }
  }
}
```

### 예제 2: 멀티클러스터 메트릭 수집 (Thanos)

```yaml
# thanos-sidecar.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prometheus
  namespace: monitoring
spec:
  serviceName: prometheus
  replicas: 2
  template:
    spec:
      containers:
        # Prometheus
        - name: prometheus
          image: prom/prometheus:v2.48.0
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --storage.tsdb.path=/prometheus
            - --storage.tsdb.min-block-duration=2h
            - --storage.tsdb.max-block-duration=2h
            - --web.enable-lifecycle
          volumeMounts:
            - name: storage
              mountPath: /prometheus

        # Thanos Sidecar
        - name: thanos-sidecar
          image: quay.io/thanos/thanos:v0.33.0
          args:
            - sidecar
            - --prometheus.url=http://localhost:9090
            - --tsdb.path=/prometheus
            - --objstore.config-file=/etc/thanos/objstore.yml
            - --grpc-address=0.0.0.0:10901
            - --http-address=0.0.0.0:10902
          volumeMounts:
            - name: storage
              mountPath: /prometheus
            - name: thanos-objstore
              mountPath: /etc/thanos
      volumes:
        - name: thanos-objstore
          secret:
            secretName: thanos-objstore-config
  volumeClaimTemplates:
    - metadata:
        name: storage
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 100Gi
---
# thanos-querier.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: thanos-querier
  namespace: monitoring
spec:
  replicas: 2
  selector:
    matchLabels:
      app: thanos-querier
  template:
    metadata:
      labels:
        app: thanos-querier
    spec:
      containers:
        - name: thanos
          image: quay.io/thanos/thanos:v0.33.0
          args:
            - query
            - --http-address=0.0.0.0:10902
            - --grpc-address=0.0.0.0:10901
            - --store=dnssrv+_grpc._tcp.prometheus-0.prometheus.monitoring.svc.cluster.local
            - --store=dnssrv+_grpc._tcp.prometheus-1.prometheus.monitoring.svc.cluster.local
            - --store=dnssrv+_grpc._tcp.thanos-store.monitoring.svc.cluster.local
```

### 예제 3: 통합 Observability with OpenTelemetry

```yaml
# otel-demo-app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
          http:

    processors:
      batch:

      # 메트릭에서 트레이스 생성
      spanmetrics:
        metrics_exporter: prometheus
        latency_histogram_buckets: [100us, 1ms, 2ms, 6ms, 10ms, 100ms, 250ms]
        dimensions:
          - name: http.method
          - name: http.status_code

      # 리소스 속성 추가
      resource:
        attributes:
          - key: environment
            value: production
            action: insert

    exporters:
      prometheus:
        endpoint: "0.0.0.0:8889"

      jaeger:
        endpoint: jaeger-collector:14250
        tls:
          insecure: true

      loki:
        endpoint: http://loki:3100/loki/api/v1/push
        labels:
          attributes:
            service.name: "service_name"
            level: "severity"

    connectors:
      spanmetrics:

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [jaeger, spanmetrics]

        metrics:
          receivers: [otlp, spanmetrics]
          processors: [batch]
          exporters: [prometheus]

        logs:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [loki]
```

---

## 📚 참고 자료

### 공식 문서
1. **Prometheus**
   - [Prometheus 공식 문서](https://prometheus.io/docs/)
   - [PromQL 가이드](https://prometheus.io/docs/prometheus/latest/querying/basics/)
   - [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

2. **Grafana**
   - [Grafana 공식 문서](https://grafana.com/docs/)
   - [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
   - [Grafana Loki](https://grafana.com/docs/loki/latest/)

3. **OpenTelemetry**
   - [OpenTelemetry 공식 사이트](https://opentelemetry.io/)
   - [Collector 문서](https://opentelemetry.io/docs/collector/)
   - [Instrumentation 가이드](https://opentelemetry.io/docs/instrumentation/)

4. **Thanos**
   - [Thanos 공식 문서](https://thanos.io/tip/thanos/quick-tutorial.md/)

### 2025 Best Practices 아티클
1. [Prometheus Monitoring: Complete Setup & Best Practices](https://www.glukhov.org/post/2025/11/monitoring-with-prometheus/)
2. [How SREs Use Prometheus and Grafana to Crush MTTR in 2025](https://rootly.com/sre/how-sres-use-prometheus-and-grafana-to-crush-mttr-in-2025)
3. [Backend Observability in 2025: Distributed Tracing with OpenTelemetry](https://medium.com/@shbhggrwl/backend-observability-in-2025-distributed-tracing-with-opentelemetry-af338a987abb)
4. [Kubernetes Monitoring in 2025: A Complete Guide](https://linuxcloudservers.com/kubernetes-monitoring/)

### 튜토리얼 및 예제
1. [Get started with Grafana and Prometheus](https://grafana.com/docs/grafana/latest/getting-started/get-started-grafana-prometheus/)
2. [OpenTelemetry Distributed Tracing Tutorial](https://www.withcoherence.com/articles/opentelemetry-distributed-tracing-tutorial-and-best-practices)
3. [Grafana Loki Log Aggregation](https://grafana.com/docs/loki/latest/get-started/)

### 커뮤니티 및 도구
1. **Awesome Prometheus**: https://github.com/roaldnefs/awesome-prometheus
2. **Grafana Dashboards**: https://grafana.com/grafana/dashboards/
3. **PromLens** (PromQL Query Builder): https://promlens.com/

---

## ✅ 학습 체크리스트

### 기본 개념
- [ ] Prometheus의 pull 기반 아키텍처 이해
- [ ] TSDB와 시계열 데이터 모델 이해
- [ ] 레이블과 카디널리티의 관계 이해
- [ ] Four Golden Signals 개념 숙지

### Prometheus & PromQL
- [ ] kube-prometheus-stack 배포 및 설정
- [ ] ServiceMonitor/PodMonitor로 커스텀 메트릭 수집
- [ ] PromQL 기본 쿼리 작성 (rate, sum, avg, quantile)
- [ ] Recording Rules와 Alerting Rules 작성
- [ ] Prometheus federation 또는 Thanos 구성

### Grafana
- [ ] 데이터소스 연결 (Prometheus, Loki)
- [ ] 3-3-3 Rule을 적용한 대시보드 설계
- [ ] 변수(Variables)를 활용한 동적 대시보드 작성
- [ ] AlertManager 통합 및 알림 채널 설정
- [ ] Dashboard as Code (Terraform/jsonnet)

### Logging (Loki)
- [ ] Loki + Promtail 설치 및 설정
- [ ] LogQL 쿼리 작성 (필터, 파싱, 메트릭 추출)
- [ ] Loki와 Prometheus 메트릭 상관관계 분석
- [ ] 로그 retention 정책 설정

### Distributed Tracing (OpenTelemetry)
- [ ] OpenTelemetry Collector 배포
- [ ] Python/Go 애플리케이션 계측 (auto & manual)
- [ ] Trace context propagation 이해
- [ ] Jaeger/Tempo에서 trace 분석
- [ ] Span metrics 활용

### 통합 및 운영
- [ ] Layered monitoring architecture 설계
- [ ] Storage 및 retention 전략 수립
- [ ] TLS 및 인증 설정
- [ ] Backup 및 disaster recovery 계획
- [ ] SLO/SLI 정의 및 모니터링

---

## 🎓 다음 단계

1. **[Ch6.Linux_OS_이미지.md](./Ch6.Linux_OS_이미지.md)**
   - OS 이미지 구조 및 커스터마이징
   - Packer를 활용한 이미지 빌드 파이프라인
   - 이미지 디버깅 및 최적화

2. **심화 주제**
   - **SLO/SLI/SLA Engineering**: Error Budget 기반 운영
   - **Chaos Engineering**: 모니터링 시스템의 복원력 테스트
   - **AIOps**: 머신러닝 기반 이상 탐지 및 예측

3. **실전 프로젝트**
   - 프로덕션 환경 Observability 플랫폼 구축
   - Multi-cluster/Multi-cloud 모니터링
   - FinOps를 위한 비용 모니터링 대시보드

---

**마지막 업데이트:** 2025-11-24
**다음 챕터:** [Ch6.Linux_OS_이미지.md](./Ch6.Linux_OS_이미지.md)
