# Chapter 7: Cloud Network CNI

## 📋 개요

본 Chapter에서는 Kubernetes의 네트워킹 플러그인 아키텍처인 CNI(Container Network Interface)를 학습합니다. CNI는 컨테이너의 네트워크 인터페이스를 구성하는 표준 스펙이며, Cilium, Calico, Flannel 등 다양한 구현체가 존재합니다.

2025년 현재, CNI는 단순한 네트워크 연결을 넘어 보안(NetworkPolicy), 관찰성(Observability), 성능 최적화의 핵심 컴포넌트로 발전했습니다. 특히 eBPF 기술을 활용한 Cilium은 커널 수준의 고성능 네트워킹을 제공하며, Service Mesh와의 통합으로 L7 트래픽 제어까지 가능해졌습니다.

### CNI의 역할

- **Pod 간 통신**: 클러스터 내 모든 Pod는 NAT 없이 직접 통신
- **Service 추상화**: ClusterIP, NodePort, LoadBalancer를 통한 서비스 디스커버리
- **네트워크 정책**: Pod 간 트래픽 제어 (방화벽 규칙)
- **외부 연결**: Ingress/Egress 트래픽 관리
- **멀티 클러스터 네트워킹**: 클러스터 간 통신 (ClusterMesh)

### 2025년 CNI 트렌드

- **eBPF 기반 네트워킹**: Cilium이 주도하는 커널 수준 패킷 처리
- **Kube-Proxy 대체**: eBPF 기반 효율적인 Service 로드밸런싱
- **Service Mesh 통합**: CNI(L4)와 Service Mesh(L7)의 시너지
- **Zero Trust 네트워킹**: 기본 mTLS 및 세밀한 NetworkPolicy
- **Cloud Provider CNI**: Azure CNI powered by Cilium, AWS VPC CNI 등

---

## 🎯 학습 목표

이 Chapter를 완료하면 다음을 할 수 있습니다:

1. **CNI 아키텍처** 이해
   - CNI 스펙 v1.0.0 표준
   - CNI 플러그인의 구성 요소 (Executable + Daemon)
   - kubelet과 CNI의 상호작용 흐름

2. **주요 CNI 플러그인** 비교 및 선택
   - Cilium: eBPF 기반 고성능 네트워킹
   - Calico: BGP 라우팅 및 강력한 보안 정책
   - Flannel: 단순하고 가벼운 Overlay 네트워크

3. **NetworkPolicy** 설계 및 구현
   - Kubernetes NetworkPolicy 리소스
   - Calico GlobalNetworkPolicy (클러스터 수준)
   - Zero Trust 네트워킹 패턴

4. **Service Mesh 통합**
   - Istio vs Linkerd 비교 (2025 벤치마크)
   - CNI와 Service Mesh의 역할 분담
   - Ambient Mesh (Sidecar-less) 아키텍처

---

## Part 1: CNI 아키텍처 및 스펙

### 1.1 CNI 개요

CNI(Container Network Interface)는 CNCF 프로젝트로, Linux 및 Windows 컨테이너의 네트워크 인터페이스를 구성하기 위한 스펙과 라이브러리를 제공합니다.

#### CNI 스펙 버전

| 버전 | 출시 | 주요 특징 |
|------|------|-----------|
| v0.4.0 | 2018 | 멀티 네트워크 지원 |
| v1.0.0 | 2021 | 안정화된 API, 하위 호환성 보장 |
| v1.1.0 | 2023 | Status 필드 추가, 에러 처리 개선 |

**2025 권장**: v1.0.0 이상 호환 CNI 플러그인 사용

### 1.2 CNI 플러그인 구조

CNI 플러그인은 두 가지 주요 컴포넌트로 구성됩니다:

```
┌─────────────────────────────────────────┐
│           Kubernetes Node               │
│                                         │
│  ┌──────────┐         ┌──────────────┐ │
│  │ kubelet  │ ──────> │ CNI Plugin   │ │
│  │          │  invoke │ (Executable) │ │
│  └──────────┘         └──────────────┘ │
│       │                      │          │
│       │                      │          │
│       v                      v          │
│  ┌──────────────────────────────────┐  │
│  │   Pod Network Namespace          │  │
│  │   (veth pair, IP, routes)        │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  CNI Daemon (DaemonSet)          │  │
│  │  - Cross-node routing            │  │
│  │  - IPAM (IP Address Management)  │  │
│  │  - NetworkPolicy enforcement     │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

#### 1. Executable (실행 파일)

Pod 네트워크를 구성하는 바이너리 파일로, kubelet이 직접 호출합니다.

- **위치**: `/opt/cni/bin/`
- **입력**: STDIN으로 JSON 네트워크 설정
- **출력**: STDOUT으로 결과 반환
- **동작**: `ADD`, `DEL`, `CHECK`, `VERSION` 커맨드 지원

#### 2. Daemon (데몬셋)

클러스터 전체 라우팅을 관리하는 백그라운드 프로세스입니다.

- **배포**: DaemonSet으로 각 노드에 실행
- **역할**:
  - 노드 간 라우팅 테이블 관리
  - IPAM (IP 주소 할당)
  - NetworkPolicy 적용
  - 모니터링 및 로깅

### 1.3 CNI 플러그인 호출 흐름

```bash
# 1. Pod 생성 요청
kubectl apply -f pod.yaml

