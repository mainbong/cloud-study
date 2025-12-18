# Ch3. RBAC & ABAC 접근 제어 모델

## 📋 개요 및 학습 목표

현대 클라우드 서비스에서 누가(Who) 무엇을(What) 할 수 있는지 결정하는 접근 제어 메커니즘인 **RBAC (Role-Based Access Control)**와 **ABAC (Attribute-Based Access Control)**을 학습합니다.

### 왜 중요한가?

KakaoCloud IAM 서비스에서는 수천 명의 사용자와 수백 개의 프로젝트(테넌트)를 관리합니다. 효과적인 접근 제어 없이는:

- ❌ 권한 과다 부여 (Over-privileged access)
- ❌ 권한 관리 복잡도 증가
- ❌ 컴플라이언스 위반 (GDPR, HIPAA 등)
- ❌ 보안 사고 발생 (데이터 유출, 무단 접근)

2025년 현재 대부분의 기업은 **RBAC + ABAC 하이브리드 모델**을 채택하고 있습니다:
- **RBAC**: 고수준 역할 기반 권한 (Admin, Developer, Viewer)
- **ABAC**: 세밀한 컨텍스트 기반 제어 (시간, 위치, 리소스 민감도)

### 학습 후 얻을 수 있는 역량

- [x] RBAC 역할 계층 구조 설계 및 구현
- [x] ABAC 정책 모델 설계 및 속성 정의
- [x] Go의 Casbin 라이브러리로 정책 엔진 개발
- [x] 하이브리드 RBAC+ABAC 모델 구현
- [x] Zero Trust 환경에서의 동적 권한 평가

---

## 🔑 핵심 개념 및 이론

### 1. RBAC (Role-Based Access Control)

**RBAC**는 사용자에게 역할(Role)을 할당하고, 역할에 권한(Permission)을 부여하는 모델입니다.

#### RBAC 구성 요소

```
User → Role → Permission → Resource
```

- **User**: 주체 (사용자, 서비스 계정)
- **Role**: 역할 (Admin, Developer, Viewer)
- **Permission**: 권한 (read, write, delete)
- **Resource**: 대상 (파일, API 엔드포인트, 데이터베이스)

#### RBAC 역할 계층 예시 (KakaoCloud)

```mermaid
graph TD
    SuperAdmin[Super Admin<br/>전체 시스템 관리]
    TenantAdmin[Tenant Admin<br/>프로젝트 관리]
    ProjectOwner[Project Owner<br/>리소스 생성/삭제]
    Developer[Developer<br/>읽기/쓰기]
    Viewer[Viewer<br/>읽기 전용]

    SuperAdmin --> TenantAdmin
    TenantAdmin --> ProjectOwner
    ProjectOwner --> Developer
    Developer --> Viewer

    style SuperAdmin fill:#ff6b6b
    style TenantAdmin fill:#ffa500
    style ProjectOwner fill:#ffd700
    style Developer fill:#87ceeb
    style Viewer fill:#90ee90
```

**상속 규칙**: 상위 역할은 하위 역할의 모든 권한을 포함합니다.

#### RBAC 장점 vs 단점

| 장점 | 단점 |
|------|------|
| ✅ 단순하고 이해하기 쉬움 | ❌ 역할 폭발 문제 (Role Explosion) |
| ✅ 구현 및 관리 용이 | ❌ 동적 컨텍스트 처리 불가 |
| ✅ 감사 추적 간단 | ❌ 세밀한 제어 어려움 |
| ✅ 안정적인 조직 구조에 적합 | ❌ 예외 처리 복잡 |

**역할 폭발 예시**:
```
Admin
Admin_ReadOnly
Admin_Finance
Admin_Finance_ReadOnly
Developer
Developer_Backend
Developer_Frontend
Developer_Backend_Senior
...
```
→ 역할이 무한히 증가하는 문제!

---

### 2. ABAC (Attribute-Based Access Control)

**ABAC**는 사용자, 리소스, 환경의 **속성(Attribute)**을 기반으로 동적으로 권한을 평가합니다.

#### ABAC 구성 요소

```
if (user.department == "Engineering" AND
    resource.classification == "Public" AND
    environment.time BETWEEN 9am-6pm AND
    environment.location IN ["Office", "VPN"])
then ALLOW
```

**속성 유형**:

1. **Subject Attributes (주체 속성)**:
   - `user.id`, `user.role`, `user.department`, `user.clearance_level`
   - `user.employment_type` (정규직, 계약직)

