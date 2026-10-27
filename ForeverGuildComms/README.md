# Forever Guild Comms 0.7.1-beta

WoW: Forever 1.60.1 / Interface 16001 addon by Michael Reilly.
Requires **ForeverCommsVoice**, which is bundled with every download.

### Maintenance fixes in 0.4.3-beta

- Fixed the login-time Guild Tabard reminder ordering: a `PLAYER_ENTERING_WORLD` zone check no longer masks the later initial check. Reminders are displayed at most once per city visit.
- Prunes the transient `A.eventsSeen` duplicate-suppression cache after the maximum supported cooldown (3600 seconds), using a sweep throttled to once per minute on activity and a 5-minute idle timer.
- Added `tests/tabard_dedup.lua` to reproduce the timing race and test reminder deduplication and cache expiration. SavedVariables and user templates are unchanged.

## Keybindings (introduced in v0.4.1-beta)

Open **Options → Key Bindings → AddOns → Forever Guild Comms** and assign any keys you prefer. No key combinations are reserved or assigned by default.

- **Open guild alerts** shows the private guild alert window (the same action as TitanPanel Quick actions → Show private alerts or `/fgc alerts`).
- **Ask guild for help** opens the editable request composer. The shortcut **never sends a guild message**. You still press Send yourself.
- **Rescan open profession** refreshes the learned-recipe cache for the profession window currently open. If no profession is open, it displays a reminder instead.

These three bindings use WoW's standard `Bindings.xml`, which is **automatically loaded from the addon root and deliberately not included in the TOC**. The integrated Windows installer explicitly copies `Bindings.xml` along with the files listed in the TOC. BigWigsMods/packager includes it in its addon release. You must restart/reload the client after installing to register the new keybinding commands; a full restart may be required for the Key Bindings panel to display them.

All three actions remain available through TitanPanel and their existing slash-command paths. Existing character keybinding choices are managed by WoW, not by the addon's SavedVariables.

## Install (integrated Windows installer)

1. **Extract All** from the downloaded ZIP into any convenient folder. Do not launch scripts directly from inside a compressed ZIP. Every download includes `ForeverCommsVoice` alongside this addon.
2. Open **`ForeverGuildComms\install`** and double-click **`Install-ForeverGuildComms.cmd`**. Installation instructions are in `ForeverGuildComms\install\INSTALL-README.txt`.
3. Choose your WoW Forever client folder if it is not found automatically. You can supply the client (`_classic_beta_`), `Interface`, or `Interface\AddOns` directory.
4. Restart WoW Forever or enter `/reload`, then open **Settings > AddOns > Forever Guild Comms** (or `/fgc options`).
5. If Titan Panel is installed, enable the **Guild Comms** Data Broker plugin.

The integrated installer reads `ForeverGuildComms.toc` and copies **only the `.toc`, loadable Lua files, the separately auto-loaded `Bindings.xml`, and `Media/Icon.tga`**. Files that are already identical are skipped. It never copies the README, tests, or `install` directory into the AddOns folder, and it does not replace your entire addon directory. Before overwriting addon files, it backs up those specific previous files to `Interface\AddOnBackups`. It leaves all character settings and SavedVariables untouched.

**Manual installation:** Copy the `ForeverGuildComms` subfolder from the extracted archive into `World of Warcraft\_classic_beta_\Interface\AddOns\`. The required folder is `AddOns\ForeverGuildComms\ForeverGuildComms.toc`. Manual copying also copies the included documentation, tests and `install` folder unless you omit them yourself; neither is loaded by WoW.

## BigWigsMods/packager releases

This source archive now contains `.pkgmeta` and `.github/workflows/package.yml`
for automatic packaging from GitHub tags. The BigWigs packager recognises
Forever (`## Interface: 16001`) without manually overriding the game type.
For CurseForge-style distribution, its release ZIP excludes `install/`,
`tests/`, the promotional `Media/ProjectIcon.png` and other repository-only files, while retaining the in-game `Media/Icon.tga` and `Bindings.xml`. **This manual ZIP still includes
the integrated Windows installer.**

To set up your own GitHub repository and publish releases, follow
[`PACKAGING.md`](PACKAGING.md). The workflow requires you to push the
extracted addon's **contents** as the repository root; it does not publish
until you push an annotated version tag. No publishing accounts or project
IDs are configured automatically.

## Addon icon

