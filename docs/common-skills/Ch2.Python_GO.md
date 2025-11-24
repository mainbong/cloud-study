# Ch2. 프로그래밍 언어 (Python / GO)

## 📋 개요

클라우드 서비스 개발에서 Python과 GO는 가장 널리 사용되는 프로그래밍 언어입니다. Python은 빠른 프로토타이핑과 풍부한 라이브러리 생태계로, GO는 뛰어난 동시성 처리와 성능으로 각광받고 있습니다.

### 학습 목표

이 장을 학습한 후, 다음을 할 수 있습니다:

- Python 또는 GO를 활용한 RESTful API 백엔드 설계 및 개발
- 비동기 프로그래밍을 통한 고성능 API 서버 구현
- gRPC를 사용한 마이크로서비스 간 통신 구현
- 테스트 주도 개발(TDD) 적용

---

## 🐍 Part 1: Python

### 1. Python 비동기 프로그래밍 (Asyncio)

#### Asyncio 개념

**Asyncio**는 Python 3.4부터 추가된 비동기 I/O 라이브러리로, 단일 스레드에서 동시성 코드를 작성할 수 있게 해줍니다.

**핵심 개념:**

- **Coroutine (코루틴)**: `async def`로 정의된 비동기 함수
- **Event Loop**: 비동기 작업을 관리하고 실행하는 루프
- **Task**: 이벤트 루프에서 실행되는 코루틴
- **Future**: 아직 완료되지 않은 작업의 결과

**언제 Asyncio를 사용해야 하나? (2025 Best Practice)**
- ✅ I/O 바운드 작업 (네트워크 요청, 데이터베이스 쿼리, 파일 I/O)
- ✅ 많은 수의 동시 연결 처리
- ❌ CPU 바운드 작업 (계산 집약적인 작업은 multiprocessing 사용)

#### 기본 Asyncio 예제

```python
import asyncio
import time

# 동기 방식 (순차 실행)
def sync_task(name, duration):
    print(f"{name} starting...")
    time.sleep(duration)
    print(f"{name} completed!")
    return f"Result from {name}"

# 비동기 방식 (동시 실행)
async def async_task(name, duration):
    print(f"{name} starting...")
    await asyncio.sleep(duration)  # time.sleep() 대신 asyncio.sleep() 사용!
    print(f"{name} completed!")
    return f"Result from {name}"

# 여러 작업 동시 실행
async def main():
    # 3개의 작업을 동시에 실행
    tasks = [
        async_task("Task 1", 2),
        async_task("Task 2", 1),
        async_task("Task 3", 3)
    ]

    results = await asyncio.gather(*tasks)
    print(f"All results: {results}")

# 이벤트 루프 실행 (Python 3.7+)
if __name__ == "__main__":
    start = time.time()
    asyncio.run(main())
    print(f"Total time: {time.time() - start:.2f} seconds")
    # 출력: Total time: 3.00 seconds (동기 방식이었다면 6초 소요)
```

#### 실전 Asyncio 패턴

**1. 비동기 HTTP 요청 (aiohttp):**
```python
import aiohttp
import asyncio

async def fetch_url(session, url):
    async with session.get(url) as response:
        return await response.text()

async def fetch_multiple_urls(urls):
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_url(session, url) for url in urls]
        results = await asyncio.gather(*tasks)
        return results

# 사용 예제
urls = [
    "https://api.github.com/users/python",
    "https://api.github.com/users/golang",
    "https://api.github.com/users/rust-lang"
]

results = asyncio.run(fetch_multiple_urls(urls))
```

**2. 비동기 데이터베이스 쿼리 (asyncpg):**
```python
import asyncpg
import asyncio

async def get_users():
    # PostgreSQL 연결
    conn = await asyncpg.connect(
        user='user',
        password='password',
        database='mydb',
        host='localhost'
    )

    # 쿼리 실행
    users = await conn.fetch('SELECT * FROM users WHERE active = $1', True)

    await conn.close()
    return users

# 사용 예제
users = asyncio.run(get_users())
```

**3. Producer-Consumer 패턴:**
```python
import asyncio
from asyncio import Queue

async def producer(queue: Queue, n: int):
    for i in range(n):
        await asyncio.sleep(0.1)  # 데이터 생성 시뮬레이션
        await queue.put(f"Item {i}")
        print(f"Produced: Item {i}")
    await queue.put(None)  # 종료 시그널

async def consumer(queue: Queue, name: str):
    while True:
        item = await queue.get()
        if item is None:
            queue.task_done()
            break
        await asyncio.sleep(0.2)  # 처리 시뮬레이션
        print(f"{name} consumed: {item}")
        queue.task_done()

async def main():
    queue = Queue(maxsize=10)

    # 1개의 Producer, 3개의 Consumer
    await asyncio.gather(
        producer(queue, 20),
        consumer(queue, "Consumer-1"),
        consumer(queue, "Consumer-2"),
        consumer(queue, "Consumer-3")
    )

asyncio.run(main())
```

