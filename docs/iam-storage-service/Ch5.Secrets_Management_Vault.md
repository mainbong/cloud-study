# Ch5. Secrets Management - HashiCorp Vault

## 📋 개요 및 학습 목표

**HashiCorp Vault**는 시크릿 관리(Secrets Management) 분야의 업계 표준 도구로, 암호, API 키, 인증서 등 민감한 정보를 안전하게 저장하고 접근을 제어합니다.

### 왜 중요한가?

전통적인 시크릿 관리 방식의 문제점:

- ❌ **하드코딩**: 코드에 직접 암호 작성 (Git에 노출 위험)
- ❌ **환경변수**: 여전히 평문으로 저장되어 프로세스 메모리에서 유출 가능
- ❌ **정적 시크릿**: 한번 생성하면 영구 사용 (탈취 시 피해 확대)
- ❌ **중앙화된 관리 부재**: 각 팀이 자체 방식으로 관리 (일관성 부족)

**Vault의 해결책**:
- ✅ **중앙 집중식 시크릿 저장소**: 단일 진실의 원천 (Single Source of Truth)
- ✅ **동적 시크릿(Dynamic Secrets)**: 요청 시 생성, TTL 후 자동 삭제
- ✅ **암호화 서비스(EaaS)**: 애플리케이션이 직접 암호화 키를 관리하지 않음
- ✅ **세밀한 접근 제어**: Policy 기반 권한 관리
- ✅ **감사 로그**: 모든 접근 기록 추적

### KakaoCloud에서의 활용 사례

- **데이터베이스 자격 증명**: PostgreSQL/MySQL 동적 계정 생성 (15분 TTL)
- **Cloud Provider API 키**: AWS/GCP 임시 자격 증명 발급
- **TLS 인증서 관리**: PKI Engine으로 자동 발급 및 갱신
- **암호화 키 관리**: 사용자 데이터 암호화를 Vault에 위임
- **Kubernetes Secret 주입**: Vault Agent Sidecar로 자동 주입

### 학습 후 얻을 수 있는 역량

- [x] Vault 아키텍처 및 Secrets Engine 이해
- [x] 동적 시크릿 생성 및 자동 회전 구현
- [x] Go 애플리케이션에 Vault 통합
- [x] Kubernetes에 Vault Agent Sidecar 배포
- [x] Transit Engine으로 Encryption as a Service 구현

---

## 🔑 핵심 개념 및 이론

### 1. Vault 아키텍처

```mermaid
graph TB
    Client[Client<br/>App/User] -->|HTTP API| Vault[Vault Server]
    Vault --> Auth[Auth Methods]
    Vault --> Policy[Policy Engine]
    Vault --> Engine[Secrets Engines]
    Vault --> Audit[Audit Devices]
    Vault --> Storage[(Storage Backend)]

    Auth --> |1. Authenticate|Token[Token]
    Token --> |2. Check Policy|Policy
    Policy --> |3. Allow/Deny|Engine
    Engine --> |4. Return Secret|Client
    Audit --> |Log all operations|LogStore[(Audit Logs)]

    Storage --> |Encrypted|Consul[(Consul)]
    Storage --> Integrated[(Integrated<br/>Raft)]
    Storage --> Cloud[(Cloud Storage)]

    style Vault fill:#00d9ff
    style Engine fill:#ffd700
    style Storage fill:#90ee90
```

**핵심 구성 요소**:

1. **Vault Server**:
   - **Dev Mode**: 메모리 스토리지, 자동 unseal (개발 전용)
   - **Production Mode**: 영구 스토리지, 수동/자동 unseal

2. **Seal/Unseal**:
   - **Sealed**: Vault가 암호화 키에 접근 불가 (재시작 후 초기 상태)
   - **Unsealed**: 암호화 키가 메모리에 로드됨 (정상 작동)
   - **Unseal 방식**:
     - Shamir's Secret Sharing (5개 키 중 3개 필요)
     - Auto-Unseal (AWS KMS, Azure Key Vault, Google Cloud KMS)

