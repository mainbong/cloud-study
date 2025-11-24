# Ch4. Cloud Native 컴퓨팅

## 📋 개요

Cloud Native 컴퓨팅은 컨테이너 기반의 분산 시스템을 구축하고 운영하는 현대적인 접근 방식입니다. 본 장에서는 Kubernetes Operator 패턴의 핵심 개념인 Custom Resource Definitions (CRD)와 Controller를 중심으로, 선언적 API 설계, Reconciliation Loop, 그리고 운영 지식을 코드로 표현하는 방법을 학습합니다.

2025년 현재, Kubernetes 1.30+ 환경에서 **CEL (Common Expression Language) 검증**, **Server-Side Apply (SSA)**, 그리고 **controller-runtime 0.21.0**을 기반으로 한 Operator 개발이 표준이 되었습니다.

## 🎯 학습 목표

1. **Operator 패턴 이해**
   - Operator란 무엇인가
   - Controller vs Operator 차이점
   - 운영 지식의 코드화

2. **CRD (Custom Resource Definition)**
   - CRD 설계 원칙
   - Spec과 Status 분리
   - CEL 검증 (2025 필수)
   - Subresource (status, scale)

3. **Controller 개발**
   - Reconciliation Loop 패턴
   - Informer 및 Workqueue
   - Event-driven 아키텍처
   - 에러 처리 및 재시도

4. **실전 Operator 개발**
   - Kubebuilder 스캐폴딩
   - RBAC 권한 설정
   - Finalizer를 통한 리소스 정리
   - Status Conditions

5. **배포 및 운영**
   - Operator Lifecycle Manager (OLM)
   - Webhook (Admission & Conversion)
   - 메트릭 및 모니터링
   - 업그레이드 전략

---

## Part 1: Operator 패턴 소개

### 1.1 Operator란?

**정의 (Kubernetes 공식):**
> Operators are software extensions to Kubernetes that make use of custom resources to manage applications and their components. Operators follow Kubernetes principles, notably the control loop.

**핵심 개념:**
```
Operator = Custom Resource Definition (CRD) + Controller
```

**Operator의 역할:**
- **운영 지식의 자동화**: 사람이 수행하던 운영 작업을 코드로 구현
- **선언적 관리**: 원하는 상태를 정의하면 Operator가 자동으로 조정
- **지속적 조정**: 장애 복구, 업그레이드, 스케일링 자동화

### 1.2 Controller vs Operator

| 특징 | Controller | Operator |
|------|-----------|----------|
| **정의** | Built-in 리소스 관리 | Custom 리소스 관리 |
| **예시** | Deployment Controller | MySQL Operator |
| **CRD** | 불필요 | 필수 |
| **복잡도** | 낮음 | 높음 (도메인 지식 필요) |
| **사용 사례** | Pod, Service 관리 | DB, Cache, 앱 운영 |

**Controller 예시 (내장):**
```
Deployment Controller:
  Watch: Deployment
  Reconcile: ReplicaSet 생성/업데이트
```

**Operator 예시 (커스텀):**
```
MySQL Operator:
  Watch: MySQL CRD
  Reconcile:
    - StatefulSet 생성
    - PVC 생성
    - 백업 스케줄링
    - 복제 설정
    - 업그레이드 수행
```

### 1.3 Operator Capability Levels

**성숙도 모델 (Operator Framework):**
```
Level 1: Basic Install
  └─ CRD 생성, 기본 배포

Level 2: Seamless Upgrades
  └─ 자동 업그레이드

Level 3: Full Lifecycle
  └─ 백업, 복원, 모니터링

Level 4: Deep Insights
  └─ 메트릭, 알러트, 로그 통합

Level 5: Auto Pilot
  └─ 자동 스케일링, 자가 치유, 튜닝
```

---

## Part 2: CRD (Custom Resource Definition)

### 2.1 CRD 기본 구조

