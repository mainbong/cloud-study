# Ch2. API 설계

## 📋 개요

API(Application Programming Interface)는 현대 클라우드 네이티브 애플리케이션의 핵심 구성 요소입니다. 마이크로서비스 아키텍처, 서버리스 컴퓨팅, 멀티 클라우드 환경에서 API는 서비스 간 통신의 중추 역할을 합니다.

2025년 현재, RESTful API가 여전히 가장 널리 사용되는 패턴이지만, 61% 이상의 조직이 GraphQL을 함께 활용하고 있으며, gRPC는 마이크로서비스 간 통신에서 최대 47% 더 높은 처리량을 보여주고 있습니다.

이 챕터에서는 RESTful API 설계 원칙, gRPC 성능 최적화, API Gateway 패턴, 그리고 효과적인 버저닝 전략까지 실무에서 바로 적용할 수 있는 API 설계 지식을 다룹니다.

---

## 🎯 학습 목표

이 챕터를 완료하면 다음을 할 수 있습니다:

- RESTful API 설계 Best Practices 적용 및 OpenAPI 3.2 활용
- gRPC와 REST의 성능 차이 이해 및 적절한 선택
- API Gateway (Kong, Envoy) 패턴 구현 및 Rate Limiting 설정
- Semantic Versioning을 활용한 API 버전 관리
- 캐싱, 압축, 페이지네이션을 통한 API 성능 최적화
- GraphQL의 장단점 이해 및 하이브리드 접근법 적용

---

## Part 1: RESTful API 설계

### 1-1. REST 아키텍처 원칙

**REST (Representational State Transfer) 6가지 제약조건:**

```
1. Client-Server 분리
   ├─ 클라이언트와 서버의 독립적인 발전
   └─ UI와 비즈니스 로직 분리

2. Stateless (무상태성)
   ├─ 각 요청은 독립적
   ├─ 서버는 클라이언트 상태를 저장하지 않음
   └─ 확장성 향상

3. Cacheable (캐시 가능)
   ├─ 응답은 캐시 가능 여부를 명시
   ├─ Cache-Control 헤더 활용
   └─ 성능 및 확장성 개선

4. Uniform Interface (통일된 인터페이스)
   ├─ 리소스 기반 URL
   ├─ HTTP 메서드 사용 (GET, POST, PUT, DELETE)
   ├─ 표준 상태 코드
   └─ HATEOAS (선택적)

5. Layered System (계층화 시스템)
   ├─ 로드 밸런서, 캐시, API Gateway
   └─ 클라이언트는 중간 계층을 인식하지 못함

6. Code on Demand (선택적)
   └─ 서버가 클라이언트 코드를 전송 가능
```

### 1-2. RESTful API 설계 Best Practices (2025)

**리소스 명명 규칙:**

```
좋은 예:
GET    /users              # 사용자 목록
GET    /users/123          # 특정 사용자
POST   /users              # 사용자 생성
PUT    /users/123          # 사용자 전체 업데이트
PATCH  /users/123          # 사용자 부분 업데이트
DELETE /users/123          # 사용자 삭제
GET    /users/123/posts    # 사용자의 게시글

나쁜 예:
GET    /getUsers           # 동사 사용 X
POST   /createUser         # 동사 사용 X
GET    /user?id=123        # 단수형 + 쿼리 파라미터 X
DELETE /deleteUserById/123 # 불필요하게 길고 복잡
```

**HTTP 메서드 사용:**

| 메서드 | 용도 | 멱등성 | 안전성 | 바디 |
|--------|------|--------|--------|------|
| **GET** | 리소스 조회 | O | O | X |
| **POST** | 리소스 생성 | X | X | O |
| **PUT** | 리소스 전체 업데이트 | O | X | O |
| **PATCH** | 리소스 부분 업데이트 | X | X | O |
| **DELETE** | 리소스 삭제 | O | X | X |
| **HEAD** | 메타데이터만 조회 | O | O | X |
| **OPTIONS** | 지원 메서드 확인 | O | O | X |

**HTTP 상태 코드 (2025 Best Practices):**

```
성공 응답 (2xx):
200 OK               - 요청 성공 (GET, PUT, PATCH)
201 Created          - 리소스 생성 성공 (POST)
202 Accepted         - 비동기 처리 시작
204 No Content       - 성공했지만 반환 데이터 없음 (DELETE)

리다이렉션 (3xx):
301 Moved Permanently - 리소스 영구 이동
304 Not Modified     - 캐시된 버전 사용

클라이언트 에러 (4xx):
400 Bad Request      - 잘못된 요청 형식
401 Unauthorized     - 인증 필요
403 Forbidden        - 권한 없음
404 Not Found        - 리소스 없음
409 Conflict         - 리소스 충돌 (중복 생성 등)
422 Unprocessable Entity - 유효성 검사 실패
429 Too Many Requests - Rate Limit 초과

서버 에러 (5xx):
500 Internal Server Error - 서버 오류
502 Bad Gateway      - 게이트웨이 오류
503 Service Unavailable - 서비스 일시 중단
504 Gateway Timeout  - 게이트웨이 타임아웃
```

**페이지네이션 (2025 패턴):**

```json
// Offset-based Pagination (전통적)
GET /users?page=2&limit=20

Response:
{
  "data": [ /* 20 users */ ],
  "pagination": {
    "page": 2,
    "limit": 20,
    "total": 1000,
    "totalPages": 50
  }
}

// Cursor-based Pagination (대규모 데이터셋, 2025 권장)
GET /users?cursor=eyJpZCI6MTIzfQ==&limit=20

Response:
{
  "data": [ /* 20 users */ ],
  "pagination": {
    "nextCursor": "eyJpZCI6MTQzfQ==",
    "hasMore": true
  }
}

장점:
- Deep pagination 성능 문제 해결
- 실시간 데이터 일관성
- 무한 스크롤에 적합
```

**필터링 및 정렬:**

```
필터링:
GET /users?status=active&role=admin
GET /products?category=electronics&price_min=100&price_max=500

정렬:
GET /users?sort=created_at:desc
GET /products?sort=price:asc,name:asc

필드 선택 (Sparse Fieldsets):
GET /users?fields=id,name,email
```

**에러 응답 표준화 (RFC 7807 - Problem Details):**

```json
{
  "type": "https://api.example.com/errors/validation-error",
  "title": "Validation Error",
  "status": 422,
  "detail": "The email field is required and must be a valid email address",
  "instance": "/users",
  "errors": [
    {
      "field": "email",
      "message": "must be a valid email address",
      "code": "INVALID_EMAIL"
    }
  ],
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

### 1-3. OpenAPI 3.2 Specification (2025)

**OpenAPI란?**

OpenAPI는 RESTful API를 기술하는 표준 스펙입니다. 2025년 현재 OpenAPI 3.2가 지배적인 표준이며, 다음을 개선했습니다:

- 향상된 웹훅 지원
- 개선된 보안 스키마
- API Gateway 통합 개선
- JSON Schema 2020-12 호환성

**OpenAPI 예제:**

```yaml
openapi: 3.2.0
info:
  title: User Management API
  version: 1.0.0
  description: API for managing users
  contact:
    name: API Support
    email: support@example.com
  license:
    name: MIT

servers:
  - url: https://api.example.com/v1
    description: Production server
  - url: https://staging-api.example.com/v1
    description: Staging server

security:
  - bearerAuth: []

