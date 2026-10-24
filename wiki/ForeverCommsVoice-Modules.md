# ForeverCommsVoice — module reference

**Version 0.2.2-beta.** The shared library. It owns every word the other two addons say,
one per-character language and accent profile, and the message review queue.

> **The library never sends.** It registers no chat event, calls no send function, and
> makes no decision about when a message goes out. It hands text back to whichever addon
> asked for it. That addon decides the rest.

Files load in this order, which is also the order below:

| File | Responsible for |
| --- | --- |
| `Core.lua` | Settings, the render pipeline, the wording-variation shuffle |
| `Languages.lua` | The 8 languages and the guild message translations |
| `Accents.lua` | The 29 accent and roleplay voices |
| `RaceProfiles.lua` | Which accents your race can use, and how "Auto" resolves |
| `MessageVariants.lua` | Alternative wordings for guild messages |
| `GroupPhrases.lua` | All party, dungeon and raid wording |
| `Queue.lua` | The shared click-to-send review list |
| `QueueUI.lua` | The floating review window |
| `Options.lua` | `/fcv`, the Settings panel |

---

## Core.lua

Publishes the addon and holds the per-character profile. Four settings live here:

| Setting | Values | Default |
| --- | --- | --- |
| Message language | one of 8 | English |
| Accent / RP voice | `Auto`, `None`, or one of 29 | None |
| Suggest accents for my race | on / off | on |
| Accent strength | Subtle / Moderate / Expressive | Subtle |

They are saved in `ForeverCommsVoiceCharDB.voice`, **per character**, not per account. An
out-of-range or unrecognised value is corrected to a safe one every time the profile is
read, so a hand-edited or outdated saved-variables file cannot leave the addon in a broken
state.

**Legacy migration.** The first time you log in with the updated Guild Comms, your old
per-character voice settings are copied here once and flagged as migrated. Later logins
never overwrite changes you made in the shared panel. If you never used Guild Comms, the
profile starts from the defaults above.

### How a message is built

1. **Your own template wins.** If you edited that message in Guild Comms' Settings, your
   text is used verbatim — no translation, no accent, no variation, no change to item
   links, player names or `{variables}`.
2. Otherwise the wording for your language is looked up.
3. If an accent is active, it supplies its own sentence (guild messages) or its own list of
   sentences (group messages).
4. If wording variation is on, one candidate is chosen from a shuffle bag.
5. Accent strength is applied, if the message is eligible.
6. `{name}`, `{level}`, `{quest}` and the other placeholders are filled in.
7. The result is clamped to the game's 250-byte chat limit, cutting on a character
   boundary so a translated message never ends in a broken character.

### Wording variation

When **Vary built-in message wording** is on, each language-and-accent combination draws
from a shuffle bag: every available wording is used once before any repeats, and a
reshuffle will not immediately repeat the wording you just saw. The bags are session-local,
so they reset on logout or `/reload`. Preview text does not consume a choice, so the
wording shown in Settings or in the Ask-for-Help window is what gets sent.

### Accent strength

One setting, two effects, and the same rule decides whether either applies.

- **Subtle (wording only)** — the accent's own phrasebook, with nothing added in front.
- **Moderate (adds a catchphrase)** — prefixes the regional or racial interjection, for
  example `By the forge! `.
- **Expressive (catchphrase + emphasis)** — the prefix, and then the closing punctuation is
  amplified: a final `.` becomes `!`, and a final `!` becomes `!!`.

| Scope | Affected | Left exactly neutral |
| --- | --- | --- |
| Guild | every message kind | `help` — keeps `[LFG]` at the front and its original punctuation so it stays scannable |
| Group | `greet`, `welcome`, `level` | every coordination and combat call: `pull`, `mana`, `regroup`, `heal`, `cc`, `skull`, `interrupt`, plus `roles`, `quests` and `request` |

**Group social messages are in scope on purpose.** Expressive changes the punctuation of
your group greetings, welcomes and level congratulations as well as your guild messages.
Dungeon instructions are excluded deliberately: at the same setting,
`Focus skull first, please.` keeps its full stop while
`May the stars guide our group.` becomes `May the stars guide our group!`, because an
instruction has to stay plain to be followed under pressure.

Two details worth knowing:

- Some accents ship **curated group wordings** for `greet` and `level`. Those replace the
  sentence rather than decorating it, so they take no catchphrase prefix — otherwise
  `By the forge! ` would land in front of `By the forge! Good tae see ye all!`. Expressive
  still amplifies their final mark.
- Punctuation is amplified **before** `{name}`, `{level}` and `{quest}` are filled in, so a
  player or quest name is never altered.

---

## Languages.lua

The eight languages and the translated guild templates.

| | |
| --- | --- |
| English | Spanish (Español) |
| French (Français) | German (Deutsch) |
| Italian (Italiano) | Portuguese (Português) |
| Polish (Polski) | Dutch (Nederlands) |

Each language has a translation of the four guild messages — **login greeting**, **new
member welcome**, **level congratulations** and **Ask for Help** — plus translated role
names (Tank / Healer / DPS / Flexible / Any role) and activity types (Dungeon / Raid /
Quest) so the Ask-for-Help message reads correctly in your language.

These are hand-written, curated translations of fixed templates. There is no translation
service involved, nothing is translated at runtime, and nothing you or anyone else types is
ever touched.

---

## Accents.lua

Twenty-nine accent and roleplay voices. Each one carries its own complete wording for the
four guild messages plus a catchphrase used at Moderate and Expressive strength.

