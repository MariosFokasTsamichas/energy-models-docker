#!/usr/bin/env bash
# Container entrypoint.
#
#   no arguments  -> start JupyterLab (the normal workbench mode)
#   arguments     -> execute them (used by `make test` and `make shell`)
set -euo pipefail

JUPYTER_PORT="${JUPYTER_PORT:-8888}"
OSEMOSYS_PORT="${OSEMOSYS_PORT:-8775}"
START_OSEMOSYS_STUDIO="${START_OSEMOSYS_STUDIO:-1}"

mkdir -p /work /data /results

# Populate the writable workspace from the read-only image copies on first
# start. Set UPDATE_MODELS=1 / UPDATE_EXAMPLES=1 to refresh them.
/usr/local/bin/init-workspace.sh

# OSeMOSYS Studio listens on 127.0.0.1:8775 inside the container.
# JupyterLab exposes it at /proxy/8775/.
if [ "$START_OSEMOSYS_STUDIO" = "1" ]; then
    nohup /usr/local/bin/start-osemosys-studio.sh \
        > /work/logs/osemosys-studio.log 2>&1 &
fi

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

# A token is generated once and stored in the work volume. Set JUPYTER_TOKEN
# to override it; set JUPYTER_TOKEN="" to disable authentication (not advised
# if the port is reachable by anyone else).
if [ "${JUPYTER_TOKEN+x}" = "x" ]; then
    TOKEN="$JUPYTER_TOKEN"
elif [ -s /work/.jupyter_token ]; then
    TOKEN="$(cat /work/.jupyter_token)"
else
    TOKEN="$(/opt/conda/envs/workbench/bin/python -c 'import secrets; print(secrets.token_hex(24))')"
    printf '%s\n' "$TOKEN" > /work/.jupyter_token
fi

cat <<EOF

Energy Models Workbench
  JupyterLab:      http://localhost:${JUPYTER_PORT}/lab?token=${TOKEN}
  OSeMOSYS Studio: http://localhost:${JUPYTER_PORT}/proxy/${OSEMOSYS_PORT}/

  Token file:      /work/.jupyter_token  (inside the container)
  Stop:            Ctrl-C, or \`docker compose down\`

EOF

ARGS=(lab --ip=0.0.0.0 --port="$JUPYTER_PORT" --no-browser --ServerApp.root_dir=/work)
if [ -n "$TOKEN" ]; then
    ARGS+=(--IdentityProvider.token="$TOKEN")
else
    ARGS+=(--IdentityProvider.token=)
fi

exec /opt/conda/envs/workbench/bin/jupyter "${ARGS[@]}"
