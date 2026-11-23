#!/usr/bin/env bash
# Print the state of the workbench: Docker, container, URL, token, environments.
# Run on the host from anywhere inside the repository.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Host =="
docker --version
docker compose version
echo

echo "== Container =="
if docker compose ps --status running --quiet workbench >/dev/null 2>&1; then
    docker compose ps
    echo
    echo "JupyterLab token: $(docker compose exec -T workbench cat /work/.jupyter_token 2>/dev/null || echo 'not created yet')"
    echo "URL: http://localhost:${JUPYTER_PORT:-8888}/lab"
    echo "Studio: http://localhost:${JUPYTER_PORT:-8888}/proxy/8775/"
    echo
    echo "== Kernels =="
    docker compose exec -T workbench /opt/conda/envs/workbench/bin/jupyter kernelspec list || true
    echo
    echo "== Workspace =="
    docker compose exec -T workbench bash -lc 'du -sh /work /data /results 2>/dev/null; ls /work/models' || true
else
    echo "workbench container is not running"
fi

echo
echo "== Disk =="
docker system df