The addon now has a custom blue-and-gold guild communications emblem. The in-game texture `Media/Icon.tga` is used by the **TitanPanel Data Broker icon**, **Settings header** and **AddOns list** (on clients supporting `IconTexture` metadata). The separate 512 × 512 PNG `Media/ProjectIcon.png` is included for GitHub, CurseForge or other project pages; it is not required by WoW and is intentionally excluded from BigWigs release ZIPs. The integrated Windows installer copies the `.tga` texture, but not the promotional `.png`.

## Features

- **Login greetings:** detects an existing guild member changing from offline to online after roster initialization.
- **New member welcomes:** localized system guild-join text with duplicate protection.
- **Level congratulations:** detects increases in guild roster level for *other* guildmates while online; filters both character name and GUID to exclude you. There is *no* congratulations message for your own level-up.
- **Automatic or Verify before Sending:** in Settings choose **Automatic** (default, same behavior as v0.1.0) or **Verify with a click**. Verify puts login greetings, new-member welcomes and level-up congratulations into a private popup. Each row shows the message and has **Send** and **Dismiss** buttons; the popup can be reopened with `/fgc verify` or through Titan Panel. There is no automatic posting while Verify is enabled.
- **Message timing controls:** Settings has independent numeric fields for **Automatic message spacing** (3–120 seconds, default 6) and **Login greeting cooldown** (0–3600 seconds, default 300; 0 disables repeat-login cooldown). Both are saved, clamped to supported limits, and have a **Use default** button. Automatic spacing applies to queued automatic greetings, not explicitly approved messages.
- **Varied built-in messages (v0.4.2-beta):** enable **Vary built-in message wording** (on by default) under Settings → Outgoing guild messages, or TitanPanel → Outgoing guild messages. Login greetings, new-member welcomes, level-up congratulations and Ask for Help now choose from multiple complete localized/RP-styled formats. Shuffle bags use each available format before repeating and avoid consecutive duplicates across reshuffles. Your chosen language and accent are preserved, and Verify shows the exact text before it is sent. Custom-authored templates are deliberately not randomized.
- **Custom messages:** edit the login, join, level and manual group-request templates in Settings. The default text is filled into each edit field for new installations and displayed below it, with a **Use default** button per template. Existing nonempty customizations are preserved when updating.
- **Languages and race-flavoured accents (new in v0.4.0):** choose from eight human languages (English, Spanish, French, German, Italian, Portuguese, Polish, Dutch), curated regional human accents and RP-inspired WoW race styles. Settings → Languages & accents and TitanPanel → Languages & accents both modify *per-character* preferences. Optional race filtering uses `UnitRace("player")` and recognises supported races (including the Skyborne name when reported by the client). Accent strength offers Subtle, Moderate and Expressive. Default is English with **no accent**, so upgrading does not suddenly change what you post. Only built-in addon-generated messages are localized; see the notes below.
- **Crafting request alerts:** cache the recipes you know by opening each crafting profession, then watch guild chat for explicit requests matching a learned recipe or output name. The cache is stored per character.
- **LFG alerts:** watches guild chat for LFG, LFM, LF, and other group requests. A private alert allows you to start a whisper.
- **Tabard reminders:** asks when entering a major city without the original Guild Tabard item (5976) equipped, and optionally asks on leaving if it is equipped. **Never swaps gear automatically.** The login-time check is independent of earlier zone checks; only one city reminder appears per uninterrupted city stay.
- **Ask for Help:** a compose window to send an explicit guild request: choose Dungeon/Raid/Quest, enter an activity, select which class-appropriate roles you can fill and which roles you need.
- **Titan Panel:** optional LibDataBroker indicator showing online count, alerts and messages awaiting review. Left-click = review if messages are pending (otherwise alerts); Shift-left-click = ask for help; **right-click = nested Guild Comms menu**. No Titan-specific library needs to be bundled. Settings remains usable without Titan.

## Titan Panel nested menu

**Right-click Guild Comms on the Titan bar** to open the nested menu:

