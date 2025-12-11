# Project Audit для диссертации

> Pentool - Distributed Golang Penetration Testing Tool
> Дата генерации: 2025-12-10

---

## 1. Структура проекта

### Go файлы в проекте:
```
pkg/models/scan.go
cmd/analyzer-agent/main.go
cmd/main-agent/main.go
cmd/scanner-agent/main.go
cmd/reporter-agent/main.go
```

### Директория cmd/:
```
total 24
drwxrwxr-x  6 madi madi 4096 сен 29 18:03 .
drwxrwxr-x 16 madi madi 4096 дек 10 16:36 ..
drwxrwxr-x  2 madi madi 4096 сен 29 18:41 analyzer-agent
drwxrwxr-x  2 madi madi 4096 сен 29 18:47 main-agent
drwxrwxr-x  2 madi madi 4096 сен 29 18:48 reporter-agent
drwxrwxr-x  2 madi madi 4096 сен 29 18:47 scanner-agent
```

---

## 2. go.mod

```go
module github.com/pentool/pentool

go 1.24.0

require (
	github.com/google/uuid v1.6.0
	github.com/lib/pq v1.10.9
	github.com/nats-io/nats.go v1.46.0
	github.com/sirupsen/logrus v1.9.3
)

require (
	github.com/klauspost/compress v1.18.0 // indirect
	github.com/nats-io/nkeys v0.4.11 // indirect
	github.com/nats-io/nuid v1.0.1 // indirect
	golang.org/x/crypto v0.37.0 // indirect
	golang.org/x/sys v0.32.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
```

### Технологический стек:
| Компонент | Технология | Версия |
|-----------|------------|--------|
| Язык программирования | Go | 1.24+ |
| Message Broker | NATS | 2.10 |
| База данных | PostgreSQL | 15 |
| Кэш | Redis | 7 |
| UUID | google/uuid | 1.6.0 |
| Логирование | logrus | 1.9.3 |

---

## 3. FILES_FOR_PAPER.md (полное содержимое)

### Результаты тестирования и анализа

**Основные отчёты:**
```
benchmark_results/
├── PAPER_DATA_SUMMARY.md           <- ГЛАВНЫЙ ФАЙЛ - вся сводка
├── detailed_research_report.txt    <- Подробный отчёт (13KB, ASCII таблицы)
├── research_summary.md             <- Краткая сводка (Markdown)
└── summary.json                    <- Данные в JSON формате
```

**Результаты тестов:**
```
benchmark_results/
├── nmap_common.txt                 <- Результаты Nmap (15 портов)
├── nmap_common_time.txt            <- Метрики (время, память, CPU)
├── nmap_range.txt                  <- Результаты Nmap (1-100 портов)
├── nmap_range_time.txt             <- Метрики
├── nmap_service.txt                <- Определение сервисов
├── nmap_service_time.txt           <- Метрики
└── pentool_scan_results.json       <- Результаты Pentool
```

**Логи работы системы:**
```
logs/
├── main-agent.log                  <- Логи главного агента
├── scanner-agent.log               <- Логи сканера (найденные порты)
├── analyzer-agent.log              <- Логи анализатора (сервисы)
└── reporter-agent.log              <- Логи генератора отчётов
```

**База данных (Goose миграции):**
```
migrations/
├── 00001_initial_schema.sql        <- Таблица scans
├── 00002_scan_results.sql          <- Таблица scan_results (с is_open)
└── 00003_service_info.sql          <- Таблица service_info
```

---

## 4. Агенты (cmd/)

### Структура и размер файлов:
| Агент | Файл | Строк кода |
|-------|------|------------|
| analyzer-agent | main.go | 574 |
| main-agent | main.go | 532 |
| reporter-agent | main.go | 364 |
| scanner-agent | main.go | 263 |
| **ВСЕГО** | | **1733** |

### Main Agent (cmd/main-agent/main.go)
**Назначение:** REST API сервер, точка входа для пользователей

