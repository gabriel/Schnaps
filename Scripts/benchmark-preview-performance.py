#!/usr/bin/env python3
"""Compile actual sources from two revisions with -O and run paired kernel benchmarks.

Requires macOS/Xcode. No screen recording permission or source checkout changes.
The baseline adapter mirrors main's crop/filter/resample and synchronous conversion.
"""
import argparse
import hashlib
import json
import pathlib
import platform
import re
import statistics
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]


def command(*args, **kwargs):
    return subprocess.check_output(args, cwd=ROOT, text=True, **kwargs).strip()


def source(ref, path):
    return command("git", "show", f"{ref}:{path}") + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", default="origin/main")
    parser.add_argument("--candidate", default="HEAD")
    parser.add_argument("--trials", type=int, default=5)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()
    if args.trials < 1:
        parser.error("--trials must be positive")
    refs = {name: command("git", "rev-parse", ref) for name, ref in
            [("main", args.baseline), ("candidate", args.candidate)]}
    baseline_capture = source(refs["main"], "Sources/Schnaps/ScreenSnapshot.swift")
    baseline_canvas = source(refs["main"], "Sources/Schnaps/DesignCanvas.swift")
    if ("if let pixels = PixelBuffer(image: image)" not in baseline_capture
            or "var filtered = VisionRenderer.apply(crop, mode: state.vision)" not in baseline_canvas
            or "VisionPreviewCache" in baseline_canvas):
        parser.error("Baseline adapter expects the synchronous/uncached implementation; "
                     "use the pinned baseline revision from the benchmark report.")
    raw = {name: [] for name in refs}
    with tempfile.TemporaryDirectory(prefix="schnaps-preview-benchmark-") as temp:
        temp = pathlib.Path(temp)
        binaries = {}
        for name, ref in refs.items():
            folder = temp / name
            folder.mkdir()
            measurement = folder / "Measurement.swift"
            measurement.write_text(source(ref, "Sources/MeasurementCore/Measurement.swift"))
            subprocess.run(["xcrun", "swiftc", "-O", "-swift-version", "6", "-emit-library", "-emit-module",
                            "-module-name", "MeasurementCore", str(measurement),
                            "-emit-module-path", str(folder / "MeasurementCore.swiftmodule"),
                            "-o", str(folder / "libMeasurementCore.dylib")], check=True)
            inputs = []
            for filename in ["ScreenSnapshot.swift", "VisionRenderer.swift"] + (
                    ["VisionPreviewCache.swift"] if name == "candidate" else []):
                path = folder / filename
                path.write_text(source(ref, f"Sources/Schnaps/{filename}"))
                inputs.append(str(path))
            tools = source(ref, "Sources/Schnaps/DesignTools.swift")
            enum = re.search(r"enum VisionSimulation[^\n]*\{.*?\n\}", tools, re.S).group()
            enum_path = folder / "VisionSimulation.swift"
            enum_path.write_text(enum + "\n")
            binary = folder / "benchmark"
            subprocess.run(["xcrun", "swiftc", "-O", "-swift-version", "6", "-parse-as-library",
                            "-I", str(folder), "-L", str(folder), "-lMeasurementCore",
                            "-Xlinker", "-rpath", "-Xlinker", str(folder),
                            *(["-D", "CACHED"] if name == "candidate" else []),
                            *inputs, str(enum_path), str(ROOT / "Scripts/Benchmarks/preview-performance.swift"),
                            "-o", str(binary)], check=True)
            binaries[name] = binary
        for trial in range(args.trials):
            # Alternate execution order to reduce thermal/order bias; never run variants concurrently.
            for name in (["main", "candidate"] if trial % 2 == 0 else ["candidate", "main"]):
                print(f"Trial {trial + 1}/{args.trials}: {name}", flush=True)
                raw[name].append(json.loads(command(str(binaries[name]))))
                time.sleep(1)
    checksums = {item["workload"]: item["checksum"] for item in raw["main"][0] if "checksum" in item}
    for trials in raw.values():
        for trial in trials:
            for item in trial:
                if "checksum" in item and item["checksum"] != checksums[item["workload"]]:
                    raise RuntimeError(f"Conversion output mismatch: {item['workload']}")
    summary = {}
    for name, trials in raw.items():
        summary[name] = {}
        for index, workload in enumerate(trials[0]):
            metrics = {}
            for key, value in workload.items():
                if isinstance(value, (int, float)):
                    values = [trial[index][key] for trial in trials]
                    metrics[key] = {"median": statistics.median(values), "min": min(values), "max": max(values)}
            summary[name][workload["workload"]] = metrics
    report = {"revisions": refs, "trials": args.trials, "machine": command("sysctl", "-n", "machdep.cpu.brand_string"),
              "os": platform.mac_ver()[0], "compiler": command("xcrun", "swiftc", "--version"),
              "harness_sha256": hashlib.sha256((ROOT / "Scripts/Benchmarks/preview-performance.swift").read_bytes()).hexdigest(),
              "summary": summary, "raw": raw}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