3. **Auth Methods**: 사용자/애플리케이션 인증
   - Token, Kubernetes, AWS, LDAP, GitHub, AppRole 등

4. **Secrets Engines**: 시크릿 저장 및 생성
   - KV (Key-Value), Database, AWS, PKI, Transit 등

5. **Policy**: 접근 권한 정의
   ```hcl
   path "secret/data/myapp/*" {
     capabilities = ["read", "list"]
   }
   ```

6. **Audit Devices**: 모든 요청/응답 로깅
   - File, Syslog, Socket

---

### 2. Secrets Engines

#### 2.1 KV (Key-Value) Secrets Engine

**Version 1 vs Version 2**:

| 기능 | KV v1 | KV v2 |
|------|-------|-------|
| **버전 관리** | 없음 | 있음 (최대 10개 버전) |
| **Soft Delete** | 불가능 | 가능 (복구 가능) |
| **CAS (Check-And-Set)** | 없음 | 있음 (동시성 제어) |
| **메타데이터** | 없음 | 생성/수정 시간, 삭제 여부 |
| **경로** | `secret/mykey` | `secret/data/mykey` |

**KV v2 사용 예시**:
```bash
# 시크릿 작성
vault kv put secret/myapp password=secret123

# 시크릿 읽기
vault kv get secret/myapp

# 특정 버전 읽기
vault kv get -version=2 secret/myapp

# 삭제 (soft delete)
vault kv delete secret/myapp

# 복구
vault kv undelete -versions=1 secret/myapp

# 영구 삭제
vault kv destroy -versions=1 secret/myapp
```

#### 2.2 Database Secrets Engine

**동적 자격 증명 생성** - 요청 시 DB 계정 생성, TTL 후 자동 삭제

```mermaid
sequenceDiagram
    participant App
    participant Vault
    participant DB as PostgreSQL

    App->>Vault: GET /database/creds/myapp-role
    Vault->>DB: CREATE USER vault_user_12345<br/>GRANT SELECT ON myapp.*
    DB-->>Vault: User created
    Vault-->>App: {username: vault_user_12345, password: xxx, lease: 15m}

    Note over App,DB: 애플리케이션 사용 (15분)

    Vault->>DB: DROP USER vault_user_12345
    Note over Vault,DB: Lease 만료 시 자동 삭제
```

**장점**:
- ✅ **자동 회전**: 15분마다 새 계정 생성/삭제
- ✅ **침해 영향 최소화**: 탈취된 자격 증명은 15분 후 무효화
- ✅ **감사 추적**: 어떤 사용자가 어떤 DB 계정을 언제 사용했는지 추적

#### 2.3 Transit Secrets Engine

**Encryption as a Service** - Vault가 암호화/복호화 담당, 애플리케이션은 키 관리 불필요

```
plaintext → [Vault Transit] → ciphertext
ciphertext → [Vault Transit] → plaintext
```

**Key Rotation 베스트 프랙티스 (2025)**:
- **AES-GCM**: 2^32 (약 42억) 암호화 전에 회전 권장 (NIST 800-38D)
- **자동 버전 관리**: 새 키 버전 생성 시 이전 버전도 복호화 가능
- **min_decryption_version**: 오래된 키 버전 아카이빙 (성능 + 보안)

**Envelope Encryption 패턴**:
```
1. KEK (Key Encryption Key) - Vault에서 관리
2. DEK (Data Encryption Key) - 로컬에서 데이터 암호화
3. Encrypted DEK - Vault로 암호화하여 저장
```

이 방식의 장점:
- ✅ **대용량 데이터 효율**: 모든 데이터를 Vault로 보내지 않음
- ✅ **키 회전 간단**: KEK만 회전, 데이터 재암호화 불필요

#### 2.4 PKI Secrets Engine

**자동 인증서 발급 및 관리**

```bash
# Root CA 생성
vault secrets enable pki
vault write pki/root/generate/internal \
    common_name=example.com \
    ttl=87600h

# Intermediate CA 생성
vault secrets enable -path=pki_int pki
vault write -format=json pki_int/intermediate/generate/internal \
    common_name="example.com Intermediate CA" \
    | jq -r '.data.csr' > pki_intermediate.csr

# 인증서 발급
vault write pki_int/issue/example-dot-com \
    common_name=www.example.com \
    ttl=24h
```

