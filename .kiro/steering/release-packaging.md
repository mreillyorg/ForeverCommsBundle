---
inclusion: auto
name: release-packaging
description: TOC metadata, per-package version bumping, SavedVariables migration, installer rules, and monorepo packaging for the Forever Comms bundle. Use when editing any .toc, changing a version, adding saved settings, touching an installer or .pkgmeta, or preparing a distributable zip or release tag.
---

# TOC, versioning, and packaging

Three packages ship independently out of one repository. Nothing here is shared between
them except the repository root and the dependency edge, so **every rule below applies per
package**.

| Package | Version | Depends on |
| --- | --- | --- |
| `ForeverCommsVoice` | 0.1.0-beta | nothing |
| `ForeverGuildComms` | 0.5.0-beta | `ForeverCommsVoice` |
| `ForeverGroupComms` | 0.2.0-beta | `ForeverCommsVoice` |

## TOC rules

All three TOCs must keep:

- `## Interface: 16001` — the Forever 1.60.1 interface number. Do not change it to a
  Classic Era or retail value, and keep all three identical.
- The file list in dependency order, `Core.lua` first.
- `## Version` identical to the `version` field in that package's `Core.lua`.

Per package:

| | Voice | GuildComms | GroupComms |
| --- | --- | --- | --- |
| `## SavedVariables` | — | `ForeverGuildCommsDB` | `ForeverGroupCommsDB` |
| `## SavedVariablesPerCharacter` | `ForeverCommsVoiceCharDB` | `ForeverGuildCommsCharDB` | — |
| `## Dependencies` | — | `ForeverCommsVoice` | `ForeverCommsVoice` |
| `## OptionalDeps` | — | `Titan` | `Titan` |
| `## IconTexture` | — | `Interface\AddOns\ForeverGuildComms\Media\Icon` | — |

- `## Dependencies` is for `ForeverCommsVoice` only. A third-party library must never
  appear there — Titan/LibDataBroker stays `OptionalDeps` plus a runtime
  `LibStub(..., true)` probe.
- `## Dependencies` guarantees presence, **not version**. There is no negotiation, so a
  breaking change to `V:Render`'s options contract requires bumping and releasing all
  three packages together.
- Every new `.lua` source file must be added to its package's TOC, and nothing that is not
  shipped code should be listed. `tests/` and `install/` stay out.
- **`Bindings.xml` must never be listed in a TOC.** The client auto-loads it from the
  addon root. GuildComms and GroupComms each ship one; Voice has none.

## Version bumps

**Seven places move together per package.** The old "three places" rule is no longer
sufficient:

1. the TOC `## Version`
2. `A.version` / `V.version` in that package's `Core.lua`
3. that package's `README.md` title line
4. `install/Install-<Addon>.cmd` — the `title` line
5. `install/Install-<Addon>.cmd` — the `echo Installing …` line
6. `install/Install-<Addon>.ps1` — the banner `Write-Host` line
7. `install/INSTALL-README.txt` — the heading

Plus, for GuildComms only: `PACKAGING.md`, which states the current version and shows an
example tag command. And if a release changes the dependency relationship, the consuming
packages' "Requires ForeverCommsVoice x.y.z" README lines.

Grep before claiming a bump is done:

```powershell
Select-String -Path "<Addon>\*","<Addon>\install\*" -Pattern "\d+\.\d+\.\d+-beta"
```

The distributable inner folder must always be exactly the addon name — `ForeverCommsVoice`,
`ForeverGuildComms`, `ForeverGroupComms` — or the client will not find the TOC.

While the client is in beta, keep the `-beta` suffix on all three and keep each README's
"Limitations and testing notes" section current. It is the honest record of what has not
been verified in a live client, and nothing in this bundle has been run against a live
server.

## SavedVariables compatibility

Four tables, three owners. Never let one package write another's table — the only
sanctioned cross-package state is the shared voice profile, and it has one writer.

- **Add new settings to that package's `defaults` in its `Core.lua`.** GuildComms'
  `fillDefaults` backfills missing keys recursively on load; GroupComms' `copyDefaults`
  plus the per-key `type()` check in `Initialize` repairs a wrong-typed value;
  Voice's `normalize` clamps each field to a valid value.
- Never rename or repurpose an existing key without a migration step in that package's
  `Initialize`.
- **Migrations must be latched.** `V:MigrateLegacy` adopts
  `ForeverGuildCommsCharDB.voice` exactly once and records `migratedFromGuild`, so a later
  login cannot overwrite a change the user made in the shared panel. Any future migration
  needs the same shape.
- Per-character data stays per character: `ForeverGuildCommsCharDB` holds `recipes`
  (professions are character-specific), `myRoles`, `needRoles`;
  `ForeverCommsVoiceCharDB` holds the voice profile. Account-wide behavior settings and
  GuildComms' custom templates stay account-wide.
- **Defaults must be the safe choice.** Anything that posts to a shared channel without a
  click defaults to the conservative setting — `outgoingMode = "automatic"` preserves
  existing GuildComms behavior, and GroupComms' `autoGreeting` / `autoLevel` both default
  to `false`. Anything that could surprise the user, like `tabardOnExit`, defaults to
  `false`.
