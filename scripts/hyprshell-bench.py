#!/usr/bin/env python3
"""Reproducible resource baseline for an existing Quickshell ``qs`` process.

The benchmark attaches to a running process. It never reads environ/cmdline,
never starts the shell, and uses only the Python standard library plus Linux
``/proc``. Samples are optionally written as JSONL; the human summary is kept
on a different stream so machine-readable output stays valid.

Example: ``hyprshell-bench.py --scenario baseline --duration 60 --jsonl
baseline.jsonl``; for a direct PID use ``--pid 1234``.
"""

from __future__ import annotations

import argparse
import json
import math
import os
from dataclasses import dataclass
from pathlib import Path
import re
import statistics
import subprocess
import sys
import time
from typing import Callable, Iterable, Optional, Sequence


EXIT_OK = 0
EXIT_USAGE = 2
EXIT_DISCOVERY = 3
EXIT_RUNTIME = 4
EXIT_INVALID_RUN = 5

DEFAULT_DURATION = 60.0
DEFAULT_WARMUP = 30.0
DEFAULT_INTERVAL = 1.0
DEFAULT_MEMORY_EVERY = 5
DEFAULT_CLK_TCK = int(os.sysconf("SC_CLK_TCK"))
DEFAULT_PAGE_SIZE = int(os.sysconf("SC_PAGE_SIZE"))


class BenchmarkError(RuntimeError):
    """Base class for expected benchmark failures."""


class DiscoveryError(BenchmarkError):
    """The target process could not be discovered."""


class ProcessUnavailableError(BenchmarkError):
    """The target disappeared while it was being sampled."""


class ProcessIdentityError(BenchmarkError):
    """The target PID now belongs to another process."""


@dataclass(frozen=True)
class QsInstance:
    pid: int
    config_path: str


@dataclass(frozen=True)
class ProcStat:
    pid: int
    comm: str
    state: str
    ppid: int
    utime: int
    stime: int
    num_threads: int
    starttime: int
    rss_pages: int

    @property
    def cpu_ticks(self) -> int:
        return self.utime + self.stime


@dataclass(frozen=True)
class ProcessIdentity:
    pid: int
    starttime: int


@dataclass(frozen=True)
class ProcessMetrics:
    pid: int
    name: str
    starttime: int
    cpu_ticks: int
    rss_kib: Optional[int]
    hwm_kib: Optional[int]
    pss_kib: Optional[int]
    uss_kib: Optional[int]
    fds: Optional[int]
    threads: Optional[int]
    rss_status: str
    hwm_status: str
    pss_status: str
    uss_status: str
    fds_status: str
    threads_status: str


@dataclass(frozen=True)
class CapturedTree:
    wall_time: float
    monotonic_time: float
    processes: tuple[ProcessMetrics, ...]
    missing_pids: tuple[int, ...]

    @property
    def root(self) -> ProcessMetrics:
        return self.processes[0]


def _parse_kib_value(value: str) -> Optional[int]:
    match = re.match(r"^\s*(\d+)\s*(kB|KB|KiB)\s*$", value)
    if not match:
        return None
    return int(match.group(1))


def parse_proc_stat(line: str) -> ProcStat:
    """Parse ``/proc/<pid>/stat`` without splitting the process name."""

    first_space = line.find(" ")
    if first_space <= 0:
        raise ValueError("/proc stat has no pid separator")
    opening = line.find("(", first_space)
    closing = line.rfind(") ")
    if opening < 0 or closing <= opening:
        raise ValueError("/proc stat has no valid comm field")

    pid = int(line[:first_space])
    comm = line[opening + 1 : closing]
    fields = line[closing + 2 :].split()
    if len(fields) < 22:
        raise ValueError("/proc stat is missing fields")

    return ProcStat(
        pid=pid,
        comm=comm,
        state=fields[0],
        ppid=int(fields[1]),
        utime=int(fields[11]),
        stime=int(fields[12]),
        num_threads=int(fields[17]),
        starttime=int(fields[19]),
        rss_pages=int(fields[21]),
    )


def parse_status(text: str) -> dict[str, Optional[int]]:
    """Parse memory fields from ``/proc/<pid>/status``."""

    result: dict[str, Optional[int]] = {"VmRSS": None, "VmHWM": None}
    for line in text.splitlines():
        key, separator, value = line.partition(":")
        if separator and key in result:
            result[key] = _parse_kib_value(value)
    return result


