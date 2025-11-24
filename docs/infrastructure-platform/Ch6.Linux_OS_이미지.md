# Ch6. Linux OS 이미지 관리 및 빌드

## 📋 개요

클라우드 환경에서 일관되고 안전한 인프라를 구축하기 위해서는 표준화된 OS 이미지 관리가 필수적입니다. 본 장에서는 Linux OS 이미지의 구조를 이해하고, HashiCorp Packer를 활용한 자동화된 Golden Image 빌드 파이프라인 구축, cloud-init을 통한 초기화 자동화, 그리고 이미지 디버깅 및 최적화 기법을 학습합니다.

2025년 현재, **Golden Image Pipeline**은 Infrastructure as Code의 핵심 요소로 자리잡았으며, 보안 패치와 컴플라이언스 요구사항을 자동으로 반영하는 이미지 빌드 자동화가 표준이 되었습니다.

## 🎯 학습 목표

1. **Linux OS 이미지 구조 이해**
   - 부팅 프로세스 (BIOS/UEFI, bootloader, kernel, initramfs)
   - 파일시스템 구조 및 파티션 레이아웃
   - Cloud 이미지 vs ISO 이미지 차이점

2. **Packer를 활용한 이미지 빌드**
   - HCL2 문법으로 Packer 템플릿 작성
   - Multi-cloud 이미지 빌드 (AWS, Azure, GCP, OpenStack)
   - Provisioner를 활용한 이미지 커스터마이징

3. **cloud-init 마스터하기**
   - cloud-init 단계 및 데이터소스 이해
   - user-data, meta-data, vendor-data 활용
   - 네트워크 설정 및 초기 설정 자동화

4. **Golden Image Pipeline 구축**
   - CI/CD를 통한 자동화된 이미지 빌드
   - HCP Packer를 활용한 이미지 버전 관리
   - 보안 스캔 및 검증 통합

5. **이미지 디버깅 및 최적화**
   - chroot 환경에서 이미지 수정
   - 이미지 크기 최적화 기법
   - 부팅 시간 단축 및 성능 튜닝

---

## Part 1: Linux OS 이미지 구조

### 1.1 부팅 프로세스 이해

**전통적인 부팅 플로우:**
```
1. BIOS/UEFI Firmware
   ↓
2. Bootloader (GRUB2)
   ↓ (loads)
3. Linux Kernel (vmlinuz)
   ↓ (unpacks)
4. initramfs (Initial RAM filesystem)
   ↓ (mounts)
5. Root Filesystem
   ↓ (executes)
6. Init System (systemd)
   ↓
7. User Space Services
```

**UEFI vs BIOS:**
| 특징 | BIOS | UEFI |
|------|------|------|
| 파티션 스킴 | MBR (2TB 제한) | GPT (9.4ZB 지원) |
| 부팅 속도 | 느림 | 빠름 |
| 보안 | 제한적 | Secure Boot 지원 |
| 인터페이스 | 텍스트 기반 | GUI 지원 |

### 1.2 이미지 타입 비교

**ISO 이미지 vs Cloud 이미지:**

**ISO 이미지:**

- 설치 미디어 (installation media)
- Anaconda/Ubiquity 등 인스톨러 포함
- 사용자 상호작용 필요
- 설치 시간 10-30분

**Cloud 이미지:**

- 사전 설치된 OS (pre-installed)
- cloud-init으로 설정 자동화
- 완전 자동화 가능
- 부팅 즉시 사용 가능 (1-2분)

**클라우드 이미지 구조:**
```
cloud-image.qcow2
├── Boot Partition (EFI System Partition)
│   └── /boot/efi/EFI/ubuntu/
│       ├── grubx64.efi
│       └── shimx64.efi
├── Root Partition (/)
│   ├── /bin, /usr, /lib, /etc
│   ├── /var/lib/cloud/  (cloud-init data)
│   └── /etc/cloud/cloud.cfg
└── (Optional) Data Partition
```

### 1.3 파일시스템 및 파티션

**일반적인 파티션 레이아웃 (GPT/UEFI):**
```bash
# parted -l 출력 예시
Number  Start   End     Size    File system  Name                  Flags
 1      1049kB  538MB   537MB   fat32        EFI System Partition  boot, esp
 2      538MB   1612MB  1074MB  ext4         Boot Partition
 3      1612MB  100GB   98.4GB  ext4         Root Partition
```

**Packer로 생성할 때 권장 레이아웃:**
```hcl
# qemu builder의 disk_size 설정
source "qemu" "ubuntu" {
  disk_size         = "20G"
  disk_interface    = "virtio"
  format            = "qcow2"

  # 파티션 자동 생성은 boot_command 또는 preseed로 제어
}
```

