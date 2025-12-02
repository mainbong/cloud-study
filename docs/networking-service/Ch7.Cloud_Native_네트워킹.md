# Ch7. Cloud Native 네트워킹

> Kubernetes 네트워킹, Service Mesh, CNI 플러그인 (2025)

## 목차

- [Kubernetes 네트워킹 모델](#kubernetes-네트워킹-모델)
- [Service 타입](#service-타입)
- [Ingress Controllers](#ingress-controllers)
- [Network Policies](#network-policies)
- [Service Mesh](#service-mesh)
- [CNI 플러그인](#cni-플러그인)
- [실습 가이드](#실습-가이드)

---

## Kubernetes 네트워킹 모델

### 네트워킹 원칙

Kubernetes는 다음 3가지 핵심 네트워킹 요구사항을 정의합니다:

1. **Pod-to-Pod 통신**: 모든 Pod은 NAT 없이 서로 통신
2. **Node-to-Pod 통신**: 모든 Node는 NAT 없이 모든 Pod과 통신
3. **Pod IP 일관성**: Pod이 보는 자신의 IP는 다른 Pod이 보는 IP와 동일

### CNI (Container Network Interface)

CNI는 컨테이너 네트워크 구성을 위한 표준 인터페이스입니다.

**주요 CNI 플러그인 (2025)**

| CNI | 네트워킹 방식 | 성능 | 보안 기능 | 사용 사례 |
|-----|-------------|------|----------|----------|
| **Cilium** | eBPF | 9.2 Gbps, 0.20ms | L3-L7, mTLS | 고성능, 관찰성 |
| **Calico** | BGP/VXLAN | 8.5 Gbps, 0.25ms | NetworkPolicy | 엔터프라이즈, 규정준수 |
| **Flannel** | VXLAN | 7.8 Gbps, 0.35ms | 기본 | 간단한 설정 |
| **Weave** | Mesh | 6.5 Gbps, 0.45ms | 암호화 | 멀티클라우드 |

---

## Service 타입

### ClusterIP (기본)

클러스터 내부에서만 접근 가능한 가상 IP를 할당합니다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 8080        # Service 포트
    targetPort: 8080  # Pod 포트
```

**동작 방식:**

```
Client Pod → kube-proxy (iptables/ipvs) → ClusterIP → Backend Pods
```

### NodePort

각 Node의 특정 포트를 통해 외부에서 접근 가능합니다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30080  # 30000-32767 범위
```

**접근 방법:**

```bash
curl http://<node-ip>:30080
```

### LoadBalancer

클라우드 제공자의 외부 로드밸런서를 프로비저닝합니다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"  # AWS NLB
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 443
    targetPort: 8443
```

**클라우드별 구현 (2025)**

- **AWS**: Network Load Balancer (NLB) - 100만+ 동시연결
- **GCP**: Global Load Balancer - 1초 이내 글로벌 페일오버
- **Azure**: Standard Load Balancer - 초당 25만 연결

### ExternalName

외부 DNS 이름으로 리디렉션합니다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
```

---

## Ingress Controllers

### ⚠️ 2025 중요 공지

**Ingress NGINX 프로젝트 종료 예정**

- **종료 날짜**: 2026년 3월
- **영향**: 릴리스 중단, 보안 업데이트 없음
- **대안**: Traefik, F5 NGINX Ingress Controller, HAProxy

### Traefik (권장)

자동 서비스 디스커버리와 Let's Encrypt 통합을 제공합니다.

**설치:**

```bash
# Helm으로 설치
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ports.web.redirectTo.port=websecure \
  --set certResolver.letsencrypt.email=admin@example.com
```

**Ingress 리소스:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### F5 NGINX Ingress Controller

엔터프라이즈급 성능과 안정성을 제공합니다.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    nginx.org/rewrites: "serviceName=web rewrite=/"
    nginx.org/rate-limit: "10r/s"
spec:
  ingressClassName: nginx
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /v1
        pathType: Prefix
        backend:
          service:
            name: api-v1
            port:
              number: 8080
```

### 성능 비교 (2025)

| Controller | 처리량 | 지연시간 (p99) | 메모리 | 특징 |
|-----------|--------|---------------|--------|------|
| **Traefik** | 45k req/s | 15ms | 256MB | 자동화, Let's Encrypt |
| **F5 NGINX** | 50k req/s | 12ms | 512MB | 엔터프라이즈, 안정성 |
| **HAProxy** | 52k req/s | 10ms | 384MB | 고성능, TCP/UDP |
| **Kong** | 40k req/s | 18ms | 768MB | API 게이트웨이 |

---

## Network Policies

### 기본 거부 정책

모든 트래픽을 차단하고 명시적으로 허용합니다.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 특정 트래픽 허용

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Egress 제어

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-and-api
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53  # DNS
  - to:
    - podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 443
```

### 네임스페이스 격리

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}  # 같은 네임스페이스만 허용
```

---

## Service Mesh

### Linkerd (권장 - 2025)

**최고 성능**: 17ms 중앙값 지연시간, 200-300MB 메모리 사용

**설치:**

```bash
# Linkerd CLI 설치
curl -sL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin

# 클러스터 체크
linkerd check --pre

# 설치
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

# 검증
linkerd check
```

**애플리케이션 메시 추가:**

```bash
# 네임스페이스 주입 활성화
kubectl annotate namespace production linkerd.io/inject=enabled

# 기존 Deployment 재시작
kubectl rollout restart deployment -n production

# mTLS 확인
linkerd viz -n production tap deploy/web
```

**서비스 프로파일 (트래픽 분할):**

```yaml
apiVersion: split.smi-spec.io/v1alpha1
kind: TrafficSplit
metadata:
  name: api-rollout
  namespace: production
spec:
  service: api-service
  backends:
  - service: api-v1
    weight: 90
  - service: api-v2
    weight: 10  # Canary 배포
```

### Istio

**풍부한 기능**: 고급 트래픽 관리, 다양한 관찰성 도구

**설치:**

```bash
# istioctl 다운로드
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# 설치 (Ambient 모드 - 2025 신기능)
istioctl install --set profile=ambient -y

# 네임스페이스 레이블
kubectl label namespace production istio.io/dataplane-mode=ambient
```

**Gateway 설정:**

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: istio-gateway
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "*.example.com"
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: istio-gateway
  hostnames:
  - "app.example.com"
  rules:
  - backendRefs:
    - name: web-service
      port: 80
```

**Virtual Service (트래픽 라우팅):**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-vs
spec:
  hosts:
  - api-service
  http:
  - match:
    - headers:
        user-type:
          exact: premium
    route:
    - destination:
        host: api-service
        subset: v2
  - route:
    - destination:
        host: api-service
        subset: v1
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-dr
spec:
  host: api-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

### 성능 비교 (2025 벤치마크)

**지연시간 (2000 RPS 기준)**

| Service Mesh | 중앙값 (p50) | p99 | 최대 | 메모리 |
|-------------|-------------|-----|------|--------|
| **Baseline** | 6ms | 28ms | 22ms | - |
| **Linkerd** | 17ms (+11ms) | 92ms | 92ms | 200-300MB |
| **Istio (Sidecar)** | 25ms (+19ms) | 255ms | 221ms | 1-2GB |
| **Istio (Ambient)** | 28ms (+22ms) | 103ms | 150ms | 800MB-1.2GB |

**처리 성능:**

- Linkerd: 163ms 더 빠름 (vs Istio Sidecar at p99)
- Linkerd: 11.2ms 더 빠름 (vs Istio Ambient)

**선택 기준 (2025)**

- **고성능 필요**: Linkerd (가장 낮은 지연시간, 최소 리소스)
- **풍부한 기능**: Istio (고급 트래픽 관리, 다양한 프로토콜)
- **마이그레이션**: Istio Ambient (기존 Pod 수정 없이 메시 추가)

---

## CNI 플러그인

### Cilium (eBPF 기반 - 권장)

**최고 성능**: 9.2 Gbps 처리량, 0.20ms 지연시간

**특징:**

- eBPF를 통한 커널 레벨 패킷 처리 (iptables 우회)
- L3-L7 네트워크 정책
- Hubble을 통한 심층 관찰성
- 투명한 암호화 (WireGuard/IPsec)

**설치:**

```bash
# Helm으로 설치
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=strict \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
```

**L7 Network Policy:**

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: api-l7-policy
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/v1/.*"
        - method: "POST"
          path: "/api/v1/orders"
```

**Hubble 관찰성:**

```bash
# Hubble CLI 설치
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz
tar xzvf hubble-linux-amd64.tar.gz
sudo mv hubble /usr/local/bin

# 트래픽 관찰
hubble observe --namespace production

# L7 트래픽 확인
hubble observe --protocol http --verdict DROPPED
```

### Calico (엔터프라이즈)

**안정성과 규정준수**: 8.5 Gbps 처리량, 0.25ms 지연시간

**특징:**

- BGP 라우팅 지원
- 세밀한 NetworkPolicy
- Windows 노드 지원
- FIPS 140-2 규정준수

**설치:**

```bash
# Operator 설치
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

# Calico 설치
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
```

**고급 Network Policy:**

```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: deny-egress-to-external
spec:
  order: 100
  selector: tier == "production"
  types:
  - Egress
  egress:
  # 내부 네트워크 허용
  - action: Allow
    destination:
      nets:
      - 10.0.0.0/8
      - 172.16.0.0/12
      - 192.168.0.0/16
  # 외부 차단
  - action: Deny
```

**BGP 설정:**

```yaml
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: true
  asNumber: 65000
  serviceClusterIPs:
  - cidr: 10.96.0.0/12
```

### 선택 가이드

| 시나리오 | 추천 CNI | 이유 |
|---------|---------|------|
| **고성능 요구** | Cilium | eBPF로 최저 지연시간 |
| **엔터프라이즈** | Calico | 규정준수, 안정성 |
| **멀티클라우드** | Calico | BGP 라우팅 |
| **관찰성 중요** | Cilium | Hubble 통합 |
| **간단한 설정** | Flannel | 최소 구성 |
| **Windows 노드** | Calico | Windows 지원 |

---

## 실습 가이드

### 실습 1: Cilium + Hubble로 네트워크 관찰

```bash
# 1. Cilium 설치 (kind 클러스터)
kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
networking:
  disableDefaultCNI: true
EOF

# 2. Cilium 설치
cilium install

# 3. Hubble 활성화
cilium hubble enable --ui

# 4. 포트포워딩
cilium hubble ui

# 5. 테스트 앱 배포
kubectl create deployment web --image=nginx --replicas=3
kubectl expose deployment web --port=80

# 6. 트래픽 생성
kubectl run -it --rm debug --image=curlimages/curl -- sh
curl http://web

# 7. Hubble로 관찰
hubble observe --namespace default --verdict FORWARDED
```

### 실습 2: Linkerd로 Canary 배포

```bash
# 1. Linkerd 설치
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

# 2. 앱 배포 (v1)
kubectl create deployment api-v1 --image=hashicorp/http-echo --replicas=3
kubectl set env deployment/api-v1 ECHO_TEXT="API v1"
kubectl expose deployment api-v1 --port=5678 --name=api-service

# 3. Linkerd 주입
kubectl get deployment api-v1 -o yaml | linkerd inject - | kubectl apply -f -

# 4. v2 배포
kubectl create deployment api-v2 --image=hashicorp/http-echo --replicas=1
kubectl set env deployment/api-v2 ECHO_TEXT="API v2 - New Feature"
kubectl get deployment api-v2 -o yaml | linkerd inject - | kubectl apply -f -

# 5. 트래픽 분할 (10% canary)
cat <<EOF | kubectl apply -f -
apiVersion: split.smi-spec.io/v1alpha1
kind: TrafficSplit
metadata:
  name: api-rollout
spec:
  service: api-service
  backends:
  - service: api-v1
    weight: 90
  - service: api-v2
    weight: 10
EOF

# 6. 테스트
for i in {1..20}; do
  kubectl run -it --rm curl-$i --image=curlimages/curl --restart=Never -- \
    curl -s http://api-service:5678
done

# 7. 메트릭 확인
linkerd viz stat trafficsplit
linkerd viz tap deployment/api-v2
```

### 실습 3: Network Policy로 마이크로서비스 보안

```bash
# 1. 3-tier 애플리케이션 배포
kubectl create namespace secure-app

# Frontend
kubectl create deployment frontend --image=nginx -n secure-app
kubectl label deployment frontend app=frontend tier=frontend -n secure-app
kubectl expose deployment frontend --port=80 -n secure-app

# Backend
kubectl create deployment backend --image=nginx -n secure-app
kubectl label deployment backend app=backend tier=backend -n secure-app
kubectl expose deployment backend --port=80 -n secure-app

# Database
kubectl create deployment database --image=postgres -n secure-app
kubectl label deployment database app=database tier=database -n secure-app
kubectl expose deployment database --port=5432 -n secure-app

# 2. 기본 거부 정책
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: secure-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 3. Frontend → Backend 허용
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: secure-app
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 80
EOF

# 4. Backend → Database 허용
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: secure-app
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
EOF

# 5. DNS 허용 (모든 Pod)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: secure-app
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF

# 6. 테스트
# Frontend → Backend (성공)
kubectl exec -it -n secure-app deployment/frontend -- curl http://backend

# Frontend → Database (실패 - 차단됨)
kubectl exec -it -n secure-app deployment/frontend -- curl http://database:5432
```

### 실습 4: Traefik Ingress + Let's Encrypt

```bash
# 1. Traefik 설치
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set ports.web.redirectTo.port=websecure

# 2. Cert-Manager 설치
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml

# 3. Let's Encrypt Issuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# 4. 애플리케이션 배포
kubectl create deployment web --image=nginxdemos/hello
kubectl expose deployment web --port=80

# 5. Ingress 생성
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - myapp.example.com
    secretName: web-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
EOF

# 6. 인증서 상태 확인
kubectl get certificate
kubectl describe certificate web-tls
```

---

## 참고 자료

### CNI 플러그인

- [Cilium vs Calico 2025 Performance](https://sanj.dev/post/cilium-calico-flannel-cni-performance-comparison)
- [Kubernetes CNI Comparison Part 2](https://klizos.com/kubernetes-cni-comparison-part-2/)
- [Stop Using the Wrong CNI in 2025](https://blog.devops.dev/stop-using-the-wrong-cni-flannel-vs-calico-vs-cilium-in-2025-c11b42ce05a3)
- [Calico vs Cilium: 9 Key Differences](https://www.tigera.io/learn/guides/cilium-vs-calico/)

### Service Mesh

- [Linkerd vs Ambient Mesh 2025 Benchmarks](https://linkerd.io/2025/04/24/linkerd-vs-ambient-mesh-2025-benchmarks/)
- [Service Meshes Decoded: Istio vs Linkerd](https://livewyer.io/blog/service-meshes-decoded-istio-vs-linkerd-vs-cilium/)
- [Linkerd vs Istio Comparison](https://www.buoyant.io/linkerd-vs-istio)
- [Service Mesh with Istio and Linkerd](https://www.glukhov.org/post/2025/10/service-mesh-with-istio-and-linkerd/)

### Ingress Controllers

- [Kubernetes Ingress Controllers 2025 Edition](https://medium.com/@canaldoagdias/kubernetes-ingress-controllers-explained-nginx-vs-traefik-vs-haproxy-2025-edition-6e288e3f7d1a)
- [Why Traefik is the Best Ingress NGINX Replacement](https://traefik.io/blog/migrate-from-ingress-nginx-to-traefik-now)
- [Best Ingress Controllers for Kubernetes 2025](https://www.pomerium.com/blog/best-ingress-controllers-for-kubernetes)
- [Nginx Ingress vs Traefik](https://www.wildnetedge.com/blogs/nginx-ingress-vs-traefik-which-ingress-controller-wins)

### 공식 문서

- [Kubernetes Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Cilium Documentation](https://docs.cilium.io/)
- [Calico Documentation](https://docs.tigera.io/calico/latest/)
- [Linkerd Documentation](https://linkerd.io/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

---

## 학습 체크리스트

- [ ] Kubernetes 네트워킹 3원칙 이해
- [ ] Service 타입별 차이점 파악 (ClusterIP, NodePort, LoadBalancer)
- [ ] Ingress Controller 선택 기준 숙지 (Traefik vs F5 NGINX)
- [ ] Network Policy로 마이크로서비스 보안 구현
- [ ] Service Mesh 성능 비교 (Linkerd vs Istio)
- [ ] CNI 플러그인 특성 비교 (Cilium vs Calico)
- [ ] eBPF 기반 네트워킹 이해
- [ ] L7 네트워크 정책 적용
- [ ] Hubble로 네트워크 트래픽 관찰
- [ ] Canary 배포 구현 (TrafficSplit)
- [ ] Let's Encrypt 자동 인증서 설정
- [ ] 3-tier 애플리케이션 네트워크 보안 구성

---

**다음 단계**: 이제 Networking Service 섹션의 모든 7개 챕터가 완성되었습니다. 각 챕터는 2025년 최신 기술과 실전 예제를 포함하고 있습니다.
