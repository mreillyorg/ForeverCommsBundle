#!/usr/bin/env python3
"""Build the Forever Comms release archive locally, mirroring BigWigsMods/packager.

BigWigs is the authoritative release path for GitHub; this is the local equivalent so a
release can be previewed and checked without pushing a tag.

    python tools/package.py                 # BigWigs-shaped bundle -> .release/
    python tools/package.py --source        # source archives with installers -> dist/
    python tools/package.py --version 1.2.3 # simulate a specific tag

Parity is achieved by reading the SAME root .pkgmeta that BigWigs reads, rather than
keeping a second list of what to include. The output is validated against the same
contract CI applies, tools/check_bigwigs_bundle.py:
  - every member sits under one of the three addon folders, nothing at top level
  - each addon's TOC is present
  - no tests/, install/ or .github/ content

Standard library only. No GitHub, third-party packages or secrets required.
"""
import argparse
from pathlib import Path
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ADDONS = ('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms')
PKGMETA = ROOT / '.pkgmeta'


def read_pkgmeta():
    """Minimal parse of the subset of .pkgmeta this project uses.

    Recognises `package-as`, `manual-changelog`, `move-folders` and `ignore`. Deliberately
    not a YAML implementation: if .pkgmeta grows a construct beyond these, this raises
    rather than silently producing an archive that differs from what BigWigs would build.
    """
    if not PKGMETA.is_file():
        raise ValueError(f'missing {PKGMETA}')
    package_as, moves, ignores, section = None, {}, [], None
    changelog = None
    for raw in PKGMETA.read_text(encoding='utf-8-sig').splitlines():
        line = raw.split('#', 1)[0].rstrip()
        if not line.strip():
            continue
        if not line.startswith((' ', '\t', '-')):
            key, _, value = line.partition(':')
            key, value = key.strip(), value.strip()
            section = key
            if key == 'package-as':
                package_as = value
            elif key == 'manual-changelog' and value:
                changelog = value          # scalar shorthand
            elif key not in ('move-folders', 'ignore', 'manual-changelog'):
                raise ValueError(f'.pkgmeta key not supported by this builder: {key!r}')
            continue
        item = line.strip()
        if section == 'ignore':
            if not item.startswith('- '):
                raise ValueError(f'unexpected ignore entry: {item!r}')
            ignores.append(item[2:].strip())
        elif section == 'move-folders':
            src, _, dst = item.partition(':')
            moves[src.strip()] = dst.strip()
        elif section == 'manual-changelog':
            key, _, value = item.partition(':')
            key, value = key.strip(), value.strip()
            if key == 'filename':
                changelog = value
            elif key != 'markup-type':
                raise ValueError(f'unsupported manual-changelog key: {key!r}')
    if not package_as:
        raise ValueError('.pkgmeta has no package-as')
    check_changelog(changelog, ignores)
    return package_as, moves, ignores


def check_changelog(changelog, ignores):
    """Enforce the pairing the archive layout depends on.

    release.sh writes a GENERATED changelog into the package directory, and only deletes
    that directory after move-folders if it is empty. A changelog left there survives as a
    spurious fourth top-level folder in the release, which is what broke v0.7.1-beta.

    Declaring a manual changelog avoids it, but only while that file is also ignored: if
    it gets copied into the package directory, release.sh uses the copy and the stray
    folder returns. Neither condition is visible in the archive this builder produces
    locally -- it does not generate changelogs at all -- so assert them on the
    configuration instead of waiting for CI to notice.
    """
    if not changelog:
        raise ValueError(
            '.pkgmeta declares no manual-changelog. BigWigs would generate '
            'ForeverCommsBundle/CHANGELOG.md, leaving a fourth top-level folder in the '
            'release archive.')
    if not (ROOT / changelog).is_file():
        raise ValueError(f'.pkgmeta manual-changelog names {changelog!r}, which does not '
                         f'exist. release.sh falls back to generating one.')
    if changelog not in ignores:
        raise ValueError(f'.pkgmeta manual-changelog {changelog!r} must also appear in '
                         f'the ignore list, or it is copied into the package directory '
                         f'and leaves a stray top-level folder in the archive.')


def ignored(rel, ignores):
    """True if a repo-relative POSIX path is excluded by .pkgmeta.

    An entry containing a slash is matched as a path prefix. A bare entry is matched
    against any path segment, which is how `tests`, `install` and `.github` exclude those
    directories inside every addon as well as at the root.
    """
    parts = rel.split('/')
    for entry in ignores:
        entry = entry.strip('/')
        if '/' in entry:
            if rel == entry or rel.startswith(entry + '/'):
                return True
        elif entry in parts:
            return True
    return False


