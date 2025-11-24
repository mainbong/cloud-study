# Chapter 6: Kubernetes Operator 심화

## 📋 개요

본 Chapter에서는 Kubernetes Operator의 고급 주제들을 다룹니다. Ch4에서 기본적인 Operator 패턴과 CRD, Controller를 학습했다면, 이번 장에서는 실제 프로덕션 환경에 배포 가능한 엔터프라이즈급 Operator를 개발하는 방법을 학습합니다.

2025년 현재, Kubernetes Operator는 단순한 자동화 도구를 넘어 mission-critical한 프로덕션 컴포넌트로 자리잡았습니다. Kubernetes 1.30+와 성숙한 controller-runtime 생태계를 활용하여 데이터베이스 운영, ML 파이프라인 오케스트레이션, 보안 제어 등 다양한 영역에서 사용되고 있습니다.

### 2025년 Operator 개발 트렌드

- **CEL Validation**: OpenAPI 스키마 수준에서 복잡한 검증 로직 표현 (Admission Webhook 없이도 가능)
- **OLMv1**: 차세대 Operator Lifecycle Manager로 ClusterExtension 도입
- **Security-First**: PodSecurity admission, 최소 RBAC, 서명된 이미지가 표준
- **Multi-Cluster**: 단일 제어 평면에서 여러 클러스터 관리가 mainstream 요구사항으로 부상
- **Observability**: Prometheus metrics, OpenTelemetry traces 통합 필수

---

## 🎯 학습 목표

이 Chapter를 완료하면 다음을 할 수 있습니다:

1. **Admission Webhooks** 구현 및 OLM 통합
   - Validating Webhook으로 커스텀 검증 로직 작성
   - Mutating Webhook으로 기본값 설정 및 리소스 변환
   - OLM의 자동 인증서 관리 이해

2. **테스트 전략** 수립 및 구현
   - Unit Test: 비즈니스 로직 검증
   - EnvTest: 실제 API Server와 통합 테스트
   - E2E Test: 전체 시나리오 검증

3. **프로덕션 배포**
   - OLM Bundle 생성 및 OperatorHub 배포
   - Multi-cluster 패턴 구현
   - Monitoring 및 Alerting 설정

4. **보안 Best Practices**
   - RBAC 최소화 원칙
   - Webhook 부작용(side effects) 처리
   - 인증서 관리 및 갱신

---

## Part 1: Admission Webhooks

### 1.1 Webhook 개요

Admission Webhooks는 리소스가 저장되기 전에 admission request를 받아 검증하거나 변경하는 HTTP 콜백입니다.

#### Webhook 타입

| 타입 | 용도 | 실행 순서 |
|------|------|----------|
| **Mutating Webhook** | 리소스 변경 (기본값 설정) | 먼저 실행 |
| **Validating Webhook** | 리소스 검증 (불변 필드 확인) | 나중에 실행 |

#### Webhook vs CEL Validation (2025)

```yaml
# 2025년 권장: CRD 수준 CEL Validation
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.db.example.com
spec:
  validation:
    openAPIV3Schema:
      properties:
        spec:
          properties:
            replicas:
              type: integer
              minimum: 1
            storageSize:
              type: string
          x-kubernetes-validations:
            # CEL로 복잡한 검증 표현 (Webhook 불필요!)
            - rule: "self.replicas == 1 || int(self.storageSize.replace('Gi', '')) >= 20"
              message: "Multi-replica setup requires at least 20Gi storage"
            - rule: "!has(oldSelf.storageSize) || self.storageSize == oldSelf.storageSize"
              message: "storageSize is immutable after creation"
```

**언제 Webhook을 사용해야 하는가?**
- CEL로 표현할 수 없는 복잡한 로직 (외부 API 호출, 다른 리소스 조회)
- 동적 기본값 설정 (현재 클러스터 상태 기반)
- Cross-resource 검증

### 1.2 Validating Webhook 구현

```go
// api/v1/database_webhook.go
package v1

import (
    "context"
    "fmt"

    "k8s.io/apimachinery/pkg/runtime"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/webhook"
    "sigs.k8s.io/controller-runtime/pkg/webhook/admission"
)

// Webhook marker - Kubebuilder가 WebhookConfiguration 생성
//+kubebuilder:webhook:path=/validate-db-example-com-v1-database,mutating=false,failurePolicy=fail,sideEffects=None,groups=db.example.com,resources=databases,verbs=create;update,versions=v1,name=vdatabase.kb.io,admissionReviewVersions=v1

type DatabaseValidator struct{}

// ValidateCreate implements webhook.Validator
func (v *DatabaseValidator) ValidateCreate(ctx context.Context, obj runtime.Object) (admission.Warnings, error) {
    db := obj.(*Database)

    // 비즈니스 로직 검증
    if db.Spec.Engine == "postgres" && db.Spec.Version < "14.0" {
        return nil, fmt.Errorf("PostgreSQL version must be 14.0 or higher")
    }

    // 외부 리소스 조회 예제 (CEL로 불가능)
    if err := v.validateStorageClass(ctx, db.Spec.StorageClass); err != nil {
        return nil, err
    }

    return nil, nil
}

// ValidateUpdate implements webhook.Validator
func (v *DatabaseValidator) ValidateUpdate(ctx context.Context, oldObj, newObj runtime.Object) (admission.Warnings, error) {
    oldDB := oldObj.(*Database)
    newDB := newObj.(*Database)

    // 불변 필드 검증 (CEL로도 가능하지만 Webhook이 더 복잡한 로직 표현 가능)
    if oldDB.Spec.Engine != newDB.Spec.Engine {
        return nil, fmt.Errorf("engine is immutable")
    }

    // 위험한 변경에 대한 경고 반환 (2025 신기능)
    var warnings admission.Warnings
    if oldDB.Spec.Version != newDB.Spec.Version {
        warnings = append(warnings, "Version upgrade requires manual backup verification")
    }

    return warnings, nil
}

// ValidateDelete implements webhook.Validator
func (v *DatabaseValidator) ValidateDelete(ctx context.Context, obj runtime.Object) (admission.Warnings, error) {
    db := obj.(*Database)

    // 삭제 보호 로직
    if db.Annotations["protect"] == "true" {
        return nil, fmt.Errorf("cannot delete protected database")
    }

    return nil, nil
}

func (r *Database) SetupWebhookWithManager(mgr ctrl.Manager) error {
    return ctrl.NewWebhookManagedBy(mgr).
        For(r).
        WithValidator(&DatabaseValidator{}).
        Complete()
}
```

