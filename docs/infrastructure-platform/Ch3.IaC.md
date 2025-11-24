# Ch3. Infrastructure as Code (IaC)

## 📋 개요

Infrastructure as Code (IaC)는 인프라를 코드로 정의하고 버전 관리하여, 일관되고 반복 가능한 인프라 배포를 가능하게 합니다. Terraform, Ansible, Packer는 IaC 생태계에서 가장 널리 사용되는 도구입니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:

- Terraform으로 인프라 리소스 정의 및 관리
- Ansible로 서버 설정 자동화
- Packer로 머신 이미지 빌드 자동화
- IaC 모범 사례 (모듈화, 상태 관리, 보안) 적용

---

## 🏗️ Part 1: Terraform

### 1. Terraform 기초

**Terraform의 핵심 개념:**

- **선언적(Declarative)**: 원하는 최종 상태를 정의
- **멱등성(Idempotent)**: 여러 번 실행해도 같은 결과
- **Provider 기반**: AWS, Azure, GCP, Kubernetes 등 다양한 플랫폼 지원

#### 기본 구조

```hcl
# main.tf
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "main-vpc"
    Environment = var.environment
  }
}

# 서브넷 생성
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}
```

```hcl
# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```

```hcl
# outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}
```

#### Terraform 워크플로우

```bash
# 초기화 (Provider 다운로드)
terraform init

# 실행 계획 확인
terraform plan

# 인프라 배포
terraform apply

# 리소스 조회
terraform show
terraform state list

# 인프라 삭제
terraform destroy
```

### 2. Terraform 모듈

**모듈 구조:**
```
modules/
└── vpc/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

**모듈 정의 (modules/vpc/main.tf):**
```hcl
# modules/vpc/main.tf
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = var.vpc_name
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-${count.index + 1}"
      Type = "public"
    }
  )
}
```

```hcl
# modules/vpc/variables.tf
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}
```

**모듈 사용:**
```hcl
# main.tf
module "vpc" {
  source = "./modules/vpc"

  vpc_name             = "production-vpc"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# 모듈 출력 사용
output "vpc_id" {
  value = module.vpc.vpc_id
}
```

### 3. State 관리 (2025 Best Practice)

#### Remote Backend (S3 + DynamoDB)

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "production/vpc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

**S3 버킷 및 DynamoDB 생성:**
```bash
# S3 버킷 생성 (버전 관리 활성화)
aws s3api create-bucket \
  --bucket my-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket my-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket my-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# DynamoDB 테이블 생성 (State locking)
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

#### Workspace (환경 분리)

```bash
# Workspace 목록
terraform workspace list

# 새 Workspace 생성
terraform workspace new staging
terraform workspace new production

# Workspace 전환
terraform workspace select production

# 현재 Workspace 확인
terraform workspace show
```

```hcl
# Workspace별 설정
locals {
  env_config = {
    staging = {
      instance_type = "t3.small"
      instance_count = 2
    }
    production = {
      instance_type = "t3.large"
      instance_count = 5
    }
  }

  current_env = local.env_config[terraform.workspace]
}

resource "aws_instance" "app" {
  count         = local.current_env.instance_count
  instance_type = local.current_env.instance_type
  # ...
}
```

### 4. Terraform Best Practices (2025)

**1. 모듈화 및 재사용:**
```
✅ 작고 집중된 모듈 (Single Responsibility)
✅ 버전 관리된 모듈
✅ 명확한 입력/출력 정의
```

**2. State 보안:**
```hcl
# Sensitive 데이터 보호
output "db_password" {
  value     = aws_db_instance.main.password
  sensitive = true  # 로그에 출력되지 않음
}
```

**3. 환경 분리:**
```
environments/
├── dev/
│   ├── main.tf
│   ├── variables.tf
│   └── backend.tf (다른 S3 key)
├── staging/
└── production/
```

**4. 변수 파일 사용:**
```hcl
# terraform.tfvars (Git에 커밋)
environment = "production"
aws_region  = "us-east-1"

# secrets.tfvars (Git에서 제외)
db_password = "super-secret-password"

# 적용
terraform apply -var-file="terraform.tfvars" -var-file="secrets.tfvars"
```

---

## ⚙️ Part 2: Ansible

### 1. Ansible 기초

**Inventory 파일:**
```ini
# inventory/hosts.ini
[webservers]
web1.example.com
web2.example.com
web3.example.com

[databases]
db1.example.com
db2.example.com

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

**동적 Inventory (2025 Best Practice):**
```yaml
# inventory/aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  tag:Environment: production
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: placement.availability_zone
    prefix: az
```

```bash
# 동적 inventory 사용
ansible-inventory -i inventory/aws_ec2.yml --list
ansible-playbook -i inventory/aws_ec2.yml playbook.yml
```

### 2. Playbook 작성

**기본 Playbook:**
```yaml
# playbook.yml
---
- name: Configure web servers
  hosts: webservers
  become: yes

