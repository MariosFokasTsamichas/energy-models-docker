#!/usr/bin/env bash
# Start the Nour OSeMOSYS Studio server.
#
# It binds to 127.0.0.1:8775 inside the container. Open it through
# JupyterLab at http://localhost:8888/proxy/8775/.
set -euo pipefail

PORT="${OSEMOSYS_PORT:-8775}"
ROOT="${OSEMOSYS_ROOT:-/opt/models/osemosys-studio}"
WORK="${OSEMOSYS_WORK:-/work/osemosys}"

mkdir -p "${WORK}/cases" "${WORK}/runs" "${WORK}/solvers" /work/logs

exec /opt/conda/envs/osemosys/bin/python "${ROOT}/run_studio.py" \
    --port "$PORT" \
    --no-browser \
    --cases "${WORK}/cases" \
    --runs "${WORK}/runs" \
    --settings "${WORK}/studio_settings.json" \
    --solvers "${WORK}/solvers"