---

### 3. Vault 1.0 이후 주요 기능 (2025 현재)

| 버전 | 주요 기능 |
|------|----------|
| **1.0 (2018)** | Auto-Unseal 오픈소스화 |
| **1.5** | Integrated Storage (Raft) |
| **1.7** | Key Management Secrets Engine |
| **1.9** | Vault Secrets Operator (K8s) |
| **1.11** | Event Streaming (Beta) |
| **1.12** | KMIP Secrets Engine |
| **1.13** | Automated License Utilization Reporting |
| **1.14** | OpenBao fork (2023) |
| **1.15** | Performance improvements |
| **1.17 (2024)** | Enhanced OIDC, Kubernetes improvements |

**2025 트렌드**:
- ✅ Kubernetes-native integration 강화
- ✅ Multi-cloud auto-unseal (AWS/Azure/GCP KMS)
- ✅ Secrets Operator로 K8s Secret 자동 동기화
- ✅ Envelope encryption 패턴 표준화

---

## 💻 실습 가이드 (Hands-on)

### Lab 1: Vault 설치 및 초기화

**목표**: Dev 서버로 Vault 기본 동작 이해

#### 1단계: Vault 설치

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# Linux
wget https://releases.hashicorp.com/vault/1.17.0/vault_1.17.0_linux_amd64.zip
unzip vault_1.17.0_linux_amd64.zip
sudo mv vault /usr/local/bin/

# 버전 확인
vault version
# Vault v1.17.0
```

#### 2단계: Dev 서버 실행

```bash
# Dev 모드 (인메모리, 자동 unseal, Root Token 출력)
vault server -dev

# 출력 예시:
# ==> Vault server configuration:
# Root Token: hvs.xxxxxxxxxxxxx
# Unseal Key: (not needed in dev mode)
#
# WARNING! dev mode is enabled!
# The dev server stores all data in memory and is insecure.
```

**새 터미널**에서:
```bash
# Vault 주소 설정
export VAULT_ADDR='http://127.0.0.1:8200'

# Root Token 설정 (위에서 출력된 값)
export VAULT_TOKEN='hvs.xxxxxxxxxxxxx'

# 상태 확인
vault status
# Seal Type: shamir
# Initialized: true
# Sealed: false
# Total Shares: 1
# Threshold: 1
# Version: 1.17.0
```

#### 3단계: KV Secrets Engine 사용

```bash
# 시크릿 작성
vault kv put secret/myapp username=admin password=secret123

# 시크릿 읽기
vault kv get secret/myapp
# ====== Data ======
# Key       Value
# ---       -----
# password  secret123
# username  admin

# JSON 형식으로 읽기
vault kv get -format=json secret/myapp | jq -r '.data.data.password'
# secret123

# 시크릿 목록 조회
vault kv list secret/
# Keys
# ----
# myapp

# 시크릿 삭제
vault kv delete secret/myapp
```

---

### Lab 2: Database Dynamic Secrets (PostgreSQL)

**목표**: PostgreSQL 동적 자격 증명 생성 및 자동 회전

#### 1단계: PostgreSQL 준비

```bash
# Docker로 PostgreSQL 실행
docker run --name postgres-vault \
  -e POSTGRES_PASSWORD=rootpass \
  -e POSTGRES_DB=myapp \
  -p 5432:5432 \
  -d postgres:15

# 초기 사용자 생성 (Vault가 사용할 관리자 계정)
docker exec -it postgres-vault psql -U postgres -d myapp -c \
  "CREATE USER vault_admin WITH PASSWORD 'vaultpass' SUPERUSER;"
```

#### 2단계: Database Secrets Engine 활성화

```bash
# Database engine 활성화
vault secrets enable database

# PostgreSQL 연결 설정
vault write database/config/myapp \
    plugin_name=postgresql-database-plugin \
    allowed_roles="myapp-role" \
    connection_url="postgresql://{{username}}:{{password}}@localhost:5432/myapp?sslmode=disable" \
    username="vault_admin" \
    password="vaultpass"
