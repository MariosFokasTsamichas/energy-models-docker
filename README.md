# Energy Models Workbench

A single JupyterLab container with three open energy-system models, each in its
own pinned environment, plus a persistent workspace for data and results.

| Model | What it does | Interface |
|---|---|---|
| **PyPSA-Eur** | Sector-coupled capacity-expansion model of the European energy system | Snakemake workflow + PyPSA networks, from notebooks/terminals |
| **EU-Flex** | EU-wide flexibility-needs assessment (day-ahead vs intraday) | Snakemake workflow + analysis notebook |
| **Nour OSeMOSYS Studio** | Build, check, solve and analyse OSeMOSYS models | Local web app, proxied through JupyterLab |

Each model is cloned at an **exact commit** (see `versions.env`) and installed in
its own conda environment, so the models cannot break each other's dependencies.
Nothing in the upstream code is patched.

## Quick start

Requirements: Docker with Compose v2 (Docker Desktop, Colima, or Docker Engine on
Linux) and enough disk for a multi-gigabyte image plus downloaded data — plan
for tens of gigabytes, not a few. You also need an internet connection for the
first build.

```bash
git clone https://github.com/MariosFokasTsamichas/energy-models-docker.git
cd energy-models-docker

docker compose up -d --build
docker compose logs -f workbench
```

The logs print the JupyterLab URL with its token. The token is generated on
first start and stored in the work volume:

```bash
docker compose exec workbench cat /work/.jupyter_token
```

Then open:

- **JupyterLab** — <http://localhost:8888/lab?token=…>
- **OSeMOSYS Studio** — <http://localhost:8888/proxy/8775/> (only while the
  container is running)

Stop with `docker compose down`. That keeps the volumes; `make clean-all`
deletes them. `make doctor` prints the container state, the token, the kernels
and the disk usage.

### Without Compose

```bash
make build                 # builds ghcr.io/…/energy-models-workbench:dev
make up                    # docker compose up -d --build
make test                  # smoke tests inside the image
make shell                 # bash inside the image
```

## What is inside

```
/work            writable workspace, persisted in the energy-models-work volume
  models/        copies of the three pinned checkouts
  examples/      the notebooks in examples/
  osemosys/      Studio cases, runs and solver settings
  .jupyter_token generated on first start
/data            persistent data volume (large downloads)
/results         persistent results volume
```

`/opt/models` holds the read-only originals baked into the image.
`init-workspace.sh` copies them into `/work/models` the first time the container
starts. To refresh an existing workspace after rebuilding the image:

```bash
UPDATE_MODELS=1 UPDATE_EXAMPLES=1 docker compose up -d
```

## Kernels

JupyterLab shows one kernel per environment:

| Kernel | Environment | Use it for |
|---|---|---|
| PyPSA-Eur (Python) | `/opt/conda/envs/pypsa-eur` | PyPSA, atlite, the PyPSA-Eur workflow |
| EU-Flex (Python) | `/opt/conda/envs/eu-flex` | EU-Flex rules and its analysis notebook |
| OSeMOSYS Studio (Python) | `/opt/conda/envs/osemosys` | OSeMOSYS solving, `solve_check.py`, Studio internals |
| Workbench (Python) | `/opt/conda/envs/workbench` | JupyterLab tooling; no model installed |

JupyterLab also lists its built-in **Python 3** kernel, which points at the
workbench environment. New notebooks default to the **Workbench** kernel, which
is the same interpreter under a clearer name.

Start with `examples/00-introduction.ipynb`.

## Running the models

### PyPSA-Eur

```bash
run-pypsa-eur.sh                 # test config, one core
CORES=all run-pypsa-eur.sh       # all cores
DRY_RUN=1 run-pypsa-eur.sh       # plan only
```

The default is `config/test/config.electricity.yaml` (Belgium, one week). It
downloads weather and demand data on the first run. The full model needs
substantially more data and time; see `docs/data-and-volumes.md`.

### EU-Flex

```bash
run-eu-flex.sh
```

The teaser run uses the dataset shipped with the repository (target year 2030,
climate year 2013) and solves a full year of hourly snapshots. When it finishes,
open `models/eu-flex/notebooks/teaser_case_analysis.ipynb` with the EU-Flex
kernel to reproduce the paper's figures.

### OSeMOSYS Studio

The container starts the Studio automatically on port 8775 and JupyterLab
proxies it at `/proxy/8775/`. Cases and runs are stored under `/work/osemosys`.
To run it in the foreground for debugging:

```bash
START_OSEMOSYS_STUDIO=0 docker compose up -d
docker compose exec workbench start-osemosys-studio.sh
```

`examples/03-osemosys-studio.ipynb` also solves the reference model
(`web/data/builtin_model.txt` + `web/data/examples/gas_solar.txt`) directly.

## Reproducibility

`versions.env` pins every upstream commit. The Dockerfile passes those values
as build arguments, so the image contains exactly those commits and records them
in `/opt/models/SOURCES.json`.

Environment files differ by architecture because the upstream projects publish
locks only for `linux-64`:

| Model | `linux/amd64` | `linux/arm64` |
|---|---|---|
| PyPSA-Eur | `envs/default_linux-64.pin.txt` (exact URLs) | `envs/environment.yaml` (solved at build) |
| EU-Flex | `envs/linux-64.lock.yaml` (exact pins) | `envs/environment.yaml` (solved at build) |
| OSeMOSYS Studio | explicit package list in `scripts/install-envs.sh` | same |

`docs/models-and-licenses.md` records the exact commits and licences.

To update the pins:

```bash
./scripts/update-pins.sh
make build && make test
```

## Testing

```bash
make test        # full suite: kernels, imports, OSeMOSYS solve, workflow planning
make test-lite   # kernels and imports only
```

The tests run inside the image and never download data. They skip gracefully
when `/work/models` has not been initialised.

## Continuous integration

`.github/workflows/docker.yml` builds both architectures on native GitHub
runners, merges the manifests, and pushes to GHCR:

- on every push to `main`: `:latest` and `:sha-<short>`
- on tags `v*`: `:vX.Y.Z`, `:X.Y`, `:latest`

Pull requests build `linux/amd64` and do not push. Set
`IMAGE_NAME` in `versions.env` to your own GHCR path before publishing.

## Platform notes

- **Apple Silicon**: the image builds natively for `linux/arm64`. PyPSA-Eur and
  EU-Flex solve their environments at build time, which is slower than
  installing a lock but works. Give Docker at least 8 GB of RAM
  (`colima start --memory 8`).
- **Linux**: the container runs as UID 1000. Named volumes inherit the right
  ownership; bind mounts need `chown -R 1000:0 <dir>`.
- **Windows**: use WSL2 with Docker Desktop and keep the project inside the WSL
  filesystem for sane file permissions.

## Licences

The workbench is Apache-2.0. The bundled models keep their upstream licences:
PyPSA-Eur is MIT (input data varies), EU-Flex is MIT, Nour OSeMOSYS Studio is
Apache-2.0. See `NOTICE` and `docs/models-and-licenses.md`.

## Layout

```
.
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── versions.env              pinned commits and image name
├── model-sources.json        machine-readable provenance
├── scripts/                  fetch, install, init, run, test
├── config/jupyter/           JupyterLab configuration
├── examples/                 example notebooks
├── tests/                    in-image smoke tests
├── docs/                     architecture, licences, data, troubleshooting
└── .github/workflows/        multi-arch GHCR build
```