---

### 2. FastAPI - 고성능 API 프레임워크

#### FastAPI 소개

FastAPI는 2025년 현재 Python 백엔드 개발의 Top 3 프레임워크 중 하나로, 다음과 같은 특징을 가집니다:

- **빠른 성능**: Node.js 및 Go와 비슷한 수준
- **자동 문서화**: OpenAPI (Swagger) 및 ReDoc 자동 생성
- **타입 안정성**: Python type hints 기반 검증
- **비동기 지원**: 네이티브 async/await 지원

#### 기본 FastAPI 애플리케이션

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional

app = FastAPI(
    title="My API",
    description="Cloud Service API",
    version="1.0.0"
)

# 데이터 모델 정의 (Pydantic)
class User(BaseModel):
    id: int
    name: str
    email: str
    active: bool = True

# 인메모리 데이터베이스 (예제용)
users_db = {}

# GET - 모든 사용자 조회
@app.get("/users", response_model=List[User])
async def get_users():
    return list(users_db.values())

# GET - 특정 사용자 조회
@app.get("/users/{user_id}", response_model=User)
async def get_user(user_id: int):
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    return users_db[user_id]

# POST - 사용자 생성
@app.post("/users", response_model=User, status_code=201)
async def create_user(user: User):
    if user.id in users_db:
        raise HTTPException(status_code=400, detail="User already exists")
    users_db[user.id] = user
    return user

# PUT - 사용자 업데이트
@app.put("/users/{user_id}", response_model=User)
async def update_user(user_id: int, user: User):
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    users_db[user_id] = user
    return user

# DELETE - 사용자 삭제
@app.delete("/users/{user_id}", status_code=204)
async def delete_user(user_id: int):
    if user_id not in users_db:
        raise HTTPException(status_code=404, detail="User not found")
    del users_db[user_id]
    return None

# 실행: uvicorn main:app --reload
# 문서: http://localhost:8000/docs
```

#### FastAPI Async Best Practices (2025)

**1. 언제 async def를 사용해야 하나?**

```python
# ✅ I/O 바운드 작업 - async def 사용
@app.get("/users/{user_id}")
async def get_user(user_id: int):
    # 데이터베이스 쿼리 (비동기)
    user = await db.fetch_one("SELECT * FROM users WHERE id = $1", user_id)
    return user

# ✅ CPU 바운드 작업 - 일반 def 사용 (스레드풀에서 실행됨)
@app.get("/compute")
def compute_heavy():
    result = heavy_computation()  # 계산 집약적인 작업
    return {"result": result}

# ❌ 잘못된 사용 - async def 안에서 블로킹 작업
@app.get("/wrong")
async def wrong_async():
    time.sleep(5)  # 블로킹! 다른 요청도 모두 대기하게 됨
    return {"message": "wrong"}

# ✅ 올바른 방법 - 비동기 sleep 사용
@app.get("/correct")
async def correct_async():
    await asyncio.sleep(5)  # 다른 요청은 계속 처리됨
    return {"message": "correct"}
```

**2. 비동기 데이터베이스 사용:**

```python
from databases import Database

database = Database("postgresql://user:password@localhost/dbname")

@app.on_event("startup")
async def startup():
    await database.connect()

@app.on_event("shutdown")
async def shutdown():
    await database.disconnect()

@app.get("/users")
async def get_users():
    query = "SELECT * FROM users"
    users = await database.fetch_all(query)
    return users
```

**3. BackgroundTasks 활용:**

```python
from fastapi import BackgroundTasks

def send_email(email: str, message: str):
    # 이메일 전송 로직 (시간 소요)
    print(f"Sending email to {email}: {message}")

@app.post("/users")
async def create_user(user: User, background_tasks: BackgroundTasks):
    users_db[user.id] = user

    # 백그라운드에서 이메일 전송 (응답은 즉시 반환)
    background_tasks.add_task(send_email, user.email, "Welcome!")

    return user
```

**4. 의존성 주입 (Dependency Injection):**

```python
from fastapi import Depends, Header, HTTPException

