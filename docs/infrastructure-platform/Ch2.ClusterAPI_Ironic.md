# Ch2. ClusterAPI & Ironic

## 📋 개요

ClusterAPI는 Kubernetes 클러스터의 프로비저닝, 업그레이드, 운영을 자동화하는 Kubernetes 서브 프로젝트입니다. OpenStack Ironic은 베어메탈 서버를 자동으로 프로비저닝하는 서비스입니다. 두 기술을 결합하면 베어메탈 인프라에서 Kubernetes 클러스터를 완전 자동화할 수 있습니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:

- ClusterAPI를 사용한 Kubernetes 클러스터 자동 생성
- ClusterAPI Provider 이해 및 활용
- OpenStack Ironic을 사용한 베어메탈 프로비저닝
- ClusterAPI와 Ironic 통합 구성

---

## 🔧 Part 1: Cluster API

### 1. Cluster API 개념

**Cluster API의 핵심 원칙:**

- **Declarative API**: YAML로 클러스터 정의
- **Kubernetes-style**: Kubernetes 패턴 사용
- **Provider 기반**: 다양한 인프라 지원 (AWS, Azure, GCP, OpenStack 등)

**아키텍처:**
```
┌─────────────────────┐
│ Management Cluster  │ ← ClusterAPI 컨트롤러 실행
└──────────┬──────────┘
           │
           ↓ Provisions
┌─────────────────────┐
│ Workload Cluster 1  │ ← 실제 워크로드 실행
└─────────────────────┘
┌─────────────────────┐
│ Workload Cluster 2  │
└─────────────────────┘
```

### 2. 핵심 리소스

#### Cluster

전체 클러스터를 정의합니다.

```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: my-cluster
  namespace: default
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - 192.168.0.0/16
    services:
      cidrBlocks:
        - 10.96.0.0/12
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: OpenStackCluster  # Provider별로 다름
    name: my-cluster
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: my-cluster-control-plane
```

#### Machine

개별 노드(VM 또는 베어메탈)를 정의합니다.

```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Machine
metadata:
  name: my-cluster-control-plane-0
  namespace: default
spec:
  clusterName: my-cluster
  version: v1.28.0
  bootstrap:
    configRef:
      apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
      kind: KubeadmConfig
      name: my-cluster-control-plane-0
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: OpenStackMachine
    name: my-cluster-control-plane-0
```

#### MachineDeployment

Worker 노드 그룹을 정의합니다 (Deployment와 유사).

```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: my-cluster-workers
  namespace: default
spec:
  clusterName: my-cluster
  replicas: 3
  selector:
    matchLabels:
      cluster.x-k8s.io/cluster-name: my-cluster
  template:
    spec:
      clusterName: my-cluster
      version: v1.28.0
      bootstrap:
        configRef:
          apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
          kind: KubeadmConfigTemplate
          name: my-cluster-worker
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: OpenStackMachineTemplate
        name: my-cluster-worker
```

### 3. ClusterAPI 설치 및 사용

#### clusterctl 설치

```bash
# macOS
brew install clusterctl

# Linux
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/latest/download/clusterctl-linux-amd64 -o clusterctl
chmod +x clusterctl
sudo mv clusterctl /usr/local/bin/

# 버전 확인
clusterctl version
```

#### Management Cluster 초기화

```bash
# Kind로 Management Cluster 생성
kind create cluster --name capi-management

# ClusterAPI 초기화 (AWS Provider 예제)
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>

clusterctl init --infrastructure aws

# 설치된 Provider 확인
kubectl get pods -n capi-system
kubectl get pods -n capa-system  # AWS Provider
```

#### Workload Cluster 생성

```bash
# 클러스터 매니페스트 생성
clusterctl generate cluster my-cluster \
  --kubernetes-version v1.28.0 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > my-cluster.yaml

# 클러스터 생성
kubectl apply -f my-cluster.yaml

# 클러스터 상태 확인
clusterctl describe cluster my-cluster

# Kubeconfig 가져오기
clusterctl get kubeconfig my-cluster > my-cluster.kubeconfig

# 생성된 클러스터 사용
export KUBECONFIG=my-cluster.kubeconfig
kubectl get nodes
```

### 4. Cluster 관리

#### 스케일링

```bash
# Worker 노드 스케일 아웃
kubectl scale machinedeployment my-cluster-workers --replicas=5

# Control Plane 스케일링
kubectl scale kubeadmcontrolplane my-cluster-control-plane --replicas=5
```

#### 업그레이드

```yaml
# Control Plane 업그레이드
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: my-cluster-control-plane
spec:
  version: v1.29.0  # 1.28.0 → 1.29.0으로 업그레이드
  rolloutStrategy:
    rollingUpdate:
      maxSurge: 1
```

```bash
# 변경 적용
kubectl apply -f control-plane.yaml

# 업그레이드 진행 상황 확인
kubectl get kubeadmcontrolplane my-cluster-control-plane -w
```

#### 클러스터 삭제

```bash
# Workload Cluster 삭제
kubectl delete cluster my-cluster

# Management Cluster도 삭제할 경우
kind delete cluster --name capi-management
```

