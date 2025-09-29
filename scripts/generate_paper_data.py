#!/usr/bin/env python3
"""
Research Paper Data Generator
Creates comprehensive analysis with charts, tables, and diagrams for scientific paper
"""

import json
import re
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
from datetime import datetime
import os
import sys

# Set matplotlib to use non-interactive backend
plt.switch_backend('Agg')

# Set Russian font support
plt.rcParams['font.family'] = 'DejaVu Sans'

class ResearchDataGenerator:
    def __init__(self, results_dir='benchmark_results'):
        self.results_dir = results_dir
        self.data = {}

        # Create output directory
        os.makedirs(results_dir, exist_ok=True)

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

            # Extract time
            time_match = re.search(r'Time: (.+)', content)
            if time_match:
                time_str = time_match.group(1)
                metrics['time_str'] = time_str

            # Extract memory
            mem_match = re.search(r'Memory: (\d+) KB', content)
            if mem_match:
                metrics['memory_kb'] = int(mem_match.group(1))

            # Extract CPU
            cpu_match = re.search(r'CPU: (\d+)%', content)
            if cpu_match:
                metrics['cpu_percent'] = int(cpu_match.group(1))

        except FileNotFoundError:
            print(f"Warning: {filename} not found")

        return metrics

    def create_comparison_table_md(self):
        """Generate comprehensive comparison table in markdown"""

        tests = self.data.get('tests', {})

        table = "# Результаты тестирования Pentool\n\n"
        table += f"**Дата тестирования:** {self.data.get('timestamp', 'N/A')}  \n"
        table += f"**Цель тестирования:** {self.data.get('target', 'N/A')}  \n\n"

        table += "## 1. Сравнительная таблица производительности\n\n"
        table += "| Инструмент | Тест | Время (мс) | Время (с) | Найдено портов | Память (MB) | CPU (%) |\n"
        table += "|------------|------|------------|-----------|----------------|-------------|----------|\n"

        # Pentool common ports
        pentool = tests.get('pentool_common_ports', {})
        table += f"| **Pentool** | Общие порты (15) | {pentool.get('time_ms', 'N/A')} | "
        table += f"{pentool.get('time_ms', 0)/1000:.2f} | {pentool.get('open_ports', 'N/A')} | - | - |\n"

        # Nmap common ports
        nmap_common = tests.get('nmap_common_ports', {})
        nmap_common_metrics = self.parse_time_metrics(f'{self.results_dir}/nmap_common_time.txt')
        table += f"| **Nmap** | Общие порты (15) | {nmap_common.get('time_ms', 'N/A')} | "
        table += f"{nmap_common.get('time_ms', 0)/1000:.2f} | {nmap_common.get('open_ports', 'N/A')} | "
        table += f"{nmap_common_metrics.get('memory_kb', 0)/1024:.1f} | "
        table += f"{nmap_common_metrics.get('cpu_percent', 'N/A')} |\n"

        # Nmap port range
        nmap_range = tests.get('nmap_port_range_1_100', {})
        nmap_range_metrics = self.parse_time_metrics(f'{self.results_dir}/nmap_range_time.txt')
        table += f"| **Nmap** | Диапазон 1-100 | {nmap_range.get('time_ms', 'N/A')} | "
        table += f"{nmap_range.get('time_ms', 0)/1000:.2f} | {nmap_range.get('open_ports', 'N/A')} | "
        table += f"{nmap_range_metrics.get('memory_kb', 0)/1024:.1f} | "
        table += f"{nmap_range_metrics.get('cpu_percent', 'N/A')} |\n"

        # Nmap service detection
        nmap_service = tests.get('nmap_service_detection', {})
        nmap_service_metrics = self.parse_time_metrics(f'{self.results_dir}/nmap_service_time.txt')
        table += f"| **Nmap -sV** | Определение сервисов | {nmap_service.get('time_ms', 'N/A')} | "
        table += f"{nmap_service.get('time_ms', 0)/1000:.2f} | - | "
        table += f"{nmap_service_metrics.get('memory_kb', 0)/1024:.1f} | "
        table += f"{nmap_service_metrics.get('cpu_percent', 'N/A')} |\n"

        table += "\n## 2. Анализ результатов\n\n"
        table += "### 2.1 Скорость сканирования\n\n"

        pentool_time = pentool.get('time_ms', 0) / 1000
        nmap_time = nmap_common.get('time_ms', 0) / 1000

        if nmap_time > 0:
            ratio = pentool_time / nmap_time
            table += f"- **Pentool**: {pentool_time:.2f} секунд\n"
            table += f"- **Nmap**: {nmap_time:.2f} секунд\n"
            table += f"- **Соотношение**: Pentool медленнее в {ratio:.1f}x раз\n\n"

        table += "### 2.2 Использование ресурсов\n\n"
        table += "**Память:**\n"
        table += f"- Nmap (общие порты): {nmap_common_metrics.get('memory_kb', 0)/1024:.1f} MB\n"
        table += f"- Nmap (диапазон): {nmap_range_metrics.get('memory_kb', 0)/1024:.1f} MB\n"
        table += f"- Nmap (определение сервисов): {nmap_service_metrics.get('memory_kb', 0)/1024:.1f} MB\n\n"

        table += "**Загрузка CPU:**\n"
        table += f"- Nmap (общие порты): {nmap_common_metrics.get('cpu_percent', 'N/A')}%\n"
        table += f"- Nmap (диапазон): {nmap_range_metrics.get('cpu_percent', 'N/A')}%\n"
        table += f"- Nmap (определение сервисов): {nmap_service_metrics.get('cpu_percent', 'N/A')}%\n\n"

        table += "### 2.3 Точность обнаружения\n\n"
        table += f"- Pentool нашел: {pentool.get('open_ports', 0)} открытых портов\n"
        table += f"- Nmap нашел: {nmap_common.get('open_ports', 0)} открытых портов\n\n"

        table += "## 3. Выводы\n\n"
        table += "### Преимущества Pentool:\n"
        table += "- ✓ Мульти-агентная распределенная архитектура\n"
        table += "- ✓ Асинхронная обработка через NATS\n"
        table += "- ✓ Горизонтальная масштабируемость\n"
        table += "- ✓ Современные паттерны Go (goroutines, channels)\n"
        table += "- ✓ RESTful API для интеграции\n"
        table += "- ✓ PostgreSQL для хранения результатов\n\n"

        table += "### Области для оптимизации:\n"
        table += "- ⚠ Скорость сканирования (timeout оптимизация)\n"
        table += "- ⚠ Параллелизм (увеличение maxWorkers)\n"
        table += "- ⚠ Точность обнаружения портов\n\n"

        return table

    def create_time_comparison_chart(self):
        """Create execution time comparison chart"""

        tests = self.data.get('tests', {})

        labels = ['Общие\nпорты\n(15)', 'Диапазон\n1-100', 'Определение\nсервисов']

        # Convert ms to seconds
        pentool_times = [
            tests.get('pentool_common_ports', {}).get('time_ms', 0) / 1000,
            0,  # Pentool didn't test range
            0   # Pentool doesn't have service detection yet
        ]

        nmap_times = [
            tests.get('nmap_common_ports', {}).get('time_ms', 0) / 1000,
            tests.get('nmap_port_range_1_100', {}).get('time_ms', 0) / 1000,
            tests.get('nmap_service_detection', {}).get('time_ms', 0) / 1000
        ]

        x = np.arange(len(labels))
        width = 0.35

        fig, ax = plt.subplots(figsize=(12, 7))

        bars1 = ax.bar(x - width/2, pentool_times, width, label='Pentool', color='#3498db', alpha=0.8)
        bars2 = ax.bar(x + width/2, nmap_times, width, label='Nmap', color='#e74c3c', alpha=0.8)

        ax.set_ylabel('Время выполнения (секунды)', fontsize=13, fontweight='bold')
        ax.set_xlabel('Тип теста', fontsize=13, fontweight='bold')
        ax.set_title('Сравнение времени выполнения сканирования\nPentool vs Nmap',
                     fontsize=15, fontweight='bold', pad=20)
        ax.set_xticks(x)
        ax.set_xticklabels(labels, fontsize=11)
        ax.legend(fontsize=12)
        ax.grid(axis='y', alpha=0.3, linestyle='--')

        # Add value labels
        for bars in [bars1, bars2]:
            for bar in bars:
                height = bar.get_height()
                if height > 0:
                    ax.text(bar.get_x() + bar.get_width()/2., height,
                           f'{height:.2f}s',
                           ha='center', va='bottom', fontsize=10, fontweight='bold')

        plt.tight_layout()
        plt.savefig(f'{self.results_dir}/time_comparison.png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved: {self.results_dir}/time_comparison.png")

    def create_architecture_diagram(self):
        """Create detailed system architecture diagram"""

        fig, ax = plt.subplots(figsize=(16, 12))
        ax.set_xlim(0, 10)
        ax.set_ylim(0, 10)
        ax.axis('off')

        # Title
        ax.text(5, 9.5, 'Pentool: Мульти-Агентная Архитектура',
               ha='center', fontsize=18, fontweight='bold',
               bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.8))

        # User Layer
        user_rect = mpatches.FancyBboxPatch((4, 8), 2, 0.6,
                                            boxstyle="round,pad=0.1",
                                            edgecolor='black', facecolor='#3498db', linewidth=2)
        ax.add_patch(user_rect)
        ax.text(5, 8.3, 'User / Client', ha='center', va='center',
               fontsize=12, fontweight='bold', color='white')

        # Main Agent
        main_rect = mpatches.FancyBboxPatch((3.5, 6.5), 3, 0.8,
                                            boxstyle="round,pad=0.1",
                                            edgecolor='black', facecolor='#e74c3c', linewidth=2)
        ax.add_patch(main_rect)
        ax.text(5, 6.9, 'Main Agent', ha='center', va='center',
               fontsize=13, fontweight='bold', color='white')
        ax.text(5, 6.7, '(REST API :8080)', ha='center', va='center',
               fontsize=9, color='white')

        # NATS Message Broker
        nats_rect = mpatches.FancyBboxPatch((3.5, 5), 3, 0.8,
                                            boxstyle="round,pad=0.1",
                                            edgecolor='black', facecolor='#f39c12', linewidth=2)
        ax.add_patch(nats_rect)
        ax.text(5, 5.5, 'NATS Message Broker', ha='center', va='center',
               fontsize=13, fontweight='bold', color='white')
        ax.text(5, 5.2, '(Pub/Sub :4222)', ha='center', va='center',
               fontsize=9, color='white')

        # Worker Agents
        agents = [
            ('Scanner Agent', 1.5, 3.5, 'Сканирование\nпортов'),
            ('Analyzer Agent', 4, 3.5, 'Определение\nсервисов'),
            ('Reporter Agent', 6.5, 3.5, 'Генерация\nотчетов')
        ]

        for name, x_pos, y_pos, desc in agents:
            agent_rect = mpatches.FancyBboxPatch((x_pos, y_pos), 2, 0.8,
                                                boxstyle="round,pad=0.1",
                                                edgecolor='black', facecolor='#2ecc71',
                                                linewidth=2)
            ax.add_patch(agent_rect)
            ax.text(x_pos + 1, y_pos + 0.5, name, ha='center', va='center',
                   fontsize=11, fontweight='bold', color='white')
            ax.text(x_pos + 1, y_pos + 0.2, desc, ha='center', va='center',
                   fontsize=8, color='white')

        # Database
        db_rect = mpatches.FancyBboxPatch((6.5, 1.5), 2, 0.8,
                                         boxstyle="round,pad=0.1",
                                         edgecolor='black', facecolor='#9b59b6', linewidth=2)
        ax.add_patch(db_rect)
        ax.text(7.5, 2, 'PostgreSQL', ha='center', va='center',
               fontsize=12, fontweight='bold', color='white')
        ax.text(7.5, 1.7, 'Database', ha='center', va='center',
               fontsize=9, color='white')

        # Arrows
        arrows = [
            ((5, 8), (5, 7.3), 'HTTP\nREST API', 'black'),
            ((5, 6.5), (5, 5.8), 'NATS\nPublish', 'black'),
            ((4.5, 5), (2.5, 4.3), 'scan.request', '#555'),
            ((5, 5), (5, 4.3), 'scan.result', '#555'),
            ((5.5, 5), (7.5, 4.3), 'service.info', '#555'),
            ((7.5, 3.5), (7.5, 2.3), 'SQL\nINSERT', 'black'),
        ]

        for (x1, y1), (x2, y2), label, color in arrows:
            ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
                       arrowprops=dict(arrowstyle='->', lw=2.5, color=color))
            mid_x, mid_y = (x1 + x2) / 2, (y1 + y2) / 2
            ax.text(mid_x + 0.3, mid_y, label, fontsize=8,
                   style='italic', color=color, fontweight='bold')

        # Features box
        features_text = (
            "Ключевые особенности:\n\n"
            "✓ Go Concurrency (Goroutines)\n"
            "✓ Async Message Passing\n"
            "✓ Distributed Architecture\n"
            "✓ Horizontal Scalability\n"
            "✓ Microservices Pattern\n"
            "✓ Event-Driven Design"
        )

        ax.text(0.3, 5, features_text, fontsize=9,
               verticalalignment='top',
               bbox=dict(boxstyle='round', facecolor='#ecf0f1',
                        alpha=0.9, edgecolor='black', linewidth=1.5))

        # Tech stack box
        tech_text = (
            "Технологии:\n\n"
            "• Go 1.19+\n"
            "• NATS Streaming\n"
            "• PostgreSQL 15\n"
            "• Docker\n"
            "• REST API"
        )

        ax.text(9.7, 5, tech_text, fontsize=9,
               verticalalignment='top', ha='right',
               bbox=dict(boxstyle='round', facecolor='#ecf0f1',
                        alpha=0.9, edgecolor='black', linewidth=1.5))

        plt.tight_layout()
        plt.savefig(f'{self.results_dir}/architecture_diagram.png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved: {self.results_dir}/architecture_diagram.png")

    def create_memory_comparison_chart(self):
        """Create memory usage comparison"""

        nmap_common_metrics = self.parse_time_metrics(f'{self.results_dir}/nmap_common_time.txt')
        nmap_range_metrics = self.parse_time_metrics(f'{self.results_dir}/nmap_range_time.txt')
        nmap_service_metrics = self.parse_time_metrics(f'{self.results_dir}/nmap_service_time.txt')

        labels = ['Общие\nпорты', 'Диапазон\n1-100', 'Определение\nсервисов']
        memory = [
            nmap_common_metrics.get('memory_kb', 0) / 1024,
            nmap_range_metrics.get('memory_kb', 0) / 1024,
            nmap_service_metrics.get('memory_kb', 0) / 1024
        ]

        fig, ax = plt.subplots(figsize=(10, 6))
        bars = ax.bar(labels, memory, color=['#e74c3c', '#e67e22', '#d35400'], alpha=0.8)

        ax.set_ylabel('Использование памяти (MB)', fontsize=12, fontweight='bold')
        ax.set_xlabel('Тип теста', fontsize=12, fontweight='bold')
        ax.set_title('Использование памяти - Nmap', fontsize=14, fontweight='bold')
        ax.grid(axis='y', alpha=0.3, linestyle='--')

        # Add value labels
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height,
                       f'{height:.1f} MB',
                       ha='center', va='bottom', fontsize=11, fontweight='bold')

        plt.tight_layout()
        plt.savefig(f'{self.results_dir}/memory_comparison.png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved: {self.results_dir}/memory_comparison.png")

    def create_feature_comparison_table(self):
        """Create feature comparison table"""

        table = "\n## 4. Сравнение функциональности\n\n"
        table += "| Функция | Pentool | Nmap | Masscan |\n"
        table += "|---------|---------|------|----------|\n"
        table += "| Сканирование портов | ✓ | ✓ | ✓ |\n"
        table += "| Определение сервисов | ✓ | ✓ | ✗ |\n"
        table += "| REST API | ✓ | ✗ | ✗ |\n"
        table += "| Распределенная архитектура | ✓ | ✗ | ✗ |\n"
        table += "| Горизонтальное масштабирование | ✓ | ✗ | ✗ |\n"
        table += "| Асинхронная обработка | ✓ | ✗ | ✓ |\n"
        table += "| Хранение результатов в БД | ✓ | ✗ | ✗ |\n"
        table += "| Сверхбыстрое сканирование | ✗ | ✗ | ✓ |\n"
        table += "| OS Detection | ✗ | ✓ | ✗ |\n"
        table += "| NSE Scripts | ✗ | ✓ | ✗ |\n\n"

        return table

    def generate_complete_report(self):
        """Generate complete research paper data"""

        print("\n" + "="*70)
        print("  Research Paper Data Generator - Pentool Analysis")
        print("="*70 + "\n")

        if not self.load_summary():
            return False

        print("\nGenerating comprehensive analysis...\n")

        # Generate markdown report
        print("Creating comparison tables...")
        report = self.create_comparison_table_md()
        report += self.create_feature_comparison_table()

        with open(f'{self.results_dir}/research_report.md', 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"✓ Saved: {self.results_dir}/research_report.md")

        # Generate charts
        print("\nGenerating charts...")
        self.create_time_comparison_chart()
        self.create_memory_comparison_chart()
        self.create_architecture_diagram()

        print("\n" + "="*70)
        print("  Analysis Complete!")
        print("="*70)
        print(f"\nAll research data saved in: {self.results_dir}/")
        print("\nGenerated files:")
        print("  📊 research_report.md - Comprehensive analysis report")
        print("  📈 time_comparison.png - Execution time comparison chart")
        print("  💾 memory_comparison.png - Memory usage chart")
        print("  🏗️  architecture_diagram.png - System architecture diagram")
        print("\nData ready for scientific paper!\n")

        return True


if __name__ == '__main__':
    generator = ResearchDataGenerator()
    success = generator.generate_complete_report()
    sys.exit(0 if success else 1)