# 2. Scheduler가 Node 할당
# 3. kubelet이 Container Runtime (containerd) 호출
# 4. Container Runtime이 CNI 플러그인 호출

# CNI 플러그인 호출 예시 (kubelet -> CNI)
CNI_COMMAND=ADD \
CNI_CONTAINERID=abc123 \
CNI_NETNS=/var/run/netns/pod1 \
CNI_IFNAME=eth0 \
CNI_PATH=/opt/cni/bin \
/opt/cni/bin/cilium < /etc/cni/net.d/10-cilium.conf

# 5. CNI Executable이 네트워크 설정
#    - veth pair 생성 (Pod <-> Host)
#    - IP 주소 할당 (CNI Daemon에 요청)
#    - 라우팅 규칙 추가

# 6. CNI Daemon이 클러스터 전체 라우팅 업데이트
#    - BGP 라우트 광고 (Calico)
#    - eBPF 맵 업데이트 (Cilium)
```

### 1.4 CNI 설정 파일

```json
// /etc/cni/net.d/10-cilium.conf
{
  "cniVersion": "1.0.0",
  "name": "cilium",
  "type": "cilium-cni",
  "enable-debug": false,
  "log-file": "/var/run/cilium/cilium-cni.log",
  "ipam": {
    "type": "cilium",
    "podCIDR": "10.244.0.0/16"
  },
  "capabilities": {
    "portMappings": true,
    "bandwidth": true
  }
}
```

---

## Part 2: 주요 CNI 플러그인 비교

### 2.1 CNI 플러그인 선택 가이드 (2025)

| 플러그인 | 장점 | 적합한 사용 사례 | 성능 |
|----------|------|-----------------|------|
| **Cilium** | eBPF 기반 고성능, L7 정책, 관찰성 | 대규모 클러스터, 마이크로서비스, 보안 중시 | ⭐⭐⭐⭐⭐ |
| **Calico** | 강력한 NetworkPolicy, BGP 지원 | 엔터프라이즈 보안, On-premise 환경 | ⭐⭐⭐⭐ |
| **Flannel** | 단순 설치, 가벼움 | 개발/테스트 환경, 소규모 클러스터 | ⭐⭐⭐ |
| **Weave** | 자동 메쉬 형성, 간편한 설정 | 빠른 프로토타이핑 | ⭐⭐⭐ |

**2025 권장**: Cilium (eBPF의 성능과 보안 이점)

### 2.2 Cilium: eBPF 기반 네트워킹

Cilium은 eBPF(extended Berkeley Packet Filter)를 활용하여 커널 수준에서 네트워크 패킷을 처리합니다.

#### eBPF 아키텍처

```
┌───────────────────────────────────────────┐
│          User Space                       │
│  ┌──────────────┐      ┌──────────────┐  │
│  │ Cilium Agent │ ───> │ Cilium CLI   │  │
│  │ (DaemonSet)  │      │  (Hubble)    │  │
│  └──────┬───────┘      └──────────────┘  │
│         │ BPF syscall                     │
├─────────┼─────────────────────────────────┤
│         v         Kernel Space            │
│  ┌──────────────────────────────────┐    │
│  │    eBPF Programs (JIT compiled)  │    │
│  │  - XDP (eXpress Data Path)       │    │
│  │  - TC (Traffic Control)          │    │
│  │  - Socket operations             │    │
│  │  - Kprobes (Kernel tracing)      │    │
│  └──────────────────────────────────┘    │
│                 │                         │
│                 v                         │
│  ┌──────────────────────────────────┐    │
│  │    eBPF Maps (Shared Data)       │    │
│  │  - Connection tracking           │    │
│  │  - NetworkPolicy rules           │    │
│  │  - Service endpoints             │    │
│  └──────────────────────────────────┘    │
└───────────────────────────────────────────┘
```

#### Cilium 주요 기능

**1. Kube-Proxy 대체 (2025 권장)**

```yaml
# values.yaml (Helm)
kubeProxyReplacement: "true"  # kube-proxy 제거
k8sServiceHost: 10.96.0.1     # API Server 직접 연결
k8sServicePort: 443

# eBPF 기반 로드밸런싱 장점
# - iptables 불필요 (O(n) -> O(1) 룩업)
# - Direct Server Return (DSR) 지원
# - Maglev 일관성 해싱
```

**성능 비교 (2025 벤치마크)**:

| 메트릭 | iptables | IPVS | Cilium eBPF |
|--------|----------|------|-------------|
| Latency (p99) | 5.2ms | 3.8ms | **1.5ms** |
| Throughput | 10 Gbps | 15 Gbps | **40+ Gbps** |
| CPU 사용률 | 높음 | 중간 | **낮음** |
| 서비스 수 확장성 | 5,000 | 10,000 | **100,000+** |

**2. L7 트래픽 제어 (HTTP/Kafka/gRPC)**

```yaml
# CiliumNetworkPolicy - HTTP 경로 기반 정책
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: http-rule
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        # GET /api/* 만 허용
        - method: "GET"
          path: "/api/.*"
        # POST /api/users는 특정 출처만
        - method: "POST"
          path: "/api/users"
          headers:
          - "X-API-Key: secret123"
