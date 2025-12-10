# 📚 Файлы для научной статьи - Полный список

## 📊 Результаты тестирования и анализа

### Основные отчёты:
```
benchmark_results/
├── PAPER_DATA_SUMMARY.md           ← 🌟 ГЛАВНЫЙ ФАЙЛ - вся сводка
├── detailed_research_report.txt    ← Подробный отчёт (13KB, ASCII таблицы)
├── research_summary.md             ← Краткая сводка (Markdown)
└── summary.json                    ← Данные в JSON формате
```

### Результаты тестов:
```
benchmark_results/
├── nmap_common.txt                 ← Результаты Nmap (15 портов)
├── nmap_common_time.txt            ← Метрики (время, память, CPU)
├── nmap_range.txt                  ← Результаты Nmap (1-100 портов)
├── nmap_range_time.txt             ← Метрики
├── nmap_service.txt                ← Определение сервисов
├── nmap_service_time.txt           ← Метрики
└── pentool_scan_results.json       ← Результаты Pentool
```

---

## 📝 Логи работы системы

```
logs/
├── main-agent.log                  ← Логи главного агента
├── scanner-agent.log               ← Логи сканера (найденные порты)
├── analyzer-agent.log              ← Логи анализатора (сервисы)
└── reporter-agent.log              ← Логи генератора отчётов
```

**Важные моменты в логах:**
- Scanner: "Found open port" port=22, port=80
- Analyzer: "Service detected" SSH, HTTP
- Main: "Successfully connected to PostgreSQL/NATS"

---

## 🗄️ База данных (Goose миграции)

```
migrations/
├── 00001_initial_schema.sql        ← Таблица scans
├── 00002_scan_results.sql          ← Таблица scan_results (с is_open)
└── 00003_service_info.sql          ← Таблица service_info
```

**Для статьи можно показать:**
- Применение миграций (`make migrate-status`)
- Схему таблиц (`\d scan_results`)

---

## 📸 Инструкции для скриншотов

```
SCREENSHOT_GUIDE.md                 ← Подробный гайд (27 скриншотов)
QUICK_START.md                      ← Быстрый старт (топ-10)
README_SCREENSHOTS.md               ← Итоговая инструкция
```

---

## 🔧 Скрипты

```
scripts/
├── demo_for_screenshots.sh         ← Интерактивный демо-скрипт
├── simple_benchmark.sh             ← Бенчмарк тесты
├── generate_text_report.py         ← Генератор отчётов
└── generate_paper_data.py          ← Генератор данных (с matplotlib)
```

---

## 📐 Архитектурные диаграммы

### ASCII диаграмма (в файлах):
- `benchmark_results/detailed_research_report.txt` (внутри)
- `SCREENSHOT_GUIDE.md` (скриншот 22)

### Текстовое описание архитектуры:
```
User → Main Agent (REST API :8080)
         ↓
      NATS (:4222)
         ↓
  ┌──────┴──────┬──────────┐
  ↓             ↓          ↓
Scanner    Analyzer    Reporter
  ↓             ↓          ↓
Results → NATS → PostgreSQL
```

---

## 📈 Ключевые метрики (для графиков)

### Из `summary.json`:
```json
{
  "execution_time_ms": {
    "pentool_common": 62722,
    "nmap_common": 1018,
    "nmap_range": 1351,
    "nmap_service": 9949
  },
  "memory_kb": {
    "nmap_common": 14560,
    "nmap_range": 14105,
    "nmap_service": 13824
  },
  "cpu_percent": {
    "nmap_common": 4,
    "nmap_range": 4,
    "nmap_service": 4
  }
}
```

### Сравнение скорости:
- Pentool: 62.72 секунды (15 портов)
- Nmap: 1.02 секунды (15 портов)
- Соотношение: Nmap быстрее в 61.5x раз

---

## 🎓 Структура для научной статьи

### Глава 1: Введение
**Файлы:**
- `README.md` - описание проекта
- `benchmark_results/PAPER_DATA_SUMMARY.md` - научная ценность

### Глава 2: Обзор литературы
**Данные:**
- Сравнение с Nmap (25+ лет)
- Сравнение с Masscan (10+ лет)
- Таблица функциональности (в detailed_research_report.txt)

### Глава 3: Реализация
**Файлы:**
- Архитектурная диаграмма
- Миграции БД (`migrations/*.sql`)
- Структура проекта (`cmd/`, `pkg/`)

**Скриншоты:**
- Docker контейнеры
- Миграции БД
- Схема таблиц

### Глава 4: Методология тестирования
**Файлы:**
- `scripts/simple_benchmark.sh` - методология
- `benchmark_results/summary.json` - параметры тестов

**Описание:**
- Цель тестирования: scanme.nmap.org
- Количество портов: 15 (общие) и 100 (диапазон)
- Метрики: время, память, CPU

