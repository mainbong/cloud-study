# 리눅스 VM 구축 실습

Mac M1 Max 환경에서 리눅스 VM을 구축하는 실습입니다.

## 실습 목표
- UTM/QEMU를 사용한 리눅스 VM 구축
- 리눅스 시스템 관리 기초 실습

## 실습 환경
- 호스트: macOS (M1 Max)
- 가상화 도구: UTM (QEMU 기반)
- 게스트 OS: Ubuntu 24.04.3 LTS Server

## 실습 단계

### 1. UTM 설치
```bash
# Homebrew를 통한 설치
brew install --cask utm
```

### 2. Ubuntu 이미지 다운로드
- Ubuntu 24.04.3 LTS Server ISO 다운로드
- 다운로드 링크: https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso
- 저장 위치: `~/Downloads/ubuntu-vm/ubuntu-24.04.3-live-server-amd64.iso`

### 3. VM 생성
- UTM에서 새 VM 생성
- 설정:
  - 아키텍처: ARM64
  - 메모리: 2GB 이상
  - 디스크: 20GB 이상

### 4. 리눅스 설치 및 기본 설정
- Ubuntu 설치 진행
- 사용자 계정 생성
- SSH 서버 설치 및 설정

## 실습 결과물
- VM 설정 파일
- 설치 스크립트
- 설정 문서

