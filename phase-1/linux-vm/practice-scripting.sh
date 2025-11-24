#!/bin/bash
# 쉘 스크립팅 기초 실습

echo "=== 쉘 스크립팅 기초 실습 ==="
echo ""

# 1. 변수 사용
echo "1. 변수 사용"
NAME="Linux User"
AGE=25
echo "이름: $NAME"
echo "나이: $AGE"
echo "변수 길이: ${#NAME}"
echo ""

# 2. 특수 변수
echo "2. 특수 변수"
echo "스크립트 이름: \$0 = $0"
echo "첫 번째 인자: \$1 = ${1:-없음}"
echo "인자 개수: \$# = $#"
echo "모든 인자: \$@ = $@"
echo "현재 PID: \$\$ = $$"
echo ""

# 3. 조건문
echo "3. 조건문 예제"
FILE="test.txt"
if [ -f "$FILE" ]; then
    echo "$FILE 파일이 존재합니다"
else
    echo "$FILE 파일이 존재하지 않습니다"
    touch "$FILE"
    echo "$FILE 파일을 생성했습니다"
fi
echo ""

# 4. 반복문
echo "4. 반복문 예제"
echo "--- for 루프 ---"
for i in {1..5}; do
    echo "반복 $i"
done
echo ""

echo "--- while 루프 ---"
COUNT=1
while [ $COUNT -le 3 ]; do
    echo "카운트: $COUNT"
    COUNT=$((COUNT + 1))
done
echo ""

# 5. 함수
echo "5. 함수 예제"
greet() {
    local name=$1
    echo "안녕하세요, $name님!"
}

greet "스터디"
greet "클라우드"
echo ""

# 6. 명령어 치환
echo "6. 명령어 치환"
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_TIME=$(date +%H:%M:%S)
echo "현재 날짜: $CURRENT_DATE"
echo "현재 시간: $CURRENT_TIME"
echo ""

# 7. 입출력 리다이렉션
echo "7. 입출력 리다이렉션"
echo "리다이렉션 테스트" > output.txt
echo "추가 내용" >> output.txt
echo "output.txt 내용:"
cat output.txt
echo ""

# 8. 에러 처리
echo "8. 에러 처리"
set -e  # 에러 발생 시 종료
echo "에러 처리 모드 활성화"
# 존재하지 않는 명령어 실행 (에러 발생)
# nonexistent_command  # 주석 처리하여 스크립트가 계속 실행되도록 함
echo ""

echo "=== 실습 완료 ==="
echo "생성된 파일: output.txt"
rm -f output.txt test.txt

