#!/usr/bin/env bash
# Run the workbench smoke tests inside the container.
set -euo pipefail

exec /opt/conda/envs/workbench/bin/python -m pytest -q /opt/tests
