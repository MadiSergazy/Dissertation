# Dissertation Knowledge Base

## Тема диссертации
**Research on Security Tools using Golang for Penetration Testing**

## Требования к объёму

| Раздел | Мин. слов | Страниц |
|--------|-----------|---------|
| Cover | 0 | 1 |
| Title page | 0 | 1 |
| Content | 0 | 1-5 |
| Introduction | 100 | 2-50 |
| Main part | 1000 | 30-100 |
| Conclusion | 100 | 1-30 |
| Normative references | 0 | 1-5 |
| Приложения | 0 | 1-10 |
| List of used sources | 0 | 1-5 |

## Фокус исследования
- **Тип работы:** Разработка собственного security-инструмента на Golang
- **Категория:** Distributed Port Scanner + Service Detection
- **Название инструмента:** Pentool
- **GitHub:** https://github.com/MadiSergazy/Dissertation

## Архитектура Pentool (Multi-Agent)
```
Main Agent (REST API :8080) ← HTTP ← Users
     ↕ NATS
Scanner Agent → Port Scanning → Results
     ↕ NATS
Analyzer Agent → Service Detection → Info
     ↕ NATS
Reporter Agent → JSON Reports → PostgreSQL
```

## Технологии
- Go 1.24+
- NATS (messaging)
- PostgreSQL (persistence)
- Docker & Docker Compose
- Goroutines (concurrency)

## Ключевые особенности
- 🔄 Multi-Agent distributed system
- 🚀 Concurrent Go goroutines scanning
- 📨 NATS message-driven communication
- 💾 PostgreSQL data persistence
- 🔍 Automated service detection
- 🐳 Docker containerized deployment

## Инструкции для Claude Code агента

### При каждой новой сессии:
1. Прочитай все файлы в папке `dissertation-knowledge/`
2. Обнови `PROGRESS.md` с текущим состоянием кода
3. Добавь новые заметки в соответствующие файлы

### Структура папки:
- `CONTEXT.md` - этот файл, общий контекст
- `PROGRESS.md` - прогресс разработки, что сделано
- `TOOLS-ANALYSIS.md` - анализ архитектуры, паттернов
- `RESEARCH-NOTES.md` - заметки для теоретической части
- `CODE-DOCS.md` - документация кода для приложений

## Контакт между сессиями
Этот knowledge base служит "памятью" между сессиями Claude Code и Claude Chat.
При обновлении важной информации - обновляй соответствующий файл.

---
*Последнее обновление: создано*