```

#### 3단계: Role 정의

```bash
# 동적 사용자 생성 규칙 정의
vault write database/roles/myapp-role \
    db_name=myapp \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="15m" \
    max_ttl="1h"
```

#### 4단계: 동적 자격 증명 생성

```bash
# 자격 증명 요청
vault read database/creds/myapp-role

# 출력:
# Key                Value
# ---                -----
# lease_id           database/creds/myapp-role/abc123
# lease_duration     15m
# lease_renewable    true
# password           A1a-xxxxxxxxx
# username           v-root-myapp-ro-xxxxxx
```

#### 5단계: 생성된 자격 증명 확인

```bash
# PostgreSQL에 접속해서 확인
docker exec -it postgres-vault psql -U postgres -d myapp -c "\du"

# 출력:
# List of roles
#  Role name               | Attributes
# v-root-myapp-ro-xxxxxx   | Password valid until 2025-01-02 14:45:00+00
```

**15분 후 자동 삭제 확인**:
```bash
# 15분 대기 후
docker exec -it postgres-vault psql -U postgres -d myapp -c "\du"
# → v-root-myapp-ro-xxxxxx 계정이 삭제됨
```

#### 6단계: Lease 연장

```bash
# Lease 정보 확인
vault read database/creds/myapp-role

# Lease 연장 (최대 max_ttl까지)
vault lease renew database/creds/myapp-role/abc123

# 즉시 revoke (삭제)
vault lease revoke database/creds/myapp-role/abc123
```

---

### Lab 3: Go 애플리케이션에 Vault 통합

**목표**: Go 앱에서 Vault API로 동적 DB 자격 증명 사용

#### 1단계: 의존성 설치

```bash
mkdir vault-go-demo && cd vault-go-demo
go mod init vault-go-demo

go get github.com/hashicorp/vault/api
go get github.com/lib/pq
```

#### 2단계: AppRole 인증 설정

```bash
# AppRole 활성화
vault auth enable approle

# Policy 생성
vault policy write myapp-policy - <<EOF
path "database/creds/myapp-role" {
  capabilities = ["read"]
}
EOF

# AppRole 생성
vault write auth/approle/role/myapp \
    secret_id_ttl=24h \
    token_ttl=15m \
    token_max_ttl=1h \
    policies="myapp-policy"

# Role ID 확인
vault read auth/approle/role/myapp/role-id
# role_id: xxxx-yyyy-zzzz

# Secret ID 생성
vault write -f auth/approle/role/myapp/secret-id
# secret_id: aaaa-bbbb-cccc
```

#### 3단계: Go 코드 구현

```go
// main.go
package main

import (
    "context"
    "database/sql"
    "fmt"
    "log"
    "os"
    "time"

    vault "github.com/hashicorp/vault/api"
    _ "github.com/lib/pq"
)

var (
    vaultClient *vault.Client
    roleID      = os.Getenv("VAULT_ROLE_ID")
    secretID    = os.Getenv("VAULT_SECRET_ID")
)

// Vault 클라이언트 초기화 및 AppRole 인증
func initVault() error {
    config := vault.DefaultConfig()
    config.Address = "http://127.0.0.1:8200"

    var err error
    vaultClient, err = vault.NewClient(config)
    if err != nil {
        return fmt.Errorf("failed to create vault client: %w", err)
    }

    // AppRole 로그인
    data := map[string]interface{}{
        "role_id":   roleID,
        "secret_id": secretID,
    }

    resp, err := vaultClient.Logical().Write("auth/approle/login", data)
    if err != nil {
        return fmt.Errorf("failed to login with AppRole: %w", err)
    }

    // Token 설정
    vaultClient.SetToken(resp.Auth.ClientToken)
    log.Printf("✓ Authenticated with Vault (Token TTL: %ds)", resp.Auth.LeaseDuration)

    return nil
}

