# План оптимизации производительности Pentool

## Резюме проблемы

| Метрика | Pentool | Nmap | Цель |
|---------|---------|------|------|
| Время (15 портов) | 62.72 сек | 1.02 сек | 5-10 сек |
| Найдено портов | 0 | 2 | 2 |

## Корневые причины (Root Cause Analysis)

### КРИТИЧЕСКИЙ БАГ #1: Несоответствие структур данных

**scanner-agent** публикует в `scan.result`:
```go
type ScanResult struct {
    ID     string `json:"id"`       // <- передаёт scan_id как "id"
    Target string `json:"target"`
    Port   int    `json:"port"`
    IsOpen bool   `json:"is_open"`  // <- передаёт bool
}
```

**reporter-agent** ожидает (pkg/models/scan.go):
```go
type ScanResult struct {
    ScanID string `json:"scan_id"`  // <- ожидает "scan_id", не "id"
    State  string `json:"state"`    // <- ожидает "open"/"closed", не bool
}
```

**main-agent** также ожидает:
```go
type NATSScanResult struct {
    ScanID string `json:"scan_id"`  // <- несоответствие!
    State  string `json:"state"`    // <- несоответствие!
}
```

**Результат**: Все результаты сканирования теряются из-за неправильного unmarshaling.

### КРИТИЧЕСКИЙ БАГ #2: Несовместимость NATS протоколов

| Агент | Публикует | Подписывается |
|-------|-----------|---------------|
| scanner-agent | `nc.Publish` (Core NATS) | `nc.Subscribe` (Core NATS) |
| main-agent | `jsCtx.Publish` (JetStream) | `jsCtx.Subscribe` (JetStream) |
| analyzer-agent | `nc.Publish` (Core NATS) | `nc.Subscribe` (Core NATS) |
| reporter-agent | - | `nc.Subscribe` (Core NATS) |

**Проблема**: main-agent публикует через JetStream, но scanner-agent подписан на Core NATS. Сообщения могут не доходить корректно.

### ПРОБЛЕМА #3: Неоптимальные параметры

```go
// cmd/scanner-agent/main.go:18-24
const (
    portTimeout  = 1 * time.Second   // <- слишком медленно
    maxWorkers   = 10                // <- недостаточно для 15 портов
)
```

**Расчёт текущего времени**:
- 15 портов / 10 workers = 2 batch
- 2 batch × 1 сек timeout = ~2 сек минимум
- Реальность: 62.72 сек (таймауты на закрытых портах)

---

## План исправления

### ФАЗА 1: Исправление критических багов (ВЫСОКИЙ ПРИОРИТЕТ)

#### Agent A: Исправление scanner-agent/main.go

**Файл**: `cmd/scanner-agent/main.go`

**Изменение 1**: Исправить структуру ScanResult (строки 44-50)

```go
// БЫЛО:
type ScanResult struct {
    ID     string `json:"id"`
    Target string `json:"target"`
    Port   int    `json:"port"`
    IsOpen bool   `json:"is_open"`
    Error  string `json:"error,omitempty"`
}

// ДОЛЖНО БЫТЬ:
type ScanResult struct {
    ID     string `json:"id"`
    ScanID string `json:"scan_id"`   // + добавить
    Target string `json:"target"`
    Port   int    `json:"port"`
    State  string `json:"state"`     // изменить с IsOpen
    IsOpen bool   `json:"is_open"`   // оставить для совместимости
    Error  string `json:"error,omitempty"`
}
```

**Изменение 2**: Обновить функцию scanPort (строки 155-191)

```go
func (sa *ScannerAgent) scanPort(scanID, target string, port int) ScanResult {
    result := ScanResult{
        ID:     scanID,
        ScanID: scanID,        // + добавить
        Target: target,
        Port:   port,
        IsOpen: false,
        State:  "closed",      // + добавить
    }

    address := fmt.Sprintf("%s:%d", target, port)
    conn, err := net.DialTimeout("tcp", address, portTimeout)

    if err != nil {
        if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
            result.Error = "timeout"
            result.State = "filtered"   // + добавить
        } else {
            result.Error = "connection_refused"
            result.State = "closed"     // + добавить
        }
        // ... логирование
        return result
    }

    conn.Close()
    result.IsOpen = true
    result.State = "open"              // + добавить

    // ... логирование
    return result
}
```

#### Agent B: Унификация NATS протокола

**Вариант 1** (Рекомендуется): scanner-agent должен публиковать через JetStream

**Файл**: `cmd/scanner-agent/main.go`

```go
// Добавить JetStream контекст
type ScannerAgent struct {
    nc     *nats.Conn
    js     nats.JetStreamContext  // + добавить
    logger *logrus.Logger
    ctx    context.Context
    cancel context.CancelFunc
}

// В Connect():
func (sa *ScannerAgent) Connect() error {
    nc, err := nats.Connect(natsURL)
    if err != nil {
        return fmt.Errorf("failed to connect to NATS: %w", err)
    }
    sa.nc = nc

    // + Добавить JetStream
    js, err := nc.JetStream()
    if err != nil {
        return fmt.Errorf("failed to create JetStream context: %w", err)
    }
    sa.js = js

    sa.logger.WithField("url", natsURL).Info("Connected to NATS with JetStream")
    return nil
}

// В publishResult():
func (sa *ScannerAgent) publishResult(result ScanResult) error {
    data, err := json.Marshal(result)
    if err != nil {
        return fmt.Errorf("failed to marshal result: %w", err)
    }

    // Изменить на JetStream publish
    if _, err := sa.js.Publish(scanResult, data); err != nil {
        return fmt.Errorf("failed to publish result: %w", err)
    }
    // ...
}
```