```go
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"github.com/nats-io/nats.go"
)

type Config struct {
	HTTPPort     string
	DatabaseURL  string
	NATSUrl      string
	MaxRetries   int
	RetryDelay   time.Duration
}

type Server struct {
	config   *Config
	db       *sql.DB
	nc       *nats.Conn
	jsCtx    nats.JetStreamContext
	mu       sync.RWMutex
	shutdown chan struct{}
}

type ScanRequest struct {
	Target string `json:"target"`
	Ports  []int  `json:"ports,omitempty"`
}

type ScanResponse struct {
	ID      string    `json:"id"`
	Target  string    `json:"target"`
	Status  string    `json:"status"`
	Message string    `json:"message,omitempty"`
	Created time.Time `json:"created_at"`
}
```

### Scanner Agent (cmd/scanner-agent/main.go)
**Назначение:** Сканирование портов с использованием горутин

```go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/sirupsen/logrus"
)

const (
	natsURL      = "nats://localhost:4222"
	scanRequest  = "scan.request"
	scanResult   = "scan.result"
	maxWorkers   = 10
	portTimeout  = 1 * time.Second
)

var topPorts = []int{
	21, 22, 23, 25, 80, 110, 443, 445, 3306, 3389,
	5432, 6379, 8080, 8443, 27017,
}

type ScannerAgent struct {
	nc     *nats.Conn
	logger *logrus.Logger
	ctx    context.Context
	cancel context.CancelFunc
}

type ScanRequest struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Ports  []int  `json:"ports"`
}

type ScanResult struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Port   int    `json:"port"`
	IsOpen bool   `json:"is_open"`
	Error  string `json:"error,omitempty"`
}
```

### Analyzer Agent (cmd/analyzer-agent/main.go)
**Назначение:** Определение сервисов на открытых портах

```go
package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/sirupsen/logrus"
)

var log = logrus.New()

type ScanResult struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Port   int    `json:"port"`
	IsOpen bool   `json:"is_open"`
	Error  string `json:"error,omitempty"`
}

type ServiceInfo struct {
	ScanID  string `json:"scan_id"`
	Target  string `json:"target"`
	Port    int    `json:"port"`
	Service string `json:"service"`
	Version string `json:"version,omitempty"`
	Banner  string `json:"banner,omitempty"`
}

type ServiceDetector struct {
	nc              *nats.Conn
	serviceRegistry map[int]string
	wg              sync.WaitGroup
	ctx             context.Context
	cancel          context.CancelFunc
}
```

### Reporter Agent (cmd/reporter-agent/main.go)
**Назначение:** Агрегация результатов и сохранение в PostgreSQL

```go
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/lib/pq"
	"github.com/nats-io/nats.go"
	"github.com/sirupsen/logrus"

	"github.com/pentool/pentool/pkg/models"
)

const (
	resultTimeout    = 30 * time.Second
	maxResultsWait   = 20
	natsURL         = "nats://localhost:4222"
	postgresConnStr = "postgres://admin:password@localhost/pentool?sslmode=disable"
)

type ReporterAgent struct {
	nc              *nats.Conn
	db              *sql.DB
	log             *logrus.Logger
	scanAggregators map[string]*ScanAggregator
	mutex           sync.RWMutex
}

type ScanAggregator struct {
	scanID      string
	target      string
	results     []models.ScanResult
	services    []models.ServiceInfo
	startTime   time.Time
	timer       *time.Timer
	resultCount int
	mutex       sync.Mutex
}

type Report struct {
	ScanID     string                `json:"scan_id"`
	Target     string                `json:"target"`
	Timestamp  time.Time             `json:"timestamp"`
	// ... дополнительные поля
}
```

---

## 5. Benchmark Results

