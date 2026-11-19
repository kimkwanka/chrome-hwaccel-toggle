# Chrome Hardware Acceleration Toggle

One click (or Alt+Shift+H) turns Chrome's "Use graphics acceleration when available" on or off and restarts Chrome with your windows restored.

## Why a native helper?
No extension API can change this setting. It is stored in Chrome's `Local State` file
(`%LOCALAPPDATA%\Google\Chrome\User Data\Local State`) and Chrome rewrites that file on exit.
So the extension asks a small local helper (Chrome native messaging) to wait until Chrome has fully exited,
edit `Local State`, and relaunch Chrome with `--restore-last-session`.

## Install (Windows 11, Windows PowerShell 5.1, no admin)
1. `powershell -ExecutionPolicy Bypass -File install.ps1` — creates the signing key on first run, writes the host manifest, registers it under `HKCU`, and prints the extension ID.
2. Open `chrome://extensions`, enable Developer mode, click **Load unpacked**, select the `extension` folder.
3. Check the ID shown there matches the one printed by the installer.
4. Optional: set the shortcut at `chrome://extensions/shortcuts` (suggested Alt+Shift+H).

## Use
Click the toolbar icon. The popup shows the saved setting, what is actually running (WebGL renderer; SwiftShader / Microsoft Basic Render means software rendering), and a button to switch. All windows close, the setting is changed, and Chrome reopens.
Verify at `chrome://gpu` ("Graphics Feature Status": Software only = off).

## Uninstall
`powershell -ExecutionPolicy Bypass -File uninstall.ps1`, then remove the extension in `chrome://extensions`.

## Caveats
- Restarting closes every Chrome window; they are restored on relaunch (`--restore-last-session`).
- If "Continue running background apps when Google Chrome is closed" is on, Chrome may keep running. The helper waits ~20 s, then tries a graceful `taskkill /IM chrome.exe` (never `/F`) for ~10 s, and gives up without editing if Chrome is still running.
- Before editing, `Local State` is copied to `Local State.hwaccel.bak` (same folder). The result is validated as JSON; on any failure the backup is restored.
- Log: `%LOCALAPPDATA%\hwaccel_toggle\log.txt`.
- Keep `extension.key.xml` private (gitignored); it keeps the extension ID stable. If deleted, a new ID is generated on the next `install.ps1`, so re-run it.
- Tests: set `HWACCEL_LOCAL_STATE` to a sample file and `HWACCEL_DRYRUN=1` (or `apply`) to exercise the host without touching Chrome.