---

## 🖥️ Part 2: OpenStack Ironic

### 1. Ironic 아키텍처

**주요 컴포넌트:**

- **ironic-api**: REST API 서버
- **ironic-conductor**: 베어메탈 관리 엔진
- **ironic-python-agent (IPA)**: 노드에서 실행되는 에이전트
- **Inspector**: 하드웨어 검사 서비스

**프로비저닝 흐름:**
```
1. Enrollment (등록)
   ↓
2. Inspection (검사)
   ↓
3. Provisioning (프로비저닝)
   ↓
4. Deployment (배포)
   ↓
5. Active (운영)
```

### 2. Ironic 설치 (Standalone)

#### Bifrost로 설치

```bash
# Bifrost 저장소 클론
git clone https://opendev.org/openstack/bifrost.git
cd bifrost

# Ansible로 설치
cd playbooks
ansible-playbook -vvvv -i inventory/target install.yaml

# Ironic 서비스 확인
sudo systemctl status ironic-api
sudo systemctl status ironic-conductor
```

#### 환경 변수 설정

```bash
# clouds.yaml 생성
mkdir -p ~/.config/openstack
cat > ~/.config/openstack/clouds.yaml <<EOF
clouds:
  bifrost:
    auth_type: none
    endpoint: http://localhost:6385
EOF

export OS_CLOUD=bifrost
```

### 3. 노드 등록 및 관리

#### 노드 등록

```bash
# 노드 등록 (IPMI 사용)
openstack baremetal node create \
  --driver ipmi \
  --name node-01 \
  --driver-info ipmi_address=192.168.1.100 \
  --driver-info ipmi_username=admin \
  --driver-info ipmi_password=password

# 포트 생성
openstack baremetal port create \
  --node node-01 \
  aa:bb:cc:dd:ee:ff

# 노드 목록
openstack baremetal node list
```

#### 노드 검사 (Inspection)

```yaml
# inspection-data.json
{
  "node": "node-01",
  "inventory": {
    "interfaces": [
      {
        "name": "eth0",
        "mac_address": "aa:bb:cc:dd:ee:ff",
        "ipv4_address": "192.168.1.101"
      }
    ],
    "disks": [
      {
        "name": "/dev/sda",
        "size": 500000000000
      }
    ],
    "memory": {
      "total": 16000000000
    },
    "cpu": {
      "count": 8
    }
  }
}
```

```bash
# Inspection 실행
openstack baremetal node inspect node-01

# Inspection 상태 확인
openstack baremetal node show node-01
```

#### 이미지 등록

```bash
# 이미지 등록 (Ubuntu 예제)
openstack image create ubuntu-22.04 \
  --file ubuntu-22.04-server-amd64.img \
  --disk-format qcow2 \
  --container-format bare \
  --property os_distro=ubuntu

# Deploy 이미지 및 Kernel/Ramdisk 설정
openstack baremetal node set node-01 \
  --instance-info image_source=ubuntu-22.04 \
  --instance-info kernel=file:///path/to/vmlinuz \
  --instance-info ramdisk=file:///path/to/initrd
```

#### 노드 프로비저닝

```bash
# 노드를 available 상태로 변경
openstack baremetal node manage node-01
openstack baremetal node provide node-01

# 노드 배포
openstack baremetal node deploy node-01 \
  --config-drive '{"meta_data": {}, "user_data": "#!/bin/bash\necho Hello"}'

# 배포 상태 확인
openstack baremetal node show node-01 -f value -c provision_state
# deploying → wait_call_back → deploying → active
```

### 4. Cleaning & Deprovisioning

```bash
# 노드 삭제 (clean 수행)
openstack baremetal node undeploy node-01

# Manual cleaning
openstack baremetal node clean node-01 \
  --clean-steps '[{"interface": "deploy", "step": "erase_devices_metadata"}]'

# 노드 삭제
openstack baremetal node delete node-01
```

---

## 🔗 Part 3: ClusterAPI + Ironic 통합

### 1. CAPO (Cluster API Provider OpenStack)

#### Provider 설치

```bash
# OpenStack credentials 설정
export OPENSTACK_CLOUD=mycloud
export OPENSTACK_CLOUD_YAML_B64=$(base64 -w0 ~/.config/openstack/clouds.yaml)

# CAPO 초기화
clusterctl init --infrastructure openstack

# 확인
kubectl get pods -n capo-system
```

#### OpenStack Cluster 정의

```yaml
# openstack-cluster.yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
kind: OpenStackCluster
metadata:
  name: my-os-cluster
  namespace: default
spec:
  cloudName: mycloud
  dnsNameservers:
    - 8.8.8.8
  externalNetworkId: public-network-id
  managedAPIServerLoadBalancer: true
  managedSecurityGroups: true
  nodeCidr: 10.0.0.0/24
```

#### OpenStack Machine Template

```yaml
# openstack-machine-template.yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
kind: OpenStackMachineTemplate
metadata:
  name: my-os-cluster-control-plane
  namespace: default
spec:
  template:
    spec:
      flavor: m1.large
      image: ubuntu-22.04
      sshKeyName: my-keypair
      cloudName: mycloud
```

