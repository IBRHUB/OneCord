# OneCord Discord WARP Route

This project makes Discord use Cloudflare WARP local proxy without routing the whole PC through WARP

## What it does

- Adds NRPT DNS rules for Discord domains to Cloudflare DNS
- Sets Cloudflare WARP to local proxy mode on `127.0.0.1:1080`
- Checks whether the proxy port is actually listening
- Checks whether Drover is installed in the latest Discord app folder
- Fixes `drover.ini` to use `socks5://127.0.0.1:1080`
- Shows a clean status instead of claiming success too early

## Requirements


| Requirement         | Details                                                        |
| ------------------- | -------------------------------------------------------------- |
| **OS**              | Windows 10 or 11                                               |
| **PowerShell**      | 5.1 or newer                                                   |
| **Privileges**      | Run as **Administrator** (needed for DNS NRPT rules)           |
| **Cloudflare WARP** | Must be installed and registered; `warp-cli` available in PATH |
| **Discord**         | Desktop app installed (stable release)                         |
| **Drover**          | Installed into the latest Discord `app-`* folder               |


### Download links


| Software            | Link                                                                                                                   |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **Cloudflare WARP** | [https://1.1.1.1](https://1.1.1.1)                                                                                     |
| **Discord**         | [https://discord.com/download](https://discord.com/download)                                                           |
| **Drover**          | [https://github.com/hdrover/discord-drover/releases/latest](https://github.com/hdrover/discord-drover/releases/latest) |


### Setup order

1. Install [Cloudflare WARP](https://1.1.1.1) and open it once so the client is registered
2. Install [Discord](https://discord.com/download) if it is not already installed
3. Download [Drover](https://github.com/hdrover/discord-drover/releases/latest), run `drover.exe`, and install it into Discord
4. Run `OneCord.ps1` as Administrator and choose **Enable Discord WARP route**
5. Restart Discord after Drover config changes so `version.dll` loads

## Usage

### Run directly from GitHub

Open **PowerShell as Administrator**, then run:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1")))
```

- 

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) Enable
```

- 

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) Status
```

- 

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) RepairDrover
```

- 

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) Disable
```

Disable without touching WARP:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/IBRHUB/OneCord/main/OneCord.ps1"))) Disable -KeepWarpConnectedOnDisable
```

### Run from a local clone

Run PowerShell as Administrator from this folder

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\OneCord.ps1
```

Direct actions:

```powershell
.\OneCord.ps1 Enable
.\OneCord.ps1 Status
.\OneCord.ps1 RepairDrover
.\OneCord.ps1 Disable
```

Disable without touching WARP :

```powershell
.\OneCord.ps1 Disable -KeepWarpConnectedOnDisable
```

## Notes

- Default WARP proxy port is `1080`. Override with `-ProxyPort` if needed
- DNS rules use Cloudflare DNS (`1.1.1.1`, `1.0.0.1`) for Discord domains only
- After a Discord update, reinstall Drover into the new `app-*` folder and run `RepairDrover`
- To fully remove Drover, open `drover.exe` and click **Uninstall**
- This is not a guaranteed ping fix. It is useful when Discord improves with WARP, but you do not want WARP to affect every app on the PC

