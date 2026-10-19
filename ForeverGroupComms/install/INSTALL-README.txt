FOREVER GROUP COMMS 0.1.0-beta - WINDOWS INSTALLER

1. Extract the ZIP using "Extract All".
2. Open the ForeverGroupComms\install folder.
3. Double-click Install-ForeverGroupComms.cmd.
4. Choose your WoW Forever _classic_beta_ game folder if prompted.
5. Use /reload in game and type /fgp.

The installer copies the TOC, loadable Lua files and Bindings.xml into
Interface\AddOns\ForeverGroupComms. It backs up replaced files under
Interface\AddOnBackups and leaves other addons and SavedVariables alone.

The CMD file runs PowerShell for this process only, without changing the
machine's permanent execution policy. In managed environments that disallow
such execution, use manual installation instead.

MANUAL: Copy the entire ForeverGroupComms folder to your WoW Forever
_classic_beta_\Interface\AddOns folder. Restart or /reload.