def parse_smaps_rollup(text: str) -> dict[str, Optional[int]]:
    """Parse PSS and private memory, returning None when unavailable."""

    values: dict[str, Optional[int]] = {
        "Pss": None,
        "Private_Clean": None,
        "Private_Dirty": None,
    }
    for line in text.splitlines():
        key, separator, value = line.partition(":")
        if separator and key in values:
            values[key] = _parse_kib_value(value)

    private_clean = values["Private_Clean"]
    private_dirty = values["Private_Dirty"]
    uss = None
    if private_clean is not None and private_dirty is not None:
        uss = private_clean + private_dirty
    return {"pss_kib": values["Pss"], "uss_kib": uss}


def _proc_path(pid: int, proc_root: os.PathLike[str] | str, name: str) -> Path:
    return Path(proc_root) / str(pid) / name


def read_proc_stat(pid: int, proc_root: os.PathLike[str] | str = "/proc") -> ProcStat:
    try:
        text = _proc_path(pid, proc_root, "stat").read_text(encoding="utf-8")
    except (FileNotFoundError, PermissionError, OSError) as error:
        raise ProcessUnavailableError(f"process {pid} disappeared") from error
    try:
        return parse_proc_stat(text.strip())
    except (TypeError, ValueError) as error:
        raise ProcessUnavailableError(f"process {pid} has an unreadable stat") from error


def read_process_identity(
    pid: int, proc_root: os.PathLike[str] | str = "/proc"
) -> ProcessIdentity:
    stat = read_proc_stat(pid, proc_root)
    return ProcessIdentity(pid=pid, starttime=stat.starttime)


def verify_process_identity(
    identity: ProcessIdentity, proc_root: os.PathLike[str] | str = "/proc"
) -> ProcStat:
    """Reject a missing or reused PID before accepting a sample."""

    current = read_proc_stat(identity.pid, proc_root)
    if current.starttime != identity.starttime:
        raise ProcessIdentityError(
            f"PID {identity.pid} was reused "
            f"(starttime {identity.starttime} -> {current.starttime})"
        )
    return current


def read_children(pid: int, proc_root: os.PathLike[str] | str = "/proc") -> list[int]:
    try:
        text = _proc_path(pid, proc_root, f"task/{pid}/children").read_text(
            encoding="utf-8"
        )
    except (FileNotFoundError, PermissionError, OSError):
        return []

    children: list[int] = []
    for token in text.split():
        try:
            child = int(token)
        except ValueError:
            continue
        if child > 0:
            children.append(child)
    return children


def collect_descendant_pids(
    root_pid: int,
    children_reader: Optional[Callable[[int], Iterable[int]]] = None,
    proc_root: os.PathLike[str] | str = "/proc",
) -> list[int]:
    """Return each descendant once, tolerating disappearing parents."""

    if children_reader is None:
        children_reader = lambda pid: read_children(pid, proc_root)

    seen = {root_pid}
    descendants: list[int] = []
    pending = [root_pid]
    while pending:
        parent = pending.pop(0)
        try:
            children = children_reader(parent)
        except (FileNotFoundError, PermissionError, OSError):
            children = ()
        for child in children:
            if child <= 0 or child in seen:
                continue
            seen.add(child)
            descendants.append(child)
            pending.append(child)
    return descendants


def _read_optional_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (FileNotFoundError, PermissionError, OSError):
        return ""


def _count_fds(pid: int, proc_root: os.PathLike[str] | str) -> Optional[int]:
    try:
        with os.scandir(_proc_path(pid, proc_root, "fd")) as entries:
            return sum(1 for _ in entries)
    except (FileNotFoundError, PermissionError, OSError):
        return None