**CRD YAML:**
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mysqls.database.example.com
spec:
  group: database.example.com
  names:
    kind: MySQL
    listKind: MySQLList
    plural: mysqls
    singular: mysql
    shortNames:
      - msql
  scope: Namespaced
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
              required:
                - version
                - storageSize
              properties:
                version:
                  type: string
                  enum:
                    - "8.0"
                    - "8.4"
                  description: MySQL version
                storageSize:
                  type: string
                  pattern: '^[0-9]+Gi$'
                  description: Storage size (e.g., 10Gi)
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 10
                  default: 1
            status:
              type: object
              properties:
                phase:
                  type: string
                  enum:
                    - Pending
                    - Running
                    - Failed
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
                      reason:
                        type: string
                      message:
                        type: string
      subresources:
        status: {}  # /status subresource 활성화
        scale:      # kubectl scale 지원
          specReplicasPath: .spec.replicas
          statusReplicasPath: .status.replicas
      additionalPrinterColumns:
        - name: Version
          type: string
          jsonPath: .spec.version
        - name: Status
          type: string
          jsonPath: .status.phase
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
```

### 2.2 CEL 검증 (2025 필수)

**CEL (Common Expression Language):**
2025년 Kubernetes 1.25+에서 강력히 권장되는 선언적 검증 방법입니다.

```yaml
spec:
  versions:
    - name: v1
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                version:
                  type: string
                storageSize:
                  type: string
                replicas:
                  type: integer
              # CEL 검증 규칙
              x-kubernetes-validations:
                # replicas가 1이면 storageSize >= 10Gi
                - rule: "self.replicas == 1 || int(self.storageSize.replace('Gi', '')) >= 20"
                  message: "Multi-replica setup requires at least 20Gi storage"

                # version 8.4는 replicas >= 3 필요
                - rule: "self.version != '8.4' || self.replicas >= 3"
                  message: "MySQL 8.4 requires at least 3 replicas for HA"

                # storageSize 증가만 허용 (감소 불가)
                - rule: "!has(oldSelf.storageSize) || int(self.storageSize.replace('Gi', '')) >= int(oldSelf.storageSize.replace('Gi', ''))"
                  message: "Storage size cannot be decreased"
```

### 2.3 Custom Resource 예시

**MySQL CR (생성 요청):**
```yaml
apiVersion: database.example.com/v1
kind: MySQL
metadata:
  name: my-database
  namespace: production
spec:
  version: "8.0"
  storageSize: "50Gi"
  replicas: 3
  backup:
    enabled: true
    schedule: "0 2 * * *"  # 매일 새벽 2시
    retention: 7
```

**Controller가 생성한 Status:**
```yaml
status:
  phase: Running
  replicas: 3
  conditions:
    - type: Ready
      status: "True"
      lastTransitionTime: "2025-11-24T10:00:00Z"
      reason: AllPodsReady
      message: "All 3 replicas are running"
    - type: BackupScheduled
      status: "True"
      lastTransitionTime: "2025-11-24T10:01:00Z"
      reason: CronJobCreated
      message: "Backup CronJob created successfully"
  masterPod: my-database-0
  lastBackup: "2025-11-24T02:00:00Z"
```

---

## Part 3: Controller 개발

### 3.1 Reconciliation Loop

**핵심 패턴:**
```
┌──────────────────────────────────────────┐
│         Kubernetes API Server            │
└────────────┬─────────────────────────────┘
             │ Watch Events
             │ (Add, Update, Delete)
┌────────────▼─────────────────────────────┐
│           Informer                        │
│  - Local Cache                            │
│  - Event Handler                          │
└────────────┬─────────────────────────────┘
             │ Enqueue
┌────────────▼─────────────────────────────┐
│          Workqueue                        │
│  - Rate Limiting                          │
│  - Retry Logic                            │
└────────────┬─────────────────────────────┘
             │ Dequeue
┌────────────▼─────────────────────────────┐
│    Reconcile() Function                   │
│  1. Get Current State (CR, Pods, etc.)   │
│  2. Compare with Desired State           │
│  3. Take Actions (Create/Update/Delete)  │
│  4. Update Status                         │
│  5. Return (Requeue or Done)             │
└───────────────────────────────────────────┘
```

### 3.2 Reconcile 함수 구조 (Go)

```go
package controllers

import (
    "context"
    "fmt"
    "time"

    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/api/errors"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/log"

    databasev1 "example.com/mysql-operator/api/v1"
)

type MySQLReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=database.example.com,resources=mysqls,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=database.example.com,resources=mysqls/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=database.example.com,resources=mysqls/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=statefulsets,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=persistentvolumeclaims,verbs=get;list;watch