// 동적 DB 자격 증명 가져오기
func getDatabaseCredentials() (username, password string, leaseID string, err error) {
    secret, err := vaultClient.Logical().Read("database/creds/myapp-role")
    if err != nil {
        return "", "", "", fmt.Errorf("failed to read database credentials: %w", err)
    }

    username = secret.Data["username"].(string)
    password = secret.Data["password"].(string)
    leaseID = secret.LeaseID

    log.Printf("✓ Got dynamic DB credentials: %s (Lease: %s, TTL: %ds)",
        username, leaseID, secret.LeaseDuration)

    return username, password, leaseID, nil
}

// Lease 갱신 백그라운드 고루틴
func renewLeaseBackground(leaseID string, stopCh chan struct{}) {
    ticker := time.NewTicker(5 * time.Minute) // 5분마다 갱신
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            secret, err := vaultClient.Sys().Renew(leaseID, 0)
            if err != nil {
                log.Printf("✗ Failed to renew lease: %v", err)
                return
            }
            log.Printf("✓ Renewed lease %s (TTL: %ds)", leaseID, secret.LeaseDuration)

        case <-stopCh:
            // Revoke lease on shutdown
            err := vaultClient.Sys().Revoke(leaseID)
            if err != nil {
                log.Printf("✗ Failed to revoke lease: %v", err)
            } else {
                log.Printf("✓ Revoked lease %s", leaseID)
            }
            return
        }
    }
}

// DB 연결 및 쿼리
func queryDatabase(username, password string) error {
    connStr := fmt.Sprintf("host=localhost port=5432 user=%s password=%s dbname=myapp sslmode=disable",
        username, password)

    db, err := sql.Open("postgres", connStr)
    if err != nil {
        return fmt.Errorf("failed to connect to database: %w", err)
    }
    defer db.Close()

    // 연결 테스트
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := db.PingContext(ctx); err != nil {
        return fmt.Errorf("failed to ping database: %w", err)
    }

    // 샘플 쿼리
    var currentUser string
    err = db.QueryRowContext(ctx, "SELECT current_user").Scan(&currentUser)
    if err != nil {
        return fmt.Errorf("failed to query current_user: %w", err)
    }

    log.Printf("✓ Connected to database as: %s", currentUser)
    return nil
}

func main() {
    // 1. Vault 초기화
    if err := initVault(); err != nil {
        log.Fatalf("Vault initialization failed: %v", err)
    }

    // 2. 동적 DB 자격 증명 가져오기
    username, password, leaseID, err := getDatabaseCredentials()
    if err != nil {
        log.Fatalf("Failed to get DB credentials: %v", err)
    }

    // 3. Lease 갱신 고루틴 시작
    stopCh := make(chan struct{})
    go renewLeaseBackground(leaseID, stopCh)

    // 4. DB 연결 및 쿼리
    if err := queryDatabase(username, password); err != nil {
        log.Fatalf("Database query failed: %v", err)
    }

    // 5. 애플리케이션 실행 (여기서는 30초 대기)
    log.Println("Application running... (Press Ctrl+C to exit)")
    time.Sleep(30 * time.Second)

    // 6. 종료 시 Lease revoke
    close(stopCh)
    time.Sleep(1 * time.Second) // revoke 완료 대기

    log.Println("✓ Application shutdown complete")
}
```

#### 4단계: 실행

```bash
# 환경변수 설정
export VAULT_ROLE_ID="xxxx-yyyy-zzzz"
export VAULT_SECRET_ID="aaaa-bbbb-cccc"

# 실행
go run main.go

# 출력:
# ✓ Authenticated with Vault (Token TTL: 900s)
# ✓ Got dynamic DB credentials: v-approle-myapp-ro-abc123 (Lease: database/creds/myapp-role/xyz, TTL: 900s)
# ✓ Connected to database as: v-approle-myapp-ro-abc123
# Application running... (Press Ctrl+C to exit)
# ✓ Renewed lease database/creds/myapp-role/xyz (TTL: 900s)
# ^C
# ✓ Revoked lease database/creds/myapp-role/xyz
# ✓ Application shutdown complete
```

---

### Lab 4: Kubernetes Vault Agent Sidecar

**목표**: Vault Agent를 Sidecar로 주입하여 K8s Pod에 시크릿 자동 주입

#### 1단계: Vault Helm Chart 설치

```bash
# Helm repo 추가
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Vault 설치 (Injector 포함)
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true"