### 1.3 Mutating Webhook 구현

```go
// api/v1/database_webhook_mutation.go

//+kubebuilder:webhook:path=/mutate-db-example-com-v1-database,mutating=true,failurePolicy=fail,sideEffects=None,groups=db.example.com,resources=databases,verbs=create;update,versions=v1,name=mdatabase.kb.io,admissionReviewVersions=v1

type DatabaseDefaulter struct {
    Client client.Client
}

// Default implements webhook.Defaulter
func (d *DatabaseDefaulter) Default(ctx context.Context, obj runtime.Object) error {
    db := obj.(*Database)

    // 기본값 설정
    if db.Spec.Replicas == 0 {
        db.Spec.Replicas = 1
    }

    if db.Spec.StorageSize == "" {
        db.Spec.StorageSize = "10Gi"
    }

    // 동적 기본값: 클러스터 상태 기반 (CEL로 불가능)
    if db.Spec.StorageClass == "" {
        defaultSC, err := d.getDefaultStorageClass(ctx)
        if err == nil {
            db.Spec.StorageClass = defaultSC
        }
    }

    // 레이블 자동 추가
    if db.Labels == nil {
        db.Labels = make(map[string]string)
    }
    db.Labels["managed-by"] = "database-operator"
    db.Labels["version"] = db.Spec.Version

    return nil
}

func (d *DatabaseDefaulter) getDefaultStorageClass(ctx context.Context) (string, error) {
    var scList storagev1.StorageClassList
    if err := d.Client.List(ctx, &scList); err != nil {
        return "", err
    }

    for _, sc := range scList.Items {
        if sc.Annotations["storageclass.kubernetes.io/is-default-class"] == "true" {
            return sc.Name, nil
        }
    }

    return "standard", nil
}
```

### 1.4 OLM Webhook 통합

OLM은 Webhook를 포함한 Operator의 인증서 생성 및 갱신을 자동으로 처리합니다.

```yaml
# config/manifests/bases/database-operator.clusterserviceversion.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: ClusterServiceVersion
metadata:
  name: database-operator.v1.0.0
spec:
  webhookdefinitions:
  - admissionReviewVersions:
    - v1
    containerPort: 443
    deploymentName: database-operator-controller-manager
    failurePolicy: Fail
    generateName: vdatabase.kb.io
    rules:
    - apiGroups:
      - db.example.com
      apiVersions:
      - v1
      operations:
      - CREATE
      - UPDATE
      resources:
      - databases
    sideEffects: None
    type: ValidatingAdmissionWebhook
    webhookPath: /validate-db-example-com-v1-database
```

**OLM 인증서 관리 (2025)**:
- 자체 서명된 CA를 각 Webhook 포함 Deployment에 자동 생성/마운트
- 인증서는 2년 후 만료되며, OLM이 자동으로 새 인증서 생성
- 사용자가 인증서 이름 또는 마운트 위치를 지정할 수 없음 (OLM 관리)

---

## Part 2: 테스트 전략

### 2.1 테스트 피라미드

```
        /\
       /E2E\       적음 (느림, 비용 높음)
      /------\
     /EnvTest\     중간 (실제 API 서버 사용)
    /----------\
   / Unit Tests \  많음 (빠름, 격리됨)
  /--------------\
```

### 2.2 Unit Tests

```go
// internal/controller/database_controller_test.go
package controller

import (
    "testing"

    "github.com/stretchr/testify/assert"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

    dbv1 "example.com/database-operator/api/v1"
)

func TestCalculateReplicas(t *testing.T) {
    tests := []struct {
        name     string
        db       *dbv1.Database
        expected int
    }{
        {
            name: "single replica for small storage",
            db: &dbv1.Database{
                Spec: dbv1.DatabaseSpec{
                    Replicas:    1,
                    StorageSize: "5Gi",
                },
            },
            expected: 1,
        },
        {
            name: "multiple replicas for large storage",
            db: &dbv1.Database{
                Spec: dbv1.DatabaseSpec{
                    Replicas:    3,
                    StorageSize: "50Gi",
                },
            },
            expected: 3,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := calculateOptimalReplicas(tt.db)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

### 2.3 EnvTest Integration Tests

EnvTest는 controller-runtime 프로젝트의 라이브러리로, 실제 Kubernetes API Server와 etcd를 가동하여 통합 테스트를 수행합니다. 전체 클러스터 없이도 선언적 API 상호작용을 테스트할 수 있습니다.

```go
// internal/controller/suite_test.go
package controller

import (
    "context"
    "path/filepath"
    "testing"
    "time"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"

    "k8s.io/client-go/kubernetes/scheme"
    "k8s.io/client-go/rest"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/envtest"
    logf "sigs.k8s.io/controller-runtime/pkg/log"
    "sigs.k8s.io/controller-runtime/pkg/log/zap"

    dbv1 "example.com/database-operator/api/v1"
)