func (r *MySQLReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    logger := log.FromContext(ctx)
    logger.Info("Reconciling MySQL", "name", req.Name, "namespace", req.Namespace)

    // 1. Fetch the MySQL instance
    mysql := &databasev1.MySQL{}
    if err := r.Get(ctx, req.NamespacedName, mysql); err != nil {
        if errors.IsNotFound(err) {
            // Object not found, probably deleted
            logger.Info("MySQL resource not found, ignoring")
            return ctrl.Result{}, nil
        }
        // Error reading the object
        logger.Error(err, "Failed to get MySQL")
        return ctrl.Result{}, err
    }

    // 2. Check if the resource is being deleted (Finalizer pattern)
    if mysql.ObjectMeta.DeletionTimestamp.IsZero() {
        // Not being deleted, ensure finalizer
        if !containsString(mysql.ObjectMeta.Finalizers, "mysql.database.example.com/finalizer") {
            mysql.ObjectMeta.Finalizers = append(mysql.ObjectMeta.Finalizers, "mysql.database.example.com/finalizer")
            if err := r.Update(ctx, mysql); err != nil {
                return ctrl.Result{}, err
            }
        }
    } else {
        // Being deleted
        if containsString(mysql.ObjectMeta.Finalizers, "mysql.database.example.com/finalizer") {
            // Perform cleanup
            if err := r.cleanupMySQL(ctx, mysql); err != nil {
                return ctrl.Result{}, err
            }

            // Remove finalizer
            mysql.ObjectMeta.Finalizers = removeString(mysql.ObjectMeta.Finalizers, "mysql.database.example.com/finalizer")
            if err := r.Update(ctx, mysql); err != nil {
                return ctrl.Result{}, err
            }
        }
        return ctrl.Result{}, nil
    }

    // 3. Reconcile StatefulSet
    if err := r.reconcileStatefulSet(ctx, mysql); err != nil {
        logger.Error(err, "Failed to reconcile StatefulSet")
        r.updateStatus(ctx, mysql, "Failed", err.Error())
        return ctrl.Result{RequeueAfter: 30 * time.Second}, err
    }

    // 4. Reconcile Service
    if err := r.reconcileService(ctx, mysql); err != nil {
        logger.Error(err, "Failed to reconcile Service")
        return ctrl.Result{RequeueAfter: 30 * time.Second}, err
    }

    // 5. Update Status
    if err := r.updateStatus(ctx, mysql, "Running", "MySQL is running"); err != nil {
        logger.Error(err, "Failed to update status")
        return ctrl.Result{}, err
    }

    logger.Info("Reconciliation completed successfully")
    return ctrl.Result{}, nil
}

func (r *MySQLReconciler) reconcileStatefulSet(ctx context.Context, mysql *databasev1.MySQL) error {
    // Desired StatefulSet
    desired := r.createStatefulSet(mysql)

    // Check if StatefulSet exists
    found := &appsv1.StatefulSet{}
    err := r.Get(ctx, client.ObjectKeyFromObject(desired), found)

    if err != nil && errors.IsNotFound(err) {
        // Create
        if err := ctrl.SetControllerReference(mysql, desired, r.Scheme); err != nil {
            return err
        }
        return r.Create(ctx, desired)
    } else if err != nil {
        return err
    }

    // Update if necessary
    if found.Spec.Replicas == nil || *found.Spec.Replicas != *desired.Spec.Replicas {
        found.Spec.Replicas = desired.Spec.Replicas
        return r.Update(ctx, found)
    }

    return nil
}

func (r *MySQLReconciler) createStatefulSet(mysql *databasev1.MySQL) *appsv1.StatefulSet {
    labels := map[string]string{
        "app": "mysql",
        "instance": mysql.Name,
    }

    return &appsv1.StatefulSet{
        ObjectMeta: metav1.ObjectMeta{
            Name:      mysql.Name,
            Namespace: mysql.Namespace,
            Labels:    labels,
        },
        Spec: appsv1.StatefulSetSpec{
            Replicas: &mysql.Spec.Replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: labels,
            },
            ServiceName: mysql.Name,
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: labels,
                },
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{
                        {
                            Name:  "mysql",
                            Image: fmt.Sprintf("mysql:%s", mysql.Spec.Version),
                            Env: []corev1.EnvVar{
                                {
                                    Name:  "MYSQL_ROOT_PASSWORD",
                                    Value: "changeme",  // Should use Secret
                                },
                            },
                            Ports: []corev1.ContainerPort{
                                {
                                    Name:          "mysql",
                                    ContainerPort: 3306,
                                },
                            },
                            VolumeMounts: []corev1.VolumeMount{
                                {
                                    Name:      "data",
                                    MountPath: "/var/lib/mysql",
                                },
                            },
                        },
                    },
                },
            },
            VolumeClaimTemplates: []corev1.PersistentVolumeClaim{
                {
                    ObjectMeta: metav1.ObjectMeta{
                        Name: "data",
                    },
                    Spec: corev1.PersistentVolumeClaimSpec{
                        AccessModes: []corev1.PersistentVolumeAccessMode{
                            corev1.ReadWriteOnce,
                        },
                        Resources: corev1.VolumeResourceRequirements{
                            Requests: corev1.ResourceList{
                                corev1.ResourceStorage: resource.MustParse(mysql.Spec.StorageSize),
                            },
                        },
                    },
                },
            },
        },
    }
}