# 확인
kubectl get pods
# NAME                                    READY   STATUS
# vault-0                                 1/1     Running
# vault-agent-injector-xxx                1/1     Running
```

#### 2단계: Kubernetes Auth 설정

```bash
# Vault Pod에 접속
kubectl exec -it vault-0 -- /bin/sh

# Kubernetes auth 활성화
vault auth enable kubernetes

# Kubernetes 설정
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

# Policy 생성
vault policy write myapp - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF

# Role 생성 (ServiceAccount와 연동)
vault write auth/kubernetes/role/myapp \
    bound_service_account_names=myapp \
    bound_service_account_namespaces=default \
    policies=myapp \
    ttl=24h

# 시크릿 작성
vault kv put secret/myapp/config \
    username=appuser \
    password=secret123 \
    database_url=postgres://localhost:5432/myapp

exit
```

#### 3단계: ServiceAccount 생성

```yaml
# myapp-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp
```

```bash
kubectl apply -f myapp-sa.yaml
```

#### 4단계: Vault Agent 주입 Annotation 설정

```yaml
# myapp-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        # Vault Injector Annotations
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/data/myapp/config" -}}
          export DATABASE_URL="{{ .Data.data.database_url }}"
          export DB_USERNAME="{{ .Data.data.username }}"
          export DB_PASSWORD="{{ .Data.data.password }}"
          {{- end }}
    spec:
      serviceAccountName: myapp
      containers:
        - name: app
          image: alpine:3.18
          command: ["/bin/sh"]
          args:
            - "-c"
            - |
              # Vault Agent가 작성한 파일 source
              source /vault/secrets/config
              echo "Connected to: $DATABASE_URL as $DB_USERNAME"
              sleep infinity
```

```bash
kubectl apply -f myapp-deployment.yaml
```

#### 5단계: 확인

```bash
# Pod 확인 (3개 컨테이너: app, vault-agent-init, vault-agent)
kubectl get pods
# NAME                    READY   STATUS
# myapp-xxx               2/2     Running

# Pod 상세 정보
kubectl describe pod myapp-xxx
# Init Containers:
#   vault-agent-init  → Vault에서 시크릿 가져와서 파일 작성
# Containers:
#   app               → 애플리케이션
#   vault-agent       → 지속적으로 시크릿 갱신

# 로그 확인
kubectl logs myapp-xxx -c app
# Connected to: postgres://localhost:5432/myapp as appuser

# 파일 내용 확인
kubectl exec myapp-xxx -- cat /vault/secrets/config
# export DATABASE_URL="postgres://localhost:5432/myapp"
# export DB_USERNAME="appuser"
# export DB_PASSWORD="secret123"
```

---

### Lab 5: Transit Engine - Encryption as a Service

**목표**: Vault Transit Engine으로 데이터 암호화/복호화

#### 1단계: Transit Engine 활성화

```bash
# Transit engine 활성화
vault secrets enable transit

# 암호화 키 생성
vault write -f transit/keys/myapp-key

# 키 정보 확인
vault read transit/keys/myapp-key
# Key                       Value
# ---                       -----
# type                      aes256-gcm96
# supports_encryption       true
# supports_decryption       true
# supports_derivation       true
```

#### 2단계: 데이터 암호화

```bash
# 평문을 Base64로 인코딩
plaintext=$(echo -n "my secret data" | base64)
echo $plaintext
# bXkgc2VjcmV0IGRhdGE=

# 암호화
vault write transit/encrypt/myapp-key plaintext=$plaintext

# 출력:
# Key           Value
# ---           -----
# ciphertext    vault:v1:8SDd3WHDOjf7mq69CyCqYjBXAiQQAVZRkFM62oBzLHiNsRRnbO8=
```

#### 3단계: 데이터 복호화

```bash
# 암호문 저장
ciphertext="vault:v1:8SDd3WHDOjf7mq69CyCqYjBXAiQQAVZRkFM62oBzLHiNsRRnbO8="