var (
    cfg       *rest.Config
    k8sClient client.Client
    testEnv   *envtest.Environment
    ctx       context.Context
    cancel    context.CancelFunc
)

func TestControllers(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Controller Suite")
}

var _ = BeforeSuite(func() {
    logf.SetLogger(zap.New(zap.WriteTo(GinkgoWriter), zap.UseDevMode(true)))

    ctx, cancel = context.WithCancel(context.TODO())

    By("bootstrapping test environment")
    testEnv = &envtest.Environment{
        CRDDirectoryPaths:     []string{filepath.Join("..", "..", "config", "crd", "bases")},
        ErrorIfCRDPathMissing: true,
    }

    var err error
    cfg, err = testEnv.Start()
    Expect(err).NotTo(HaveOccurred())
    Expect(cfg).NotTo(BeNil())

    err = dbv1.AddToScheme(scheme.Scheme)
    Expect(err).NotTo(HaveOccurred())

    k8sClient, err = client.New(cfg, client.Options{Scheme: scheme.Scheme})
    Expect(err).NotTo(HaveOccurred())
    Expect(k8sClient).NotTo(BeNil())

    // Controller 시작
    k8sManager, err := ctrl.NewManager(cfg, ctrl.Options{
        Scheme: scheme.Scheme,
    })
    Expect(err).ToNot(HaveOccurred())

    err = (&DatabaseReconciler{
        Client: k8sManager.GetClient(),
        Scheme: k8sManager.GetScheme(),
    }).SetupWithManager(k8sManager)
    Expect(err).ToNot(HaveOccurred())

    go func() {
        defer GinkgoRecover()
        err = k8sManager.Start(ctx)
        Expect(err).ToNot(HaveOccurred(), "failed to run manager")
    }()
})

var _ = AfterSuite(func() {
    cancel()
    By("tearing down the test environment")
    err := testEnv.Stop()
    Expect(err).NotTo(HaveOccurred())
})
```

```go
// internal/controller/database_controller_integration_test.go
var _ = Describe("Database Controller", func() {
    const (
        DatabaseName      = "test-database"
        DatabaseNamespace = "default"
        timeout           = time.Second * 30
        interval          = time.Millisecond * 250
    )

    Context("When creating a Database", func() {
        It("Should create StatefulSet and Service", func() {
            ctx := context.Background()

            database := &dbv1.Database{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      DatabaseName,
                    Namespace: DatabaseNamespace,
                },
                Spec: dbv1.DatabaseSpec{
                    Engine:       "postgres",
                    Version:      "15.0",
                    Replicas:     3,
                    StorageSize:  "20Gi",
                    StorageClass: "fast-ssd",
                },
            }

            Expect(k8sClient.Create(ctx, database)).Should(Succeed())

            databaseLookupKey := types.NamespacedName{
                Name:      DatabaseName,
                Namespace: DatabaseNamespace,
            }
            createdDatabase := &dbv1.Database{}

            // Database가 생성되었는지 확인
            Eventually(func() bool {
                err := k8sClient.Get(ctx, databaseLookupKey, createdDatabase)
                return err == nil
            }, timeout, interval).Should(BeTrue())

            // StatefulSet이 생성되었는지 확인
            statefulSetLookupKey := types.NamespacedName{
                Name:      DatabaseName,
                Namespace: DatabaseNamespace,
            }
            createdStatefulSet := &appsv1.StatefulSet{}

            Eventually(func() bool {
                err := k8sClient.Get(ctx, statefulSetLookupKey, createdStatefulSet)
                return err == nil
            }, timeout, interval).Should(BeTrue())

            Expect(*createdStatefulSet.Spec.Replicas).Should(Equal(int32(3)))

            // Status가 업데이트되었는지 확인
            Eventually(func() bool {
                err := k8sClient.Get(ctx, databaseLookupKey, createdDatabase)
                if err != nil {
                    return false
                }
                return createdDatabase.Status.Phase == "Running"
            }, timeout, interval).Should(BeTrue())
        })
    })

    Context("When updating Database replicas", func() {
        It("Should scale StatefulSet", func() {
            ctx := context.Background()

            databaseLookupKey := types.NamespacedName{
                Name:      DatabaseName,
                Namespace: DatabaseNamespace,
            }
            database := &dbv1.Database{}

            Expect(k8sClient.Get(ctx, databaseLookupKey, database)).Should(Succeed())

            // Replicas 수정
            database.Spec.Replicas = 5
            Expect(k8sClient.Update(ctx, database)).Should(Succeed())

            // StatefulSet이 업데이트되었는지 확인
            statefulSetLookupKey := types.NamespacedName{
                Name:      DatabaseName,
                Namespace: DatabaseNamespace,
            }
            updatedStatefulSet := &appsv1.StatefulSet{}

            Eventually(func() int32 {
                err := k8sClient.Get(ctx, statefulSetLookupKey, updatedStatefulSet)
                if err != nil {
                    return 0
                }
                return *updatedStatefulSet.Spec.Replicas
            }, timeout, interval).Should(Equal(int32(5)))
        })
    })
})
```

### 2.4 E2E Tests

```go
// test/e2e/e2e_test.go
package e2e

import (
    "context"
    "testing"
    "time"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"

    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/clientcmd"

    dbv1 "example.com/database-operator/api/v1"
)

var (
    clientset    *kubernetes.Clientset
    databaseClient dbv1client.Interface
)

func TestE2E(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "E2E Suite")
}

var _ = BeforeSuite(func() {
    // 실제 클러스터에 연결
    config, err := clientcmd.BuildConfigFromFlags("", kubeconfigPath)
    Expect(err).NotTo(HaveOccurred())

    clientset, err = kubernetes.NewForConfig(config)
    Expect(err).NotTo(HaveOccurred())

    databaseClient, err = dbv1client.NewForConfig(config)
    Expect(err).NotTo(HaveOccurred())
})

