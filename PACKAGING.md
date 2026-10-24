# Forever Comms packaging and releases

## Build locally (no GitHub Actions required)

From the suite root, run `package.cmd` on Windows or `python tools/package.py --output dist`. The build reads each addon `.toc` to obtain its version, verifies every listed runtime module and icon, and creates individual source ZIPs (each consumer includes its ForeverCommsVoice dependency) plus one suite source ZIP. For addon-manager-minimal builds use `python tools/package.py --output dist --runtime`.

Current versions: ForeverCommsVoice **0.2.1-beta**, ForeverGuildComms **0.6.1-beta**, ForeverGroupComms **0.3.1-beta** (suite 0.6.1-beta). Copy release archives from `dist/`; do not upload an unextracted ZIP to a WoW AddOns folder.

## GitHub

The suite-root `.github/workflows/package.yml` builds on version tags and manual dispatch. The independent addon-root `.github/workflows/package.yml` files are BigWigsMods/packager workflows for independently hosted repositories: copy each addon folder's *contents* to that addon's GitHub repository root, and configure its CurseForge secrets as necessary. Do not expect an addon-root workflow to execute automatically when nested within the suite repository.

## Installation

The suite installer (`install/Install-ForeverComms.cmd`) stages and checks all runtime files before replacing installed addons, backs up existing directories outside AddOns, and preserves SavedVariables. Each consumer ZIP includes ForeverCommsVoice and redirects its per-addon installer to the shared installer.

## Tests

From the suite root: `texlua ForeverCommsVoice/tests/queue.lua`, `texlua ForeverCommsVoice/tests/queue_ui.lua`, and `texlua ForeverCommsVoice/tests/integration.lua`. From the GuildComms folder: `texlua tests/verify.lua` and `texlua tests/icon.lua`. From the GroupComms folder: `texlua tests/smoke.lua`. These test Lua behavior and UI with lightweight mocks, not in-game client acceptance.

Titan menu update: GuildComms 0.6.2-beta and GroupComms 0.3.3-beta; Voice remains 0.2.1-beta. `TitanMenu.lua` is included in GroupComms TOC and both source and runtime packages.

## BigWigsMods/packager: whole bundle

The repository **root** now contains `.pkgmeta` and `.github/workflows/package.yml`.
It is intended for a **single GitHub repository containing all three addon
subdirectories**, not a repository that contains only one addon folder.

On GitHub, **Actions → Package Forever Comms bundle (BigWigs) → Run workflow**
creates an installable artifact. Pushing an annotated tag such as
`v0.6.2-beta.1` also creates a GitHub Release with the ZIP attached. Tag and
ZIP versioning is managed by BigWigs.

The root `.pkgmeta` uses `package-as: ForeverCommsBundle` plus `move-folders`
to produce the only correct installable layout:

```
ForeverCommsVoice/ForeverCommsVoice.toc
ForeverGuildComms/ForeverGuildComms.toc
ForeverGroupComms/ForeverGroupComms.toc
```

The workflow passes `-d` to suppress automatic third-party publication. This
keeps the beta safe to build without CurseForge/Wago project IDs or API secrets;
GitHub Releases and workflow artifacts still receive the output ZIP. When you
create a dedicated CurseForge project, supply its actual project ID and upload
credentials before enabling platform publication. WoW Forever's nonstandard
`## Interface: 16001` may require manual game-version selection on hosted
addon platforms.

Run `python tools/check_bigwigs_bundle.py` after an actual BigWigs build to
check its structure. Local custom packaging via `package.cmd` remains available.