- **Enable addon:** on/off checkbox.
- **Outgoing guild messages:** Automatic / Verify with a click radio modes; individual login / new-member / level-up controls; **Vary built-in message wording** on/off; **Automatic message spacing** presets (3, 6, 10, 15, 30, 60, 120 seconds) and **Login greeting cooldown** presets (0, 60, 300, 600, 900, 1800, 3600 seconds). Each timing submenu has **Reset to default**.
- **Private guild requests:** crafting-request and group-request detection, plus alert sounds.
- **Languages & accents:** per-character language, optional race filter, accent/style and strength selectors. All changes sync to the Settings page. The selector shows compatible accents for the currently selected language and race filter.
- **Guild tabard:** the two independent city/exit reminders.
- **Quick actions:** review pending messages, view alerts, ask for help, rescan your currently open profession.
- **Edit custom messages in Settings...:** opens the full Settings page and scrolls to the message editor; **custom text is never edited inside the Titan menu**.
- **Open full Settings...:** opens the normal addon Settings page.

Titan menu and Settings page use the same saved variables and a shared update function. A menu change immediately refreshes existing Settings controls; reopening the menu reflects any Settings changes. Exact custom timing values (such as 17 or 480 seconds) are still editable in Settings and are **not** reset when the Titan menu is opened. Choosing one of the Titan presets changes only the selected timing setting.

Previously queued Verify messages **remain in the review list** if you switch back to Automatic. This behaviour has not changed. If Blizzard's `MenuUtil` context menus are unavailable, right-click falls back to opening the normal Settings page.

## Built-in message variety (v0.4.2-beta)

Enable **Vary built-in message wording** in Settings → Outgoing guild messages or TitanPanel → Outgoing guild messages. Default: **on**. Setting it off reproduces the original single-template behaviour.

> **Note on upgrading.** This is the one setting in the addon whose default *changes what you already post*. Every other optional feature defaults to preserving existing behaviour — `outgoingMode` stays `automatic`, `accent` stays `none` — but because `randomizeMessages` is on by default, greetings that previously used one fixed sentence begin rotating through the curated variants after you upgrade. The wording still honours your chosen language and accent, and your own edited templates are never varied. If you had settled on specific wording, turn this off to restore it.

- Neutral English has four variants for each outgoing message type (one original + three alternatives). Other supported neutral languages have three each.
- Every supported accent and race style has at least two curated message versions for each type; several popular voices have three.
- Each language/accent and message type uses a session-local shuffle bag. The addon does not repeat the same template until every choice in that bag has been used, and avoids the same template immediately before/after a reshuffle.
- Editing any **Custom Messages** field opts that particular message type out of variants, translation and accents, exactly as before. Select **Use default** on that field to re-enable built-in variants.
- The Ask for Help composer locks a random choice to the current draft so preview refreshes do not alter the message. Changing the activity, roles or language creates an updated draft; reopening the composer starts a fresh selection.
- Nothing is added to guild chat without using the existing Automatic queue, Verify button or explicit Send button. Normal manually typed chat is never touched.

## Languages & accents (v0.4.0-beta)

The built-in login, join, level-up and Ask for Help messages use **curated offline translations**, not a general-purpose translation API. All formatting occurs **before** staging a message for click-to-verify, so the review window contains exactly what will be sent. Existing staged messages stay as they were when created, even if you change language or accent later.

- **Human languages:** English, Spanish, French, German, Italian, Portuguese, Polish and Dutch.
- **Human/regional styles:** Australian, British, American, Scottish-inspired, Irish-inspired, Canadian, New Zealand, South African, Mexican Spanish, Cuban Spanish, Spain Spanish, Québécois French, Bavarian-inspired German, Brazilian and European Portuguese, and Southern Italian-inspired.
- **WoW RP styles:** Khaz Modan / Wildhammer / Dark Iron Dwarf, Gnomeregan, Kaldorei, Orcish, Darkspear Troll, Mulgore Tauren, Forsaken, Skyborne, Goblin, Sin'dorei and Draenei. These are invented English-language RP phrasebooks, *not* Blizzard's in-game racial languages.
- **Race filter:** ON by default. Only suggests accents appropriate to your character's `UnitRace`; turn it off to use other races' styles. On a client race we don't recognise, **Auto** falls back to neutral messages.
- **Strength:** **Subtle (wording only)** uses the accent's phrasebook and adds **nothing** in front of the message — it is the accent's own sentences, not a decorated version of the neutral ones. **Moderate (adds a catchphrase)** prefixes the racial or regional interjection, for example `By the forge! `. **Expressive (catchphrase + emphasis)** does the same and then amplifies the closing punctuation, turning a final `.` into `!` and a final `!` into `!!`. Help requests stay concise and keep `[LFG]` at the front in every mode. This setting is **shared with ForeverGroupComms**, where it also affects group greetings, welcomes and level congratulations — but no dungeon or combat directive. The full table is in the accent strength section of the [ForeverCommsVoice README](../ForeverCommsVoice/README.md).
- **Custom messages:** existing user-edited templates always override built-in translations and accents **without being modified**. Reset a field to the exact built-in default to enable localized phrases for that message again. This protects intentional wording, `{variables}`, names, and WoW hyperlinks.
- **Per-character:** preferences are in `ForeverGuildCommsCharDB`; guild-wide on/off controls and existing templates still use the previous saved settings.
- **No guild-chat rewriting:** manually typed chat and other addons' messages are completely untouched. A future opt-in feature could add typed-chat transformations separately without changing this module's scope.