func (r *MySQLReconciler) updateStatus(ctx context.Context, mysql *databasev1.MySQL, phase, message string) error {
    mysql.Status.Phase = phase
    mysql.Status.Conditions = []metav1.Condition{
        {
            Type:               "Ready",
            Status:             metav1.ConditionTrue,
            LastTransitionTime: metav1.Now(),
            Reason:             phase,
            Message:            message,
        },
    }
    return r.Status().Update(ctx, mysql)
}

func (r *MySQLReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&databasev1.MySQL{}).
        Owns(&appsv1.StatefulSet{}).
        Owns(&corev1.Service{}).
        Complete(r)
}

// Helper functions
func containsString(slice []string, s string) bool {
    for _, item := range slice {
        if item == s {
            return true
        }
    }
    return false
}

func removeString(slice []string, s string) []string {
    result := []string{}
    for _, item := range slice {
        if item != s {
            result = append(result, item)
        }
    }
    return result
}
```

---

## Part 4: Kubebuilder로 Operator 개발

### 4.1 Kubebuilder 초기화

```bash
# 1. Kubebuilder 설치
curl -L -o kubebuilder https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)
chmod +x kubebuilder && sudo mv kubebuilder /usr/local/bin/

# 2. 프로젝트 초기화
mkdir mysql-operator && cd mysql-operator
kubebuilder init --domain example.com --repo example.com/mysql-operator

# 3. API (CRD) 생성
kubebuilder create api --group database --version v1 --kind MySQL

# Create Resource [y/n]: y
# Create Controller [y/n]: y

# 생성된 파일 구조:
# mysql-operator/
# ├── api/
# │   └── v1/
# │       ├── mysql_types.go       # CRD 정의
# │       └── zz_generated.deepcopy.go
# ├── internal/controller/
# │   └── mysql_controller.go      # Controller 로직
# ├── config/
# │   ├── crd/                     # CRD YAML
# │   ├── rbac/                    # RBAC 설정
# │   ├── manager/                 # Deployment
# │   └── samples/                 # CR 예시
# ├── Dockerfile
# ├── Makefile
# └── main.go
```

### 4.2 CRD 타입 정의 (api/v1/mysql_types.go)

```go
package v1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// MySQLSpec defines the desired state of MySQL
type MySQLSpec struct {
    // +kubebuilder:validation:Enum=8.0;8.4
    // +kubebuilder:validation:Required
    Version string `json:"version"`

    // +kubebuilder:validation:Pattern=`^[0-9]+Gi$`
    // +kubebuilder:validation:Required
    StorageSize string `json:"storageSize"`

    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=10
    // +kubebuilder:default=1
    Replicas int32 `json:"replicas,omitempty"`

    // Backup configuration
    Backup *BackupSpec `json:"backup,omitempty"`
}

type BackupSpec struct {
    Enabled   bool   `json:"enabled"`
    Schedule  string `json:"schedule"`     // Cron format
    Retention int    `json:"retention"`    // Days
}

