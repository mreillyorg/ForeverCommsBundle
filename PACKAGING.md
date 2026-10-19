# Forever Comms Suite: packaging and releases

Release set: **ForeverGuildComms 0.5.1-beta**, **ForeverGroupComms 0.2.1-beta**, **ForeverCommsVoice 0.1.1-beta** (WoW Forever Interface 16001).

## Build locally without GitHub Actions

This extracted bundle is immediately packageable. No Git repository, tag, CurseForge account, network connection, packager installation or API token is needed.

**Windows:** double-click `package.cmd`, or run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\package.ps1` in the extracted suite directory. Windows PowerShell 5.1 and .NET zip support are sufficient. The script includes hidden workflow files in the source archives.

**Windows/macOS/Linux with Python 3:** run `python tools/package.py --output dist`. Python's standard library is the only dependency. `--runtime` optionally creates smaller addon-manager ZIPs with only runtime files; source ZIPs are the default.

Both commands put these archives under `dist/`:

- `ForeverCommsVoice-0.1.1-beta.zip`
- `ForeverGuildComms-0.5.1-beta.zip` (includes ForeverCommsVoice)
- `ForeverGroupComms-0.2.1-beta.zip` (includes ForeverCommsVoice)
- `ForeverComms-Bundle-0.5.1-beta.zip` (all three)

Every source ZIP includes the root `install/Install-ForeverComms.ps1` shared installer, and the per-addon `.cmd`/`.ps1` entry point inside its addon folder. An individual Guild/Group ZIP contains its Voice dependency so its installer can install both in the correct order. All source ZIPs include `Media/Icon.tga` and `Media/ProjectIcon.png` for each addon. Run `install/Install-ForeverComms.cmd` for the bundle.

`--runtime` ZIPs contain TOC-listed runtime files, any `Bindings.xml`, and game icon `Media/Icon.tga`. They intentionally contain no installer, tests, `.pkgmeta` or promotional project icon. If installing a runtime ZIP manually, copy each top-level addon folder under `Interface/AddOns`.

## GitHub layout: suite in ONE repository

Commit the **contents of the extracted bundle** at repository root:

```text
.github/workflows/package.yml    <-- active in a suite repository
package.cmd                       <-- offline Windows entry point
package.ps1
PACKAGING.md
README.md
tools/package.py                  <-- offline cross-platform entry point
install/Install-ForeverComms.ps1
ForeverCommsVoice/ForeverCommsVoice.toc
ForeverGuildComms/ForeverGuildComms.toc
ForeverGroupComms/ForeverGroupComms.toc
```

The active **root** `.github/workflows/package.yml` runs the same offline Python builder on manual workflow dispatch or `v*` tag push. It uploads four ZIPs as a workflow artifact. Tagged runs additionally attach the ZIPs to the GitHub Release using the built-in `GITHUB_TOKEN`, which needs `contents: write` permission. It does **not** require BigWigsMods or optional CurseForge secrets. A workflow nested inside `ForeverGuildComms/.github` is NOT discovered when GitHub's repository root is the *suite*; those nested workflows are for independent addon repositories only.

For a tagged release, run `git tag -a v0.5.1-beta -m "Forever Comms 0.5.1 beta"` then `git push origin v0.5.1-beta`, after committing the sources. The root workflow is also usable via Actions > Build Forever Comms suite > Run workflow.

## Three independent repositories / BigWigsMods/packager

For *standalone* CurseForge-style source repositories, move the **contents** of `ForeverGuildComms/`, `ForeverGroupComms/` or `ForeverCommsVoice/` to that repository root. Each contains its own `.pkgmeta` and `.github/workflows/package.yml`. That workflow uses [BigWigsMods/packager@v2](https://github.com/BigWigsMods/packager), runs only after code is pushed to GitHub, and should receive the supported environment variables `GH_API_TOKEN` and `CF_API_TOKEN`. It will not work merely by extracting the downloaded ZIP on your PC. Local builds should use `package.cmd` / `package.ps1` from the bundle instead.

The packager omits tests, install scripts, and promotional project icon (but preserves `Media/Icon.tga`). It does not bundle ForeverCommsVoice into the Guild or Group standalone release: users must install ForeverCommsVoice separately, and any CurseForge project metadata must declare it as a dependency. Set any optional CurseForge/Wago/WoWInterface tokens and real project IDs yourself; none are bundled or presumed. WoW Forever's custom interface ID `16001` may not be recognized by third-party publishing providers, and should be tested before public upload.

## Release checks

1. Confirm that `.toc` versions match the intended release names (scripts read these automatically).
2. Run the offline Lua tests with `texlua` in the respective addon directories, and package smoke tests in `tools/verify_package.py`.
3. Test individual installs and bundle installs on Windows, including backup/rollback, and the new addon icons with a full WoW restart.
4. In-game verify GuildComms Settings > Restore Defaults leaves `/fcv` language and accents unchanged, and expressive terminal periods change to exclamation marks for built-in, accented guild messages.

All three addons share the same per-character voice SavedVariables. This shared file lives under the WoW WTF SavedVariables path and is never copied over by an installer.
