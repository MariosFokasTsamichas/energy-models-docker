#!/usr/bin/env bash
# Run the EU-Flex teaser workflow from the writable workspace.
#
# Environment variables:
#   CORES=all                snakemake -c value (default: all)
#   EU_FLEX_CONFIG=...       config file relative to the repo (default: teaser)
#   EU_FLEX_RUN_DIR=...      working directory for the run (default: runs/teaser)
#   DRY_RUN=1                add -n (plan only, no solves)
set -euo pipefail

CORES="${CORES:-all}"
CONFIG="${EU_FLEX_CONFIG:-config/teaser.yaml}"
RUN_DIR="${EU_FLEX_RUN_DIR:-runs/teaser}"

cd /work/models/eu-flex

ARGS=(-c "$CORES" --configfile "$CONFIG" --directory "$RUN_DIR")
if [ "${DRY_RUN:-0}" = "1" ]; then
    ARGS+=(-n)
fi

exec /opt/conda/envs/eu-flex/bin/snakemake "${ARGS[@]}"
