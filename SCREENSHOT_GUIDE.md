# 📸 Руководство по созданию скриншотов для научной статьи

**Дата:** 2025-09-30
**Проект:** Pentool - Distributed Golang Penetration Testing Tool

---

## ⚠️ ВАЖНО: Подготовка перед началом

### 1. Настройка терминала для красивых скриншотов

```bash
# Увеличить шрифт терминала
# Ctrl + Shift + "+" (несколько раз)

# Использовать темную тему
# Настройки → Профили → Цвета → Выбрать темную схему

# Развернуть терминал на весь экран или сделать большим окном
```

### 2. Очистка системы

```bash
# Остановить все процессы
pkill -f "main-agent|scanner-agent|analyzer-agent|reporter-agent"

# Очистить старые логи
> logs/main-agent.log
> logs/scanner-agent.log
> logs/analyzer-agent.log
> logs/reporter-agent.log

# Убедиться что Docker запущен
docker ps
```

---

## 🎬 СЦЕНАРИЙ СКРИНШОТОВ

### РАЗДЕЛ 1: ПОДГОТОВКА И МИГРАЦИИ БД

#### 📸 Скриншот 1: "Запуск Docker контейнеров"

```bash
# Запустить Docker
make docker-up

# Проверить контейнеры
docker ps --filter name=pentool
```

**Что показать:** Таблица с 3 контейнерами (postgres, nats, redis) в статусе "Up"

---

#### 📸 Скриншот 2: "Применение миграций БД с Goose"

```bash
# Запустить миграции
make migrate-up
```

**Что показать:** Вывод с "OK 00001_initial_schema.sql", "OK 00002_scan_results.sql", "OK 00003_service_info.sql"

---

#### 📸 Скриншот 3: "Проверка статуса миграций"

```bash
make migrate-status
```

**Что показать:** Таблица с применёнными миграциями и датами

---

#### 📸 Скриншот 4: "Схема таблицы scan_results"

```bash
docker exec pentool-postgres psql -U admin -d pentool -c "\d scan_results"
```

**Что показать:** Схему таблицы с колонками включая `is_open` и `error`

---

#### 📸 Скриншот 5: "Список всех таблиц в БД"

```bash
docker exec pentool-postgres psql -U admin -d pentool -c "\dt"
```

**Что показать:** Список таблиц: scans, scan_results, service_info, goose_db_version

---

### РАЗДЕЛ 2: ЗАПУСК АГЕНТОВ

**Откройте 5 терминалов:**
- Терминал 1: Main Agent
- Терминал 2: Scanner Agent
- Терминал 3: Analyzer Agent
- Терминал 4: Reporter Agent
- Терминал 5: Команды для тестирования

#### 📸 Скриншот 6: "Запуск Main Agent"

**Терминал 1:**
```bash
DATABASE_URL="postgres://admin:secret123@localhost:5432/pentool?sslmode=disable" \
  NATS_URL="nats://localhost:4222" \
  ./bin/main-agent
```

**Что показать:** Вывод с:
- Successfully connected to PostgreSQL
- Successfully connected to NATS
- Starting HTTP server on port 8080
- Started listening for scan results

---

#### 📸 Скриншот 7: "Запуск Scanner Agent"

**Терминал 2:**
```bash
./bin/scanner-agent
```

**Что показать:** JSON логи с:
- "Connected to NATS"
- "Subscribed to scan requests"
- "Scanner Agent started"

---

#### 📸 Скриншот 8: "Запуск Analyzer Agent"

**Терминал 3:**
```bash
./bin/analyzer-agent
```

**Что показать:** Цветные логи с:
- "Starting Analyzer Agent"
- "Successfully connected to NATS"
- "Analyzer Agent is running"

---

#### 📸 Скриншот 9: "Запуск Reporter Agent"

**Терминал 4:**
```bash
./bin/reporter-agent
```

**Что показать:** Логи подключения к NATS и PostgreSQL

---

### РАЗДЕЛ 3: ПРОВЕРКА СИСТЕМЫ

#### 📸 Скриншот 10: "Health Check API"

**Терминал 5:**
```bash
curl -s http://localhost:8080/health | jq .
```

**Что показать:** JSON ответ:
```json
{
  "status": "healthy",
  "database": true,
  "nats": true
}
```

---

### РАЗДЕЛ 4: ЗАПУСК СКАНИРОВАНИЯ

#### 📸 Скриншот 11: "Создание задачи сканирования"

**Терминал 5:**
```bash
curl -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d '{"target":"scanme.nmap.org"}' | jq .
```

**Что показать:** JSON с:
- id (UUID)
- target: "scanme.nmap.org"
- status: "pending"
- created_at

**💡 ВАЖНО:** Сохраните SCAN_ID из ответа!

---

#### 📸 Скриншот 12: "Логи Scanner Agent - обнаружение портов"

**Вернитесь к Терминалу 2 (Scanner Agent)**

**Что показать:** Логи с:
- "Received scan request"
- "Found open port" port=22
- "Found open port" port=80
- "Completed port scan"

