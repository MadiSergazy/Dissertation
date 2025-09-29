#!/usr/bin/env python3
"""
Text-based Research Report Generator (no matplotlib required)
Creates comprehensive text analysis for scientific paper
"""

import json
import re
import os

class TextReportGenerator:
    def __init__(self, results_dir='benchmark_results'):
        self.results_dir = results_dir
        self.data = {}

    def load_summary(self):
        """Load summary.json with benchmark results"""
        try:
            with open(f'{self.results_dir}/summary.json', 'r') as f:
                self.data = json.load(f)
            print("✓ Loaded benchmark summary")
            return True
        except FileNotFoundError:
            print("✗ Error: summary.json not found. Run benchmark first.")
            return False

    def parse_time_metrics(self, filename):
        """Parse /usr/bin/time output"""
        metrics = {}
        try:
            with open(filename, 'r') as f:
                content = f.read()

            time_match = re.search(r'Time: (.+)', content)
            if time_match:
                metrics['time_str'] = time_match.group(1)

            mem_match = re.search(r'Memory: (\d+) KB', content)
            if mem_match:
                metrics['memory_kb'] = int(mem_match.group(1))

            cpu_match = re.search(r'CPU: (\d+)%', content)
            if cpu_match:
                metrics['cpu_percent'] = int(cpu_match.group(1))

        except FileNotFoundError:
            pass

        return metrics

    def generate_report(self):
        """Generate comprehensive text report"""

        if not self.load_summary():
            return False

        tests = self.data.get('tests', {})

        # Parse metrics
        nmap_common_m = self.parse_time_metrics(f'{self.results_dir}/nmap_common_time.txt')
        nmap_range_m = self.parse_time_metrics(f'{self.results_dir}/nmap_range_time.txt')
        nmap_service_m = self.parse_time_metrics(f'{self.results_dir}/nmap_service_time.txt')

        report = []
        report.append("="*80)
        report.append("  РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ PENTOOL")
        report.append("  Исследование инструментов тестирования на проникновение на Go")
        report.append("="*80)
        report.append("")
        report.append(f"Дата тестирования: {self.data.get('timestamp', 'N/A')}")
        report.append(f"Цель тестирования: {self.data.get('target', 'N/A')}")
        report.append("")

        report.append("="*80)
        report.append("1. СРАВНИТЕЛЬНАЯ ТАБЛИЦА ПРОИЗВОДИТЕЛЬНОСТИ")
        report.append("="*80)
        report.append("")

        # Table header
        report.append("┌─────────────┬──────────────────────┬───────────┬──────────┬──────────┬─────────────┬─────────┐")
        report.append("│ Инструмент  │ Тест                 │ Время (мс)│ Время (с)│ Найдено  │ Память (MB) │ CPU (%) │")
        report.append("├─────────────┼──────────────────────┼───────────┼──────────┼──────────┼─────────────┼─────────┤")

        # Pentool
        pentool = tests.get('pentool_common_ports', {})
        report.append(f"│ Pentool     │ Общие порты (15)     │ {pentool.get('time_ms', 0):>9} │ {pentool.get('time_ms', 0)/1000:>8.2f} │ {pentool.get('open_ports', 0):>8} │ {'-':>11} │ {'-':>7} │")

        # Nmap common
        nmap_common = tests.get('nmap_common_ports', {})
        report.append(f"│ Nmap        │ Общие порты (15)     │ {nmap_common.get('time_ms', 0):>9} │ {nmap_common.get('time_ms', 0)/1000:>8.2f} │ {nmap_common.get('open_ports', 0):>8} │ {nmap_common_m.get('memory_kb', 0)/1024:>11.1f} │ {nmap_common_m.get('cpu_percent', 0):>7} │")

        # Nmap range
        nmap_range = tests.get('nmap_port_range_1_100', {})
        report.append(f"│ Nmap        │ Диапазон 1-100       │ {nmap_range.get('time_ms', 0):>9} │ {nmap_range.get('time_ms', 0)/1000:>8.2f} │ {nmap_range.get('open_ports', 0):>8} │ {nmap_range_m.get('memory_kb', 0)/1024:>11.1f} │ {nmap_range_m.get('cpu_percent', 0):>7} │")

        # Nmap service
        nmap_service = tests.get('nmap_service_detection', {})
        report.append(f"│ Nmap -sV    │ Определение сервисов │ {nmap_service.get('time_ms', 0):>9} │ {nmap_service.get('time_ms', 0)/1000:>8.2f} │ {'-':>8} │ {nmap_service_m.get('memory_kb', 0)/1024:>11.1f} │ {nmap_service_m.get('cpu_percent', 0):>7} │")

        report.append("└─────────────┴──────────────────────┴───────────┴──────────┴──────────┴─────────────┴─────────┘")
        report.append("")

        report.append("="*80)
        report.append("2. АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ")
        report.append("="*80)
        report.append("")

        # Speed Analysis
        report.append("2.1. Скорость сканирования")
        report.append("-" * 80)
        pentool_time = pentool.get('time_ms', 0) / 1000
        nmap_time = nmap_common.get('time_ms', 0) / 1000

        if nmap_time > 0:
            ratio = pentool_time / nmap_time
            report.append(f"  Pentool:      {pentool_time:>6.2f} секунд")
            report.append(f"  Nmap:         {nmap_time:>6.2f} секунд")
            report.append(f"  Соотношение:  Pentool медленнее в {ratio:.1f}x раз")
            report.append("")
            report.append("  Причины:")
            report.append("  • Overhead распределенной архитектуры (NATS messaging)")
            report.append("  • Timeout = 1 секунда на порт (можно оптимизировать)")
            report.append("  • База данных overhead (PostgreSQL INSERT операции)")
            report.append("")

        # Resource usage
        report.append("2.2. Использование ресурсов")
        report.append("-" * 80)
        report.append("")
        report.append("Память (Memory):")
        report.append(f"  Nmap (общие порты):        {nmap_common_m.get('memory_kb', 0)/1024:>6.1f} MB")
        report.append(f"  Nmap (диапазон 1-100):     {nmap_range_m.get('memory_kb', 0)/1024:>6.1f} MB")
        report.append(f"  Nmap (определение сервисов): {nmap_service_m.get('memory_kb', 0)/1024:>6.1f} MB")
        report.append("")
        report.append("Загрузка CPU:")
        report.append(f"  Nmap (общие порты):        {nmap_common_m.get('cpu_percent', 0):>6}%")
        report.append(f"  Nmap (диапазон 1-100):     {nmap_range_m.get('cpu_percent', 0):>6}%")
        report.append(f"  Nmap (определение сервисов): {nmap_service_m.get('cpu_percent', 0):>6}%")
        report.append("")

        # Accuracy
        report.append("2.3. Точность обнаружения")
        report.append("-" * 80)
        report.append(f"  Pentool нашел: {pentool.get('open_ports', 0)} открытых портов")
        report.append(f"  Nmap нашел:    {nmap_common.get('open_ports', 0)} открытых портов")
        report.append("")
        if pentool.get('open_ports', 0) < nmap_common.get('open_ports', 0):
            report.append("  ⚠ Pentool пропустил некоторые открытые порты")
            report.append("    Возможные причины:")
            report.append("    • Короткий timeout (1 сек)")
            report.append("    • Проблемы с сетевой задержкой")
            report.append("    • Firewall фильтрация")
        report.append("")

        report.append("="*80)
        report.append("3. АРХИТЕКТУРНЫЕ ОСОБЕННОСТИ PENTOOL")
        report.append("="*80)
        report.append("")

        report.append("3.1. Мульти-агентная архитектура")
        report.append("-" * 80)
        report.append("")
        report.append("  ┌──────────────────┐")
        report.append("  │  User / Client   │")
        report.append("  └────────┬─────────┘")
        report.append("           │ HTTP REST API")
        report.append("           ▼")
        report.append("  ┌──────────────────┐")
        report.append("  │   Main Agent     │ ◄─── Координация и API")
        report.append("  │   (port :8080)   │")
        report.append("  └────────┬─────────┘")
        report.append("           │ NATS Pub/Sub")
        report.append("           ▼")
        report.append("  ┌──────────────────────────────────────┐")
        report.append("  │    NATS Message Broker (:4222)       │")
        report.append("  └───┬──────────────┬──────────────┬────┘")
        report.append("      │              │              │")
        report.append("      ▼              ▼              ▼")
        report.append("  ┌────────┐    ┌────────┐    ┌──────────┐")
        report.append("  │Scanner │    │Analyzer│    │ Reporter │")
        report.append("  │ Agent  │    │ Agent  │    │  Agent   │")
        report.append("  └────────┘    └────────┘    └─────┬────┘")
        report.append("                                     │")
        report.append("                                     ▼")
        report.append("                               ┌──────────┐")
        report.append("                               │PostgreSQL│")
        report.append("                               └──────────┘")
        report.append("")

        report.append("3.2. Компоненты системы")
        report.append("-" * 80)
        report.append("")
        report.append("  1) Main Agent:")
        report.append("     • REST API сервер (порт 8080)")
        report.append("     • Управление задачами сканирования")
        report.append("     • Взаимодействие с БД (PostgreSQL)")
        report.append("")
        report.append("  2) Scanner Agent:")
        report.append("     • Параллельное сканирование портов (10 workers)")
        report.append("     • TCP connect для определения открытых портов")
        report.append("     • Публикация результатов в NATS")
        report.append("")
        report.append("  3) Analyzer Agent:")
        report.append("     • Определение сервисов по баннерам")
        report.append("     • Идентификация версий")
        report.append("     • Fingerprinting")
        report.append("")
        report.append("  4) Reporter Agent:")
        report.append("     • Агрегация результатов")
        report.append("     • Генерация отчетов (JSON)")
        report.append("     • Сохранение в PostgreSQL")
        report.append("")

        report.append("="*80)
        report.append("4. СРАВНЕНИЕ ФУНКЦИОНАЛЬНОСТИ")
        report.append("="*80)
        report.append("")

        report.append("┌───────────────────────────────────┬─────────┬──────┬─────────┐")
        report.append("│ Функция                           │ Pentool │ Nmap │ Masscan │")
        report.append("├───────────────────────────────────┼─────────┼──────┼─────────┤")
        report.append("│ Сканирование портов               │    ✓    │  ✓   │    ✓    │")
        report.append("│ Определение сервисов              │    ✓    │  ✓   │    ✗    │")
        report.append("│ REST API                          │    ✓    │  ✗   │    ✗    │")
        report.append("│ Распределенная архитектура        │    ✓    │  ✗   │    ✗    │")
        report.append("│ Горизонтальное масштабирование    │    ✓    │  ✗   │    ✗    │")
        report.append("│ Асинхронная обработка             │    ✓    │  ✗   │    ✓    │")
        report.append("│ Хранение результатов в БД         │    ✓    │  ✗   │    ✗    │")
        report.append("│ Сверхбыстрое сканирование         │    ✗    │  ✗   │    ✓    │")
        report.append("│ OS Detection                      │    ✗    │  ✓   │    ✗    │")
        report.append("│ NSE Scripts                       │    ✗    │  ✓   │    ✗    │")
        report.append("│ Зрелость проекта                  │  Новый  │ 25+  │   10+   │")
        report.append("└───────────────────────────────────┴─────────┴──────┴─────────┘")
        report.append("")

        report.append("="*80)
        report.append("5. ВЫВОДЫ И РЕКОМЕНДАЦИИ")
        report.append("="*80)
        report.append("")

        report.append("5.1. Преимущества Pentool")
        report.append("-" * 80)
        report.append("")
        report.append("  ✓ Современная архитектура:")
        report.append("    - Мульти-агентная распределенная система")
        report.append("    - Асинхронная обработка через NATS")
        report.append("    - Микросервисный подход")
        report.append("")
        report.append("  ✓ Масштабируемость:")
        report.append("    - Горизонтальное масштабирование агентов")
        report.append("    - Независимое развертывание компонентов")
        report.append("    - Message-driven коммуникация")
        report.append("")
        report.append("  ✓ Интеграция:")
        report.append("    - RESTful API для внешних систем")
        report.append("    - PostgreSQL для централизованного хранения")
        report.append("    - Docker containerization")
        report.append("")
        report.append("  ✓ Современные паттерны Go:")
        report.append("    - Goroutines для параллелизма")
        report.append("    - Channels для синхронизации")
        report.append("    - Context для управления жизненным циклом")
        report.append("")

        report.append("5.2. Области для улучшения")
        report.append("-" * 80)
        report.append("")
        report.append("  ⚠ Производительность:")
        report.append("    - Оптимизация timeout (adaptive timeout)")
        report.append("    - Увеличение maxWorkers (dynamic scaling)")
        report.append("    - Батчинг операций БД")
        report.append("")
        report.append("  ⚠ Точность:")
        report.append("    - Улучшение алгоритмов обнаружения")
        report.append("    - Повторные попытки для неустойчивых портов")
        report.append("    - SYN сканирование (требует привилегий)")
        report.append("")
        report.append("  ⚠ Функциональность:")
        report.append("    - OS fingerprinting")
        report.append("    - Vulnerability scanning")
        report.append("    - Custom scripts support")
        report.append("")

        report.append("5.3. Use Cases для Pentool")
        report.append("-" * 80)
        report.append("")
        report.append("  Подходит для:")
        report.append("  • Корпоративные Security Operations Centers (SOC)")
        report.append("  • Непрерывный мониторинг сетевой безопасности")
        report.append("  • Интеграция в DevSecOps pipeline")
        report.append("  • Масштабируемые сканирования больших сетей")
        report.append("  • Централизованное управление и отчетность")
        report.append("")
        report.append("  Не подходит для:")
        report.append("  • Ad-hoc быстрые проверки (Nmap быстрее)")
        report.append("  • Массовые интернет-сканирования (Masscan эффективнее)")
        report.append("  • Детальный анализ одиночных хостов")
        report.append("")

        report.append("="*80)
        report.append("6. НАУЧНАЯ ЦЕННОСТЬ ИССЛЕДОВАНИЯ")
        report.append("="*80)
        report.append("")

        report.append("  Данная работа демонстрирует:")
        report.append("")
        report.append("  1. Применение Go в разработке инструментов безопасности")
        report.append("     - Эффективное использование concurrency")
        report.append("     - Низкий memory footprint")
        report.append("     - Быстрая компиляция и развертывание")
        report.append("")
        report.append("  2. Современные архитектурные паттерны")
        report.append("     - Микросервисы")
        report.append("     - Event-driven architecture")
        report.append("     - CQRS (Command Query Responsibility Segregation)")
        report.append("")
        report.append("  3. Практическое сравнение с индустриальными стандартами")
        report.append("     - Объективная оценка производительности")
        report.append("     - Анализ trade-offs")
        report.append("     - Рекомендации по применению")
        report.append("")

        report.append("="*80)
        report.append("ЗАКЛЮЧЕНИЕ")
        report.append("="*80)
        report.append("")
        report.append("Pentool представляет собой современный подход к разработке инструментов")
        report.append("тестирования на проникновение, демонстрируя преимущества распределенной")
        report.append("архитектуры и возможности языка Go. Несмотря на текущие ограничения в")
        report.append("скорости сканирования по сравнению с Nmap, проект показывает потенциал")
        report.append("для масштабируемых корпоративных решений и интеграции в современные")
        report.append("DevSecOps процессы.")
        report.append("")
        report.append("="*80)

        # Write report
        report_text = '\n'.join(report)
        with open(f'{self.results_dir}/detailed_research_report.txt', 'w', encoding='utf-8') as f:
            f.write(report_text)

        print("\n" + report_text)
        print(f"\n✓ Report saved to: {self.results_dir}/detailed_research_report.txt")

        # Also create markdown version
        self._create_markdown_report(tests, nmap_common_m, nmap_range_m, nmap_service_m)

        return True

    def _create_markdown_report(self, tests, nmap_common_m, nmap_range_m, nmap_service_m):
        """Create markdown version for easier reading"""

        md = []
        md.append("# Результаты тестирования Pentool")
        md.append("")
        md.append(f"**Дата:** {self.data.get('timestamp', 'N/A')}  ")
        md.append(f"**Цель:** {self.data.get('target', 'N/A')}  ")
        md.append("")

        md.append("## 1. Сравнительная таблица производительности")
        md.append("")
        md.append("| Инструмент | Тест | Время (мс) | Время (с) | Найдено | Память (MB) | CPU (%) |")
        md.append("|------------|------|------------|-----------|---------|-------------|---------|")

        pentool = tests.get('pentool_common_ports', {})
        md.append(f"| Pentool | Общие порты (15) | {pentool.get('time_ms', 0)} | {pentool.get('time_ms', 0)/1000:.2f} | {pentool.get('open_ports', 0)} | - | - |")

        nmap_common = tests.get('nmap_common_ports', {})
        md.append(f"| Nmap | Общие порты (15) | {nmap_common.get('time_ms', 0)} | {nmap_common.get('time_ms', 0)/1000:.2f} | {nmap_common.get('open_ports', 0)} | {nmap_common_m.get('memory_kb', 0)/1024:.1f} | {nmap_common_m.get('cpu_percent', 0)} |")

        nmap_range = tests.get('nmap_port_range_1_100', {})
        md.append(f"| Nmap | Диапазон 1-100 | {nmap_range.get('time_ms', 0)} | {nmap_range.get('time_ms', 0)/1000:.2f} | {nmap_range.get('open_ports', 0)} | {nmap_range_m.get('memory_kb', 0)/1024:.1f} | {nmap_range_m.get('cpu_percent', 0)} |")

        nmap_service = tests.get('nmap_service_detection', {})
        md.append(f"| Nmap -sV | Определение сервисов | {nmap_service.get('time_ms', 0)} | {nmap_service.get('time_ms', 0)/1000:.2f} | - | {nmap_service_m.get('memory_kb', 0)/1024:.1f} | {nmap_service_m.get('cpu_percent', 0)} |")

        md.append("")
        md.append("## 2. Преимущества Pentool")
        md.append("")
        md.append("- ✓ Мульти-агентная распределенная архитектура")
        md.append("- ✓ Асинхронная обработка через NATS")
        md.append("- ✓ Горизонтальная масштабируемость")
        md.append("- ✓ RESTful API")
        md.append("- ✓ PostgreSQL для хранения")
        md.append("- ✓ Современные паттерны Go")
        md.append("")

        md.append("## 3. Области для улучшения")
        md.append("")
        md.append("- ⚠ Скорость сканирования (оптимизация timeout)")
        md.append("- ⚠ Параллелизм (увеличение workers)")
        md.append("- ⚠ Точность обнаружения")
        md.append("")

        with open(f'{self.results_dir}/research_summary.md', 'w', encoding='utf-8') as f:
            f.write('\n'.join(md))

        print(f"✓ Markdown report saved to: {self.results_dir}/research_summary.md")


if __name__ == '__main__':
    generator = TextReportGenerator()
    generator.generate_report()