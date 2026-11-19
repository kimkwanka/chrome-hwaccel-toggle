# Browser Hardware Acceleration Toggle (Chrome and Brave)

One click (or Alt+Shift+H) turns the browser's "Use graphics acceleration when available" on or off and restarts it with your windows restored.

## Why a native helper?
No extension API can change this setting. It is stored in the browser's `Local State` file
(Chrome: `%LOCALAPPDATA%\Google\Chrome\User Data\Local State`,
Brave: `%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Local State`) and the browser rewrites that file on exit.
So the extension asks a small local helper (native messaging) to wait until the browser has fully exited,
edit `Local State`, and relaunch it with `--restore-last-session`.

## Install (Windows 11, Windows PowerShell 5.1, no admin)
1. `powershell -ExecutionPolicy Bypass -File install.ps1` creates the signing key on first run, writes two host manifests, registers them under `HKCU`, and prints the extension ID.
   - Chrome uses `HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.local.hwaccel_toggle` (launcher `hwaccel_host.bat`).
   - Brave uses its own key, `HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.local.hwaccel_toggle` (launcher `hwaccel_host_brave.bat`, which sets `HWACCEL_BROWSER=brave`).
   - Both are always registered; the one for a browser you don't have is harmless.
2. Chrome: open `chrome://extensions`. Brave: open `brave://extensions`. Enable Developer mode, click **Load unpacked**, select the `extension` folder.
3. Check the ID shown there matches the one printed by the installer (same ID in both browsers).
4. Optional: set the shortcut at `chrome://extensions/shortcuts` or `brave://extensions/shortcuts` (suggested Alt+Shift+H).

## Use
Click the toolbar icon. The popup shows the browser, the saved setting, what is actually running (WebGL renderer; SwiftShader / Microsoft Basic Render means software rendering), and a button to switch. All windows close, the setting is changed, and the browser reopens.
Verify at `chrome://gpu` or `brave://gpu` ("Graphics Feature Status": Software only = off).

## Uninstall
`powershell -ExecutionPolicy Bypass -File uninstall.ps1` (removes both registry keys and both manifests), then remove the extension in `chrome://extensions` / `brave://extensions`.

## Caveats
- Restarting closes every window of that browser; they are restored on relaunch (`--restore-last-session`).
- If "Continue running background apps when the browser is closed" is on (Chrome and Brave both have it), the browser may keep running. The helper waits ~20 s, then tries a graceful `taskkill /IM <browser>.exe` (never `/F`) for ~10 s, and gives up without editing if it is still running.
- Before editing, `Local State` is copied to `Local State.hwaccel.bak` (same folder). The result is validated as JSON; on any failure the backup is restored.
- Log: `%LOCALAPPDATA%\hwaccel_toggle\log.txt`.
- Keep `extension.key.xml` private (gitignored); it keeps the extension ID stable. If deleted, a new ID is generated on the next `install.ps1`, so re-run it.
- Tests: set `HWACCEL_LOCAL_STATE` to a sample file and `HWACCEL_DRYRUN=1` (or `apply`) to exercise the host without touching a browser; `install.ps1 -SkipRegistry` only generates the manifests.
