---
inclusion: auto
name: ui-frames
description: Frame, widget, and Settings-panel conventions for the Forever Comms bundle. Use when editing any UI.lua or Options.lua in ForeverGuildComms, ForeverGroupComms or ForeverCommsVoice, or when adding windows, buttons, checkboxes, edit boxes, popups, or options controls.
---

# UI and options conventions

All UI in all three packages is built in Lua, at init time, from that package's
`Initialize` → `BuildUI` / `BuildPanel` / `BuildOptions`. There is no XML layout, no
layout library, and no textures beyond GuildComms' `Media/Icon.tga` — Blizzard templates
and manual offsets only.

| Package | Builders | Named frames |
| --- | --- | --- |
| GuildComms | `A:BuildUI` (alerts), `A:BuildApprovalsUI`, `A:BuildRequestUI`, `A:BuildOptions` | `FGCAlertsFrame`, `FGCApprovalsFrame`, `FGCRequestFrame`, `ForeverGuildCommsOptionsPanel` |
| GroupComms | `A:BuildPanel`, `A:BuildQuests`, `A:BuildOptions` | `ForeverGroupCommsPanel`, `ForeverGroupCommsQuests` |
| Voice | `V:BuildOptions` | none — the Settings canvas frame is anonymous |

## Local widget helpers

Each UI file defines its own small constructors near the top and uses them everywhere
instead of repeating `CreateFrame` boilerplate:

- GuildComms `UI.lua`: `Label(parent, text, x, y, width, size)`,
  `Button(parent, text, x, y, width, callback)`,
  `Check(parent, title, x, y, checked, onClick)`
- GuildComms `Options.lua`: `MakeLabel`, `MakeButton`, plus the panel-scoped `section`,
  `toggle`, `voiceToggle`, `voiceCycle`, `timingOption`, `outgoingMode` and `template`
  closures that advance a running `y` cursor
- GroupComms `UI.lua`: `text(parent, label, x, y, width, height, font)`,
  `button(parent, label, x, y, width, height, onClick)`,
  `makeFrame(name, title, w, h)`
- GroupComms `Options.lua`: a declarative `options` table of
  `{key, label, hint}` rows rendered in one loop — prefer extending the table over adding
  bespoke widget code
- Voice `Options.lua`: `label(parent, text, y, template)` and the panel-scoped `cycle`
  closure

Add a new control type by extending these helpers rather than hand-rolling a frame in the
middle of a layout function. Do not copy a helper between packages — each package's set
matches its own layout conventions.

## Templates in use — stay with them

| Need | Template |
| --- | --- |
| Window | `BasicFrameTemplateWithInset` |
| Button | `UIPanelButtonTemplate` |
| Checkbox | `UICheckButtonTemplate` |
| Radio | `UIRadioButtonTemplate` |
| Text input | `InputBoxTemplate` |
| Scrolling options panel | `UIPanelScrollFrameTemplate` + a sized child frame |
| Confirmations | `StaticPopupDialogs` with `timeout = 0`, `whileDead = false`, `hideOnEscape = true`, `preferredIndex = 3` |
| Nested context menu | `MenuUtil.CreateContextMenu` + `CreateTitle` / `CreateButton` / `CreateCheckbox` / `CreateRadio` / `CreateDivider` |

## Layout rules

- Anchor with `SetPoint("TOPLEFT", x, y)` and negative `y`, matching the existing
  coordinate math. Windows use `SetPoint("CENTER")`.
- Font strings: `CreateFontString(nil, "OVERLAY", style)` in the application packages and
  `"ARTWORK"` in the two Settings-only files, with `GameFontNormal`,
  `GameFontNormalLarge`, `GameFontHighlight`, `GameFontNormalSmall`, or
  `GameFontHighlightSmall`; always `SetWidth` and `SetJustifyH("LEFT")`, and
  `SetJustifyV("TOP")` on anything multi-line.
- Windows are movable: `SetMovable(true)`, `EnableMouse(true)`,
  `RegisterForDrag("LeftButton")`, `StartMoving`/`StopMovingOrSizing`, strata `DIALOG`.
  GroupComms additionally sets `SetClampedToScreen(true)` in `makeFrame`; prefer that for
  new windows.
- Build every window hidden (`frame:Hide()`) and show it from a slash command, an options
  button, a keybinding, or the broker click. GuildComms' windows `Show()`; GroupComms'
  `ShowPanel`/`ShowQuests` toggle.