# 복호화
vault write transit/decrypt/myapp-key ciphertext=$ciphertext

# 출력:
# Key          Value
# ---          -----
# plaintext    bXkgc2VjcmV0IGRhdGE=

# Base64 디코딩
echo "bXkgc2VjcmV0IGRhdGE=" | base64 -d
# my secret data
```

#### 4단계: Key Rotation

```bash
# 키 회전
vault write -f transit/keys/myapp-key/rotate

# 키 정보 확인 (버전 2 생성됨)
vault read transit/keys/myapp-key
# latest_version    2

# 새 키로 암호화
vault write transit/encrypt/myapp-key plaintext=$plaintext
# ciphertext    vault:v2:xxxxx  (v2!)

# 이전 버전으로 암호화된 데이터도 복호화 가능
vault write transit/decrypt/myapp-key ciphertext="vault:v1:8SDd3WHDOjf7mq69CyCqYjBXAiQQAVZRkFM62oBzLHiNsRRnbO8="
# ✓ 성공! (버전 호환성 보장)
```

#### 5단계: 재암호화 (Rewrap)

```bash
# 이전 키 버전으로 암호화된 데이터를 최신 키로 재암호화
vault write transit/rewrap/myapp-key ciphertext="vault:v1:8SDd3WHDOjf7mq69CyCqYjBXAiQQAVZRkFM62oBzLHiNsRRnbO8="

# 출력:
# ciphertext    vault:v2:yyyyy  (v1 → v2로 변경!)
```

#### 6단계: Go 코드로 Transit Engine 사용

```go
// transit.go
package main

import (
    "encoding/base64"
    "fmt"
    "log"

    vault "github.com/hashicorp/vault/api"
)