---

#### 📸 Скриншот 13: "Логи Analyzer Agent - определение сервисов"

**Вернитесь к Терминалу 3 (Analyzer Agent)**

**Что показать:** Логи с:
- "Service detected and published" port=22 service=SSH
- "Service detected and published" port=80 service=HTTP

---

#### 📸 Скриншот 14: "Результаты сканирования Pentool"

**Терминал 5 (замените YOUR_SCAN_ID на реальный):**
```bash
SCAN_ID="YOUR_SCAN_ID"
curl -s http://localhost:8080/scan/$SCAN_ID | jq .
```

**Что показать:** JSON с:
- status: "completed"
- open_ports: 2
- results: массив с найденными портами

---

### РАЗДЕЛ 5: СРАВНЕНИЕ С NMAP

#### 📸 Скриншот 15: "Сканирование с Nmap"

**Терминал 5:**
```bash
time nmap -p 21,22,23,25,80,110,443,445,3306,3389,5432,6379,8080,8443,27017 \
  scanme.nmap.org
```

**Что показать:**
- Вывод Nmap с найденными портами
- Время выполнения (real time)
- Версии сервисов

---

#### 📸 Скриншот 16: "Сравнение скорости выполнения"

**Сделать коллаж или показать рядом:**
- Pentool: ~60 секунд
- Nmap: ~1-2 секунды

---

### РАЗДЕЛ 6: БАЗА ДАННЫХ

#### 📸 Скриншот 17: "Сохраненные сканы в PostgreSQL"

```bash
docker exec pentool-postgres psql -U admin -d pentool -c \
  "SELECT id, target, status, open_ports, created_at FROM scans ORDER BY created_at DESC LIMIT 5;"
```

**Что показать:** Таблица с записями о сканированиях

---

#### 📸 Скриншот 18: "Результаты сканирования в БД"

```bash
docker exec pentool-postgres psql -U admin -d pentool -c \
  "SELECT scan_id, port, state, is_open FROM scan_results WHERE scan_id = 'YOUR_SCAN_ID' ORDER BY port;"
```

**Что показать:** Список портов с их статусами

---

#### 📸 Скриншот 19: "Информация о сервисах в БД"

```bash
docker exec pentool-postgres psql -U admin -d pentool -c \
  "SELECT scan_id, port, service_name, version FROM service_info WHERE scan_id = 'YOUR_SCAN_ID';"
```

**Что показать:** SSH и HTTP сервисы с версиями

---

### РАЗДЕЛ 7: МОНИТОРИНГ СИСТЕМЫ

#### 📸 Скриншот 20: "NATS статистика"

```bash
curl -s http://localhost:8222/varz | jq '{connections, in_msgs, out_msgs, uptime}'
```

**Что показать:** JSON с метриками NATS

---

#### 📸 Скриншот 21: "Запущенные процессы агентов"

```bash
ps aux | grep -E "main-agent|scanner-agent|analyzer-agent|reporter-agent" | grep -v grep
```

**Что показать:** Список процессов с PID и памятью

---

### РАЗДЕЛ 8: АРХИТЕКТУРА

#### 📸 Скриншот 22: "Архитектура системы (текст)"

```bash
cat << 'EOF'
    Pentool Multi-Agent Architecture
    ═════════════════════════════════

    ┌──────────────────┐
    │  User / Client   │
    └────────┬─────────┘
             │ HTTP REST API (:8080)
             ▼
    ┌──────────────────┐
    │   Main Agent     │
    │   (port :8080)   │
    └────────┬─────────┘
             │ NATS Pub/Sub (:4222)
             ▼
    ┌──────────────────────────────────────┐
    │    NATS Message Broker               │
    └───┬──────────────┬──────────────┬────┘
        │              │              │
        ▼              ▼              ▼
    ┌────────┐    ┌────────┐    ┌──────────┐
    │Scanner │    │Analyzer│    │ Reporter │
    │ Agent  │    │ Agent  │    │  Agent   │
    └────────┘    └────────┘    └─────┬────┘
                                      │
                                      ▼
                                ┌──────────┐
                                │PostgreSQL│
                                └──────────┘
EOF
```

**Что показать:** ASCII диаграмму архитектуры

---

### РАЗДЕЛ 9: БЕНЧМАРК ОТЧЕТЫ

#### 📸 Скриншот 23: "Сравнительная таблица производительности"

```bash
cat benchmark_results/research_summary.md
```

**Что показать:** Markdown таблицу с метриками

---

#### 📸 Скриншот 24: "Детальный отчет (часть 1)"

```bash
head -50 benchmark_results/detailed_research_report.txt
```

**Что показать:** Первую часть отчета с таблицей

---

#### 📸 Скриншот 25: "Детальный отчет (часть 2 - выводы)"

```bash
tail -50 benchmark_results/detailed_research_report.txt
```

**Что показать:** Выводы и рекомендации

---

### РАЗДЕЛ 10: ДОПОЛНИТЕЛЬНЫЕ (ОПЦИОНАЛЬНО)