```

**3. Hubble: 네트워크 관찰성**

```bash
# Hubble CLI로 실시간 트래픽 모니터링
hubble observe --namespace default

# 출력 예시
Nov 24 10:15:23.456: default/frontend:12345 -> default/backend:8080 (tcp) [FORWARDED]
Nov 24 10:15:23.460: default/backend:8080 -> external-api:443 (https) [DENIED by policy]

# 서비스 맵 시각화 (Hubble UI)
hubble observe --since 1h | hubble summarize --graph
```

**4. 멀티 클러스터 네트워킹 (ClusterMesh)**

```yaml
# clustermesh-config
apiVersion: v1
kind: ConfigMap
metadata:
  name: cilium-config
  namespace: kube-system
data:
  cluster-name: cluster-1
  cluster-id: "1"
  enable-cluster-mesh: "true"
  cluster-mesh-config: |
    clusters:
    - name: cluster-2
      address: cluster2.example.com:2379
      tls:
        ca-file: /etc/cilium/cluster2-ca.crt
```

#### Cilium 설치 (2025)

```bash
# Helm으로 설치
helm repo add cilium https://helm.cilium.io/
helm repo update

# 프로덕션 설정
helm install cilium cilium/cilium --version 1.16.0 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set operator.replicas=2 \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true

# 상태 확인
cilium status --wait

# Hubble 활성화
cilium hubble enable --ui
```

### 2.3 Calico: BGP 라우팅 및 보안 정책

Calico는 BGP(Border Gateway Protocol)를 사용하여 노드 간 라우팅을 수행하며, 강력한 NetworkPolicy 기능을 제공합니다.

#### Calico 아키텍처

```
┌─────────────────────────────────────────┐
│          Kubernetes Cluster             │
│                                         │
│  Node 1                 Node 2          │
│  ┌────────────┐        ┌────────────┐  │
│  │   Felix    │ ◄────► │   Felix    │  │
│  │ (Agent)    │  BGP   │ (Agent)    │  │
│  └──────┬─────┘        └─────┬──────┘  │
│         │                    │          │
│         │    ┌──────────┐    │          │
│         └───►│  BIRD    │◄───┘          │
│              │(BGP Peer)│               │
│              └─────┬────┘               │
│                    │                    │
│                    v                    │
│         ┌──────────────────┐            │
│         │   Datastore      │            │
│         │ (Kubernetes API  │            │
│         │   or etcd)       │            │
│         └──────────────────┘            │
└─────────────────────────────────────────┘
              │
              v
      ┌───────────────┐
      │  External     │
      │  BGP Router   │
      │  (ToR Switch) │
      └───────────────┘
```

#### Calico 주요 기능

**1. IP-in-IP vs VXLAN vs Native Routing**

```yaml
# Calico IPPool 설정
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  cidr: 10.244.0.0/16

  # 옵션 1: IP-in-IP (Overlay)
  ipipMode: Always  # CrossSubnet | Never

  # 옵션 2: VXLAN (Overlay)
  vxlanMode: Always  # CrossSubnet | Never

  # 옵션 3: Native Routing (No Encapsulation)
  # ipipMode: Never
  # vxlanMode: Never
  # natOutgoing: true

  blockSize: 26  # /26 블록 (64개 IP)
  nodeSelector: all()
```

| 모드 | 성능 | 사용 사례 |
|------|------|----------|
| **Native** | ⭐⭐⭐⭐⭐ | AWS VPC, Azure VNET (클라우드 네이티브 라우팅) |
| **IP-in-IP** | ⭐⭐⭐⭐ | 온프레미스, 복잡한 네트워크 토폴로지 |
| **VXLAN** | ⭐⭐⭐ | 방화벽이 IP-in-IP를 차단하는 환경 |

**2. BGP 라우트 광고**

```yaml
# BGPConfiguration - 서비스 IP를 외부로 광고
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: true  # 모든 노드 간 Full Mesh BGP
  asNumber: 65001              # 클러스터 AS 번호
  serviceLoadBalancerIPs:
  - cidr: 203.0.113.0/24       # 광고할 LoadBalancer IP 범위
  listenPort: 179

  # BGP Peer 설정 (ToR 스위치)
  communities:
  - name: bgp-large-community
    value: 65001:1000
```

```yaml
# BGPPeer - 외부 라우터 연결
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: tor-switch-1
spec:
  peerIP: 192.168.1.1          # ToR 스위치 IP
  asNumber: 65000              # ToR AS 번호
  nodeSelector: rack == 'rack-1'
