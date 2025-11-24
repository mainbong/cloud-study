# Ch1. Kubernetes 심화

## 📋 개요

Kubernetes는 컨테이너 오케스트레이션의 사실상 표준이 되었습니다. 이 장에서는 Kubernetes의 내부 아키텍처를 깊이 이해하고, Controller와 Operator를 직접 개발하는 방법을 학습합니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:
- Kubernetes Control Plane의 내부 동작 원리 이해
- Custom Resource Definition (CRD) 생성 및 관리
- Kubernetes Controller 개발 (Informer, Workqueue)
- Kubernetes Operator 패턴 구현
- 대규모 클러스터 운영 및 최적화

---

## 🏗️ Part 1: Kubernetes 아키텍처 심화

### 1. Control Plane 컴포넌트

#### API Server

모든 Kubernetes 작업의 진입점입니다.

**주요 기능:**

- RESTful API 제공
- 인증/인가 (Authentication/Authorization)
- Admission Control
- etcd와 통신

**API Request 흐름:**
```
Client (kubectl)
  ↓
API Server
  ↓ Authentication (인증)
  ↓ Authorization (인가)
  ↓ Admission Control (검증/변경)
  ↓ Validation (스키마 검증)
  ↓ etcd (저장)
```

**Admission Controllers 예제:**
```yaml
# MutatingWebhookConfiguration
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: pod-injector
webhooks:
  - name: pod-injector.example.com
    clientConfig:
      service:
        name: pod-injector
        namespace: default
        path: "/mutate"
    rules:
      - operations: ["CREATE"]
        apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
```

#### etcd

Kubernetes의 모든 상태를 저장하는 분산 키-값 저장소입니다.

**etcd 백업:**
```bash
# etcd 스냅샷 생성
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 스냅샷 검증
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-snapshot.db

# 복원
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir=/var/lib/etcd-restore
```

#### Scheduler

Pod를 적절한 Node에 할당합니다.

**스케줄링 프로세스:**
```
1. Filtering (필터링)
   - Node가 Pod 요구사항을 만족하는가?
   - Resource 충분한가?
   - Taints/Tolerations 일치하는가?

2. Scoring (점수 부여)
   - 남은 리소스 비율
   - Pod 분산 정도
   - Node Affinity

3. Binding (할당)
   - 최고 점수 Node에 Pod 할당
```

**Custom Scheduler:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  schedulerName: my-custom-scheduler  # 커스텀 스케줄러 지정
  containers:
  - name: app
    image: myapp:latest
```

#### Controller Manager

다양한 Controller를 실행하는 데몬입니다.

**주요 Controller:**

- **Deployment Controller**: Deployment 관리
- **ReplicaSet Controller**: Pod 복제본 관리
- **Node Controller**: Node 상태 모니터링
- **Service Controller**: LoadBalancer Service 관리

---

### 2. Node 컴포넌트

#### Kubelet

각 Node에서 실행되며, Pod의 생명주기를 관리합니다.

**주요 기능:**

- Pod Spec 수신 및 실행
- Container 상태 모니터링
- Volume 마운트
- Health Check 수행

#### Container Runtime

실제 컨테이너를 실행하는 엔진입니다.

**지원되는 Runtime:**

- containerd (권장)
- CRI-O
- Docker (deprecated, dockershim 제거됨)

#### Kube-proxy

각 Node에서 네트워크 규칙을 관리합니다.

**모드:**

- **iptables**: 기본값, iptables 규칙 사용
- **IPVS**: 고성능, 대규모 클러스터에 적합
- **userspace**: 레거시

---

## 🔧 Part 2: Custom Resource Definition (CRD)

### 1. CRD란?

Kubernetes API를 확장하여 사용자 정의 리소스를 생성할 수 있습니다.

**CRD 정의:**
```yaml
# crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.example.com
spec:
  group: example.com
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                image:
                  type: string
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 10
                port:
                  type: integer
            status:
              type: object
              properties:
                availableReplicas:
                  type: integer
                conditions:
                  type: array
                  items:
                    type: object
                    properties:
                      type:
                        type: string
                      status:
                        type: string
                      lastTransitionTime:
                        type: string
                        format: date-time
      subresources:
        status: {}  # /status 서브리소스 활성화
      additionalPrinterColumns:
        - name: Image
          type: string
          jsonPath: .spec.image
        - name: Replicas
          type: integer
          jsonPath: .spec.replicas
        - name: Available
          type: integer
          jsonPath: .status.availableReplicas
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
    shortNames:
      - app
