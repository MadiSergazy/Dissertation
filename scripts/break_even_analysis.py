#!/usr/bin/env python3
"""
Extended Break-even Analysis
Tests larger port ranges: 10000, 20000, 30000, 65535 (full scan)
"""

import json
import subprocess
import time
import os
import statistics
from datetime import datetime
from typing import Dict, List, Optional
import requests

TARGET = "scanme.nmap.org"
RUNS = 2  # Fewer runs for large scans
SCANNER_LOG = "/tmp/scanner-agent.log"
OUTPUT_DIR = "experiment_results"

class BreakEvenAnalysis:
    def __init__(self):
        self.results = {
            "experiment_date": datetime.now().strftime("%Y-%m-%d"),
            "experiment_type": "break_even_analysis",
            "target": TARGET,
            "runs_per_test": RUNS,
            "break_even_data": {}
        }

    def generate_ports_list(self, count: int) -> List[int]:
        return list(range(1, count + 1))

    def run_pentool_scan(self, port_count: int) -> Optional[float]:
        ports = self.generate_ports_list(port_count)
        start_time = time.perf_counter()

        try:
            response = requests.post(
                'http://localhost:8080/scan',
                json={"target": TARGET, "ports": ports},
                headers={"Content-Type": "application/json"},
                timeout=600  # 10 min timeout for large scans
            )
            response.raise_for_status()
            scan_id = response.json().get('id')
        except Exception as e:
            print(f"    ERROR: {e}")
            return None

        if not scan_id:
            return None

        # Wait for completion
        max_wait = 1200  # 20 minutes
        check_interval = 0.5
        waited = 0

        while waited < max_wait:
            time.sleep(check_interval)
            waited += check_interval

            try:
                with open(SCANNER_LOG, 'r') as f:
                    content = f.read()
                    if scan_id in content and "Completed port scan" in content:
                        end_time = time.perf_counter()
                        return end_time - start_time
            except:
                pass

        print("    TIMEOUT")
        return None

    def run_nmap_scan(self, port_count: int) -> Optional[float]:
        start_time = time.perf_counter()

        try:
            result = subprocess.run(
                ['nmap', '-p', f'1-{port_count}', '-T4', '--min-parallelism', '100',
                 '--max-retries', '1', TARGET],
                capture_output=True,
                timeout=1200  # 20 min timeout
            )
            end_time = time.perf_counter()
            return end_time - start_time
        except Exception as e:
            print(f"    ERROR: {e}")
            return None

    def run_averaged_tests(self, tool: str, port_count: int) -> Dict:
        times = []

        for run in range(1, RUNS + 1):
            print(f"    Run {run}/{RUNS}: ", end='', flush=True)

            if tool == "pentool":
                duration = self.run_pentool_scan(port_count)
            else:
                duration = self.run_nmap_scan(port_count)

            if duration is not None:
                times.append(duration)
                print(f"{duration:.3f}s")
            else:
                print("FAILED")

            time.sleep(3)

        if not times:
            return {"avg": 0, "min": 0, "max": 0}

        return {
            "avg": statistics.mean(times),
            "min": min(times),
            "max": max(times)
        }

    def run_experiment(self):
        print("=" * 60)
        print("BREAK-EVEN ANALYSIS")
        print(f"Target: {TARGET}")
        print("=" * 60)

        port_counts = [10000, 20000, 30000]  # Skip 65535 as it takes too long

        for port_count in port_counts:
            print(f"\n=== Testing {port_count} ports ===")

            print(f"  Pentool:")
            pentool_stats = self.run_averaged_tests("pentool", port_count)

            print(f"  Nmap:")
            nmap_stats = self.run_averaged_tests("nmap", port_count)

            if pentool_stats["avg"] > 0 and nmap_stats["avg"] > 0:
                ratio = pentool_stats["avg"] / nmap_stats["avg"]
                speedup = nmap_stats["avg"] / pentool_stats["avg"]
                print(f"  => Pentool: {pentool_stats['avg']:.3f}s")
                print(f"  => Nmap: {nmap_stats['avg']:.3f}s")
                print(f"  => Ratio (Pentool/Nmap): {ratio:.3f}")
                print(f"  => Speedup (Nmap/Pentool): {speedup:.2f}x")

                self.results["break_even_data"][f"{port_count}_ports"] = {
                    "pentool": round(pentool_stats["avg"], 3),
                    "nmap": round(nmap_stats["avg"], 3),
                    "ratio": round(ratio, 3),
                    "speedup": round(speedup, 2),
                    "pentool_faster": ratio < 1
                }

        self.save_results()

    def save_results(self):
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(OUTPUT_DIR, f"break_even_{timestamp}.json")

        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)

        print(f"\nResults saved to: {filename}")
        print("\nFINAL RESULTS:")
        print(json.dumps(self.results, indent=2))


if __name__ == "__main__":
    analysis = BreakEvenAnalysis()
    analysis.run_experiment()