```

**3. GlobalNetworkPolicy (클러스터 수준)**

```yaml
# GlobalNetworkPolicy - 모든 네임스페이스에 적용
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: deny-all-egress
spec:
  # 우선순위 (낮을수록 우선)
  order: 1000

  # 모든 Pod에 적용
  selector: all()

  types:
  - Egress

  egress:
  # DNS 허용
  - action: Allow
    protocol: UDP
    destination:
      ports:
      - 53
      selector: k8s-app == 'kube-dns'

  # Kubernetes API 서버 허용
  - action: Allow
    protocol: TCP
    destination:
      nets:
      - 10.96.0.1/32  # Kubernetes Service ClusterIP
      ports:
      - 443

  # 나머지는 거부
  - action: Deny
```

**4. Zero Trust 네트워킹**

```yaml
# 단계 1: 기본 Deny (모든 트래픽 차단)
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-deny
spec:
  order: 1000
  selector: all()
  types:
  - Ingress
  - Egress

---
# 단계 2: 명시적 Allow (필요한 트래픽만 허용)
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: production
spec:
  order: 100
  selector: app == 'backend'
  types:
  - Ingress
  ingress:
  - action: Allow
    protocol: TCP
    source:
      selector: app == 'frontend'
    destination:
      ports:
      - 8080
```

**5. 지리적 차단 (Geo-blocking)**

```yaml
# GlobalNetworkSet - 악성 IP 범위 정의
apiVersion: projectcalico.org/v3
kind: GlobalNetworkSet
metadata:
  name: blocked-countries
  labels:
    type: blocked-ips
spec:
  nets:
  # 예시: 특정 국가의 IP 범위
  - 203.0.113.0/24
  - 198.51.100.0/24

---
# GlobalNetworkPolicy - 차단 적용
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: geo-blocking
spec:
  order: 10
  selector: all()
  types:
  - Ingress
  ingress:
  - action: Deny
    protocol: TCP
    source:
      selector: type == 'blocked-ips'
```

#### Calico 설치 (2025)

```bash
# Operator로 설치
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/tigera-operator.yaml

# Custom Resource 설정
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    bgp: Enabled
    ipPools:
    - cidr: 10.244.0.0/16
      encapsulation: None  # Native routing
      natOutgoing: Enabled
      nodeSelector: all()
EOF

# 상태 확인
kubectl get tigerastatus

# BGP 피어 확인
calicoctl node status
```

### 2.4 Flannel: 단순 Overlay 네트워크

Flannel은 간단하고 가벼운 Overlay 네트워크를 제공합니다.

```yaml
# kube-flannel.yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
  namespace: kube-flannel
data:
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan",
        "Port": 8472
      }
    }
```

```bash
# Flannel 설치
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

**사용 사례**: 개발 환경, 학습 목적, 소규모 클러스터

---

## Part 3: NetworkPolicy 실전

### 3.1 Kubernetes NetworkPolicy

```yaml
# 예제: 3-Tier 애플리케이션 격리
---
# Frontend: Ingress에서만 접근 허용
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Ingress Controller에서만
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
  egress:
  # Backend API로만
  - to:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 8080
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    - podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53

---
# Backend: Frontend와 Database만 접근
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53

---
# Database: Backend에서만 접근
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
    ports:
    - protocol: TCP
      port: 5432
```

### 3.2 NetworkPolicy 디버깅

```bash
# 1. NetworkPolicy 확인
kubectl get networkpolicy -n production

# 2. Pod에 적용된 정책 확인 (Cilium)
kubectl -n production exec -it frontend-pod -- cilium endpoint list

# 3. 트래픽 차단 원인 확인 (Cilium Hubble)
hubble observe --namespace production --verdict DROPPED

# 4. 연결 테스트
kubectl run test-pod --rm -it --image=nicolaka/netshoot -- /bin/bash
# Pod 내에서
curl -v http://backend-service.production.svc.cluster.local:8080

# 5. Calico 정책 확인
calicoctl get networkpolicy -n production -o yaml
```

---

## Part 4: Service Mesh 통합

### 4.1 CNI vs Service Mesh

| 계층 | CNI | Service Mesh |
|------|-----|--------------|
| **OSI Layer** | L3/L4 (Network/Transport) | L7 (Application) |
| **책임** | Pod 간 연결, IP 라우팅 | 트래픽 관리, 보안, 관찰성 |
| **기능** | NetworkPolicy, LoadBalancing | Retry, Circuit Breaker, mTLS, Tracing |
| **구현** | Cilium, Calico, Flannel | Istio, Linkerd, Consul |
| **배포** | 클러스터 필수 (CNI 없으면 동작 불가) | 선택적 (복잡한 마이크로서비스에 추천) |

### 4.2 Istio vs Linkerd 비교 (2025)

#### 성능 벤치마크 (2025)

| 메트릭 | Istio (Envoy) | Linkerd (Rust Proxy) |
|--------|---------------|----------------------|
| **Latency (p99)** | 163ms | **0ms** (추가 지연 거의 없음) |
| **Latency (추가)** | 2-3ms | **0.8-1.5ms** |
| **Memory (per proxy)** | 40-50MB | **~10MB** |
| **CPU 소비** | Baseline | **30-40% 낮음** |