```

```bash
# CRD 생성
kubectl apply -f crd.yaml

# CRD 확인
kubectl get crd applications.example.com
kubectl describe crd applications.example.com
```

### 2. Custom Resource 사용

```yaml
# my-app.yaml
apiVersion: example.com/v1
kind: Application
metadata:
  name: my-web-app
spec:
  image: nginx:1.25
  replicas: 3
  port: 80
```

```bash
# CR 생성
kubectl apply -f my-app.yaml

# CR 조회
kubectl get applications
kubectl get app my-web-app -o yaml

# 간편 조회 (additionalPrinterColumns)
kubectl get app
# NAME          IMAGE         REPLICAS   AVAILABLE   AGE
# my-web-app    nginx:1.25    3          3           5m
```

### 3. Validation & Defaulting

**Validation (검증):**
```yaml
schema:
  openAPIV3Schema:
    properties:
      spec:
        properties:
          replicas:
            type: integer
            minimum: 1
            maximum: 100
          image:
            type: string
            pattern: '^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*:[a-z0-9]+([\-\.\_]{1}[a-z0-9]+)*$'
        required:
          - image
          - replicas
```

**Defaulting (기본값 설정):**
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
# ...
spec:
  versions:
    - name: v1
      schema:
        openAPIV3Schema:
          properties:
            spec:
              properties:
                replicas:
                  type: integer
                  default: 1  # 기본값
```

---

## 🎮 Part 3: Kubernetes Controller 개발

### 1. Controller 패턴

**Controller Loop (Reconcile Loop):**
```
   ┌──────────────────┐
   │  Desired State   │ (CR Spec)
   └────────┬─────────┘
            │
            ↓
   ┌──────────────────┐
   │   Reconcile      │ ← Controller Logic
   └────────┬─────────┘
            │
            ↓
   ┌──────────────────┐
   │  Current State   │ (Actual Resources)
   └──────────────────┘
```

### 2. Controller 구조

**핵심 컴포넌트:**

- **Informer**: Kubernetes API를 Watch하고 캐시 유지
- **Lister**: 캐시에서 리소스 조회
- **Workqueue**: 처리할 작업 큐
- **EventHandler**: 리소스 변경 시 호출되는 함수