Translation here applies to addon *outgoing* messages only. It does not translate replies, guildmates' messages, or Blizzard's actual in-game language mechanics. RP accent text is stylized writing, not speech/audio synthesis. Non-English language settings with an incompatible race accent fall back to the translated neutral variant.

## Commands

- `/fgc` or `/fgc alerts` : private alert inbox.
- `/fgc request` : compose a group/quest/raid request.
- `/fgc options` : Settings addon page.
- `/fgc verify` or `/fgc review` : open the pending outgoing-message review window.
- `/fgc status` : guild roster statistics.
- `/fgc recipes` : number of known recipe names cached.
- `/fgc clearrecipes` : remove cached recipes (use after unlearning a profession).

## Timing settings

- `messageSpacing` is the minimum number of seconds between **automatic** guild-chat sends, default **6**. It does not delay a user-confirmed **Send** click.
- `loginCooldown` is the number of seconds between repeated login greetings **to the same guildmate**, default **300** (5 minutes). Set to **0** to allow repeat greetings on every detected offline-to-online transition.
- Both settings are configurable in the AddOns Settings page and persist across reloads; old invalid SavedVariables are normalized automatically. The unused `A.lastMessages` field has been removed; `A.eventsSeen` remains responsible for duplicate suppression. Deduplication timestamps are pruned after the maximum configured cooldown (60-minute retention), via an activity-triggered sweep at most once per minute and an idle-session sweep every five minutes.

## Automatic versus Verify mode

- **Automatic** is the default for existing installs; greetings, welcomes, and congratulations continue to post without interaction. Auto sends are spaced apart using the existing queue.
- **Verify with a click** keeps outgoing event messages in a *private* review window. Nothing posts to guild chat until you click the **Send** button for that specific message. Click **Dismiss** to discard it or **Dismiss all** to clear the review list. The popup appears as new review items are created.
- Switching **Verify** back to **Automatic** does not send older pending items; they must still be manually approved or dismissed. Conversely, changing from Automatic to Verify before a queued message is sent moves it to review rather than auto-posting it.
- The review window holds up to 30 items. It clears pending messages if you leave or switch guilds; old messages cannot be approved into another guild. Disabling the addon or leaving guild prevents sending.
- Crafting and LFG alerts are private and unaffected by this setting. Manual help requests already have their own explicit **Send to Guild** button.

## Templates

- Login: `Welcome back, {name}!`
- New guild member: `Welcome to the guild, {name}!`
- Level-up: `Congratulations on level {level}, {name}!`
- Help: `[LFG] {type}: {activity}. I can fill: {myroles}. Looking for: {needed}. Whisper me!`

## Limitations and testing notes

