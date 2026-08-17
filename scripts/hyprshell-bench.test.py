#!/usr/bin/env python3
"""Unit tests for hyprshell-bench.py using only synthetic data."""

from __future__ import annotations

import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("hyprshell-bench.py")
SPEC = importlib.util.spec_from_file_location("hyprshell_bench", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
bench = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = bench
SPEC.loader.exec_module(bench)


def stat_line(
    pid: int,
    name: str,
    *,
    starttime: int = 12345,
    utime: int = 12,
    stime: int = 13,
    threads: int = 4,
    rss_pages: int = 8,
) -> str:
    fields = [
        "S",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "10",
        str(utime),
        str(stime),
        "14",
        "15",
        "16",
        "17",
        str(threads),
        "19",
        str(starttime),
        "21",
        str(rss_pages),
    ]
    return f"{pid} ({name}) " + " ".join(fields) + "\n"


class ParserTests(unittest.TestCase):
    def test_qs_blocks_and_ansi_are_parsed(self) -> None:
        output = """
Instance one:
  Process ID: 101
  Shell ID: alpha
  Config path: /home/test/shell.qml

Instance two:
  Config path: /home/test/other.qml
  Process ID: 202
"""
        self.assertEqual(
            bench.parse_qs_list(output),
            [
                bench.QsInstance(101, "/home/test/shell.qml"),
                bench.QsInstance(202, "/home/test/other.qml"),
            ],
        )

    def test_qs_blocks_without_blank_lines_are_split_by_process_id(self) -> None:
        output = (
            "Process ID: 101\n"
            "Config path: /one/shell.qml\n"
            "Process ID: 202\n"
            "Config path: /two/shell.qml\n"
        )
        self.assertEqual(
            bench.parse_qs_list(output),
            [
                bench.QsInstance(101, "/one/shell.qml"),
                bench.QsInstance(202, "/two/shell.qml"),
            ],
        )

    def test_proc_stat_keeps_spaces_and_parentheses_in_comm(self) -> None:
        parsed = bench.parse_proc_stat(stat_line(7, "helper (west) unit"))
        self.assertEqual(parsed.pid, 7)
        self.assertEqual(parsed.comm, "helper (west) unit")
        self.assertEqual(parsed.cpu_ticks, 25)
        self.assertEqual(parsed.num_threads, 4)
        self.assertEqual(parsed.starttime, 12345)
        self.assertEqual(parsed.rss_pages, 8)

    def test_missing_pss_and_uss_are_none(self) -> None:
        self.assertEqual(
            bench.parse_smaps_rollup("Rss: 20 kB\nShared_Clean: 5 kB\n"),
            {"pss_kib": None, "uss_kib": None},
        )
        self.assertEqual(
            bench.parse_smaps_rollup(
                "Pss: 20 kB\nPrivate_Clean: 3 kB\nPrivate_Dirty: 4 kB\n"
            ),
            {"pss_kib": 20, "uss_kib": 7},
        )

    def test_process_metrics_marks_missing_memory_explicitly(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            process_dir = Path(directory) / "42"
            process_dir.mkdir()
            (process_dir / "stat").write_text(
                stat_line(42, "qs", rss_pages=8), encoding="utf-8"
            )
            (process_dir / "status").write_text(
                "VmRSS: 32 kB\nVmHWM: 48 kB\n", encoding="utf-8"
            )
            metrics = bench.read_process_metrics(42, directory)
            self.assertIsNone(metrics.pss_kib)
            self.assertIsNone(metrics.uss_kib)
            self.assertEqual(metrics.pss_status, "unavailable")
            self.assertEqual(metrics.uss_status, "unavailable")


class CalculationTests(unittest.TestCase):
    def test_cpu_uses_utime_and_stime_delta(self) -> None:
        self.assertEqual(bench.cpu_percent(100, 130, 1.0, clk_tck=100), 30.0)
        self.assertIsNone(bench.cpu_percent(None, 130, 1.0, clk_tck=100))
        self.assertIsNone(bench.cpu_percent(130, 100, 1.0, clk_tck=100))

    def test_statistics_are_deterministic(self) -> None:
        self.assertEqual(bench.median([1.0, 4.0, 2.0]), 2.0)
        self.assertEqual(bench.percentile([1.0, 2.0, 3.0, 4.0], 95), 3.85)
        self.assertEqual(bench.linear_slope([1.0, 3.0, 5.0]), 2.0)
        self.assertEqual(
            bench.linear_slope([(0.0, 10.0), (2.0, 14.0), (4.0, 18.0)]), 2.0
        )
        self.assertIsNone(bench.linear_slope([1.0]))

    def test_tree_walk_deduplicates_descendants(self) -> None:
        children = {1: [2, 3, 2], 2: [4], 3: [4], 4: []}
        self.assertEqual(
            bench.collect_descendant_pids(1, lambda pid: children.get(pid, [])),
            [2, 3, 4],
        )

    def test_tree_sum_does_not_turn_missing_into_zero(self) -> None:
        self.assertEqual(bench.sum_optional([2, 3, 5]), 10)
        self.assertIsNone(bench.sum_optional([2, None, 5]))


class IdentityTests(unittest.TestCase):
    def test_changed_starttime_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            stat_path = Path(directory) / "42" / "stat"
            stat_path.parent.mkdir()
            stat_path.write_text(stat_line(42, "qs", starttime=10), encoding="utf-8")
            identity = bench.read_process_identity(42, directory)
            stat_path.write_text(stat_line(42, "qs", starttime=11), encoding="utf-8")
            with self.assertRaises(bench.ProcessIdentityError):
                bench.verify_process_identity(identity, directory)


class CliTests(unittest.TestCase):
    def test_cli_defaults_and_explicit_pid(self) -> None:
        defaults = bench.parse_args(["--pid", "42"])
        self.assertEqual(defaults.pid, 42)
        self.assertEqual(defaults.interval, 1.0)
        self.assertEqual(defaults.warmup, 30.0)
        self.assertEqual(defaults.duration, 60.0)
        self.assertEqual(defaults.memory_every, 5)

        explicit = bench.parse_args(
            [
                "--pid",
                "42",
                "--duration",
                "1",
                "--warmup",
                "0",
                "--interval",
                "0.25",
                "--memory-every",
                "2",
            ]
        )
        self.assertEqual(explicit.warmup, 0)
        self.assertEqual(explicit.interval, 0.25)
        self.assertEqual(explicit.memory_every, 2)


class SummaryTests(unittest.TestCase):
    def test_cpu_baseline_is_not_missing(self) -> None:
        records = [
            {
                "elapsed_seconds": 0.0,
                "main_cpu_percent": None,
                "main_cpu_status": "baseline",
            },
            {
                "elapsed_seconds": 1.0,
                "main_cpu_percent": 10.0,
                "main_cpu_status": "available",
            },
            {
                "elapsed_seconds": 2.0,
                "main_cpu_percent": 12.0,
                "main_cpu_status": "available",
            },
        ]

        stats = bench.build_summary(records)["main"]["cpu_percent"]

        self.assertEqual(stats["status"], "available")
        self.assertEqual(stats["baseline_count"], 1)
        self.assertEqual(stats["skipped_count"], 0)
        self.assertEqual(stats["missing_count"], 0)

    def test_intentional_memory_skips_do_not_make_metric_partial(self) -> None:
        records = [
            {
                "elapsed_seconds": 0.0,
                "main_pss_kib": 10,
                "main_pss_kib_status": "available",
            },
            {
                "elapsed_seconds": 1.0,
                "main_pss_kib": None,
                "main_pss_kib_status": "skipped",
            },
        ]

        stats = bench.build_summary(records)["main"]["pss_kib"]

        self.assertEqual(stats["count"], 1)
        self.assertEqual(stats["skipped_count"], 1)
        self.assertEqual(stats["missing_count"], 0)
        self.assertEqual(stats["status"], "available")

    def test_missing_values_and_processes_are_not_marked_available(self) -> None:
        records = [
            {
                "elapsed_seconds": 0.0,
                "main_pss_kib": 10,
                "main_pss_kib_status": "available",
                "tree_pss_kib": 10,
                "tree_missing_pids": [],
            },
            {
                "elapsed_seconds": 1.0,
                "main_pss_kib": None,
                "main_pss_kib_status": "unavailable",
                "tree_pss_kib": None,
                "tree_missing_pids": [99],
            },
        ]

        summary = bench.build_summary(records)

        self.assertEqual(summary["main"]["pss_kib"]["status"], "partial")
        self.assertEqual(summary["main"]["pss_kib"]["skipped_count"], 0)
        self.assertEqual(summary["main"]["pss_kib"]["missing_count"], 1)
        self.assertEqual(summary["processes"]["status"], "partial")
        self.assertEqual(summary["processes"]["missing_pids"], [99])

    def test_cli_rejects_invalid_values(self) -> None:
        for option, value in (
            ("--duration", "0"),
            ("--warmup", "-1"),
            ("--interval", "nan"),
            ("--memory-every", "0"),
            ("--pid", "0"),
        ):
            with self.subTest(option=option):
                with contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as raised:
                        bench.parse_args([option, value])
                self.assertEqual(raised.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
