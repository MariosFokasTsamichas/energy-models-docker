"""JupyterLab configuration for the workbench image.

The entrypoint passes the port and token on the command line, so those are
intentionally not fixed here. This file only sets container-safe defaults.
"""

c = get_config()  # noqa: F821

c.ServerApp.ip = "0.0.0.0"
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.root_dir = "/work"
c.ServerApp.allow_remote_access = True
c.ServerApp.allow_origin = "*"
c.ServerApp.terminado_settings = {"shell_command": ["/bin/bash"]}
c.LabApp.collaborative = False

# New notebooks open with the workbench kernel rather than Jupyter's built-in
# fallback (which also points at the workbench environment, but is named
# "Python 3" and confuses the four-model kernel list).
c.MultiKernelManager.default_kernel_name = "workbench"
