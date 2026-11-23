# Troubleshooting

## The container starts but the browser cannot connect

Check the health and the published port:

```bash
docker compose ps
docker compose logs --tail=50 workbench
```

If the port is already in use, publish a different host port:

```bash
JUPYTER_PORT=8890 docker compose up -d
```

The container always listens on 8888 internally.

## I lost the Jupyter token

```bash
docker compose exec workbench cat /work/.jupyter_token
```

To pin your own token, set `JUPYTER_TOKEN` in `.env` and restart. Setting it to
an empty string disables authentication — only do that behind a firewall or an
SSH tunnel.

## OSeMOSYS Studio shows 502 / 404 at `/proxy/8775/`

1. Confirm the server is running:

   ```bash
   docker compose exec workbench curl -fsS http://127.0.0.1:8775/ | head
   ```

2. Read its log:

   ```bash
   docker compose exec workbench tail -100 /work/logs/osemosys-studio.log
   ```

3. If it is disabled, start it: `docker compose exec workbench
   start-osemosys-studio.sh`. If the Studio needs to be restarted after a crash,
   the entrypoint only starts it once; restart the container.

The proxy URL must keep the trailing slash: `/proxy/8775/`, not `/proxy/8775`.

## A kernel is missing from JupyterLab

```bash
docker compose exec workbench ls /opt/jupyter/kernels
docker compose exec workbench cat /opt/jupyter/kernels/pypsa-eur/kernel.json
```

`JUPYTER_PATH` must be `/opt/jupyter`; the entrypoint sets it in the image. If a
kernelspec points at a non-existent interpreter, that environment failed to
build — rebuild the image and read the build log for the environment name.

## The image build fails while creating a conda environment

The build log names the environment (`pypsa-eur`, `eu-flex`, `osemosys`,
`workbench`).

- **PyPSA-Eur on amd64** installs the upstream explicit pin. A failure here is
  usually network-related: the pin lists exact URLs on conda-forge, bioconda and
  the Gurobi channel. Retry, or check that the pinned URLs still exist.
- **PyPSA-Eur / EU-Flex on arm64** solve `environment.yaml` at build time. A
  solve failure means the upstream specification no longer resolves against the
  current package index. Re-run `./scripts/update-pins.sh` to move to a newer
  commit, or reduce `numpy`/`pypsa` constraints in a *local* copy and record the
  change — do not patch the checkout silently.
- **`critical libmamba Error parsing MatchSpec "": Empty package name`** means
  micromamba rejected the environment file. The EU-Flex lock is an old
  pre-1.0 conda-lock file; if a future micromamba drops support for it, switch
  the amd64 path in `scripts/install-envs.sh` to `envs/environment.yaml` and
  note the loss of exact pinning.

Out-of-memory kills during a solve look like "Killed" or a signal 9. Give the
VM more memory (`colima stop && colima start --memory 12`).

## macOS: the build is extremely slow or runs out of memory

PyPSA-Eur and EU-Flex are solved at build time on arm64, and conda's solver is
memory-hungry. Give the VM at least 8 GB and 4 CPUs. On Apple Silicon, do not
cross-build amd64 locally unless you need to; it runs under emulation and can
take hours.

## Changes to model files disappear after a rebuild

Rebuilding the image does not touch `/work`, and starting a container does not
overwrite existing files in `/work/models`. If you *want* the new image's
checkouts, start with:

```bash
UPDATE_MODELS=1 UPDATE_EXAMPLES=1 docker compose up -d
```

This runs `rsync --delete`, so any edits inside `/work/models/<name>` are
replaced. Keep your own work outside the model directories, or commit it
elsewhere, before refreshing.

## Permission denied writing to `/work` on Linux

The container runs as UID 1000, GID 0. Named volumes inherit the image's
ownership and work out of the box. Bind mounts do not:

```bash
sudo chown -R 1000:0 ./work ./data ./results
```

## `make test` fails on the workflow-planning tests

Those tests run `snakemake -n` inside the image and require the writable
workspace. If `/work/models` is empty, they skip. If they fail:

```bash
docker run --rm \
  --entrypoint /usr/local/bin/init-workspace.sh \
  ghcr.io/mariosfokastsamichas/energy-models-workbench:dev
```

then re-run. The most common cause is an environment that imports but whose
Snakemake plugins are missing (PyPSA-Eur uses storage and logger plugins pinned
in its own environment).

## EU-Flex: `ModuleNotFoundError: No module named 'euflex'`

The package is installed editable from `/opt/models/eu-flex`. If you deleted or
moved that directory inside the container, the editable link breaks. Rebuild the
image, or reinstall in a running container:

```bash
/opt/conda/envs/eu-flex/bin/python -m pip install --no-build-isolation -e /opt/models/eu-flex
```

## Gurobi warnings during the PyPSA-Eur build

The pinned PyPSA-Eur environment includes the Gurobi Python package. It is
installed without a licence and is not used by the workbench; warnings about a
missing licence are expected. HiGHS, GLPK and CBC are available and licensed for
use.

## "No space left on device" inside the container

Check the VM disk, not the host disk:

```bash
docker system df
colima ssh -- df -h /
```

Prune build cache and unused images, or recreate the Colima VM with a larger
`--disk`.

## Docker is not installed

The project was developed against Docker 29 with Compose v2. On macOS:

```bash
brew install colima docker docker-buildx docker-compose
colima start --cpu 4 --memory 8 --disk 60
```

Add `/opt/homebrew/lib/docker/cli-plugins` to `cliPluginsExtraDirs` in
`~/.docker/config.json` so `docker compose` and `docker buildx` are found.
