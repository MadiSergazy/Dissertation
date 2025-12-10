# ⚡ Быстрый старт для скриншотов

## 🎯 Минимальная команда (всё за 5 минут)

### Шаг 1: Подготовка
```bash
cd ~/pentool
pkill -f agent  # Убить старые процессы
make docker-up  # Запустить Docker
make migrate-up # Применить миграции
```

### Шаг 2: Открыть 5 терминалов и запустить:

**Терминал 1:**
```bash
DATABASE_URL="postgres://admin:secret123@localhost:5432/pentool?sslmode=disable" \
  NATS_URL="nats://localhost:4222" \
  ./bin/main-agent
```

**Терминал 2:**
```bash
./bin/scanner-agent
```

**Терминал 3:**
```bash
./bin/analyzer-agent
```

**Терминал 4:**
```bash
./bin/reporter-agent
```

**Терминал 5 (команды):**
```bash
# Health Check
curl -s http://localhost:8080/health | jq .

# Запустить скан
curl -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d '{"target":"scanme.nmap.org"}' | jq .

# Сохранить SCAN_ID из ответа!
SCAN_ID="ВСТАВЬТЕ_СЮДА"

# Подождать 60 секунд, затем:
curl -s http://localhost:8080/scan/$SCAN_ID | jq .

# Сравнить с Nmap
time nmap -p 21,22,23,25,80,110,443,445,3306,3389,5432,6379,8080,8443,27017 scanme.nmap.org
```

### Шаг 3: БД и отчёты
```bash
# Данные в БД
docker exec pentool-postgres psql -U admin -d pentool -c "SELECT * FROM scans LIMIT 3;"

# Отчёт
cat benchmark_results/research_summary.md
```

---

## 📸 Обязательные скриншоты (топ-10)

1. ✅ Docker контейнеры (`docker ps`)
2. ✅ Миграции (`make migrate-status`)
3. ✅ Схема БД (`\d scan_results`)
4. ✅ Все 4 агента запущены (мозаика)
5. ✅ Health API (JSON с "healthy")
6. ✅ Создание скана (JSON ответ с ID)
7. ✅ Логи Scanner (Found open port)
8. ✅ Результаты Pentool (JSON с results)
9. ✅ Результаты Nmap (с временем)
10. ✅ Данные в PostgreSQL

---

## 🆘 Если что-то пошло не так

```bash
# Перезапуск всего
make clean
make docker-up
make migrate-up
make build

# Затем запустить агенты снова
```

---

## 📁 Все файлы для статьи

```
benchmark_results/
├── PAPER_DATA_SUMMARY.md       ← ГЛАВНЫЙ ФАЙЛ
├── detailed_research_report.txt
├── research_summary.md
└── summary.json

logs/
├── main-agent.log
├── scanner-agent.log
└── analyzer-agent.log

SCREENSHOT_GUIDE.md  ← Подробная инструкция
```

Готово! 🎉