var _ = Describe("Database Operator E2E", func() {
    Context("Full lifecycle test", func() {
        It("Should create, update, backup, and delete database", func() {
            ctx := context.Background()
            namespace := "e2e-test"

            // Namespace 생성
            ns := &corev1.Namespace{
                ObjectMeta: metav1.ObjectMeta{Name: namespace},
            }
            _, err := clientset.CoreV1().Namespaces().Create(ctx, ns, metav1.CreateOptions{})
            Expect(err).NotTo(HaveOccurred())

            // Database 생성
            database := &dbv1.Database{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "e2e-db",
                    Namespace: namespace,
                },
                Spec: dbv1.DatabaseSpec{
                    Engine:       "postgres",
                    Version:      "15.0",
                    Replicas:     1,
                    StorageSize:  "10Gi",
                },
            }

            _, err = databaseClient.Databases(namespace).Create(ctx, database, metav1.CreateOptions{})
            Expect(err).NotTo(HaveOccurred())

            // Database가 Ready 상태가 될 때까지 대기
            Eventually(func() bool {
                db, err := databaseClient.Databases(namespace).Get(ctx, "e2e-db", metav1.GetOptions{})
                if err != nil {
                    return false
                }
                return db.Status.Phase == "Running" && db.Status.Ready
            }, 5*time.Minute, 10*time.Second).Should(BeTrue())

            // 실제 연결 테스트
            By("Testing database connectivity")
            pod, err := clientset.CoreV1().Pods(namespace).Get(ctx, "e2e-db-0", metav1.GetOptions{})
            Expect(err).NotTo(HaveOccurred())
            Expect(pod.Status.Phase).To(Equal(corev1.PodRunning))

            // Cleanup
            err = databaseClient.Databases(namespace).Delete(ctx, "e2e-db", metav1.DeleteOptions{})
            Expect(err).NotTo(HaveOccurred())

            err = clientset.CoreV1().Namespaces().Delete(ctx, namespace, metav1.DeleteOptions{})
            Expect(err).NotTo(HaveOccurred())
        })
    })
})
```

**2025 테스트 Best Practices**:
- Unit Tests로 비즈니스 로직의 70-80% 커버
- EnvTest로 Controller 로직 검증 (fake client 사용 지양 - 실제 API Server 사용 권장)
- E2E는 critical path만 테스트 (비용/시간 고려)
- CI에서 EnvTest는 병렬 실행, E2E는 nightly 실행

---

## Part 3: OLM Bundle 및 배포

### 3.1 OLM Bundle 생성

```bash
# Makefile 타겟 사용
make bundle

# 생성되는 구조
bundle/
├── manifests/
│   ├── database-operator.clusterserviceversion.yaml  # CSV
│   ├── databases.db.example.com.crd.yaml             # CRD
│   └── ...
├── metadata/
│   └── annotations.yaml
└── tests/
    └── scorecard/
```

```yaml
# bundle/metadata/annotations.yaml
annotations:
  # OLMv1 지원 (2025)
  operators.operatorframework.io.bundle.mediatype.v1: registry+v1
  operators.operatorframework.io.bundle.manifests.v1: manifests/
  operators.operatorframework.io.bundle.metadata.v1: metadata/
  operators.operatorframework.io.bundle.package.v1: database-operator
  operators.operatorframework.io.bundle.channels.v1: stable,beta
  operators.operatorframework.io.bundle.channel.default.v1: stable
  operators.operatorframework.io.metrics.builder: operator-sdk-v1.35.0
  operators.operatorframework.io.metrics.mediatype.v1: metrics+v1
  operators.operatorframework.io.metrics.project_layout: go.kubebuilder.io/v4

  # Container annotations
  com.redhat.openshift.versions: "v4.12-v4.16"
  com.redhat.delivery.operator.bundle: "true"
```

### 3.2 ClusterServiceVersion (CSV) 작성

```yaml
# bundle/manifests/database-operator.clusterserviceversion.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: ClusterServiceVersion
metadata:
  name: database-operator.v1.0.0
  annotations:
    alm-examples: |-
      [
        {
          "apiVersion": "db.example.com/v1",
          "kind": "Database",
          "metadata": {
            "name": "example-database"
          },
          "spec": {
            "engine": "postgres",
            "version": "15.0",
            "replicas": 3,
            "storageSize": "20Gi"
          }
        }
      ]
    capabilities: Deep Insights
    categories: Database
    certified: "false"
    containerImage: quay.io/example/database-operator:v1.0.0
    createdAt: "2025-01-15T00:00:00Z"
    description: Enterprise-grade database operator for Kubernetes
    repository: https://github.com/example/database-operator
    support: Example Inc.