def read_process_metrics(
    pid: int,
    proc_root: os.PathLike[str] | str = "/proc",
    include_memory: bool = True,
) -> ProcessMetrics:
    """Read safe process fields; no environ, cmdline, or command arguments."""

    stat = read_proc_stat(pid, proc_root)
    status = parse_status(_read_optional_text(_proc_path(pid, proc_root, "status")))
    rss_kib = status["VmRSS"]
    if rss_kib is None:
        rss_kib = stat.rss_pages * DEFAULT_PAGE_SIZE // 1024
    rss_status = "available" if rss_kib is not None else "unavailable"
    hwm_kib = status["VmHWM"]
    hwm_status = "available" if hwm_kib is not None else "unavailable"

    pss_kib: Optional[int] = None
    uss_kib: Optional[int] = None
    if include_memory:
        memory = parse_smaps_rollup(
            _read_optional_text(_proc_path(pid, proc_root, "smaps_rollup"))
        )
        pss_kib = memory["pss_kib"]
        uss_kib = memory["uss_kib"]
        pss_status = "available" if pss_kib is not None else "unavailable"
        uss_status = "available" if uss_kib is not None else "unavailable"
    else:
        pss_status = "skipped"
        uss_status = "skipped"

    fds = _count_fds(pid, proc_root)
    fds_status = "available" if fds is not None else "unavailable"
    threads = stat.num_threads
    return ProcessMetrics(
        pid=stat.pid,
        name=stat.comm,
        starttime=stat.starttime,
        cpu_ticks=stat.cpu_ticks,
        rss_kib=rss_kib,
        hwm_kib=hwm_kib,
        pss_kib=pss_kib,
        uss_kib=uss_kib,
        fds=fds,
        threads=threads,
        rss_status=rss_status,
        hwm_status=hwm_status,
        pss_status=pss_status,
        uss_status=uss_status,
        fds_status=fds_status,
        threads_status="available",
    )


def _aggregate_field(
    processes: Sequence[ProcessMetrics],
    value_name: str,
    status_name: str,
) -> tuple[Optional[int], str]:
    if not processes:
        return None, "unavailable"
    statuses = [getattr(process, status_name) for process in processes]
    if all(status == "skipped" for status in statuses):
        return None, "skipped"
    values = [getattr(process, value_name) for process in processes]
    if any(value is None for value in values):
        if any(value is not None for value in values):
            return None, "partial"
        return None, "unavailable"
    return sum(values), "available"


def sum_optional(values: Iterable[Optional[int]]) -> Optional[int]:
    """Sum only complete measurements; never turn missing values into zero."""

    materialized = list(values)
    if not materialized or any(value is None for value in materialized):
        return None
    return sum(materialized)


def aggregate_tree(
    processes: Sequence[ProcessMetrics],
) -> dict[str, tuple[Optional[int], str]]:
    return {
        "rss_kib": _aggregate_field(processes, "rss_kib", "rss_status"),
        "hwm_kib": _aggregate_field(processes, "hwm_kib", "hwm_status"),
        "pss_kib": _aggregate_field(processes, "pss_kib", "pss_status"),
        "uss_kib": _aggregate_field(processes, "uss_kib", "uss_status"),
        "fds": _aggregate_field(processes, "fds", "fds_status"),
        "threads": _aggregate_field(processes, "threads", "threads_status"),
    }


def capture_tree(
    identity: ProcessIdentity,
    include_memory: bool,
    proc_root: os.PathLike[str] | str = "/proc",
) -> CapturedTree:
    """Capture the root and a best-effort descendant snapshot."""

    root_stat = verify_process_identity(identity, proc_root)
    root = read_process_metrics(identity.pid, proc_root, include_memory)
    if root.starttime != root_stat.starttime:
        raise ProcessIdentityError(f"PID {identity.pid} changed during sampling")

    descendants = collect_descendant_pids(identity.pid, proc_root=proc_root)
    processes = [root]
    missing: list[int] = []
    for pid in descendants:
        try:
            processes.append(read_process_metrics(pid, proc_root, include_memory))
        except ProcessUnavailableError:
            missing.append(pid)

    verify_process_identity(identity, proc_root)
    return CapturedTree(
        wall_time=time.time(),
        monotonic_time=time.monotonic(),
        processes=tuple(processes),
        missing_pids=tuple(missing),
    )


def cpu_percent(
    previous_ticks: Optional[int],
    current_ticks: int,
    elapsed_seconds: float,
    clk_tck: int = DEFAULT_CLK_TCK,
) -> Optional[float]:
    """Calculate CPU from successive utime+stime snapshots."""

    if previous_ticks is None or elapsed_seconds <= 0 or clk_tck <= 0:
        return None
    delta = current_ticks - previous_ticks
    if delta < 0:
        return None
    return delta * 100.0 / clk_tck / elapsed_seconds