paths:
  /users:
    get:
      summary: List all users
      description: Returns a paginated list of users
      tags:
        - Users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
        - name: status
          in: query
          schema:
            type: string
            enum: [active, inactive, suspended]
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'
                  pagination:
                    $ref: '#/components/schemas/Pagination'
        '401':
          $ref: '#/components/responses/UnauthorizedError'

    post:
      summary: Create a new user
      tags:
        - Users
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateUserRequest'
      responses:
        '201':
          description: User created successfully
          headers:
            Location:
              schema:
                type: string
              description: URL of the created user
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '422':
          $ref: '#/components/responses/ValidationError'

  /users/{userId}:
    get:
      summary: Get user by ID
      tags:
        - Users
      parameters:
        - name: userId
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        '404':
          $ref: '#/components/responses/NotFoundError'

    put:
      summary: Update user
      tags:
        - Users
      parameters:
        - name: userId
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UpdateUserRequest'
      responses:
        '200':
          description: User updated successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'

    delete:
      summary: Delete user
      tags:
        - Users
      parameters:
        - name: userId
          in: path
          required: true
          schema:
            type: integer
      responses:
        '204':
          description: User deleted successfully

components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: integer
          readOnly: true
        email:
          type: string
          format: email
        name:
          type: string
        status:
          type: string
          enum: [active, inactive, suspended]
        createdAt:
          type: string
          format: date-time
          readOnly: true
        updatedAt:
          type: string
          format: date-time
          readOnly: true

    CreateUserRequest:
      type: object
      required:
        - email
        - name
      properties:
        email:
          type: string
          format: email
        name:
          type: string
          minLength: 2
          maxLength: 100
        password:
          type: string
          format: password
          minLength: 8

    UpdateUserRequest:
      type: object
      properties:
        name:
          type: string
        status:
          type: string
          enum: [active, inactive, suspended]

    Pagination:
      type: object
      properties:
        page:
          type: integer
        limit:
          type: integer
        total:
          type: integer
        totalPages:
          type: integer

    Error:
      type: object
      properties:
        type:
          type: string
        title:
          type: string
        status:
          type: integer
        detail:
          type: string
        instance:
          type: string
        traceId:
          type: string

  responses:
    UnauthorizedError:
      description: Authentication required
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

    NotFoundError:
      description: Resource not found
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

    ValidationError:
      description: Validation failed
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

**OpenAPI 도구 (2025):**

- **Swagger UI**: 인터랙티브 API 문서
- **Redoc**: 깔끔한 문서 생성
- **Postman**: API 테스트 및 문서화
- **OpenAPI Generator**: 클라이언트/서버 코드 생성

---

## Part 2: gRPC vs REST 성능 비교

### 2-1. gRPC 개요

**gRPC (Google Remote Procedure Call):**

- Google이 개발한 고성능 RPC 프레임워크
- HTTP/2 기반
- Protocol Buffers (Protobuf) 직렬화
- 4가지 통신 패턴 지원:
  - Unary (단일 요청-응답)
  - Server Streaming
  - Client Streaming
  - Bidirectional Streaming

**gRPC 아키텍처:**

```
┌─────────────────────────────────────────────────────┐
│                   Client Application                 │
├─────────────────────────────────────────────────────┤
│         Generated Stub (from .proto)                │
├─────────────────────────────────────────────────────┤
│              gRPC Client Library                    │
│  ┌──────────────────────────────────────────────┐  │
│  │  HTTP/2 Transport                            │  │
│  │  - Multiplexing (다중화)                      │  │
│  │  - Header Compression (헤더 압축)            │  │
│  │  - Flow Control (흐름 제어)                  │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │
                      │ Protobuf Binary
                      │
┌─────────────────────▼───────────────────────────────┐
│              gRPC Server Library                    │
├─────────────────────────────────────────────────────┤
│    Generated Server Code (from .proto)              │
├─────────────────────────────────────────────────────┤
│                Server Application                    │
│         (Business Logic Implementation)             │
└─────────────────────────────────────────────────────┘
```

### 2-2. 2025 성능 벤치마크

**gRPC vs REST 성능 비교 (최신 연구):**

```
처리량 (Requests/Second):
┌──────────────────────────────────────┐
│ gRPC:      4,700 req/s    (기준)     │
│ REST/HTTP2: 3,200 req/s   (-47%)    │
│ REST/HTTP1: 1,900 req/s   (-60%)    │
└──────────────────────────────────────┘

응답 시간:
┌──────────────────────────────────────┐
│ gRPC 단순 CRUD:     12ms             │
│ REST 단순 CRUD:     22ms (+45%)      │
│                                      │
│ gRPC 복잡 쿼리:     45ms             │
│ REST 복잡 쿼리:     80ms (+44%)      │
└──────────────────────────────────────┘

동시 처리 능력:
gRPC는 REST 대비 2-3배 더 많은 동시 요청 처리

메모리 사용량:
gRPC가 REST/HTTP2 대비 20% 낮음

페이로드 크기:
Protobuf는 JSON 대비 5-10배 작음
```

**학술적 벤치마크 (2025):**

최대 처리량 테스트에서 gRPC는 약 8,700 req/s를 처리했으며, 이는 JSON/HTTP REST의 약 2.5배입니다.

**페이로드 크기에 따른 성능 차이:**

```
작은 페이로드 (< 1KB):
- gRPC: 평균 5ms
- REST: 평균 8ms
- 차이: 37%

중간 페이로드 (1-10KB):
- gRPC: 평균 15ms
- REST: 평균 30ms
- 차이: 50%

큰 페이로드 (> 10KB):
- gRPC: 평균 45ms
- REST: 평균 120ms
- 차이: 63%

결론: 페이로드가 클수록 gRPC의 이점이 커짐
```

### 2-3. Protocol Buffers vs JSON

**Protobuf 정의 예제:**

```protobuf
// user.proto
syntax = "proto3";

package user;

// 메시지 정의
message User {
  int32 id = 1;
  string email = 2;
  string name = 3;
  UserStatus status = 4;
  google.protobuf.Timestamp created_at = 5;
}

enum UserStatus {
  UNKNOWN = 0;
  ACTIVE = 1;
  INACTIVE = 2;
  SUSPENDED = 3;
}

// 서비스 정의
service UserService {
  // Unary RPC
  rpc GetUser(GetUserRequest) returns (User);

  // Server Streaming
  rpc ListUsers(ListUsersRequest) returns (stream User);

  // Client Streaming
  rpc CreateUsers(stream CreateUserRequest) returns (CreateUsersResponse);

  // Bidirectional Streaming
  rpc SyncUsers(stream User) returns (stream SyncResponse);
}

message GetUserRequest {
  int32 id = 1;
}

message ListUsersRequest {
  int32 page = 1;
  int32 limit = 2;
  UserStatus status = 3;
}

message CreateUserRequest {
  string email = 1;
  string name = 2;
  string password = 3;
}

message CreateUsersResponse {
  int32 count = 1;
  repeated int32 ids = 2;
}

message SyncResponse {
  bool success = 1;
  string message = 2;
}
```

**크기 비교:**

```
동일한 User 객체:

JSON (169 bytes):
{
  "id": 12345,
  "email": "user@example.com",
  "name": "John Doe",
  "status": "ACTIVE",
  "created_at": "2025-01-15T10:30:00Z"
}

Protobuf (약 30-40 bytes):
Binary encoding, 약 75-80% 작음

gzip 압축 후:
- JSON: 약 90 bytes
- Protobuf: 약 25 bytes
```

### 2-4. gRPC 서버 구현 (Go 예제)