- **Beta / in-game testing required.** Source is written against documented Forever 1.60.1 API, but not run in a real client. Blizzard can adjust APIs during beta.
- Guild roster updates are not a guaranteed instantaneous level-up feed. Updates may be delayed or missed if someone levels when their roster entry is not observed as online. The addon polls no more than once per minute.
- Initial guild roster is treated as a baseline: it never sends messages for everyone already online on login or `/reload`. Very early transitions while initializing may be missed on purpose rather than risk spam.
- Guild welcomes require Blizzard's localized guild-join system message; automatically posted greetings are rate-limited. Messages sent via deliberate Send clicks are not delayed.
- Craft alerts are *not* a guaranteed craftability promise: recipe matching checks what you have learned, not whether you currently have materials, tools or sufficient bag space. You must open your tradeskill panels once after installing; if you unlearn a profession, `/fgc clearrecipes` and rescan to remove stale recipes.
- The recipe cache is keyed by profession name, which the addon reads through `C_TradeSkillUI.GetProfessionChildSkillLineID` and `GetProfessionInfoBySkillLineID`. If this beta client does not expose those, every scan falls back to a single bucket named `Current Profession`, so opening a second profession **overwrites** the first instead of adding to it. `/fgc recipes` reports the cached total, so a count that drops after opening another profession is the symptom. Workaround: reopen the profession you want matched most, or `/fgc clearrecipes` and rescan.
- Group-alert matching is text-based and may pick up ambiguous `LF` messages. It only scans **guild chat** and never automatically whispers.
- Tabard detection currently checks the original Guild Tabard item ID (5976) and a set of capital city maps/English zone names. Other tabard items and localized capitals can be added in a later revision.
- Titan integration uses Titan Panel's embedded LibDataBroker library; if no broker is detected, the addon remains functional without the Titan button. Its right-click menu uses Blizzard `MenuUtil` (expected in the Forever client); if the API is missing, right-click opens the Settings page instead. In-game testing on your particular Titan/Forever combination is still necessary.
- Character role defaults use traditional Vanilla-capable classes, and are selectable in the request window. Roles are labels for communication; the addon does not attempt to inspect your spec.

## Suggested test sequence

1. Set **Verify with a click** while setting up, customize templates, and then enable greetings one at a time.
2. Have another guild member log in; verify a greeting appears in your private review window, then click Send or Dismiss. Nothing should post before clicking Send.
3. Have a member join; check for one welcome in review. Try the Use default button in Settings if you changed a message.
4. Have another member level while online; verify one congratulations. Level yourself and verify **nothing** is sent.
5. Open Tailoring and Enchanting (or your professions), type `/fgc recipes`; ask a guildmate to request a *known output* by name.
6. Have another member write `LFG Deadmines` or `LF healer for quest`; verify the private alert and Whisper button.
7. Request help using `/fgc request` and examine the preview before clicking Send.
8. Move into and out of a capital city with the original Guild Tabard to check the prompts; turn exit reminders on in Settings.
9. Install Titan Panel and select Guild Comms in Titan configuration; verify left-click opens pending messages and shift-left-click opens Ask for Help. Right-click the Titan bar item, explore each nested submenu, toggle greetings, select Verify, change the spacing and cooldown presets and confirm Settings reflects them. Check the custom-message shortcut scrolls to the text fields.
10. Change back to Automatic and confirm future messages send without a click while *previously pending* messages do not auto-send.
11. Under Languages & accents, try Spanish, then Spanish with a Mexican regional style on a Human, and a Dwarf RP accent on a Dwarf. Confirm that the review window and Ask for Help preview show exactly the selected wording. Ensure custom messages and manually typed chat remain unchanged.
12. Enable **Vary built-in message wording**, trigger several greetings or congratulations and check that the wording rotates without repeated formats until the available bank is exhausted. Confirm the Ask for Help preview matches what is sent. Disable it to restore the original fixed messages.

## Build and tests

Run the whole bundle's suite from the repository root with `python tools/run_tests.py`
(or `run-tests.cmd` on Windows), which discovers every harness across all three addons.
To run just this package's, from `ForeverGuildComms`: `lua5.1 tests/syntax.lua` and then
any of `smoke`, `settings`, `verify`, `timing`, `titanmenu`, `roster`, `alertsui`,
`variations`, `voice`, `tabard_dedup`, `keybindings` and `icon`. Several of them load the
sibling `ForeverCommsVoice` source, so keep the three folders together.

Coverage includes the roster diff and self-exclusion rules, the suspicious-roster-read
guard, the approval flow and its backlog cap, the alerts window paging, the Titan menu
hierarchy, and a mocked Blizzard menu and Data Broker frame. These tests **do not replace
in-game testing** — nothing in this bundle has been run against a live server.

## Feedback and debugging

Enable Lua errors in game with `/console scriptErrors 1`, then `/reload`. If any feature fails, capture the exact Lua error, what event occurred and the client build from `/dump select(4, GetBuildInfo())`.

## Shared language/voice engine (0.5.0-beta)

**Requires ForeverCommsVoice 0.7.1-beta.** `VoiceBridge.lua` now delegates all languages, accents, race filters, message variation and shared character settings to `ForeverCommsVoice`, instead of maintaining four duplicated runtime modules. All guild custom templates are retained, always take precedence over translations and do not modify item links or player names. Existing per-character voice settings migrate once into `ForeverCommsVoiceCharDB.voice` when the new GuildComms loads. Set up the shared voice with `/fcv`; the existing GuildComms Settings and Titan voice controls continue to edit the same settings.