---

## Part 2: HashiCorp Packer - 이미지 빌드 자동화

### 2.1 Packer 아키텍처

**핵심 컴포넌트:**

- **Source**: 이미지 빌드 환경 정의 (AWS, Azure, QEMU 등)
- **Build**: Source를 실행하고 Provisioner 적용
- **Provisioner**: 이미지 커스터마이징 (Shell, Ansible, file 등)
- **Post-Processor**: 빌드 후 처리 (압축, 업로드, manifest)

**Packer 워크플로우:**
```
1. Source 정의 (builder)
   ↓
2. VM/인스턴스 생성
   ↓
3. 부팅 및 연결 (SSH/WinRM)
   ↓
4. Provisioner 실행 (커스터마이징)
   ↓
5. Graceful Shutdown
   ↓
6. 이미지 스냅샷 생성
   ↓
7. Post-Processing (선택적)
   ↓
8. 리소스 정리
```

### 2.2 Packer HCL2 템플릿 작성

**기본 구조:**

```hcl
# ubuntu-2204.pkr.hcl
packer {
  required_version = ">= 1.10.0"
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

# 변수 정의
variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "version" {
  type    = string
  default = "1.0.0"
}

variable "environment" {
  type    = string
  default = "production"
}

# 로컬 변수
locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
  image_name = "ubuntu-2204-${var.environment}-${local.timestamp}"
}

# AWS AMI Source
source "amazon-ebs" "ubuntu" {
  ami_name      = local.image_name
  instance_type = "t3.small"
  region        = var.aws_region

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = "ubuntu"

  # 태그
  tags = {
    Name        = local.image_name
    Environment = var.environment
    Version     = var.version
    BuildDate   = local.timestamp
    OS          = "Ubuntu 22.04"
    ManagedBy   = "Packer"
  }

  # 스냅샷 태그
  snapshot_tags = {
    Name = "${local.image_name}-snapshot"
  }
}

# QEMU Source (로컬 빌드 또는 OpenStack)
source "qemu" "ubuntu" {
  iso_url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  iso_checksum     = "sha256:..." # ISO 체크섬

  output_directory = "output-qemu"
  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"

  ssh_username     = "ubuntu"
  ssh_password     = "ubuntu"
  ssh_timeout      = "20m"

  vm_name          = local.image_name
  net_device       = "virtio-net"
  disk_interface   = "virtio"

  # cloud-init을 사용한 초기 설정
  cd_files = [
    "./cloud-init/meta-data",
    "./cloud-init/user-data"
  ]
  cd_label = "cidata"

  headless         = true

  qemuargs = [
    ["-m", "2048M"],
    ["-smp", "2"]
  ]
}

# Build 블록
build {
  name = "ubuntu-golden-image"

  sources = [
    "source.amazon-ebs.ubuntu",
    "source.qemu.ubuntu"
  ]

  # 시스템 업데이트
  provisioner "shell" {
    inline = [
      "echo 'Starting system update...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo apt-get clean"
    ]
  }

  # 패키지 설치
  provisioner "shell" {
    script = "./scripts/install-packages.sh"
  }

  # Ansible Provisioner
  provisioner "ansible" {
    playbook_file = "./ansible/setup.yml"
    user          = "ubuntu"
    extra_arguments = [
      "--extra-vars",
      "env=${var.environment}"
    ]
  }

  # 파일 복사
  provisioner "file" {
    source      = "./configs/custom.conf"
    destination = "/tmp/custom.conf"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/custom.conf /etc/myapp/custom.conf"
    ]
  }

  # 정리 스크립트
  provisioner "shell" {
    script = "./scripts/cleanup.sh"
  }

  # cloud-init 리셋 (중요!)
  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs --seed"
    ]
  }

  # Post-processor: manifest 생성
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
    custom_data = {
      version     = var.version
      environment = var.environment
      build_date  = local.timestamp
    }
  }

  # Post-processor: checksum 생성
  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "packer_{{.BuildName}}_{{.ChecksumType}}.checksum"
  }
}
```

### 2.3 실전 Provisioner 스크립트

**install-packages.sh:**
```bash
#!/bin/bash
set -e

echo "=== Installing required packages ==="

# 기본 도구
sudo apt-get install -y \
  curl \
  wget \
  vim \
  git \
  htop \
  jq \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release

# Docker 설치
echo "=== Installing Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker 사용자 추가
sudo usermod -aG docker ubuntu

# Kubernetes 도구 설치
echo "=== Installing Kubernetes tools ==="
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 보안 강화
echo "=== Security hardening ==="
sudo apt-get install -y \
  fail2ban \
  ufw \
  auditd

# UFW 기본 설정 (SSH 허용)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
# 주의: UFW는 cloud-init에서 활성화

echo "=== Package installation completed ==="
```

