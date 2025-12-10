#!/bin/bash

# Demo script for creating screenshots
# This script will guide you through the system demonstration with pauses

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to wait for user
wait_for_screenshot() {
    echo ""
    echo -e "${YELLOW}${BOLD}📸 СКРИНШОТ $1: $2${NC}"
    echo -e "${CYAN}Нажмите Enter когда сделаете скриншот...${NC}"
    read -r
}

# Function to pause
pause() {
    echo -e "${CYAN}Нажмите Enter для продолжения...${NC}"
    read -r
}

# Start
clear
echo -e "${GREEN}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║    PENTOOL - DEMO SCRIPT ДЛЯ СКРИНШОТОВ                  ║"
echo "║    Distributed Golang Penetration Testing Tool          ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Этот скрипт проведет вас через демонстрацию системы"
echo "с паузами для создания скриншотов."
echo ""
pause

# ============================================================================
# SECTION 1: Preparation
# ============================================================================
print_header "РАЗДЕЛ 1: ПОДГОТОВКА СИСТЕМЫ"

echo -e "${YELLOW}Шаг 1.1: Остановка старых процессов${NC}"
echo "Команда: pkill -f \"main-agent|scanner-agent|analyzer-agent|reporter-agent\""
pkill -f "main-agent|scanner-agent|analyzer-agent|reporter-agent" 2>/dev/null || true
sleep 2
echo -e "${GREEN}✓ Старые процессы остановлены${NC}"

echo ""
echo -e "${YELLOW}Шаг 1.2: Запуск Docker контейнеров${NC}"
echo "Команда: docker-compose -f deployments/docker-compose.yml up -d"
docker-compose -f deployments/docker-compose.yml up -d
sleep 3

echo ""
echo -e "${YELLOW}Шаг 1.3: Проверка Docker контейнеров${NC}"
docker ps --filter name=pentool --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
wait_for_screenshot "1" "Docker контейнеры запущены"

echo ""
echo -e "${YELLOW}Шаг 1.4: Запуск миграций БД (Goose)${NC}"
echo "Команда: make migrate-reset && make migrate-up"
make migrate-reset 2>/dev/null || true
sleep 1
make migrate-up
wait_for_screenshot "2" "Миграции БД применены"

echo ""
echo -e "${YELLOW}Шаг 1.5: Проверка схемы БД${NC}"
echo "Команда: docker exec pentool-postgres psql -U admin -d pentool -c '\dt'"
docker exec pentool-postgres psql -U admin -d pentool -c "\dt"
echo ""
echo "Команда: docker exec pentool-postgres psql -U admin -d pentool -c '\d scan_results'"
docker exec pentool-postgres psql -U admin -d pentool -c "\d scan_results"
wait_for_screenshot "3" "Схема базы данных"

# ============================================================================
# SECTION 2: Start Agents
# ============================================================================
print_header "РАЗДЕЛ 2: ЗАПУСК АГЕНТОВ"

echo -e "${CYAN}${BOLD}Откройте 4 отдельных терминала для каждого агента!${NC}"
echo ""
echo "Терминал 1 - Main Agent:"
echo -e "${YELLOW}DATABASE_URL=\"postgres://admin:secret123@localhost:5432/pentool?sslmode=disable\" NATS_URL=\"nats://localhost:4222\" ./bin/main-agent${NC}"
echo ""
echo "Терминал 2 - Scanner Agent:"
echo -e "${YELLOW}./bin/scanner-agent${NC}"
echo ""
echo "Терминал 3 - Analyzer Agent:"
echo -e "${YELLOW}./bin/analyzer-agent${NC}"
echo ""
echo "Терминал 4 - Reporter Agent:"
echo -e "${YELLOW}./bin/reporter-agent${NC}"
echo ""
echo -e "${CYAN}Запустите все агенты и нажмите Enter когда готово...${NC}"
read -r

# Start agents in background for health check
DATABASE_URL="postgres://admin:secret123@localhost:5432/pentool?sslmode=disable" NATS_URL="nats://localhost:4222" ./bin/main-agent > logs/demo-main.log 2>&1 &
MAIN_PID=$!
sleep 2

./bin/scanner-agent > logs/demo-scanner.log 2>&1 &
SCANNER_PID=$!
sleep 1

./bin/analyzer-agent > logs/demo-analyzer.log 2>&1 &
ANALYZER_PID=$!
sleep 1

./bin/reporter-agent > logs/demo-reporter.log 2>&1 &
REPORTER_PID=$!
sleep 2

echo -e "${GREEN}✓ Агенты запущены в фоне${NC}"
wait_for_screenshot "4" "Все агенты запущены (показать терминалы)"

# ============================================================================
# SECTION 3: Health Check
# ============================================================================
print_header "РАЗДЕЛ 3: ПРОВЕРКА ЗДОРОВЬЯ СИСТЕМЫ"

