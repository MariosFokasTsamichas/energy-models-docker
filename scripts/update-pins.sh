#!/usr/bin/env bash
# Refresh the commit pins in versions.env from each repository's default branch.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck disable=SC1091
source versions.env

sha_of() {
    git ls-remote "$1" HEAD | awk '{print $1}'
}

PYPSA_EUR_NEW="$(sha_of "$PYPSA_EUR_REPO")"
EU_FLEX_NEW="$(sha_of "$EU_FLEX_REPO")"
OSEMOSYS_NEW="$(sha_of "$OSEMOSYS_REPO")"

[ -n "$PYPSA_EUR_NEW" ] || { echo "could not resolve PyPSA-Eur" >&2; exit 1; }
[ -n "$EU_FLEX_NEW" ] || { echo "could not resolve EU-Flex" >&2; exit 1; }
[ -n "$OSEMOSYS_NEW" ] || { echo "could not resolve OSeMOSYS Studio" >&2; exit 1; }

tmp="$(mktemp)"
while IFS= read -r line; do
    case "$line" in
        PINNED_ON=*) printf 'PINNED_ON=%s\n' "$(date -u +%F)" ;;
        PYPSA_EUR_REF=*) printf 'PYPSA_EUR_REF=%s\n' "$PYPSA_EUR_NEW" ;;
        EU_FLEX_REF=*) printf 'EU_FLEX_REF=%s\n' "$EU_FLEX_NEW" ;;
        OSEMOSYS_REF=*) printf 'OSEMOSYS_REF=%s\n' "$OSEMOSYS_NEW" ;;
        *) printf '%s\n' "$line" ;;
    esac
done < versions.env > "$tmp"
mv "$tmp" versions.env

echo "Updated versions.env:"
echo "  PyPSA-Eur  $PYPSA_EUR_NEW"
echo "  EU-Flex    $EU_FLEX_NEW"
echo "  OSeMOSYS   $OSEMOSYS_NEW"