#### 📸 Скриншот 26: "Структура проекта"

```bash
tree -L 2 -I 'bin|vendor|node_modules'
```

или

```bash
ls -lah
echo ""
echo "Структура:"
echo "cmd/        - Агенты"
echo "pkg/        - Общие пакеты"
echo "migrations/ - SQL миграции"
echo "scripts/    - Утилиты"
```

---

#### 📸 Скриншот 27: "Логи всех агентов (мозаика)"

Сделать один большой скриншот со всеми 4 терминалами агентов одновременно (используйте tmux или расположите окна рядом).

---

## 🎨 СОВЕТЫ ПО ОФОРМЛЕНИЮ СКРИНШОТОВ

### Для лучшего качества:

1. **Разрешение:** Минимум 1920x1080
2. **Формат:** PNG (не JPEG!)
3. **Терминал:** Тёмная тема + крупный шрифт
4. **Обрезка:** Убирайте лишние панели/меню
5. **Подписи:** Добавьте стрелки/выделения на важные части (в редакторе)

### Инструменты для скриншотов:

```bash
# Linux - встроенный
# Ctrl + Shift + Print Screen (выделение области)
# или Shift + Print Screen (всё окно)

# Альтернативно - flameshot (лучший)
sudo apt install flameshot
flameshot gui
```

---

## 📋 БЫСТРЫЙ ЧЕКЛИСТ

```
□ 1.  Docker контейнеры запущены
□ 2.  Миграции применены (Goose)
□ 3.  Статус миграций
□ 4.  Схема scan_results
□ 5.  Список таблиц
□ 6.  Main Agent запущен
□ 7.  Scanner Agent запущен
□ 8.  Analyzer Agent запущен
□ 9.  Reporter Agent запущен
□ 10. Health Check API
□ 11. Создание задачи сканирования
□ 12. Логи Scanner - найденные порты
□ 13. Логи Analyzer - определение сервисов
□ 14. Результаты Pentool
□ 15. Результаты Nmap
□ 16. Сравнение скорости
□ 17. Сканы в PostgreSQL
□ 18. Результаты в БД
□ 19. Сервисы в БД
□ 20. NATS статистика
□ 21. Процессы агентов
□ 22. Архитектура (ASCII)
□ 23. Сравнительная таблица
□ 24. Детальный отчет (часть 1)
□ 25. Детальный отчет (часть 2)
□ 26. Структура проекта (опц.)
□ 27. Мозаика из 4 терминалов (опц.)
```

---

## 🚀 АВТОМАТИЧЕСКИЙ СПОСОБ (с паузами)

Если хотите полуавтоматический процесс:

```bash
./scripts/demo_for_screenshots.sh
```

Этот скрипт будет:
1. Выполнять команды автоматически
2. Делать паузы для скриншотов
3. Показывать подсказки что снимать
4. Проводить вас через весь процесс

---

## 📊 ДАННЫЕ ДЛЯ ГРАФИКОВ В СТАТЬЕ

После скриншотов, используй эти данные для создания графиков:

### Время выполнения (секунды):
- Pentool (15 портов): 62.72
- Nmap (15 портов): 1.02
- Nmap (1-100 портов): 1.35
- Nmap (определение сервисов): 9.95

### Использование памяти (MB):
- Nmap (все тесты): ~14 MB

### Загрузка CPU (%):
- Nmap (все тесты): 4%

---

## ✅ ФИНАЛЬНАЯ ПРОВЕРКА

Перед завершением убедитесь что у вас есть:

✅ Скриншоты всех агентов в работе
✅ Логи с обнаруженными портами
✅ JSON ответы API
✅ Данные из PostgreSQL
✅ Сравнение с Nmap
✅ Архитектурная диаграмма
✅ Таблицы и отчёты

---

## 🎓 ДЛЯ НАУЧНОЙ СТАТЬИ

### Рекомендуемые секции с скриншотами:

**Глава 3 - Реализация:**
- Скриншоты 1-5 (инфраструктура и БД)
- Скриншот 22 (архитектура)

**Глава 4 - Тестирование:**
- Скриншоты 6-14 (запуск и работа системы)
- Скриншоты 17-19 (данные в БД)

**Глава 5 - Результаты:**
- Скриншоты 15-16 (сравнение с Nmap)
- Скриншоты 23-25 (отчёты и таблицы)

**Приложения:**
- Скриншоты 20-21 (мониторинг)
- Скриншот 26 (структура проекта)

---

## 💡 ВАЖНЫЕ ЗАМЕЧАНИЯ

1. **Сохраняйте SCAN_ID** после создания задачи - он понадобится для нескольких команд
2. **Не закрывайте терминалы агентов** до завершения всех скриншотов
3. **Делайте скриншоты последовательно** - некоторые зависят от предыдущих
4. **Проверяйте качество** каждого скриншота перед переходом к следующему

---

**Готово! Завтра просто следуйте этой инструкции шаг за шагом. Удачи! 🚀**