For the first upgrade, install the three-addon **ForeverComms bundle** or at least install ForeverCommsVoice before updating GuildComms. The updated GuildComms will not load without its dependency. Continue to use `/fgc` for guild functionality.

## Shared review queue (v0.6.1-beta)

**Verify with a click** now stages guild greetings and congratulations in ForeverCommsVoice's shared review list, alongside GroupComms messages. The old Guild-only approval frame has been removed. Use `/fgc verify` or `/fcv queue` to open it. Source column, visible rows, timeouts and auto-open are controlled under `/fcv`. A timeout only skips a message. `Restore Defaults` still does **not** modify the shared voice/queue profile.

## What changed in 0.7.1-beta

**Requires ForeverCommsVoice 0.7.1-beta.**

**A packaging fix. Nothing in this addon changed** — every file the game loads is
identical to 0.7.0-beta. No setting, message, window, command or keybinding differs, and
no saved settings are renamed or removed.

The release archive is now explicitly restricted to the three addon folders, so project
files that have no business in a download cannot be swept in by the packager. Updating
from 0.7.0-beta is optional and safe.

## What changed in 0.7.0-beta

**Requires ForeverCommsVoice 0.7.1-beta**, which is the same number as this addon --
see below.

**Nothing in the addon changed.** Every file the game loads is identical to 0.6.4-beta
apart from the version number, so if you already run 0.6.4-beta, updating gains you
nothing but matching numbers. No setting, message, window, command or keybinding differs,
and no saved settings are renamed or removed.

**The three addons now share one version number.** They were numbered separately, which
had reached ForeverCommsVoice 0.2.3-beta, this addon 0.6.4-beta and ForeverGroupComms
0.3.5-beta. Since all three are built, tested and installed together, three numbers made
"which version do I have?" harder to answer than it needed to be. The minor bump to 0.7.0
marks that change rather than any new feature.

**One real fix, invisible from inside the game.** The automated build installed the Lua
linter under the wrong package name, so the checks meant to gate a release could not run
for 0.6.4-beta. Corrected; this is the first release built with them passing.

There is no 0.6.5-beta. It existed briefly for the build fix above but was never
published, so its notes are folded into this entry rather than describing a version
nobody could download.

## What changed in 0.6.4-beta

**Requires ForeverCommsVoice 0.7.1-beta.**

Internal maintenance only. **No setting, message or keybinding changes**, and the Ask for
Help window looks and behaves exactly as before.

**Internal: the Ask for Help activity type is now addon state rather than window state.**
The Dungeon/Raid/Quest selection was held inside the window-building code, which meant it
could only be read once that window existed and could not be exercised by the offline
test suite. It now lives with the addon's other settings state, and the cycling behaviour
of that button is covered by tests for the first time.

## What changed in 0.6.3-beta

**Requires ForeverCommsVoice 0.7.1-beta.**

**New setting: "Open the review list when a message is staged."** On by default, which
keeps the existing behaviour. Turn it off if the review list popping up during a busy
login is intrusive; you can still reach it with `/fgc verify` at any time. When
ForeverCommsVoice's shared queue is installed it uses its own auto-open setting under
`/fcv` instead, so this toggle governs the fallback window only.

**New: a short pause between approved messages.** Clicking Send through a backlog used
to post several lines to guild chat in the same instant. Approvals are now spaced at
least two seconds apart; a click that arrives too soon prints a short wait notice and
**leaves the message queued**, so you simply click again. This affects how quickly
consecutive approvals go out, not whether they go out.

**Fixed: Restore Defaults no longer re-enables unattended posting.** It used to reset the
outgoing mode back to Automatic. If you had deliberately chosen **Verify with a click**,
restoring defaults silently returned you to posting to guild chat without confirmation.
Your outgoing mode is now preserved. Restore Defaults also leaves the shared language and
accent alone, since those are shared with Group Comms.

**Clearer accent strength labels**, matching ForeverCommsVoice: **Subtle (wording only)**,
**Moderate (adds a catchphrase)**, **Expressive (catchphrase + emphasis)**. Wording is
unchanged; see the ForeverCommsVoice README for exactly which messages each level affects.
