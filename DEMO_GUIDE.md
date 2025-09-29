# 🚀 Pentool Demo Guide - Быстрый запуск для демонстрации

## 📋 Что готово к демонстрации

✅ **Полная система создана:**
- Main Agent (REST API координатор)
- Scanner Agent (TCP сканер портов)
- Analyzer Agent (определение сервисов)
- Reporter Agent (генерация отчетов)
- PostgreSQL, NATS, Redis
- Скрипты автоматизации

## 🎯 Демонстрация в 3 шага

### 1. Запуск системы (2 минуты)
```bash
# Стартуем всю систему одной командой
./scripts/start-system.sh
```
**Что произойдет:**
- Запустятся Docker контейнеры (PostgreSQL, NATS, Redis)
- Инициализируется база данных
- Соберутся все агенты
- Запустятся 4 агента в фоне
- API станет доступно на http://localhost:8080

### 2. Интерактивная демонстрация (5-10 минут)
```bash
# Полная демонстрация с пояснениями
./scripts/demo.sh
```
**Что покажет:**
- Проверку здоровья системы
- Запуск сканирования scanme.nmap.org
- Мониторинг прогресса в реальном времени
- Результаты сканирования
- Обнаруженные сервисы
- Сгенерированные отчеты
- Архитектуру системы

### 3. Тестирование API (2 минуты)
```bash
# Автоматические тесты всех endpoints
./scripts/test-api.sh
```

## 🎓 Для защиты диссертации

### Ключевые демонстрируемые технологии:

**1. Go Concurrency (горутины)**
```go
// Параллельное сканирование портов
for _, port := range ports {
    semaphore <- struct{}{} // Ограничение до 10 одновременно
    go func(p int) {
        defer func() { <-semaphore }()
        scanPort(target, p) // Сканирование порта
    }(port)
}
```

**2. Микросервисная архитектура**
- Main Agent ← HTTP ← Пользователи
- Scanner ↔ NATS ↔ Analyzer ↔ Reporter
- PostgreSQL для персистентности

**3. Message-Driven Architecture**
```go
// NATS pub/sub коммуникация
nats.Publish("scan.request", scanData)
nats.Subscribe("scan.result", handleResult)
```

### Научная ценность проекта:

**Производительность:**
- 20 портов сканируются за ~5-15 секунд
- Параллельные goroutines
- Неблокирующий I/O

**Масштабируемость:**
- Горизонтальное масштабирование агентов
- Message queue для distributed processing
- Database persistence

**Сравнение с существующими:**
- Nmap: монолитный C++
- Masscan: single-threaded scanner
- Pentool: distributed Go microservices

## 📊 Метрики для диссертации

После запуска демо собери эти данные:

```bash
# Время сканирования
curl http://localhost:8080/scan/{scan-id} | jq '.created_at, .completed_at'

# Количество обнаруженных сервисов
docker exec pentool-postgres psql -U admin -d pentool -c "SELECT COUNT(*) FROM services;"

# Статистика производительности
docker exec pentool-postgres psql -U admin -d pentool -c "
SELECT
  target,
  total_ports,
  open_ports,
  EXTRACT(EPOCH FROM (completed_at - created_at)) as duration_seconds
FROM scans
ORDER BY created_at DESC LIMIT 5;"
```

## 🛑 Остановка системы
```bash
./scripts/stop-system.sh
```

## 🔍 Troubleshooting

**Если что-то не работает:**
```bash
# Перезапуск системы
./scripts/stop-system.sh
./scripts/start-system.sh

# Проверка логов
tail -f logs/main-agent.log
tail -f logs/scanner-agent.log

# Проверка Docker сервисов
docker ps
docker logs pentool-postgres
```

## 🎯 Основные команды для демо

```bash
# Быстрый тест API
curl http://localhost:8080/health

# Запустить сканирование
curl -X POST http://localhost:8080/scan \
  -H "Content-Type: application/json" \
  -d '{"target":"scanme.nmap.org"}'

# Проверить результаты (замени {scan-id})
curl http://localhost:8080/scan/{scan-id}

# Мониторинг NATS сообщений
docker exec -it pentool-nats nats sub 'scan.*'
```

---

**✨ Основная фишка проекта:** Демонстрирует современные Go паттерны для создания production-ready инструментов безопасности с микросервисной архитектурой!