**결론**: Linkerd가 성능 우위, Istio는 기능 우위

#### 아키텍처 비교

**Istio (Envoy Sidecar)**

```
┌───────────────────────────────┐
│           Pod                 │
│  ┌──────────┐  ┌───────────┐ │
│  │   App    │  │  Envoy    │ │
│  │Container │◄─┤  Sidecar  │ │
│  └──────────┘  └───────────┘ │
└───────────────────────────────┘
         │              ▲
         │              │
         v              │
┌───────────────────────────────┐
│      Istio Control Plane      │
│  ┌────────┐  ┌─────────────┐ │
│  │ Istiod │  │ Galley      │ │
│  │(Pilot) │  │(Config)     │ │
│  └────────┘  └─────────────┘ │
└───────────────────────────────┘
```

**Linkerd (Rust Micro-Proxy)**

```
┌───────────────────────────────┐
│           Pod                 │
│  ┌──────────┐  ┌───────────┐ │
│  │   App    │  │ linkerd2  │ │
│  │Container │◄─┤  -proxy   │ │
│  └──────────┘  └───────────┘ │
└───────────────────────────────┘
         │              ▲
         │              │
         v              │
┌───────────────────────────────┐
│   Linkerd Control Plane       │
│  ┌──────────┐  ┌───────────┐ │
│  │Controller│  │ Identity  │ │
│  │(Dest API)│  │ (mTLS CA) │ │
│  └──────────┘  └───────────┘ │
└───────────────────────────────┘
```

#### 기능 비교

| 기능 | Istio | Linkerd |
|------|-------|---------|
| **자동 mTLS** | 설정 필요 | ✅ 기본 활성화 |
| **트래픽 분할** | ✅ 세밀한 제어 | ✅ 기본 지원 |
| **Circuit Breaker** | ✅ | ✅ |
| **Observability** | ✅ (Kiali, Jaeger) | ✅ (Linkerd Viz) |
| **멀티 클러스터** | ✅ (복잡) | ✅ (간단) |
| **VM 지원** | ✅ | ❌ (Kubernetes 전용) |
| **학습 곡선** | 높음 | **낮음** |

### 4.3 CNI + Service Mesh 통합 패턴

#### 패턴 1: Cilium + Istio

```yaml
# Cilium: L4 NetworkPolicy
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l4-policy
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP

---
# Istio: L7 트래픽 관리
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-route
spec:
  hosts:
  - backend.production.svc.cluster.local
  http:
  - match:
    - headers:
        version:
          exact: v2
    route:
    - destination:
        host: backend
        subset: v2
      weight: 20
    - destination:
        host: backend
        subset: v1
      weight: 80
  - route:
    - destination:
        host: backend
        subset: v1
```

#### 패턴 2: Calico + Linkerd

```yaml
# Calico: 외부 트래픽 제어
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: external-access
spec:
  order: 100
  selector: app == 'frontend'
  types:
  - Egress
  egress:
  # 외부 API 허용
  - action: Allow
    protocol: TCP
    destination:
      nets:
      - 203.0.113.0/24
      ports:
      - 443

---
# Linkerd: 클러스터 내 mTLS
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: production
  annotations:
    # Linkerd가 자동으로 mTLS 적용
    linkerd.io/inject: enabled
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
```

### 4.4 Ambient Mesh (Sidecar-less Service Mesh)

2025년 Istio의 새로운 아키텍처로, Sidecar 없이 Service Mesh 기능을 제공합니다.

```
Traditional Sidecar             Ambient Mesh
┌─────────────────┐            ┌─────────────────┐
│  Pod            │            │  Pod            │
│ ┌────┐ ┌─────┐ │            │ ┌────────────┐  │
│ │App │ │Envoy│ │            │ │    App     │  │
│ └────┘ └─────┘ │            │ └────────────┘  │
└─────────────────┘            └─────────────────┘
                                       │
                                       v
                               ┌─────────────────┐
                               │  ztunnel (Node) │
                               │  (mTLS, L4)     │
                               └─────────────────┘
                                       │
                                       v
                               ┌─────────────────┐
                               │  waypoint       │
                               │  (L7 policies)  │
                               └─────────────────┘
```

```yaml
# Ambient Mesh 활성화
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio.io/dataplane-mode: ambient  # Ambient 모드

---
# L7 정책이 필요한 경우만 waypoint 배포
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: backend-waypoint
  namespace: production
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: http
    port: 15008
    protocol: HTTP
```

**Ambient Mesh 장점**:
- 리소스 오버헤드 감소 (Sidecar 불필요)
- 더 빠른 배포 및 업그레이드
- L4 보안은 기본 제공, L7은 필요시만 배포

---

## 🛠️ 실습 가이드

### 실습 1: Cilium 설치 및 Hubble로 트래픽 관찰