spec:
  displayName: Database Operator
  description: |
    The Database Operator automates the deployment, scaling, and management
    of relational databases in Kubernetes.

    ## Features
    - Automated provisioning and lifecycle management
    - High availability with automated failover
    - Backup and restore capabilities
    - Monitoring with Prometheus integration

    ## Prerequisites
    - Kubernetes 1.28+
    - Storage provisioner with RWO support

  keywords:
    - database
    - postgres
    - mysql
    - high-availability

  version: 1.0.0
  maturity: stable
  minKubeVersion: 1.28.0

  maintainers:
    - name: Platform Team
      email: platform@example.com

  provider:
    name: Example Inc.

  links:
    - name: Documentation
      url: https://docs.example.com/database-operator
    - name: Source Code
      url: https://github.com/example/database-operator

  icon:
    - base64data: <base64-encoded-icon>
      mediatype: image/png

  # RBAC
  install:
    strategy: deployment
    spec:
      permissions:
        - serviceAccountName: database-operator-controller-manager
          rules:
            - apiGroups: [""]
              resources: [pods, services, configmaps, secrets]
              verbs: [get, list, watch, create, update, patch, delete]
            - apiGroups: [apps]
              resources: [statefulsets]
              verbs: [get, list, watch, create, update, patch, delete]

      clusterPermissions:
        - serviceAccountName: database-operator-controller-manager
          rules:
            - apiGroups: [db.example.com]
              resources: [databases, databases/status]
              verbs: [get, list, watch, create, update, patch, delete]
            - apiGroups: [storage.k8s.io]
              resources: [storageclasses]
              verbs: [get, list, watch]

      deployments:
        - name: database-operator-controller-manager
          spec:
            replicas: 1
            selector:
              matchLabels:
                control-plane: controller-manager
            template:
              metadata:
                labels:
                  control-plane: controller-manager
              spec:
                serviceAccountName: database-operator-controller-manager
                containers:
                  - name: manager
                    image: quay.io/example/database-operator:v1.0.0
                    command: [/manager]
                    args:
                      - --leader-elect
                      - --health-probe-bind-address=:8081
                      - --metrics-bind-address=127.0.0.1:8080
                    env:
                      - name: WATCH_NAMESPACE
                        valueFrom:
                          fieldRef:
                            fieldPath: metadata.annotations['olm.targetNamespaces']
                    ports:
                      - containerPort: 9443
                        name: webhook-server
                        protocol: TCP
                    livenessProbe:
                      httpGet:
                        path: /healthz
                        port: 8081
                      initialDelaySeconds: 15
                      periodSeconds: 20
                    readinessProbe:
                      httpGet:
                        path: /readyz
                        port: 8081
                      initialDelaySeconds: 5
                      periodSeconds: 10
                    resources:
                      limits:
                        cpu: 500m
                        memory: 512Mi
                      requests:
                        cpu: 100m
                        memory: 128Mi
                    securityContext:
                      allowPrivilegeEscalation: false
                      capabilities:
                        drop: [ALL]
                      runAsNonRoot: true
                      seccompProfile:
                        type: RuntimeDefault

  # CRD 소유권
  customresourcedefinitions:
    owned:
      - name: databases.db.example.com
        version: v1
        kind: Database
        displayName: Database
        description: Represents a managed database instance
        resources:
          - kind: StatefulSet
            version: v1
          - kind: Service
            version: v1
          - kind: ConfigMap
            version: v1
          - kind: Secret
            version: v1
        specDescriptors:
          - path: engine
            displayName: Database Engine
            description: The database engine (postgres, mysql)
            x-descriptors:
              - urn:alm:descriptor:com.tectonic.ui:select:postgres
              - urn:alm:descriptor:com.tectonic.ui:select:mysql
          - path: version
            displayName: Version
            description: Database version
            x-descriptors:
              - urn:alm:descriptor:com.tectonic.ui:text
          - path: replicas
            displayName: Replicas
            description: Number of database replicas
            x-descriptors:
              - urn:alm:descriptor:com.tectonic.ui:podCount
          - path: storageSize
            displayName: Storage Size
            description: Size of persistent volume
            x-descriptors:
              - urn:alm:descriptor:com.tectonic.ui:text
        statusDescriptors:
          - path: phase
            displayName: Phase
            description: Current phase of the database
            x-descriptors:
              - urn:alm:descriptor:io.kubernetes.phase
          - path: ready
            displayName: Ready
            description: Whether the database is ready
            x-descriptors:
              - urn:alm:descriptor:io.kubernetes.conditions

  # Webhook 정의
  webhookdefinitions:
    - admissionReviewVersions: [v1]
      containerPort: 443
      deploymentName: database-operator-controller-manager
      failurePolicy: Fail
      generateName: vdatabase.kb.io
      rules:
        - apiGroups: [db.example.com]
          apiVersions: [v1]
          operations: [CREATE, UPDATE]
          resources: [databases]
      sideEffects: None
      type: ValidatingAdmissionWebhook
      webhookPath: /validate-db-example-com-v1-database

    - admissionReviewVersions: [v1]
      containerPort: 443
      deploymentName: database-operator-controller-manager
      failurePolicy: Fail
      generateName: mdatabase.kb.io
      rules:
        - apiGroups: [db.example.com]
          apiVersions: [v1]
          operations: [CREATE, UPDATE]
          resources: [databases]
      sideEffects: None
      type: MutatingAdmissionWebhook
      webhookPath: /mutate-db-example-com-v1-database
```

### 3.3 OLMv1 배포 (2025)

```yaml
# olmv1-clusterextension.yaml
apiVersion: olm.operatorframework.io/v1alpha1
kind: ClusterExtension
metadata:
  name: database-operator
spec:
  packageName: database-operator
  version: 1.0.0

  # OLMv1에서는 명시적 serviceAccount 필요 (보안 강화)
  serviceAccount:
    name: database-operator-installer

  # 설치 네임스페이스
  installNamespace: operators

  # 업그레이드 정책
  upgradeConstraintPolicy: SemVer
```

```bash
# OLM Bundle 이미지 빌드 및 푸시
make bundle-build bundle-push IMG=quay.io/example/database-operator-bundle:v1.0.0

# Catalog 생성
opm index add \
  --bundles quay.io/example/database-operator-bundle:v1.0.0 \
  --tag quay.io/example/database-operator-catalog:latest

# CatalogSource 생성
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: database-operator-catalog
  namespace: olm
spec:
  sourceType: grpc
  image: quay.io/example/database-operator-catalog:latest
  displayName: Database Operator Catalog
  publisher: Example Inc.
  updateStrategy:
    registryPoll:
      interval: 10m