### Содержимое директории benchmark_results/:
```
total 72
-rw-rw-r-- 1 madi madi 13283 detailed_research_report.txt
-rw-rw-r-- 1 madi madi    39 nmap_common_time.txt
-rw-rw-r-- 1 madi madi   831 nmap_common.txt
-rw-rw-r-- 1 madi madi    39 nmap_range_time.txt
-rw-rw-r-- 1 madi madi   465 nmap_range.txt
-rw-rw-r-- 1 madi madi    39 nmap_service_time.txt
-rw-rw-r-- 1 madi madi  1114 nmap_service.txt
-rw-rw-r-- 1 madi madi 11884 PAPER_DATA_SUMMARY.md
-rw-rw-r-- 1 madi madi   239 pentool_scan_results.json
-rw-rw-r-- 1 madi madi  1308 research_summary.md
-rw-rw-r-- 1 madi madi   458 summary.json
```

### summary.json:
```json
{
  "timestamp": "2025-09-29T23:39:46+05:00",
  "target": "scanme.nmap.org",
  "tests": {
    "pentool_common_ports": {
      "time_ms": 62722,
      "open_ports": 0,
      "scan_id": "ee2fe0c5-d4a5-42f4-8165-d785896ed1ee"
    },
    "nmap_common_ports": {
      "time_ms": 1018,
      "open_ports": 2
    },
    "nmap_port_range_1_100": {
      "time_ms": 1351,
      "open_ports": 2
    },
    "nmap_service_detection": {
      "time_ms": 9949
    }
  }
}
```

### research_summary.md - Сравнительная таблица производительности:

| Инструмент | Тест | Время (мс) | Время (с) | Найдено | Память (MB) | CPU (%) |
|------------|------|------------|-----------|---------|-------------|---------|
| Pentool | Общие порты (15) | 62722 | 62.72 | 0 | - | - |
| Nmap | Общие порты (15) | 1018 | 1.02 | 2 | 14.2 | 4 |
| Nmap | Диапазон 1-100 | 1351 | 1.35 | 2 | 14.4 | 3 |
| Nmap -sV | Определение сервисов | 9949 | 9.95 | - | 55.1 | 4 |

### Преимущества Pentool:
- Мульти-агентная распределенная архитектура
- Асинхронная обработка через NATS
- Горизонтальная масштабируемость
- RESTful API
- PostgreSQL для хранения
- Современные паттерны Go

### Области для улучшения:
- Скорость сканирования (оптимизация timeout)
- Параллелизм (увеличение workers)
- Точность обнаружения

---

## 6. Ключевые пакеты (pkg/)

### Структура pkg/:
```
pkg/
└── models/
    └── scan.go (89 строк)
```

### pkg/models/scan.go - Основные модели данных:

```go
package models

import "time"

// ScanRequest represents a scan task request
type ScanRequest struct {
	ID     string `json:"id"`
	Target string `json:"target"`
	Ports  []int  `json:"ports"`
}

// ScanResult represents the result of scanning a single port
type ScanResult struct {
	ID       string `json:"id"`
	ScanID   string `json:"scan_id"`
	Target   string `json:"target"`
	Port     int    `json:"port"`
	Protocol string `json:"protocol"`
	State    string `json:"state"` // open, closed, filtered
	Error    string `json:"error,omitempty"`
}

// ServiceInfo represents detected service information
type ServiceInfo struct {
	ID          string  `json:"id"`
	ScanID      string  `json:"scan_id"`
	Target      string  `json:"target"`
	Port        int     `json:"port"`
	ServiceName string  `json:"service"`
	Version     string  `json:"version,omitempty"`
	Banner      string  `json:"banner,omitempty"`
	Confidence  float64 `json:"confidence"`
}

// Scan represents a scan session in the database
type Scan struct {
	ID          string    `json:"id"`
	Target      string    `json:"target"`
	Status      string    `json:"status"` // pending, running, completed, failed
	TotalPorts  int       `json:"total_ports"`
	OpenPorts   int       `json:"open_ports"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
}