echo -e "${YELLOW}Проверка Health Endpoint${NC}"
echo "Команда: curl -s http://localhost:8080/health | jq ."
echo ""
curl -s http://localhost:8080/health | jq .
wait_for_screenshot "5" "Health Check - система здорова"

# ============================================================================
# SECTION 4: Create Scan
# ============================================================================
print_header "РАЗДЕЛ 4: СОЗДАНИЕ ЗАДАЧИ СКАНИРОВАНИЯ"

echo -e "${YELLOW}Запуск сканирования scanme.nmap.org${NC}"
echo "Команда: curl -X POST http://localhost:8080/scan -H \"Content-Type: application/json\" -d '{\"target\":\"scanme.nmap.org\"}'"
echo ""

RESPONSE=$(curl -s -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d '{"target":"scanme.nmap.org"}')

echo "$RESPONSE" | jq .
SCAN_ID=$(echo "$RESPONSE" | jq -r '.id')

echo ""
echo -e "${GREEN}✓ Сканирование создано! ID: ${SCAN_ID}${NC}"
wait_for_screenshot "6" "Создание задачи сканирования (JSON ответ)"

echo ""
echo -e "${CYAN}Проверьте логи в терминалах агентов!${NC}"
echo "- Scanner Agent должен показать: 'Found open port'"
echo "- Analyzer Agent должен показать: 'Service detected'"
pause
wait_for_screenshot "7" "Логи Scanner Agent (Found open port)"
wait_for_screenshot "8" "Логи Analyzer Agent (Service detected)"

# ============================================================================
# SECTION 5: Wait for completion
# ============================================================================
print_header "РАЗДЕЛ 5: ОЖИДАНИЕ ЗАВЕРШЕНИЯ"

