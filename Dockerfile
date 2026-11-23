# syntax=docker/dockerfile:1

# Energy Models Workbench: one JupyterLab image with three isolated model
# environments (PyPSA-Eur, EU-Flex, Nour OSeMOSYS Studio).
#
# Build:
#   docker build -t energy-models-workbench:dev .
# or, on Apple Silicon, force the native architecture:
#   docker build --platform linux/arm64 -t energy-models-workbench:dev .
#
# The upstream model sources are pinned in versions.env. The defaults below
# must stay in sync with that file; `make build` and the CI workflow pass the
# pinned values explicitly.

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

# Re-declared after FROM so the label below can interpolate it.
ARG UBUNTU_VERSION

ARG TARGETARCH
ARG MICROMAMBA_VERSION=2.10.0-0

ARG PYPSA_EUR_REPO=https://github.com/PyPSA/pypsa-eur.git
ARG PYPSA_EUR_REF=4b2822102a3b4b2c90be1b48bf221a2bb59e0d06
ARG EU_FLEX_REPO=https://github.com/EU-ACER/eu-flex-model.git
ARG EU_FLEX_REF=65cb449bc1ddc3731f542337e1a0e5dbddc35536
ARG OSEMOSYS_REPO=https://github.com/Islam-Dj/Nour-OSeMOSYS-Studio-Standard.git
ARG OSEMOSYS_REF=1602afd56e47d444906f56d7ff5af8951ae87808

ARG BUILD_PYPSA_EUR=1
ARG BUILD_EU_FLEX=1
ARG BUILD_OSEMOSYS=1

LABEL org.opencontainers.image.title="Energy Models Workbench"
LABEL org.opencontainers.image.description="JupyterLab workbench with PyPSA-Eur, EU-Flex and Nour OSeMOSYS Studio"
LABEL org.opencontainers.image.source="https://github.com/MariosFokasTsamichas/energy-models-docker"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.base.name="ubuntu:${UBUNTU_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MAMBA_ROOT_PREFIX=/opt/conda \
    JUPYTER_PATH=/opt/jupyter \
    HOME=/home/workbench \
    PATH=/opt/conda/envs/workbench/bin:/usr/local/bin:/usr/bin:/bin

# System libraries. Conda ships most scientific libraries, but a JupyterLab
# image still needs the X/GL runtime, fonts and the usual build tools.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        bzip2 \
        ca-certificates \
        curl \
        fonts-liberation \
        git \
        libgl1 \
        libglx-mesa0 \
        libgomp1 \
        libsecret-1-0 \
        libsqlite3-0 \
        libx11-6 \
        libxext6 \
        libxrender1 \
        passwd \
        rsync \
        tar \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Micromamba is a single static binary and is used only to build the conda
# environments. At runtime the environment binaries are called directly, so
# the container does not depend on a writable package cache.
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) MM_ARCH=linux-64 ;; \
        arm64) MM_ARCH=linux-aarch64 ;; \
        *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/micromamba \
        "https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VERSION}/micromamba-${MM_ARCH}"; \
    install -m 0755 /tmp/micromamba /usr/local/bin/micromamba; \
    rm /tmp/micromamba; \
    micromamba --version

# Clone the three model repositories at the exact commits in versions.env.
COPY scripts/fetch-models.sh /usr/local/bin/fetch-models.sh
RUN set -eux; \
    chmod +x /usr/local/bin/fetch-models.sh; \
    PYPSA_EUR_REPO="${PYPSA_EUR_REPO}" \
    PYPSA_EUR_REF="${PYPSA_EUR_REF}" \
    EU_FLEX_REPO="${EU_FLEX_REPO}" \
    EU_FLEX_REF="${EU_FLEX_REF}" \
    OSEMOSYS_REPO="${OSEMOSYS_REPO}" \
    OSEMOSYS_REF="${OSEMOSYS_REF}" \
    /usr/local/bin/fetch-models.sh /opt/models

# Create the four conda environments. This is the large, slow layer and is
# intentionally placed before the small configuration layers.
COPY scripts/install-envs.sh /usr/local/bin/install-envs.sh
RUN chmod +x /usr/local/bin/install-envs.sh \
    && BUILD_PYPSA_EUR="${BUILD_PYPSA_EUR}" \
       BUILD_EU_FLEX="${BUILD_EU_FLEX}" \
       BUILD_OSEMOSYS="${BUILD_OSEMOSYS}" \
       TARGETARCH="${TARGETARCH}" \
       /usr/local/bin/install-envs.sh

# Register one Jupyter kernel per environment. The kernelspecs are plain JSON
# under /opt/jupyter/kernels, which JupyterLab finds via JUPYTER_PATH.
COPY scripts/register-kernels.sh /usr/local/bin/register-kernels.sh
RUN chmod +x /usr/local/bin/register-kernels.sh \
    && /usr/local/bin/register-kernels.sh

# Runtime scripts and example notebooks.
COPY scripts/ /usr/local/bin/
COPY examples/ /opt/examples/
COPY tests/ /opt/tests/
COPY config/jupyter/jupyter_lab_config.py /etc/jupyter/jupyter_lab_config.py

RUN set -eux; \
    # Ubuntu 24.04 ships an `ubuntu` user at UID 1000. Replace it so the
    # workbench user can own the conventional UID used by bind mounts.
    if id ubuntu >/dev/null 2>&1; then /usr/sbin/userdel --remove ubuntu; fi; \
    if getent group ubuntu >/dev/null; then /usr/sbin/groupdel ubuntu; fi; \
    /usr/sbin/useradd --uid 1000 --gid 0 --create-home --home-dir /home/workbench --shell /bin/bash workbench; \
    chmod +x /usr/local/bin/*.sh; \
    mkdir -p /work /data /results /home/workbench; \
    chown -R workbench:root /work /data /results /home/workbench; \
    chmod -R a+rX /opt/models /opt/examples /opt/tests /opt/jupyter

USER workbench
WORKDIR /work

EXPOSE 8888

# No default CMD: the entrypoint starts JupyterLab when no command is given,
# and executes the given command otherwise (used by `make test` and `make shell`).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