**cleanup.sh:**
```bash
#!/bin/bash
set -e

echo "=== Cleaning up image ==="

# APT 캐시 정리
sudo apt-get clean
sudo apt-get autoremove -y
sudo rm -rf /var/lib/apt/lists/*

# 로그 정리
sudo find /var/log -type f -delete
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# SSH 키 삭제 (보안)
sudo rm -f /home/ubuntu/.ssh/authorized_keys
sudo rm -f /root/.ssh/authorized_keys

# 머신 ID 리셋 (중요: 각 인스턴스가 고유 ID 생성)
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# 네트워크 설정 초기화
sudo rm -f /etc/udev/rules.d/70-persistent-net.rules

# 쉘 히스토리 삭제
history -c
cat /dev/null > ~/.bash_history

# cloud-init 로그 및 캐시 정리
sudo cloud-init clean --logs --seed

echo "=== Cleanup completed ==="
```

---

## Part 3: cloud-init 마스터하기

### 3.1 cloud-init 개요 및 단계

**cloud-init 실행 단계:**
```
1. Generator (systemd-generator)
   ↓
2. Local Stage (cloud-init-local.service)
   - 데이터소스 감지
   - 네트워크 설정 (early network)
   ↓
3. Network Stage (cloud-init.service)
   - 네트워크 완전 초기화
   - user-data 및 meta-data 가져오기
   ↓
4. Config Stage (cloud-config.service)
   - cloud-config 모듈 실행
   - 패키지 설치, 사용자 생성 등
   ↓
5. Final Stage (cloud-final.service)
   - 최종 스크립트 실행
   - 사용자 정의 스크립트
```

**데이터소스 타입:**

- **NoCloud**: ISO 또는 HTTP로 제공 (로컬 테스트용)
- **EC2**: AWS 메타데이터 서비스 (169.254.169.254)
- **OpenStack**: OpenStack 메타데이터 서비스
- **Azure**: Azure 메타데이터
- **GCP**: Google Compute Engine 메타데이터

### 3.2 user-data 작성 (cloud-config)

**기본 cloud-config 예시:**

```yaml
#cloud-config

# 호스트명 설정
hostname: web-server-01
fqdn: web-server-01.example.com

# 사용자 생성
users:
  - name: devops
    groups: sudo, docker
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@example.com

  - name: app
    groups: app
    shell: /bin/bash
    lock_passwd: true  # 패스워드 로그인 비활성화

# 패키지 업데이트 및 설치
package_update: true
package_upgrade: true
packages:
  - nginx
  - postgresql
  - redis-server
  - python3-pip
  - git

# 파일 작성
write_files:
  - path: /etc/nginx/sites-available/myapp
    owner: root:root
    permissions: '0644'
    content: |
      server {
        listen 80;
        server_name myapp.example.com;

        location / {
          proxy_pass http://127.0.0.1:8000;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
        }
      }

  - path: /opt/app/config.json
    owner: app:app
    permissions: '0640'
    content: |
      {
        "database": {
          "host": "localhost",
          "port": 5432
        },
        "redis": {
          "host": "localhost",
          "port": 6379
        }
      }

  - path: /etc/systemd/system/myapp.service
    owner: root:root
    permissions: '0644'
    content: |
      [Unit]
      Description=My Application
      After=network.target postgresql.service redis.service

      [Service]
      Type=simple
      User=app
      WorkingDirectory=/opt/app
      ExecStart=/usr/bin/python3 /opt/app/server.py
      Restart=on-failure

      [Install]
      WantedBy=multi-user.target

# runcmd: 명령 실행
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
  - ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
  - systemctl reload nginx

  - systemctl enable myapp
  - systemctl start myapp

  # Docker 컨테이너 실행
  - docker run -d --name redis -p 6379:6379 redis:latest

  # 방화벽 설정
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable

# 부팅 후 한 번만 실행되는 스크립트
bootcmd:
  - echo "First boot initialization" >> /var/log/first-boot.log

# 재부팅 (필요시)
power_state:
  mode: reboot
  delay: now
  message: Rebooting after cloud-init
  condition: true  # 또는 False
```

**멀티파트 user-data (복합 형식):**

```yaml
Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"

#cloud-config
packages:
  - docker.io
  - kubernetes

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
echo "Custom shell script"
docker pull myapp:latest
docker run -d myapp:latest

--==BOUNDARY==
Content-Type: text/cloud-boothook; charset="us-ascii"

#!/bin/bash
# 매 부팅마다 실행
echo "Running on every boot"

--==BOUNDARY==--
```