// Report represents a scan report
type Report struct {
	ScanID    string          `json:"scan_id"`
	Target    string          `json:"target"`
	Timestamp time.Time       `json:"timestamp"`
	Duration  int             `json:"duration_ms"`
	OpenPorts []PortInfo      `json:"open_ports"`
	Stats     ScanStatistics  `json:"statistics"`
}

// Common port list for scanning
var CommonPorts = []int{
	21, 22, 23, 25, 53, 80, 110, 143, 443, 993,
	995, 3306, 3389, 5432, 6379, 8080, 8443, 27017, 3000, 9200,
}
```

---

## 7. Docker/Deployments

### Структура deployments/:
```
deployments/
├── docker-compose.yml
├── postgres/
│   └── init.sql
└── sql/
    └── init.sql
```

### docker-compose.yml:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: pentool-postgres
    environment:
      POSTGRES_DB: pentool
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d pentool"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - pentool-net

  redis:
    image: redis:7-alpine
    container_name: pentool-redis
    command: redis-server --appendonly yes
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - pentool-net

  nats:
    image: nats:2.10-alpine
    container_name: pentool-nats
    command: "--http_port 8222 -js"
    ports:
      - "4222:4222"   # Client connections
      - "8222:8222"   # HTTP monitoring
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8222/healthz"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - pentool-net

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

networks:
  pentool-net:
    driver: bridge
```

---

## 8. Архитектура системы

### ASCII диаграмма:
```
User -> Main Agent (REST API :8080)
          |
       NATS (:4222)
          |
  +-------+-------+---------+
  |               |         |
Scanner      Analyzer    Reporter
  |               |         |
Results -> NATS -> PostgreSQL
```

### Компоненты:
1. **Main Agent** - REST API сервер (порт 8080)
   - Принимает HTTP запросы на сканирование
   - Публикует задачи в NATS
   - Возвращает результаты клиенту

2. **Scanner Agent** - Сканер портов
   - Подписан на scan.request в NATS
   - Использует goroutines для параллельного сканирования
   - Публикует результаты в scan.result

3. **Analyzer Agent** - Анализатор сервисов
   - Определяет сервисы на открытых портах
   - Получает баннеры и версии
   - Публикует информацию о сервисах

4. **Reporter Agent** - Генератор отчётов
   - Агрегирует результаты сканирования
   - Сохраняет данные в PostgreSQL
   - Формирует JSON отчёты

---

## 9. Ключевые метрики для диссертации

### Производительность:
- **Pentool**: 62.72 секунды (15 портов)
- **Nmap**: 1.02 секунды (15 портов)
- **Соотношение**: Nmap быстрее в ~61.5x раз

### Архитектурные преимущества:
1. Горизонтальное масштабирование агентов
2. Асинхронная обработка через message broker
3. Персистентное хранение результатов
4. REST API для интеграции
5. Контейнеризация через Docker

### Научная ценность:
1. Демонстрация Go concurrency patterns (goroutines)
2. Microservices architecture design
3. Message-driven distributed systems
4. Production-ready error handling
5. Scalable security tool development

---

## 10. Статистика кода

| Компонент | Файлов | Строк кода |
|-----------|--------|------------|
| cmd/analyzer-agent | 1 | 574 |
| cmd/main-agent | 1 | 532 |
| cmd/reporter-agent | 1 | 364 |
| cmd/scanner-agent | 1 | 263 |
| pkg/models | 1 | 89 |
| **ИТОГО** | **5** | **1822** |

---

## 11. Команды для запуска

```bash
# Установка зависимостей
make dev

# Запуск инфраструктуры (PostgreSQL, Redis, NATS)
make docker-up

# Запуск всех агентов
./scripts/start-system.sh

# Тестирование API
curl -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d '{"target":"scanme.nmap.org"}'

# Проверка статуса
curl http://localhost:8080/scan/{scan-id}

# Health check
curl http://localhost:8080/health
```

---

**Файл сгенерирован автоматически для передачи в чат диссертации**