# 인증 검증 의존성
async def verify_token(authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid token")
    token = authorization.replace("Bearer ", "")
    # 토큰 검증 로직
    return token

# 데이터베이스 연결 의존성
async def get_db():
    db = Database("postgresql://...")
    await db.connect()
    try:
        yield db
    finally:
        await db.disconnect()

# 의존성 사용
@app.get("/protected")
async def protected_route(
    token: str = Depends(verify_token),
    db: Database = Depends(get_db)
):
    # token과 db를 사용한 로직
    return {"message": "Authenticated", "token": token}
```

---

### 3. Python 테스팅

#### Pytest를 사용한 테스트

```python
# test_api.py
import pytest
from fastapi.testclient import TestClient
from main import app, users_db

client = TestClient(app)

@pytest.fixture(autouse=True)
def reset_db():
    """각 테스트 전에 DB 초기화"""
    users_db.clear()
    yield
    users_db.clear()

def test_create_user():
    response = client.post(
        "/users",
        json={"id": 1, "name": "John", "email": "john@example.com"}
    )
    assert response.status_code == 201
    assert response.json()["name"] == "John"

def test_get_user():
    # 사용자 생성
    client.post(
        "/users",
        json={"id": 1, "name": "John", "email": "john@example.com"}
    )

    # 사용자 조회
    response = client.get("/users/1")
    assert response.status_code == 200
    assert response.json()["email"] == "john@example.com"

def test_user_not_found():
    response = client.get("/users/999")
    assert response.status_code == 404

@pytest.mark.asyncio
async def test_async_function():
    result = await some_async_function()
    assert result == expected_value

# 실행: pytest test_api.py -v
```

---

## 🔷 Part 2: GO

### 1. GO 기초 및 동시성

#### Goroutines - GO의 경량 스레드

Goroutine은 GO의 가장 강력한 기능 중 하나로, 수천 개의 동시 작업을 효율적으로 처리할 수 있습니다.

```go
package main

import (
    "fmt"
    "time"
)

// 일반 함수
func task(name string, duration int) {
    fmt.Printf("%s starting...\n", name)
    time.Sleep(time.Duration(duration) * time.Second)
    fmt.Printf("%s completed!\n", name)
}

func main() {
    // 동기 방식 (순차 실행)
    task("Task 1", 2)
    task("Task 2", 1)
    task("Task 3", 3)
    // 총 6초 소요

    // 비동기 방식 (Goroutine 사용)
    go task("Goroutine 1", 2)
    go task("Goroutine 2", 1)
    go task("Goroutine 3", 3)

    // 메인 함수가 종료되면 모든 goroutine이 종료되므로 대기
    time.Sleep(4 * time.Second)
    // 총 3초 소요 (가장 긴 작업의 시간)
}
```

#### Channels - Goroutine 간 통신

```go
package main

import "fmt"

func main() {
    // 채널 생성
    messages := make(chan string)

    // Goroutine에서 채널로 데이터 전송
    go func() {
        messages <- "Hello from goroutine"
    }()

    // 채널에서 데이터 수신
    msg := <-messages
    fmt.Println(msg)
}
```

**버퍼링된 채널:**
```go
// 버퍼 크기가 3인 채널
ch := make(chan int, 3)

ch <- 1
ch <- 2
ch <- 3
// 버퍼가 가득 찼으므로 다음은 블로킹됨

fmt.Println(<-ch)  // 1
fmt.Println(<-ch)  // 2
fmt.Println(<-ch)  // 3
```

**Select 문 - 여러 채널 처리:**
```go
func main() {
    ch1 := make(chan string)
    ch2 := make(chan string)

    go func() {
        time.Sleep(1 * time.Second)
        ch1 <- "from channel 1"
    }()

    go func() {
        time.Sleep(2 * time.Second)
        ch2 <- "from channel 2"
    }()

    // 여러 채널 중 먼저 준비된 것부터 처리
    for i := 0; i < 2; i++ {
        select {
        case msg1 := <-ch1:
            fmt.Println("Received:", msg1)
        case msg2 := <-ch2:
            fmt.Println("Received:", msg2)
        }
    }
}
```

#### 실전 동시성 패턴

**1. Worker Pool 패턴:**
```go
package main

import (
    "fmt"
    "time"
)

func worker(id int, jobs <-chan int, results chan<- int) {
    for job := range jobs {
        fmt.Printf("Worker %d processing job %d\n", id, job)
        time.Sleep(time.Second)  // 작업 시뮬레이션
        results <- job * 2
    }
}

func main() {
    const numJobs = 10
    const numWorkers = 3

    jobs := make(chan int, numJobs)
    results := make(chan int, numJobs)

    // Worker 풀 시작
    for w := 1; w <= numWorkers; w++ {
        go worker(w, jobs, results)
    }

    // Job 전송
    for j := 1; j <= numJobs; j++ {
        jobs <- j
    }
    close(jobs)

    // 결과 수집
    for a := 1; a <= numJobs; a++ {
        result := <-results
        fmt.Println("Result:", result)
    }
}
```

**2. Pipeline 패턴:**
```go
// 숫자 생성 스테이지
func generate(nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        for _, n := range nums {
            out <- n
        }
        close(out)
    }()
    return out
}

