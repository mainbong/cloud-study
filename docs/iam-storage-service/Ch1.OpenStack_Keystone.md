# Ch1. OpenStack Keystone

> OpenStack Identity Service - 멀티 테넌트 IAM 시스템 (2025)

## 목차

- [Keystone 개요](#keystone-개요)
- [Keystone 아키텍처](#keystone-아키텍처)
- [토큰 관리](#토큰-관리)
- [Identity 백엔드](#identity-백엔드)
- [Federation](#federation)
- [정책 관리](#정책-관리)
- [실습 가이드](#실습-가이드)

---

## Keystone 개요

OpenStack Keystone은 OpenStack 클라우드의 **Identity Service**로, 인증(Authentication)과 인가(Authorization)를 담당합니다.

### 주요 기능

- **인증 (Authentication)**: 사용자, 서비스 인증
- **서비스 카탈로그 (Service Catalog)**: API 엔드포인트 관리
- **인가 (Authorization)**: 역할 기반 접근 제어 (RBAC)
- **멀티 테넌시 (Multi-Tenancy)**: 도메인, 프로젝트, 사용자 계층 구조
- **토큰 관리 (Token Management)**: Fernet, JWT 토큰 발급 및 검증
- **Federation**: 외부 IdP (SAML, OIDC) 연동

---

## Keystone 아키텍처

### 핵심 컴포넌트

```
┌─────────────────────────────────────────────────────────┐
│                    Keystone API                         │
│                    (WSGI/uWSGI)                         │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴──────────┬──────────────────┐
         │                      │                  │
    ┌────▼─────┐        ┌──────▼──────┐    ┌─────▼──────┐
    │ Identity │        │  Resource   │    │  Token     │
    │ Service  │        │  Service    │    │  Service   │
    └────┬─────┘        └──────┬──────┘    └─────┬──────┘
         │                     │                  │
    ┌────▼─────┐        ┌──────▼──────┐    ┌─────▼──────┐
    │ SQL/LDAP │        │     SQL     │    │  Fernet    │
    │ Backend  │        │   Backend   │    │  /JWS      │
    └──────────┘        └─────────────┘    └────────────┘
```

### 서비스 구성

| 서비스 | 역할 | 주요 기능 |
|--------|------|----------|
| **Identity** | 사용자/그룹 관리 | 인증, 사용자 CRUD |
| **Resource** | 프로젝트/도메인 관리 | 리소스 계층 구조 |
| **Assignment** | 역할 할당 | 사용자-프로젝트-역할 매핑 |
| **Token** | 토큰 발급/검증 | Fernet/JWS 토큰 관리 |
| **Catalog** | 서비스 카탈로그 | API 엔드포인트 등록 |
| **Policy** | 정책 엔진 | RBAC 정책 평가 |
| **Federation** | 외부 IdP 연동 | SAML/OIDC 통합 |

### 도메인-프로젝트-사용자 계층

```
Domain (조직)
  ├── Project (프로젝트/테넌트)
  │   ├── User (사용자)
  │   │   └── Role (역할)
  │   └── Group (그룹)
  │       └── Role (역할)
  └── Project (프로젝트/테넌트)
      └── ...
```

---

## 토큰 관리

Keystone은 다양한 토큰 포맷을 지원합니다.

### Fernet 토큰 (기본, 권장)

**특징:**
- **경량**: 180-240 바이트
- **비영구적**: DB 저장 불필요
- **대칭 암호화**: AES256 암호화, SHA256 HMAC 서명
- **키 로테이션**: 자동 키 순환 지원

**구조:**

```
Fernet Token = Base64(Version | Timestamp | IV | Ciphertext | HMAC)
```

**장점:**
- 낮은 DB 부하
- 빠른 검증 속도
- 간단한 운영

**단점:**
- 키 공유 필요 (멀티 노드)
- 토큰 크기가 UUID보다 큼

### JWS (JWT) 토큰

**특징:**
- **비대칭 암호화**: RS256/ES256 (권장: ES256)
- **비영구적**: DB 저장 불필요
- **디코딩 가능**: 토큰 페이로드 확인 가능
- **키 공유 불필요**: Public key만 배포

**구조:**

```json
{
  "header": {
    "alg": "ES256",
    "typ": "JWT"
  },
  "payload": {
    "exp": 1703980800,
    "iat": 1703977200,
    "methods": ["password"],
    "user": {...},
    "project": {...}
  },
  "signature": "..."
}
```

**장점:**
- 키 공유 불필요
- 표준 JWT 포맷

**단점:**
- 토큰 크기가 큼 (400-600 바이트)
- 페이로드 노출 (암호화 아님)

### 토큰 비교 (2024-2025)

| 특징 | Fernet | JWS |
|------|--------|-----|
| **크기** | 180-240B | 400-600B |
| **암호화** | 대칭 (AES256) | 비대칭 (ES256) |
| **DB** | 불필요 | 불필요 |
| **키 공유** | 필요 | Public Key만 |
| **성능** | 빠름 | 중간 |
| **보안** | 높음 (암호화) | 중간 (서명만) |
| **사용 사례** | 대부분 | 마이크로서비스 |

### Go로 Keystone 토큰 검증

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/gophercloud/gophercloud"
    "github.com/gophercloud/gophercloud/openstack"
    "github.com/gophercloud/gophercloud/openstack/identity/v3/tokens"
)

func validateToken(authURL, token string) error {
    // Keystone 클라이언트 생성
    provider, err := openstack.NewClient(authURL)
    if err != nil {
        return fmt.Errorf("failed to create client: %w", err)
    }

    // 관리자 토큰으로 인증
    provider.TokenID = token

    // 토큰 검증
    client, err := openstack.NewIdentityV3(provider, gophercloud.EndpointOpts{})
    if err != nil {
        return fmt.Errorf("failed to create identity client: %w", err)
    }

    result := tokens.Get(context.Background(), client, token)
    user, err := result.ExtractUser()
    if err != nil {
        return fmt.Errorf("invalid token: %w", err)
    }

    fmt.Printf("Token valid for user: %s (ID: %s)\n", user.Name, user.ID)
    return nil
}

func main() {
    authURL := "https://keystone.example.com:5000/v3"
    token := "gAAAAABl..."

    if err := validateToken(authURL, token); err != nil {
        log.Fatal(err)
    }
}
```

---

## Identity 백엔드

Keystone은 다양한 Identity 백엔드를 지원합니다.

### SQL 백엔드 (기본)

**설정 (/etc/keystone/keystone.conf):**

```ini
[identity]
driver = sql

[database]
connection = mysql+pymysql://keystone:password@localhost/keystone
```

**특징:**
- 완전한 CRUD 지원
- 비밀번호 직접 관리
- 기본 권장 방식

### LDAP 백엔드

**설정:**

```ini
[identity]
driver = ldap

[ldap]
url = ldap://ldap.example.com
user = cn=admin,dc=example,dc=com
password = secret
suffix = dc=example,dc=com
user_tree_dn = ou=Users,dc=example,dc=com
user_objectclass = inetOrgPerson
user_id_attribute = uid
user_name_attribute = cn
```

**특징:**
- 기존 LDAP/AD 통합
- Read-only 권장
- Keystone은 인증만, LDAP가 사용자 관리

### 하이브리드 백엔드

SQL + LDAP 조합:

```ini
[identity]
driver = sql

[assignment]
driver = sql

[ldap]
# LDAP은 인증용으로만 사용
url = ldap://ldap.example.com
```

---

## Federation

외부 Identity Provider(IdP)와 연동하여 Single Sign-On(SSO)을 구현합니다.

### 지원 프로토콜

| 프로토콜 | Apache 모듈 | 사용 사례 |
|---------|------------|----------|
| **SAML 2.0** | mod_shib, mod_auth_mellon | 엔터프라이즈 SSO |
| **OpenID Connect** | mod_auth_openidc | Google, Azure AD |

### OIDC Federation 아키텍처

```
┌──────────┐         ┌─────────────┐         ┌──────────┐
│  User    │─(1)────>│   Apache    │─(2)────>│  Keycloak│
│ Browser  │<─(6)────│ mod_auth_   │<─(3)────│  (IdP)   │
└──────────┘         │  openidc    │         └──────────┘
                     └──────┬──────┘
                           (4)
                     ┌──────▼──────┐
                     │  Keystone   │
                     │  (Federated)│
                     └─────────────┘
```

**플로우:**
1. 사용자가 Keystone에 접근
2. Apache가 IdP로 리디렉션
3. IdP가 사용자 인증 후 토큰 반환
4. Apache가 Keystone에 federated 토큰 요청
5. Keystone이 unscoped 토큰 발급
6. 사용자가 프로젝트 scope로 토큰 교환

### OIDC 설정 예시

**/etc/httpd/conf.d/keystone-oidc.conf:**

```apache
LoadModule auth_openidc_module modules/mod_auth_openidc.so

<Location /v3/OS-FEDERATION/identity_providers/keycloak/protocols/openid/auth>
  Require valid-user
  AuthType openid-connect

  OIDCProviderMetadataURL https://keycloak.example.com/auth/realms/master/.well-known/openid-configuration
  OIDCClientID keystone
  OIDCClientSecret secret
  OIDCRedirectURI https://keystone.example.com/v3/OS-FEDERATION/identity_providers/keycloak/protocols/openid/auth

  OIDCCryptoPassphrase random-secret
  OIDCResponseType code
  OIDCScope "openid email profile"
</Location>
```

### Go로 Federated 인증

```go
package main

import (
    "context"
    "fmt"

    "github.com/gophercloud/gophercloud"
    "github.com/gophercloud/gophercloud/openstack"
    "github.com/gophercloud/gophercloud/openstack/identity/v3/tokens"
)

func federatedAuth(authURL, idpID, protocol, accessToken string) (*tokens.Token, error) {
    // Federated 인증 옵션
    opts := gophercloud.AuthOptions{
        IdentityEndpoint: authURL,
        TokenID:          accessToken,
    }

    provider, err := openstack.NewClient(authURL)
    if err != nil {
        return nil, err
    }

    // Federated 토큰 발급 (unscoped)
    unscopedToken, err := tokens.Create(context.Background(), provider, &opts).Extract()
    if err != nil {
        return nil, fmt.Errorf("failed to get unscoped token: %w", err)
    }

    // 프로젝트 scope 토큰으로 교환
    scopedOpts := gophercloud.AuthOptions{
        IdentityEndpoint: authURL,
        TokenID:          unscopedToken.ID,
        Scope: &gophercloud.AuthScope{
            ProjectName: "demo",
            DomainName:  "Default",
        },
    }

    scopedToken, err := tokens.Create(context.Background(), provider, &scopedOpts).Extract()
    if err != nil {
        return nil, fmt.Errorf("failed to scope token: %w", err)
    }

    return scopedToken, nil
}
```

---

## 정책 관리

Keystone은 `policy.json` (또는 `policy.yaml`)을 통해 RBAC 정책을 정의합니다.

### 기본 역할

| 역할 | 권한 | 설명 |
|------|------|------|
| **admin** | 전체 | 모든 리소스 관리 |
| **member** | 읽기/쓰기 | 프로젝트 리소스 관리 |
| **reader** | 읽기 | 읽기 전용 |

### Policy 파일 예시

**/etc/keystone/policy.yaml:**

```yaml
# 관리자만 사용자 생성 가능
"identity:create_user": "role:admin"

# 프로젝트 멤버는 자신의 정보 읽기 가능
"identity:get_user": "rule:admin_or_owner"

# admin_or_owner 규칙 정의
"admin_or_owner": "role:admin or user_id:%(user_id)s"

# 프로젝트 생성은 도메인 admin만
"identity:create_project": "role:admin and domain_id:%(target.project.domain_id)s"
```

### 커스텀 정책 엔진 (Go)

```go
package main

import (
    "encoding/json"
    "fmt"
)

type PolicyRule struct {
    Resource string `json:"resource"`
    Action   string `json:"action"`
    Rule     string `json:"rule"`
}

type PolicyEngine struct {
    rules map[string]string
}

func NewPolicyEngine(policyJSON []byte) (*PolicyEngine, error) {
    var rules map[string]string
    if err := json.Unmarshal(policyJSON, &rules); err != nil {
        return nil, err
    }

    return &PolicyEngine{rules: rules}, nil
}

func (p *PolicyEngine) Enforce(action string, context map[string]interface{}) (bool, error) {
    rule, exists := p.rules[action]
    if !exists {
        return false, fmt.Errorf("no rule for action: %s", action)
    }

    // 간단한 규칙 평가 (실제로는 더 복잡한 파서 필요)
    switch rule {
    case "role:admin":
        role, ok := context["role"].(string)
        return ok && role == "admin", nil
    case "rule:admin_or_owner":
        role, _ := context["role"].(string)
        userID, _ := context["user_id"].(string)
        targetUserID, _ := context["target_user_id"].(string)
        return role == "admin" || userID == targetUserID, nil
    default:
        return false, nil
    }
}

func main() {
    policyJSON := []byte(`{
        "identity:create_user": "role:admin",
        "identity:get_user": "rule:admin_or_owner"
    }`)

    engine, _ := NewPolicyEngine(policyJSON)

    // 테스트
    context := map[string]interface{}{
        "role":           "member",
        "user_id":        "user-123",
        "target_user_id": "user-123",
    }

    allowed, _ := engine.Enforce("identity:get_user", context)
    fmt.Printf("Allowed: %v\n", allowed) // true (owner)
}
```

---

## 실습 가이드

### 실습 1: Keystone 설치 및 설정 (DevStack)

```bash
# 1. DevStack 클론
git clone https://opendev.org/openstack/devstack
cd devstack

# 2. local.conf 생성
cat > local.conf <<EOF
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=secret
RABBIT_PASSWORD=secret
SERVICE_PASSWORD=secret

# Keystone만 설치
disable_all_services
enable_service key mysql
EOF

# 3. 설치
./stack.sh

# 4. 환경 변수 설정
source openrc admin admin

# 5. Keystone 동작 확인
openstack token issue
openstack user list
openstack project list
```

### 실습 2: 멀티 테넌트 구성

```bash
# 1. 도메인 생성
openstack domain create company-a
openstack domain create company-b

# 2. 프로젝트 생성
openstack project create --domain company-a project-dev
openstack project create --domain company-a project-prod
openstack project create --domain company-b project-main

# 3. 사용자 생성
openstack user create --domain company-a --password secret alice
openstack user create --domain company-a --password secret bob
openstack user create --domain company-b --password secret charlie

# 4. 역할 할당
openstack role add --project project-dev --user alice member
openstack role add --project project-prod --user bob admin
openstack role add --project project-main --user charlie member

# 5. 확인
openstack role assignment list --user alice --names
```

### 실습 3: Fernet 토큰 설정

```bash
# 1. Fernet 키 생성
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

# 2. 키 확인
ls -la /etc/keystone/fernet-keys/

# 3. 키 로테이션
keystone-manage fernet_rotate --keystone-user keystone --keystone-group keystone

# 4. 토큰 발급 테스트
openstack token issue

# 5. 토큰 크기 확인 (Fernet은 ~200 bytes)
openstack token issue -f value -c id | wc -c
```

### 실습 4: LDAP 백엔드 통합

```bash
# 1. LDAP 서버 준비 (테스트용)
docker run -d -p 389:389 -p 636:636 \
  --name openldap \
  -e LDAP_ORGANISATION="Example Inc" \
  -e LDAP_DOMAIN="example.com" \
  -e LDAP_ADMIN_PASSWORD="admin" \
  osixia/openldap:latest

# 2. Keystone 설정 수정
cat >> /etc/keystone/keystone.conf <<EOF
[identity]
driver = ldap

[ldap]
url = ldap://localhost:389
user = cn=admin,dc=example,dc=com
password = admin
suffix = dc=example,dc=com
user_tree_dn = ou=users,dc=example,dc=com
user_objectclass = inetOrgPerson
EOF

# 3. Keystone 재시작
systemctl restart devstack@keystone

# 4. LDAP 사용자 확인
openstack user list
```

### 실습 5: Go 클라이언트 개발

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/gophercloud/gophercloud"
    "github.com/gophercloud/gophercloud/openstack"
    "github.com/gophercloud/gophercloud/openstack/identity/v3/projects"
    "github.com/gophercloud/gophercloud/openstack/identity/v3/users"
)

func main() {
    // 1. 인증 옵션
    opts := gophercloud.AuthOptions{
        IdentityEndpoint: "http://localhost:5000/v3",
        Username:         "admin",
        Password:         "secret",
        DomainName:       "Default",
        Scope: &gophercloud.AuthScope{
            ProjectName: "admin",
            DomainName:  "Default",
        },
    }

    // 2. 인증
    provider, err := openstack.AuthenticatedClient(context.Background(), opts)
    if err != nil {
        log.Fatal(err)
    }

    // 3. Identity 클라이언트 생성
    client, err := openstack.NewIdentityV3(provider, gophercloud.EndpointOpts{})
    if err != nil {
        log.Fatal(err)
    }

    // 4. 사용자 목록
    listOpts := users.ListOpts{}
    allPages, err := users.List(client, listOpts).AllPages(context.Background())
    if err != nil {
        log.Fatal(err)
    }

    allUsers, err := users.ExtractUsers(allPages)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println("Users:")
    for _, user := range allUsers {
        fmt.Printf("- %s (ID: %s)\n", user.Name, user.ID)
    }

    // 5. 프로젝트 목록
    projectPages, err := projects.List(client, projects.ListOpts{}).AllPages(context.Background())
    if err != nil {
        log.Fatal(err)
    }

    allProjects, err := projects.ExtractProjects(projectPages)
    if err != nil {
        log.Fatal(err)
    }

    fmt.Println("\nProjects:")
    for _, project := range allProjects {
        fmt.Printf("- %s (ID: %s, Domain: %s)\n",
            project.Name, project.ID, project.DomainID)
    }
}
```

**실행:**

```bash
go mod init keystone-demo
go get github.com/gophercloud/gophercloud
go run main.go
```

---

## 참고 자료

### 공식 문서

- [Keystone Documentation](https://docs.openstack.org/keystone/latest/)
- [Keystone Tokens Overview](https://docs.openstack.org/keystone/latest/admin/tokens-overview.html)
- [Token Provider](https://docs.openstack.org/keystone/latest/admin/token-provider.html)
- [Configuring Federation](https://docs.openstack.org/keystone/latest/admin/federation/configure_federation.html)

### Go 라이브러리

- [gophercloud/gophercloud](https://github.com/gophercloud/gophercloud)
- [gophercloud/gophercloud/openstack/identity/v3](https://pkg.go.dev/github.com/gophercloud/gophercloud/openstack/identity/v3)

### 추가 학습

- [OpenStack Security Guide - Identity](https://docs.openstack.org/security-guide/identity.html)
- [Keystone Federation Introduction](https://docs.openstack.org/keystone/latest/admin/federation/introduction.html)

---

## 학습 체크리스트

- [ ] Keystone 아키텍처 이해 (Identity, Resource, Token, Catalog)
- [ ] Fernet vs JWS 토큰 차이점 파악
- [ ] Domain-Project-User 계층 구조 이해
- [ ] SQL vs LDAP 백엔드 비교
- [ ] Federation (SAML/OIDC) 플로우 이해
- [ ] Policy 파일 작성 및 RBAC 정책 설계
- [ ] Go로 Keystone 클라이언트 개발
- [ ] Fernet 키 로테이션 실습
- [ ] 멀티 테넌트 환경 구성
- [ ] LDAP 통합 구현

---

**다음 챕터**: [Ch2. OAuth 2.0 / OIDC / JWT](Ch2.OAuth_OIDC_JWT.md)에서 현대적인 인증 프로토콜을 학습합니다.

**Sources:**
- [Keystone Tokens Overview](https://docs.openstack.org/keystone/latest/admin/tokens-overview.html)
- [Token Provider Documentation](https://docs.openstack.org/keystone/latest/admin/token-provider.html)
- [JSON Web Tokens Spec](https://specs.openstack.org/openstack/keystone-specs/specs/keystone/stein/json-web-tokens.html)
- [Configuring Keystone Federation](https://docs.openstack.org/keystone/latest/admin/federation/configure_federation.html)
- [Federation Introduction](https://docs.openstack.org/keystone/latest/admin/federation/introduction.html)