**Human and English-speaking regional styles (8):** Australian, British, American,
Scottish-inspired, Irish-inspired, Canadian, New Zealand, South African.

**WoW roleplay voices (13):** Khaz Modan Dwarf, Wildhammer Dwarf, Dark Iron Dwarf,
Gnomeregan Tinker, Kaldorei, Orcish Warrior, Darkspear Troll, Mulgore Tauren, Forsaken,
Skyborne, Goblin Dealer, Sin'dorei, Draenei.

**Regional styles within the translated languages (8):** Mexican Spanish, Cuban Spanish,
Spain Spanish, Québécois French, Bavarian-inspired German, Brazilian Portuguese, Portugal
Portuguese, Southern Italian-inspired.

Each accent belongs to one language, so the accent list you see changes when you change
language. The roleplay voices are invented English-language phrasebooks written for flavour
— they are not Blizzard's in-game racial languages, and the regional styles are stylised
writing, not claims about how anyone really speaks.

---

## RaceProfiles.lua

Decides which accents you are offered and what **Auto** means for you.

- **Suggest accents for my race** (on by default) filters the list to the voices that suit
  your character's race. Turn it off to use any voice in your current language.
- **Auto** picks the first suggested voice for your race. On a race the addon does not
  recognise, Auto falls back to neutral wording rather than guessing.
- Human characters additionally keep the regional non-English styles available, because
  those belong to the translated languages rather than to a race.

Race is read from the client's own race token. The Skyborne race is detected by name when
the client reports it.

This file also supplies the translated role names and activity type names used by the
Ask-for-Help message.

---

## MessageVariants.lua

Alternative wordings for guild messages, used when **Vary built-in message wording** is on.

Neutral English has four wordings per message type; the other seven languages have three
each. Every accent has at least two wordings per type, and several have three. Combined
with the shuffle bag in `Core.lua`, that is what stops your login greetings from reading
like a macro.

---

## GroupPhrases.lua

All party, dungeon and raid wording, in all eight languages, across thirteen message kinds:

| Kind | Used for |
| --- | --- |
| `greet` | greeting a new party |
| `welcome` | welcoming someone who joined mid-run |
| `level` | congratulating a group member's level-up |
| `roles` | the role confirmation call |
| `quests` | the quest-sharing reminder |
| `pull` | next pull |
| `mana` | mana break |
| `regroup` | regroup / stack up |
| `heal` | wait for the healer |
| `cc` | crowd-control the moon target |
| `skull` | focus the skull target |
| `interrupt` | coordinate interrupts |
| `request` | ask someone to share a named quest |

Accents also contribute curated group wordings for the social kinds. This file is where the
library registers its two catalogs, `guild` and `group`, which is what lets one render
pipeline serve two very different kinds of message.

---

## Queue.lua

The shared click-to-send review list. Both applications stage messages here, so there is
one window to watch instead of two.

**What it does.** Holds a message, shows you the exact text that will be sent, and sends it
only when you tick the box. Skipping or letting a message time out never sends anything.

**Settings** (per character, under `/fcv`):

| Setting | Range | Default |
| --- | --- | --- |
| Rows visible | 1–10 | 2 |
| Message source column | Guild / Group text, or source icon | text |
| Auto-skip after | 0–3600 seconds, 0 = never | 20 |
| Open queue when a message is added | on / off | on |
| Window position | — | centre |

**Rules worth knowing:**

- **A timeout never sends.** The countdown starts when the message is staged, runs even
  while the window is hidden or the row is scrolled out of sight, and silently discards the
  message when it reaches zero. A click that races the expiry loses — an expired message
  cannot be resurrected.
- **Nothing is saved across sessions.** Each entry holds a callback into the addon that
  created it plus the guild or group it was written for, and neither may survive a reload.
  Logging out or reloading discards everything pending. That is deliberate: it means a
  message written for last night's party can never surface in tonight's.
- **A stale entry is skipped, not retargeted.** If you changed guild or the group roster
  changed, the owning addon reports the entry as stale and it is dropped rather than sent
  somewhere it was not meant for.
- **A failed send stays queued.** If the send is refused for a recoverable reason — for
  example the two-second spacing floor — the message stays in the list so you can click
  again.
- The list holds up to 100 entries and drops the oldest when full.

---

## QueueUI.lua

The review window itself: a compact, movable, scrollable overlay rather than a standard
Blizzard panel, so it can sit wherever you want without taking over the screen.

- Drag the title bar to move it; the position is saved per character.
- Scroll with the scrollbar or the mouse wheel. The number of visible rows is a setting;
  the rest scroll.
- Each row shows the source (Guild or Group), what kind of message it is, the full text,
  and a countdown or `No limit`.
- **Tick the checkbox to send.** **Skip** discards that one row. **Skip all** clears the
  whole list. **Settings** opens the Forever Comms Voice panel.
- The header counts what is waiting, broken down by Guild and Group.

Open it with `/fcv queue`, `/fgc verify` or `/fgp queue`.

---

## Options.lua

Registers the **Settings → AddOns → Forever Comms Voice** panel and the slash commands.

| Command | Action |
| --- | --- |
| `/fcv` or `/commsvoice` | open the Settings panel |
| `/fcv queue` or `/fcv review` | open the review window |
| `/fcv clear` | skip everything in the review list |

The panel has the four voice settings, the five queue settings, and a button that opens the
review window. Everything on it applies to the current character only.

The panel is registered as soon as the addon loads, so Forever Comms Voice appears under
Settings → AddOns on a fresh login without your having to type `/fcv` first. (Before
0.2.2-beta it did not, which is why some older notes tell you to run `/fcv` to reach it.)
