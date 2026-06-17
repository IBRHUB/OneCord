# OneCord

Route Discord desktop traffic through Cloudflare WARP local proxy without sending your whole PC through WARP

## What it does

- Adds NRPT DNS rules so Discord domains resolve via Cloudflare DNS (`1.1.1.1`, `1.0.0.1`)
- Configures WARP local proxy mode on `127.0.0.1:1080`
- Verifies the proxy port is listening before reporting success
- Checks whether the proxy hook is installed in the latest Discord `app-*` folder
- Writes `onecord.ini` with `socks5://127.0.0.1:1080`
- Reports real status instead of claiming success too early

## Requirements

| Requirement | Details |
| ----------- | ------- |
| OS | Windows 10 or 11 |
| PowerShell | 5.1 or newer |
| Privileges | Run as Administrator (needed for DNS NRPT rules) |
| Cloudflare WARP | Installed and registered; `warp-cli` on PATH |
| Discord | Desktop app (stable) |
| Proxy hook | Build from [`src/`](src/) with `package.ps1` |

## Repository layout

```
OneCord/
  OneCord.ps1     WARP route manager (menu, enable, disable, status, repair)
  README.md
  src/
    package.ps1   Build installer and proxy DLL
    installer/    C# WinForms installer
    native/       Optional experimental C++ hook DLL
    assets/       onecord.ini and packet template
    dist/         Build output (generated, not committed)
```

## Quick start

1. Install [Cloudflare WARP](https://1.1.1.1) and open it once so the client registers
2. Install [Discord](https://discord.com/download) if needed
3. Build the proxy package:

   ```powershell
   cd src
   .\package.ps1
   ```

4. Run `src\dist\Installer.exe` and install the proxy into Discord (see [`src/README.md`](src/README.md))
5. Run `OneCord.ps1` as Administrator and choose **Enable Discord WARP route**
6. Restart Discord after proxy changes so `version.dll` loads

## Usage

### Run from GitHub

Open PowerShell as Administrator:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1")))
```

Actions:

#### Enable

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) Enable
```

#### Status

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) Status
```

#### RepairDrover

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) RepairDrover
```

#### Disable

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) Disable
```

Disable without disconnecting WARP:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) Disable -KeepWarpConnectedOnDisable
```

### Run from a local clone

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\OneCord.ps1
```

Direct actions:

#### Enable

```powershell
.\OneCord.ps1 Enable
```

#### Status

```powershell
.\OneCord.ps1 Status
```

#### RepairDrover

```powershell
.\OneCord.ps1 RepairDrover
```

#### Disable

```powershell
.\OneCord.ps1 Disable
```

Disable without disconnecting WARP:

```powershell
.\OneCord.ps1 Disable -KeepWarpConnectedOnDisable
```

Override the default proxy port with `-ProxyPort` if needed

## Notes

- DNS rules apply to Discord domains only, not your whole system
- After a Discord update, reinstall the proxy into the new `app-*` folder and run `RepairDrover`
- To remove the proxy, run `src\dist\Installer.exe` and click **Remove from Discord**
- This is not a guaranteed latency fix. It helps when Discord works better through WARP but you do not want WARP for every app