def median(values: Sequence[float]) -> Optional[float]:
    return statistics.median(values) if values else None


def percentile(values: Sequence[float], percentage: float) -> Optional[float]:
    """Linear-interpolated percentile, deterministic for small samples."""

    if not values:
        return None
    if not 0 <= percentage <= 100:
        raise ValueError("percentage must be between 0 and 100")
    ordered = sorted(values)
    position = (len(ordered) - 1) * percentage / 100.0
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return float(ordered[lower])
    fraction = position - lower
    return float(ordered[lower]) + (ordered[upper] - ordered[lower]) * fraction


def linear_slope(
    values: Sequence[float] | Sequence[tuple[float, float]],
    xs: Optional[Sequence[float]] = None,
) -> Optional[float]:
    """Return the least-squares slope, using sample index by default."""

    if xs is None:
        if values and isinstance(values[0], tuple):
            points = [
                (float(point[0]), float(point[1]))
                for point in values  # type: ignore[union-attr]
            ]
        else:
            points = [
                (float(index), float(value))
                for index, value in enumerate(values)  # type: ignore[arg-type]
            ]
    else:
        points = [
            (float(x), float(y)) for x, y in zip(xs, values)  # type: ignore[arg-type]
        ]
    if len(points) < 2:
        return None
    mean_x = statistics.fmean(point[0] for point in points)
    mean_y = statistics.fmean(point[1] for point in points)
    denominator = sum((x - mean_x) ** 2 for x, _ in points)
    if denominator == 0:
        return None
    numerator = sum((x - mean_x) * (y - mean_y) for x, y in points)
    return numerator / denominator


def parse_qs_list(output: str) -> list[QsInstance]:
    """Parse ``qs list --all`` blocks without depending on their ordering."""

    clean = re.sub(r"\x1b\[[0-9;]*m", "", output)
    blocks: list[list[str]] = []
    current: list[str] = []
    for line in clean.splitlines():
        if not line.strip():
            if current:
                blocks.append(current)
                current = []
            continue
        starts_instance = re.match(r"^\s*Instance\b", line, re.IGNORECASE)
        starts_process = re.match(r"^\s*Process ID\s*:", line, re.IGNORECASE)
        has_process = any(
            re.match(r"^\s*Process ID\s*:", previous, re.IGNORECASE)
            for previous in current
        )
        if current and (starts_instance or (starts_process and has_process)):
            blocks.append(current)
            current = []
        current.append(line)
    if current:
        blocks.append(current)

    instances: list[QsInstance] = []
    for block in blocks:
        pid: Optional[int] = None
        config_path: Optional[str] = None
        for line in block:
            key, separator, value = line.partition(":")
            if not separator:
                continue
            normalized_key = key.strip().lower()
            value = value.strip()
            if normalized_key == "process id":
                match = re.fullmatch(r"\d+", value)
                if match:
                    pid = int(value)
            elif normalized_key == "config path":
                config_path = value
        if pid is not None and config_path:
            instances.append(QsInstance(pid=pid, config_path=config_path))
    return instances


def _normalized_path(value: str | os.PathLike[str]) -> str:
    return os.path.realpath(os.path.expanduser(os.fspath(value)))


