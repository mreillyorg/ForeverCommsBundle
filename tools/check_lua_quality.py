#!/usr/bin/env python3
"""Run strict Lua 5.1 syntax, harness, and luacheck gates.

Usage: python tools/check_lua_quality.py
       python tools/check_lua_quality.py --lua C:\\tools\\lua5.1.exe --luac C:\\tools\\luac5.1.exe --luacheck C:\\tools\\luacheck.exe

All three tools must be installed locally. The game client's embedded Lua
interpreter is not a standalone executable and cannot run these tests.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
ADDONS = ('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms')


def resolve(explicit, candidates, label):
    """Resolve a user-selected tool or probe common executable names."""
    names = [explicit] if explicit else candidates
    for name in names:
        candidate = shutil.which(name)
        if not candidate and Path(name).is_file():
            candidate = str(Path(name).resolve())
        if candidate:
            return candidate
    print(f'ERROR: {label} executable not found.', file=sys.stderr)
    if explicit:
        print(f'  Requested: {explicit}', file=sys.stderr)
    else:
        print('  Tried: ' + ', '.join(names), file=sys.stderr)
    print('  Install stock Lua 5.1, its matching luac compiler, and luacheck.', file=sys.stderr)
    print('  Add their executable directories to PATH, or pass explicit paths:', file=sys.stderr)
    print('  python tools/check_lua_quality.py --lua "C:\\tools\\lua51\\lua.exe" '
          '--luac "C:\\tools\\lua51\\luac.exe" '
          '--luacheck "C:\\tools\\luacheck\\luacheck.exe"', file=sys.stderr)
    return None


def banner_for(exe):
    try:
        result = subprocess.run([exe, '-v'], text=True, capture_output=True, timeout=20)
    except (OSError, subprocess.SubprocessError) as exc:
        print(f'ERROR: Cannot execute {exe}: {exc}', file=sys.stderr)
        return None
    return (result.stdout or '') + (result.stderr or '')


def run(command, cwd=ROOT):
    print('+', ' '.join(map(str, command)), flush=True)
    try:
        return subprocess.run(list(map(str, command)), cwd=cwd, check=False).returncode
    except OSError as exc:
        print(f'ERROR: Failed to execute {command[0]}: {exc}', file=sys.stderr)
        return 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default=os.environ.get('LUA51'), help='Path to stock Lua 5.1 interpreter')
    parser.add_argument('--luac', default=os.environ.get('LUAC51'), help='Path to Lua 5.1 compiler')
    parser.add_argument('--luacheck', default=os.environ.get('LUACHECK'), help='Path to luacheck')
    args = parser.parse_args()

    lua = resolve(args.lua, ['lua5.1', 'lua5.1.exe', 'lua51.exe', 'lua.exe'], 'Lua 5.1')
    luac = resolve(args.luac, ['luac5.1', 'luac5.1.exe', 'luac51.exe', 'luac.exe'], 'luac 5.1')
    luacheck = resolve(args.luacheck, ['luacheck', 'luacheck.exe'], 'luacheck')
    if not all((lua, luac, luacheck)):
        return 2

    lua_banner = banner_for(lua)
    compiler_banner = banner_for(luac)
    if lua_banner is None or compiler_banner is None:
        return 2
    if 'Lua 5.1' not in lua_banner or 'LuaJIT' in lua_banner:
        print(f'ERROR: Expected stock Lua 5.1, got: {lua_banner.strip()}', file=sys.stderr)
        return 2
    if 'Lua 5.1' not in compiler_banner:
        print(f'ERROR: Expected Lua 5.1 compiler, got: {compiler_banner.strip()}', file=sys.stderr)
        return 2

    print('Lua interpreter:', lua, flush=True)
    print('Lua compiler:', luac, flush=True)
    print('Luacheck:', luacheck, flush=True)
    sources = sorted(p for name in ADDONS for p in (ROOT / name).rglob('*.lua'))
    if not sources:
        print('ERROR: No Lua sources found', file=sys.stderr)
        return 2
    print(f'Parsing {len(sources)} Lua files with Lua 5.1', flush=True)
    for source in sources:
        if run([luac, '-p', source]):
            return 1
    if run([sys.executable, ROOT / 'tools' / 'run_tests.py', '--lua', lua]):
        return 1
    if run([luacheck, '.', '--codes' ]):
        return 1
    print('Lua 5.1 syntax, harnesses, and luacheck: PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