EOF

# Subscription 생성 (자동 설치)
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: database-operator
  namespace: operators
spec:
  channel: stable
  name: database-operator
  source: database-operator-catalog
  sourceNamespace: olm
  installPlanApproval: Automatic
EOF
```

---

## Part 4: 프로덕션 Best Practices

### 4.1 Multi-Cluster 패턴

2025년 현재, Multi-cluster 관리는 edge case에서 mainstream 요구사항으로 변화했습니다.

#### 패턴 1: Hub-Spoke (Federated Operator)

```go
// Hub 클러스터에서 실행되는 Multi-Cluster Controller
type MultiClusterDatabaseReconciler struct {
    HubClient    client.Client
    ClusterClients map[string]client.Client  // cluster name -> client
}

func (r *MultiClusterDatabaseReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    var db dbv1.Database
    if err := r.HubClient.Get(ctx, req.NamespacedName, &db); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // 타겟 클러스터 결정
    targetCluster := db.Spec.TargetCluster
    if targetCluster == "" {
        targetCluster = r.selectOptimalCluster(ctx, &db)
    }

    // 타겟 클러스터에 Database 리소스 생성
    targetClient := r.ClusterClients[targetCluster]
    targetDB := db.DeepCopy()
    targetDB.Namespace = db.Spec.TargetNamespace

    if err := targetClient.Create(ctx, targetDB); err != nil {
        if !apierrors.IsAlreadyExists(err) {
            return ctrl.Result{}, err
        }
        // 이미 존재하면 업데이트
        if err := targetClient.Update(ctx, targetDB); err != nil {
            return ctrl.Result{}, err
        }
    }

    // Hub에 상태 동기화
    db.Status.TargetCluster = targetCluster
    db.Status.Phase = "Deployed"
    if err := r.HubClient.Status().Update(ctx, &db); err != nil {
        return ctrl.Result{}, err
    }

    return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}

func (r *MultiClusterDatabaseReconciler) selectOptimalCluster(ctx context.Context, db *dbv1.Database) string {
    // 리소스 가용성, 지역, 비용 등을 고려한 클러스터 선택 로직
    // 2025: AI 기반 예측 배치 가능
    return "cluster-us-east-1"
}
```

#### 패턴 2: Per-Cluster Deployment with Central Coordination

```yaml
# 각 클러스터에 Operator 배포 + ConfigMap으로 중앙 조정
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-topology
  namespace: database-operator-system
data:
  clusters.yaml: |
    clusters:
      - name: us-east-1
        apiServer: https://cluster1.example.com
        region: us-east-1
        capacity:
          cpu: 1000
          memory: 4000Gi
      - name: eu-west-1
        apiServer: https://cluster2.example.com
        region: eu-west-1
        capacity:
          cpu: 800
          memory: 3200Gi
```

### 4.2 Observability

```go
// Prometheus Metrics
import (
    "github.com/prometheus/client_golang/prometheus"
    "sigs.k8s.io/controller-runtime/pkg/metrics"
)

var (
    databaseReconcileTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "database_reconcile_total",
            Help: "Total number of database reconciliations",
        },
        []string{"namespace", "name", "result"},
    )

    databaseReconcileDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "database_reconcile_duration_seconds",
            Help:    "Duration of database reconciliations",
            Buckets: prometheus.DefBuckets,
        },
        []string{"namespace", "name"},
    )

    databaseStatusGauge = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "database_status",
            Help: "Current status of databases (1=Running, 0=Failed)",
        },
        []string{"namespace", "name", "phase"},
    )
)

func init() {
    metrics.Registry.MustRegister(
        databaseReconcileTotal,
        databaseReconcileDuration,
        databaseStatusGauge,
    )
}

func (r *DatabaseReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    start := time.Now()
    defer func() {
        duration := time.Since(start).Seconds()
        databaseReconcileDuration.WithLabelValues(req.Namespace, req.Name).Observe(duration)
    }()

    // ... reconcile 로직 ...

    result := "success"
    if err != nil {
        result = "error"
    }
    databaseReconcileTotal.WithLabelValues(req.Namespace, req.Name, result).Inc()

    // Status gauge 업데이트
    statusValue := 0.0
    if db.Status.Phase == "Running" {
        statusValue = 1.0
    }
    databaseStatusGauge.WithLabelValues(req.Namespace, req.Name, db.Status.Phase).Set(statusValue)

    return ctrl.Result{}, err
}
```

```yaml
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: database-operator-metrics
  namespace: database-operator-system
spec:
  selector:
    matchLabels:
      control-plane: controller-manager
  endpoints:
    - port: https
      scheme: https
      tlsConfig:
        insecureSkipVerify: true
      bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
```

### 4.3 보안 Best Practices

#### RBAC 최소화

```yaml
# 필요한 최소 권한만 부여 (2025 표준)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: database-operator-manager-role
rules:
  # 필수: 관리하는 CRD
  - apiGroups: [db.example.com]
    resources: [databases]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [db.example.com]
    resources: [databases/status]
    verbs: [get, update, patch]

  # 필수: 생성하는 리소스 (namespace-scoped)
  # ClusterRole이지만 RoleBinding으로 namespace 제한 가능
  - apiGroups: [""]
    resources: [services, configmaps, secrets]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [apps]
    resources: [statefulsets]
    verbs: [get, list, watch, create, update, patch, delete]

  # 읽기 전용: 참조하는 리소스
  - apiGroups: [storage.k8s.io]
    resources: [storageclasses]
    verbs: [get, list, watch]

  # 이벤트 생성 (선택적)
  - apiGroups: [""]
    resources: [events]
    verbs: [create, patch]
