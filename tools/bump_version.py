"""Bump one or more Forever Comms package versions, everywhere they are written.

    python tools/bump_version.py --package guild --patch
    python tools/bump_version.py --package all --minor
    python tools/bump_version.py --package voice --major --channel alpha
    python tools/bump_version.py --package guild --channel release   # re-channel only
    python tools/bump_version.py --package all --patch --dry-run
    python tools/bump_version.py --sync --patch        # one version for all three
    python tools/bump_version.py --sync                # level up, no roll

`--package all` and `--sync` are different operations and the distinction matters. The
first rolls each package from its own current version, so they stay apart: 0.2.3 / 0.6.5 /
0.3.5 with --patch becomes 0.2.4 / 0.6.6 / 0.3.6. The second collapses them onto one
number, the highest in the bundle with the roll applied once: the same input with
`--sync --patch` makes all three 0.6.6-beta. Sync takes the maximum rather than a mean or
the lowest so that no package's version can move backwards onto a number that was already
published under different contents.

Why this exists. A version is written in four canonical places per package, plus the root
README and PACKAGING, plus GuildComms' own PACKAGING, plus cross-references in other
packages' documentation -- "Requires ForeverCommsVoice x.y.z" and the tag examples. Doing
that by hand has gone wrong in this repository in two different ways: a release shipped
with a stale README and installer banner between 0.5.1 and 0.6.2, and 0.6.4-beta was
chosen for a bump when a tag of that name already existed and was pushed.

So this tool does three things, and the second two matter as much as the first:

1. Rewrites only known, individually-specified sites. It never blanket-replaces a version
   string, because historical changelog headings like `## What changed in 0.6.4-beta` and
   release notes that refer to the previous release must keep their old numbers.
2. Reports any *other* occurrence of a superseded version it did not rewrite, so an
   unanticipated site surfaces as a visible list instead of silent staleness.
3. Refuses to produce a GuildComms version whose release tag already exists, because the
   unprefixed `v*` tag namespace tracks GuildComms' version alone.

It does not commit, tag, or push. Run `python tools/check_bigwigs_bundle.py` after
building to confirm the release gate agrees.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VOICE, GUILD, GROUP = 'ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms'
ADDONS = (VOICE, GUILD, GROUP)
SELECTORS = {'voice': VOICE, 'guild': GUILD, 'group': GROUP}
CHANNEL_SUFFIX = {'alpha': 'alpha', 'beta': 'beta', 'release': None}

# A version as it appears in text. Kept deliberately narrow: three numeric components and
# an optional alphanumeric channel, so it cannot swallow a date or an interface number.
VERSION = r'\d+\.\d+\.\d+(?:-[A-Za-z][A-Za-z0-9]*)?'


class BumpError(Exception):
    """A problem that must stop the bump before anything is written."""


class Version:
    def __init__(self, major, minor, patch, channel):
        self.major, self.minor, self.patch, self.channel = major, minor, patch, channel

    @classmethod
    def parse(cls, text, label):
        match = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)(?:-([A-Za-z][A-Za-z0-9]*))?', text)
        if not match:
            raise BumpError(f'{label}: cannot parse version {text!r}')
        return cls(int(match.group(1)), int(match.group(2)), int(match.group(3)),
                   match.group(4))

    def bumped(self, part, channel):
        """A major bump resets minor and patch; a minor bump resets patch."""
        major, minor, patch = self.major, self.minor, self.patch
        if part == 'major':
            major, minor, patch = major + 1, 0, 0
        elif part == 'minor':
            minor, patch = minor + 1, 0
        elif part == 'patch':
            patch += 1
        return Version(major, minor, patch, self.channel if channel is _KEEP else channel)

    @property
    def sort_key(self):
        """Ordering for --sync, which needs a single highest version.

        Numeric components first, then the channel, following semver precedence: a
        release outranks a pre-release of the same numbers, and alpha precedes beta. An
        unrecognised channel sorts below both known ones rather than being guessed at, and
        its name is included last so the order is deterministic either way.
        """
        rank = {None: 3, 'beta': 2, 'alpha': 1}.get(self.channel, 0)
        return (self.major, self.minor, self.patch, rank, self.channel or '')

    def __str__(self):
        base = f'{self.major}.{self.minor}.{self.patch}'
        return f'{base}-{self.channel}' if self.channel else base

    @property
    def numeric(self):
        return f'{self.major}.{self.minor}.{self.patch}'


_KEEP = object()   # "--channel not given": keep whatever channel the version already has


def read_text(path):
    """Read without newline translation and report whether a BOM was present, so a file
    is written back byte-identical apart from the versions. The repository pins LF via
    .gitattributes and the TOCs may carry a BOM; both must survive a bump."""
    raw = path.read_bytes()
    bom = raw.startswith(b'\xef\xbb\xbf')
    return raw[3:].decode('utf-8') if bom else raw.decode('utf-8'), bom


def write_text(path, text, bom):
    path.write_bytes((b'\xef\xbb\xbf' if bom else b'') + text.encode('utf-8'))


def sites(addon):
    """The four canonical locations for one package. Each pattern captures the version in
    a group named `ver`; nothing else in the match is touched."""
    return [
        (f'{addon}/{addon}.toc', rf'(?m)^## Version:[ \t]*(?P<ver>{VERSION})[ \t]*$'),
        # Two forms are in use: `A.version = "x"` and `V.name, V.version = ADDON, "x"`.
        (f'{addon}/Core.lua', rf'(?m)^.*\.version\s*=.*?["\'](?P<ver>{VERSION})["\']'),
        # The title line only, anchored at the start of the file, so changelog headings
        # further down keep the versions they describe.
        (f'{addon}/README.md', rf'\A\#[^\n]*?(?P<ver>{VERSION})'),
        (f'{addon}/install/Install-{addon}.cmd',
         rf'(?m)^title {addon} (?P<ver>{VERSION}) Installer$'),
        (f'{addon}/install/Install-{addon}.cmd',
         rf'(?m)^echo Installing {addon} (?P<ver>{VERSION})'),
    ]


def cross_references(addon):
    """Places that state `addon`'s version from somewhere else in the repository. These
    are rewritten from the final version map regardless of which package was bumped, so a
    reference cannot be left pointing at a version that no longer exists."""
    refs = [
        # Root README bullet list and the "Current versions" sentences in both root docs.
        ('README.md', rf'\*\*{addon} (?P<ver>{VERSION})\*\*'),
        ('README.md', rf'{addon} \*\*(?P<ver>{VERSION})\*\*'),
        ('PACKAGING.md', rf'{addon} \*\*(?P<ver>{VERSION})\*\*'),
    ]
    if addon == VOICE:
        # Both consumers state the library version they require.
        for consumer in (GUILD, GROUP):
            refs.append((f'{consumer}/README.md',
                         rf'Requires\s+\*{{0,2}}{VOICE}\*{{0,2}}\s+(?P<ver>{VERSION})'))
    if addon == GUILD:
        refs += [
            (f'{VOICE}/README.md', rf'then GuildComms (?P<ver>{VERSION})'),
            # GuildComms' own packaging guide, its version banner and the tag examples.
            (f'{GUILD}/PACKAGING.md', rf'\*\*`(?P<ver>{VERSION})`\*\*'),
            (f'{GUILD}/PACKAGING.md', rf'(?m)^\s*git (?:tag -a|push origin) v(?P<ver>{VERSION})'),
            ('PACKAGING.md', rf'(?m)^\s*git (?:tag -a|push origin) v(?P<ver>{VERSION})'),
            # The worked example rows in the root packaging guide.
            ('PACKAGING.md', rf'\| TOC `\#\# Version:` \| `\#\# Version: (?P<ver>{VERSION})` \|'),
            ('PACKAGING.md', rf'\| `Core\.lua` \| `A\.version = "(?P<ver>{VERSION})"` \|'),
        ]
    if addon == GROUP:
        refs.append((f'{VOICE}/README.md', rf'and/or GroupComms (?P<ver>{VERSION})'))
    return refs


def tag_messages(version):
    """`git tag -a ... -m "ForeverGuildComms 0.6.5 beta"` spells the channel with a space
    rather than a hyphen, so it needs its own rewrite."""
    channel = version.channel or 'release'
    return [
        (f'{GUILD}/PACKAGING.md',
         rf'-m "{GUILD} (?P<ver>\d+\.\d+\.\d+ [A-Za-z][A-Za-z0-9]*)"',
         f'{version.numeric} {channel}'),
        ('PACKAGING.md',
         rf'-m "Forever Comms (?P<ver>\d+\.\d+\.\d+ [A-Za-z][A-Za-z0-9]*)"',
         f'{version.numeric} {channel}'),
    ]


def current_versions():
    versions = {}
    for addon in ADDONS:
        path = ROOT / addon / f'{addon}.toc'
        text, _ = read_text(path)
        match = re.search(rf'(?m)^## Version:[ \t]*(?P<ver>{VERSION})', text)
        if not match:
            raise BumpError(f'{addon}.toc has no parsable ## Version line')
        versions[addon] = Version.parse(match.group('ver'), f'{addon}.toc')
    return versions


def existing_tags():
    """Local tags plus whatever the remote advertises. A missing remote is not fatal --
    offline is a normal state -- but it is reported, because the check is weaker then."""
    tags = set()
    local = subprocess.run(['git', 'tag', '--list'], cwd=ROOT,
                           capture_output=True, text=True)
    if local.returncode == 0:
        tags.update(line.strip() for line in local.stdout.splitlines() if line.strip())
    remote = subprocess.run(['git', 'ls-remote', '--tags', 'origin'], cwd=ROOT,
                            capture_output=True, text=True, timeout=30)
    if remote.returncode != 0:
        print('NOTE: could not reach origin; tag collision checked against local tags only')
        return tags, False
    for line in remote.stdout.splitlines():
        _, _, ref = line.partition('refs/tags/')
        if ref and not ref.endswith('^{}'):
            tags.add(ref.strip())
    return tags, True


def git(*arguments):
    result = subprocess.run(('git',) + arguments, cwd=ROOT,
                            capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def report_repository():
    """Print the repository state before anything is rewritten.

    This exists because skipping it has gone wrong twice: a bump was once chosen without
    noticing that the target tag was already published, and on another occasion HEAD had
    moved and been tagged externally while a bump was being prepared against the old
    state. Both are obvious the moment the log and tag list are in front of you.
    """
    head = git('log', '-1', '--format=%h %s') or '(no commits)'
    branch = git('rev-parse', '--abbrev-ref', 'HEAD') or '(unknown)'
    print(f'Repository:\n  HEAD     {head}\n  branch   {branch}')

    counts = git('rev-list', '--left-right', '--count', '@{u}...HEAD')
    ahead = 0
    if counts:
        behind, ahead = (int(part) for part in counts.split())
        state = 'in sync with upstream'
        if ahead or behind:
            state = f'{ahead} ahead, {behind} behind upstream'
        print(f'  upstream {state}')
    else:
        print('  upstream (none configured)')

    staged = [line[3:] for line in (git('status', '--porcelain') or '').splitlines()
              if line[:1] not in (' ', '?', '')]
    unstaged = [line[3:] for line in (git('status', '--porcelain') or '').splitlines()
                if line[1:2] == 'M']
    print(f'  pending  {len(staged)} staged, {len(unstaged)} unstaged')
    return {'staged': set(staged), 'unstaged': set(unstaged), 'ahead': ahead}


def warn_about_pending(state, targets):
    """A bump that lands on top of someone else's in-flight edit to the same file leaves
    two unrelated changesets tangled in the working tree. Worth naming, not blocking."""
    pending = state['staged'] | state['unstaged']
    overlap = sorted(p for p in pending if p.replace('\\', '/') in targets)
    if overlap:
        print('\nWARNING: these files already have uncommitted changes and this bump '
              'will rewrite them:')
        for path in overlap:
            print(f'  {path}')
        print('  Consider committing or stashing that work first, so the bump is a '
              'reviewable change on its own.')


def apply_edits(replacements, dry_run):
    """replacements: {relative path: [(pattern, new text for the `ver` group)]}"""
    changed, touched = [], 0
    for relative, rules in sorted(replacements.items()):
        path = ROOT / relative
        if not path.is_file():
            print(f'NOTE: {relative} not found, skipped')
            continue
        text, bom = read_text(path)
        original = text
        for pattern, new in rules:
            def swap(match, new=new):
                start, end = match.span('ver')
                return match.group(0)[:start - match.start()] + new + \
                    match.group(0)[end - match.start():]
            text, count = re.subn(pattern, swap, text)
            if count:
                changed.append(f'  {relative}: {count} x -> {new}')
        if text != original:
            touched += 1
            if not dry_run:
                write_text(path, text, bom)
    return changed, touched


def leftovers(superseded):
    """Any remaining mention of a version this run replaced, excluding the places that
    legitimately keep it: changelog headings and prose about an earlier release."""
    found = []
    for relative in ['README.md', 'PACKAGING.md'] + [
            f'{a}/{p}' for a in ADDONS for p in
            ('README.md', 'PACKAGING.md', f'{a}.toc', 'Core.lua',
             f'install/Install-{a}.cmd')]:
        path = ROOT / relative
        if not path.is_file():
            continue
        text, _ = read_text(path)
        for number, line in enumerate(text.splitlines(), 1):
            for old in superseded:
                if old in line and not re.match(r'\s*#{1,6}\s', line):
                    found.append(f'  {relative}:{number}: {line.strip()[:90]}')
    return found


def main():
    parser = argparse.ArgumentParser(
        description='Bump Forever Comms package versions everywhere they are written.')
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument('--package', choices=sorted(SELECTORS) + ['all'],
                       help='which package to bump, or "all" to bump each package from '
                            'its own current version')
    scope.add_argument('--sync', action='store_true',
                       help='set every package to one version: the highest currently in '
                            'the bundle, with any bump applied to it. Unlike '
                            '"--package all", which rolls each package separately and '
                            'keeps them apart, this collapses them to a single number')
    part = parser.add_mutually_exclusive_group()
    part.add_argument('--major', action='store_const', const='major', dest='part',
                      help='bump major, resetting minor and patch to 0')
    part.add_argument('--minor', action='store_const', const='minor', dest='part',
                      help='bump minor, resetting patch to 0')
    part.add_argument('--patch', action='store_const', const='patch', dest='part',
                      help='bump patch')
    parser.add_argument('--channel', choices=sorted(CHANNEL_SUFFIX),
                        help='set the channel: alpha, beta, or release for no suffix. '
                             'Omit to keep the current channel')
    parser.add_argument('--dry-run', action='store_true',
                        help='report what would change without writing')
    parser.add_argument('--allow-existing-tag', action='store_true',
                        help='proceed even if the resulting release tag already exists')
    args = parser.parse_args()

    if not args.part and not args.channel and not args.sync:
        parser.error('nothing to do: pass --major, --minor or --patch, '
                     'and/or --channel, or --sync')

    state = report_repository()
    released = sorted(t for t in (git('tag', '--list') or '').splitlines() if t.strip())
    print(f'  released {", ".join(released) if released else "(no tags)"}\n')

    channel = _KEEP if args.channel is None else CHANNEL_SUFFIX[args.channel]
    versions = current_versions()
    updated = dict(versions)

    if args.sync:
        # One source version for the whole bundle: the highest in play, rolled once.
        # Taking the maximum means no package's version can move backwards, which would
        # otherwise make an already-released number ambiguous.
        source = max(ADDONS, key=lambda addon: versions[addon].sort_key)
        target = versions[source].bumped(args.part, channel)
        print(f'Sync source: {source} at {versions[source]}, the highest in the bundle')
        if args.part:
            print(f'Rolled by --{args.part} to {target}')
        for addon in ADDONS:
            updated[addon] = target
        behind = [a for a in ADDONS if versions[a].sort_key < versions[source].sort_key]
        if behind:
            print('Jumping ' + ', '.join(f'{a} {versions[a]}' for a in behind) +
                  f' straight to {target}')
    else:
        targets = ADDONS if args.package == 'all' else (SELECTORS[args.package],)
        for addon in targets:
            updated[addon] = versions[addon].bumped(args.part, channel)

    print('Versions:')
    for addon in ADDONS:
        before, after = str(versions[addon]), str(updated[addon])
        mark = '  ->' if before != after else '    '
        print(f'  {addon:<18} {before:<14}{mark} {after if before != after else ""}')

    if all(str(versions[a]) == str(updated[a]) for a in ADDONS):
        print('\nNothing would change.')
        return 0

    if args.channel == 'release':
        print('\nWARNING: --channel release drops the -beta suffix. '
              'release-packaging.md says to keep -beta on all three packages while the '
              'Forever client itself is in beta.')

    # The unprefixed v* tag namespace tracks GuildComms' version alone.
    tag = f'v{updated[GUILD]}'
    if str(updated[GUILD]) != str(versions[GUILD]):
        tags, reached_remote = existing_tags()
        if tag in tags:
            where = 'locally or on origin' if reached_remote else 'locally'
            message = (f'tag {tag} already exists {where}. '
                       f'A released version cannot be reused; bump further')
            if not args.allow_existing_tag:
                raise BumpError(message)
            print(f'\nWARNING: {message} (continuing, --allow-existing-tag given)')
        else:
            print(f'\nRelease tag {tag} is free.')

    replacements = {}
    for addon in ADDONS:
        new = str(updated[addon])
        if new == str(versions[addon]):
            continue
        for relative, pattern in sites(addon) + cross_references(addon):
            replacements.setdefault(relative, []).append((pattern, new))
        if addon == GUILD:
            for relative, pattern, new_message in tag_messages(updated[addon]):
                replacements.setdefault(relative, []).append((pattern, new_message))

    warn_about_pending(state, set(replacements))

    changed, touched = apply_edits(replacements, args.dry_run)
    verb = 'Would rewrite' if args.dry_run else 'Rewrote'
    print(f'\n{verb} {len(changed)} site(s) across {touched} file(s):')
    print('\n'.join(changed) if changed else '  (none -- check the patterns)')

    if not changed:
        raise BumpError('no site matched; refusing to report success')

    superseded = {str(versions[a]) for a in ADDONS
                  if str(versions[a]) != str(updated[a])}
    if not args.dry_run:
        remaining = leftovers(superseded)
        if remaining:
            print('\nReview these remaining mentions of a superseded version. Release '
                  'notes and prose about an earlier release are expected here; anything '
                  'else is a site this tool does not know about:')
            print('\n'.join(remaining))

    # The release gate only requires the README to *mention* the version, which the title
    # line now does, so a missing changelog section will not fail any check.
    print('\nStill to do by hand: a "What changed in x.y.z" section in the README of '
          'each bumped package.')
    if state['ahead'] and str(updated[GUILD]) != str(versions[GUILD]):
        print(f'\nWARNING: HEAD is {state["ahead"]} commit(s) ahead of upstream. A tag on '
              'an unpushed commit will not build in GitHub Actions; push before tagging.')

    print('\nNot committed, not tagged. Next:')
    print('  python tools/package.py && python tools/check_bigwigs_bundle.py')
    if str(updated[GUILD]) != str(versions[GUILD]):
        print(f'  git tag -a {tag} -m "Forever Comms {updated[GUILD].numeric} '
              f'{updated[GUILD].channel or "release"}"')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except BumpError as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
