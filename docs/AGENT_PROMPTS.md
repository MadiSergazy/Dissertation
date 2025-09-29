Промпты для Быстрой Реализации MVP
🎯 Промпт для ГЛАВНОГО АГЕНТА (Координатор)
Ты - главный агент-координатор для создания penetration testing tool на Golang.

КОНТЕКСТ:
- Проект: распределенный сканер портов с микросервисной архитектурой
- Технологии: Go, NATS (messaging), PostgreSQL (storage), Docker
- Архитектура: Main Agent + 3 Sub-Agents (Scanner, Analyzer, Reporter)
- Цель: MVP за 2-3 дня

ТВОЯ РОЛЬ:
1. Координировать работу SubAgents
2. Проверять качество их кода
3. Обеспечивать интеграцию компонентов
4. Следить за соблюдением архитектуры

СТРУКТУРА ПРОЕКТА:
pentool/
├── cmd/
│   ├── main-agent/
│   ├── scanner-agent/
│   ├── analyzer-agent/
│   └── reporter-agent/
├── internal/
├── pkg/
└── deployments/

ПОРЯДОК РАБОТЫ:
1. Сначала создай базовую структуру проекта
2. Затем координируй SubAgents для реализации компонентов
3. В конце проведи интеграционное тестирование

Начни с создания Makefile и docker-compose.yml для быстрого старта.

📝 Промпты для SUBAGENTS в Claude IDE
SubAgent 1: Project Setup & Infrastructure
Создай начальную структуру проекта для penetration testing tool на Go.

ТРЕБОВАНИЯ:
1. Создай файловую структуру:
    - cmd/ для точек входа агентов
    - internal/ для внутренней логики
    - deployments/ для Docker и docker-compose
    - pkg/models/ для общих типов данных

2. Создай docker-compose.yml с:
    - PostgreSQL (порт 5432)
    - Redis (порт 6379)
    - NATS (порт 4222)

3. Создай Makefile с командами:
    - build: компиляция всех агентов
    - run: запуск docker-compose
    - test: запуск тестов
    - clean: очистка

4. Создай go.mod с зависимостями:
    - github.com/nats-io/nats.go
    - github.com/lib/pq
    - github.com/sirupsen/logrus

5. Создай базовый README.md с инструкциями запуска

Выведи все файлы с полным кодом.
SubAgent 2: Scanner Agent Implementation
Реализуй Scanner Agent для сканирования TCP портов на Go.

ФАЙЛ: cmd/scanner-agent/main.go

ФУНКЦИОНАЛЬНОСТЬ:
1. Подключение к NATS (localhost:4222)
2. Подписка на топик "scan.request"
3. Сканирование TCP портов (только top 20 для MVP):
    - Порты: 21,22,23,25,80,110,443,445,3306,3389,5432,6379,8080,8443,27017
    - Timeout: 1 секунда на порт
    - Concurrent: используй goroutines (max 10 одновременно)

4. Публикация результатов в топик "scan.result"

