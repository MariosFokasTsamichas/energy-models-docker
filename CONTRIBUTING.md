# Contributing

This repository is a packaging layer. Its job is to run upstream models
unmodified in a reproducible container. Contributions that keep that promise
are welcome; contributions that fork model logic are not.

## Ground rules

1. **No patches to upstream model code.** If a model needs a change, it goes
   upstream, and this repository updates the pin afterwards. The only
   permitted additions are files outside the model checkouts (configs,
   notebooks, scripts, docs).
2. **Pins are exact commits.** `versions.env` is the single source of truth.
   Never replace a commit with a branch name, a tag that could move, or a date.
3. **No invented numbers.** Do not state image sizes, runtimes, download sizes or
   model results in docs unless they were measured on a recorded run. Prefer
   "several gigabytes" to a made-up figure.
4. **Licences are tracked.** A new bundled component needs an entry in
   `NOTICE` and in `docs/models-and-licenses.md`, with its real licence.

## Changing a model pin

```bash
./scripts/update-pins.sh        # re-resolve from upstream default branches
make build
make test
```

A pin bump is one commit that also updates `model-sources.json` and the
"Pinned commits" table in `docs/models-and-licenses.md`. If the model's
environment files changed, re-check `scripts/install-envs.sh` — the file it
uses for each architecture is listed there.

## Adding a model

A fourth model must satisfy all of the following:

- open source, with a licence compatible with redistribution in a container;
- installable from conda/pip without a licence key or registration;
- usable from a Python kernel, or runnable as a local server that
  `jupyter-server-proxy` can expose;
- pinned to an exact commit.

Then: add the pin to `versions.env`, the clone to `scripts/fetch-models.sh`,
an environment block to `scripts/install-envs.sh`, a kernelspec to
`scripts/register-kernels.sh`, a smoke test, a notebook, and licence entries.

## Local checks before a pull request

```bash
ruff check .                # if you touched Python
shellcheck scripts/*.sh     # if you touched shell
docker compose config -q    # compose file validity
make build && make test     # the real check
```

`make test` runs inside the image and covers the kernels, the environments, the
OSeMOSYS solver, and workflow planning for PyPSA-Eur and EU-Flex.

## Commit messages

State what changed and why, and name the affected pin or script. Example:

```
Pin EU-Flex to 65cb449; use environment.yaml on arm64

The upstream linux-64 lock file is the pre-1.0 conda-lock format and does not
cover linux-aarch64, so arm64 solves from environment.yaml at build time.
```