### 3.3 meta-data 및 vendor-data

**meta-data (NoCloud 예시):**
```yaml
instance-id: i-0123456789abcdef0
local-hostname: web-server-01
public-keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...
```

**network-config (v2 - Netplan 형식):**
```yaml
version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
      - 192.168.1.100/24
    gateway4: 192.168.1.1
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4
```

**vendor-data (클라우드 제공자가 제공):**
```yaml
#cloud-config
# 제공자가 강제하는 설정
packages:
  - cloud-provider-agent
```

### 3.4 Packer에서 cloud-init 사용

**QEMU Builder + cloud-init:**

```
project/
├── ubuntu.pkr.hcl
└── cloud-init/
    ├── meta-data
    └── user-data
```

**cloud-init/meta-data:**
```yaml
instance-id: packer-build-{{ isotime "20060102-150405" }}
local-hostname: packer-ubuntu
```

**cloud-init/user-data:**
```yaml
#cloud-config
password: ubuntu
chpasswd: { expire: False }
ssh_pwauth: True

# Packer SSH 접근을 위한 임시 설정
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
```

**Packer 템플릿에서 사용:**
```hcl
source "qemu" "ubuntu" {
  # ... 기타 설정 ...

  cd_files = [
    "./cloud-init/meta-data",
    "./cloud-init/user-data"
  ]
  cd_label = "cidata"
}
```

---

## Part 4: Golden Image Pipeline

### 4.1 CI/CD 통합 (GitHub Actions)

**.github/workflows/build-image.yml:**
```yaml
name: Build Golden Image

on:
  push:
    branches:
      - main
    paths:
      - 'packer/**'
  schedule:
    # 매주 월요일 새벽 2시 (보안 패치 자동 적용)
    - cron: '0 2 * * 1'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

env:
  PACKER_VERSION: '1.10.0'

jobs:
  validate:
    name: Validate Packer Template
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Packer
        uses: hashicorp/setup-packer@main
        with:
          version: ${{ env.PACKER_VERSION }}

      - name: Initialize Packer
        run: packer init packer/

      - name: Validate Template
        run: packer validate packer/ubuntu.pkr.hcl

      - name: Format Check
        run: packer fmt -check packer/

  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: 'packer/'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  build:
    name: Build Image
    runs-on: ubuntu-latest
    needs: [validate, security-scan]
    permissions:
      id-token: write  # OIDC 인증
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GithubActionsPackerRole
          aws-region: ap-northeast-2

      - name: Setup Packer
        uses: hashicorp/setup-packer@main
        with:
          version: ${{ env.PACKER_VERSION }}

      - name: Initialize Packer
        run: packer init packer/

      - name: Build Image
        run: |
          packer build \
            -var "environment=${{ github.event.inputs.environment || 'staging' }}" \
            -var "version=${{ github.sha }}" \
            packer/ubuntu.pkr.hcl

      - name: Upload Manifest
        uses: actions/upload-artifact@v3
        with:
          name: packer-manifest
          path: packer/manifest.json

  test:
    name: Test Image
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Download Manifest
        uses: actions/download-artifact@v3
        with:
          name: packer-manifest

      - name: Extract AMI ID
        id: ami
        run: |
          AMI_ID=$(jq -r '.builds[0].artifact_id' manifest.json | cut -d':' -f2)
          echo "ami_id=$AMI_ID" >> $GITHUB_OUTPUT

      - name: Test AMI with Kitchen (or custom test)
        run: |
          # 여기에 테스트 로직 추가
          # 예: AWS에서 인스턴스 생성 → 검증 스크립트 실행 → 삭제
          echo "Testing AMI: ${{ steps.ami.outputs.ami_id }}"

  promote:
    name: Promote to Production
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Tag AMI as Production-Ready
        run: |
          # AMI에 Production 태그 추가
          aws ec2 create-tags \
            --resources ${{ steps.ami.outputs.ami_id }} \
            --tags Key=Environment,Value=production Key=Status,Value=approved
```

### 4.2 HCP Packer 통합

**HCP Packer란?**
HashiCorp Cloud Platform Packer는 이미지 메타데이터를 중앙에서 관리하고, Terraform과 통합하여 항상 최신의 검증된 이미지를 사용하도록 보장합니다.

**Packer 템플릿에 HCP Packer 추가:**
```hcl
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# HCP Packer 설정
hcp_packer_registry {
  bucket_name = "ubuntu-2204-golden-image"
  description = "Ubuntu 22.04 Golden Image for Production"

  bucket_labels = {
    "os"          = "ubuntu"
    "os_version"  = "22.04"
    "team"        = "platform"
  }

  build_labels = {
    "build_time" = timestamp()
    "git_sha"    = var.git_sha
  }
}

build {
  # HCP Packer는 자동으로 이미지 메타데이터 수집
  sources = ["source.amazon-ebs.ubuntu"]

  # ... provisioners ...
}
```