```

#### Webhook 부작용 처리

```go
// Webhook은 side effects를 최소화해야 함
// 부작용이 있는 경우 반드시 Controller로 동기화

//+kubebuilder:webhook:sideEffects=NoneOnDryRun

func (v *DatabaseValidator) ValidateCreate(ctx context.Context, obj runtime.Object) (admission.Warnings, error) {
    db := obj.(*Database)

    // ❌ 나쁜 예: Webhook에서 직접 외부 리소스 생성
    // if db.Spec.CreateBackup {
    //     createBackupBucket(db.Name)  // dry-run에서도 실행됨!
    // }

    // ✅ 좋은 예: 검증만 수행, 생성은 Controller가 담당
    if db.Spec.CreateBackup && !isValidBackupConfig(db.Spec.BackupConfig) {
        return nil, fmt.Errorf("invalid backup configuration")
    }

    return nil, nil
}
```

#### 인증서 갱신 모니터링

```go
// OLM이 자동 갱신하지만, 만료 전 알림 설정
func (r *DatabaseReconciler) checkWebhookCertExpiry(ctx context.Context) error {
    var secret corev1.Secret
    if err := r.Get(ctx, types.NamespacedName{
        Name:      "webhook-server-cert",
        Namespace: "database-operator-system",
    }, &secret); err != nil {
        return err
    }

    certData := secret.Data["tls.crt"]
    cert, err := x509.ParseCertificate(certData)
    if err != nil {
        return err
    }

    daysUntilExpiry := time.Until(cert.NotAfter).Hours() / 24
    if daysUntilExpiry < 30 {
        // Alert 발송
        log.Info("Webhook certificate expiring soon", "days", daysUntilExpiry)
    }

    return nil
}
```

---

## 🛠️ 실습 가이드

### 실습 1: Validating Webhook 구현

```bash
# 1. Kubebuilder로 Webhook 스캐폴딩
kubebuilder create webhook \
  --group db \
  --version v1 \
  --kind Database \
  --defaulting \
  --programmatic-validation

# 2. 생성된 파일 확인
# api/v1/database_webhook.go
# config/webhook/manifests.yaml
# config/certmanager/certificate.yaml

# 3. Webhook 로직 구현 (위 예제 참조)

# 4. 로컬 테스트 (cert-manager 필요)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# 5. Webhook 배포
make deploy

# 6. 테스트
kubectl apply -f config/samples/db_v1_database.yaml

# 7. Webhook 로그 확인
kubectl logs -n database-operator-system deployment/database-operator-controller-manager
```

### 실습 2: EnvTest로 Integration Test 작성

```bash
# 1. 테스트 의존성 설치
go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest
setup-envtest use 1.30.0

# 2. 테스트 작성 (위 예제 참조)

# 3. 테스트 실행
make test

# 4. Coverage 확인
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out
```

### 실습 3: OLM Bundle 생성 및 배포

```bash
# 1. Bundle 생성
make bundle IMG=quay.io/yourorg/database-operator:v1.0.0

# 2. CSV 편집
vim bundle/manifests/database-operator.clusterserviceversion.yaml

# 3. Bundle 검증
operator-sdk bundle validate ./bundle

# 4. Bundle 이미지 빌드
make bundle-build bundle-push BUNDLE_IMG=quay.io/yourorg/database-operator-bundle:v1.0.0

# 5. OLM 설치 (Kind 클러스터)
operator-sdk olm install

# 6. Bundle 실행
operator-sdk run bundle quay.io/yourorg/database-operator-bundle:v1.0.0

# 7. 확인
kubectl get csv -n operators
kubectl get installplan -n operators
kubectl get subscription -n operators

# 8. Database 생성
kubectl apply -f config/samples/db_v1_database.yaml

# 9. 정리
operator-sdk cleanup database-operator
```

---

## 💻 예제 코드

### 완전한 Operator 프로젝트 구조 (2025)

```
database-operator/
├── api/
│   └── v1/
│       ├── database_types.go
│       ├── database_webhook.go
│       ├── groupversion_info.go
│       └── zz_generated.deepcopy.go
├── internal/
│   └── controller/
│       ├── database_controller.go
│       ├── database_controller_test.go
│       ├── suite_test.go
│       └── testdata/
├── config/
│   ├── crd/
│   │   └── bases/
│   │       └── db.example.com_databases.yaml
│   ├── rbac/
│   │   ├── role.yaml
│   │   └── role_binding.yaml
│   ├── manager/
│   │   └── manager.yaml
│   ├── webhook/
│   │   └── manifests.yaml
│   ├── certmanager/
│   │   └── certificate.yaml
│   ├── prometheus/
│   │   └── monitor.yaml
│   └── samples/
│       └── db_v1_database.yaml
├── bundle/
│   ├── manifests/
│   │   ├── database-operator.clusterserviceversion.yaml
│   │   └── databases.db.example.com.crd.yaml
│   ├── metadata/
│   │   └── annotations.yaml
│   └── tests/
│       └── scorecard/
├── test/
│   └── e2e/
│       ├── e2e_test.go
│       └── e2e_suite_test.go
├── cmd/
│   └── main.go
├── Dockerfile
├── Makefile
├── go.mod
├── go.sum
└── PROJECT
```

### Makefile 주요 타겟 (2025)

```makefile
# Makefile
VERSION ?= 1.0.0
IMG ?= quay.io/example/database-operator:$(VERSION)
BUNDLE_IMG ?= quay.io/example/database-operator-bundle:$(VERSION)

.PHONY: test
test: envtest
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" go test ./... -coverprofile cover.out

.PHONY: test-e2e
test-e2e:
	go test ./test/e2e/... -v -ginkgo.v

.PHONY: docker-build
docker-build:
	docker build -t ${IMG} .

.PHONY: docker-push
docker-push:
	docker push ${IMG}

