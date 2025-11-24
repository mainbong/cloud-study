#!/bin/bash
# 파일 시스템 및 권한 관리 실습 스크립트

echo "=== 파일 시스템 및 권한 관리 실습 ==="
echo ""

# 실습 디렉토리 생성
PRACTICE_DIR="practice-fs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$PRACTICE_DIR"
cd "$PRACTICE_DIR" || exit

echo "1. 디렉토리 구조 확인"
echo "현재 디렉토리: $(pwd)"
echo ""

echo "2. 파일 생성 및 권한 확인"
touch test_file.txt
echo "Hello, Linux!" > test_file.txt
ls -la test_file.txt
echo ""

echo "3. 파일 권한 변경 (chmod)"
echo "원본 권한:"
ls -l test_file.txt
chmod 755 test_file.txt
echo "755 권한 적용 후:"
ls -l test_file.txt
chmod 644 test_file.txt
echo "644 권한 적용 후:"
ls -l test_file.txt
echo ""

echo "4. 디렉토리별 사용량 확인"
echo "현재 디렉토리 사용량:"
du -sh .
echo ""

echo "5. 파일 시스템 사용량 확인"
df -h | head -5
echo ""

echo "6. 권한 테스트"
# 실행 가능한 스크립트 생성
cat > test_script.sh << 'EOF'
#!/bin/bash
echo "This is a test script"
EOF

chmod +x test_script.sh
echo "실행 권한 추가 후:"
ls -l test_script.sh
./test_script.sh
echo ""

echo "7. 특수 권한 테스트 (SUID 예시)"
echo "SUID가 설정된 파일 예시 (시스템 파일):"
ls -l /usr/bin/passwd 2>/dev/null || echo "passwd 파일을 찾을 수 없습니다 (Mac 환경)"
echo ""

echo "=== 실습 완료 ==="
echo "실습 디렉토리: $(pwd)"
echo "정리하려면: rm -rf $PRACTICE_DIR"