```go
// server.go
package main

import (
    "context"
    "log"
    "net"
    "time"

    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    pb "example.com/user/proto"
)

type userServer struct {
    pb.UnimplementedUserServiceServer
    users map[int32]*pb.User
}

func newServer() *userServer {
    return &userServer{
        users: make(map[int32]*pb.User),
    }
}

// Unary RPC
func (s *userServer) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    log.Printf("GetUser called with ID: %d", req.Id)

    user, exists := s.users[req.Id]
    if !exists {
        return nil, status.Errorf(codes.NotFound, "user not found: %d", req.Id)
    }

    return user, nil
}

// Server Streaming RPC
func (s *userServer) ListUsers(req *pb.ListUsersRequest, stream pb.UserService_ListUsersServer) error {
    log.Printf("ListUsers called with page=%d, limit=%d", req.Page, req.Limit)

    count := 0
    for _, user := range s.users {
        // 필터링
        if req.Status != pb.UserStatus_UNKNOWN && user.Status != req.Status {
            continue
        }

        // 스트리밍 전송
        if err := stream.Send(user); err != nil {
            return err
        }

        count++
        if count >= int(req.Limit) {
            break
        }

        // 시뮬레이션: 실시간 스트리밍
        time.Sleep(100 * time.Millisecond)
    }

    return nil
}

// Client Streaming RPC
func (s *userServer) CreateUsers(stream pb.UserService_CreateUsersServer) error {
    log.Println("CreateUsers called (client streaming)")

    var ids []int32
    count := int32(0)

    for {
        req, err := stream.Recv()
        if err == io.EOF {
            // 클라이언트가 전송 완료
            return stream.SendAndClose(&pb.CreateUsersResponse{
                Count: count,
                Ids:   ids,
            })
        }
        if err != nil {
            return err
        }

        // 사용자 생성
        id := int32(len(s.users) + 1)
        user := &pb.User{
            Id:    id,
            Email: req.Email,
            Name:  req.Name,
            Status: pb.UserStatus_ACTIVE,
        }

        s.users[id] = user
        ids = append(ids, id)
        count++

        log.Printf("Created user: %s (%d)", user.Name, id)
    }
}

// Bidirectional Streaming RPC
func (s *userServer) SyncUsers(stream pb.UserService_SyncUsersServer) error {
    log.Println("SyncUsers called (bidirectional streaming)")

    for {
        user, err := stream.Recv()
        if err == io.EOF {
            return nil
        }
        if err != nil {
            return err
        }

        // 사용자 동기화
        s.users[user.Id] = user

        // 즉시 응답
        resp := &pb.SyncResponse{
            Success: true,
            Message: fmt.Sprintf("Synced user %d", user.Id),
        }

        if err := stream.Send(resp); err != nil {
            return err
        }
    }
}

func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("failed to listen: %v", err)
    }

    // gRPC 서버 생성
    s := grpc.NewServer(
        grpc.MaxRecvMsgSize(10 * 1024 * 1024), // 10MB
        grpc.MaxSendMsgSize(10 * 1024 * 1024),
    )

    pb.RegisterUserServiceServer(s, newServer())

    log.Println("gRPC server listening on :50051")
    if err := s.Serve(lis); err != nil {
        log.Fatalf("failed to serve: %v", err)
    }
}
```

**gRPC 클라이언트 구현:**

```go
// client.go
package main

import (
    "context"
    "io"
    "log"
    "time"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"
    pb "example.com/user/proto"
)

func main() {
    // 서버 연결
    conn, err := grpc.Dial("localhost:50051",
        grpc.WithTransportCredentials(insecure.NewCredentials()),
    )
    if err != nil {
        log.Fatalf("did not connect: %v", err)
    }
    defer conn.Close()

    client := pb.NewUserServiceClient(conn)
    ctx := context.Background()

    // 1. Unary RPC
    log.Println("=== Unary RPC ===")
    user, err := client.GetUser(ctx, &pb.GetUserRequest{Id: 1})
    if err != nil {
        log.Printf("GetUser failed: %v", err)
    } else {
        log.Printf("Got user: %+v", user)
    }

    // 2. Server Streaming RPC
    log.Println("\n=== Server Streaming RPC ===")
    stream, err := client.ListUsers(ctx, &pb.ListUsersRequest{
        Page:   1,
        Limit:  10,
        Status: pb.UserStatus_ACTIVE,
    })
    if err != nil {
        log.Fatalf("ListUsers failed: %v", err)
    }

    for {
        user, err := stream.Recv()
        if err == io.EOF {
            break
        }
        if err != nil {
            log.Fatalf("stream error: %v", err)
        }
        log.Printf("Received user: %s", user.Name)
    }

    // 3. Client Streaming RPC
    log.Println("\n=== Client Streaming RPC ===")
    createStream, err := client.CreateUsers(ctx)
    if err != nil {
        log.Fatalf("CreateUsers failed: %v", err)
    }

    users := []struct {
        email string
        name  string
    }{
        {"alice@example.com", "Alice"},
        {"bob@example.com", "Bob"},
        {"carol@example.com", "Carol"},
    }

    for _, u := range users {
        req := &pb.CreateUserRequest{
            Email: u.email,
            Name:  u.name,
        }
        if err := createStream.Send(req); err != nil {
            log.Fatalf("send error: %v", err)
        }
        log.Printf("Sent user: %s", u.name)
        time.Sleep(500 * time.Millisecond)
    }

    resp, err := createStream.CloseAndRecv()
    if err != nil {
        log.Fatalf("CloseAndRecv error: %v", err)
    }
    log.Printf("Created %d users: %v", resp.Count, resp.Ids)
}
```

### 2-5. REST vs gRPC 선택 가이드

**REST를 선택해야 하는 경우:**

- 공개 API (Public API)
- 브라우저 클라이언트
- 간단한 CRUD 작업
- 캐싱이 중요한 경우
- 기존 인프라 (HTTP/1.1)와의 호환성

**gRPC를 선택해야 하는 경우:**

- 마이크로서비스 간 내부 통신
- 실시간 양방향 스트리밍 필요
- 높은 처리량 및 낮은 지연시간 요구
- 큰 데이터 전송 (Protobuf 효율성)
- Polyglot 환경 (다양한 언어 지원)

**하이브리드 접근법 (2025 트렌드):**

```
┌─────────────────────────────────────┐
│      Public Clients                 │
│   (Web, Mobile, 3rd Party)          │
└──────────────┬──────────────────────┘
               │ REST/HTTP
               │
┌──────────────▼──────────────────────┐
│        API Gateway                  │
│    (REST → gRPC 변환)                │
└──────────────┬──────────────────────┘
               │ gRPC
               │
┌──────────────▼──────────────────────┐
│      Microservices                  │
│  (Service A ←gRPC→ Service B)       │
└─────────────────────────────────────┘

장점:
- 외부에는 REST의 단순성
- 내부에는 gRPC의 성능
```

---

## Part 3: API Gateway 패턴

### 3-1. API Gateway 개요

**API Gateway의 역할:**

```
┌──────────────────────────────────────────────┐
│            API Gateway                       │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │ Request Routing (요청 라우팅)           │ │
│  ├────────────────────────────────────────┤ │
│  │ Authentication (인증)                   │ │
│  ├────────────────────────────────────────┤ │
│  │ Authorization (인가)                    │ │
│  ├────────────────────────────────────────┤ │
│  │ Rate Limiting (속도 제한)               │ │
│  ├────────────────────────────────────────┤ │
│  │ Request/Response Transformation         │ │
│  ├────────────────────────────────────────┤ │
│  │ Protocol Translation (REST↔gRPC)        │ │
│  ├────────────────────────────────────────┤ │
│  │ Load Balancing (로드 밸런싱)            │ │
│  ├────────────────────────────────────────┤ │
│  │ Caching (캐싱)                          │ │
│  ├────────────────────────────────────────┤ │
│  │ Logging & Monitoring                   │ │
│  ├────────────────────────────────────────┤ │
│  │ Circuit Breaking (서킷 브레이커)        │ │
│  └────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

### 3-2. Kong Gateway (2025)

**Kong 아키텍처:**

```
Client Request
      │
      ▼
┌─────────────────────────────────────┐
│        Kong Gateway                 │
│  ┌───────────────────────────────┐  │
│  │  Request Phase                │  │
│  │  - Routing                    │  │
│  │  - Plugins (Authentication)   │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Upstream                     │  │
│  │  - Load Balancing             │  │
│  │  - Health Checks              │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Response Phase               │  │
│  │  - Plugins (Rate Limiting)    │  │
│  │  - Transformation             │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
      │
      ▼