// 제곱 계산 스테이지
func square(in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        for n := range in {
            out <- n * n
        }
        close(out)
    }()
    return out
}

func main() {
    // 파이프라인 구성
    nums := generate(1, 2, 3, 4, 5)
    squares := square(nums)

    // 결과 출력
    for result := range squares {
        fmt.Println(result)
    }
}
```

---

### 2. GO로 RESTful API 개발

#### Gin 프레임워크

```go
package main

import (
    "net/http"
    "github.com/gin-gonic/gin"
)

type User struct {
    ID     int    `json:"id"`
    Name   string `json:"name"`
    Email  string `json:"email"`
    Active bool   `json:"active"`
}

var users = make(map[int]User)

func main() {
    router := gin.Default()

    // GET - 모든 사용자 조회
    router.GET("/users", func(c *gin.Context) {
        userList := []User{}
        for _, user := range users {
            userList = append(userList, user)
        }
        c.JSON(http.StatusOK, userList)
    })

    // GET - 특정 사용자 조회
    router.GET("/users/:id", func(c *gin.Context) {
        id := c.Param("id")
        // ID를 int로 변환하고 조회하는 로직
        c.JSON(http.StatusOK, gin.H{"message": "Get user " + id})
    })

    // POST - 사용자 생성
    router.POST("/users", func(c *gin.Context) {
        var user User
        if err := c.ShouldBindJSON(&user); err != nil {
            c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
            return
        }
        users[user.ID] = user
        c.JSON(http.StatusCreated, user)
    })

    // PUT - 사용자 업데이트
    router.PUT("/users/:id", func(c *gin.Context) {
        // 업데이트 로직
        c.JSON(http.StatusOK, gin.H{"message": "User updated"})
    })

    // DELETE - 사용자 삭제
    router.DELETE("/users/:id", func(c *gin.Context) {
        // 삭제 로직
        c.Status(http.StatusNoContent)
    })

    router.Run(":8080")
}
```

---

### 3. gRPC 서비스 개발

#### Protocol Buffers 정의

```protobuf
// user.proto
syntax = "proto3";

package user;

option go_package = "./proto";

message User {
    int32 id = 1;
    string name = 2;
    string email = 3;
    bool active = 4;
}

message GetUserRequest {
    int32 id = 1;
}

message ListUsersRequest {}

message ListUsersResponse {
    repeated User users = 1;
}

service UserService {
    rpc GetUser(GetUserRequest) returns (User);
    rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
    rpc CreateUser(User) returns (User);
}
```

#### gRPC 서버 구현

```go
package main

import (
    "context"
    "log"
    "net"

    "google.golang.org/grpc"
    pb "your-module/proto"
)

type userServer struct {
    pb.UnimplementedUserServiceServer
    users map[int32]*pb.User
}

func (s *userServer) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    user, exists := s.users[req.Id]
    if !exists {
        return nil, grpc.Errorf(grpc.Code(404), "User not found")
    }
    return user, nil
}

func (s *userServer) ListUsers(ctx context.Context, req *pb.ListUsersRequest) (*pb.ListUsersResponse, error) {
    users := []*pb.User{}
    for _, user := range s.users {
        users = append(users, user)
    }
    return &pb.ListUsersResponse{Users: users}, nil
}

func (s *userServer) CreateUser(ctx context.Context, user *pb.User) (*pb.User, error) {
    s.users[user.Id] = user
    return user, nil
}

func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("Failed to listen: %v", err)
    }

    grpcServer := grpc.NewServer()
    pb.RegisterUserServiceServer(grpcServer, &userServer{
        users: make(map[int32]*pb.User),
    })

    log.Println("gRPC server listening on :50051")
    if err := grpcServer.Serve(lis); err != nil {
        log.Fatalf("Failed to serve: %v", err)
    }
}
```

#### gRPC 클라이언트

```go
package main

import (
    "context"
    "log"

    "google.golang.org/grpc"
    pb "your-module/proto"
)