**Terraform에서 HCP Packer 이미지 사용:**
```hcl
data "hcp_packer_iteration" "ubuntu" {
  bucket_name = "ubuntu-2204-golden-image"
  channel     = "production"  # 또는 "latest", "staging"
}

data "hcp_packer_image" "ubuntu_ap_northeast_2" {
  bucket_name    = data.hcp_packer_iteration.ubuntu.bucket_name
  iteration_id   = data.hcp_packer_iteration.ubuntu.id
  cloud_provider = "aws"
  region         = "ap-northeast-2"
}

resource "aws_instance" "web" {
  ami           = data.hcp_packer_image.ubuntu_ap_northeast_2.cloud_image_id
  instance_type = "t3.micro"

  tags = {
    Name = "web-server"
  }
}
```

### 4.3 보안 스캔 통합

**Packer 템플릿에 Trivy 스캔 추가:**
```hcl
build {
  sources = ["source.amazon-ebs.ubuntu"]

  # ... provisioners ...

  # 보안 스캔
  provisioner "shell" {
    inline = [
      "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin",
      "sudo trivy rootfs --severity HIGH,CRITICAL --exit-code 1 /"
    ]
  }
}
```

---

## Part 5: 이미지 디버깅 및 최적화

### 5.1 chroot 환경에서 이미지 수정

**QCOW2 이미지 마운트 및 수정:**

```bash
# 1. qcow2를 nbd로 연결
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 image.qcow2

# 2. 파티션 확인
sudo fdisk -l /dev/nbd0

# 3. 파티션 마운트
sudo mount /dev/nbd0p1 /mnt

# 4. chroot 환경 준비
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys

# 5. chroot 진입
sudo chroot /mnt /bin/bash

# 이제 이미지 내부에서 작업 가능
apt-get update
apt-get install vim
# ... 필요한 작업 수행 ...

# 6. 빠져나오기
exit

# 7. 언마운트
sudo umount /mnt/sys
sudo umount /mnt/proc
sudo umount /mnt/dev
sudo umount /mnt

# 8. nbd 연결 해제
sudo qemu-nbd --disconnect /dev/nbd0
```

**스크립트로 자동화:**
```bash
#!/bin/bash
# mount-image.sh

IMAGE=$1
MOUNT_POINT=/mnt/image

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <image.qcow2>"
  exit 1
fi

# NBD 연결
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 "$IMAGE"
sleep 2

# 마운트
sudo mkdir -p "$MOUNT_POINT"
sudo mount /dev/nbd0p1 "$MOUNT_POINT"
sudo mount --bind /dev "$MOUNT_POINT/dev"
sudo mount --bind /proc "$MOUNT_POINT/proc"
sudo mount --bind /sys "$MOUNT_POINT/sys"

echo "Image mounted at $MOUNT_POINT"
echo "Run: sudo chroot $MOUNT_POINT /bin/bash"
echo "When done, run: ./umount-image.sh"
```

### 5.2 이미지 크기 최적화

**불필요한 패키지 제거:**
```bash
# 개발 도구 제거 (프로덕션 이미지에서)
sudo apt-get purge -y \
  build-essential \
  gcc \
  g++ \
  make

# 문서 파일 제거
sudo rm -rf /usr/share/doc/*
sudo rm -rf /usr/share/man/*
sudo rm -rf /usr/share/locale/*

# 캐시 정리
sudo apt-get clean
sudo apt-get autoremove -y
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /var/cache/apt/*

# 로그 정리
sudo find /var/log -type f -delete
```

**QCOW2 이미지 압축:**
```bash
# Sparse file 최적화
qemu-img convert -O qcow2 -c input.qcow2 output-compressed.qcow2

# 크기 비교
ls -lh input.qcow2 output-compressed.qcow2

# 더 공격적인 압축
qemu-img convert -O qcow2 -c -o compression_type=zstd input.qcow2 output-zstd.qcow2
```

**Zero-fill 미사용 공간:**
```bash
# 이미지 내부에서 실행 (chroot 환경)
sudo dd if=/dev/zero of=/EMPTY bs=1M || true
sudo rm -f /EMPTY

# 그 후 외부에서 압축
qemu-img convert -O qcow2 -c input.qcow2 optimized.qcow2
```

### 5.3 부팅 시간 최적화