### Глава 5: Результаты
**Файлы:**
- `benchmark_results/detailed_research_report.txt` (таблицы)
- `benchmark_results/research_summary.md` (краткие результаты)

**Скриншоты:**
- Работа агентов (логи)
- Результаты Pentool (JSON)
- Результаты Nmap
- Данные в PostgreSQL

**Графики (данные есть):**
- Сравнение времени выполнения
- Использование памяти
- Загрузка CPU

### Глава 6: Анализ и обсуждение
**Файлы:**
- `detailed_research_report.txt` - секция "Анализ результатов"
- Преимущества Pentool
- Области для улучшения

### Глава 7: Выводы
**Файлы:**
- `detailed_research_report.txt` - секция "Заключение"
- Use Cases
- Научная ценность

### Приложения
**Приложение А:** Архитектура
**Приложение Б:** Миграции БД
**Приложение В:** Логи работы системы
**Приложение Г:** Полные результаты тестов

---

## 📊 Таблицы для статьи (готовые)

### Таблица 1: Сравнение производительности
Файл: `benchmark_results/research_summary.md`

| Инструмент | Тест | Время (с) | Память (MB) | CPU (%) |
|------------|------|-----------|-------------|---------|
| Pentool | Общие порты (15) | 62.72 | - | - |
| Nmap | Общие порты (15) | 1.02 | 14.2 | 4 |
| Nmap | Диапазон 1-100 | 1.35 | 14.1 | 4 |
| Nmap | Определение сервисов | 9.95 | 13.8 | 4 |

### Таблица 2: Сравнение функциональности
Файл: `benchmark_results/detailed_research_report.txt`

| Функция | Pentool | Nmap | Masscan |
|---------|---------|------|---------|
| Сканирование портов | ✓ | ✓ | ✓ |
| REST API | ✓ | ✗ | ✗ |
| Распределенная архитектура | ✓ | ✗ | ✗ |
| Горизонтальное масштабирование | ✓ | ✗ | ✗ |
| Хранение в БД | ✓ | ✗ | ✗ |

### Таблица 3: Технологический стек
| Компонент | Технология | Версия |
|-----------|------------|--------|
| Язык программирования | Go | 1.19+ |
| Message Broker | NATS | 2.10 |
| База данных | PostgreSQL | 15 |
| Кэш | Redis | 7 |
| Контейнеризация | Docker | latest |

---

## 🔍 Цитаты для статьи

### Из логов (реальные):
```
"Successfully connected to PostgreSQL"
"Successfully connected to NATS"
"Found open port" port=22 target=scanme.nmap.org
"Service detected and published" service=SSH version="Ubuntu-2ubuntu2.13"
"Service detected and published" service=HTTP version="Apache/2.4.7"
```

### Из анализа:
> "Pentool представляет собой современный подход к разработке инструментов
> тестирования на проникновение, демонстрируя преимущества распределенной
> архитектуры и возможности языка Go."

---

## 💾 Как получить данные из БД (для статьи)

```bash
# Экспорт результатов в CSV
docker exec pentool-postgres psql -U admin -d pentool -c \
  "COPY (SELECT * FROM scans) TO STDOUT WITH CSV HEADER" > scans.csv

docker exec pentool-postgres psql -U admin -d pentool -c \
  "COPY (SELECT * FROM scan_results) TO STDOUT WITH CSV HEADER" > results.csv
```

---

## 📦 Создание архива для статьи

```bash
# Создать архив со всеми материалами
cd ~/pentool
tar -czf pentool_research_data.tar.gz \
  benchmark_results/ \
  logs/ \
  migrations/ \
  SCREENSHOT_GUIDE.md \
  PAPER_DATA_SUMMARY.md \
  README.md
```

---

## ✅ Чеклист готовности к написанию статьи

```
✅ Результаты тестирования собраны
✅ Логи работы системы сохранены
✅ Сравнение с Nmap/Masscan проведено
✅ Таблицы производительности созданы
✅ Архитектурные диаграммы готовы
✅ Миграции БД документированы
✅ Метрики и данные структурированы
✅ Инструкции для воспроизведения результатов написаны
✅ Выводы и рекомендации сформулированы
```

---

## 📞 Быстрый доступ к ключевым файлам

```bash
# Главный файл со всеми данными
cat benchmark_results/PAPER_DATA_SUMMARY.md

# Детальный отчёт
cat benchmark_results/detailed_research_report.txt

# Краткая сводка
cat benchmark_results/research_summary.md

# Данные в JSON
cat benchmark_results/summary.json | jq .

# Логи
tail -100 logs/scanner-agent.log
tail -100 logs/analyzer-agent.log
```

---

**🎓 Все материалы готовы для научной статьи!**