.PHONY: bundle
bundle: manifests kustomize operator-sdk
	$(OPERATOR_SDK) generate kustomize manifests -q
	cd config/manager && $(KUSTOMIZE) edit set image controller=$(IMG)
	$(KUSTOMIZE) build config/manifests | $(OPERATOR_SDK) generate bundle -q --overwrite --version $(VERSION)
	$(OPERATOR_SDK) bundle validate ./bundle

.PHONY: bundle-build
bundle-build:
	docker build -f bundle.Dockerfile -t $(BUNDLE_IMG) .

.PHONY: bundle-push
bundle-push:
	docker push $(BUNDLE_IMG)

.PHONY: deploy
deploy: manifests kustomize
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

.PHONY: undeploy
undeploy:
	$(KUSTOMIZE) build config/default | kubectl delete -f -
```

---

## 📚 참고 자료

### 공식 문서 (2025)

- [Operator SDK Documentation](https://sdk.operatorframework.io/)
- [Kubebuilder Book](https://book.kubebuilder.io/)
- [Kubernetes Admission Webhooks Good Practices](https://kubernetes.io/docs/concepts/cluster-administration/admission-webhooks-good-practices/)
- [OLM Documentation](https://olm.operatorframework.io/)
- [controller-runtime GitHub](https://github.com/kubernetes-sigs/controller-runtime)

### 테스팅 리소스

- [Testing Kubernetes Operators using EnvTest](https://www.infracloud.io/blogs/testing-kubernetes-operator-envtest/)
- [EnvTest Practical Guide](https://blog.marcnuri.com/go-testing-kubernetes-applications-envtest/)
- [Testing Production Kubernetes Controllers](https://superorbital.io/blog/testing-production-controllers/)

### 프로덕션 가이드

- [Kubernetes Operators in 2025 Guide](https://outerbyte.com/kubernetes-operators-2025-guide/)
- [Enterprise Kubernetes Operators 2025](https://support.tools/post/enterprise-kubernetes-operators-comprehensive-development-guide-2025/)
- [Deploying Operators with OLM bundles](https://developers.redhat.com/blog/2021/02/08/deploying-kubernetes-operators-with-operator-lifecycle-manager-bundles)

### 커뮤니티 리소스

- [Operator Framework GitHub](https://github.com/operator-framework)
- [Kubernetes Operator Patterns Repository](https://github.com/operator-framework/operator-sdk)
- [CNCF Operator White Paper](https://www.cncf.io/reports/)

### 2025 기술 블로그

- [Operator Best Practices](https://sdk.operatorframework.io/docs/best-practices/best-practices/)
- [OLMv1 Support and Chart Dependencies](https://validatedpatterns.io/blog/2025-08-11-olmv1-support-and-chart-dependencies/)
- [Slack Engineering: Simple Kubernetes Webhook](https://slack.engineering/simple-kubernetes-webhook/)

---

## ✅ 학습 체크리스트

### 기본 (Essential)

- [ ] Validating Webhook과 Mutating Webhook의 차이 이해
- [ ] CEL Validation과 Webhook의 적절한 사용 시나리오 판단
- [ ] EnvTest로 Controller 통합 테스트 작성
- [ ] OLM Bundle 생성 및 CSV 작성
- [ ] 기본적인 Prometheus metrics 노출

### 중급 (Intermediate)

- [ ] Webhook에서 다른 리소스 조회하여 검증
- [ ] admission.Warnings 활용하여 사용자에게 경고 전달
- [ ] Ginkgo/Gomega로 BDD 스타일 테스트 작성
- [ ] OLM의 자동 인증서 관리 메커니즘 이해
- [ ] Multi-cluster 배포 패턴 중 하나 구현

### 고급 (Advanced)

- [ ] Conversion Webhook 구현 (CRD 버전 변환)
- [ ] E2E 테스트 프레임워크 구축
- [ ] OLMv1 ClusterExtension으로 배포
- [ ] Federated Operator 패턴으로 multi-cluster 관리
- [ ] OpenTelemetry traces 통합
- [ ] Operator 성능 프로파일링 및 최적화

### 프로덕션 (Production-Ready)

- [ ] RBAC 최소 권한 원칙 적용 및 검증
- [ ] Webhook 부작용(side effects) 처리 패턴 구현
- [ ] 인증서 만료 모니터링 및 알림
- [ ] OperatorHub.io에 Operator 등록
- [ ] Chaos Engineering으로 장애 시나리오 테스트
- [ ] SLO/SLI 정의 및 Monitoring Dashboard 구축

---

## 🎓 다음 단계

### Ch7: Cloud Network CNI
Kubernetes의 네트워크 플러그인 아키텍처인 CNI(Container Network Interface)를 학습하고, Cilium, Calico, Flannel 등 주요 CNI 플러그인의 동작 원리와 Service Mesh 통합 방법을 다룹니다.

**주요 주제:**

- CNI 플러그인 아키텍처 및 Spec
- Cilium: eBPF 기반 네트워킹 및 보안
- Calico: BGP 기반 네트워크 정책
- Service Mesh (Istio, Linkerd)와 CNI의 관계
- NetworkPolicy 고급 활용

### 추가 학습 리소스

- [OperatorHub.io](https://operatorhub.io/) - 커뮤니티 Operator 탐색
- [Kubernetes SIG-API-Machinery](https://github.com/kubernetes/community/tree/master/sig-api-machinery) - API 확장 메커니즘 학습
- [CNCF Landscape](https://landscape.cncf.io/) - Operator 생태계 이해

---

**작성일:** 2025-11-24
**대상:** Computing Service 엔지니어
**난이도:** Advanced
**예상 학습 시간:** 12-16시간 (실습 포함)
