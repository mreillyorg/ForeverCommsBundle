# Installation

All three addons target **WoW Forever 1.60.1**, Interface `16001`. Guild Comms and Group
Comms both declare Forever Comms Voice as a **required** dependency and will not load
without it, so install the bundle rather than picking addons individually unless you know
you already have the library.

## Windows installer (recommended)

1. **Extract the whole ZIP** to any convenient folder, keeping the three addon folders and
   the `install` folder together. Do not run scripts from inside a compressed ZIP.
2. Run `install\Install-ForeverComms.cmd`.
3. Choose your WoW Forever folder if it is not detected. You can point at the client folder
   (`_classic_beta_`), at `Interface`, or at `Interface\AddOns`.
4. Restart WoW, or `/reload` if it is already running.
5. Set your shared voice: `/fcv`, or Settings → AddOns → Forever Comms Voice.

### What the installer does and does not do

- Validates every addon's file list **before** touching your installation, and copies only
  the manifest, the loadable Lua files, `Bindings.xml` and the in-game icon. Documentation,
  tests and the installer itself are never copied into `AddOns`.
- Stages everything in a temporary folder first, then swaps it in. If any step fails it
  removes what it installed and restores the previous folders.
- Backs up the addon folders it is about to replace to `Interface\AddOnBackups\`, outside
  `AddOns`, so a backup never shows up as a stray addon.
- **Does not touch your `WTF` folder or any SavedVariables.** Your settings survive.
- Always installs Forever Comms Voice first, and adds it automatically if your selection
  names either of the other two.

The PowerShell script takes `-GamePath`, `-Addons` and `-NonInteractive` if you would
rather drive it directly.

## Manual installation

Copy the **three** addon folders into `_classic_beta_\Interface\AddOns`, so that you end up
with:

```text
Interface\AddOns\ForeverCommsVoice\ForeverCommsVoice.toc
Interface\AddOns\ForeverGuildComms\ForeverGuildComms.toc
Interface\AddOns\ForeverGroupComms\ForeverGroupComms.toc
```

Copying by hand also copies the documentation, tests and `install` folders unless you leave
them out. None of that is loaded by the game.

## After installing

| Step | How |
| --- | --- |
| Set language and accent | `/fcv` |
| Configure guild behaviour | `/fgc options` |
| Configure group behaviour | `/fgp settings` |
| Assign keybindings | Options → Key Bindings → AddOns |
| Enable the Titan indicators | Titan Panel configuration → Guild Comms / Group Comms |

A **full client restart** is needed for new addon metadata and icons, and before new
keybinding commands appear in the Key Bindings panel. `/reload` is enough for Lua changes.

## Updating

Run the installer again, or copy the folders over. Nothing in a saved settings file is
renamed or removed between releases, so your configuration carries forward.

Two things to know about upgrading:

- **Your old Guild Comms voice settings migrate once.** The first login after the upgrade
  copies your language, accent, race filter and strength into the shared profile and marks
  them migrated. Later logins never overwrite changes you make in the shared panel. Your
  account-wide custom message templates are left exactly as they are.
- **`Vary built-in message wording` is on by default**, and it is the one setting whose
  default changes what you already post: greetings that used one fixed sentence begin
  rotating through the curated variants. Your language, accent and your own edited templates
  are unaffected. Turn it off if you had settled on specific wording.

Keep your existing `WTF`/SavedVariables files if you want the option of rolling back. A
normal reinstall does not remove them.

## Settings storage

| File | Scope | Holds |
| --- | --- | --- |
| `ForeverCommsVoiceCharDB` | per character | shared language, accent, race filter, strength; review-queue preferences and window position |
| `ForeverGuildCommsDB` | per account | guild behaviour toggles, timing, custom message templates |
| `ForeverGuildCommsCharDB` | per character | cached recipes, your role selections |
| `ForeverGroupCommsDB` | per account | group behaviour toggles |

Language and accent are a **per-character profile**, not an account-wide synchronised one.
Full details in the [Settings Reference](Settings-Reference).

## Optional: Titan Panel

Both applications offer a LibDataBroker indicator. Titan Panel already embeds the library,
so nothing is bundled and nothing is required — if no data broker is present, the indicators
simply do not appear and everything else works normally. See the Broker and TitanMenu
sections of the [Guild Comms](ForeverGuildComms-Modules#brokerlua) and
[Group Comms](ForeverGroupComms-Modules#brokerlua) module pages.

## Beta caveats

Nothing in this bundle has been run against a live Forever server. The code is written
against the documented 1.60.1 API with feature detection around calls that may be absent,
but a beta client can change. Each addon's README lists what remains unverified, and
[Troubleshooting](Troubleshooting) covers what to capture if something misbehaves.