func main() {
    // Vault 클라이언트
    client, err := vault.NewClient(vault.DefaultConfig())
    if err != nil {
        log.Fatal(err)
    }
    client.SetToken("hvs.xxxxx") // Root token

    // 평문
    plaintext := "Sensitive user data: SSN=123-45-6789"

    // 1. 암호화
    encoded := base64.StdEncoding.EncodeToString([]byte(plaintext))
    encryptResp, err := client.Logical().Write("transit/encrypt/myapp-key", map[string]interface{}{
        "plaintext": encoded,
    })
    if err != nil {
        log.Fatal(err)
    }
    ciphertext := encryptResp.Data["ciphertext"].(string)
    fmt.Printf("Encrypted: %s\n", ciphertext)

    // 2. 복호화
    decryptResp, err := client.Logical().Write("transit/decrypt/myapp-key", map[string]interface{}{
        "ciphertext": ciphertext,
    })
    if err != nil {
        log.Fatal(err)
    }

    decodedBytes, _ := base64.StdEncoding.DecodeString(decryptResp.Data["plaintext"].(string))
    fmt.Printf("Decrypted: %s\n", string(decodedBytes))
}
```

**실행 결과**:
```
Encrypted: vault:v2:8SDd3WHDOjf7mq69CyCqYjBXAiQQAVZRkFM62oBzLHiNsRRnbO8=
Decrypted: Sensitive user data: SSN=123-45-6789
```

---

## 📚 참고 자료

### 공식 문서

**Vault 기본**:
- [HashiCorp Vault Official Website](https://www.hashicorp.com/en/products/vault)
- [Vault Project](https://www.vaultproject.io/)
- [Vault GitHub Repository](https://github.com/hashicorp/vault)
- [HashiCorp Developer - Vault](https://developer.hashicorp.com/vault)

**Dynamic Secrets**:
- [Dynamic Secrets Use Cases](https://www.vaultproject.io/use-cases/dynamic-secrets)
- [Database Secrets Tutorial](https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets)
- [Understand Static and Dynamic Secrets](https://developer.hashicorp.com/vault/tutorials/get-started/understand-static-dynamic-secrets)
- [Secrets Management Tutorials](https://developer.hashicorp.com/vault/tutorials/secrets-management)

**Kubernetes Integration**:
- [Vault Agent Kubernetes Tutorial](https://developer.hashicorp.com/vault/tutorials/kubernetes-introduction/agent-kubernetes)
- [Kubernetes Sidecar Injection](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar)
- [Vault Secrets Operator](https://developer.hashicorp.com/vault/tutorials/kubernetes-introduction/vault-secrets-operator)
- [Mastering Vault Integration with Kubernetes](https://blog.avidhara.cloud/posts/vault-integration-with-kubernetes/)
- [LambdaStack Kubernetes/Vault Integration](https://www.lambdastackio.com/docs/reference/design-docs/k8s-vault-integration/)
- [Integrating HashiCorp Vault with Kubernetes - Toxigon](https://toxigon.com/integrating-hashicorp-vault-with-kubernetes)

**Auto-Unseal**:
- [Auto Unseal Tutorial](https://developer.hashicorp.com/vault/tutorials/auto-unseal)
- [Auto Unseal Learning Resources](https://www.hashicorp.com/en/blog/vault-learning-resources-auto-unseal-agent-kubernetes)
- [KubeVault Auto Initialization](https://kubevault.com/features/auto-initialization-and-unsealing/)

**Transit Engine & Encryption**:
- [Transit Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/transit)
- [Encrypt Data in Transit Tutorial](https://developer.hashicorp.com/vault/tutorials/encryption-as-a-service/eaas-transit)
- [Encryption-as-a-Service with Transit](https://www.hashicorp.com/en/resources/encryption-as-a-service-with-vault-s-transit-secret-engine)
- [Transit Best Practices](https://developer.hashicorp.com/vault/docs/configuration/seal/transit-best-practices)
- [Scaling Data Encryption with Transit Engine - Medium](https://medium.com/hashicorp-engineering/scaling-data-encryption-with-hashicorp-vaults-transit-engine-2d0cb3d31c2f)
- [Rotating Vault Encryption Keys - Medium 2025](https://medium.com/@panayot.atanasov/rotating-encryption-keys-for-bank-data-with-hashicorp-vault-without-re-encrypting-a-single-record-f12c1ed923db)
- [Vault Transit Engine and BYOK](https://mantraideas.com/hashicorp-vault-transit-engine/)

**2025 Guides**:
- [Complete Guide to Secrets Management in 2025](https://opstree.com/blog/2025/08/05/what-is-hashicorp-vault-a-complete-guide-to-secrets-management-in-2025/)
- [Vault Secret Engines 2025](https://www.infralovers.com/blog/2025-05-21-vault-secret-engines/)
- [HCP Vault Secrets](https://developer.hashicorp.com/hcp/docs/vault-secrets)

### 학습 체크리스트

- [ ] Vault 아키텍처 및 Seal/Unseal 메커니즘 이해
- [ ] KV v1 vs v2 차이점 및 버전 관리
- [ ] Database Secrets Engine으로 동적 자격 증명 생성
- [ ] Go 애플리케이션에 Vault API 통합 (AppRole 인증)
- [ ] Lease 관리 및 자동 갱신 구현
- [ ] Kubernetes Vault Agent Sidecar 배포
- [ ] Transit Engine으로 Encryption as a Service 구현
- [ ] Key Rotation 및 Rewrap 전략 수립
- [ ] Envelope Encryption (KEK/DEK) 패턴 적용
- [ ] Auto-Unseal 설정 (AWS KMS/Azure Key Vault)
- [ ] Audit Logs 수집 및 모니터링
- [ ] Production 환경 HA 구성 (Integrated Raft)

---

## 🎯 다음 단계

Ch6에서는 **Service Mesh Security**를 학습합니다. mTLS, SPIFFE/SPIRE, Zero Trust 네트워크 아키텍처를 다루며, Istio/Envoy에서의 보안 구현을 실습합니다.

**Preview**:
- mTLS (mutual TLS) 자동 인증서 관리
- SPIFFE/SPIRE 신원 프레임워크
- Envoy Proxy를 통한 서비스 간 인증
- Zero Trust 네트워크 아키텍처
- Istio Authorization Policies