2. **Resource Attributes (리소스 속성)**:
   - `resource.owner`, `resource.project_id`, `resource.classification`
   - `resource.creation_date`, `resource.sensitivity`

3. **Action Attributes (동작 속성)**:
   - `action.type` (read, write, delete, execute)
   - `action.scope` (single, bulk)

4. **Environment Attributes (환경 속성)**:
   - `environment.time`, `environment.location`, `environment.ip_address`
   - `environment.device_trust_level`, `environment.network_type`

#### ABAC 평가 흐름

```mermaid
graph LR
    Request[Access Request] --> PDP[Policy Decision Point]
    PDP --> PIP[Policy Information Point]
    PIP --> |Fetch Attributes|DB[(Attribute Store)]
    PDP --> |Evaluate Policy|Decision{Allow/Deny}
    Decision --> |Allow|PEP[Policy Enforcement Point]
    Decision --> |Deny|Reject[Reject]
    PEP --> Resource[Access Resource]

    style PDP fill:#4ecdc4
    style PEP fill:#95e1d3
    style Decision fill:#ffd166
```

#### ABAC 장점 vs 단점

| 장점 | 단점 |
|------|------|
| ✅ 세밀한 제어 (Fine-grained) | ❌ 초기 설정 복잡 |
| ✅ 동적 컨텍스트 지원 | ❌ 성능 오버헤드 |
| ✅ 역할 폭발 방지 | ❌ 디버깅 어려움 |
| ✅ Zero Trust에 적합 | ❌ 전문 지식 필요 |

---

### 3. RBAC vs ABAC 비교 (2025년 관점)

| 항목 | RBAC | ABAC |
|------|------|------|
| **복잡도** | 낮음 | 높음 |
| **세밀함** | 낮음 | 매우 높음 |
| **구현 시간** | 빠름 (1-2주) | 느림 (1-2개월) |
| **관리 비용** | 낮음 | 높음 |
| **동적 제어** | 불가능 | 가능 |
| **Zero Trust** | 부적합 | 적합 |
| **사용 사례** | 안정적 조직 구조 | 규제 준수, 민감 데이터 |
| **성능** | ⚡⚡⚡ 빠름 | ⚡⚡ 보통 (속성 조회 필요) |

**2025 권장사항 (하이브리드 모델)**:
```
RBAC (기본 역할 정의) + ABAC (세밀한 제어)
```

**예시**:
- **RBAC**: `Developer` 역할 할당 → 모든 개발 리소스 접근
- **ABAC**: "단, 근무 시간(9am-6pm)에만" + "자신이 소유한 프로젝트만" + "VPN 연결 시에만"

---

### 4. Casbin 정책 엔진

**Casbin**은 Go로 작성된 강력한 오픈소스 접근 제어 라이브러리입니다.

**지원 모델**:
- ACL, RBAC, ABAC, ReBAC, PBAC, LBAC, Priority, RESTful 등