```bash
# 1. Kind 클러스터 생성 (CNI 비활성화)
cat <<EOF | kind create cluster --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# 2. Cilium 설치
cilium install --version 1.16.0

# 3. 상태 확인
cilium status --wait

# 4. 연결 테스트
cilium connectivity test

# 5. Hubble 활성화
cilium hubble enable --ui

# 6. Hubble UI 접근
cilium hubble ui

# 7. 샘플 앱 배포
kubectl create namespace demo
kubectl -n demo create deployment nginx --image=nginx
kubectl -n demo create deployment curl --image=curlimages/curl:latest -- sleep infinity

# 8. 트래픽 생성
kubectl -n demo exec -it deploy/curl -- sh
# 컨테이너 내에서
while true; do curl -s http://nginx; sleep 1; done

# 9. Hubble로 관찰
hubble observe --namespace demo --follow
```

### 실습 2: Calico NetworkPolicy로 Zero Trust 구현

```bash
# 1. Calico 설치 (실습 1의 Kind 클러스터 재사용)
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/tigera-operator.yaml

cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - cidr: 10.244.0.0/16
      encapsulation: VXLAN
EOF

# 2. 3-Tier 앱 배포
kubectl create namespace production

# Database
kubectl -n production create deployment postgres \
  --image=postgres:15 \
  --port=5432

kubectl -n production expose deployment postgres --port=5432

# Backend
kubectl -n production create deployment backend \
  --image=your-backend-app:latest \
  --port=8080

kubectl -n production expose deployment backend --port=8080

# Frontend
kubectl -n production create deployment frontend \
  --image=your-frontend-app:latest \
  --port=80

kubectl -n production expose deployment frontend --port=80 --type=LoadBalancer

# 3. 기본 Deny 정책 적용
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 4. 연결 테스트 (실패해야 정상)
kubectl -n production exec -it deploy/frontend -- curl http://backend:8080

# 5. 명시적 Allow 정책 적용 (Part 3.1 예제 사용)

# 6. 연결 테스트 (성공)
kubectl -n production exec -it deploy/frontend -- curl http://backend:8080
```

### 실습 3: Linkerd 설치 및 mTLS 검증

```bash
# 1. Linkerd CLI 설치
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install-edge | sh
export PATH=$PATH:$HOME/.linkerd2/bin

# 2. 사전 확인
linkerd check --pre

# 3. Linkerd 설치
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

# 4. 상태 확인
linkerd check

# 5. 샘플 앱에 Linkerd 주입
kubectl create namespace demo
kubectl -n demo create deployment nginx --image=nginx
kubectl -n demo create deployment curl --image=curlimages/curl:latest -- sleep infinity

# Linkerd 주입
kubectl get deploy -n demo -o yaml | linkerd inject - | kubectl apply -f -

# 6. mTLS 확인
linkerd -n demo tap deploy/nginx

# 출력에서 "tls=true" 확인:
# req id=1:1 proxy=in  src=10.244.1.5:45678 dst=10.244.1.6:80 tls=true

# 7. Linkerd Viz 설치 (대시보드)
linkerd viz install | kubectl apply -f -
linkerd viz dashboard
```

---

## 💻 예제 코드

### CNI 플러그인 호출 시뮬레이션

```go
// cni-simulator.go
package main

import (
    "encoding/json"
    "fmt"
    "os"

    "github.com/containernetworking/cni/pkg/skel"
    "github.com/containernetworking/cni/pkg/types"
    "github.com/containernetworking/cni/pkg/version"
)

// NetConf는 CNI 설정 구조체
type NetConf struct {
    types.NetConf
    BridgeName string `json:"bridge"`
    IPMasq     bool   `json:"ipMasq"`
}

func cmdAdd(args *skel.CmdArgs) error {
    // 1. 네트워크 설정 파싱
    conf := &NetConf{}
    if err := json.Unmarshal(args.StdinData, conf); err != nil {
        return fmt.Errorf("failed to parse network config: %v", err)
    }

    // 2. IPAM 플러그인 호출하여 IP 할당
    ipamResult, err := callIPAM(conf, args)
    if err != nil {
        return fmt.Errorf("IPAM failed: %v", err)
    }

    // 3. veth pair 생성
    hostVeth, containerVeth, err := createVethPair(args.ContainerID)
    if err != nil {
        return fmt.Errorf("failed to create veth pair: %v", err)
    }

    // 4. Container 네임스페이스에 인터페이스 추가
    if err := moveToNetNS(containerVeth, args.Netns); err != nil {
        return fmt.Errorf("failed to move veth to netns: %v", err)
    }

    // 5. IP 주소 할당
    if err := assignIP(containerVeth, ipamResult); err != nil {
        return fmt.Errorf("failed to assign IP: %v", err)
    }

    // 6. 라우팅 규칙 추가
    if err := addRoutes(args.Netns, ipamResult); err != nil {
        return fmt.Errorf("failed to add routes: %v", err)
    }

    // 7. 결과 반환
    return types.PrintResult(ipamResult, conf.CNIVersion)
}

func cmdDel(args *skel.CmdArgs) error {
    // 1. 네트워크 설정 파싱
    conf := &NetConf{}
    if err := json.Unmarshal(args.StdinData, conf); err != nil {
        return fmt.Errorf("failed to parse network config: %v", err)
    }

    // 2. IPAM IP 해제
    if err := releaseIPAM(conf, args); err != nil {
        return fmt.Errorf("IPAM release failed: %v", err)
    }

    // 3. veth 삭제 (netns 삭제 시 자동)
    return nil
}

func cmdCheck(args *skel.CmdArgs) error {
    // 네트워크 설정 검증
    return nil
}

func main() {
    skel.PluginMain(cmdAdd, cmdCheck, cmdDel, version.All, "my-cni-plugin")
}
```