```go
// controller.go
package main

import (
    "fmt"
    "time"

    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/api/errors"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    utilruntime "k8s.io/apimachinery/pkg/util/runtime"
    "k8s.io/apimachinery/pkg/util/wait"
    appsinformers "k8s.io/client-go/informers/apps/v1"
    "k8s.io/client-go/kubernetes"
    appslisters "k8s.io/client-go/listers/apps/v1"
    "k8s.io/client-go/tools/cache"
    "k8s.io/client-go/util/workqueue"
    "k8s.io/klog/v2"
)

type Controller struct {
    kubeclientset     kubernetes.Interface
    deploymentsLister appslisters.DeploymentLister
    deploymentsSynced cache.InformerSynced
    workqueue         workqueue.RateLimitingInterface
}

func NewController(
    kubeclientset kubernetes.Interface,
    deploymentInformer appsinformers.DeploymentInformer) *Controller {

    controller := &Controller{
        kubeclientset:     kubeclientset,
        deploymentsLister: deploymentInformer.Lister(),
        deploymentsSynced: deploymentInformer.Informer().HasSynced,
        workqueue: workqueue.NewNamedRateLimitingQueue(
            workqueue.DefaultControllerRateLimiter(),
            "Deployments"),
    }

    // Event Handlers 설정
    deploymentInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
        AddFunc: controller.enqueueDeployment,
        UpdateFunc: func(old, new interface{}) {
            controller.enqueueDeployment(new)
        },
        DeleteFunc: controller.enqueueDeployment,
    })

    return controller
}

func (c *Controller) enqueueDeployment(obj interface{}) {
    var key string
    var err error
    if key, err = cache.MetaNamespaceKeyFunc(obj); err != nil {
        utilruntime.HandleError(err)
        return
    }
    c.workqueue.Add(key)
}

func (c *Controller) Run(workers int, stopCh <-chan struct{}) error {
    defer utilruntime.HandleCrash()
    defer c.workqueue.ShutDown()

    klog.Info("Starting controller")

    // Informer 캐시 동기화 대기
    klog.Info("Waiting for informer caches to sync")
    if ok := cache.WaitForCacheSync(stopCh, c.deploymentsSynced); !ok {
        return fmt.Errorf("failed to wait for caches to sync")
    }

    klog.Info("Starting workers")
    // Worker 시작
    for i := 0; i < workers; i++ {
        go wait.Until(c.runWorker, time.Second, stopCh)
    }

    klog.Info("Started workers")
    <-stopCh
    klog.Info("Shutting down workers")

    return nil
}

func (c *Controller) runWorker() {
    for c.processNextWorkItem() {
    }
}

func (c *Controller) processNextWorkItem() bool {
    obj, shutdown := c.workqueue.Get()

    if shutdown {
        return false
    }

    err := func(obj interface{}) error {
        defer c.workqueue.Done(obj)
        var key string
        var ok bool

        if key, ok = obj.(string); !ok {
            c.workqueue.Forget(obj)
            utilruntime.HandleError(fmt.Errorf("expected string in workqueue but got %#v", obj))
            return nil
        }

        // Reconcile 로직 실행
        if err := c.syncHandler(key); err != nil {
            c.workqueue.AddRateLimited(key)
            return fmt.Errorf("error syncing '%s': %s, requeuing", key, err.Error())
        }

        c.workqueue.Forget(obj)
        klog.Infof("Successfully synced '%s'", key)
        return nil
    }(obj)

    if err != nil {
        utilruntime.HandleError(err)
        return true
    }

    return true
}

func (c *Controller) syncHandler(key string) error {
    // key를 namespace/name으로 분리
    namespace, name, err := cache.SplitMetaNamespaceKey(key)
    if err != nil {
        utilruntime.HandleError(fmt.Errorf("invalid resource key: %s", key))
        return nil
    }

    // Lister를 사용하여 캐시에서 Deployment 조회
    deployment, err := c.deploymentsLister.Deployments(namespace).Get(name)
    if err != nil {
        if errors.IsNotFound(err) {
            klog.Infof("Deployment %s/%s has been deleted", namespace, name)
            return nil
        }
        return err
    }

    // 비즈니스 로직 (예: 레이블 확인 및 업데이트)
    if deployment.Labels["managed-by"] != "my-controller" {
        klog.Infof("Deployment %s/%s is not managed by this controller", namespace, name)
        return nil
    }

    klog.Infof("Processing deployment: %s/%s", namespace, name)
    // 여기에 실제 Reconcile 로직 작성

    return nil
}
```

### 3. Informer & Workqueue 상세

**Informer의 역할:**
```
┌─────────────────┐
│  API Server     │
└────────┬────────┘
         │ Watch
         ↓
┌─────────────────┐
│   Informer      │
│  - Reflector    │ ← API 변경 사항 감지
│  - Store/Cache  │ ← 로컬 캐시 유지
│  - Event Handler│ ← 이벤트 처리
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│   Workqueue     │
└─────────────────┘
```

**Workqueue의 특징 (2025 Best Practice):**

