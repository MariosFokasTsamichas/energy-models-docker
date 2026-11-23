# Data, volumes and disk

## The three volumes

| Volume | Mount | Contents | Safe to delete? |
|---|---|---|---|
| `energy-models-work` | `/work` | Model checkouts, notebooks, token, Studio cases and runs | Yes, but you lose edits and Studio cases |
| `energy-models-data` | `/data` | Large downloads (weather, demand, grid data) | Yes, at the cost of re-downloading |
| `energy-models-results` | `/results` | Solve outputs you want to keep | **No** — treat as your only copy |

The model repositories are copied from `/opt/models` into `/work/models` on the
first start. `/opt/models` is read-only, so a container rebuild does not discard
your edits in `/work`.

`/work/data` and `/work/results` are symlinks to the data and results volumes,
so model scripts that write to a relative `data/` or `results/` can be pointed at
persistent storage without changing the model.

## Where each model writes

| Model | Default location | Notes |
|---|---|---|
| PyPSA-Eur | `models/pypsa-eur/results/<run name>/` | Data downloads go to `models/pypsa-eur/data/` and the atlite cache, both in `/work` |
| EU-Flex | `models/eu-flex/runs/<run name>/` | The teaser dataset ships in the repository |
| OSeMOSYS Studio | `/work/osemosys/cases`, `/work/osemosys/runs` | Set at start by `start-osemosys-studio.sh` |

To keep PyPSA-Eur's large downloads off the work volume, edit its config to
point `data` at a path under `/data`, for example:

```yaml
# /work/models/pypsa-eur/config/my-config.yaml
data:
  base_path: /data/pypsa-eur
```

or symlink the download directory:

```bash
rm -rf /work/models/pypsa-eur/data
ln -s /data/pypsa-eur /work/models/pypsa-eur/data
```

## First-run downloads

- **PyPSA-Eur** downloads weather (ERA5/Copernicus), demand, renewable
  potentials and grid data when the workflow runs. The test configuration
  (`config/test/config.electricity.yaml`) needs far less than the full default
  configuration. Both need internet access; neither is cached in the image.
- **EU-Flex** needs nothing beyond the repository for the teaser run.
- **OSeMOSYS Studio** needs nothing; the reference model and example data are in
  the repository.

Nothing is downloaded at container start. Starting the workbench offline is fine
until you run a workflow that needs data.

## Inspecting and backing up

```bash
# Where the volumes live on the host (Docker Desktop / Colima VM)
docker volume inspect energy-models-work

# Archive a volume to the host filesystem
docker run --rm \
  -v energy-models-work:/src:ro \
  -v "$PWD":/backup \
  alpine tar czf /backup/work-$(date +%F).tar.gz -C /src .

# Restore
docker run --rm \
  -v energy-models-work:/dst \
  -v "$PWD":/backup \
  alpine tar xzf /backup/work-2026-11-23.tar.gz -C /dst
```

## Disk planning

The image itself is large: four conda environments containing the full PyPSA
and geospatial stack. Plan for **tens of gigabytes** of Docker disk, plus room
for downloaded data and results. On Colima the VM disk is set at creation:

```bash
colima start --cpu 4 --memory 8 --disk 60
```

Docker Desktop uses a sparse disk image whose size is configurable in
*Settings → Resources*.

Reclaim space that is safe to reclaim:

```bash
docker builder prune           # build cache
docker image prune -a          # unused images
```

Do not prune volumes unless you mean it.

## Bind mounts instead of volumes

If you prefer host directories:

```yaml
volumes:
  - ./work:/work
  - ./data:/data
  - ./results:/results
```

The container runs as UID 1000, so on Linux the directories must be writable by
that UID:

```bash
mkdir -p work data results
sudo chown -R 1000:0 work data results
```

On macOS, Docker Desktop and Colima translate ownership, so this is rarely
needed.