Upstream Services
```

**Kong Rate Limiting 설정 (2025):**

```bash
# Kong Gateway 설치 (Kubernetes)
kubectl create namespace kong
helm repo add kong https://charts.konghq.com
helm install kong kong/kong -n kong

# Service 생성
curl -i -X POST http://localhost:8001/services \
  --data name=user-service \
  --data url='http://user-service:8080'

# Route 생성
curl -i -X POST http://localhost:8001/services/user-service/routes \
  --data 'paths[]=/users' \
  --data name=user-route

# Rate Limiting 플러그인 활성화 (Token Bucket 알고리즘)
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data name=rate-limiting \
  --data config.minute=5000 \
  --data config.policy=redis \
  --data config.redis_host=redis \
  --data config.redis_port=6379

# Response Rate Limiting (출력 대역폭 제한)
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data name=response-ratelimiting \
  --data config.limits.sms.minute=20

# Key Auth 플러그인
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data name=key-auth

# Consumer 생성
curl -i -X POST http://localhost:8001/consumers \
  --data username=mobile-app

# API Key 생성
curl -i -X POST http://localhost:8001/consumers/mobile-app/key-auth \
  --data key=secret-api-key-12345
```

**Kong 플러그인 체인 (2025 실무 사례):**

```yaml
# kong-plugins.yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-by-device
plugin: rate-limiting
config:
  minute: 5000
  policy: redis
  redis_host: redis
  redis_port: 6379
  limit_by: consumer
---
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: request-transformer
plugin: request-transformer
config:
  add:
    headers:
      - "X-Gateway:Kong"
      - "X-Request-ID:$(uuid)"
---
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: correlation-id
plugin: correlation-id
config:
  header_name: X-Request-ID
  generator: uuid
---
apiVersion: configuration.konghq.com/v1
kind: KongIngress
metadata:
  name: user-service-ingress
route:
  plugins:
    - rate-limit-by-device
    - correlation-id
    - request-transformer
```

**2025 실무 사례: Agora Systems**

Q1 2025에 Agora Systems는 Kong을 Kubernetes의 중앙 API Gateway로 채택했습니다:

- 50개 이상의 라우트 설정
- 가중치 기반 라운드 로빈 로드 밸런싱
- Device ID당 5000 RPS Rate Limiting (Token Bucket)
- 결과: 무효 요청 85% 감소

### 3-3. Envoy Gateway (2025)

**Envoy 특징:**

- C++로 작성된 고성능 프록시
- Service Mesh (Istio, Linkerd)의 데이터 플레인
- L3/L4 + L7 프로토콜 지원
- 동적 설정 (xDS API)

**Envoy Local Rate Limiting:**

```yaml
# envoy-ratelimit.yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: rate-limit-policy
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: user-route
  rateLimit:
    type: Local
    local:
      rules:
        - clientSelectors:
          - headers:
            - name: x-user-id
              type: Distinct
          limit:
            requests: 100
            unit: Minute
        - limit:
            requests: 1000
            unit: Second
```

**Envoy Global Rate Limiting (Redis 백엔드):**

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: global-rate-limit
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: api-gateway
  rateLimit:
    type: Global
    global:
      rules:
        - clientSelectors:
          - headers:
            - name: x-api-key
              type: Distinct
          limit:
            requests: 10000
            unit: Hour
```

**Envoy vs Kong 비교 (2025):**

| 특성 | Kong | Envoy Gateway |
|------|------|---------------|
| **성능** | 높음 | 매우 높음 (C++) |
| **플러그인** | 50+ 공식 플러그인 | 제한적 (xDS 기반) |
| **설정 복잡도** | 낮음 | 높음 |
| **Service Mesh** | 제한적 | 네이티브 (Istio) |
| **Kubernetes 통합** | 우수 | 매우 우수 |
| **오픈소스** | Yes (Kong OSS) | Yes |
| **상용 지원** | Kong Enterprise | Envoy Proxy (CNCF) |

### 3-4. Rate Limiting 알고리즘

**Token Bucket (가장 널리 사용):**

```python
import time
from threading import Lock

class TokenBucket:
    def __init__(self, capacity, refill_rate):
        """
        capacity: 버킷 최대 용량 (토큰 수)
        refill_rate: 초당 추가되는 토큰 수
        """
        self.capacity = capacity
        self.tokens = capacity
        self.refill_rate = refill_rate
        self.last_refill = time.time()
        self.lock = Lock()

    def consume(self, tokens=1):
        """토큰 소비 시도"""
        with self.lock:
            # 토큰 리필
            now = time.time()
            elapsed = now - self.last_refill
            refill = elapsed * self.refill_rate

            self.tokens = min(self.capacity, self.tokens + refill)
            self.last_refill = now

            # 토큰 소비
            if self.tokens >= tokens:
                self.tokens -= tokens
                return True
            else:
                return False

# 사용 예제
bucket = TokenBucket(capacity=100, refill_rate=10)  # 100개 용량, 초당 10개 리필

for i in range(150):
    if bucket.consume():
        print(f"Request {i+1}: Allowed")
    else:
        print(f"Request {i+1}: Rate Limited")
    time.sleep(0.05)  # 50ms 간격
```

**Leaky Bucket:**

```python
import time
from collections import deque
from threading import Lock

class LeakyBucket:
    def __init__(self, capacity, leak_rate):
        """
        capacity: 버킷 최대 용량
        leak_rate: 초당 처리(누출) 속도
        """
        self.capacity = capacity
        self.leak_rate = leak_rate
        self.queue = deque()
        self.last_leak = time.time()
        self.lock = Lock()

    def add_request(self):
        """요청 추가"""
        with self.lock:
            # 누출 처리
            now = time.time()
            elapsed = now - self.last_leak
            leak_count = int(elapsed * self.leak_rate)

            for _ in range(min(leak_count, len(self.queue))):
                self.queue.popleft()

            self.last_leak = now

            # 용량 체크
            if len(self.queue) < self.capacity:
                self.queue.append(now)
                return True
            else:
                return False

# 사용 예제
bucket = LeakyBucket(capacity=50, leak_rate=5)  # 50개 용량, 초당 5개 처리
```

**Fixed Window:**

```python
import time
from collections import defaultdict
from threading import Lock

class FixedWindow:
    def __init__(self, limit, window_size=60):
        """
        limit: 윈도우당 최대 요청 수
        window_size: 윈도우 크기 (초)
        """
        self.limit = limit
        self.window_size = window_size
        self.windows = defaultdict(int)
        self.lock = Lock()

    def allow_request(self, key):
        """요청 허용 여부 판단"""
        with self.lock:
            now = time.time()
            window = int(now / self.window_size)

            # 이전 윈도우 정리
            old_windows = [w for w in self.windows.keys() if w < window - 1]
            for w in old_windows:
                del self.windows[w]

            # 현재 윈도우 카운트
            if self.windows[window] < self.limit:
                self.windows[window] += 1
                return True
            else:
                return False

# 사용 예제
limiter = FixedWindow(limit=100, window_size=60)  # 분당 100개

for i in range(150):
    if limiter.allow_request("user_123"):
        print(f"Request {i+1}: Allowed")
    else:
        print(f"Request {i+1}: Rate Limited")
```

**Sliding Window Log:**

```python
import time
from collections import deque
from threading import Lock

class SlidingWindowLog:
    def __init__(self, limit, window_size=60):
        """
        limit: 윈도우당 최대 요청 수
        window_size: 윈도우 크기 (초)
        """
        self.limit = limit
        self.window_size = window_size
        self.logs = defaultdict(deque)
        self.lock = Lock()

    def allow_request(self, key):
        """요청 허용 여부 판단"""
        with self.lock:
            now = time.time()
            log = self.logs[key]

            # 오래된 로그 제거
            while log and log[0] < now - self.window_size:
                log.popleft()

            # 현재 요청 수 체크
            if len(log) < self.limit:
                log.append(now)
                return True
            else:
                return False

# 사용 예제
limiter = SlidingWindowLog(limit=100, window_size=60)
```