- **Deduplication**: 같은 키를 중복 처리하지 않음
- **Rate Limiting**: 실패 시 백오프 지연
- **Retry**: 실패한 항목 재시도
- **Concurrency**: 여러 Worker가 병렬 처리

---

## 🤖 Part 4: Kubernetes Operator

### 1. Operator 패턴

Operator = CRD + Custom Controller

**Operator의 역할:**

- 애플리케이션 배포
- 업그레이드 자동화
- 백업 및 복구
- 스케일링

### 2. Operator SDK로 Operator 개발

```bash
# Operator SDK 설치
brew install operator-sdk

# Operator 프로젝트 초기화
mkdir myapp-operator
cd myapp-operator
operator-sdk init --domain example.com --repo github.com/myorg/myapp-operator

# API (CRD) 생성
operator-sdk create api \
  --group apps \
  --version v1 \
  --kind MyApp \
  --resource --controller

# 생성된 파일 구조
# api/v1/myapp_types.go      ← CRD 정의
# controllers/myapp_controller.go ← Controller 로직
```

**CRD 타입 정의:**
```go
// api/v1/myapp_types.go
package v1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// MyAppSpec defines the desired state of MyApp
type MyAppSpec struct {
    // +kubebuilder:validation:Required
    // +kubebuilder:validation:MinLength=1
    Image string `json:"image"`

    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=10
    // +kubebuilder:default=1
    Replicas int32 `json:"replicas,omitempty"`

    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=65535
    Port int32 `json:"port,omitempty"`
}

// MyAppStatus defines the observed state of MyApp
type MyAppStatus struct {
    AvailableReplicas int32 `json:"availableReplicas"`
    Conditions        []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Image",type=string,JSONPath=`.spec.image`
// +kubebuilder:printcolumn:name="Replicas",type=integer,JSONPath=`.spec.replicas`
// +kubebuilder:printcolumn:name="Available",type=integer,JSONPath=`.status.availableReplicas`

// MyApp is the Schema for the myapps API
type MyApp struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   MyAppSpec   `json:"spec,omitempty"`
    Status MyAppStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// MyAppList contains a list of MyApp
type MyAppList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items           []MyApp `json:"items"`
}
```

