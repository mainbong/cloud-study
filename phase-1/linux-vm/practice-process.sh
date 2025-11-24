#!/bin/bash
# 프로세스 및 서비스 관리 실습 스크립트

echo "=== 프로세스 및 서비스 관리 실습 ==="
echo ""

echo "1. 현재 실행 중인 프로세스 확인"
echo "--- ps aux (상위 10개) ---"
ps aux | head -11
echo ""

echo "2. 프로세스 트리 확인"
echo "--- pstree 또는 ps -ef ---"
ps -ef | head -10
echo ""

echo "3. 특정 프로세스 검색 (예: bash)"
echo "--- bash 프로세스 검색 ---"
ps aux | grep -i bash | grep -v grep | head -5
echo ""

echo "4. 프로세스 모니터링 (top 대신 ps로 CPU 사용률 확인)"
echo "--- CPU 사용률 상위 5개 프로세스 ---"
ps aux | sort -rk 3 | head -6
echo ""

echo "5. 백그라운드 프로세스 실행"
echo "백그라운드에서 sleep 프로세스 시작..."
sleep 10 &
BG_PID=$!
echo "백그라운드 프로세스 PID: $BG_PID"
ps -p $BG_PID
echo ""

echo "6. 프로세스 종료 테스트"
echo "5초 후 프로세스 종료..."
sleep 5
kill $BG_PID 2>/dev/null && echo "프로세스 종료됨" || echo "프로세스가 이미 종료되었습니다"
echo ""

echo "7. 시스템 서비스 확인 (Mac에서는 launchd 사용)"
echo "--- 실행 중인 서비스 확인 (Mac) ---"
launchctl list | head -10
echo ""

echo "8. 프로세스 우선순위 확인"
echo "--- 현재 프로세스의 Nice 값 ---"
ps -o pid,ni,comm -p $$
echo ""

echo "=== 실습 완료 ==="