echo -e "${YELLOW}Ожидание завершения сканирования (макс 30 сек)...${NC}"
for i in {1..30}; do
    STATUS=$(curl -s http://localhost:8080/scan/$SCAN_ID | jq -r '.status')
    echo -n "."
    if [ "$STATUS" == "completed" ] || [ "$STATUS" == "failed" ]; then
        echo ""
        echo -e "${GREEN}✓ Статус: $STATUS${NC}"
        break
    fi
    sleep 1
done
echo ""

# ============================================================================
# SECTION 6: View Results
# ============================================================================
print_header "РАЗДЕЛ 6: ПРОСМОТР РЕЗУЛЬТАТОВ"

echo -e "${YELLOW}Получение результатов сканирования${NC}"
echo "Команда: curl -s http://localhost:8080/scan/$SCAN_ID | jq ."
echo ""

RESULTS=$(curl -s http://localhost:8080/scan/$SCAN_ID)
echo "$RESULTS" | jq .

wait_for_screenshot "9" "Результаты сканирования Pentool"

# ============================================================================
# SECTION 7: Compare with Nmap
# ============================================================================
print_header "РАЗДЕЛ 7: СРАВНЕНИЕ С NMAP"

echo -e "${YELLOW}Запуск Nmap для сравнения${NC}"
echo "Команда: time nmap -p 21,22,23,25,80,110,443,445,3306,3389,5432,6379,8080,8443,27017 scanme.nmap.org"
echo ""

START_TIME=$(date +%s)
nmap -p 21,22,23,25,80,110,443,445,3306,3389,5432,6379,8080,8443,27017 scanme.nmap.org
END_TIME=$(date +%s)
NMAP_TIME=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}✓ Nmap завершен за ${NMAP_TIME} секунд${NC}"
wait_for_screenshot "10" "Результаты Nmap (сравнение)"

# ============================================================================
# SECTION 8: Database Check
# ============================================================================
print_header "РАЗДЕЛ 8: ПРОВЕРКА БАЗЫ ДАННЫХ"

echo -e "${YELLOW}Просмотр сохраненных сканов${NC}"
echo "Команда: docker exec pentool-postgres psql -U admin -d pentool -c \"SELECT id, target, status, open_ports, created_at FROM scans ORDER BY created_at DESC LIMIT 3;\""
echo ""

docker exec pentool-postgres psql -U admin -d pentool -c "SELECT id, target, status, open_ports, created_at FROM scans ORDER BY created_at DESC LIMIT 3;"

wait_for_screenshot "11" "Данные в PostgreSQL"

echo ""
echo -e "${YELLOW}Просмотр результатов сканирования${NC}"
echo "Команда: docker exec pentool-postgres psql -U admin -d pentool -c \"SELECT scan_id, port, state, is_open FROM scan_results WHERE scan_id = '$SCAN_ID' LIMIT 5;\""
echo ""

docker exec pentool-postgres psql -U admin -d pentool -c "SELECT scan_id, port, state, is_open FROM scan_results WHERE scan_id = '$SCAN_ID' LIMIT 5;"

wait_for_screenshot "12" "Результаты сканирования в БД"

# ============================================================================
# SECTION 9: System Monitoring
# ============================================================================
print_header "РАЗДЕЛ 9: МОНИТОРИНГ СИСТЕМЫ"

echo -e "${YELLOW}NATS мониторинг${NC}"
echo "Команда: curl -s http://localhost:8222/varz | jq '{connections, in_msgs, out_msgs, uptime}'"
echo ""

curl -s http://localhost:8222/varz | jq '{connections, in_msgs, out_msgs, uptime}'

wait_for_screenshot "13" "NATS статистика"

echo ""
echo -e "${YELLOW}Запущенные процессы агентов${NC}"
ps aux | grep -E "main-agent|scanner-agent|analyzer-agent|reporter-agent" | grep -v grep

wait_for_screenshot "14" "Процессы агентов"

# ============================================================================
# SECTION 10: Architecture
# ============================================================================
print_header "РАЗДЕЛ 10: АРХИТЕКТУРА СИСТЕМЫ"

cat << 'EOF'

    Pentool Multi-Agent Architecture
    ═════════════════════════════════

    ┌──────────────────┐
    │  User / Client   │
    └────────┬─────────┘
             │ HTTP REST API (:8080)
             ▼
    ┌──────────────────┐
    │   Main Agent     │ ◄─── REST API, Координация
    │   (port :8080)   │      PostgreSQL взаимодействие
    └────────┬─────────┘
             │ NATS Pub/Sub (:4222)
             ▼
    ┌──────────────────────────────────────┐
    │    NATS Message Broker               │
    │    (Message Queue & Streaming)       │
    └───┬──────────────┬──────────────┬────┘
        │              │              │
        ▼              ▼              ▼
    ┌────────┐    ┌────────┐    ┌──────────┐
    │Scanner │    │Analyzer│    │ Reporter │
    │ Agent  │    │ Agent  │    │  Agent   │
    │        │    │        │    │          │
    │Port    │    │Service │    │Report    │
    │Scanning│    │Detect  │    │Generate  │
    └────────┘    └────────┘    └─────┬────┘
                                      │
                                      ▼
                                ┌──────────┐
                                │PostgreSQL│
                                │ Database │
                                └──────────┘

    Технологии:
    • Go 1.19+ (Goroutines & Channels)
    • NATS Streaming (Message Broker)
    • PostgreSQL 15 (Data Storage)
    • Redis 7 (Caching)
    • Docker (Containerization)

EOF

wait_for_screenshot "15" "Архитектура системы (ASCII диаграмма)"

# ============================================================================
# SECTION 11: Benchmark Report
# ============================================================================
print_header "РАЗДЕЛ 11: ИТОГОВЫЙ ОТЧЕТ"

if [ -f "benchmark_results/research_summary.md" ]; then
    echo -e "${YELLOW}Просмотр итогового отчета${NC}"
    cat benchmark_results/research_summary.md
    wait_for_screenshot "16" "Итоговый отчет (Markdown)"
fi

# ============================================================================
# CLEANUP
# ============================================================================
print_header "ЗАВЕРШЕНИЕ ДЕМОНСТРАЦИИ"

echo -e "${GREEN}${BOLD}✓ Демонстрация завершена!${NC}"
echo ""
echo "Созданные скриншоты:"
echo "  📸 1.  Docker контейнеры"
echo "  📸 2.  Миграции БД (Goose)"
echo "  📸 3.  Схема базы данных"
echo "  📸 4.  Все агенты запущены"
echo "  📸 5.  Health Check"
echo "  📸 6.  Создание задачи сканирования"
echo "  📸 7.  Логи Scanner Agent"
echo "  📸 8.  Логи Analyzer Agent"
echo "  📸 9.  Результаты Pentool"
echo "  📸 10. Результаты Nmap"
echo "  📸 11. PostgreSQL данные (scans)"
echo "  📸 12. PostgreSQL данные (results)"
echo "  📸 13. NATS статистика"
echo "  📸 14. Процессы агентов"
echo "  📸 15. Архитектура системы"
echo "  📸 16. Итоговый отчет"
echo ""
echo -e "${YELLOW}Хотите остановить агенты? (y/n)${NC}"
read -r STOP_AGENTS

if [ "$STOP_AGENTS" == "y" ]; then
    echo "Остановка агентов..."
    kill $MAIN_PID $SCANNER_PID $ANALYZER_PID $REPORTER_PID 2>/dev/null || true
    echo -e "${GREEN}✓ Агенты остановлены${NC}"
fi

echo ""
echo -e "${CYAN}${BOLD}Все данные для научной статьи готовы!${NC}"
echo ""
echo "Файлы для статьи:"
echo "  • benchmark_results/detailed_research_report.txt"
echo "  • benchmark_results/research_summary.md"
echo "  • benchmark_results/PAPER_DATA_SUMMARY.md"
echo "  • logs/*.log"
echo ""
echo -e "${GREEN}Удачи с научной статьей! 🎓${NC}"