def discover_qs_pid(config_path: str | os.PathLike[str]) -> int:
    """Find exactly one running qs instance for a config, without a shell."""

    try:
        result = subprocess.run(
            ["qs", "list", "--all"],
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired) as error:
        raise DiscoveryError(f"could not execute 'qs list --all': {error}") from error
    if result.returncode != 0:
        raise DiscoveryError(
            f"'qs list --all' failed with exit code {result.returncode}"
        )

    expected = _normalized_path(config_path)
    matches = [
        instance
        for instance in parse_qs_list(result.stdout)
        if _normalized_path(instance.config_path) == expected
    ]
    if not matches:
        raise DiscoveryError(f"no running qs instance uses config {config_path}")
    if len(matches) > 1:
        pids = ", ".join(str(instance.pid) for instance in matches)
        raise DiscoveryError(f"config {config_path} matches multiple qs PIDs: {pids}")
    return matches[0].pid


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="hyprshell-bench.py",
        description=(
            "Measure an existing qs process and its descendants via /proc.\n\n"
            "Example: hyprshell-bench.py --scenario baseline --duration 60 "
            "--jsonl baseline.jsonl; direct PID mode: hyprshell-bench.py "
            "--pid 1234 --scenario baseline --duration 60 --jsonl -"
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        allow_abbrev=False,
    )
    parser.add_argument(
        "--scenario",
        default="baseline",
        help="label attached to every sample",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=DEFAULT_DURATION,
        help="measurement duration in seconds",
    )
    parser.add_argument(
        "--warmup",
        type=float,
        default=DEFAULT_WARMUP,
        help="warmup duration in seconds",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=DEFAULT_INTERVAL,
        help="seconds between samples",
    )
    parser.add_argument(
        "--memory-every",
        type=int,
        default=DEFAULT_MEMORY_EVERY,
        metavar="N",
        help="read smaps_rollup on every Nth sample; other samples are skipped",
    )
    parser.add_argument(
        "--jsonl",
        metavar="PATH",
        help="write samples as JSONL; use '-' for stdout",
    )
    parser.add_argument("--pid", type=int, help="attach directly to this PID")
    parser.add_argument(
        "--config",
        help="config path used by qs discovery (default: repository shell.qml)",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="suppress the human summary (errors still go to stderr)",
    )
    return parser


