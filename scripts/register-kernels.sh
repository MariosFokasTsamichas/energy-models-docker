#!/usr/bin/env bash
# Write one kernelspec per conda environment into /opt/jupyter/kernels.
# JupyterLab discovers them because JUPYTER_PATH=/opt/jupyter.
set -euo pipefail

KERNEL_DIR="${JUPYTER_PATH:-/opt/jupyter}/kernels"
mkdir -p "$KERNEL_DIR"

add_kernel() {
    local env="$1"
    local display="$2"
    local python="/opt/conda/envs/${env}/bin/python"

    if [ ! -x "$python" ]; then
        echo "  skipping ${env}: ${python} not found"
        return
    fi

    mkdir -p "${KERNEL_DIR}/${env}"
    cat > "${KERNEL_DIR}/${env}/kernel.json" <<EOF
{
  "argv": ["${python}", "-m", "ipykernel_launcher", "-f", "{connection_file}"],
  "display_name": "${display}",
  "language": "python",
  "metadata": {
    "debugger": true
  }
}
EOF
    echo "  registered ${env} -> ${display}"
}

echo "Registering Jupyter kernels"
add_kernel pypsa-eur "PyPSA-Eur (Python)"
add_kernel eu-flex "EU-Flex (Python)"
add_kernel osemosys "OSeMOSYS Studio (Python)"
add_kernel workbench "Workbench (Python)"

# conda-forge's ipykernel ships a default `python3` kernelspec inside each
# environment. Remove those so the kernel list is exactly the four named
# entries above; a stray "Python 3" would silently point at one environment.
rm -rf /opt/conda/envs/*/share/jupyter/kernels/python3