**Controller 로직:**
```go
// controllers/myapp_controller.go
package controllers

import (
    "context"

    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/api/errors"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/log"

    appsv1alpha1 "github.com/myorg/myapp-operator/api/v1"
)

// MyAppReconciler reconciles a MyApp object
type MyAppReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=apps.example.com,resources=myapps,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=apps.example.com,resources=myapps/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete

// Reconcile is part of the main kubernetes reconciliation loop
func (r *MyAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    logger := log.FromContext(ctx)

    // MyApp 리소스 조회
    var myApp appsv1alpha1.MyApp
    if err := r.Get(ctx, req.NamespacedName, &myApp); err != nil {
        if errors.IsNotFound(err) {
            logger.Info("MyApp resource not found. Ignoring since object must be deleted")
            return ctrl.Result{}, nil
        }
        logger.Error(err, "Failed to get MyApp")
        return ctrl.Result{}, err
    }

    // Deployment 생성 또는 업데이트
    deployment := r.deploymentForMyApp(&myApp)
    found := &appsv1.Deployment{}
    err := r.Get(ctx, client.ObjectKey{Name: deployment.Name, Namespace: deployment.Namespace}, found)
    if err != nil && errors.IsNotFound(err) {
        logger.Info("Creating a new Deployment", "Deployment.Namespace", deployment.Namespace, "Deployment.Name", deployment.Name)
        if err = r.Create(ctx, deployment); err != nil {
            logger.Error(err, "Failed to create new Deployment", "Deployment.Namespace", deployment.Namespace, "Deployment.Name", deployment.Name)
            return ctrl.Result{}, err
        }
        return ctrl.Result{Requeue: true}, nil
    } else if err != nil {
        logger.Error(err, "Failed to get Deployment")
        return ctrl.Result{}, err
    }

    // Deployment 업데이트 (spec.replicas 또는 image 변경)
    if *found.Spec.Replicas != myApp.Spec.Replicas || found.Spec.Template.Spec.Containers[0].Image != myApp.Spec.Image {
        found.Spec.Replicas = &myApp.Spec.Replicas
        found.Spec.Template.Spec.Containers[0].Image = myApp.Spec.Image
        if err = r.Update(ctx, found); err != nil {
            logger.Error(err, "Failed to update Deployment", "Deployment.Namespace", found.Namespace, "Deployment.Name", found.Name)
            return ctrl.Result{}, err
        }
        logger.Info("Updated Deployment", "Deployment.Namespace", found.Namespace, "Deployment.Name", found.Name)
        return ctrl.Result{Requeue: true}, nil
    }

    // Status 업데이트
    if myApp.Status.AvailableReplicas != found.Status.AvailableReplicas {
        myApp.Status.AvailableReplicas = found.Status.AvailableReplicas
        if err := r.Status().Update(ctx, &myApp); err != nil {
            logger.Error(err, "Failed to update MyApp status")
            return ctrl.Result{}, err
        }
    }

    return ctrl.Result{}, nil
}

func (r *MyAppReconciler) deploymentForMyApp(m *appsv1alpha1.MyApp) *appsv1.Deployment {
    labels := map[string]string{
        "app":        m.Name,
        "managed-by": "myapp-operator",
    }

    dep := &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      m.Name,
            Namespace: m.Namespace,
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &m.Spec.Replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: labels,
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: labels,
                },
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{{
                        Name:  "app",
                        Image: m.Spec.Image,
                        Ports: []corev1.ContainerPort{{
                            ContainerPort: m.Spec.Port,
                        }},
                    }},
                },
            },
        },
    }

    // Owner Reference 설정 (MyApp 삭제 시 Deployment도 삭제)
    ctrl.SetControllerReference(m, dep, r.Scheme)

    return dep
}

// SetupWithManager sets up the controller with the Manager.
func (r *MyAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&appsv1alpha1.MyApp{}).
        Owns(&appsv1.Deployment{}).  // Deployment 변경도 감지
        Complete(r)
}
```

**빌드 및 배포:**
```bash
# CRD 생성
make manifests
kubectl apply -f config/crd/bases/

# Operator 빌드 및 푸시
make docker-build docker-push IMG=myregistry/myapp-operator:v1.0.0

# Operator 배포
make deploy IMG=myregistry/myapp-operator:v1.0.0
```

---

## 📚 참고 자료

### 공식 문서
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Controller Development Guide](https://kubernetes.io/docs/concepts/architecture/controller/)
- [CRD Documentation](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)

### Controller 개발
- [client-go Examples](https://github.com/kubernetes/client-go/tree/master/examples)
- [sample-controller](https://github.com/kubernetes/sample-controller)
- [Informers Deep Dive (2025)](https://medium.com/@dhruvbhl/informers-listers-workqueues-the-brain-behind-your-controller-f5b0967026de)

### Operator SDK
- [Operator SDK Documentation](https://sdk.operatorframework.io/)
- [Operator Framework](https://operatorframework.io/)
- [Kubebuilder Book](https://book.kubebuilder.io/)

---

## ✅ 학습 체크리스트

- [ ] Kubernetes Control Plane 아키텍처 이해
- [ ] etcd 백업 및 복구
- [ ] CRD 정의 및 생성
- [ ] Informer, Lister, Workqueue 이해
- [ ] Raw Kubernetes Controller 개발 (client-go)
- [ ] Operator SDK로 Operator 개발
- [ ] Owner Reference 및 Finalizer 사용
- [ ] Admission Controller 구현
- [ ] 대규모 클러스터 운영 및 최적화

---

## 🎓 다음 단계

Kubernetes 심화를 마스터한 후:
- [Ch2. ClusterAPI & Ironic](./Ch2.ClusterAPI_Ironic.md)로 진행
- 또는 [README](./README.md)로 돌아가서 학습 로드맵 확인