**systemd 분석:**
```bash
# 부팅 시간 확인
systemd-analyze

# 서비스별 시간
systemd-analyze blame

# Critical chain
systemd-analyze critical-chain

# 그래프 생성
systemd-analyze plot > boot.svg
```

**불필요한 서비스 비활성화:**
```bash
# 클라우드 환경에서 불필요한 서비스
sudo systemctl disable bluetooth.service
sudo systemctl disable ModemManager.service
sudo systemctl disable wpa_supplicant.service

# 부팅 후 확인
sudo systemctl list-unit-files --state=enabled
```

**커널 파라미터 튜닝:**
```bash
# /etc/default/grub 수정
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nomodeset"

# 적용
sudo update-grub
```

### 5.4 이미지 검증 및 테스트

**자동화된 테스트 스크립트:**
```bash
#!/bin/bash
# test-image.sh

set -e

echo "=== Testing Image ==="

# 1. 필수 패키지 확인
REQUIRED_PACKAGES="docker.io kubectl nginx"
for pkg in $REQUIRED_PACKAGES; do
  if dpkg -l | grep -q "^ii  $pkg"; then
    echo "✓ $pkg is installed"
  else
    echo "✗ $pkg is NOT installed"
    exit 1
  fi
done

# 2. 서비스 상태 확인
REQUIRED_SERVICES="docker nginx"
for svc in $REQUIRED_SERVICES; do
  if systemctl is-active --quiet "$svc"; then
    echo "✓ $svc is running"
  else
    echo "✗ $svc is NOT running"
    exit 1
  fi
done

# 3. 네트워크 연결 확인
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
  echo "✓ Network connectivity OK"
else
  echo "✗ Network connectivity FAILED"
  exit 1
fi

# 4. 포트 확인
if sudo netstat -tuln | grep -q ":80 "; then
  echo "✓ Port 80 is listening"
else
  echo "✗ Port 80 is NOT listening"
  exit 1
fi

# 5. 디스크 공간 확인
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
  echo "✓ Disk usage is $DISK_USAGE% (< 80%)"
else
  echo "✗ Disk usage is $DISK_USAGE% (>= 80%)"
  exit 1
fi

echo "=== All tests passed ==="
```

---

## 🛠️ 실습 가이드

### 실습 1: Packer로 로컬 QEMU 이미지 빌드

**목표:** Ubuntu 22.04 클라우드 이미지 기반 커스텀 이미지 빌드

**단계:**

```bash
# 1. 프로젝트 디렉토리 생성
mkdir -p packer-lab/{scripts,cloud-init,ansible}
cd packer-lab

# 2. Packer 설치 (Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install packer

# 3. QEMU 설치
sudo apt install -y qemu-kvm qemu-utils

# 4. cloud-init 파일 생성
cat > cloud-init/meta-data <<EOF
instance-id: packer-$(date +%s)
local-hostname: packer-ubuntu
EOF

cat > cloud-init/user-data <<'EOF'
#cloud-config
password: ubuntu
chpasswd: { expire: False }
ssh_pwauth: True
EOF

# 5. Packer 템플릿 생성 (위의 Part 2.2 HCL 코드 사용)
# ubuntu.pkr.hcl 파일 생성

# 6. Packer 초기화 및 검증
packer init ubuntu.pkr.hcl
packer validate ubuntu.pkr.hcl

# 7. 빌드 실행
packer build ubuntu.pkr.hcl

# 8. 결과 확인
ls -lh output-qemu/

# 9. 이미지 테스트 (QEMU로 부팅)
qemu-system-x86_64 \
  -hda output-qemu/packer-ubuntu \
  -m 2048 \
  -enable-kvm \
  -nographic
```

### 실습 2: AWS AMI 빌드 및 배포

```bash
# 1. AWS 자격증명 설정
export AWS_REGION=ap-northeast-2
export AWS_PROFILE=default

# 2. Packer 템플릿 (Part 2.2의 amazon-ebs source 사용)

# 3. 빌드
packer build -only="amazon-ebs.ubuntu" ubuntu.pkr.hcl

# 4. AMI ID 추출
AMI_ID=$(jq -r '.builds[0].artifact_id' manifest.json | cut -d':' -f2)

# 5. Terraform으로 인스턴스 시작
cat > main.tf <<EOF
provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_instance" "test" {
  ami           = "$AMI_ID"
  instance_type = "t3.micro"

  tags = {
    Name = "packer-test"
  }
}

output "public_ip" {
  value = aws_instance.test.public_ip
}
EOF

terraform init
terraform apply -auto-approve

# 6. SSH 접속 테스트
ssh ubuntu@$(terraform output -raw public_ip)

# 7. 정리
terraform destroy -auto-approve
```