def validate(addon):
    """Validate one addon and return (version, required_runtime_paths).

    Independent of .pkgmeta: derived from the TOC. Used both to fail fast on a broken
    addon and to confirm the .pkgmeta-driven file list did not drop a runtime file.
    """
    folder = ROOT / addon
    toc = folder / (addon + '.toc')
    if not toc.is_file():
        raise ValueError(f'missing {toc}')
    text = toc.read_text(encoding='utf-8-sig')
    match = re.search(r'^## Version:\s*(\S+)', text, re.M)
    if not match:
        raise ValueError(f'{toc} has no ## Version')
    required = {toc}
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith('## IconTexture:'):
            expected = rf'Interface\AddOns\{addon}\Media\Icon'
            if line.split(':', 1)[1].strip().lower() != expected.lower():
                raise ValueError(f'{addon} declares an incorrect IconTexture')
            required.add(folder / 'Media' / 'Icon.tga')
        if not line or line.startswith('#'):
            continue
        if not re.fullmatch(r'[a-zA-Z0-9_-]+\.(?:lua|xml)', line):
            raise ValueError(f'unsafe or unsupported TOC entry in {addon}: {line!r}')
        required.add(folder / line)
    # Auto-loaded from the addon root and deliberately absent from the TOC.
    binding = folder / 'Bindings.xml'
    if binding.is_file():
        required.add(binding)
    missing = sorted(p.relative_to(ROOT).as_posix() for p in required if not p.is_file())
    if missing:
        raise ValueError(f'{addon} is missing runtime files: {", ".join(missing)}')
    if addon != 'ForeverCommsVoice' and '## Dependencies: ForeverCommsVoice' not in text:
        raise ValueError(f'{addon} must declare ## Dependencies: ForeverCommsVoice')
    if not (folder / 'Media' / 'ProjectIcon.png').is_file():
        raise ValueError(f'{addon} is missing Media/ProjectIcon.png')
    return match.group(1), required


def walk(folder):
    for path in sorted(folder.rglob('*')):
        if path.is_file() and not path.is_symlink() and path.name != '.DS_Store':
            yield path


def write_archive(path, members):
    """members: iterable of (source_path, archive_name)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    members = sorted(set(members), key=lambda pair: pair[1])
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as out:
        for source, arc in members:
            if arc.startswith('/') or '..' in Path(arc).parts:
                raise ValueError(f'unsafe archive member: {arc}')
            out.write(source, arc)
    print(f'{path.name}: {len(members)} files')
    return path


def build_bundle(output, version_override):
    """The BigWigs-equivalent archive: three top-level addon folders, runtime only."""
    package_as, moves, ignores = read_pkgmeta()
    expected_tops = set(moves.values()) or set(ADDONS)
    if expected_tops != set(ADDONS):
        raise ValueError(f'.pkgmeta move-folders targets {sorted(expected_tops)}, '
                         f'expected {sorted(ADDONS)}')

    versions, required = {}, {}
    for addon in ADDONS:
        versions[addon], required[addon] = validate(addon)
    # BigWigs names the archive from the tag; locally the suite tracks GuildComms.
    version = version_override or versions['ForeverGuildComms']

    members, included = [], set()
    for addon in ADDONS:
        for source in walk(ROOT / addon):
            rel = source.relative_to(ROOT).as_posix()
            # BigWigs does not ship its own config or other dotfiles.
            if any(part.startswith('.') for part in rel.split('/')):
                continue
            if ignored(rel, ignores):
                continue
            members.append((source, rel))
            included.add(source)

    # Cross-check the two independent views: anything the TOC needs must have survived
    # the .pkgmeta exclusions. Catches an ignore entry that accidentally drops a module.
    for addon in ADDONS:
        dropped = sorted(p.relative_to(ROOT).as_posix() for p in required[addon] - included)
        if dropped:
            raise ValueError(f'.pkgmeta excludes required runtime files: {", ".join(dropped)}')

    archive = write_archive(output / f'{package_as}-{version}.zip', members)
    for addon in ADDONS:
        print(f'  {addon} {versions[addon]}')
    return archive


def build_source(output):
    """Source archives carrying the Windows installers. Not what BigWigs produces."""
    versions = {addon: validate(addon)[0] for addon in ADDONS}
    for addon in ADDONS:
        selected = (addon,) if addon == 'ForeverCommsVoice' else ('ForeverCommsVoice', addon)
        members = []
        for name in selected:
            members += [(p, p.relative_to(ROOT).as_posix()) for p in walk(ROOT / name)]
        members += [(p, p.relative_to(ROOT).as_posix()) for p in walk(ROOT / 'install')]
        write_archive(output / f'{addon}-{versions[addon]}-source.zip', members)
    members = []
    for addon in ADDONS:
        members += [(p, p.relative_to(ROOT).as_posix()) for p in walk(ROOT / addon)]
    for folder in ('install', 'tools', '.github'):
        members += [(p, p.relative_to(ROOT).as_posix()) for p in walk(ROOT / folder)]
    for name in ('README.md', 'PACKAGING.md', 'SUGGESTED-CHANGES.md',
                 'package.cmd', 'package.ps1', 'run-tests.cmd'):
        path = ROOT / name
        if path.is_file():
            members.append((path, name))
    write_archive(output / f'ForeverComms-Bundle-{versions["ForeverGuildComms"]}-source.zip',
                  members)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output', type=Path,
                        help='Output directory. Defaults to .release for the bundle, dist for --source.')
    parser.add_argument('--source', action='store_true',
                        help='Build source archives with installers instead of the BigWigs-shaped bundle.')
    parser.add_argument('--version', help='Override the archive version, to simulate a tag.')
    args = parser.parse_args()

    default = Path('dist') if args.source else Path('.release')
    output = args.output or default
    output = output if output.is_absolute() else ROOT / output

    if args.source:
        build_source(output)
        print('\nSource archives are a local convenience; BigWigs does not produce these.')
    else:
        build_bundle(output, args.version)
        print('\nVerify with: python tools/check_bigwigs_bundle.py')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as exc:
        print(f'Packaging failed: {exc}', file=sys.stderr)
        sys.exit(1)