**주요 특징**:
- ✅ 정책을 코드와 분리 (외부 파일, DB 저장)
- ✅ 다양한 스토리지 백엔드 (MySQL, PostgreSQL, Redis, MongoDB, S3 등)
- ✅ 온라인 에디터 제공 ([casbin.org/editor](https://casbin.org/editor/))
- ✅ Management API + RBAC API

#### Casbin 구성 요소

**1. Model (모델 정의)** - `model.conf`:
```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
```

**2. Policy (정책 데이터)** - `policy.csv`:
```
p, alice, data1, read
p, bob, data2, write
g, alice, admin
```

**3. Enforcer (실행 엔진)**:
```go
e, _ := casbin.NewEnforcer("model.conf", "policy.csv")
allowed, _ := e.Enforce("alice", "data1", "read")
```

---

## 💻 실습 가이드 (Hands-on)

### Lab 1: RBAC 구현 (Casbin)

**목표**: Casbin을 사용한 계층적 RBAC 시스템 구축

#### 1단계: 의존성 설치

```bash
mkdir rbac-demo && cd rbac-demo
go mod init rbac-demo
go get github.com/casbin/casbin/v2
```

#### 2단계: RBAC 모델 정의

`model.conf`:
```ini
[request_definition]
# sub: 주체 (사용자), obj: 객체 (리소스), act: 동작
r = sub, obj, act

[policy_definition]
# 정책 규칙: 누가(sub) 무엇을(obj) 어떻게(act) 할 수 있는가
p = sub, obj, act

[role_definition]
# 역할 계층: g(사용자, 역할) 또는 g(역할, 상위역할)
g = _, _

[policy_effect]
# 허용 정책이 하나라도 있으면 Allow
e = some(where (p.eft == allow))

[matchers]
# 매칭 규칙: 사용자가 해당 역할을 가지고 있고, 리소스와 동작이 일치하면 허용
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
```

#### 3단계: 정책 데이터 정의

`policy.csv`:
```csv
# 역할별 권한 (p, role, resource, action)
p, admin, /api/*, *
p, developer, /api/projects, read
p, developer, /api/projects, write
p, viewer, /api/projects, read

# 사용자 역할 할당 (g, user, role)
g, alice, admin
g, bob, developer
g, charlie, viewer

# 역할 계층 (g, child_role, parent_role)
g, developer, viewer
```

**해석**:
- `admin`: 모든 API 엔드포인트에 대해 모든 동작 가능
- `developer`: `/api/projects`에 대해 read, write 가능
- `viewer`: `/api/projects`에 대해 read만 가능
- `developer` 역할은 `viewer`의 모든 권한을 상속

#### 4단계: Go 코드 구현

```go
// main.go
package main

import (
    "fmt"
    "log"

    "github.com/casbin/casbin/v2"
)

func main() {
    // 1. Enforcer 생성
    e, err := casbin.NewEnforcer("model.conf", "policy.csv")
    if err != nil {
        log.Fatalf("Failed to create enforcer: %v", err)
    }

    // 2. 권한 검사
    testCases := []struct {
        user     string
        resource string
        action   string
    }{
        {"alice", "/api/users", "delete"},        // admin
        {"bob", "/api/projects", "write"},        // developer
        {"bob", "/api/projects", "read"},         // developer (상속된 권한)
        {"charlie", "/api/projects", "read"},     // viewer
        {"charlie", "/api/projects", "write"},    // 거부되어야 함
        {"bob", "/api/users", "read"},            // 거부되어야 함
    }

    fmt.Println("=== RBAC Authorization Tests ===\n")
    for _, tc := range testCases {
        allowed, err := e.Enforce(tc.user, tc.resource, tc.action)
        if err != nil {
            log.Printf("Error checking %s: %v", tc.user, err)
            continue
        }

        result := "✓ ALLOW"
        if !allowed {
            result = "✗ DENY"
        }
        fmt.Printf("%s | User: %s | Resource: %s | Action: %s\n",
            result, tc.user, tc.resource, tc.action)
    }

    // 3. 동적으로 정책 추가
    fmt.Println("\n=== Dynamic Policy Management ===\n")

    // 새 사용자에게 역할 할당
    added, err := e.AddGroupingPolicy("david", "developer")
    if err == nil && added {
        fmt.Println("✓ Assigned 'developer' role to david")
    }

    // 검증
    allowed, _ := e.Enforce("david", "/api/projects", "write")
    if allowed {
        fmt.Println("✓ david can now write to /api/projects")
    }

    // 역할 제거
    removed, err := e.RemoveGroupingPolicy("david", "developer")
    if err == nil && removed {
        fmt.Println("✓ Removed 'developer' role from david")
    }

    // 4. 사용자의 모든 역할 조회
    fmt.Println("\n=== User Roles ===\n")
    roles := e.GetRolesForUser("bob")
    fmt.Printf("bob's roles: %v\n", roles)

    // 역할의 모든 사용자 조회
    users := e.GetUsersForRole("developer")
    fmt.Printf("Users with 'developer' role: %v\n", users)

    // 5. 역할의 모든 권한 조회
    fmt.Println("\n=== Role Permissions ===\n")
    permissions := e.GetPermissionsForUser("developer")
    fmt.Printf("'developer' role permissions:\n")
    for _, perm := range permissions {
        fmt.Printf("  - Resource: %s, Action: %s\n", perm[1], perm[2])
    }

    // 6. 정책 저장 (변경 사항 유지)
    err = e.SavePolicy()
    if err != nil {
        log.Printf("Failed to save policy: %v", err)
    } else {
        fmt.Println("\n✓ Policy saved successfully")
    }
}
```

#### 5단계: 실행 및 결과

```bash
$ go run main.go

=== RBAC Authorization Tests ===

✓ ALLOW | User: alice | Resource: /api/users | Action: delete
✓ ALLOW | User: bob | Resource: /api/projects | Action: write
✓ ALLOW | User: bob | Resource: /api/projects | Action: read
✓ ALLOW | User: charlie | Resource: /api/projects | Action: read
✗ DENY | User: charlie | Resource: /api/projects | Action: write
✗ DENY | User: bob | Resource: /api/users | Action: read

=== Dynamic Policy Management ===

✓ Assigned 'developer' role to david
✓ david can now write to /api/projects
✓ Removed 'developer' role from david

=== User Roles ===

bob's roles: [developer]
Users with 'developer' role: [bob]

=== Role Permissions ===

'developer' role permissions:
  - Resource: /api/projects, Action: read
  - Resource: /api/projects, Action: write

✓ Policy saved successfully
```

---

### Lab 2: ABAC 구현 (Casbin)

**목표**: 속성 기반의 세밀한 접근 제어 구현

#### 1단계: ABAC 모델 정의

`abac_model.conf`:
```ini
[request_definition]
# sub: 사용자 객체, obj: 리소스 객체, act: 동작
r = sub, obj, act

[policy_definition]
p = sub_rule, obj_rule, act

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
# ABAC 매처: 속성 기반 평가
m = eval(p.sub_rule) && eval(p.obj_rule) && r.act == p.act
```

#### 2단계: ABAC 정책 데이터

`abac_policy.csv`:
```csv
# 정책: (주체 규칙, 객체 규칙, 동작)
# "자신의 리소스만 읽기 가능"
p, r.sub.ID == r.obj.Owner, r.obj.Status == "Active", read

# "Admin은 모든 리소스 읽기 가능"
p, r.sub.Role == "Admin", , read

# "근무 시간(9-18시)에만 쓰기 가능"
p, r.sub.Role == "Developer" && r.sub.WorkingHours == true, r.obj.Classification != "Confidential", write
```

#### 3단계: Go 구조체 및 코드

```go
// abac.go
package main

import (
    "fmt"
    "log"
    "time"

    "github.com/casbin/casbin/v2"
)

// 주체 (사용자)
type Subject struct {
    ID           string
    Name         string
    Role         string
    Department   string
    WorkingHours bool
}

// 객체 (리소스)
type Resource struct {
    ID             string
    Owner          string
    Classification string // Public, Internal, Confidential
    Status         string // Active, Archived
    ProjectID      string
}

// 주체를 Casbin에서 사용할 수 있는 형태로 변환
func (s Subject) ToCasbinObj() map[string]interface{} {
    return map[string]interface{}{
        "ID":           s.ID,
        "Name":         s.Name,
        "Role":         s.Role,
        "Department":   s.Department,
        "WorkingHours": s.WorkingHours,
    }
}

// 리소스를 Casbin에서 사용할 수 있는 형태로 변환
func (r Resource) ToCasbinObj() map[string]interface{} {
    return map[string]interface{}{
        "ID":             r.ID,
        "Owner":          r.Owner,
        "Classification": r.Classification,
        "Status":         r.Status,
        "ProjectID":      r.ProjectID,
    }
}

// 현재 시간이 근무 시간인지 확인
func isWorkingHours() bool {
    hour := time.Now().Hour()
    return hour >= 9 && hour < 18
}

func main() {
    // Enforcer 생성
    e, err := casbin.NewEnforcer("abac_model.conf", "abac_policy.csv")
    if err != nil {
        log.Fatalf("Failed to create enforcer: %v", err)
    }

    // 테스트 데이터
    alice := Subject{
        ID:           "user-001",
        Name:         "Alice",
        Role:         "Developer",
        Department:   "Engineering",
        WorkingHours: isWorkingHours(),
    }

    bob := Subject{
        ID:           "user-002",
        Name:         "Bob",
        Role:         "Admin",
        Department:   "Operations",
        WorkingHours: true,
    }

    resource1 := Resource{
        ID:             "res-001",
        Owner:          "user-001", // Alice 소유
        Classification: "Public",
        Status:         "Active",
        ProjectID:      "project-A",
    }

    resource2 := Resource{
        ID:             "res-002",
        Owner:          "user-003", // 다른 사람 소유
        Classification: "Confidential",
        Status:         "Active",
        ProjectID:      "project-B",
    }

    resource3 := Resource{
        ID:             "res-003",
        Owner:          "user-001",
        Classification: "Internal",
        Status:         "Archived",
        ProjectID:      "project-A",
    }

    fmt.Println("=== ABAC Authorization Tests ===\n")
    fmt.Printf("Current Time: %s (Working Hours: %v)\n\n", time.Now().Format("15:04"), alice.WorkingHours)

    // 테스트 케이스
    testCases := []struct {
        subject  Subject
        resource Resource
        action   string
        expected string
    }{
        {alice, resource1, "read", "자신의 리소스 읽기"},
        {alice, resource1, "write", "근무시간 & Public 리소스 쓰기"},
        {alice, resource2, "read", "타인의 리소스 읽기 (거부)"},
        {alice, resource2, "write", "Confidential 리소스 쓰기 (거부)"},
        {bob, resource2, "read", "Admin의 모든 리소스 읽기"},
        {alice, resource3, "read", "Archived 리소스 읽기 (거부)"},
    }

    for _, tc := range testCases {
        allowed, err := e.Enforce(tc.subject.ToCasbinObj(), tc.resource.ToCasbinObj(), tc.action)
        if err != nil {
            log.Printf("Error: %v", err)
            continue
        }

        result := "✓ ALLOW"
        if !allowed {
            result = "✗ DENY"
        }

        fmt.Printf("%s | %s (%s) | %s | %s | %s\n",
            result,
            tc.subject.Name,
            tc.subject.Role,
            tc.action,
            tc.resource.ID,
            tc.expected,
        )
    }

    // 커스텀 함수 등록 (복잡한 로직)
    fmt.Println("\n=== Custom Function Example ===\n")

    e.AddFunction("timeInRange", func(args ...interface{}) (interface{}, error) {
        start := args[0].(int)
        end := args[1].(int)
        current := time.Now().Hour()
        return current >= start && current < end, nil
    })

    // 새로운 정책 추가
    _, err = e.AddPolicy(
        "r.sub.Role == \"Developer\" && timeInRange(9, 18)",
        "r.obj.Classification == \"Public\"",
        "delete",
    )
    if err == nil {
        fmt.Println("✓ Added time-based policy")
    }

    // 검증
    allowed, _ := e.Enforce(alice.ToCasbinObj(), resource1.ToCasbinObj(), "delete")
    if allowed {
        fmt.Printf("✓ Alice can delete public resources during working hours (current: %d:00)\n", time.Now().Hour())
    } else {
        fmt.Printf("✗ Alice cannot delete resources (current: %d:00)\n", time.Now().Hour())
    }
}
```

**실행 결과**:
```
=== ABAC Authorization Tests ===

Current Time: 14:30 (Working Hours: true)

✓ ALLOW | Alice (Developer) | read | res-001 | 자신의 리소스 읽기
✓ ALLOW | Alice (Developer) | write | res-001 | 근무시간 & Public 리소스 쓰기
✗ DENY | Alice (Developer) | read | res-002 | 타인의 리소스 읽기 (거부)
✗ DENY | Alice (Developer) | write | res-002 | Confidential 리소스 쓰기 (거부)
✓ ALLOW | Bob (Admin) | read | res-002 | Admin의 모든 리소스 읽기
✗ DENY | Alice (Developer) | read | res-003 | Archived 리소스 읽기 (거부)

=== Custom Function Example ===

✓ Added time-based policy
✓ Alice can delete public resources during working hours (current: 14:00)
```

---

### Lab 3: 하이브리드 RBAC + ABAC

**목표**: RBAC의 단순함 + ABAC의 세밀함을 결합

#### 모델 정의

`hybrid_model.conf`:
```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act, eft

[role_definition]
g = _, _

[policy_effect]
# 명시적 거부(deny)가 있으면 거부, 없으면 허용 정책 확인
e = some(where (p.eft == allow)) && !some(where (p.eft == deny))

[matchers]
# RBAC (역할 기반) + ABAC (속성 기반)
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act || \
    eval(p.sub) && eval(p.obj) && r.act == p.act
```

#### 하이브리드 정책

`hybrid_policy.csv`:
```csv
# === RBAC 정책 ===
# 역할 정의
p, admin, *, *, allow
p, developer, /api/projects/*, read, allow
p, developer, /api/projects/*, write, allow

# 사용자 역할
g, alice, developer

# === ABAC 정책 (세밀한 제어) ===
# "자신의 리소스가 아니면 거부"
p, r.sub.ID != r.obj.Owner, , write, deny

# "근무 시간 외 쓰기 거부"
p, r.sub.WorkingHours == false, , write, deny

# "Confidential 리소스는 Admin만 접근"
p, r.sub.Role != "Admin", r.obj.Classification == "Confidential", *, deny
```

**해석**:
1. **RBAC 레이어**: `developer` 역할은 `/api/projects/*`에 read/write 가능
2. **ABAC 레이어**:
   - 자신의 리소스가 아니면 write 거부
   - 근무 시간 외에는 write 거부
   - Confidential 리소스는 Admin만 접근

#### Go 구현

```go
// hybrid.go
package main

import (
    "fmt"
    "log"

    "github.com/casbin/casbin/v2"
)

func main() {
    e, err := casbin.NewEnforcer("hybrid_model.conf", "hybrid_policy.csv")
    if err != nil {
        log.Fatalf("Failed to create enforcer: %v", err)
    }

    // Alice (Developer, 근무 시간 중)
    alice := map[string]interface{}{
        "ID":           "user-001",
        "Role":         "Developer",
        "WorkingHours": true,
    }

    // 리소스
    ownResource := map[string]interface{}{
        "ID":             "res-001",
        "Owner":          "user-001",
        "Classification": "Public",
    }

    othersResource := map[string]interface{}{
        "ID":             "res-002",
        "Owner":          "user-999",
        "Classification": "Internal",
    }

    confidentialResource := map[string]interface{}{
        "ID":             "res-003",
        "Owner":          "user-001",
        "Classification": "Confidential",
    }

    fmt.Println("=== Hybrid RBAC + ABAC Tests ===\n")

    // 1. 자신의 Public 리소스 쓰기: ALLOW (RBAC + ABAC 모두 통과)
    allowed, _ := e.Enforce(alice, ownResource, "write")
    fmt.Printf("1. Write own public resource: %v (RBAC ✓ + ABAC ✓)\n", allowed)

    // 2. 타인의 리소스 쓰기: DENY (ABAC에서 거부)
    allowed, _ = e.Enforce(alice, othersResource, "write")
    fmt.Printf("2. Write others' resource: %v (RBAC ✓ but ABAC ✗)\n", allowed)

    // 3. Confidential 리소스 읽기: DENY (ABAC에서 거부)
    allowed, _ = e.Enforce(alice, confidentialResource, "read")
    fmt.Printf("3. Read confidential resource: %v (ABAC ✗)\n", allowed)

    // 4. 근무 시간 외 쓰기
    aliceAfterHours := map[string]interface{}{
        "ID":           "user-001",
        "Role":         "Developer",
        "WorkingHours": false,
    }
    allowed, _ = e.Enforce(aliceAfterHours, ownResource, "write")
    fmt.Printf("4. Write after working hours: %v (ABAC ✗)\n", allowed)
}
```

**실행 결과**:
```
=== Hybrid RBAC + ABAC Tests ===

1. Write own public resource: true (RBAC ✓ + ABAC ✓)
2. Write others' resource: false (RBAC ✓ but ABAC ✗)
3. Read confidential resource: false (ABAC ✗)
4. Write after working hours: false (ABAC ✗)
```

---

### Lab 4: HTTP API 서버에 Casbin 통합

**목표**: RESTful API 서버에서 Casbin으로 권한 검사

```go
// api_server.go
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "strings"

    "github.com/casbin/casbin/v2"
)

var enforcer *casbin.Enforcer

// Casbin Middleware
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // 1. 사용자 인증 (JWT 토큰에서 추출 가정)
        user := r.Header.Get("X-User-ID")
        if user == "" {
            http.Error(w, "Unauthorized: No user ID", http.StatusUnauthorized)
            return
        }

        // 2. Casbin 권한 검사
        allowed, err := enforcer.Enforce(user, r.URL.Path, r.Method)
        if err != nil {
            http.Error(w, "Authorization error", http.StatusInternalServerError)
            return
        }

        if !allowed {
            http.Error(w, fmt.Sprintf("Forbidden: %s cannot %s %s", user, r.Method, r.URL.Path),
                http.StatusForbidden)
            return
        }

        // 3. 권한 통과 → 다음 핸들러 실행
        next(w, r)
    }
}

// API 핸들러들
func listProjects(w http.ResponseWriter, r *http.Request) {
    projects := []string{"project-A", "project-B", "project-C"}
    json.NewEncoder(w).Encode(map[string]interface{}{
        "projects": projects,
    })
}

func createProject(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Project created successfully",
    })
}

func deleteProject(w http.ResponseWriter, r *http.Request) {
    json.NewEncoder(w).Encode(map[string]string{
        "message": "Project deleted successfully",
    })
}

func main() {
    // Casbin 초기화
    var err error
    enforcer, err = casbin.NewEnforcer("api_model.conf", "api_policy.csv")
    if err != nil {
        log.Fatalf("Failed to create enforcer: %v", err)
    }

    // 라우트 등록
    http.HandleFunc("/api/projects", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
        switch r.Method {
        case http.MethodGet:
            listProjects(w, r)
        case http.MethodPost:
            createProject(w, r)
        default:
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        }
    }))

    http.HandleFunc("/api/projects/", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
        if r.Method == http.MethodDelete {
            deleteProject(w, r)
        } else {
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        }
    }))

    log.Println("API Server running on :8080")
    log.Println("Test with: curl -H 'X-User-ID: alice' http://localhost:8080/api/projects")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

**API 모델** (`api_model.conf`):
```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && keyMatch2(r.obj, p.obj) && regexMatch(r.act, p.act)
```

**API 정책** (`api_policy.csv`):
```csv
# 역할 권한
p, admin, /api/*, (GET)|(POST)|(PUT)|(DELETE)
p, developer, /api/projects, (GET)|(POST)
p, viewer, /api/projects, GET

# 사용자 역할
g, alice, developer
g, bob, viewer
g, admin_user, admin
```

**테스트**:
```bash
# 서버 실행
go run api_server.go

# Alice (developer): GET 성공
curl -H "X-User-ID: alice" http://localhost:8080/api/projects
# → {"projects":["project-A","project-B","project-C"]}

# Alice: POST 성공
curl -X POST -H "X-User-ID: alice" http://localhost:8080/api/projects
# → {"message":"Project created successfully"}

# Bob (viewer): GET 성공
curl -H "X-User-ID: bob" http://localhost:8080/api/projects
# → {"projects":["project-A","project-B","project-C"]}

# Bob: DELETE 실패
curl -X DELETE -H "X-User-ID: bob" http://localhost:8080/api/projects/123
# → Forbidden: bob cannot DELETE /api/projects/123
```

---

### Lab 5: PostgreSQL 기반 정책 저장소

**목표**: 정책을 데이터베이스에 저장하여 동적 관리

```bash
go get github.com/casbin/casbin/v2
go get github.com/casbin/pg-adapter
go get github.com/lib/pq
```

```go
// db_policy.go
package main

import (
    "fmt"
    "log"

    "github.com/casbin/casbin/v2"
    pgadapter "github.com/casbin/pg-adapter"
)

func main() {
    // PostgreSQL 연결
    adapter, err := pgadapter.NewAdapter(
        "postgres://user:password@localhost:5432/casbin_db?sslmode=disable",
        "casbin_rule", // 테이블 이름
    )
    if err != nil {
        log.Fatalf("Failed to create adapter: %v", err)
    }

    // Enforcer 생성 (DB 기반)
    e, err := casbin.NewEnforcer("model.conf", adapter)
    if err != nil {
        log.Fatalf("Failed to create enforcer: %v", err)
    }

    // 정책 자동 로드
    err = e.LoadPolicy()
    if err != nil {
        log.Fatalf("Failed to load policy: %v", err)
    }

    fmt.Println("=== DB-based Policy Management ===\n")

    // 1. 정책 추가
    added, _ := e.AddPolicy("david", "/api/storage", "read")
    if added {
        fmt.Println("✓ Added policy: david can read /api/storage")
    }

    // 2. 역할 할당
    e.AddGroupingPolicy("david", "developer")
    fmt.Println("✓ Assigned 'developer' role to david")

    // 3. 정책 저장 (DB에 영구 저장)
    err = e.SavePolicy()
    if err != nil {
        log.Fatalf("Failed to save policy: %v", err)
    }
    fmt.Println("✓ Policy saved to database")

    // 4. 검증
    allowed, _ := e.Enforce("david", "/api/storage", "read")
    fmt.Printf("\nCan david read /api/storage? %v\n", allowed)

    // 5. 모든 정책 조회
    policies := e.GetPolicy()
    fmt.Println("\nAll policies in database:")
    for _, p := range policies {
        fmt.Printf("  %v\n", p)
    }
}
```

**PostgreSQL 스키마** (자동 생성됨):
```sql
CREATE TABLE casbin_rule (
    id SERIAL PRIMARY KEY,
    ptype VARCHAR(100),
    v0 VARCHAR(100),
    v1 VARCHAR(100),
    v2 VARCHAR(100),
    v3 VARCHAR(100),
    v4 VARCHAR(100),
    v5 VARCHAR(100)
);
```

---

## 📚 참고 자료

### 공식 문서

**RBAC vs ABAC**:
- [RBAC vs ABAC Comparison - Splunk](https://www.splunk.com/en_us/blog/learn/rbac-vs-abac.html)
- [RBAC vs ABAC vs PBAC - Oso 2025](https://www.osohq.com/learn/rbac-vs-abac-vs-pbac)
- [RBAC vs ABAC Best Practices](https://www.osohq.com/learn/rbac-vs-abac)
- [AWS Access Control Types](https://docs.aws.amazon.com/prescriptive-guidance/latest/saas-multitenant-api-access-authorization/access-control-types.html)
- [Role-Based Access Control Best Practices 2025](https://www.techprescient.com/blogs/role-based-access-control-best-practices/)
- [RBAC vs ABAC - Okta](https://www.okta.com/identity-101/role-based-access-control-vs-attribute-based-access-control/)
- [RBAC vs ABAC - OLOID](https://www.oloid.com/blog/rbac-vs-abac-the-difference-between-the-two-types-of-access-control)
- [RBAC Implementation Best Practices - Kiteworks](https://www.kiteworks.com/risk-compliance-glossary/role-based-access-control/)
- [RBAC vs ABAC vs ACL vs PBAC vs DAC - StrongDM](https://www.strongdm.com/blog/rbac-vs-abac)
- [RBAC vs ABAC - OneLogin](https://www.onelogin.com/learn/rbac-vs-abac)

**Casbin**:
- [Casbin Official Website](https://casbin.org/)
- [Casbin GitHub](https://github.com/casbin/casbin)
- [Casbin v2 Documentation](https://pkg.go.dev/github.com/casbin/casbin/v2)
- [Casbin Tutorials](https://casbin.org/docs/tutorials/)
- [Casbin Online Editor](https://casbin.org/editor/)
- [Basic HTTP Authorization with Casbin](https://www.zupzup.org/casbin-http-role-auth/index.html)
- [Building RBAC in Go - Aserto](https://www.aserto.com/blog/building-rbac-in-go)
- [HTTP Authorization with Casbin, Redis, PostgreSQL](https://dev.to/girishg4t/basic-role-based-http-authorization-in-go-with-casbin-redis-postgresql-1eh2)

**ABAC Implementation**:
- [ABAC Enterprise Implementation - Permify](https://permify.co/post/attribute-based-access-control-abac/)
- [ABAC with OPA - Medium](https://medium.com/permify-tech-blog/attribute-based-access-control-abac-implementation-with-open-policy-agent-opa-b47052248f29)
- [ABAC Basics - GeeksforGeeks](https://www.geeksforgeeks.org/system-design/attribute-based-access-controlabac/)
- [How to Implement ABAC - Permit.io](https://www.permit.io/blog/how-to-implement-abac)
- [NIST ABAC Project](https://csrc.nist.gov/projects/attribute-based-access-control)
- [Golang ABAC Demo - GitHub](https://github.com/TropicolX/golang-abac-demo)
- [ABAC Complete Guide - Zluri](https://www.zluri.com/blog/attribute-based-access-control)
- [What is ABAC? - CrowdStrike](https://www.crowdstrike.com/en-us/cybersecurity-101/identity-protection/attribute-based-access-control-abac/)

### 학습 체크리스트

- [ ] RBAC 역할 계층 구조 설계 및 구현
- [ ] Casbin으로 RBAC 시스템 구축
- [ ] ABAC 정책 모델 작성 및 속성 정의
- [ ] RBAC vs ABAC 장단점 비교 이해
- [ ] 하이브리드 RBAC+ABAC 모델 구현
- [ ] HTTP API 서버에 Casbin 미들웨어 통합
- [ ] PostgreSQL 기반 정책 저장소 구축
- [ ] Casbin 온라인 에디터 활용
- [ ] Zero Trust 환경에서의 동적 권한 평가 구현
- [ ] 역할 폭발 문제 해결 전략 수립

---

## 🎯 다음 단계

Ch4에서는 **Open Policy Agent (OPA)**를 학습합니다. OPA는 Rego 언어로 정책을 코드로 작성하는 Policy-as-Code 접근법을 제공하며, Kubernetes Admission Control, API Gateway 인가 등 다양한 환경에서 활용됩니다.

**Preview**:
- OPA 아키텍처 및 Rego 언어
- Kubernetes Admission Control with OPA
- API Gateway 인가 정책
- OPA Bundle 관리 및 배포