---

## Part 4: API 버저닝 전략

### 4-1. 버저닝 방법

**1. URL Path Versioning (가장 일반적):**

```
장점:
✓ 명확하고 직관적
✓ 브라우저에서 쉽게 테스트
✓ 문서화 용이
✓ 캐싱 친화적

단점:
✗ URL 증가
✗ 라우팅 복잡도 증가

예제:
GET https://api.example.com/v1/users
GET https://api.example.com/v2/users
GET https://api.example.com/v3/users
```

**2. Header Versioning:**

```
장점:
✓ URL 깔끔함
✓ 버전 로직과 라우팅 분리

단점:
✗ 브라우저 테스트 어려움
✗ 문서화 복잡
✗ 캐싱 복잡

예제:
GET https://api.example.com/users
Headers:
  Accept-Version: 1.0
  API-Version: 2.0
```

**3. Media Type Versioning (Content Negotiation):**

```
장점:
✓ RESTful 원칙에 부합
✓ 같은 리소스, 다른 표현

단점:
✗ 복잡함
✗ 클라이언트 구현 어려움

예제:
GET https://api.example.com/users
Headers:
  Accept: application/vnd.example.v2+json
```

**4. Query Parameter Versioning:**

```
장점:
✓ 구현 간단
✓ 기본 버전 제공 가능

단점:
✗ 직관적이지 않음
✗ 캐싱 복잡

예제:
GET https://api.example.com/users?version=2
GET https://api.example.com/users?api-version=v2
```

### 4-2. Semantic Versioning (2025 표준)

**Semantic Versioning 2.0 (MAJOR.MINOR.PATCH):**

```
형식: X.Y.Z

X (MAJOR): 호환되지 않는 API 변경
Y (MINOR): 하위 호환되는 기능 추가
Z (PATCH): 하위 호환되는 버그 수정

예제:
1.0.0 → 1.0.1 (버그 수정)
1.0.1 → 1.1.0 (새 기능 추가, 하위 호환)
1.1.0 → 2.0.0 (Breaking Change)
```

**Breaking Changes (MAJOR 버전 증가):**

- 엔드포인트 제거
- 필수 필드 추가
- 응답 구조 변경
- 에러 코드 변경
- 인증 방식 변경

**Non-Breaking Changes (MINOR 버전 증가):**

- 새 엔드포인트 추가
- 선택적 필드 추가
- 새 HTTP 헤더 추가
- 새 쿼리 파라미터 추가 (선택적)

**Bug Fixes (PATCH 버전 증가):**

- 버그 수정
- 성능 개선
- 문서 업데이트

### 4-3. Deprecation 전략 (2025)

**Graceful Deprecation 프로세스:**

```
Phase 1: 공지 (3-6개월 전)
├─ 문서에 Deprecated 표시
├─ 릴리스 노트 업데이트
└─ 이메일 공지

Phase 2: Deprecation 헤더 (RFC 9745)
├─ Deprecation: @1735689600 (2025-01-01)
├─ Sunset: @1748304000 (2025-05-01)
└─ Link: <https://api.example.com/v2/users>; rel="alternate"

Phase 3: Warning 응답
├─ HTTP 200 (아직 동작)
├─ X-API-Warn 헤더 추가
└─ 경고 메시지 본문 포함

Phase 4: 제한적 동작
├─ Rate Limit 감소
└─ 성능 저하 (의도적)

Phase 5: 완전 제거
└─ HTTP 410 Gone
```

**Deprecation 헤더 예제:**

```http
GET /v1/users HTTP/1.1
Host: api.example.com

HTTP/1.1 200 OK
Deprecation: @1735689600
Sunset: @1748304000
Link: <https://api.example.com/v2/users>; rel="alternate"
X-API-Warn: "This endpoint is deprecated and will be removed on 2025-05-01. Please migrate to /v2/users"
Content-Type: application/json

{
  "data": [...],
  "_meta": {
    "deprecated": true,
    "sunset": "2025-05-01T00:00:00Z",
    "migration_url": "https://docs.example.com/migration-guide"
  }
}
```

**Spring Boot API Versioning (2025):**

```java
// UserControllerV1.java
@RestController
@RequestMapping("/v1/users")
public class UserControllerV1 {

    @GetMapping
    @Deprecated
    public ResponseEntity<List<UserV1>> getUsers() {
        // Deprecation 헤더 추가
        HttpHeaders headers = new HttpHeaders();
        headers.add("Deprecation", "@1735689600");
        headers.add("Sunset", "@1748304000");
        headers.add("Link", "</v2/users>; rel=\"alternate\"");

        List<UserV1> users = userService.getAllUsersV1();
        return ResponseEntity.ok()
            .headers(headers)
            .body(users);
    }
}

// UserControllerV2.java
@RestController
@RequestMapping("/v2/users")
public class UserControllerV2 {

    @GetMapping
    public ResponseEntity<Page<UserV2>> getUsers(
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size
    ) {
        Page<UserV2> users = userService.getAllUsersV2(page, size);
        return ResponseEntity.ok(users);
    }
}
```

### 4-4. 버전 간 변환 레이어

**API Gateway에서 버전 변환:**

```python
# version_adapter.py - FastAPI 예제
from fastapi import FastAPI, Request, Header
from typing import Optional

app = FastAPI()

class VersionAdapter:
    """API 버전 간 변환"""

    @staticmethod
    def v1_to_v2_user(user_v1: dict) -> dict:
        """V1 사용자를 V2 형식으로 변환"""
        return {
            "id": user_v1["id"],
            "profile": {
                "email": user_v1["email"],
                "full_name": user_v1["name"],  # V1의 name → V2의 full_name
                "display_name": user_v1["name"].split()[0]  # 새 필드
            },
            "status": {
                "value": user_v1["status"],
                "updated_at": user_v1.get("updated_at", "")  # 새 필드
            },
            "created_at": user_v1["created_at"],
            "metadata": {}  # V2의 새 필드
        }

    @staticmethod
    def v2_to_v1_user(user_v2: dict) -> dict:
        """V2 사용자를 V1 형식으로 변환"""
        return {
            "id": user_v2["id"],
            "email": user_v2["profile"]["email"],
            "name": user_v2["profile"]["full_name"],
            "status": user_v2["status"]["value"],
            "created_at": user_v2["created_at"]
        }

@app.get("/users")
async def get_users(
    accept_version: Optional[str] = Header(None, alias="Accept-Version")
):
    """버전 협상을 통한 사용자 목록 조회"""

    # 실제 데이터는 V2 형식으로 저장
    users_v2 = get_users_from_db()

    # 클라이언트 버전에 따라 변환
    if accept_version == "1.0":
        users_v1 = [VersionAdapter.v2_to_v1_user(u) for u in users_v2]
        return {
            "data": users_v1,
            "_meta": {
                "version": "1.0",
                "deprecated": True,
                "sunset": "2025-05-01T00:00:00Z"
            }
        }
    else:
        return {
            "data": users_v2,
            "pagination": {"page": 1, "limit": 20},
            "_meta": {"version": "2.0"}
        }
```

---

## Part 5: API 성능 최적화

### 5-1. HTTP 캐싱

**Cache-Control 헤더 (2025 Best Practices):**

```http
# 공개 리소스, 1시간 캐싱
Cache-Control: public, max-age=3600

# 사용자별 데이터, CDN 캐싱 금지
Cache-Control: private, max-age=300

# 절대 캐싱 금지 (민감한 데이터)
Cache-Control: no-store

# 재검증 필요 (ETag 사용)
Cache-Control: no-cache, must-revalidate

# CDN에서 1일, 브라우저에서 1시간
Cache-Control: public, max-age=3600, s-maxage=86400

# Stale-while-revalidate (2025 권장)
Cache-Control: max-age=3600, stale-while-revalidate=86400
```

**ETag를 활용한 조건부 요청:**

