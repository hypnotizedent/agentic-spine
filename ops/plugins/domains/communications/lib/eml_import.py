# Thin shim — canonical source is now in workbench.
# Re-export from the canonical location so existing importers keep working.
import importlib.util as _ilu
import os as _os

_target = _os.environ.get(
    "COMMUNICATIONS_TARGET_REPO",
    "/Users/ronnyworks/code/workbench/agents/communications/tools/spine-plugin-communications",
)
_spec = _ilu.spec_from_file_location(
    "eml_import",
    _os.path.join(_target, "lib", "eml_import.py"),
)
_mod = _ilu.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

# Re-export everything from the canonical module
from types import ModuleType as _MT
for _name in dir(_mod):
    if not _name.startswith("_"):
        globals()[_name] = getattr(_mod, _name)
