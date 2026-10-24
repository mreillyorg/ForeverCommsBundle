FOREVERCOMMSVOICE - WINDOWS INSTALLER
This is the shared library that Forever Guild Comms and Forever Group Comms
both require. It has no dependencies of its own, and installing it on its own
is useful only if you already have one of those addons.
1. Extract ALL files from the ZIP. Do not run installers inside the ZIP.
2. Open ForeverCommsVoice\install.
3. Run Install-ForeverCommsVoice.cmd.
4. Select your WoW Forever client folder if prompted.
5. Restart WoW (required for new addon list icons) and set up /fcv.
Backups are stored in Interface\AddOnBackups, outside AddOns.
SavedVariables are never overwritten. If a source is missing, installation
refuses to modify existing addon directories.
Manual install: copy the ForeverCommsVoice folder into
_classic_beta_\Interface\AddOns. The copied folder must contain the TOC, the
Lua files and Media/Icon.tga, not another nested addon folder.
To install all three addons at once, run install\Install-ForeverComms.cmd
from the top level of the extracted package. That is the recommended route,
because Guild Comms and Group Comms will not load without this library.