### 2. Bare Metal을 사용한 Cluster 생성

```yaml
# baremetal-cluster.yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: baremetal-cluster
  namespace: default
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - 192.168.0.0/16
    services:
      cidrBlocks:
        - 10.96.0.0/12
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
    kind: OpenStackCluster
    name: baremetal-cluster
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: baremetal-cluster-control-plane
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
kind: OpenStackCluster
metadata:
  name: baremetal-cluster
spec:
  cloudName: bifrost  # Ironic standalone
  identityRef:
    name: baremetal-cluster-cloud-config
    kind: Secret
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: baremetal-cluster-control-plane
spec:
  version: v1.28.0
  replicas: 3
  machineTemplate:
    infrastructureRef:
      apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
      kind: OpenStackMachineTemplate
      name: baremetal-cluster-control-plane
  kubeadmConfigSpec:
    initConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: external
    joinConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: external
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
kind: OpenStackMachineTemplate
metadata:
  name: baremetal-cluster-control-plane
spec:
  template:
    spec:
      flavor: baremetal  # Ironic flavor
      image: ubuntu-k8s
      cloudName: bifrost
```

### 3. 자동화 스크립트

```bash
#!/bin/bash
# create-baremetal-cluster.sh

set -e

CLUSTER_NAME="production-k8s"
K8S_VERSION="v1.28.0"
CONTROL_PLANE_COUNT=3
WORKER_COUNT=5

echo "Creating ClusterAPI resources..."

# Cluster 생성
cat <<EOF | kubectl apply -f -
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - 192.168.0.0/16
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
    kind: OpenStackCluster
    name: ${CLUSTER_NAME}
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: ${CLUSTER_NAME}-cp
EOF

# Control Plane 생성
cat <<EOF | kubectl apply -f -
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: ${CLUSTER_NAME}-cp
spec:
  version: ${K8S_VERSION}
  replicas: ${CONTROL_PLANE_COUNT}
  machineTemplate:
    infrastructureRef:
      apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
      kind: OpenStackMachineTemplate
      name: ${CLUSTER_NAME}-cp
  kubeadmConfigSpec:
    initConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: external
EOF

# Worker 노드 생성
cat <<EOF | kubectl apply -f -
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: ${CLUSTER_NAME}-workers
spec:
  clusterName: ${CLUSTER_NAME}
  replicas: ${WORKER_COUNT}
  selector:
    matchLabels: {}
  template:
    spec:
      clusterName: ${CLUSTER_NAME}
      version: ${K8S_VERSION}
      bootstrap:
        configRef:
          apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
          kind: KubeadmConfigTemplate
          name: ${CLUSTER_NAME}-worker
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1alpha7
        kind: OpenStackMachineTemplate
        name: ${CLUSTER_NAME}-worker
EOF

echo "Waiting for cluster to be ready..."
clusterctl describe cluster ${CLUSTER_NAME}

echo "Cluster created successfully!"
echo "To get kubeconfig:"
echo "  clusterctl get kubeconfig ${CLUSTER_NAME} > ${CLUSTER_NAME}.kubeconfig"
```

---

## 📚 참고 자료

### Cluster API

- [Cluster API Official Documentation](https://cluster-api.sigs.k8s.io/)
- [Cluster API Book](https://cluster-api.sigs.k8s.io/user/quick-start)
- [ClusterAPI GitHub](https://github.com/kubernetes-sigs/cluster-api)
- [ClusterAPI Providers](https://cluster-api.sigs.k8s.io/reference/providers)

### OpenStack Ironic

- [Ironic Documentation](https://docs.openstack.org/ironic/latest/)
- [Ironic User Guide](https://docs.openstack.org/ironic/latest/user/)
- [Bifrost Documentation](https://docs.openstack.org/bifrost/latest/)
- [Ironic Python Agent](https://docs.openstack.org/ironic-python-agent/latest/)

### 통합

- [CAPO - Cluster API Provider OpenStack](https://github.com/kubernetes-sigs/cluster-api-provider-openstack)
- [Metal3 - Bare Metal Provisioning](https://metal3.io/)

---

## ✅ 학습 체크리스트

- [ ] ClusterAPI 핵심 개념 이해 (Cluster, Machine, MachineDeployment)
- [ ] clusterctl로 Management Cluster 구성
- [ ] Workload Cluster 생성 및 관리
- [ ] 클러스터 스케일링 및 업그레이드
- [ ] Ironic 아키텍처 이해
- [ ] Ironic으로 베어메탈 노드 등록 및 프로비저닝
- [ ] CAPO를 사용한 OpenStack 기반 클러스터 생성
- [ ] ClusterAPI + Ironic 통합 구성

---

## 🎓 다음 단계

ClusterAPI & Ironic을 마스터한 후:

- [Ch3. Infrastructure as Code (IaC)](./Ch3.IaC.md)로 진행
- 또는 [README](./README.md)로 돌아가서 학습 로드맵 확인