### 실습 3: cloud-init 고급 활용

**동적 user-data 생성 (Jinja2 템플릿):**

```python
# generate-userdata.py
from jinja2 import Template
import yaml

template = Template('''
#cloud-config

hostname: {{ hostname }}

users:
  - name: {{ admin_user }}
    groups: sudo, docker
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
{% for key in ssh_keys %}
      - {{ key }}
{% endfor %}

packages:
{% for pkg in packages %}
  - {{ pkg }}
{% endfor %}

runcmd:
{% for cmd in runcmd %}
  - {{ cmd }}
{% endfor %}
''')

config = {
    'hostname': 'web-server-prod-01',
    'admin_user': 'devops',
    'ssh_keys': [
        'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user1@example.com',
        'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD... user2@example.com'
    ],
    'packages': ['docker.io', 'nginx', 'postgresql'],
    'runcmd': [
        'systemctl enable docker',
        'systemctl start docker',
        'docker run -d -p 80:80 nginx:latest'
    ]
}

userdata = template.render(**config)
print(userdata)
```

---

## 💻 예제 코드

### 예제 1: 멀티 클라우드 이미지 빌드

```hcl
# multi-cloud.pkr.hcl
variable "version" {
  type = string
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmm", timestamp())
}

# AWS
source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-2204-${local.timestamp}"
  instance_type = "t3.small"
  region        = "ap-northeast-2"

  source_ami_filter {
    filters = {
      name = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    }
    most_recent = true
    owners      = ["099720109477"]
  }

  ssh_username = "ubuntu"
}

# Azure
source "azure-arm" "ubuntu" {
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id

  managed_image_name                = "ubuntu-2204-${local.timestamp}"
  managed_image_resource_group_name = "packer-images"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  location = "koreacentral"
  vm_size  = "Standard_B2s"
}

# GCP
source "googlecompute" "ubuntu" {
  project_id   = var.gcp_project_id
  source_image = "ubuntu-2204-jammy-v20231213"
  ssh_username = "ubuntu"
  zone         = "asia-northeast3-a"

  image_name        = "ubuntu-2204-${local.timestamp}"
  image_description = "Ubuntu 22.04 Golden Image"
}

# OpenStack
source "openstack" "ubuntu" {
  identity_endpoint = var.openstack_auth_url
  username          = var.openstack_username
  password          = var.openstack_password
  region            = "RegionOne"

  image_name        = "ubuntu-2204-${local.timestamp}"
  source_image_name = "Ubuntu 22.04 LTS"
  flavor            = "m1.small"

  ssh_username = "ubuntu"
}

build {
  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu",
    "source.googlecompute.ubuntu",
    "source.openstack.ubuntu"
  ]

  # 공통 프로비저닝
  provisioner "shell" {
    scripts = [
      "./scripts/install-packages.sh",
      "./scripts/security-hardening.sh",
      "./scripts/cleanup.sh"
    ]
  }
}
```

### 예제 2: Ansible Provisioner 활용

**ansible/setup.yml:**
```yaml
---
- name: Setup Golden Image
  hosts: all
  become: yes
  vars:
    docker_version: "24.0"
    kubectl_version: "1.28.0"

  tasks:
    - name: Update APT cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install base packages
      apt:
        name:
          - curl
          - wget
          - vim
          - git
          - htop
          - jq
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
        state: present

    - name: Install Docker
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
        state: present

    - name: Add ubuntu user to docker group
      user:
        name: ubuntu
        groups: docker
        append: yes

    - name: Download kubectl
      get_url:
        url: "https://dl.k8s.io/release/v{{ kubectl_version }}/bin/linux/amd64/kubectl"
        dest: /usr/local/bin/kubectl
        mode: '0755'

    - name: Configure security - UFW
      ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
      loop:
        - "22"
        - "80"
        - "443"

    - name: Enable UFW
      ufw:
        state: enabled
        policy: deny

    - name: Configure fail2ban
      apt:
        name: fail2ban
        state: present

    - name: Start fail2ban
      systemd:
        name: fail2ban
        state: started
        enabled: yes
```

**Packer에서 사용:**
```hcl
provisioner "ansible" {
  playbook_file = "./ansible/setup.yml"
  user          = "ubuntu"

  extra_arguments = [
    "--extra-vars",
    "ansible_python_interpreter=/usr/bin/python3"
  ]
}
```

---

## 📚 참고 자료

