# 네트워킹 실습

네트워킹 기초 개념을 실습으로 익히는 과정입니다.

## 실습 목표
- 로컬 네트워크 구성 이해
- 패킷 분석 도구 사용법 익히기
- 서브넷팅 및 라우팅 실습

## 실습 환경
- 호스트: macOS (M1 Max)
- 도구: Wireshark, tcpdump, netstat

## 실습 단계

### 1. 네트워크 인터페이스 확인
```bash
# 네트워크 인터페이스 목록 확인
ifconfig
ip addr show

# 라우팅 테이블 확인
netstat -rn
ip route show
```

### 2. 패킷 캡처
```bash
# tcpdump를 사용한 패킷 캡처
sudo tcpdump -i en0 -n

# 특정 포트만 캡처
sudo tcpdump -i en0 port 80

# 파일로 저장
sudo tcpdump -i en0 -w capture.pcap
```

### 3. Wireshark를 사용한 패킷 분석
- Wireshark 설치
- 패킷 캡처 파일 분석
- 프로토콜별 필터링

## 실습 결과물
- 패킷 캡처 파일
- 분석 리포트
- 네트워크 구성도

