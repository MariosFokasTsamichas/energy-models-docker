# Smoke tests

The tests in `test_workbench.py` run **inside the image** and check the
parts that are easy to get silently wrong:

- all four kernelspecs exist and point at the right interpreters;
- each model environment can import its core packages;
- the OSeMOSYS reference model builds and solves to `OPTIMAL`;
- PyPSA-Eur and EU-Flex can plan their test/teaser workflows with
  `snakemake -n` (no downloads, no solves);
- the OSeMOSYS Studio web server answers on a loopback port.

Run them with:

```bash
make test
```

or directly:

```bash
docker run --rm -e START_OSEMOSYS_STUDIO=0 \
  energy-models-workbench:dev \
  /opt/conda/envs/workbench/bin/python -m pytest -q /opt/tests
```

The workflow-planning tests need the writable workspace at `/work/models`;
the entrypoint copies the model repositories there on first start. If that
directory is missing, those tests skip rather than fail.