### 공식 문서
1. **HashiCorp Packer**
   - [Packer 공식 문서](https://www.packer.io/)
   - [HCL2 Templates](https://developer.hashicorp.com/packer/guides/hcl)
   - [Builders](https://developer.hashicorp.com/packer/docs/builders)
   - [Provisioners](https://developer.hashicorp.com/packer/docs/provisioners)

2. **cloud-init**
   - [cloud-init 공식 문서](https://cloudinit.readthedocs.io/)
   - [Examples](https://cloudinit.readthedocs.io/en/latest/reference/examples.html)
   - [Modules Reference](https://cloudinit.readthedocs.io/en/latest/reference/modules.html)

3. **HCP Packer**
   - [HCP Packer 문서](https://developer.hashicorp.com/hcp/docs/packer)
   - [Golden Image Pipeline Tutorial](https://developer.hashicorp.com/packer/tutorials/cloud-production/golden-image-with-hcp-packer)

### 2025 Best Practices
1. [Packer Build Pipelines](https://developer.hashicorp.com/packer/guides/packer-on-cicd/pipelineing-builds)
2. [Building preconfigured OS images with HashiCorp Packer](https://community.hetzner.com/tutorials/custom-os-images-with-packer/)
3. [Customized Ubuntu Images using Packer + QEMU + Cloud-Init](https://shantanoo-desai.github.io/posts/technology/packer-ubuntu-qemu/)
4. [3 Essential Tips for Success in Virtual Machine Image Development](https://www.marktinderholt.com/cloud/2025/01/21/packer-3-tips.html)

### 튜토리얼 및 예제
1. [Creating custom OS images with Packer - Dask](https://cloudprovider.dask.org/en/latest/packer.html)
2. [Building a Golden Image Pipeline with Azure DevOps](https://www.hashicorp.com/en/resources/building-a-golden-image-pipeline-with-hashicorp-packer-and-azure-devops)
3. [GitHub: packer-ubuntu-cloud-image](https://github.com/nbarnum/packer-ubuntu-cloud-image)

### 커뮤니티 및 도구
1. **Awesome Packer**: https://github.com/dawitnida/awesome-packer
2. **Packer Examples**: https://github.com/hashicorp/packer-examples
3. **cloud-init Examples**: https://github.com/canonical/cloud-init

---

## ✅ 학습 체크리스트

### 기본 개념

- [ ] Linux 부팅 프로세스 (BIOS/UEFI → kernel → init) 이해
- [ ] ISO 이미지와 Cloud 이미지의 차이점 이해
- [ ] GPT/MBR 파티션 스킴 차이 이해
- [ ] cloud-init의 역할 및 4단계 실행 흐름 이해

### Packer

- [ ] HCL2 문법으로 Packer 템플릿 작성
- [ ] Source, Build, Provisioner, Post-Processor 구조 이해
- [ ] QEMU builder로 로컬 이미지 빌드
- [ ] AWS AMI 빌드 및 배포
- [ ] Ansible Provisioner 통합

### cloud-init

- [ ] user-data (cloud-config) 작성
- [ ] meta-data 및 network-config 설정
- [ ] 멀티파트 user-data 작성
- [ ] Packer와 cloud-init 통합
- [ ] cloud-init clean 명령 이해

### Golden Image Pipeline

- [ ] GitHub Actions로 이미지 빌드 자동화
- [ ] OIDC 기반 인증 설정
- [ ] HCP Packer 연동
- [ ] Terraform에서 HCP Packer 이미지 사용
- [ ] 보안 스캔 (Trivy) 통합

### 디버깅 및 최적화

- [ ] chroot 환경으로 이미지 수정
- [ ] QCOW2 이미지 압축 및 최적화
- [ ] 부팅 시간 분석 (systemd-analyze)
- [ ] 이미지 크기 최소화
- [ ] 자동화된 이미지 테스트 스크립트 작성

---

## 🎓 다음 단계

Infrastructure Platform 섹션을 완료했습니다! 다음은 Computing Service로 이동합니다.

1. **[../computing-service/Ch1.OpenStack.md](../computing-service/Ch1.OpenStack.md)**
   - OpenStack 아키텍처 (Nova, Cinder, Glance, Ironic)
   - 컴퓨팅 리소스 관리 및 스케줄링
   - 가상화 및 베어메탈 프로비저닝

2. **심화 주제**
   - **Immutable Infrastructure**: 컨테이너 이미지 + Packer 조합
   - **Image Bakery**: Netflix Aminator, Spinnaker Bakery
   - **OSTree/rpm-ostree**: Fedora CoreOS, Flatcar Container Linux

3. **실전 프로젝트**
   - 완전 자동화된 Golden Image Pipeline 구축
   - Multi-cloud 이미지 배포 자동화
   - CIS Benchmark 준수 이미지 빌드

---

**마지막 업데이트:** 2025-11-24
**다음 섹션:** [Computing Service](../computing-service/)
