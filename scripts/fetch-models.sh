#!/usr/bin/env bash
# Clone each model repository at an exact commit into DEST.
#
# The repository/commit pairs come from versions.env. They are passed as
# environment variables so the Dockerfile build args can override them.
set -euo pipefail

DEST="${1:-/opt/models}"

: "${PYPSA_EUR_REPO:?PYPSA_EUR_REPO is required}"
: "${PYPSA_EUR_REF:?PYPSA_EUR_REF is required}"
: "${EU_FLEX_REPO:?EU_FLEX_REPO is required}"
: "${EU_FLEX_REF:?EU_FLEX_REF is required}"
: "${OSEMOSYS_REPO:?OSEMOSYS_REPO is required}"
: "${OSEMOSYS_REF:?OSEMOSYS_REF is required}"

mkdir -p "$DEST"

clone_at() {
    local repo="$1"
    local ref="$2"
    local dest="$3"

    rm -rf "$dest"
    git init -q "$dest"
    git -C "$dest" remote add origin "$repo"
    git -C "$dest" fetch -q --depth 1 origin "$ref"
    git -C "$dest" checkout -q --detach FETCH_HEAD

    local actual
    actual="$(git -C "$dest" rev-parse HEAD)"
    printf '  %-16s %s\n' "$(basename "$dest")" "$actual"
    printf '%s' "$actual" > "$dest/.hem-ref"
}

echo "Cloning pinned model sources into $DEST"
clone_at "$PYPSA_EUR_REPO" "$PYPSA_EUR_REF" "$DEST/pypsa-eur"
clone_at "$EU_FLEX_REPO" "$EU_FLEX_REF" "$DEST/eu-flex"
clone_at "$OSEMOSYS_REPO" "$OSEMOSYS_REF" "$DEST/osemosys-studio"

# Record provenance in the image. This file is also copied into /work/models
# by init-workspace.sh, so users can see exactly what they are running.
cat > "$DEST/SOURCES.json" <<EOF
{
  "pinned_on": "$(date -u +%F)",
  "models": {
    "pypsa-eur": {
      "repository": "$PYPSA_EUR_REPO",
      "requested_ref": "$PYPSA_EUR_REF",
      "commit": "$(git -C "$DEST/pypsa-eur" rev-parse HEAD)"
    },
    "eu-flex": {
      "repository": "$EU_FLEX_REPO",
      "requested_ref": "$EU_FLEX_REF",
      "commit": "$(git -C "$DEST/eu-flex" rev-parse HEAD)"
    },
    "osemosys-studio": {
      "repository": "$OSEMOSYS_REPO",
      "requested_ref": "$OSEMOSYS_REF",
      "commit": "$(git -C "$DEST/osemosys-studio" rev-parse HEAD)"
    }
  }
}
EOF

echo "Wrote $DEST/SOURCES.json"
