# Lua 5.1 CI and lint audit (25 October 2026)

## Starting point
The supplied checked-out repository already had `lua5.1`, `luac5.1 -p`, Lua 5.1 harnesses and `luacheck --max-warnings 0` in `.github/workflows/package.yml`. The build was already configured to fail before BigWigs packaging if these checks failed.

## Changes
- Introduced `tools/check_lua_quality.py` as one local and CI entry point for all three checks.
- Replaced the three repeated workflow steps with a single explicit command.
- It rejects missing executables and non-stock Lua 5.1, parses all addon Lua files, runs the existing harnesses, and demands zero luacheck warnings.

## Verification
- Python syntax compilation: passed.
- `git diff --check`: passed.
- Running the new checker locally fails closed because this environment has no `lua5.1` executable (and cannot install it with the available package manager).
- **No claim is made that the 29 historical luacheck warnings have been resolved.** Running `python3 tools/check_lua_quality.py` on a machine with the three tools installed will give the precise current findings. The old count may have changed in this checkout.

## Install tooling (Ubuntu CI)
`sudo apt-get install -y lua5.1 luacheck`

## Execute
`python3 tools/check_lua_quality.py`

Once available, address warning locations individually rather than suppressing warning categories globally, then rerun the command and the release packaging workflow.