### NetworkPolicy 검증 스크립트

```python
#!/usr/bin/env python3
# netpol-validator.py

import subprocess
import json
from typing import List, Dict

def get_network_policies(namespace: str) -> List[Dict]:
    """네임스페이스의 모든 NetworkPolicy 가져오기"""
    cmd = ["kubectl", "get", "networkpolicy", "-n", namespace, "-o", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout)
    return data.get("items", [])

def get_pods(namespace: str) -> List[Dict]:
    """네임스페이스의 모든 Pod 가져오기"""
    cmd = ["kubectl", "get", "pods", "-n", namespace, "-o", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout)
    return data.get("items", [])

def matches_selector(pod_labels: Dict, selector: Dict) -> bool:
    """Pod 라벨이 selector와 매치되는지 확인"""
    if not selector:
        return True

    match_labels = selector.get("matchLabels", {})
    for key, value in match_labels.items():
        if pod_labels.get(key) != value:
            return False
    return True

def validate_connectivity(namespace: str):
    """NetworkPolicy에 따른 연결성 검증"""
    policies = get_network_policies(namespace)
    pods = get_pods(namespace)

    print(f"\n=== NetworkPolicy 검증: {namespace} ===\n")

    for policy in policies:
        policy_name = policy["metadata"]["name"]
        pod_selector = policy["spec"].get("podSelector", {})

        print(f"Policy: {policy_name}")
        print(f"적용 대상 Pod: {pod_selector}")

        # 정책이 적용되는 Pod 찾기
        affected_pods = []
        for pod in pods:
            pod_name = pod["metadata"]["name"]
            pod_labels = pod["metadata"].get("labels", {})

            if matches_selector(pod_labels, pod_selector):
                affected_pods.append(pod_name)

        print(f"  - 영향받는 Pod: {', '.join(affected_pods) if affected_pods else 'None'}")

        # Ingress 규칙 검증
        if "ingress" in policy["spec"]:
            print("  - Ingress 규칙:")
            for rule in policy["spec"]["ingress"]:
                from_rules = rule.get("from", [])
                ports = rule.get("ports", [])

                if not from_rules:
                    print("    * 모든 소스에서 허용")
                else:
                    for from_rule in from_rules:
                        if "podSelector" in from_rule:
                            print(f"    * Pod: {from_rule['podSelector']}")
                        if "namespaceSelector" in from_rule:
                            print(f"    * Namespace: {from_rule['namespaceSelector']}")

                for port in ports:
                    print(f"    * Port: {port['port']}/{port.get('protocol', 'TCP')}")

        # Egress 규칙 검증
        if "egress" in policy["spec"]:
            print("  - Egress 규칙:")
            for rule in policy["spec"]["egress"]:
                to_rules = rule.get("to", [])
                ports = rule.get("ports", [])

                if not to_rules:
                    print("    * 모든 목적지 허용")
                else:
                    for to_rule in to_rules:
                        if "podSelector" in to_rule:
                            print(f"    * Pod: {to_rule['podSelector']}")
                        if "namespaceSelector" in to_rule:
                            print(f"    * Namespace: {to_rule['namespaceSelector']}")

                for port in ports:
                    print(f"    * Port: {port['port']}/{port.get('protocol', 'TCP')}")

        print()

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: netpol-validator.py <namespace>")
        sys.exit(1)

    namespace = sys.argv[1]
    validate_connectivity(namespace)
```

실행:

```bash
chmod +x netpol-validator.py
./netpol-validator.py production
```

---

## 📚 참고 자료

### 공식 문서 (2025)

