#!/usr/bin/env bash
# Build the four conda environments inside the image.
#
# Reproducibility tiers:
#   linux/amd64  PyPSA-Eur uses the exported explicit pin (exact URLs).
#                EU-Flex uses the old-style conda-lock file (exact pins).
#   linux/arm64  Both use the upstream environment.yaml, solved at build time.
#                The upstream projects do not publish linux-aarch64 lock files.
set -euo pipefail

MM="${MM:-/usr/local/bin/micromamba}"
ARCH="${TARGETARCH:-amd64}"
export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-/opt/conda}"

echo "== Building environments for linux/${ARCH} =="

if [ "${BUILD_PYPSA_EUR:-1}" = "1" ]; then
    echo "-- PyPSA-Eur --"
    if [ "$ARCH" = "amd64" ]; then
        SPEC=/opt/models/pypsa-eur/envs/default_linux-64.pin.txt
    else
        SPEC=/opt/models/pypsa-eur/envs/environment.yaml
    fi
    "$MM" create --yes --name pypsa-eur --file "$SPEC"
    # The pinned environment has no pip/ipykernel. ensurepip adds pip without
    # asking the conda solver to touch the pinned package set.
    /opt/conda/envs/pypsa-eur/bin/python -m ensurepip --upgrade
    /opt/conda/envs/pypsa-eur/bin/python -m pip install --no-cache-dir ipykernel
fi

if [ "${BUILD_EU_FLEX:-1}" = "1" ]; then
    echo "-- EU-Flex --"
    if [ "$ARCH" = "amd64" ]; then
        SPEC=/opt/models/eu-flex/envs/linux-64.lock.yaml
    else
        SPEC=/opt/models/eu-flex/envs/environment.yaml
    fi
    "$MM" create --yes --name eu-flex --file "$SPEC"
    /opt/conda/envs/eu-flex/bin/python -m pip install --no-cache-dir ipykernel
    if [ "$ARCH" != "amd64" ]; then
        # micromamba does not execute the pip: subsection of environment.yaml.
        /opt/conda/envs/eu-flex/bin/python -m pip install --no-cache-dir highspy
    fi
    # EU-Flex is a Python package as well as a Snakemake workflow.
    /opt/conda/envs/eu-flex/bin/python -m pip install --no-cache-dir --no-build-isolation -e /opt/models/eu-flex
fi

if [ "${BUILD_OSEMOSYS:-1}" = "1" ]; then
    echo "-- Nour OSeMOSYS Studio --"
    "$MM" create --yes --name osemosys \
        --channel conda-forge --channel nodefaults \
        python=3.12 \
        "pandas>=2.2,<3" \
        numpy \
        openpyxl \
        werkzeug \
        scipy \
        glpk \
        coin-or-cbc \
        highspy \
        swiglpk \
        ipykernel \
        pip
    /opt/conda/envs/osemosys/bin/python -m pip install --no-cache-dir "pulp>=2.7,<3"
fi

echo "-- Workbench --"
"$MM" create --yes --name workbench \
    --channel conda-forge --channel nodefaults \
    python=3.12 \
    jupyterlab \
    jupyter-server-proxy \
    ipykernel \
    pytest \
    matplotlib \
    pandas \
    numpy \
    scipy

# Remove tarballs and unused package records. The environments are hardlinked
# into place, so this keeps the image smaller without breaking them.
"$MM" clean --all --yes

echo "== Environment build complete =="
