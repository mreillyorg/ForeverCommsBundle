# Slash commands and keybindings

## Forever Comms Voice — `/fcv`

Also available as `/commsvoice`.

| Command | Action |
| --- | --- |
| `/fcv` | open Settings → AddOns → Forever Comms Voice |
| `/fcv queue` / `/fcv review` | open the shared message review window |
| `/fcv clear` | skip everything waiting for review, Guild and Group |

## Forever Guild Comms — `/fgc`

Also available as `/guildcomms`.

| Command | Action | Sends to guild chat? |
| --- | --- | --- |
| `/fgc` / `/fgc alerts` | private alert inbox | no |
| `/fgc request` / `/fgc help` | Ask-for-Help composer | only when you press **Send to Guild** |
| `/fgc verify` / `/fgc review` | open the shared review window | only when you tick a row |
| `/fgc options` / `/fgc settings` | Settings page | no |
| `/fgc status` | guild counts, alert and review counts, current outgoing mode | no |
| `/fgc recipes` | how many learned recipe names are cached | no |
| `/fgc clearrecipes` | empty the recipe cache | no |

## Forever Group Comms — `/fgp`

Also available as `/forevergroup`.

| Command | Action | Sends to group chat? |
| --- | --- | --- |
| `/fgp` / `/fgp open` | toggle the group panel | no |
| `/fgp quests` | quest comparison window | no |
| `/fgp queue` / `/fgp review` | open the shared review window | only when you tick a row |
| `/fgp settings` | Settings page | no |
| `/fgp sync` | rebroadcast your active quest IDs to other Group Comms users | addon data only, not chat |
| `/fgp roles` | role check | **yes** |
| `/fgp pull` | next pull | **yes** |
| `/fgp mana` | mana break | **yes** |
| `/fgp regroup` | regroup | **yes** |
| `/fgp heal` | wait for the healer | **yes** |
| `/fgp cc` | crowd-control the moon target | **yes** |
| `/fgp interrupt` | coordinate interrupts | **yes** |
| `/fgp ready` | native ready check — leader or raid assistant | no chat message |
| `/fgp skull` | mark your target with skull — leader or raid assistant | no chat message |
| `/fgp moon` | mark your target with moon — leader or raid assistant | no chat message |

An unrecognised `/fgp` subcommand prints the list.

## Keybindings

Open **Options → Key Bindings → AddOns** and assign whatever keys you prefer. **Nothing is
bound by default** and no combination is reserved.

### Forever Guild Comms

| Binding | Action |
| --- | --- |
| Open guild alerts | shows the private alerts window |
| Ask guild for help | opens the composer — **never sends**; you still press Send |
| Rescan open profession | refreshes the recipe cache for the open profession window |

### Forever Group Comms

| Binding | Action |
| --- | --- |
| Open Group Comms | toggles the group panel |
| Review group roles | **sends** the role-check message to your group |
| Review group quests | opens the quest comparison window |

Both addons load their bindings from a file the game picks up automatically. You must
reload or restart the client after installing for the commands to register, and a full
restart may be needed before they appear in the Key Bindings panel. Your key choices are
stored by WoW, not by the addons.
