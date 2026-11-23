#!/usr/bin/env bash
# Populate the writable /work volume from the read-only image copies.
# Runs once on first start; safe to run again.
set -euo pipefail

mkdir -p \
    /work/models \
    /work/logs \
    /work/osemosys/cases \
    /work/osemosys/runs \
    /work/osemosys/solvers \
    /data \
    /results

for src in /opt/models/*/; do
    [ -d "$src" ] || continue
    name="$(basename "$src")"
    dst="/work/models/${name}"

    if [ ! -d "$dst" ]; then
        cp -a "$src" "$dst"
        echo "  copied ${name} -> ${dst}"
    elif [ "${UPDATE_MODELS:-0}" = "1" ]; then
        rsync -a --delete "$src" "$dst/"
        echo "  refreshed ${name} -> ${dst}"
    fi
done

if [ ! -d /work/examples ]; then
    cp -a /opt/examples /work/examples
    echo "  copied examples -> /work/examples"
elif [ "${UPDATE_EXAMPLES:-0}" = "1" ]; then
    rsync -a --delete /opt/examples/ /work/examples/
    echo "  refreshed examples -> /work/examples"
fi

# Convenience links to the separate data and results volumes.
[ -e /work/data ] || ln -s /data /work/data
[ -e /work/results ] || ln -s /results /work/results

# Copy the provenance record next to the model clones.
if [ -f /opt/models/SOURCES.json ] && [ ! -f /work/models/SOURCES.json ]; then
    cp /opt/models/SOURCES.json /work/models/SOURCES.json
fi

touch /work/.initialized
