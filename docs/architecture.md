# Architecture

## Layers

```
┌────────────────────────────────────────────────────────────────────┐
│ JupyterLab  (conda env: workbench)                                 │
│   :8888  → /lab                                                   │
│          → /proxy/8775/  ──────────────┐                           │
│                                        │ jupyter-server-proxy      │
│ Kernels                                ▼                           │
│   pypsa-eur  → /opt/conda/envs/pypsa-eur   OSeMOSYS Studio        │
│   eu-flex    → /opt/conda/envs/eu-flex     127.0.0.1:8775         │
│   osemosys   → /opt/conda/envs/osemosys                           │
│   workbench  → /opt/conda/envs/workbench                          │
├────────────────────────────────────────────────────────────────────┤
│ /opt/models      read-only pinned checkouts, baked into the image  │
│ /opt/examples    example notebooks                                 │
│ /work            writable workspace        (named volume)          │
│ /data            large downloads           (named volume)          │
│ /results         solve outputs             (named volume)          │
└────────────────────────────────────────────────────────────────────┘
```

One process (JupyterLab) plus one child (the Studio server). There is no
supervisor, no init system, and no second network service to configure.

## Build pipeline

The Dockerfile has four substantive layers, ordered from slowest-changing to
fastest-changing so rebuilds during development are cheap:

1. **Base** — Ubuntu 24.04, system libraries, and a pinned micromamba binary
   (`MICROMAMBA_VERSION`). `TARGETARCH` selects the matching static build.
2. **Model sources** — `scripts/fetch-models.sh` clones each repository at the
   exact commit from `versions.env` into `/opt/models`, shallowly, and writes
   `/opt/models/SOURCES.json` with the resolved SHAs.
3. **Environments** — `scripts/install-envs.sh` creates four conda environments.
   This is the large layer. Which file it uses depends on the architecture
   because upstream lock coverage differs:

   | Model | `linux/amd64` | `linux/arm64` |
   |---|---|---|
   | PyPSA-Eur | `envs/default_linux-64.pin.txt` | `envs/environment.yaml` |
   | EU-Flex | `envs/linux-64.lock.yaml` | `envs/environment.yaml` |
   | OSeMOSYS Studio | explicit list in the script | explicit list in the script |
   | Workbench | explicit list in the script | explicit list in the script |

   The pin file is an *explicit spec*: every package is a URL with a hash. The
   EU-Flex lock is a conda-lock file with exact versions. The `environment.yaml`
   fallbacks are solved at build time, so they are reproducible only modulo the
   package index state; this is documented rather than hidden.

4. **Configuration** — kernelspecs under `/opt/jupyter/kernels`, the JupyterLab
   config, runtime scripts in `/usr/local/bin`, example notebooks and tests, and
   the unprivileged `workbench` user (UID 1000, GID 0).

## Kernel registration

There is no `conda activate` at runtime and no `nb_conda_kernels`. Each
kernelspec is a small JSON file with an absolute interpreter path:

```json
{
  "argv": ["/opt/conda/envs/pypsa-eur/bin/python", "-m", "ipykernel_launcher", "-f", "{connection_file}"],
  "display_name": "PyPSA-Eur (Python)",
  "language": "python"
}
```

`JUPYTER_PATH=/opt/jupyter` makes JupyterLab discover `/opt/jupyter/kernels`.
Because the path is absolute, the workbench environment does not need to know
anything about the others.

## Runtime flow

`entrypoint.sh` runs as `workbench` and does, in order:

1. Create `/work`, `/data`, `/results` if missing.
2. `init-workspace.sh`: copy `/opt/models/*` to `/work/models/*` when absent
   (or `rsync` them when `UPDATE_MODELS=1`); same for examples; link
   `/work/data → /data` and `/work/results → /results`; copy `SOURCES.json`.
3. Start `start-osemosys-studio.sh` in the background unless
   `START_OSEMOSYS_STUDIO=0`, logging to `/work/logs/osemosys-studio.log`.
4. Resolve the Jupyter token: `JUPYTER_TOKEN` if set, else
   `/work/.jupyter_token`, else generate and store one.
5. `exec jupyter lab --ip=0.0.0.0 --port=8888 --root-dir=/work`.

If the container is given a command, the entrypoint runs that command instead
(steps 1–3 still run). `make test` and `make shell` rely on this.

## Why the model checkouts are copied

The image copies are read-only and immutable; the workspace copies are writable.
That gives two properties at once:

- rebuilding the image never destroys user edits or generated outputs;
- `UPDATE_MODELS=1` can refresh the workspace without losing `/data` or
  `/results`.

The trade-off is disk: the model checkouts exist twice. They are source trees
(tens of megabytes each), not datasets, so the cost is small relative to the
conda environments.

## What is deliberately absent

- **No JupyterHub, no authentication service.** This is a single-user workbench.
  Do not expose port 8888 to an untrusted network; use an SSH tunnel instead.
- **No conda at runtime.** Environments are baked. Installing more packages
  means building a derived image.
- **No patched model code.** Every checkout is unmodified upstream.
- **No second solution framework.** The models bring their own solvers; the
  workbench does not add one.
