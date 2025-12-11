# Tools & Architecture Analysis

## Почему Golang для Security Tools

### Преимущества Go:
- Компиляция в статический бинарник (легко деплоить)
- Высокая производительность (близко к C)
- Отличная поддержка concurrency (goroutines)
- Кроссплатформенная компиляция
- Богатая стандартная библиотека (net, crypto)

### Популярные Security Tools на Go:
- **Nuclei** - vulnerability scanner
- **ffuf** - web fuzzer
- **gobuster** - directory/DNS bruteforcer
- **Amass** - OSINT/subdomain enumeration
- **Naabu** - port scanner

## Архитектура Pentool

### Выбранная категория:
**Distributed Port Scanner + Service Detection**

Комбинирует:
- Port scanning (как nmap/masscan)
- Service detection/fingerprinting
- Distributed processing (unique feature)

### Архитектура Multi-Agent:
```
┌─────────────────────────────────────────────────────────┐
│                      Users/CLI                           │
└─────────────────────────┬───────────────────────────────┘
                          │ HTTP
                          ▼
┌─────────────────────────────────────────────────────────┐
│              Main Agent (REST API :8080)                 │
│  - Receives scan requests                                │
│  - Manages scan lifecycle                                │
│  - Returns results                                       │
└─────────────────────────┬───────────────────────────────┘
                          │ NATS Pub/Sub
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  Scanner    │   │  Analyzer   │   │  Reporter   │
│   Agent     │   │   Agent     │   │   Agent     │
│             │   │             │   │             │
│ Port Scan   │──►│ Service     │──►│ Store to    │
│ TCP/UDP     │   │ Detection   │   │ PostgreSQL  │
└─────────────┘   └─────────────┘   └─────────────┘
```

### Ключевые паттерны Go:
1. **Goroutines** - concurrent port scanning
2. **Channels** - safe data passing between goroutines
3. **Context** - timeout and cancellation
4. **Worker Pool** - rate limiting scans
5. **Interface-based design** - pluggable agents

## Сравнение с альтернативами
| Аспект | Go | Python | Rust |
|--------|----|---------|----- |
| Скорость | Высокая | Средняя | Очень высокая |
| Простота | Высокая | Очень высокая | Низкая |
| Бинарники | Да | Нет | Да |
| Экосистема security | Растущая | Большая | Малая |