func main() {
    conn, err := grpc.Dial("localhost:50051", grpc.WithInsecure())
    if err != nil {
        log.Fatalf("Failed to connect: %v", err)
    }
    defer conn.Close()

    client := pb.NewUserServiceClient(conn)

    // 사용자 생성
    user, err := client.CreateUser(context.Background(), &pb.User{
        Id:     1,
        Name:   "John Doe",
        Email:  "john@example.com",
        Active: true,
    })
    if err != nil {
        log.Fatalf("CreateUser failed: %v", err)
    }
    log.Printf("Created user: %v", user)

    // 사용자 조회
    user, err = client.GetUser(context.Background(), &pb.GetUserRequest{Id: 1})
    if err != nil {
        log.Fatalf("GetUser failed: %v", err)
    }
    log.Printf("Retrieved user: %v", user)
}
```

#### gRPC 동시성 (2025 Best Practice)

gRPC-Go는 스레드 안전하게 설계되었습니다:

- **ClientConn**은 동시에 안전하게 접근 가능
- 각 RPC 핸들러는 자체 goroutine에서 실행됨
- 서버는 많은 수의 동시 요청을 효율적으로 처리

```go
// 동시에 여러 요청 처리
func makeConcurrentRequests(client pb.UserServiceClient) {
    const numRequests = 100

    results := make(chan *pb.User, numRequests)
    errors := make(chan error, numRequests)

    for i := 0; i < numRequests; i++ {
        go func(id int32) {
            user, err := client.GetUser(context.Background(), &pb.GetUserRequest{Id: id})
            if err != nil {
                errors <- err
                return
            }
            results <- user
        }(int32(i))
    }

    // 결과 수집
    for i := 0; i < numRequests; i++ {
        select {
        case user := <-results:
            log.Printf("Got user: %v", user)
        case err := <-errors:
            log.Printf("Error: %v", err)
        }
    }
}
```

---

### 4. GO 테스팅

```go
// user_test.go
package main

import (
    "testing"
)

func TestCreateUser(t *testing.T) {
    user := User{
        ID:     1,
        Name:   "Test User",
        Email:  "test@example.com",
        Active: true,
    }

    users[user.ID] = user

    if users[1].Name != "Test User" {
        t.Errorf("Expected 'Test User', got '%s'", users[1].Name)
    }
}

func BenchmarkCreateUser(b *testing.B) {
    for i := 0; i < b.N; i++ {
        user := User{ID: i, Name: "User", Email: "user@example.com"}
        users[user.ID] = user
    }
}

// 실행: go test -v
// 벤치마크: go test -bench=.
```

---

## 📚 참고 자료

### Python 자료

- [Python 공식 문서](https://docs.python.org/3/)
- [FastAPI 공식 문서](https://fastapi.tiangolo.com/)
- [Asyncio 공식 가이드](https://docs.python.org/3/library/asyncio.html)
- [FastAPI Best Practices (GitHub)](https://github.com/zhanymkanov/fastapi-best-practices)
- [Real Python - Async IO](https://realpython.com/async-io-python/)

### GO 자료

- [Go 공식 문서](https://go.dev/doc/)
- [Effective Go](https://go.dev/doc/effective_go)
- [Go by Example](https://gobyexample.com/)
- [gRPC-Go 공식 문서](https://grpc.io/docs/languages/go/)
- [Gin 프레임워크](https://gin-gonic.com/docs/)

### 2025년 최신 자료

- [Python Backend 2025: Asyncio & FastAPI](https://www.nucamp.co/blog/coding-bootcamp-backend-with-python-2025)
- [Coursera - Go Essentials: Concurrency, gRPC & More](https://www.coursera.org/learn/packt-go-essentials)

---

## ✅ 학습 체크리스트

### Python

- [ ] Python 기초 문법 및 객체지향 프로그래밍
- [ ] Asyncio 개념 및 기본 사용법
- [ ] FastAPI로 RESTful API 구현
- [ ] Pydantic을 사용한 데이터 검증
- [ ] 비동기 데이터베이스 연동
- [ ] Pytest를 사용한 테스트 작성

### GO

- [ ] Go 기초 문법
- [ ] Goroutine 및 Channel 사용
- [ ] 동시성 패턴 (Worker Pool, Pipeline)
- [ ] Gin을 사용한 RESTful API 구현
- [ ] Protocol Buffers 정의
- [ ] gRPC 서버/클라이언트 개발
- [ ] Go 테스팅 및 벤치마크

---

## 🎓 다음 단계

프로그래밍 언어 기초를 마스터한 후:

- [Ch3. Cloud-Native 환경](./Ch3.Cloud_Native.md)으로 진행
- 또는 [README](./README.md)로 돌아가서 학습 로드맵 확인
