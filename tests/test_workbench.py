"""Smoke tests for the energy-models-workbench image.

Run inside the container:

    docker run --rm -e START_OSEMOSYS_STUDIO=0 \
        energy-models-workbench:dev \
        /opt/conda/envs/workbench/bin/python -m pytest -q /opt/tests

The tests deliberately avoid downloading data. They check that each
environment is importable, that the pinned Snakemake workflows can plan a
run, and that the OSeMOSYS solver and web server start.
"""

from __future__ import annotations

import json
import socket
import subprocess
import time
import urllib.request
from pathlib import Path

import pytest

ENVS = Path("/opt/conda/envs")
WORKSPACE = Path("/work/models")
KERNELS = Path("/opt/jupyter/kernels")
OSEMOSYS = WORKSPACE / "osemosys-studio"


def env_python(env: str) -> Path:
    path = ENVS / env / "bin" / "python"
    assert path.exists(), f"missing interpreter: {path}"
    return path


def run_python(env: str, code: str, timeout: int = 120) -> str:
    result = subprocess.run(
        [str(env_python(env)), "-c", code],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    assert result.returncode == 0, (
        f"{env} failed\n--- stdout ---\n{result.stdout}\n--- stderr ---\n{result.stderr}"
    )
    return result.stdout


def run_snakemake(env: str, cwd: Path, args: list[str], timeout: int = 300) -> str:
    exe = ENVS / env / "bin" / "snakemake"
    assert exe.exists(), f"missing snakemake: {exe}"
    assert cwd.is_dir(), f"missing workspace directory: {cwd}"
    result = subprocess.run(
        [str(exe), *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    assert result.returncode == 0, (
        f"{env} snakemake failed in {cwd}\n"
        f"--- stdout ---\n{result.stdout}\n--- stderr ---\n{result.stderr}"
    )
    return result.stdout


def test_kernels_are_registered() -> None:
    expected = {"pypsa-eur", "eu-flex", "osemosys", "workbench"}
    found = {p.name for p in KERNELS.iterdir() if p.is_dir()}
    assert expected <= found, f"missing kernels: {expected - found}"

    for name in expected:
        spec = json.loads((KERNELS / name / "kernel.json").read_text())
        assert spec["argv"][0].startswith("/opt/conda/envs/")
        assert spec["language"] == "python"


def test_pypsa_eur_environment() -> None:
    out = run_python(
        "pypsa-eur",
        "import pypsa, atlite, snakemake, highspy; print(pypsa.__version__)",
    )
    assert out.strip()


def test_eu_flex_environment() -> None:
    out = run_python(
        "eu-flex",
        "import euflex, pypsa, snakemake; print(pypsa.__version__)",
    )
    assert out.strip()


def test_osemosys_environment() -> None:
    out = run_python(
        "osemosys",
        "import highspy, swiglpk, pulp, pandas, werkzeug; print(pandas.__version__)",
    )
    assert out.strip()


def test_osemosys_reference_model_solves() -> None:
    if not (OSEMOSYS / "engine" / "solve_check.py").exists():
        pytest.skip("OSeMOSYS workspace not initialised")

    model = OSEMOSYS / "web" / "data" / "builtin_model.txt"
    data = OSEMOSYS / "web" / "data" / "examples" / "gas_solar.txt"
    assert model.exists() and data.exists()

    result = subprocess.run(
        [str(env_python("osemosys")), str(OSEMOSYS / "engine" / "solve_check.py"), str(model), str(data)],
        capture_output=True,
        text=True,
        timeout=300,
    )
    combined = (result.stdout + result.stderr).upper()
    assert result.returncode == 0, combined
    assert "OPTIMAL" in combined, combined


def test_pypsa_eur_workflow_plans() -> None:
    repo = WORKSPACE / "pypsa-eur"
    if not repo.exists():
        pytest.skip("PyPSA-Eur workspace not initialised")
    out = run_snakemake(
        "pypsa-eur",
        repo,
        ["-n", "-c1", "--configfile", "config/test/config.electricity.yaml"],
        timeout=600,
    )
    assert "Job stats" in out or "job" in out.lower() or out.strip()


def test_eu_flex_teaser_plans() -> None:
    repo = WORKSPACE / "eu-flex"
    if not repo.exists():
        pytest.skip("EU-Flex workspace not initialised")
    out = run_snakemake(
        "eu-flex",
        repo,
        ["-n", "-c1", "--configfile", "config/teaser.yaml", "--directory", "runs/teaser"],
        timeout=600,
    )
    assert "Job stats" in out or "job" in out.lower() or out.strip()


def test_osemosys_studio_serves_html(tmp_path: Path) -> None:
    if not (OSEMOSYS / "run_studio.py").exists():
        pytest.skip("OSeMOSYS workspace not initialised")

    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]

    proc = subprocess.Popen(
        [
            str(env_python("osemosys")),
            str(OSEMOSYS / "run_studio.py"),
            "--port",
            str(port),
            "--no-browser",
            "--cases",
            str(tmp_path / "cases"),
            "--runs",
            str(tmp_path / "runs"),
            "--settings",
            str(tmp_path / "settings.json"),
            "--solvers",
            str(tmp_path / "solvers"),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    try:
        deadline = time.time() + 45
        last_error: Exception | None = None
        while time.time() < deadline:
            if proc.poll() is not None:
                output = proc.stdout.read() if proc.stdout else ""
                pytest.fail(f"OSeMOSYS Studio exited early:\n{output}")
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=2) as response:
                    body = response.read(2048).decode("utf-8", "replace")
                    assert response.status == 200
                    assert "<" in body
                    return
            except Exception as exc:  # noqa: BLE001 - startup race is expected
                last_error = exc
                time.sleep(0.5)
        pytest.fail(f"OSeMOSYS Studio did not answer on port {port}: {last_error}")
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