```python
# FastAPI ETag 예제
from fastapi import FastAPI, Response, Request, status
import hashlib
import json

app = FastAPI()

@app.get("/users/{user_id}")
async def get_user(user_id: int, request: Request, response: Response):
    user = get_user_from_db(user_id)

    if not user:
        return Response(status_code=status.HTTP_404_NOT_FOUND)

    # ETag 생성 (콘텐츠 해시)
    user_json = json.dumps(user, sort_keys=True)
    etag = hashlib.md5(user_json.encode()).hexdigest()

    # If-None-Match 헤더 확인
    if_none_match = request.headers.get("if-none-match")

    if if_none_match == f'"{etag}"':
        # 변경 없음
        return Response(status_code=status.HTTP_304_NOT_MODIFIED)

    # 변경됨, ETag 포함하여 반환
    response.headers["ETag"] = f'"{etag}"'
    response.headers["Cache-Control"] = "private, max-age=300"

    return user
```

**Last-Modified 헤더:**

```python
from datetime import datetime
from fastapi import FastAPI, Response, Request, status

@app.get("/posts/{post_id}")
async def get_post(post_id: int, request: Request, response: Response):
    post = get_post_from_db(post_id)

    if not post:
        return Response(status_code=status.HTTP_404_NOT_FOUND)

    last_modified = post["updated_at"]  # datetime 객체

    # If-Modified-Since 헤더 확인
    if_modified_since = request.headers.get("if-modified-since")

    if if_modified_since:
        ims_date = datetime.strptime(if_modified_since, "%a, %d %b %Y %H:%M:%S GMT")
        if last_modified <= ims_date:
            return Response(status_code=status.HTTP_304_NOT_MODIFIED)

    # Last-Modified 헤더 설정
    response.headers["Last-Modified"] = last_modified.strftime("%a, %d %b %Y %H:%M:%S GMT")
    response.headers["Cache-Control"] = "public, max-age=600"

    return post
```

### 5-2. 응답 압축

**Gzip/Brotli 압축:**

```python
# FastAPI 압축 미들웨어
from fastapi import FastAPI
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Gzip 압축 (최소 500 bytes)
app.add_middleware(GZipMiddleware, minimum_size=500)

@app.get("/large-data")
async def get_large_data():
    # 큰 응답 데이터
    data = [{"id": i, "name": f"Item {i}"} for i in range(10000)]
    return {"data": data}
```

**압축 효율 비교 (2025):**

```
100KB JSON 응답:
┌─────────────────────────────────────┐
│ 압축 없음:     100 KB               │
│ Gzip:           15 KB (-85%)        │
│ Brotli:         12 KB (-88%)        │
└─────────────────────────────────────┘

Brotli 장점:
- Gzip보다 15-20% 더 작음
- 브라우저 지원 우수 (2025)
- CPU 사용량 Gzip과 유사
```

**Nginx Brotli 설정:**

```nginx
# nginx.conf
http {
    # Gzip 설정
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Brotli 설정 (모듈 필요)
    brotli on;
    brotli_comp_level 6;
    brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
```

### 5-3. 데이터베이스 쿼리 최적화

**N+1 쿼리 문제 해결:**

```python
# 나쁜 예: N+1 쿼리
@app.get("/users")
async def get_users_bad():
    users = db.query(User).all()  # 1 쿼리

    result = []
    for user in users:
        posts = db.query(Post).filter(Post.user_id == user.id).all()  # N 쿼리
        result.append({
            "user": user,
            "posts": posts
        })

    return result

# 좋은 예: Eager Loading
from sqlalchemy.orm import joinedload

@app.get("/users")
async def get_users_good():
    users = db.query(User).options(joinedload(User.posts)).all()  # 1 쿼리 (JOIN)

    return [
        {
            "user": user,
            "posts": user.posts
        }
        for user in users
    ]
```

**DataLoader 패턴 (GraphQL 스타일):**

```python
from collections import defaultdict
from typing import List, Dict

class UserLoader:
    def __init__(self):
        self.cache = {}
        self.queue = []

    async def load(self, user_id: int):
        """사용자 로드 (배치 처리)"""
        if user_id in self.cache:
            return self.cache[user_id]

        self.queue.append(user_id)
        return await self._flush()

    async def _flush(self):
        """큐의 모든 ID를 한 번에 조회"""
        if not self.queue:
            return

        user_ids = self.queue
        self.queue = []

        # 한 번의 쿼리로 모든 사용자 조회
        users = db.query(User).filter(User.id.in_(user_ids)).all()

        for user in users:
            self.cache[user.id] = user

        return users
```

### 5-4. Redis 캐싱

**Redis를 활용한 API 응답 캐싱:**

```python
# FastAPI + Redis 캐싱
from fastapi import FastAPI
import redis
import json
from functools import wraps

app = FastAPI()
redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)

def cache_response(expiration=300):
    """API 응답 캐싱 데코레이터"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # 캐시 키 생성
            cache_key = f"api:{func.__name__}:{str(args)}:{str(kwargs)}"

            # 캐시 확인
            cached = redis_client.get(cache_key)
            if cached:
                return json.loads(cached)

            # 실행 및 캐싱
            result = await func(*args, **kwargs)
            redis_client.setex(cache_key, expiration, json.dumps(result))

            return result

        return wrapper
    return decorator

@app.get("/expensive-query")
@cache_response(expiration=600)  # 10분 캐싱
async def expensive_query():
    # 무거운 쿼리
    result = perform_expensive_database_query()
    return result
```

**캐시 무효화 전략:**

```python
class CacheManager:
    def __init__(self, redis_client):
        self.redis = redis_client

    def invalidate_user(self, user_id: int):
        """사용자 관련 캐시 무효화"""
        pattern = f"api:*:user_id={user_id}*"
        keys = self.redis.keys(pattern)
        if keys:
            self.redis.delete(*keys)

    def invalidate_pattern(self, pattern: str):
        """패턴 기반 캐시 무효화"""
        keys = self.redis.keys(pattern)
        if keys:
            self.redis.delete(*keys)

# 사용 예제
cache_manager = CacheManager(redis_client)

@app.put("/users/{user_id}")
async def update_user(user_id: int, user_data: dict):
    # 사용자 업데이트
    update_user_in_db(user_id, user_data)

    # 관련 캐시 무효화
    cache_manager.invalidate_user(user_id)

    return {"status": "updated"}
```

---

## 🛠️ 실습 가이드

### 실습 1: RESTful API 구현 (FastAPI)

**목표**: OpenAPI 3.2 스펙을 준수하는 User Management API 구현

```python
# main.py
from fastapi import FastAPI, HTTPException, status, Header, Response
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime
import uvicorn

app = FastAPI(
    title="User Management API",
    version="1.0.0",
    description="RESTful API for user management",
    docs_url="/docs",
    redoc_url="/redoc"
)

# 모델
class UserCreate(BaseModel):
    email: EmailStr
    name: str
    password: str

class UserUpdate(BaseModel):
    name: Optional[str] = None
    status: Optional[str] = None

class User(BaseModel):
    id: int
    email: str
    name: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

# 인메모리 DB (실습용)
users_db = {}
user_id_counter = 1

# 엔드포인트
@app.get("/users", response_model=List[User], tags=["Users"])
async def list_users(
    page: int = 1,
    limit: int = 20,
    status: Optional[str] = None
):
    """사용자 목록 조회 (페이지네이션)"""
    filtered_users = [
        u for u in users_db.values()
        if status is None or u['status'] == status
    ]

    start = (page - 1) * limit
    end = start + limit

    return filtered_users[start:end]

@app.post("/users", response_model=User, status_code=status.HTTP_201_CREATED, tags=["Users"])
async def create_user(user: UserCreate, response: Response):
    """사용자 생성"""
    global user_id_counter

    # 이메일 중복 체크
    if any(u['email'] == user.email for u in users_db.values()):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already exists"
        )

    new_user = {
        "id": user_id_counter,
        "email": user.email,
        "name": user.name,
        "status": "active",
        "created_at": datetime.now()
    }

    users_db[user_id_counter] = new_user
    response.headers["Location"] = f"/users/{user_id_counter}"

    user_id_counter += 1

    return new_user

@app.get("/users/{user_id}", response_model=User, tags=["Users"])
async def get_user(user_id: int):
    """사용자 조회"""
    if user_id not in users_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User {user_id} not found"
        )

    return users_db[user_id]

@app.put("/users/{user_id}", response_model=User, tags=["Users"])
async def update_user(user_id: int, user_update: UserUpdate):
    """사용자 업데이트"""
    if user_id not in users_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User {user_id} not found"
        )

    user = users_db[user_id]

    if user_update.name:
        user['name'] = user_update.name
    if user_update.status:
        user['status'] = user_update.status

    return user

@app.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["Users"])
async def delete_user(user_id: int):
    """사용자 삭제"""
    if user_id not in users_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User {user_id} not found"
        )

    del users_db[user_id]

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

**실행 및 테스트:**

```bash
# 실행
python main.py

