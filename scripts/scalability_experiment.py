#!/usr/bin/env python3
"""
Experiment B: Scalability Analysis
Tests Pentool with different numbers of scanner agents (1-10)

This script starts multiple scanner-agent processes and measures throughput.
"""

import json
import subprocess
import time
import os
import signal
import statistics
from datetime import datetime
from typing import Dict, List, Optional
import requests

# Configuration
TARGET = "scanme.nmap.org"
PORT_COUNT = 1000
RUNS = 3
SCANNER_BINARY = "./bin/scanner-agent"
OUTPUT_DIR = "experiment_results"

class ScalabilityExperiment:
    def __init__(self):
        self.scanner_processes = []
        self.results = {
            "experiment_date": datetime.now().strftime("%Y-%m-%d"),
            "experiment_type": "scalability",
            "target": TARGET,
            "port_count": PORT_COUNT,
            "runs_per_test": RUNS,
            "scalability": {}
        }
        self.baseline_throughput = None

    def start_scanner_agents(self, count: int) -> List[subprocess.Popen]:
        """Start multiple scanner agent processes."""
        processes = []
        for i in range(count):
            log_file = f"/tmp/scanner-agent-{i}.log"
            with open(log_file, 'w') as f:
                proc = subprocess.Popen(
                    [SCANNER_BINARY],
                    stdout=f,
                    stderr=subprocess.STDOUT
                )
                processes.append(proc)
        return processes

    def stop_scanner_agents(self, processes: List[subprocess.Popen]):
        """Stop all scanner agent processes."""
        for proc in processes:
            try:
                proc.terminate()
                proc.wait(timeout=5)
            except:
                proc.kill()

    def wait_for_agents_ready(self, count: int, timeout: int = 10):
        """Wait for all scanner agents to be ready."""
        time.sleep(2)  # Give agents time to connect to NATS

    def generate_ports_list(self, count: int) -> List[int]:
        """Generate list of ports 1 to count."""
        return list(range(1, count + 1))

    def run_pentool_scan(self, port_count: int) -> Optional[float]:
        """Run Pentool scan and return duration in seconds."""
        ports = self.generate_ports_list(port_count)

        start_time = time.perf_counter()

        try:
            response = requests.post(
                'http://localhost:8080/scan',
                json={"target": TARGET, "ports": ports},
                headers={"Content-Type": "application/json"},
                timeout=120
            )
            response.raise_for_status()
            scan_id = response.json().get('id')
        except Exception as e:
            print(f"    ERROR submitting scan: {e}")
            return None

        if not scan_id:
            print("    ERROR: No scan ID returned")
            return None

        # Wait for scan to complete by checking status
        max_wait = 300
        check_interval = 0.2
        waited = 0

        while waited < max_wait:
            time.sleep(check_interval)
            waited += check_interval

            try:
                status_response = requests.get(f'http://localhost:8080/scan/{scan_id}', timeout=5)
                scan_data = status_response.json()

                # Check if scan has results (open_ports count matches or scan completed)
                total_ports = scan_data.get('total_ports', 0)
                results = scan_data.get('results', [])

                # A rough heuristic: scan is complete when we have results
                # and the updated_at hasn't changed for a while
                if len(results) > 0 or scan_data.get('status') == 'completed':
                    # Wait a bit more to ensure all results are in
                    time.sleep(0.5)
                    end_time = time.perf_counter()
                    return end_time - start_time
            except:
                pass

            # Also check scanner logs for completion
            for i in range(10):  # Check up to 10 scanner logs
                log_file = f"/tmp/scanner-agent-{i}.log"
                if os.path.exists(log_file):
                    try:
                        with open(log_file, 'r') as f:
                            content = f.read()
                            if scan_id in content and "Completed port scan" in content:
                                end_time = time.perf_counter()
                                return end_time - start_time
                    except:
                        pass

        print("    TIMEOUT: Scan did not complete in time")
        return None

    def run_averaged_tests(self, agent_count: int, runs: int = RUNS) -> Dict:
        """Run multiple tests and return statistics."""
        times = []

        for run in range(1, runs + 1):
            print(f"    Run {run}/{runs}: ", end='', flush=True)
            duration = self.run_pentool_scan(PORT_COUNT)

            if duration is not None:
                times.append(duration)
                print(f"{duration:.3f}s")
            else:
                print("FAILED")

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

    def run_experiment(self):
        """Run scalability experiment with different agent counts."""
        print("=" * 60)
        print("EXPERIMENT B: Scalability Analysis")
        print(f"Target: {TARGET}")
        print(f"Ports: {PORT_COUNT}")
        print(f"Runs per test: {RUNS}")
        print("=" * 60)

        # First, kill any existing scanner agents
        print("\nStopping any existing scanner agents...")
        subprocess.run(['pkill', '-f', 'scanner-agent'], capture_output=True)
        time.sleep(2)

        agent_counts = [1, 2, 3, 5, 10]

        for agent_count in agent_counts:
            print(f"\n=== Testing with {agent_count} scanner agent(s) ===")

            # Start scanner agents
            print(f"  Starting {agent_count} scanner agent(s)...")
            processes = self.start_scanner_agents(agent_count)
            self.wait_for_agents_ready(agent_count)

            # Run tests
            print(f"  Running {RUNS} scans of {PORT_COUNT} ports...")
            stats = self.run_averaged_tests(agent_count)

            # Stop scanner agents
            print(f"  Stopping scanner agents...")
            self.stop_scanner_agents(processes)
            time.sleep(2)

            if stats["avg"] > 0:
                ports_per_min = (PORT_COUNT / stats["avg"]) * 60

                # Calculate efficiency based on linear scaling from baseline
                if self.baseline_throughput is None:
                    self.baseline_throughput = ports_per_min
                    efficiency = 100.0
                else:
                    expected_throughput = self.baseline_throughput * agent_count
                    efficiency = (ports_per_min / expected_throughput) * 100

                print(f"  => Average time: {stats['avg']:.3f}s")
                print(f"  => Throughput: {ports_per_min:.0f} ports/min")
                print(f"  => Efficiency: {efficiency:.1f}%")

                self.results["scalability"][f"{agent_count}_agents"] = {
                    "time_sec": round(stats["avg"], 3),
                    "time_stdev": round(stats["stdev"], 3),
                    "ports_per_min": round(ports_per_min, 0),
                    "efficiency": round(efficiency, 1)
                }
            else:
                print(f"  => FAILED to complete tests")

        # Save results
        self.save_results()
        self.print_summary()

    def save_results(self):
        """Save results to JSON file."""
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(OUTPUT_DIR, f"scalability_{timestamp}.json")

        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)

        print(f"\nResults saved to: {filename}")
        return filename

    def print_summary(self):
        """Print summary table."""
        print("\n" + "=" * 60)
        print("SCALABILITY SUMMARY")
        print("=" * 60)
        print()
        print(f"{'Agents':<10} | {'Time (s)':<12} | {'Ports/min':<12} | {'Efficiency':<10}")
        print("-" * 60)

        for key, values in sorted(self.results["scalability"].items()):
            agents = key.replace("_agents", "")
            time_sec = values.get("time_sec", 0)
            ports_per_min = values.get("ports_per_min", 0)
            efficiency = values.get("efficiency", 0)
            print(f"{agents:<10} | {time_sec:<12.3f} | {ports_per_min:<12.0f} | {efficiency:.1f}%")

        print("\n" + "=" * 60)
        print("FINAL RESULTS (JSON)")
        print("=" * 60)
        print(json.dumps(self.results, indent=2))


if __name__ == "__main__":
    experiment = ScalabilityExperiment()
    experiment.run_experiment()