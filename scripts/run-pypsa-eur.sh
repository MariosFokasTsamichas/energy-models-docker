#!/usr/bin/env bash
# Run the PyPSA-Eur test workflow from the writable workspace.
#
# Environment variables:
#   CORES=1|all              snakemake -c value (default: 1)
#   PYPSA_EUR_CONFIG=...     config file relative to the repo (default: test electricity)
#   DRY_RUN=1                add -n (plan only, no downloads or solves)
set -euo pipefail

CORES="${CORES:-1}"
CONFIG="${PYPSA_EUR_CONFIG:-config/test/config.electricity.yaml}"

cd /work/models/pypsa-eur

ARGS=(-c "$CORES" --configfile "$CONFIG")
if [ "${DRY_RUN:-0}" = "1" ]; then
    ARGS+=(-n)
fi

exec /opt/conda/envs/pypsa-eur/bin/snakemake "${ARGS[@]}"