# Swagger UI 접속
open http://localhost:8000/docs

# cURL 테스트
# 사용자 생성
curl -X POST http://localhost:8000/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","name":"Test User","password":"secret123"}'

# 사용자 목록
curl http://localhost:8000/users?page=1&limit=10

# 사용자 조회
curl http://localhost:8000/users/1

# 사용자 업데이트
curl -X PUT http://localhost:8000/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Name"}'

# 사용자 삭제
curl -X DELETE http://localhost:8000/users/1
```

### 실습 2: gRPC 서비스 구현 및 성능 벤치마크

**목표**: REST와 gRPC 성능 비교

**프로토콜 정의 (user.proto):**

```protobuf
syntax = "proto3";
package user;
option go_package = "github.com/example/user/proto";

service UserService {
  rpc GetUser(GetUserRequest) returns (User);
  rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
  rpc CreateUser(CreateUserRequest) returns (User);
}

message User {
  int32 id = 1;
  string email = 2;
  string name = 3;
  string status = 4;
}

message GetUserRequest {
  int32 id = 1;
}

message ListUsersRequest {
  int32 page = 1;
  int32 limit = 2;
}

message ListUsersResponse {
  repeated User users = 1;
  int32 total = 2;
}

message CreateUserRequest {
  string email = 1;
  string name = 2;
}
```

**gRPC 서버 (Go):**

```go
// server.go
package main

import (
    "context"
    "log"
    "net"

    "google.golang.org/grpc"
    pb "github.com/example/user/proto"
)

type userServer struct {
    pb.UnimplementedUserServiceServer
    users map[int32]*pb.User
}

func (s *userServer) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    user, exists := s.users[req.Id]
    if !exists {
        return nil, grpc.Errorf(codes.NotFound, "user not found")
    }
    return user, nil
}

func (s *userServer) ListUsers(ctx context.Context, req *pb.ListUsersRequest) (*pb.ListUsersResponse, error) {
    var users []*pb.User
    for _, u := range s.users {
        users = append(users, u)
    }

    return &pb.ListUsersResponse{
        Users: users,
        Total: int32(len(users)),
    }, nil
}

func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("failed to listen: %v", err)
    }

    s := grpc.NewServer()
    pb.RegisterUserServiceServer(s, &userServer{users: make(map[int32]*pb.User)})

    log.Println("gRPC server listening on :50051")
    if err := s.Serve(lis); err != nil {
        log.Fatalf("failed to serve: %v", err)
    }
}
```

**벤치마크 스크립트:**

```python
# benchmark.py
import time
import requests
import grpc
import statistics
from concurrent.futures import ThreadPoolExecutor

# gRPC 클라이언트 import (생성된 코드)
import user_pb2
import user_pb2_grpc

def benchmark_rest(url, num_requests=1000, concurrency=10):
    """REST API 벤치마크"""
    times = []

    def make_request():
        start = time.time()
        response = requests.get(url)
        elapsed = time.time() - start
        return elapsed

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        times = list(executor.map(lambda _: make_request(), range(num_requests)))

    return {
        "total_requests": num_requests,
        "avg_time": statistics.mean(times),
        "median_time": statistics.median(times),
        "p95_time": statistics.quantiles(times, n=20)[18],
        "p99_time": statistics.quantiles(times, n=100)[98],
        "throughput": num_requests / sum(times)
    }

def benchmark_grpc(host, port, num_requests=1000, concurrency=10):
    """gRPC 벤치마크"""
    times = []

    def make_request():
        with grpc.insecure_channel(f'{host}:{port}') as channel:
            stub = user_pb2_grpc.UserServiceStub(channel)
            start = time.time()
            response = stub.GetUser(user_pb2.GetUserRequest(id=1))
            elapsed = time.time() - start
            return elapsed

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        times = list(executor.map(lambda _: make_request(), range(num_requests)))

    return {
        "total_requests": num_requests,
        "avg_time": statistics.mean(times),
        "median_time": statistics.median(times),
        "p95_time": statistics.quantiles(times, n=20)[18],
        "p99_time": statistics.quantiles(times, n=100)[98],
        "throughput": num_requests / sum(times)
    }

# 실행
print("Benchmarking REST API...")
rest_results = benchmark_rest("http://localhost:8000/users/1")

print("\nBenchmarking gRPC API...")
grpc_results = benchmark_grpc("localhost", 50051)

print("\n=== Results ===")
print(f"REST - Avg: {rest_results['avg_time']*1000:.2f}ms, P95: {rest_results['p95_time']*1000:.2f}ms, Throughput: {rest_results['throughput']:.0f} req/s")
print(f"gRPC - Avg: {grpc_results['avg_time']*1000:.2f}ms, P95: {grpc_results['p95_time']*1000:.2f}ms, Throughput: {grpc_results['throughput']:.0f} req/s")
print(f"\ngRPC is {(rest_results['avg_time'] / grpc_results['avg_time'] - 1) * 100:.1f}% faster")
```

### 실습 3: Kong API Gateway 설정

**목표**: Kong으로 Rate Limiting 및 인증 구현

```bash
# Kong & PostgreSQL 설치 (Docker Compose)
# docker-compose.yml
version: '3.8'
services:
  kong-database:
    image: postgres:15
    environment:
      POSTGRES_USER: kong
      POSTGRES_DB: kong
      POSTGRES_PASSWORD: kong
    ports:
      - "5432:5432"

  kong-migration:
    image: kong:3.5
    command: kong migrations bootstrap
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-database
      KONG_PG_PASSWORD: kong
    depends_on:
      - kong-database

  kong:
    image: kong:3.5
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: kong-database
      KONG_PG_PASSWORD: kong
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
      KONG_PROXY_LISTEN: 0.0.0.0:8000
    ports:
      - "8000:8000"
      - "8001:8001"
    depends_on:
      - kong-migration

# 실행
docker-compose up -d

# Service 생성
curl -i -X POST http://localhost:8001/services \
  --data name=user-service \
  --data url='http://host.docker.internal:8000'

# Route 생성
curl -i -X POST http://localhost:8001/services/user-service/routes \
  --data 'paths[]=/api/users' \
  --data name=user-route

# Rate Limiting 플러그인
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data name=rate-limiting \
  --data config.minute=100 \
  --data config.hour=1000 \
  --data config.policy=local

# Key Authentication 플러그인
curl -i -X POST http://localhost:8001/services/user-service/plugins \
  --data name=key-auth \
  --data config.key_names=apikey

# Consumer 생성
curl -i -X POST http://localhost:8001/consumers \
  --data username=test-user

# API Key 생성
curl -i -X POST http://localhost:8001/consumers/test-user/key-auth \
  --data key=my-secret-key