- **Rows are fixed pools of reused frames with paging — never create frames per item.**
  Current pools: GuildComms alerts 7, GuildComms approvals 4, GroupComms suggestions 3,
  GroupComms quest lines 9. Clamp the page to
  `math.max(1, math.ceil(#items / pageSize))` on every refresh.
- In GuildComms' `Options.lua`, let the `section`/`toggle`/`template` closures manage the
  `y` cursor and finish with `content:SetHeight(math.max(1460, -y+80))` so the scroll
  child grows with new controls. Keep `self.messagesScrollY` and
  `self.languagesScrollY` anchored where they are set, since the Titan menu scrolls to
  them.

## Edit box behavior

`SetAutoFocus(false)`, `SetMaxLetters(...)`, commit on `OnEditFocusLost`, clear focus on
`OnEnterPressed`, and revert to the stored value on `OnEscapePressed`. Numeric fields add
`SetNumeric(true)` and route through `A:SetOption` so the timing clamps apply regardless
of which surface edited them. Any edit that feeds a chat template calls
`A:UpdateRequestPreview` so the preview stays truthful.

## Settings registration

Use the modern API: `Settings.RegisterCanvasLayoutCategory` +
`Settings.RegisterAddOnCategory`, storing the category on `self.settingsCategory` for that
package's `OpenSettings` / `OpenOptions`. Guard the whole thing. The three packages
currently differ in how, and that difference is worth knowing:

- **Voice and GroupComms** fall back to `InterfaceOptions_AddCategory`.
- **GuildComms** prints a note and skips registration entirely, so on a client without
  the modern API it has no options page at all.

Prefer the fallback form for new panels.

Canvas callbacks — only GuildComms implements them today, and it is the model to follow
when a panel has state worth syncing:

- `panel.OnRefresh` — push stored values into the controls, via the `controls` closure list
- `panel.OnCommit` — flush edit boxes into the DB
- `panel.OnDefault` — restore defaults, then refresh

### `OnDefault` must not reach outside its own addon's account settings

Restoring defaults is a local action on that package's own behavior settings. It must
**not** silently reset:

- `db.outgoingMode`, which controls whether public messages post without a click
- the shared voice profile, because `A.char.voice` and `ForeverCommsVoiceCharDB.voice` are
  the **same table object** at runtime — writing it from GuildComms changes the language
  and accent GroupComms is using and leaves Voice's own panel stale

Where a shared value genuinely must change, route it through `V:SetOption` so validation
runs once and every open panel refreshes.

GuildComms' `panel.OnDefault` now complies for the shared profile — the voice reset was
removed in 0.5.1 and `ForeverGuildComms/tests/settings.lua` asserts that GroupComms'
rendered output is unchanged across a Restore Defaults. Two smaller deviations remain in
that function: it still resets `outgoingMode` to `automatic`, and it still copies
`A.defaults` only one level deep instead of reusing `fillDefaults`.

## Keeping multiple surfaces in sync

GuildComms has three editors for one settings table — the Settings panel, the Titan
menu, and the slash commands. The rule that makes that safe: **one writer**.

- All behavior settings go through `A:SetOption`, which validates by key class and clamps
  timing values. The Titan menu never edits custom message text; it links to Settings.
- Voice settings go through the shared profile. `V:SetOption` refreshes its own panel and
  probes `_G.ForeverGuildComms` for `RefreshOptions` and `UpdateRequestPreview`.
- After any write that changes displayed state, call that package's refresh —
  `A:RefreshOptions`, `A:UpdateBroker`, `A:RefreshUI`, `A:RefreshQuestUI`,
  `V:RefreshOptions` — rather than relying on the panel being rebuilt.

## Settings write directly to the DB

Toggles assign to `A.db[key]` (via `A:SetOption` where one exists) on click; there is no
apply/cancel buffer. Keep that model, and keep every option's description honest about
what the feature will and will not do — that the tabard reminder never equips anything,
that role alerts never change a role, that quest sync is an opt-in data exchange needing
both sides.

## Preview before send

Any feature that posts to a shared channel from the UI must show the exact text first and
require a deliberate button press:

- GuildComms' composer renders through `A:RequestText` into `A.requestPreview`, and caches
  the draft against a **fingerprint** of every input that affects the wording so Send
  posts exactly what was previewed. Clear the draft on open and after a successful send.
- The Verify window shows the fully formatted text, formatted at stage time, so changing
  language or accent later cannot alter a message already awaiting approval.
- GroupComms' suggestion rows show the description and send on click through `A:Approve`,
  which re-checks `groupSerial` first.
- A Settings-page sample must be a **non-consuming** preview: pass `preview = true` so it
  cannot advance a shuffle bag and change what the next real message says.
