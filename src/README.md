# OneCord Proxy Core

Discord proxy hook (`version.dll` hijack) and C# installer

## Layout

```
src/
  native/       C++20 hook DLL (MinHook + Winsock), optional via -Native
  installer/    C# WinForms installer (.NET 8)
  assets/       onecord.ini, packet template
  dist/         Build output (gitignored)
  package.ps1   Build everything
  build.ps1     Shortcut to package.ps1
```

## Requirements

| Tool | Purpose |
| ---- | ------- |
| .NET 8 SDK | C# installer |
| CMake 3.20+ and MSVC | Optional experimental native `version.dll` (`package.ps1 -Native`) |

Default build patches upstream [discord-drover](https://github.com/hdrover/discord-drover) v0.9 and renames config to `onecord.ini`

## Build

```powershell
cd src
.\package.ps1
```

Optional native DLL:

```powershell
.\package.ps1 -Native
```

Output in `dist/`:

- `Installer.exe`
- `version.dll`
- `onecord.ini`
- `drover-packet.bin`
- `release.zip` (archive of dist contents)

## Manual install

Copy into the Discord `app-*` folder next to `Discord.exe`:

- `version.dll`
- `onecord.ini`
- `drover-packet.bin` (optional UDP prefix)

Or run `dist\Installer.exe` (self-contained; no separate .NET runtime install needed)

## Stack

| Part | Tech |
| ---- | ---- |
| Hook DLL | C++20, MinHook, `version.dll` export forwarding (or patched drover) |
| Installer | C# .NET 8 WinForms |