СТРУКТУРА СООБЩЕНИЙ:
```go
type ScanRequest struct {
    ID     string   `json:"id"`
    Target string   `json:"target"`
    Ports  []int    `json:"ports"`
}

type ScanResult struct {
    ID     string `json:"id"`
    Target string `json:"target"`
    Port   int    `json:"port"`
    IsOpen bool   `json:"is_open"`
    Error  string `json:"error,omitempty"`
}
Используй логирование через logrus.
Добавь graceful shutdown по Ctrl+C.
Выведи полный рабочий код.

### SubAgent 3: Main Agent API Implementation
Реализуй Main Agent с REST API для управления сканированием.
ФАЙЛ: cmd/main-agent/main.go
ФУНКЦИОНАЛЬНОСТЬ:

REST API на порту 8080:

POST /scan - начать сканирование
GET /scan/:id - статус сканирования
GET /health - проверка здоровья


Подключения:

NATS для отправки задач
PostgreSQL для хранения результатов


База данных (создай SQL):

sqlCREATE TABLE IF NOT EXISTS scans (
    id VARCHAR(36) PRIMARY KEY,
    target VARCHAR(255),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS scan_results (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(36) REFERENCES scans(id),
    port INTEGER,
    is_open BOOLEAN,
    created_at TIMESTAMP DEFAULT NOW()
);

Логика:

Принять POST запрос с target
Сгенерировать UUID для scan_id
Сохранить в БД со статусом "pending"
Отправить в NATS топик "scan.request"
Слушать "scan.result" и обновлять БД



Используй стандартный net/http.
Добавь CORS headers.
Выведи полный код с обработкой ошибок.

### SubAgent 4: Analyzer Agent Implementation
Реализуй Analyzer Agent для определения сервисов на открытых портах.
ФАЙЛ: cmd/analyzer-agent/main.go
ФУНКЦИОНАЛЬНОСТЬ:

Подписка на NATS топик "scan.result"
Для открытых портов определи сервис:

22 -> SSH (попробуй подключиться и получить баннер)
80 -> HTTP (отправь GET /)
443 -> HTTPS
3306 -> MySQL
5432 -> PostgreSQL
6379 -> Redis
27017 -> MongoDB


Публикация в топик "service.detected":

gotype ServiceInfo struct {
    ScanID  string `json:"scan_id"`
    Target  string `json:"target"`
    Port    int    `json:"port"`
    Service string `json:"service"`
    Version string `json:"version,omitempty"`
    Banner  string `json:"banner,omitempty"`
}

Простое определение через:

Banner grabbing (читай первые 1024 байта)
HTTP заголовки для веб-сервисов
Известные порты для остальных



Таймаут 2 секунды на проверку.
Выведи полный код.

### SubAgent 5: Reporter Agent Implementation
Реализуй Reporter Agent для генерации отчетов.
ФАЙЛ: cmd/reporter-agent/main.go
ФУНКЦИОНАЛЬНОСТЬ:

Подписка на топики:

"scan.result" - результаты портов
"service.detected" - информация о сервисах


Агрегация данных по scan_id
Когда получено 20 результатов или прошло 30 секунд:

Сгенерировать JSON отчет
Сохранить в PostgreSQL
Обновить статус скана на "completed"


Структура отчета:

json{
  "scan_id": "uuid",
  "target": "192.168.1.1",
  "timestamp": "2024-01-01T00:00:00Z",
  "duration_ms": 5000,
  "open_ports": [
    {
      "port": 80,
      "service": "HTTP",
      "version": "nginx/1.18"
    }
  ],
  "statistics": {
    "total_ports": 20,
    "open_ports": 3,
    "closed_ports": 17
  }
}
Сохрани отчет в таблицу:
sqlCREATE TABLE reports (
    id SERIAL PRIMARY KEY,
    scan_id VARCHAR(36),
    report JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
Выведи полный код.

### SubAgent 6: Integration & Testing
Создай интеграционные тесты и скрипт запуска.
ФАЙЛЫ:

scripts/start.sh - запуск всей системы
scripts/test.sh - тестирование
internal/agent/nats_client.go - общий NATS клиент

start.sh должен:

Запустить docker-compose
Подождать готовности сервисов
Запустить все агенты в фоне
Вывести инструкции для тестирования

test.sh должен:

Отправить тестовый запрос на сканирование scanme.nmap.org
Проверить статус
Получить результаты
Вывести отчет

nats_client.go должен содержать:

Переиспользуемые функции подключения
Публикация/подписка с retry логикой
Graceful shutdown

Добавь примеры curl команд для тестирования API.
Выведи все файлы.

---

## 🚀 ПОРЯДОК ВЫПОЛНЕНИЯ

### День 1: Базовая инфраструктура
1. Отправь промпт SubAgent 1 → получи структуру проекта
2. Запусти `docker-compose up -d`
3. Проверь что все сервисы работают

### День 2: Основные агенты
1. SubAgent 2 → Scanner Agent
2. SubAgent 3 → Main Agent API
3. Протестируй связку Main ↔ Scanner

### День 3: Дополнительные агенты и интеграция
1. SubAgent 4 → Analyzer Agent
2. SubAgent 5 → Reporter Agent  
3. SubAgent 6 → Integration

---

## 📋 ЧЕКЛИСТ ГОТОВНОСТИ MVP
```bash
# После выполнения всех промптов проверь:

✅ docker-compose up -d  # Все контейнеры запущены
✅ make build           # Все агенты скомпилированы
✅ ./bin/main-agent     # API работает на :8080
✅ ./bin/scanner-agent  # Подключен к NATS
✅ curl -X POST http://localhost:8080/scan -d '{"target":"scanme.nmap.org"}'
✅ curl http://localhost:8080/scan/{id}  # Возвращает результаты

💡 СОВЕТЫ

Начни с простого: Сначала запусти только Main + Scanner агенты
Используй логи: Каждый агент должен логировать свои действия
Тестируй поэтапно: Не запускай все сразу, проверяй каждый компонент
scanme.nmap.org: Безопасная цель для тестирования


🔧 БЫСТРЫЕ ФИКСЫ
Если что-то не работает:
bash# Перезапустить все
docker-compose down
docker-compose up -d
pkill -f agent  # Остановить все агенты

# Проверить NATS
docker logs pentool_nats_1

# Проверить PostgreSQL
docker exec -it pentool_postgres_1 psql -U admin -d pentool

# Очистить и пересобрать
make clean
make build