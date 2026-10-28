# Forever Comms Suite: packaging and releases

Current versions: ForeverCommsVoice **0.7.4-beta**, ForeverGuildComms **0.7.4-beta**,
ForeverGroupComms **0.7.4-beta** (WoW Forever Interface 16001).

## One release path, two ways to run it

**[BigWigsMods/packager](https://github.com/BigWigsMods/packager) is the authoritative
release path.** It runs in GitHub Actions and produces the archive users install.

The local build mirrors it, so a release can be previewed and checked without pushing a
tag. It is not a separate format: it reads the **same root `.pkgmeta`** BigWigs reads, so
there is one source of truth for what ships, and its output is validated against the same
contract CI applies.

| | Authoritative GitHub release | Local preview |
| --- | --- | --- |
| Builder | `BigWigsMods/packager@v2` | `tools/package.py` |
| Driven by | root `.pkgmeta` | root `.pkgmeta` |
| Output | `.release/*.zip` | `.release/*.zip` |
| Validated by | `tools/check_bigwigs_bundle.py` | `tools/check_bigwigs_bundle.py` |
| Needs | a pushed `v*` tag, nothing installed locally | Python 3 |

### Build locally

```text
package.cmd                       Windows, double-clickable
python tools/package.py           any platform
```

Both write `.release/ForeverCommsBundle-<version>.zip` and then run the structure check.
`package.cmd` is a launcher over `package.ps1`, which is a launcher over
`tools/package.py` — deliberately not a second implementation, because an earlier version
kept parallel inclusion rules and drifted from `.pkgmeta`.

Options:

```text
python tools/package.py --version 1.2.3    simulate a specific tag
python tools/package.py --source           source archives with the Windows installers
package.ps1 -Source                        same, from Windows
```

### What the archive contains

Three top-level addon folders and nothing else — the layout WoW expects under
`Interface/AddOns`:

```text
ForeverCommsVoice/    TOC, 9 Lua modules, Media/Icon.tga
ForeverGuildComms/    TOC, 9 Lua modules, Bindings.xml, Media/Icon.tga
ForeverGroupComms/    TOC, 7 Lua modules, Bindings.xml, Media/Icon.tga
```

33 files. The root `.pkgmeta` `ignore` list strips `.github`, `install`, `tools`, `tests`,
every README, `PACKAGING.md`, the promotional `Media/ProjectIcon.png` and the build
scripts. Dotfiles, including `.pkgmeta` itself, are not shipped.

`move-folders` lifts the three addons out of the `ForeverCommsBundle/` wrapper
directory to top level. **Every other repository-root file/directory must be listed
in the root `.pkgmeta` `ignore` section**, otherwise BigWigs may leave an extra
`ForeverCommsBundle/` directory in the archive. The local Python builder
includes only addon folders, so its successful run alone cannot prove that
BigWigs has no leftover root files. The structure validator catches this.

## What `check_bigwigs_bundle.py` verifies

This runs on both paths — in CI after BigWigs, and locally after `package.cmd`. Three
groups of checks:

**1. Archive structure.** Exactly the three expected folders at top level with no stray
files, no member containing `..` or a leading `/`, both consumer
`## Dependencies: ForeverCommsVoice` lines intact, and no `tests/`, `install/` or
`.github/` content. This is what catches `move-folders` going wrong.

**2. Runtime completeness.** Every file the client needs is present, derived from each
TOC. That explicitly includes **`Bindings.xml`**, which is auto-loaded from the addon root
and deliberately absent from the TOC — so without this check a release could ship with no
key bindings and nothing TOC-driven would notice. It also covers `Media/Icon.tga` for any
addon declaring `## IconTexture:`. The shipped TOC's version must match the repository's,
so a rewritten manifest cannot slip through.

**3. Version consistency.** Each addon states its version in four places and they must
agree:

| Place | Example |
| --- | --- |
| TOC `## Version:` | `## Version: 0.7.4-beta` |
| `Core.lua` | `A.version = "0.7.4-beta"` |
| `README.md` | the title or "Current release" line |
| `install/Install-<Addon>.cmd` | the `title` and `echo` lines |

This is the check whose absence let 0.6.2 ship with a 0.6.1 README and a 0.5.1 installer
banner. Historical changelog headings like `## Shared review queue (v0.6.1-beta)` are not
affected — the check requires the current version to appear, not that older ones are
removed.

Every check fails the build with a specific message naming the file and the mismatch.
Addon *behaviour* is not checked here; the workflow runs `tools/run_tests.py` first.

### Source archives are a local convenience

`--source` produces per-addon archives that bundle `ForeverCommsVoice` plus the Windows
installers under `install/`, and a suite archive with the build tools and docs. **BigWigs
does not produce these.** They exist for manual Windows installation, where
`install/Install-ForeverComms.ps1` installs the dependency first and copies only
TOC-declared runtime files. Verify them with `tools/verify_package.py`, not
`check_bigwigs_bundle.py`.

### Build validation

Both paths fail rather than shipping something wrong. The local builder refuses to build
on:

- a missing TOC, or a TOC with no `## Version:`
- a TOC entry that is not `^[A-Za-z0-9_-]+\.(lua|xml)$`, or names a file that is absent
- an `## IconTexture:` value other than that addon's own `Media\Icon`
- a missing `Media/Icon.tga` or `Media/ProjectIcon.png`
- a consumer addon missing `## Dependencies: ForeverCommsVoice`
- a `.pkgmeta` `ignore` entry that would drop a TOC-declared runtime file
- a `.pkgmeta` construct the builder does not implement, rather than silently producing an
  archive that differs from what BigWigs would build
- any archive member with a leading `/` or a `..` segment

The last two are the parity guards. The builder cross-checks two independent views of what
ships — the TOC manifest and the `.pkgmeta` exclusions — and fails if they disagree.

## Releasing from GitHub

Commit the suite contents at the repository root, then push an annotated tag:

```bash
git tag -a v0.7.4-beta -m "Forever Comms 0.7.4 beta"
git push origin v0.7.4-beta
```

The workflow checks out with full tag history, runs BigWigs with `-d`, runs
`check_bigwigs_bundle.py`, uploads the ZIP as a workflow artifact, and on a tag attaches
it to a GitHub Release using the built-in `GITHUB_TOKEN` with `contents: write`. No
third-party secret is required. It is also runnable from Actions > Run workflow without a
tag, which produces the artifact but no Release.

One `v*` tag releases the suite as a unit; the per-addon versions live in each TOC and the
archive takes GuildComms' version.

## Three independent repositories

For standalone CurseForge-style repositories, move the **contents** of one addon folder to
that repository root. Each addon keeps its own `.pkgmeta` and
`.github/workflows/package.yml` for exactly this case, and each of those workflows carries
a header comment saying it is active only then. A standalone packager release does **not**
bundle `ForeverCommsVoice`: users must install it separately, and any project metadata
must declare it as a dependency.

## Publishing to CurseForge

Each addon is **its own CurseForge project**, not one project for the bundle. Author
account `mreillyorg`.

| Addon | Project ID | Primary category | Required dependency |
| --- | --- | --- | --- |
| `ForeverCommsVoice` | `1768865` | Chat & Communication | — |
| `ForeverGuildComms` | `1768871` | Guild | Forever Comms Voice |
| `ForeverGroupComms` | `1768876` | Chat & Communication | Forever Comms Voice |

The ids live in each addon's own TOC as `## X-Curse-Project-ID`. The API token is the
`CF_API_TOKEN` repository secret and must never be committed.

`16001` **is** recognised. An earlier note here warned it might not be; that has been
settled. `release.sh` maps interface `16???` to game type `forever`, its flavour table
accepts both `forever` and `camelot`, and CurseForge lists the client as *WoW: Forever
(codename Camelot, flavour `wow_classic_beta`)* with other addons already publishing
Forever files. No `-g` override is needed — the game version comes from the TOC.

### How the workflow publishes

Four packager invocations, deliberately separated:

- **The bundle** builds with `-d -p 0` and is for GitHub only. `-d` skips uploading; `-p 0`
  unsets any CurseForge id. The second flag matters because there is no
  `ForeverCommsBundle.toc`, so `release.sh` falls back to a `move-folders` TOC and would
  otherwise adopt one of the three addons' project ids and publish the whole bundle to
  that single project.
- **Each addon** builds with `-t <addon>`, which points `release.sh` at that folder, where
  it finds the addon's own `.pkgmeta` and writes to `<addon>/.release`. These cannot
  disturb the bundle already verified by `check_bigwigs_bundle.py`.

### Publishing one, two, or all three

Each addon has its own upload switch, so a release can publish any subset without
touching the others.

| Trigger | What publishes |
| --- | --- |
| Push a `v*` tag | All three. No inputs exist on a tag push, and an absent input means yes |
| Push to `main` | Nothing. All three are still built and verified |
| Dispatch against a tag | Whichever boxes are ticked |

```powershell
# republish only ForeverGuildComms for an existing tag
gh workflow run "Package Forever Comms bundle (BigWigs)" --ref v0.7.5-beta `
  -f publish_voice=false -f publish_guild=true -f publish_group=false
```

Two rules hold regardless of the switches:

- **Uploading always requires a tag ref.** An untagged build has no release version, and
  CurseForge files cannot be unpublished, so a branch push must never reach an upload.
- **A deselected addon is still built and verified.** Only its upload is skipped. A
  package nobody builds is a package nobody notices has broken.

The flags are `UPLOAD_VOICE`, `UPLOAD_GUILD` and `UPLOAD_GROUP`, each holding either `-d`
(skip uploading) or empty. They are computed by the "Decide what to publish" step and
**must not** be turned into expressions: `${{ cond && '' || '-d' }}` is always `-d`,
because an empty string is falsy in GitHub expressions, so the true branch falls through
to the `||`. That would disable publishing while looking correct. The job-level defaults
are `-d` so that the safe outcome is also the default if that step is ever removed.

Each per-addon `.pkgmeta` declares `manual-changelog: CHANGELOG.md` and also ignores it, so
uploads carry the curated root changelog rather than a generated commit dump, and no
`CHANGELOG.md` ends up inside the addon folder. A workflow step copies the root
`CHANGELOG.md` into each addon directory before packaging; those copies are gitignored and
must not be committed. Run a per-addon build without that copy and `release.sh` simply
warns and generates a changelog instead.

### Project page content

Keep the beta caveat on all three pages while the addons carry `-beta`. The READMEs state
that nothing in this bundle has been run against a live Forever server; a store page that
omits it would be the one actively misleading thing about these projects.

## Before tagging

1. `python tools/run_tests.py` — the offline Lua suite. See `.kiro/steering/testing.md`.
   CI runs the same command before packaging, so a failure here is a failure there.
2. `package.cmd` or `python tools/package.py`, which runs `check_bigwigs_bundle.py` itself
   and therefore covers the version consistency and runtime completeness checks above.
3. Install the local archive into a real client and confirm all three addons load.

Step 2 means version drift and a missing `Bindings.xml` are now caught automatically on
both paths; neither needs a manual pass.

All three addons share one per-character voice/queue SavedVariables file under `WTF`. No
installer or builder ever reads, writes or copies SavedVariables.