// MySQLStatus defines the observed state of MySQL
type MySQLStatus struct {
    // +kubebuilder:validation:Enum=Pending;Running;Failed
    Phase string `json:"phase,omitempty"`

    Conditions []metav1.Condition `json:"conditions,omitempty"`

    Replicas     int32  `json:"replicas,omitempty"`
    MasterPod    string `json:"masterPod,omitempty"`
    LastBackup   string `json:"lastBackup,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:subresource:scale:specpath=.spec.replicas,statuspath=.status.replicas
// +kubebuilder:printcolumn:name="Version",type=string,JSONPath=`.spec.version`
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
// +kubebuilder:resource:shortName=msql

// MySQL is the Schema for the mysqls API
type MySQL struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   MySQLSpec   `json:"spec,omitempty"`
    Status MySQLStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// MySQLList contains a list of MySQL
type MySQLList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items           []MySQL `json:"items"`
}

func init() {
    SchemeBuilder.Register(&MySQL{}, &MySQLList{})
}
```

### 4.3 빌드 및 배포

```bash
# 1. CRD 생성 (manifests 생성)
make manifests

# 2. 로컬 테스트 (클러스터 외부에서 실행)
make install  # CRD를 클러스터에 설치
make run      # Controller 로컬 실행

# 3. Docker 이미지 빌드
make docker-build docker-push IMG=myregistry/mysql-operator:v1.0.0

# 4. 클러스터에 배포
make deploy IMG=myregistry/mysql-operator:v1.0.0

# 5. CR 생성 테스트
kubectl apply -f config/samples/database_v1_mysql.yaml

# 6. 로그 확인
kubectl logs -n mysql-operator-system deployment/mysql-operator-controller-manager -f

# 7. 정리
make undeploy
```

---

## Part 5: 고급 주제

### 5.1 Webhook (Admission & Conversion)

**Validating Webhook:**
```go
// +kubebuilder:webhook:path=/validate-database-example-com-v1-mysql,mutating=false,failurePolicy=fail,groups=database.example.com,resources=mysqls,verbs=create;update,versions=v1,name=vmysql.kb.io,admissionReviewVersions=v1

func (r *MySQL) ValidateCreate() (admission.Warnings, error) {
    // 생성 시 검증
    if r.Spec.Replicas > 1 && !strings.HasSuffix(r.Spec.StorageSize, "Gi") {
        return nil, fmt.Errorf("invalid storage size format")
    }
    return nil, nil
}

func (r *MySQL) ValidateUpdate(old runtime.Object) (admission.Warnings, error) {
    // 업데이트 시 검증
    oldMySQL := old.(*MySQL)

    // Storage 감소 방지
    oldSize, _ := strconv.Atoi(strings.TrimSuffix(oldMySQL.Spec.StorageSize, "Gi"))
    newSize, _ := strconv.Atoi(strings.TrimSuffix(r.Spec.StorageSize, "Gi"))

    if newSize < oldSize {
        return nil, fmt.Errorf("storage size cannot be decreased")
    }

    return nil, nil
}
```

**Mutating Webhook:**
```go
// +kubebuilder:webhook:path=/mutate-database-example-com-v1-mysql,mutating=true,failurePolicy=fail,groups=database.example.com,resources=mysqls,verbs=create;update,versions=v1,name=mmysql.kb.io,admissionReviewVersions=v1

func (r *MySQL) Default() {
    // 기본값 설정
    if r.Spec.Replicas == 0 {
        r.Spec.Replicas = 1
    }

    if r.Spec.Backup == nil {
        r.Spec.Backup = &BackupSpec{
            Enabled:   false,
            Schedule:  "0 2 * * *",
            Retention: 7,
        }
    }
}
```

### 5.2 메트릭 및 모니터링 (2025)

**controller-runtime 0.21.0+ 메트릭:**
```go
import (
    "sigs.k8s.io/controller-runtime/pkg/metrics"
    "github.com/prometheus/client_golang/prometheus"
)

var (
    mysqlReconcileTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "mysql_reconcile_total",
            Help: "Total number of reconciliations",
        },
        []string{"namespace", "name", "result"},
    )

    mysqlReconcileDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "mysql_reconcile_duration_seconds",
            Help: "Reconciliation duration",
        },
        []string{"namespace", "name"},
    )
)

func init() {
    metrics.Registry.MustRegister(mysqlReconcileTotal, mysqlReconcileDuration)
}

func (r *MySQLReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    start := time.Now()
    defer func() {
        duration := time.Since(start).Seconds()
        mysqlReconcileDuration.WithLabelValues(req.Namespace, req.Name).Observe(duration)
    }()

    // ... reconcile logic ...

    mysqlReconcileTotal.WithLabelValues(req.Namespace, req.Name, "success").Inc()
    return ctrl.Result{}, nil
}
```

---

## 📚 참고 자료

### 공식 문서
1. [Operator Pattern - Kubernetes](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
2. [Custom Resources - Kubernetes](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
3. [Kubebuilder Book](https://book.kubebuilder.io/)
4. [Operator SDK Documentation](https://sdk.operatorframework.io/)

### 2025 Best Practices
1. [Kubernetes Operators in 2025: Best Practices](https://outerbyte.com/kubernetes-operators-2025-guide/)
2. [Operator Framework 2025 Updates](https://notes.kodekloud.com/docs/CKA-Certification-Course-Certified-Kubernetes-Administrator/Security/Operator-Framework-2025-Updates)
3. [Standardizing CRD Condition Metrics (2025)](https://sourcehawk.medium.com/kubernetes-operator-metrics-411ca81833ab)

---

## ✅ 학습 체크리스트

- [ ] Operator 패턴의 핵심 개념 이해
- [ ] CRD 설계 및 CEL 검증 작성
- [ ] Reconciliation Loop 구현
- [ ] Kubebuilder로 Operator 스캐폴딩
- [ ] Finalizer를 통한 리소스 정리
- [ ] Webhook 구현 (Validating, Mutating)
- [ ] 메트릭 및 모니터링 통합

---

**마지막 업데이트:** 2025-11-24
**다음 챕터:** [Ch5.클라우드_인프라_설계.md](./Ch5.클라우드_인프라_설계.md)