# 테스트
curl -H "apikey: my-secret-key" http://localhost:8000/api/users/1
```

---

## 📚 참고 자료

### 공식 문서

**REST & OpenAPI:**

- [OpenAPI Specification 3.2](https://spec.openapis.org/oas/v3.2.0)
- [RFC 7807: Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807)
- [RFC 9745: Deprecation HTTP Header Field](https://datatracker.ietf.org/doc/html/rfc9745)
- [Semantic Versioning 2.0.0](https://semver.org/)

**gRPC & Protobuf:**

- [gRPC Official Documentation](https://grpc.io/docs/)
- [Protocol Buffers Language Guide](https://protobuf.dev/programming-guides/proto3/)
- [gRPC Performance Best Practices](https://grpc.io/docs/guides/performance/)

**API Gateway:**

- [Kong Gateway Documentation](https://docs.konghq.com/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Kong Rate Limiting Plugin](https://docs.konghq.com/hub/kong-inc/rate-limiting/)

### 최신 연구 및 벤치마크 (2025)

**Performance Comparisons:**

- [gRPC vs REST in 2025: Performance Benchmarks (Markaicode)](https://markaicode.com/grpc-vs-rest-benchmarks-2025/)
- [tRPC vs gRPC vs REST: API Performance Battle 2025](https://www.metatech.dev/blog/2025-05-04-trpc-vs-grpc-vs-rest-api-performance-battle-2025)
- [Scaling up REST versus gRPC Benchmark Tests (Medium)](https://medium.com/@i.gorton/scaling-up-rest-versus-grpc-benchmark-tests-551f73ed88d4)

**API Design:**

- [API Design Best Practices in 2025 (DEV Community)](https://dev.to/cryptosandy/api-design-best-practices-in-2025-rest-graphql-and-grpc-2666)
- [MyAppAPI: API Design Best Practices 2025](https://myappapi.com/blog/api-design-best-practices-2025)
- [GraphQL vs REST API: Comparison 2025 (API7.ai)](https://api7.ai/blog/graphql-vs-rest-api-comparison-2025)

**Versioning & Deprecation:**

- [API Versioning Best Practices 2025 (DevZery)](https://www.devzery.com/post/versioning-rest-api-strategies-best-practices-2025)
- [Semantic Versioning for APIs (Zuplo)](https://zuplo.com/blog/2025/04/24/semantic-api-versioning)
- [API Versioning in Spring (Spring Blog, 2025)](https://spring.io/blog/2025/09/16/api-versioning-in-spring/)

**API Gateway:**

- [Kong Gateway in Kubernetes (2025)](https://opstree.com/blog/2025/11/18/kong-gateway-in-kubernetes/)
- [API Gateway Patterns with Kong 2025 (Johal.in)](https://johal.in/api-gateway-patterns-with-kong-routing-and-rate-limiting-for-python-microservices-in-2025/)
- [Envoy Gateway: Enterprise API Management (2025)](https://saptak.in/writing/2025/03/09/envoy-gateway)

### 도서

- **RESTful Web APIs** - Leonard Richardson, Mike Amundsen
- **Designing Web APIs** - Brenda Jin, Saurabh Sahni
- **gRPC: Up and Running** - Kasun Indrasiri, Danesh Kuruppu
- **API Design Patterns** - JJ Geewax

### 커뮤니티 및 도구

- [Postman](https://www.postman.com/)
- [Swagger/OpenAPI Tools](https://swagger.io/tools/)
- [grpcurl](https://github.com/fullstorydev/grpcurl) - gRPC CLI 도구
- [Buf](https://buf.build/) - Protobuf 도구체인
- [API Blueprint](https://apiblueprint.org/)

---

## ✅ 학습 체크리스트

### RESTful API 설계

- [ ] REST 6가지 제약조건 이해 및 설명 가능
- [ ] RESTful URL 네이밍 Best Practices 적용 경험
- [ ] HTTP 메서드 적절한 사용 (멱등성, 안전성 이해)
- [ ] HTTP 상태 코드 정확한 사용
- [ ] 페이지네이션 구현 (Offset/Cursor-based)
- [ ] 필터링, 정렬, 필드 선택 구현 경험
- [ ] RFC 7807 에러 응답 표준화 적용
- [ ] OpenAPI 3.2 스펙 작성 경험
- [ ] Swagger UI/Redoc 문서 생성 경험

### gRPC

- [ ] Protobuf 문법 이해 및 작성 가능
- [ ] gRPC 4가지 통신 패턴 이해
- [ ] gRPC 서버/클라이언트 구현 경험 (Go/Python/Java 중 하나)
- [ ] Protobuf vs JSON 성능 차이 이해
- [ ] gRPC와 REST 선택 기준 판단 가능
- [ ] 하이브리드 접근법(REST→gRPC) 설계 경험

### API Gateway

- [ ] API Gateway의 역할 및 필요성 이해
- [ ] Kong Gateway 설치 및 기본 설정 경험
- [ ] Envoy Gateway 기본 개념 이해
- [ ] Rate Limiting 알고리즘 이해 (Token Bucket, Leaky Bucket)
- [ ] Kong 플러그인 설정 경험 (Rate Limiting, Authentication)
- [ ] API Gateway를 통한 프로토콜 변환 경험

### API 버저닝

- [ ] 4가지 버저닝 방법 비교 가능
- [ ] Semantic Versioning 이해 및 적용
- [ ] Breaking vs Non-Breaking Changes 구분 가능
- [ ] Deprecation 전략 수립 및 적용 경험
- [ ] RFC 9745 Deprecation 헤더 사용 경험
- [ ] 버전 간 변환 레이어 구현 경험

### 성능 최적화

- [ ] HTTP 캐싱 (Cache-Control, ETag, Last-Modified) 이해
- [ ] 조건부 요청 (304 Not Modified) 구현 경험
- [ ] Gzip/Brotli 압축 설정 경험
- [ ] N+1 쿼리 문제 인식 및 해결 경험
- [ ] Redis를 활용한 API 응답 캐싱 경험
- [ ] 캐시 무효화 전략 구현 경험

### 종합 역량

- [ ] 대규모 트래픽 처리를 위한 API 아키텍처 설계 가능
- [ ] API 모니터링 및 메트릭 수집 경험
- [ ] API 보안 (OAuth 2.0, JWT) 적용 경험
- [ ] API 문서 자동화 파이프라인 구축 경험
- [ ] API 테스트 자동화 (Unit, Integration) 경험

---

## 🎓 다음 단계

Ch2. API 설계를 완료했다면, 다음 학습 주제로 진행하세요:

**Ch3. OpenStack 네트워킹**

- Neutron 아키텍처
- ML2 플러그인
- SDN 통합 (OVN, OVS)
- 네트워크 가상화
- 커스텀 플러그인 개발

**또는 심화 학습:**

- **GraphQL**: Schema, Resolvers, Apollo Server
- **WebSocket**: 실시간 양방향 통신
- **API Security**: OAuth 2.0, OIDC, mTLS
- **API Governance**: API Catalog, Contract Testing
- **Event-Driven API**: AsyncAPI, WebHooks, SSE

**실무 프로젝트 아이디어:**

1. **마이크로서비스 API Gateway 구축**
   - Kong/Envoy로 중앙화된 Gateway
   - Rate Limiting, Circuit Breaker
   - 인증/인가 통합
   - 모니터링 대시보드

2. **gRPC ↔ REST 프록시 서버**
   - 외부 REST, 내부 gRPC
   - Protobuf ↔ JSON 변환
   - 스트리밍 지원
   - 성능 벤치마크

3. **API 버전 관리 시스템**
   - 자동 Deprecation 헤더
   - 버전별 트래픽 분석
   - 마이그레이션 가이드 생성
   - A/B 테스트 지원

API 설계는 시스템 아키텍처의 핵심입니다. 계속해서 학습하고 실습하면서 확장 가능하고 유지보수하기 쉬운 API를 설계하는 전문가로 성장하세요!
