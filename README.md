# universal-clipboard-autosave

Automatically saves images that arrive on the macOS clipboard — most usefully
those sent from an iPhone/iPad via **Universal Clipboard** (Handoff) — as PNG
files into a folder of your choice.

Copy a screenshot on your iPhone, and a second later it is a file on your Mac.

## How it works

A tiny Swift daemon watches `NSPasteboard.changeCount` every 0.2 s (managed by
`launchd` with `KeepAlive`). When the clipboard changes and contains an image:

- **Saves** it as `clipboard_YYYYMMDD_HHMMSS.png` into the save folder
- **Skips** it when the clipboard also carries a file URL — the image already
  exists on disk (e.g. CleanShot X and similar tools save the file themselves
  and copy it), so no duplicate is created
- **Deduplicates** by SHA-256: copying the same image twice saves it once
- Tags the file with `kMDItemIsScreenCapture` so macOS treats it as a
  screenshot, and refreshes the Spotlight index

Images that exist only in the clipboard (Universal Clipboard, "Copy Image"
in a browser, screenshot-to-clipboard) are saved; images that are already
files on disk are left alone.

By default images are saved to `~/Downloads`. Override the destination with
the `CLIPBOARD_AUTOSAVE_DIR` environment variable — no need to edit the
source.

## Install

1. Compile:

   ```sh
   swiftc -O -o clipboard-image-auto-save clipboard-image-auto-save.swift
   ```

2. Edit `com.noki.clipboard-image-auto-save.plist` so `ProgramArguments`
   points at the compiled binary. Optionally set `CLIPBOARD_AUTOSAVE_DIR` in
   an `EnvironmentVariables` dict to save somewhere other than `~/Downloads`:

   ```xml
   <key>EnvironmentVariables</key>
   <dict>
     <key>CLIPBOARD_AUTOSAVE_DIR</key>
     <string>/Users/you/Pictures/ClipboardSaves</string>
   </dict>
   ```

3. Install and load it:

   ```sh
   cp com.noki.clipboard-image-auto-save.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.noki.clipboard-image-auto-save.plist
   ```

Logs go to `/tmp/clipboard-image-auto-save.log` / `.error.log`.

## Uninstall

```sh
launchctl unload ~/Library/LaunchAgents/com.noki.clipboard-image-auto-save.plist
rm ~/Library/LaunchAgents/com.noki.clipboard-image-auto-save.plist
```
