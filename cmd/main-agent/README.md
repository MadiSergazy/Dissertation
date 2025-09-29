# Main Agent - Penetration Testing Tool

## Описание

Main Agent - центральный компонент системы для проведения тестирования на проникновение. Предоставляет REST API для управления сканированием портов и координирует работу других агентов через NATS.

## API Endpoints

### 1. POST /scan - Начать сканирование

**Request:**
```json
{
  "target": "192.168.1.1",
  "ports": [80, 443, 8080]  // Опционально
}
```

**Response:**
```json
{
  "id": "uuid-scan-id",
  "target": "192.168.1.1",
  "status": "pending",
  "message": "Scan queued successfully",
  "created_at": "2025-09-29T10:00:00Z"
}
```

### 2. GET /scan/:id - Получить статус сканирования

**Response:**
```json
{
  "id": "uuid-scan-id",
  "target": "192.168.1.1",
  "status": "completed",
  "total_ports": 3,
  "open_ports": 2,
  "created_at": "2025-09-29T10:00:00Z",
  "updated_at": "2025-09-29T10:05:00Z",
  "completed_at": "2025-09-29T10:05:00Z",
  "results": [
    {
      "port": 80,
      "state": "open",
      "service": "http",
      "version": "nginx/1.18.0"
    }
  ]
}
```

### 3. GET /health - Проверка здоровья

**Response:**
```json
{
  "status": "healthy",
  "database": true,
  "nats": true
}
```

## Запуск

### 1. Через Docker Compose
```bash
make dev        # Полная настройка окружения
make run        # Запуск только Main Agent
```

### 2. Локальный запуск
```bash
# Установка зависимостей
go mod download

# Запуск сервисов
docker-compose -f deployments/docker-compose.yml up -d

# Инициализация БД
psql -U postgres -d pentool_db < scripts/init_db.sql

# Запуск агента
go run cmd/main-agent/main.go
```

## Конфигурация

Переменные окружения:
- `HTTP_PORT` - Порт для REST API (по умолчанию: 8080)
- `DATABASE_URL` - Строка подключения к PostgreSQL
- `NATS_URL` - URL для подключения к NATS

## Архитектура

Main Agent выполняет следующие функции:
1. Принимает HTTP запросы на сканирование
2. Сохраняет задачи в PostgreSQL
3. Отправляет задачи в NATS топик `scan.request`
4. Слушает результаты из топика `scan.result`
5. Обновляет статус сканирования в БД

## База данных

Схема БД включает:
- `scans` - Основная информация о сканировании
- `scan_results` - Результаты сканирования портов
- `service_info` - Информация об обнаруженных сервисах

## Интеграция с NATS

- **Публикация**: `scan.request` - задачи на сканирование
- **Подписка**: `scan.result` - результаты сканирования

## Безопасность

- CORS headers включены для всех endpoints
- Валидация входных данных
- Транзакции БД для консистентности данных
- Graceful shutdown при остановке