- [Kubernetes Network Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
- [CNI Specification](https://www.cni.dev/docs/)
- [Cilium Documentation](https://docs.cilium.io/)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Linkerd Documentation](https://linkerd.io/2.14/overview/)

### CNI 가이드

- [Kubernetes CNI: The Ultimate Guide (2025)](https://www.plural.sh/blog/kubernetes-cni-guide/)
- [Tigera: Kubernetes CNI Explained](https://www.tigera.io/learn/guides/kubernetes-networking/kubernetes-cni/)
- [The Kubernetes Networking Guide - CNI](https://www.tkng.io/cni/)

### Cilium & eBPF

- [Cilium GitHub](https://github.com/cilium/cilium)
- [Unlocking cloud native security with Cilium and eBPF](https://www.cncf.io/blog/2025/01/02/unlocking-cloud-native-security-with-cilium-and-ebpf/)
- [Azure CNI powered by Cilium with eBPF Host Routing](https://techcommunity.microsoft.com/blog/azurenetworkingblog/introducing-ebpf-host-routing-high-performance-ai-networking-with-azure-cni-powe/4468216)
- [Cilium Kubernetes Guide](https://www.plural.sh/blog/cilium-kubernetes-guide/)

### Calico & NetworkPolicy

- [Calico GitHub](https://github.com/projectcalico/calico)
- [Advertising Kubernetes Service IPs with Calico and BGP](https://www.tigera.io/blog/advertising-kubernetes-service-ips-with-calico-and-bgp/)
- [Calico: Open-source Kubernetes networking and security](https://www.helpnetsecurity.com/2025/07/21/open-source-kubernetes-networking-security-observability/)
- [Implementing Kubernetes Network Policies with Calico](https://www.xgrid.co/resources/implementing-kubernetes-network-policies-with-calico/)

### Service Mesh

- [Service Mesh Comparison (2025)](https://blog.sparkfabrik.com/en/service-mesh)
- [Istio vs Linkerd: Service Mesh Showdown](https://www.wallarm.com/cloud-native-products-101/istio-vs-linkerd-service-mesh-technologies)
- [AKS Service Mesh Best Practices (2025)](https://medium.com/@h.stoychev87/aks-azure-networking-and-services-best-practices-azure-caf-and-waf-2025-edition-part-3-9a342d9e2abd)
- [Service Mesh in Java: Istio and Linkerd Integration](https://www.javacodegeeks.com/2025/07/service-mesh-in-java-istio-and-linkerd-integration-for-secure-microservices.html)

### 성능 및 벤치마크

- [Kubernetes network performance with Cilium and eBPF](https://www.techtarget.com/searchitoperations/tutorial/Improve-Kubernetes-network-performance-with-Cilium-and-eBPF)
- [eBPF technology impact on networking performance](https://www.researchgate.net/publication/393211756_The_impact_of_using_eBPF_technology_on_the_performance_of_networking_solutions_in_a_Kubernetes_cluster)
- [K8s Service Mesh Comparison](https://www.toptal.com/kubernetes/service-mesh-comparison)

---

## ✅ 학습 체크리스트

### 기본 (Essential)
- [ ] CNI 스펙과 플러그인 구조 이해
- [ ] Cilium, Calico, Flannel 차이점 설명 가능
- [ ] Kubernetes NetworkPolicy 작성 및 적용
- [ ] Pod 간 네트워크 연결 문제 디버깅
- [ ] Service 타입 (ClusterIP, NodePort, LoadBalancer) 이해

### 중급 (Intermediate)
- [ ] eBPF 기반 네트워킹의 장점 이해
- [ ] Cilium으로 kube-proxy 대체
- [ ] Calico BGP 설정 및 외부 라우터 연동
- [ ] GlobalNetworkPolicy로 클러스터 수준 보안 정책 구현
- [ ] Hubble로 네트워크 트래픽 관찰

### 고급 (Advanced)
- [ ] 멀티 클러스터 네트워킹 (ClusterMesh) 구성
- [ ] L7 NetworkPolicy (HTTP/gRPC) 작성
- [ ] Service Mesh (Istio/Linkerd) 설치 및 설정
- [ ] CNI와 Service Mesh 통합 패턴 구현
- [ ] Ambient Mesh (Sidecar-less) 아키텍처 이해

### 프로덕션 (Production-Ready)
- [ ] Zero Trust 네트워킹 아키텍처 설계
- [ ] 지리적 차단 및 Egress 트래픽 제어
- [ ] CNI 플러그인 성능 튜닝 및 벤치마크
- [ ] NetworkPolicy 자동화 (GitOps)
- [ ] 멀티 테넌트 환경에서 네트워크 격리 전략 수립

---

## 🎓 다음 단계

### Computing Service 완료!

축하합니다! Computing Service 섹션의 7개 Chapter를 모두 완료했습니다:
1. ✅ OpenStack
2. ✅ 가상화 기술
3. ✅ 스케줄링
4. ✅ Cloud Native 컴퓨팅
5. ✅ 클라우드 인프라 설계
6. ✅ Kubernetes Operator
7. ✅ Cloud Network CNI

### Networking Service (보류)

사용자 요청에 따라 Networking Service 섹션은 현재 보류 상태입니다. Computing Service 학습을 먼저 완료하고, 추후 필요시 Networking Service 학습을 진행할 수 있습니다.

### 추가 학습 리소스
- [CNCF Landscape - Networking](https://landscape.cncf.io/guide#runtime--cloud-native-network)
- [Kubernetes Networking Special Interest Group](https://github.com/kubernetes/community/tree/master/sig-network)
- [eBPF Documentation](https://ebpf.io/)
- [Cilium Lab Exercises](https://cilium.io/labs/)

---

**작성일:** 2025-11-24
**대상:** Computing Service 엔지니어, Networking Service 엔지니어
**난이도:** Intermediate to Advanced
**예상 학습 시간:** 14-18시간 (실습 포함)
