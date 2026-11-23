# Example notebooks

These notebooks ship in the image at `/opt/examples` and are copied to
`/work/examples` on first start.

| Notebook | Kernel | What it does |
|---|---|---|
| `00-introduction.ipynb` | Workbench | Shows the mounts, the model checkouts and the registered kernels |
| `01-pypsa-eur.ipynb` | PyPSA-Eur | Checks the pinned checkout and plans the test workflow |
| `02-eu-flex.ipynb` | EU-Flex | Checks the teaser data and plans the teaser workflow |
| `03-osemosys-studio.ipynb` | OSeMOSYS Studio | Checks the proxied Studio and solves the reference model |

The notebooks are deliberately cheap: they plan workflows (`snakemake -n`) and
solve only the small OSeMOSYS reference model. None of them downloads
PyPSA-Eur data. That keeps them usable as a first-run check.

Open them from JupyterLab's file browser under `examples/`. If you edit one and
rebuild the image, `UPDATE_EXAMPLES=1` refreshes the copies in `/work`.