def validate_args(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    if not args.scenario.strip():
        parser.error("--scenario must not be empty")
    for name in ("duration", "interval"):
        value = getattr(args, name)
        if not math.isfinite(value) or value <= 0:
            parser.error(f"--{name} must be a finite number greater than zero")
    if not math.isfinite(args.warmup) or args.warmup < 0:
        parser.error("--warmup must be a finite number greater than or equal to zero")
    if args.memory_every <= 0:
        parser.error("--memory-every must be a positive integer")
    if args.pid is not None and args.pid <= 0:
        parser.error("--pid must be a positive integer")
    if args.jsonl == "":
        parser.error("--jsonl PATH must not be empty")


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = build_parser()
    args = parser.parse_args(argv)
    validate_args(parser, args)
    return args


class JsonlWriter:
    def __init__(self, path: Optional[str]) -> None:
        self.path = path
        self.stream = sys.stdout if path == "-" else None
        self.owns_stream = False

    def __enter__(self) -> "JsonlWriter":
        if self.path and self.path != "-":
            self.stream = open(self.path, "w", encoding="utf-8")
            self.owns_stream = True
        return self

    def write(self, sample: dict[str, object]) -> None:
        if self.stream is None:
            return
        json.dump(sample, self.stream, sort_keys=True, separators=(",", ":"))
        self.stream.write("\n")
        self.stream.flush()

    def __exit__(self, *_: object) -> None:
        if self.owns_stream and self.stream is not None:
            self.stream.close()


def _cpu_status(value: Optional[float], previous: Optional[CapturedTree]) -> str:
    if value is not None:
        return "available"
    return "baseline" if previous is None else "unavailable"


def make_sample(
    current: CapturedTree,
    previous: Optional[CapturedTree],
    phase_start: float,
    scenario: str,
    phase: str,
    sample_index: int,
    identity: ProcessIdentity,
    process_label: str,
) -> dict[str, object]:
    tree_values = aggregate_tree(current.processes)
    elapsed = current.monotonic_time - phase_start
    previous_ticks = previous.root.cpu_ticks if previous else None
    tree_ticks = sum(process.cpu_ticks for process in current.processes)
    previous_tree_ticks = (
        sum(process.cpu_ticks for process in previous.processes) if previous else None
    )
    main_cpu = cpu_percent(
        previous_ticks,
        current.root.cpu_ticks,
        current.monotonic_time - previous.monotonic_time if previous else 0,
    )
    tree_cpu = cpu_percent(
        previous_tree_ticks,
        tree_ticks,
        current.monotonic_time - previous.monotonic_time if previous else 0,
    )
    root = current.root
    sample: dict[str, object] = {
        "timestamp": current.wall_time,
        "elapsed_seconds": elapsed,
        "scenario": scenario,
        "phase": phase,
        "sample_index": sample_index,
        "pid": identity.pid,
        "process_label": process_label,
        "process_name": root.name,
        "tree_pids": [process.pid for process in current.processes],
        "tree_count": len(current.processes),
        "tree_names": [process.name for process in current.processes],
        "tree_missing_pids": list(current.missing_pids),
        "tree_process_status": (
            "partial" if current.missing_pids else "available"
        ),
        "main_cpu_percent": main_cpu,
        "main_cpu_status": _cpu_status(main_cpu, previous),
        "tree_cpu_percent": tree_cpu,
        "tree_cpu_status": _cpu_status(tree_cpu, previous),
    }
    for prefix, metrics in (("main", root), ("tree", tree_values)):
        if prefix == "main":
            values = {
                "rss_kib": (metrics.rss_kib, metrics.rss_status),
                "hwm_kib": (metrics.hwm_kib, metrics.hwm_status),
                "pss_kib": (metrics.pss_kib, metrics.pss_status),
                "uss_kib": (metrics.uss_kib, metrics.uss_status),
                "fds": (metrics.fds, metrics.fds_status),
                "threads": (metrics.threads, metrics.threads_status),
            }
        else:
            values = metrics
        for name, (value, status) in values.items():
            sample[f"{prefix}_{name}"] = value
            sample[f"{prefix}_{name}_status"] = status
    return sample


def _metric_stats(
    records: Sequence[dict[str, object]],
    key: str,
    status_key: Optional[str] = None,
) -> dict[str, object]:
    values: list[float] = []
    baseline_count = 0
    skipped_count = 0
    missing_count = 0
    status_key = status_key or f"{key}_status"
    for record in records:
        value = record.get(key)
        if value is not None:
            values.append(float(value))
        elif record.get(status_key) == "baseline":
            baseline_count += 1
        elif record.get(status_key) == "skipped":
            skipped_count += 1
        else:
            missing_count += 1

    if not values:
        return {
            "count": 0,
            "baseline_count": baseline_count,
            "skipped_count": skipped_count,
            "missing_count": missing_count,
            "median": None,
            "p95": None,
            "max": None,
            "status": "skipped" if skipped_count and not missing_count else "unavailable",
        }
    return {
        "count": len(values),
        "baseline_count": baseline_count,
        "skipped_count": skipped_count,
        "missing_count": missing_count,
        "median": median(values),
        "p95": percentile(values, 95),
        "max": max(values),
        "status": "partial" if missing_count else "available",
    }


def _trend(records: Sequence[dict[str, object]], key: str) -> Optional[float]:
    points = [
        (float(record["elapsed_seconds"]), float(value))
        for record in records
        if (value := record.get(key)) is not None
    ]
    return linear_slope(points)


def build_summary(records: Sequence[dict[str, object]]) -> dict[str, object]:
    metrics = {
        "rss_kib": ("rss_kib", "rss_kib_status"),
        "pss_kib": ("pss_kib", "pss_kib_status"),
        "uss_kib": ("uss_kib", "uss_kib_status"),
        "cpu_percent": ("cpu_percent", "cpu_status"),
        "fds": ("fds", "fds_status"),
    }
    summary: dict[str, object] = {"sample_count": len(records)}
    for prefix in ("main", "tree"):
        summary[prefix] = {
            name: _metric_stats(records, f"{prefix}_{key}", f"{prefix}_{status_key}")
            for name, (key, status_key) in metrics.items()
        }
    missing_pids = sorted(
        {
            pid
            for record in records
            for pid in (record.get("tree_missing_pids") or [])
        }
    )
    summary["processes"] = {
        "missing_pids": missing_pids,
        "status": "partial" if missing_pids else "available",
    }
    summary["trend"] = {
        prefix: {
            "pss_kib_per_second": _trend(records, f"{prefix}_pss_kib"),
            "uss_kib_per_second": _trend(records, f"{prefix}_uss_kib"),
            "fds_per_second": _trend(records, f"{prefix}_fds"),
        }
        for prefix in ("main", "tree")
    }
    return summary


def _format_value(value: object) -> str:
    if value is None:
        return "unavailable"
    if isinstance(value, float):
        return f"{value:.3f}"
    return str(value)


def print_summary(
    summary: dict[str, object],
    scenario: str,
    pid: int,
    process_label: str,
    stream: object,
) -> None:
    print(f"Benchmark summary: {scenario} ({process_label}, PID {pid})", file=stream)
    print(f"Measurement samples: {summary['sample_count']}", file=stream)
    print("metric                 median       p95        max     status", file=stream)
    for prefix in ("tree", "main"):
        group = summary[prefix]
        assert isinstance(group, dict)
        for metric in ("rss_kib", "pss_kib", "uss_kib", "cpu_percent", "fds"):
            stats = group[metric]
            assert isinstance(stats, dict)
            label = f"{prefix} {metric}"
            print(
                f"{label:<22} {_format_value(stats['median']):>10}"
                f" {_format_value(stats['p95']):>10} {_format_value(stats['max']):>10}"
                f" {stats['status']:>10}",
                file=stream,
            )
    processes = summary["processes"]
    assert isinstance(processes, dict)
    print(f"processes status: {processes['status']}", file=stream)
    if processes["missing_pids"]:
        print(f"missing descendant PIDs: {processes['missing_pids']}", file=stream)
    print("trend (linear slope per second)", file=stream)
    trends = summary["trend"]
    assert isinstance(trends, dict)
    for prefix in ("tree", "main"):
        values = trends[prefix]
        assert isinstance(values, dict)
        group = summary[prefix]
        assert isinstance(group, dict)
        pss_status = group["pss_kib"]["status"]
        uss_status = group["uss_kib"]["status"]
        fds_status = group["fds"]["status"]
        print(
            f"{prefix:<6} PSS {_format_value(values['pss_kib_per_second'])}"
            f" ({pss_status}), USS {_format_value(values['uss_kib_per_second'])}"
            f" ({uss_status}), FDs {_format_value(values['fds_per_second'])}"
            f" ({fds_status})",
            file=stream,
        )


def _default_config_path() -> Path:
    return Path(__file__).resolve().parent.parent / "shell.qml"


def _resolve_target(args: argparse.Namespace) -> tuple[int, str, Optional[str]]:
    if args.pid is not None:
        config = args.config
        return args.pid, f"pid-{args.pid}", config

    config_path = Path(args.config).expanduser() if args.config else _default_config_path()
    if not config_path.exists():
        raise DiscoveryError(f"config path does not exist: {config_path}")
    config_path = config_path.resolve()
    pid = discover_qs_pid(config_path)
    return pid, f"qs-{config_path.name}", str(config_path)


def _sample_phase(
    identity: ProcessIdentity,
    duration: float,
    interval: float,
    memory_every: int,
    scenario: str,
    phase: str,
    process_label: str,
    writer: JsonlWriter,
) -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    phase_start = time.monotonic()
    deadline = phase_start + duration
    previous: Optional[CapturedTree] = None
    sample_index = 0

    while True:
        include_memory = sample_index % memory_every == 0
        current = capture_tree(identity, include_memory)
        sample = make_sample(
            current,
            previous,
            phase_start,
            scenario,
            phase,
            sample_index,
            identity,
            process_label,
        )
        writer.write(sample)
        records.append(sample)
        previous = current
        sample_index += 1
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        time.sleep(min(interval, remaining))
    return records


def run_benchmark(args: argparse.Namespace) -> int:
    try:
        pid, process_label, config = _resolve_target(args)
        identity = read_process_identity(pid)
    except DiscoveryError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_DISCOVERY
    except ProcessUnavailableError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_RUNTIME

    summary_stream = sys.stderr if args.jsonl == "-" else sys.stdout
    try:
        with JsonlWriter(args.jsonl) as writer:
            if args.warmup > 0:
                _sample_phase(
                    identity,
                    args.warmup,
                    args.interval,
                    args.memory_every,
                    args.scenario,
                    "warmup",
                    process_label,
                    writer,
                )
            records = _sample_phase(
                identity,
                args.duration,
                args.interval,
                args.memory_every,
                args.scenario,
                "measurement",
                process_label,
                writer,
            )
    except (BenchmarkError, OSError, ValueError, BrokenPipeError) as error:
        print(
            f"INVALID benchmark: {error}; no valid summary was produced",
            file=sys.stderr,
        )
        return EXIT_INVALID_RUN

    summary = build_summary(records)
    if not args.quiet:
        print_summary(summary, args.scenario, pid, process_label, summary_stream)
    return EXIT_OK


def main(argv: Optional[Sequence[str]] = None) -> int:
    try:
        args = parse_args(argv)
    except SystemExit as error:
        return int(error.code)
    return run_benchmark(args)


if __name__ == "__main__":
    raise SystemExit(main())
