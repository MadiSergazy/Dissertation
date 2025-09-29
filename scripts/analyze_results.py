#!/usr/bin/env python3
"""
Benchmark Results Analysis Script
Generates graphs and comparison tables for scientific paper
"""

import json
import re
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime
import os

# Set matplotlib to use non-interactive backend
plt.switch_backend('Agg')

class BenchmarkAnalyzer:
    def __init__(self, results_dir='benchmark_results'):
        self.results_dir = results_dir
        self.data = {
            'pentool': {},
            'nmap': {},
            'masscan': {}
        }

    def parse_time_to_seconds(self, time_str):
        """Convert time string (MM:SS.ms or S.ms) to seconds"""
        if ':' in time_str:
            parts = time_str.split(':')
            if len(parts) == 2:
                minutes, seconds = parts
                return float(minutes) * 60 + float(seconds)
            elif len(parts) == 3:
                hours, minutes, seconds = parts
                return float(hours) * 3600 + float(minutes) * 60 + float(seconds)
        else:
            return float(time_str)

    def parse_nmap_metrics(self, filename):
        """Parse /usr/bin/time output for Nmap"""
        metrics = {}
        try:
            with open(filename, 'r') as f:
                content = f.read()

            # Extract elapsed time
            elapsed_match = re.search(r'Elapsed \(wall clock\) time.*: (.+)', content)
            if elapsed_match:
                metrics['time'] = self.parse_time_to_seconds(elapsed_match.group(1))

            # Extract memory
            mem_match = re.search(r'Maximum resident set size \(kbytes\): (\d+)', content)
            if mem_match:
                metrics['memory_kb'] = int(mem_match.group(1))

            # Extract CPU usage
            cpu_match = re.search(r'Percent of CPU this job got: (\d+)%', content)
            if cpu_match:
                metrics['cpu_percent'] = int(cpu_match.group(1))

        except FileNotFoundError:
            print(f"Warning: {filename} not found")

        return metrics

    def load_results(self):
        """Load all benchmark results"""

        # Load Nmap results
        self.data['nmap']['common_ports'] = self.parse_nmap_metrics(
            f'{self.results_dir}/nmap_common_metrics.txt')
        self.data['nmap']['port_range'] = self.parse_nmap_metrics(
            f'{self.results_dir}/nmap_range_metrics.txt')
        self.data['nmap']['localhost'] = self.parse_nmap_metrics(
            f'{self.results_dir}/nmap_localhost_metrics.txt')
        self.data['nmap']['service_detection'] = self.parse_nmap_metrics(
            f'{self.results_dir}/nmap_service_metrics.txt')

        # Load Pentool results (from JSON response if available)
        try:
            with open(f'{self.results_dir}/pentool_common_response.json', 'r') as f:
                pentool_data = json.load(f)
                # Store basic info
                self.data['pentool']['scan_id'] = pentool_data.get('scan_id', 'N/A')
        except:
            pass

    def create_comparison_table(self):
        """Generate comparison table in markdown format"""

        table = "# Сравнительная таблица результатов\n\n"
        table += "## Тест 1: Сканирование распространенных портов (15 портов)\n\n"
        table += "| Инструмент | Время выполнения | Память (KB) | Загрузка CPU (%) |\n"
        table += "|------------|------------------|-------------|------------------|\n"

        nmap_common = self.data['nmap'].get('common_ports', {})
        table += f"| Nmap | {nmap_common.get('time', 'N/A')}s | "
        table += f"{nmap_common.get('memory_kb', 'N/A')} | "
        table += f"{nmap_common.get('cpu_percent', 'N/A')} |\n\n"

        table += "## Тест 2: Сканирование диапазона портов (1-1000)\n\n"
        table += "| Инструмент | Время выполнения | Память (KB) | Загрузка CPU (%) |\n"
        table += "|------------|------------------|-------------|------------------|\n"

        nmap_range = self.data['nmap'].get('port_range', {})
        table += f"| Nmap | {nmap_range.get('time', 'N/A')}s | "
        table += f"{nmap_range.get('memory_kb', 'N/A')} | "
        table += f"{nmap_range.get('cpu_percent', 'N/A')} |\n\n"

        table += "## Тест 3: Сканирование localhost (1-1000)\n\n"
        table += "| Инструмент | Время выполнения | Память (KB) | Загрузка CPU (%) |\n"
        table += "|------------|------------------|-------------|------------------|\n"

        nmap_localhost = self.data['nmap'].get('localhost', {})
        table += f"| Nmap | {nmap_localhost.get('time', 'N/A')}s | "
        table += f"{nmap_localhost.get('memory_kb', 'N/A')} | "
        table += f"{nmap_localhost.get('cpu_percent', 'N/A')} |\n\n"

        table += "## Тест 4: Определение сервисов\n\n"
        table += "| Инструмент | Время выполнения | Память (KB) | Загрузка CPU (%) |\n"
        table += "|------------|------------------|-------------|------------------|\n"

        nmap_service = self.data['nmap'].get('service_detection', {})
        table += f"| Nmap -sV | {nmap_service.get('time', 'N/A')}s | "
        table += f"{nmap_service.get('memory_kb', 'N/A')} | "
        table += f"{nmap_service.get('cpu_percent', 'N/A')} |\n\n"

        return table

    def create_time_comparison_chart(self):
        """Create execution time comparison chart"""

        tests = ['Common\nPorts\n(15)', 'Port Range\n(1-1000)', 'Localhost\n(1-1000)', 'Service\nDetection']

        nmap_times = [
            self.data['nmap'].get('common_ports', {}).get('time', 0),
            self.data['nmap'].get('port_range', {}).get('time', 0),
            self.data['nmap'].get('localhost', {}).get('time', 0),
            self.data['nmap'].get('service_detection', {}).get('time', 0)
        ]

        x = np.arange(len(tests))
        width = 0.35

        fig, ax = plt.subplots(figsize=(12, 6))
        bars = ax.bar(x, nmap_times, width, label='Nmap', color='#2E86AB')

        ax.set_ylabel('Время выполнения (секунды)', fontsize=12)
        ax.set_xlabel('Тест', fontsize=12)
        ax.set_title('Сравнение времени выполнения сканирования', fontsize=14, fontweight='bold')
        ax.set_xticks(x)
        ax.set_xticklabels(tests)
        ax.legend()
        ax.grid(axis='y', alpha=0.3)

        # Add value labels on bars
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height,
                       f'{height:.2f}s',
                       ha='center', va='bottom', fontsize=10)

        plt.tight_layout()
        plt.savefig(f'{self.results_dir}/time_comparison.png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved: {self.results_dir}/time_comparison.png")

    def create_memory_comparison_chart(self):
        """Create memory usage comparison chart"""

        tests = ['Common\nPorts', 'Port Range', 'Localhost', 'Service\nDetection']

        nmap_memory = [
            self.data['nmap'].get('common_ports', {}).get('memory_kb', 0) / 1024,  # Convert to MB
            self.data['nmap'].get('port_range', {}).get('memory_kb', 0) / 1024,
            self.data['nmap'].get('localhost', {}).get('memory_kb', 0) / 1024,
            self.data['nmap'].get('service_detection', {}).get('memory_kb', 0) / 1024
        ]

        x = np.arange(len(tests))
        width = 0.35

        fig, ax = plt.subplots(figsize=(12, 6))
        bars = ax.bar(x, nmap_memory, width, label='Nmap', color='#A23B72')

        ax.set_ylabel('Использование памяти (MB)', fontsize=12)
        ax.set_xlabel('Тест', fontsize=12)
        ax.set_title('Сравнение использования памяти', fontsize=14, fontweight='bold')
        ax.set_xticks(x)
        ax.set_xticklabels(tests)
        ax.legend()
        ax.grid(axis='y', alpha=0.3)

        # Add value labels on bars
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height,
                       f'{height:.1f}MB',
                       ha='center', va='bottom', fontsize=10)

        plt.tight_layout()
        plt.savefig(f'{self.results_dir}/memory_comparison.png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved: {self.results_dir}/memory_comparison.png")

    def create_cpu_comparison_chart(self):
        """Create CPU usage comparison chart"""

        tests = ['Common\nPorts', 'Port Range', 'Localhost', 'Service\nDetection']

        nmap_cpu = [
            self.data['nmap'].get('common_ports', {}).get('cpu_percent', 0),
            self.data['nmap'].get('port_range', {}).get('cpu_percent', 0),
            self.data['nmap'].get('localhost', {}).get('cpu_percent', 0),
            self.data['nmap'].get('service_detection', {}).get('cpu_percent', 0)
        ]

        x = np.arange(len(tests))
        width = 0.35

        fig, ax = plt.subplots(figsize=(12, 6))
        bars = ax.bar(x, nmap_cpu, width, label='Nmap', color='#F18F01')

        ax.set_ylabel('Загрузка CPU (%)', fontsize=12)
        ax.set_xlabel('Тест', fontsize=12)
        ax.set_title('Сравнение загрузки процессора', fontsize=14, fontweight='bold')
        ax.set_xticks(x)
        ax.set_xticklabels(tests)
        ax.legend()
        ax.grid(axis='y', alpha=0.3)
        ax.set_ylim(0, 100)

        # Add value labels on bars
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height,
                       f'{int(height)}%',
                       ha='center', va='bottom', fontsize=10)

        plt.tight_layout()
        plt.savefig(f'{self.results_dir}/cpu_comparison.png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved: {self.results_dir}/cpu_comparison.png")

    def create_architecture_diagram(self):
        """Create system architecture diagram"""

        fig, ax = plt.subplots(figsize=(14, 10))
        ax.axis('off')

        # Define positions
        positions = {
            'user': (0.5, 0.9),
            'main_agent': (0.5, 0.7),
            'nats': (0.5, 0.5),
            'scanner': (0.2, 0.3),
            'analyzer': (0.5, 0.3),
            'reporter': (0.8, 0.3),
            'postgres': (0.8, 0.1)
        }

        # Draw boxes
        boxes = {
            'user': plt.Rectangle((0.4, 0.87), 0.2, 0.08, fc='#3498db', ec='black', linewidth=2),
            'main_agent': plt.Rectangle((0.35, 0.67), 0.3, 0.08, fc='#e74c3c', ec='black', linewidth=2),
            'nats': plt.Rectangle((0.35, 0.47), 0.3, 0.08, fc='#f39c12', ec='black', linewidth=2),
            'scanner': plt.Rectangle((0.05, 0.27), 0.3, 0.08, fc='#2ecc71', ec='black', linewidth=2),
            'analyzer': plt.Rectangle((0.35, 0.27), 0.3, 0.08, fc='#2ecc71', ec='black', linewidth=2),
            'reporter': plt.Rectangle((0.65, 0.27), 0.3, 0.08, fc='#2ecc71', ec='black', linewidth=2),
            'postgres': plt.Rectangle((0.65, 0.07), 0.3, 0.08, fc='#9b59b6', ec='black', linewidth=2)
        }

        for box in boxes.values():
            ax.add_patch(box)

        # Add labels
        labels = {
            'user': 'User / CLI / API Client',
            'main_agent': 'Main Agent\n(REST API :8080)',
            'nats': 'NATS Message Broker\n(Message Queue)',
            'scanner': 'Scanner Agent\n(Port Scanning)',
            'analyzer': 'Analyzer Agent\n(Service Detection)',
            'reporter': 'Reporter Agent\n(Report Generation)',
            'postgres': 'PostgreSQL Database\n(Results Storage)'
        }

        for key, (x, y) in positions.items():
            ax.text(x, y, labels[key], ha='center', va='center',
                   fontsize=10, fontweight='bold', color='white')

        # Draw arrows
        arrows = [
            ((0.5, 0.87), (0.5, 0.75), 'HTTP REST'),
            ((0.5, 0.67), (0.5, 0.55), 'NATS Pub/Sub'),
            ((0.45, 0.47), (0.25, 0.35), ''),
            ((0.5, 0.47), (0.5, 0.35), ''),
            ((0.55, 0.47), (0.75, 0.35), ''),
            ((0.8, 0.27), (0.8, 0.15), 'SQL')
        ]

        for (x1, y1), (x2, y2), label in arrows:
            ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
                       arrowprops=dict(arrowstyle='->', lw=2, color='black'))
            if label:
                mid_x, mid_y = (x1 + x2) / 2, (y1 + y2) / 2
                ax.text(mid_x + 0.05, mid_y, label, fontsize=9, style='italic')

        # Add title
        ax.text(0.5, 0.98, 'Pentool Multi-Agent Architecture',
               ha='center', fontsize=16, fontweight='bold')

        # Add features list
        features = [
            '• Go Concurrency (Goroutines)',
            '• Message-Driven Communication',
            '• Distributed Microservices',
            '• Horizontal Scalability',
            '• Async Processing'
        ]

        feature_text = '\n'.join(features)
        ax.text(0.02, 0.5, feature_text, fontsize=9,
               verticalalignment='top', bbox=dict(boxstyle='round',
               facecolor='wheat', alpha=0.3))

        plt.tight_layout()
        plt.savefig(f'{self.results_dir}/architecture_diagram.png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved: {self.results_dir}/architecture_diagram.png")

    def generate_report(self):
        """Generate complete analysis report"""

        print("\n" + "="*60)
        print("  Benchmark Results Analysis")
        print("="*60 + "\n")

        # Load results
        print("Loading benchmark results...")
        self.load_results()
        print("✓ Results loaded\n")

        # Create comparison table
        print("Generating comparison table...")
        table = self.create_comparison_table()
        with open(f'{self.results_dir}/comparison_table.md', 'w', encoding='utf-8') as f:
            f.write(table)
        print(f"✓ Saved: {self.results_dir}/comparison_table.md\n")

        # Create charts
        print("Generating charts...")
        self.create_time_comparison_chart()
        self.create_memory_comparison_chart()
        self.create_cpu_comparison_chart()
        self.create_architecture_diagram()

        print("\n" + "="*60)
        print("  Analysis Complete!")
        print("="*60)
        print(f"\nAll results saved in: {self.results_dir}/")
        print("\nGenerated files:")
        print("  • comparison_table.md - Detailed comparison table")
        print("  • time_comparison.png - Execution time chart")
        print("  • memory_comparison.png - Memory usage chart")
        print("  • cpu_comparison.png - CPU usage chart")
        print("  • architecture_diagram.png - System architecture")


if __name__ == '__main__':
    analyzer = BenchmarkAnalyzer()
    analyzer.generate_report()