#!/usr/bin/env python3
"""Offline Forever Comms release builder. No GitHub, third-party packages or secrets required.

From the extracted suite root: python tools/package.py --output dist
The individual source archives bundle the required Voice dependency.
"""
import argparse
from pathlib import Path
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ADDONS = ('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms')


def manifest(addon):
    folder = ROOT / addon
    toc = folder / (addon + '.toc')
    if not toc.is_file():
        raise ValueError(f'missing {toc}')
    text = toc.read_text(encoding='utf-8-sig')
    version_match = re.search(r'^## Version:\s*(\S+)', text, re.M)
    if not version_match:
        raise ValueError(f'{toc} has no version')
    version = version_match.group(1)
    runtime = {toc}
    has_icon = False
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith('## IconTexture:'):
            expected = rf'Interface\AddOns\{addon}\Media\Icon'
            if line.split(':', 1)[1].strip().lower() != expected.lower():
                raise ValueError(f'{addon} has an incorrect IconTexture')
            has_icon = True
        if not line or line.startswith('#'):
            continue
        if not re.fullmatch(r'[a-zA-Z0-9_-]+\.(?:lua|xml)', line):
            raise ValueError(f'unsafe or unsupported TOC entry: {line!r}')
        runtime.add(folder / line)
    if has_icon:
        runtime.add(folder / 'Media' / 'Icon.tga')
    binding = folder / 'Bindings.xml'
    if binding.exists():
        runtime.add(binding)
    if len(runtime) <= 1 or any(not p.is_file() for p in runtime):
        raise ValueError(f'{addon} runtime files missing')
    if addon != 'ForeverCommsVoice' and '## Dependencies: ForeverCommsVoice' not in text:
        raise ValueError(f'{addon} must depend on ForeverCommsVoice')
    project_icon = folder / 'Media' / 'ProjectIcon.png'
    if not project_icon.exists():
        raise ValueError(f'{addon} project icon missing')
    return version, runtime


def source_files(folder):
    return (p for p in folder.rglob('*') if p.is_file() and not p.is_symlink() and p.name != '.DS_Store')


def build(path, files):
    path.parent.mkdir(parents=True, exist_ok=True)
    files = sorted(set(files), key=lambda p: p.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as out:
        for p in files:
            arc = p.relative_to(ROOT).as_posix()
            if '..' in Path(arc).parts or arc.startswith('/'):
                raise ValueError(f'unsafe archive member: {arc}')
            out.write(p, arc)
    print(f'{path.name}: {len(files)} files')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('dist'))
    parser.add_argument('--runtime', action='store_true', help='Exclude installers/tests/docs; suitable for addon-manager archives')
    args = parser.parse_args()
    output = args.output if args.output.is_absolute() else ROOT / args.output
    versions, manifests = {}, {}
    for addon in ADDONS:
        versions[addon], manifests[addon] = manifest(addon)
    # Bump the suite with GuildComms' release number; no stale hardcoded versions.
    suite_version = versions['ForeverGuildComms']
    for addon in ADDONS:
        selected = (addon, 'ForeverCommsVoice') if addon != 'ForeverCommsVoice' else (addon,)
        files = set()
        for name in selected:
            files.update(manifests[name] if args.runtime else source_files(ROOT / name))
        if not args.runtime:
            files.update(source_files(ROOT / 'install'))
        build(output / f'{addon}-{versions[addon]}-{ "runtime" if args.runtime else "source"}.zip', files)
    suite_files = set()
    for addon in ADDONS:
        suite_files.update(manifests[addon] if args.runtime else source_files(ROOT / addon))
    if not args.runtime:
        for path in ('install', 'tools', '.github'):
            suite_files.update(source_files(ROOT / path))
        for name in ('README.md', 'PACKAGING.md', 'package.cmd', 'package.ps1'):
            f = ROOT / name
            if f.exists(): suite_files.add(f)
    build(output / f'ForeverComms-Bundle-{suite_version}-{ "runtime" if args.runtime else "source"}.zip', suite_files)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as exc:
        print(f'Packaging failed: {exc}', file=sys.stderr)
        sys.exit(1)