- If a new default **changes existing output on upgrade**, say so explicitly in that
  package's README. `randomizeMessages = true` is the one precedent and it is the
  exception, not the pattern.
- `A.char.voice` and `ForeverCommsVoiceCharDB.voice` are the **same table object** at
  runtime. The client serializes each file separately, so the profile is written into both
  files on logout and the GuildComms copy is then ignored forever by the migration latch.
  Do not "fix" that by writing one from the other; route all changes through
  `V:SetOption`.

## Installers

Four installers: one combined at the repository root and one per package.

- The **per-package installers** parse their own TOC, copy only the listed loadable files
  plus `Bindings.xml` and, for GuildComms, `Media\Icon.tga`. They back up the specific
  files they replace under `Interface\AddOnBackups`, skip files that are already
  identical, and never touch WTF/SavedVariables. Keep that precision — the READMEs
  advertise it.
- The **combined installer** (`install/Install-ForeverComms.ps1`) stages all three folders,
  verifies every source TOC before touching the existing installation, and rolls back on
  failure. Its `$names` array is the list of packages; a new package must be added there.
- **A per-package installer for a dependent addon must handle the dependency.** Installing
  GuildComms or GroupComms without `ForeverCommsVoice` produces an addon the client
  refuses to load. At minimum detect the library's absence and refuse with a clear
  message pointing at the combined installer; better, offer to install it.
- Keep the `.cmd` launchers using `-NoProfile -ExecutionPolicy Bypass` for that process
  only, and keep the manual-copy instructions in each `INSTALL-README.txt`.

> **Known deviations:** neither per-package installer references `ForeverCommsVoice` at
> all, and the combined installer copies whole folders recursively, so `tests/`,
> `install/` and `.github/` land in `AddOns/`. Both are target-state violations.

## Monorepo packaging

The repository root is **not** an addon folder. BigWigsMods/packager and GitHub Actions
both assume things about the checkout root, so the layout rules are:

- **Workflows live at the repository root**, in `.github/workflows/`. GitHub Actions does
  not read workflow files from subdirectories, so a `package.yml` inside a package folder
  never runs.
- **Tags must be package-scoped.** Three packages at three versions cannot share one
  unprefixed `v*` namespace. Use a prefix per package — for example `voice/v0.1.0-beta`,
  `guild/v0.5.0-beta`, `group/v0.2.0-beta` — and filter each job on its own pattern.
- **Each packager invocation needs its own working directory and `.pkgmeta`.** Point the
  packager at the package folder rather than the checkout root.
- Keep the env-var names consistent across jobs. `GITHUB_TOKEN` is enough for a GitHub
  release; CurseForge/WoWInterface/Wago tokens are optional and only needed alongside real
  `## X-…-ID` metadata in that package's TOC. Do not paste placeholder IDs into a TOC.
- Each `.pkgmeta` excludes repository-only files: `.github`, `install`, `tests`,
  `PACKAGING.md`, `Media/ProjectIcon.png`. It must **not** exclude `Bindings.xml` or
  `Media/Icon.tga` — both are runtime files.
- Nothing is vendored. No `externals` block, no `Libs/`, no `embeds.xml`. Titan integration
  deliberately uses Titan's own LibDataBroker copy.
- The root `.gitignore` must ignore `.release/`, the packager's local output directory.

> **Known deviations:** all three `package.yml` files sit in package subdirectories and the
> root has no `.github/`, so **no tag currently triggers any packaging**. All three also
> listen on an unprefixed `v*`. The three `.pkgmeta` files are positioned for a
> single-addon repository root. The root `.gitignore` does not ignore `.release/`.
> GuildComms' `PACKAGING.md` documents the old single-addon-at-root layout as a
> requirement and lists four modules that moved into the library.

## Manual ZIP vs packager ZIP

- **Manual ZIP** (what a user downloads from the repository): includes the package, its
  `install/` folder, `tests/`, `.pkgmeta` and the docs. The user runs
  `install\Install-<Addon>.cmd`, or the root `install\Install-ForeverComms.cmd` for all
  three.
- **Packager ZIP** (from Actions): the `.toc`, its loadable Lua files, `Bindings.xml`,
  `Media/Icon.tga` where present, and the README. Intended for addon managers.

## Pre-release pass

Per package being released:

1. **All 13 harnesses run and print `PASSED`** — not just the ones in the package you
   changed. Eight GuildComms harnesses load the Voice source, and
   `ForeverCommsVoice/tests/integration.lua` loads all three packages, so a library change
   can break a consumer's suite. See `testing.md` for the run commands.
2. All seven version-string locations match, plus `PACKAGING.md` for GuildComms.
3. Every shipped `.lua` file is in that package's TOC in the right load order, and
   `Bindings.xml` is **not**.
4. `.pkgmeta` still does not exclude `Bindings.xml` or `Media/Icon.tga`.
5. `## Dependencies` and `## OptionalDeps` are still correct, and a dependency contract
   change has been applied to all three packages.
6. The README's features, commands, templates and limitations reflect the code, and the
   root `README.md` still describes the bundle accurately.
7. The in-game checklist has been walked, or the gaps are written down as limitations.
8. If the release changes the dependency relationship, the install documentation says so
   and the installers enforce it.