  vars:
    nginx_version: "1.24"
    app_port: 8080

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install Nginx
      apt:
        name: nginx={{ nginx_version }}*
        state: present

    - name: Copy Nginx configuration
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: '0644'
      notify: Reload Nginx

    - name: Ensure Nginx is running
      service:
        name: nginx
        state: started
        enabled: yes

  handlers:
    - name: Reload Nginx
      service:
        name: nginx
        state: reloaded
```

### 3. Ansible Roles (2025 Best Practice)

**Role 구조:**
```
roles/
└── nginx/
    ├── tasks/
    │   └── main.yml
    ├── handlers/
    │   └── main.yml
    ├── templates/
    │   └── nginx.conf.j2
    ├── files/
    ├── vars/
    │   └── main.yml
    ├── defaults/
    │   └── main.yml
    └── meta/
        └── main.yml
```

**Role 정의:**
```yaml
# roles/nginx/tasks/main.yml
---
- name: Install Nginx
  apt:
    name: nginx={{ nginx_version }}
    state: present
  when: ansible_os_family == "Debian"

- name: Install Nginx (RedHat)
  yum:
    name: nginx-{{ nginx_version }}
    state: present
  when: ansible_os_family == "RedHat"

- name: Copy Nginx configuration
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload Nginx

- name: Start Nginx service
  service:
    name: nginx
    state: started
    enabled: yes
```

```yaml
# roles/nginx/defaults/main.yml
---
nginx_version: "1.24"
nginx_port: 80
nginx_worker_processes: auto
nginx_worker_connections: 1024
```

```yaml
# roles/nginx/handlers/main.yml
---
- name: Reload Nginx
  service:
    name: nginx
    state: reloaded

- name: Restart Nginx
  service:
    name: nginx
    state: restarted
```

**Role 사용:**
```yaml
# site.yml
---
- name: Configure web servers
  hosts: webservers
  become: yes

  roles:
    - role: nginx
      vars:
        nginx_port: 8080
    - role: app_deploy
```

### 4. Ansible Vault (보안)

```bash
# Vault 파일 생성
ansible-vault create secrets.yml

# Vault 파일 편집
ansible-vault edit secrets.yml

# Vault 파일 암호화
ansible-vault encrypt vars/secrets.yml

# Vault 파일 복호화
ansible-vault decrypt vars/secrets.yml
```

```yaml
# secrets.yml (암호화됨)
---
db_password: "super-secret-password"
api_key: "secret-api-key-12345"
```

```yaml
# playbook에서 사용
- name: Deploy application
  hosts: webservers
  vars_files:
    - vars/secrets.yml

  tasks:
    - name: Configure database connection
      template:
        src: config.j2
        dest: /app/config.yml
```

```bash
# Vault 비밀번호와 함께 실행
ansible-playbook -i inventory playbook.yml --ask-vault-pass

# 비밀번호 파일 사용
ansible-playbook -i inventory playbook.yml --vault-password-file ~/.vault_pass
```

---

## 📦 Part 3: Packer

### 1. Packer 기초

**Packer Template (HCL2 포맷):**
```hcl
# ubuntu-k8s.pkr.hcl
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "k8s_version" {
  type    = string
  default = "1.28.0"
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-k8s-${var.k8s_version}-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.aws_region

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]  # Canonical
    most_recent = true
  }

  ssh_username = "ubuntu"

  tags = {
    Name        = "ubuntu-k8s-${var.k8s_version}"
    Environment = "production"
    OS          = "Ubuntu 22.04"
    K8sVersion  = var.k8s_version
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  # 시스템 업데이트
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y apt-transport-https ca-certificates curl",
    ]
  }

  # Docker 설치
  provisioner "shell" {
    script = "scripts/install-docker.sh"
  }

  # Kubernetes 설치
  provisioner "shell" {
    environment_vars = [
      "K8S_VERSION=${var.k8s_version}",
    ]
    script = "scripts/install-k8s.sh"
  }

  # Ansible로 설정
  provisioner "ansible" {
    playbook_file = "ansible/configure.yml"
  }

  # 정리 작업
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "history -c",
    ]
  }

  # AMI 검증
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
```

**프로비저닝 스크립트:**
```bash
# scripts/install-docker.sh
#!/bin/bash
set -e

# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Docker 서비스 시작
sudo systemctl enable docker
sudo systemctl start docker

# 사용자를 docker 그룹에 추가
sudo usermod -aG docker ubuntu

echo "Docker installed successfully"
```

```bash
# scripts/install-k8s.sh
#!/bin/bash
set -e

K8S_VERSION=${K8S_VERSION:-1.28.0}

# Kubernetes 저장소 추가
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# kubeadm, kubelet, kubectl 설치
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "Kubernetes ${K8S_VERSION} installed successfully"
```

### 2. Packer 빌드

```bash
# 템플릿 검증
packer validate ubuntu-k8s.pkr.hcl

# 빌드 (dry-run)
packer build -debug ubuntu-k8s.pkr.hcl

# 실제 빌드
packer build ubuntu-k8s.pkr.hcl

# 변수 오버라이드
packer build \
  -var 'k8s_version=1.29.0' \
  -var 'instance_type=t3.large' \
  ubuntu-k8s.pkr.hcl
```

### 3. Multi-Platform 빌드

```hcl
# multi-cloud.pkr.hcl
source "amazon-ebs" "aws" {
  ami_name = "myapp-aws-{{timestamp}}"
  # AWS 설정...
}

source "azure-arm" "azure" {
  image_name = "myapp-azure-{{timestamp}}"
  # Azure 설정...
}

source "googlecompute" "gcp" {
  image_name = "myapp-gcp-{{timestamp}}"
  # GCP 설정...
}

build {
  sources = [
    "source.amazon-ebs.aws",
    "source.azure-arm.azure",
    "source.googlecompute.gcp",
  ]

  # 공통 프로비저닝
  provisioner "shell" {
    scripts = [
      "scripts/update.sh",
      "scripts/install-app.sh",
    ]
  }
}
```

---

## 📚 참고 자료

### Terraform

- [Terraform Documentation](https://developer.hashicorp.com/terraform)
- [Terraform Best Practices 2025](https://www.elysiate.com/blog/terraform-best-practices-infrastructure-as-code-2025)
- [Terraform Module Registry](https://registry.terraform.io/)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Ansible

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/)
- [Ansible Best Practices 2025](https://www.gocodeo.com/post/ansible-in-2025-best-practices-for-configuration-and-provisioning)
- [Good Practices for Ansible](https://redhat-cop.github.io/automation-good-practices/)

### Packer

- [Packer Documentation](https://developer.hashicorp.com/packer)
- [Packer Plugin Registry](https://developer.hashicorp.com/packer/plugins)
- [HCL2 Configuration](https://developer.hashicorp.com/packer/guides/hcl)

---

## ✅ 학습 체크리스트

### Terraform

- [ ] 리소스 정의 및 프로비저닝
- [ ] 모듈 작성 및 재사용
- [ ] Remote Backend 설정 (S3 + DynamoDB)
- [ ] Workspace를 통한 환경 분리
- [ ] State 파일 보안 및 관리
- [ ] 변수 및 출력값 사용

### Ansible

- [ ] Inventory 파일 작성 (정적/동적)
- [ ] Playbook 작성
- [ ] Role 구조 이해 및 작성
- [ ] Ansible Vault로 비밀 관리
- [ ] 템플릿(Jinja2) 사용
- [ ] Handler 및 알림 사용

### Packer

- [ ] Packer 템플릿 작성 (HCL2)
- [ ] 프로비저너 사용 (Shell, Ansible)
- [ ] 이미지 빌드 및 검증
- [ ] Multi-platform 빌드

---

## 🎓 다음 단계

IaC를 마스터한 후:

- [Ch4. Cloud-Native 플랫폼 구성 도구](./Ch4.Cloud_Native_플랫폼_도구.md)로 진행
- 또는 [README](./README.md)로 돌아가서 학습 로드맵 확인
