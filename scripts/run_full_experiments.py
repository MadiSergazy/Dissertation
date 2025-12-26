#!/usr/bin/env python3
"""
Extended Experiments for Scientific Paper
Tests Pentool vs Nmap performance at various port ranges

Experiments:
A) Volume Comparison: 100, 500, 1000, 2000, 5000 ports
B) Scalability: 1-10 scanner agents
C) Break-even Point: Find where Pentool matches/beats Nmap
"""

import json
import subprocess
import time
import os
import re
import statistics
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import requests

# Configuration
TARGET = "scanme.nmap.org"
RUNS = 3  # Number of runs per test for averaging
SCANNER_LOG = "/tmp/scanner-agent.log"
OUTPUT_DIR = "experiment_results"

class ExperimentRunner:
    def __init__(self):
        self.results = {
            "experiment_date": datetime.now().strftime("%Y-%m-%d"),
            "environment": self.get_environment_info(),
            "volume_comparison": {},
            "scalability": {},
            "break_even_point": {},
            "observations": []
        }

    def get_environment_info(self) -> Dict:
        """Collect system environment information."""
        env = {}

        # OS info
        try:
            result = subprocess.run(['lsb_release', '-d'], capture_output=True, text=True)
            env['os'] = result.stdout.split(':')[1].strip() if result.returncode == 0 else "Unknown"
        except:
            env['os'] = "Unknown"

        # Go version
        try:
            result = subprocess.run(['go', 'version'], capture_output=True, text=True)
            env['go_version'] = result.stdout.split()[2] if result.returncode == 0 else "Unknown"
        except:
            env['go_version'] = "Unknown"

        # CPU info
        try:
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if 'model name' in line:
                        env['cpu'] = line.split(':')[1].strip()
                        break
        except:
            env['cpu'] = "Unknown"

        # RAM info
        try:
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if 'MemTotal' in line:
                        mem_kb = int(line.split()[1])
                        env['ram'] = f"{mem_kb // 1024 // 1024}GB"
                        break
        except:
            env['ram'] = "Unknown"

        # Nmap version
        try:
            result = subprocess.run(['nmap', '--version'], capture_output=True, text=True)
            env['nmap_version'] = result.stdout.split('\n')[0] if result.returncode == 0 else "Unknown"
        except:
            env['nmap_version'] = "Unknown"

        return env

    def generate_ports_list(self, count: int) -> List[int]:
        """Generate list of ports 1 to count."""
        return list(range(1, count + 1))

    def run_pentool_scan(self, port_count: int) -> Optional[float]:
        """Run Pentool scan and return duration in seconds."""
        ports = self.generate_ports_list(port_count)

        # Get current log line count
        try:
            with open(SCANNER_LOG, 'r') as f:
                log_lines_before = sum(1 for _ in f)
        except:
            log_lines_before = 0

        start_time = time.perf_counter()

        # Submit scan request
        try:
            response = requests.post(
                'http://localhost:8080/scan',
                json={"target": TARGET, "ports": ports},
                headers={"Content-Type": "application/json"},
                timeout=60
            )
            response.raise_for_status()
            scan_id = response.json().get('id')
        except Exception as e:
            print(f"    ERROR submitting scan: {e}")
            return None

        if not scan_id:
            print("    ERROR: No scan ID returned")
            return None

        # Wait for scanner to complete by monitoring log
        max_wait = 600  # 10 minutes
        check_interval = 0.1
        waited = 0

        while waited < max_wait:
            time.sleep(check_interval)
            waited += check_interval

            # Check scanner log for completion
            try:
                with open(SCANNER_LOG, 'r') as f:
                    lines = f.readlines()
                    # Check last 100 lines for our scan completion
                    for line in lines[-100:]:
                        if scan_id in line and "Completed port scan" in line:
                            end_time = time.perf_counter()
                            return end_time - start_time
            except:
                pass

        print("    TIMEOUT: Scan did not complete in time")
        return None

    def run_nmap_scan(self, port_count: int) -> Optional[float]:
        """Run Nmap scan and return duration in seconds."""
        start_time = time.perf_counter()

        try:
            result = subprocess.run(
                ['nmap', '-p', f'1-{port_count}', '-T4', '--min-parallelism', '100',
                 '--max-retries', '1', TARGET],
                capture_output=True,
                timeout=600
            )
            end_time = time.perf_counter()

            if result.returncode != 0:
                print(f"    WARNING: Nmap returned non-zero exit code")

            return end_time - start_time
        except subprocess.TimeoutExpired:
            print("    TIMEOUT: Nmap did not complete in time")
            return None
        except Exception as e:
            print(f"    ERROR running nmap: {e}")
            return None

    def run_averaged_tests(self, tool: str, port_count: int, runs: int = RUNS) -> Dict:
        """Run multiple tests and return statistics."""
        times = []

        for run in range(1, runs + 1):
            print(f"    Run {run}/{runs}: ", end='', flush=True)

            if tool == "pentool":
                duration = self.run_pentool_scan(port_count)
            else:
                duration = self.run_nmap_scan(port_count)

            if duration is not None:
                times.append(duration)
                print(f"{duration:.3f}s")
            else:
                print("FAILED")

            # Brief pause between runs
            time.sleep(2)

        if not times:
            return {"avg": 0, "min": 0, "max": 0, "stdev": 0, "times": []}

        return {
            "avg": statistics.mean(times),
            "min": min(times),
            "max": max(times),
            "stdev": statistics.stdev(times) if len(times) > 1 else 0,
            "times": times
        }

    def experiment_a_volume_comparison(self):
        """Experiment A: Volume comparison at different port counts."""
        print("\n" + "=" * 60)
        print("EXPERIMENT A: Volume Comparison (Pentool vs Nmap)")
        print("=" * 60)

        port_counts = [100, 500, 1000, 2000, 5000]

        for port_count in port_counts:
            print(f"\n=== Testing {port_count} ports ===")

            # Pentool test
            print(f"  Pentool ({port_count} ports):")
            pentool_stats = self.run_averaged_tests("pentool", port_count)

            # Nmap test
            print(f"  Nmap ({port_count} ports):")
            nmap_stats = self.run_averaged_tests("nmap", port_count)

            # Calculate ratio
            if pentool_stats["avg"] > 0 and nmap_stats["avg"] > 0:
                speedup = nmap_stats["avg"] / pentool_stats["avg"]
                print(f"  => Pentool avg: {pentool_stats['avg']:.3f}s")
                print(f"  => Nmap avg: {nmap_stats['avg']:.3f}s")
                print(f"  => Speedup (Nmap/Pentool): {speedup:.2f}x")
            else:
                speedup = 0

            # Store results
            self.results["volume_comparison"][f"{port_count}_ports"] = {
                "pentool": round(pentool_stats["avg"], 3),
                "nmap": round(nmap_stats["avg"], 3),
                "pentool_stdev": round(pentool_stats["stdev"], 3),
                "nmap_stdev": round(nmap_stats["stdev"], 3),
                "speedup": round(speedup, 2)
            }

    def experiment_b_scalability(self):
        """Experiment B: Scalability with multiple scanner agents.

        NOTE: This requires manual setup of multiple scanner agents.
        For now, we document the single-agent baseline.
        """
        print("\n" + "=" * 60)
        print("EXPERIMENT B: Scalability Analysis")
        print("=" * 60)
        print("\nNOTE: Multi-agent testing requires manual configuration.")
        print("Recording single-agent baseline for 1000 ports...")

        # Single agent baseline
        print("\n  Testing with 1 agent (1000 ports):")
        stats = self.run_averaged_tests("pentool", 1000)

        if stats["avg"] > 0:
            ports_per_min = (1000 / stats["avg"]) * 60
            print(f"  => Time: {stats['avg']:.3f}s")
            print(f"  => Throughput: {ports_per_min:.0f} ports/min")

            self.results["scalability"]["1_agent"] = {
                "time_sec": round(stats["avg"], 3),
                "ports_per_min": round(ports_per_min, 0),
                "efficiency": 100.0
            }

            # Add note for multi-agent testing
            self.results["observations"].append(
                "Scalability experiment requires manual setup of multiple scanner agents via docker-compose"
            )

    def experiment_c_break_even(self):
        """Experiment C: Find break-even point where Pentool becomes faster."""
        print("\n" + "=" * 60)
        print("EXPERIMENT C: Break-even Point Analysis")
        print("=" * 60)
        print("\nTesting larger port ranges to find break-even point...")

        # Test progressively larger ranges
        test_ranges = [10000, 20000, 30000]

        for port_count in test_ranges:
            print(f"\n=== Testing {port_count} ports ===")

            print(f"  Pentool ({port_count} ports):")
            pentool_stats = self.run_averaged_tests("pentool", port_count, runs=2)

            print(f"  Nmap ({port_count} ports):")
            nmap_stats = self.run_averaged_tests("nmap", port_count, runs=2)

            if pentool_stats["avg"] > 0 and nmap_stats["avg"] > 0:
                ratio = pentool_stats["avg"] / nmap_stats["avg"]
                print(f"  => Pentool/Nmap ratio: {ratio:.2f}")

                self.results["break_even_point"][f"{port_count}_ports"] = {
                    "pentool": round(pentool_stats["avg"], 3),
                    "nmap": round(nmap_stats["avg"], 3),
                    "ratio": round(ratio, 3)
                }

                # If Pentool is faster (ratio < 1), we found break-even
                if ratio < 1:
                    self.results["observations"].append(
                        f"Break-even point found: Pentool faster at {port_count} ports"
                    )
                    break

    def save_results(self):
        """Save results to JSON file."""
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(OUTPUT_DIR, f"results_{timestamp}.json")

        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)

        print(f"\nResults saved to: {filename}")
        return filename

    def print_summary(self):
        """Print summary table of results."""
        print("\n" + "=" * 60)
        print("VOLUME COMPARISON SUMMARY")
        print("=" * 60)
        print()
        print(f"{'Ports':<10} | {'Pentool (s)':<15} | {'Nmap (s)':<15} | {'Speedup':<10}")
        print("-" * 60)

        for key, values in sorted(self.results["volume_comparison"].items()):
            port_count = key.replace("_ports", "")
            pentool = values.get("pentool", 0)
            nmap = values.get("nmap", 0)
            speedup = values.get("speedup", 0)
            print(f"{port_count:<10} | {pentool:<15.3f} | {nmap:<15.3f} | {speedup:.2f}x")

    def run_all_experiments(self):
        """Run all experiments."""
        print("=" * 60)
        print("Pentool vs Nmap Extended Experiments")
        print(f"Target: {TARGET}")
        print(f"Runs per test: {RUNS}")
        print("=" * 60)

        print("\nEnvironment:")
        for key, value in self.results["environment"].items():
            print(f"  {key}: {value}")

        # Run experiments
        self.experiment_a_volume_comparison()
        self.experiment_b_scalability()
        self.experiment_c_break_even()

        # Save and print results
        self.print_summary()
        filename = self.save_results()

        print("\n" + "=" * 60)
        print("FINAL RESULTS (JSON)")
        print("=" * 60)
        print(json.dumps(self.results, indent=2))

        return filename


if __name__ == "__main__":
    runner = ExperimentRunner()
    runner.run_all_experiments()