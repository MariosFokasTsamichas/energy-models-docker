# Models and licences

Every model is cloned from its canonical upstream repository at the commit
below. `versions.env` is the machine-readable source of truth; this page is the
human-readable record.

## Pinned commits

| Model | Repository | Commit | Commit date |
|---|---|---|---|
| PyPSA-Eur | [PyPSA/pypsa-eur](https://github.com/PyPSA/pypsa-eur) | `4b2822102a3b4b2c90be1b48bf221a2bb59e0d06` | 2026-11-20 |
| EU-Flex | [EU-ACER/eu-flex-model](https://github.com/EU-ACER/eu-flex-model) | `65cb449bc1ddc3731f542337e1a0e5dbddc35536` | 2026-11-05 |
| Nour OSeMOSYS Studio | [Islam-Dj/Nour-OSeMOSYS-Studio-Standard](https://github.com/Islam-Dj/Nour-OSeMOSYS-Studio-Standard) | `1602afd56e47d444906f56d7ff5af8951ae87808` | 2026-11-11 |

Pins were resolved on 2026-11-23. The commit, not the date, is authoritative.
`/opt/models/SOURCES.json` inside a built image records the SHAs actually
fetched, so an image can be audited without trusting this file.

## PyPSA-Eur

- **Role.** Sector-coupled capacity-expansion model of the European energy
  system, built on PyPSA and atlite, orchestrated with Snakemake.
- **Entry point.** `Snakefile` at the repository root. The workbench script
  `run-pypsa-eur.sh` runs `snakemake -c <cores> --configfile <config>`.
- **Environment.** Python 3.13 environment exported as an explicit
  `linux-64` pin (563 packages, exact URLs) for amd64. arm64 solves
  `envs/environment.yaml`, which is the same specification without the pin.
- **Data.** Input data is downloaded by the workflow from many sources
  (Copernicus, ERA5 via atlite, ENTSO-E, ...). Each source has its own licence
  and terms; see `doc/data_sources.md` in the upstream repository. The workbench
  does not redistribute that data.
- **Licence.** MIT for the code. Documentation is CC-BY-4.0. Input data varies
  by source.

## EU-Flex

- **Role.** EU-wide flexibility-needs assessment: a stylised multi-zone system
  solved day-ahead and intraday, producing short-term flexibility indicators.
  The repository accompanies the ACER paper *Preparing for the European
  flexibility needs assessment* (2026).
- **Entry point.** Root `Snakefile` includes
  `src/euflex/eu_flex_model/Snakefile`. The package installs as
  `eu-flex-model` and imports as `euflex`.
- **Environment.** `envs/linux-64.lock.yaml` for amd64 (conda-lock, exact
  versions) and `envs/environment.yaml` for arm64. Key pins in the YAML:
  `pypsa=0.33.2`, `linopy=0.7.0`, `snakemake-minimal>=9,<=9.16.3`, `numpy<2.5`,
  with `highspy` from pip.
  The installed package is editable, so edits under `/work/models/eu-flex/src`
  take effect without reinstalling.
- **Data.** `data/teaser/` ships with the repository (about 3 MB) and is enough
  for the teaser run.
- **Licence.** MIT. Documentation and teaser data: CC-BY-4.0, configuration and
  other input data: CC0-1.0 (as stated in the repository's `REUSE.toml`).

## Nour OSeMOSYS Studio

- **Role.** Desktop-style web application to build, check, solve and analyse
  OSeMOSYS models, with case management, Monte Carlo runs and result plots.
- **Entry point.** `run_studio.py` starts the server on `127.0.0.1:8775`.
  Accepts `--port`, `--cases`, `--runs`, `--settings`, `--solvers`,
  `--no-browser`.
- **Environment.** Python 3.12 with `pandas`, `numpy`, `scipy`, `openpyxl`,
  `werkzeug`, `pulp` (CBC), `glpk`/`swiglpk`, `highspy`.
- **Data.** The standard OSeMOSYS model file (`web/data/builtin_model.txt`) and
  a gas-and-solar example (`web/data/examples/gas_solar.txt`) ship with the
  repository.
- **Licence.** Apache-2.0. Bundled OSeMOSYS model files are Apache-2.0;
  JavaScript libraries and fonts keep their own licences (see the upstream
  `NOTICE`). Solvers installed separately: GLPK GPL-3.0, CBC EPL-2.0, HiGHS MIT.

## Not bundled

**marco-BIS** was considered and deliberately excluded. It is a
macroeconometric agent-based framework for balance-sheet analysis, not an
energy-system model, and the workbench scope is energy models. Adding it later
is possible with the recipe in `CONTRIBUTING.md`.

## Attribution requirements in practice

If you publish results:

- cite each model you used, using its own `CITATION.cff` (all three repositories
  ship one);
- cite the data sources listed in each model's documentation, not this
  workbench;
- state the commits from `versions.env`, so the result is tied to a known model
  version.