**Вариант 2**: main-agent подписывается на Core NATS (проще, но менее надёжно)

#### Agent C: Проверка analyzer-agent

**Файл**: `cmd/analyzer-agent/main.go`

Analyzer корректно получает данные, но нужно убедиться что он обрабатывает оба поля:

```go
// Строка 108-122
func (sd *ServiceDetector) Subscribe() error {
    _, err := sd.nc.Subscribe("scan.result", func(msg *nats.Msg) {
        var result ScanResult
        if err := json.Unmarshal(msg.Data, &result); err != nil {
            log.WithError(err).Error("Failed to unmarshal scan result")
            return
        }

        // Изменить проверку:
        if result.IsOpen || result.State == "open" {  // <- поддержка обоих
            sd.wg.Add(1)
            go func() {
                defer sd.wg.Done()
                sd.detectService(result)
            }()
        }
    })
    // ...
}
```

---

### ФАЗА 2: Оптимизация параметров

#### Изменения в scanner-agent/main.go

**Файл**: `cmd/scanner-agent/main.go`

```go
// БЫЛО (строки 18-24):
const (
    natsURL      = "nats://localhost:4222"
    scanRequest  = "scan.request"
    scanResult   = "scan.result"
    maxWorkers   = 10
    portTimeout  = 1 * time.Second
)

// ДОЛЖНО БЫТЬ:
const (
    natsURL      = "nats://localhost:4222"
    scanRequest  = "scan.request"
    scanResult   = "scan.result"
    maxWorkers   = 100               // 10 → 100
    portTimeout  = 300 * time.Millisecond  // 1s → 300ms
)
```

**Ожидаемый результат**:
- 15 портов / 100 workers = 1 batch (все порты сканируются параллельно)
- 300ms × 1 = ~300ms минимум
- С учётом сетевой задержки: ~1-3 сек

#### Добавить улучшенное логирование

```go
func (sa *ScannerAgent) scanPorts(scanID, target string, ports []int) {
    startTime := time.Now()  // + добавить

    sa.logger.WithFields(logrus.Fields{
        "id":          scanID,
        "target":      target,
        "ports":       len(ports),
        "max_workers": maxWorkers,
        "timeout":     portTimeout,
    }).Info("Starting port scan")  // + улучшить лог

    // ... существующий код ...

    duration := time.Since(startTime)  // + добавить
    sa.logger.WithFields(logrus.Fields{
        "id":       scanID,
        "target":   target,
        "ports":    len(ports),
        "duration": duration,
    }).Info("Completed port scan")
}
```

---

### ФАЗА 3: Тестирование

#### Шаг 1: Запуск инфраструктуры
```bash
cd /home/madi/pentool
make docker-up
# или
docker-compose -f deployments/docker-compose.yml up -d
```

#### Шаг 2: Запуск агентов
```bash
# Терминал 1
go run cmd/main-agent/main.go

# Терминал 2
go run cmd/scanner-agent/main.go

# Терминал 3
go run cmd/analyzer-agent/main.go

# Терминал 4
go run cmd/reporter-agent/main.go
```

#### Шаг 3: Тестовый скан
```bash
# Pentool тест
time curl -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d '{"target":"scanme.nmap.org"}'

# Сохранить scan_id и проверить результат
curl http://localhost:8080/scan/{scan-id}
```

#### Шаг 4: Сравнение с nmap
```bash
time nmap -Pn -p 21,22,23,25,80,110,443,445,3306,3389,5432,6379,8080,8443,27017 scanme.nmap.org
```

---

### ФАЗА 4: Документация

#### Обновить benchmark_results/summary.json
```json
{
  "timestamp": "2025-12-10T...",
  "target": "scanme.nmap.org",
  "tests": {
    "pentool_common_ports_v2": {
      "time_ms": <новое значение>,
      "open_ports": <новое значение>,
      "scan_id": "<новый id>"
    },
    "nmap_common_ports": {
      "time_ms": 1018,
      "open_ports": 2
    }
  }
}
```

---

## Зависимости между агентами

```
ФАЗА 1 (параллельно):
├── Agent A: scanner-agent структуры
├── Agent B: NATS протокол
└── Agent C: analyzer-agent совместимость

ФАЗА 2 (после ФАЗЫ 1):
└── Оптимизация параметров

ФАЗА 3 (после ФАЗЫ 2):
└── Тестирование

ФАЗА 4 (параллельно с ФАЗОЙ 3):
└── Документация
```

---

## Checklist

- [ ] Исправить json tags в scanner-agent ScanResult
- [ ] Добавить поле State в scanner-agent
- [ ] Унифицировать NATS протокол (JetStream vs Core)
- [ ] Изменить portTimeout: 1s → 300ms
- [ ] Изменить maxWorkers: 10 → 100
- [ ] Добавить timing логи
- [ ] Тест на scanme.nmap.org
- [ ] Сравнить с nmap
- [ ] Обновить benchmark_results/

---

## Ожидаемые результаты после исправления

| Метрика | Было | Ожидается | Улучшение |
|---------|------|-----------|-----------|
| Время | 62.72 сек | 1-5 сек | 12-60x |
| Найдено портов | 0 | 2 | ✓ |
| Workers | 10 | 100 | 10x |
| Timeout | 1000ms | 300ms | 3.3x |