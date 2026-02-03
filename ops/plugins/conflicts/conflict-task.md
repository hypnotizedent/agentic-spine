# TASK: Conflicts Lookup (plugin template)
MODE: PLUGIN
STAGE: ANALYZE
OUTCOME: "Scan the repository tree for unresolved merge markers."

## REQUEST
List all files and line numbers containing Git conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`). Use `rg` or similar to search the current workspace. Return one line per match in the format `<file>:<line>:<marker>`.
