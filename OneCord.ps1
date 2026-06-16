[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Enable', 'Disable', 'Status', 'RepairDrover')]
    [string]$Action = 'Menu',

    [int]$ProxyPort = 1080,

    [string[]]$DnsServers = @('1.1.1.1', '1.0.0.1'),

    [switch]$KeepWarpConnectedOnDisable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Domains = @(
    'discord.com',
    'discordapp.com',
    'discordapp.net',
    'discord.gg',
    'discord.media',
    'discordstatus.com'
)

$NrptTag = 'Discord-CF'
$ProxyHost = '127.0.0.1'
$DroverProxy = "socks5://$($ProxyHost):$ProxyPort"

function Write-Ok   { param([string]$Text) Write-Host "  OK   $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "  WARN $Text" -ForegroundColor Yellow }
function Write-Bad  { param([string]$Text) Write-Host "  FAIL $Text" -ForegroundColor Red }
function Write-Note { param([string]$Text) Write-Host "  $Text" -ForegroundColor DarkGray }

function Write-MenuLine {
    param(
        [string]$LeftText,
        [string]$HintText,
        [switch]$Selected,

        [System.ConsoleColor]$Foreground,
        [System.ConsoleColor]$Background
    )

    if ($Selected) {
        [System.Console]::ForegroundColor = $Background
        [System.Console]::BackgroundColor = $Foreground
        [System.Console]::Write($LeftText)
        [System.Console]::ForegroundColor = $Foreground
        [System.Console]::BackgroundColor = $Background
    }
    else {
        [System.Console]::Write($LeftText)
    }

    if ($HintText) {
        [System.Console]::ForegroundColor = [System.ConsoleColor]::DarkGray
        [System.Console]::Write(" | $HintText")
        [System.Console]::ForegroundColor = $Foreground
    }

    [System.Console]::WriteLine()
}

function Format-MenuHint {
    param(
        [string]$Keys,
        [string]$Label,
        [int]$MaxKeysLen
    )

    if ([string]::IsNullOrWhiteSpace($Keys)) { return '' }
    if ([string]::IsNullOrWhiteSpace($Label)) { return $Keys }

    $padCount = [Math]::Max(3, ($MaxKeysLen - $Keys.Length) + 3)
    return "$Keys$(' ' * $padCount)$Label"
}

function Pause-Key {
    param([string]$Message = 'Press any key to continue...')

    Write-Host ''
    Write-Host "  $Message" -NoNewline -ForegroundColor DarkGray
    [void][System.Console]::ReadKey($true)
}

function Write-Menu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('InputObject')]
        [object]$Entries,

        [Alias('Name')]
        [string]$Title = 'Menu',

        [switch]$Sort
    )

    $items = @()

    if ($Entries -is [System.Collections.IDictionary]) {
        foreach ($key in $Entries.Keys) {
            $items += [pscustomobject]@{
                Name  = [string]$key
                Value = $Entries[$key]
            }
        }
    }
    else {
        foreach ($entry in @($Entries)) {
            $items += [pscustomobject]@{
                Name  = [string]$entry
                Value = $entry
            }
        }
    }

    if ($Sort) {
        $items = @($items | Sort-Object -Property Name)
    }

    if (@($items).Count -eq 0) { return $null }

    if ($Host.Name -ne 'ConsoleHost') {
        Clear-Host
        Write-Host ''
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "  $('-' * $Title.Length)" -ForegroundColor DarkGray
        Write-Host ''

        for ($i = 0; $i -lt @($items).Count; $i++) {
            Write-Host "  $($i + 1)) $($items[$i].Name)"
        }

        Write-Host ''
        $rawChoice = Read-Host '  Choose'
        $choice = 0

        if ([int]::TryParse($rawChoice, [ref]$choice) -and $choice -ge 1 -and $choice -le @($items).Count) {
            return $items[$choice - 1].Value
        }

        return $null
    }

    $selected = 0
    $oldForeground = [System.Console]::ForegroundColor
    $oldBackground = [System.Console]::BackgroundColor
    $oldCursor = [System.Console]::CursorVisible

    try {
        [System.Console]::CursorVisible = $false

        while ($true) {
            Clear-Host
            Write-Host ''
            Write-Host "  $Title" -ForegroundColor Cyan
            Write-Host "  $('-' * $Title.Length)" -ForegroundColor DarkGray
            Write-Host ''

            $hintDefs = @(
                @{ Keys = 'keyboard arrow Up/Down or 8 for up 2 for down'; Label = 'Move' }
                @{ Keys = 'Enter'; Label = 'Select' }
                @{ Keys = 'Esc'; Label = 'Exit' }
                @{ Keys = 'by IBRAHIM @IBRHUB'; Label = '' }
            )

            $labeledHints = @($hintDefs | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Label) })
            $maxHintKeysLen = ($labeledHints | ForEach-Object { $_.Keys.Length } | Measure-Object -Maximum).Maximum
            if (-not $maxHintKeysLen) { $maxHintKeysLen = 0 }

            $hints = @(
                foreach ($hintDef in $hintDefs) {
                    Format-MenuHint -Keys $hintDef.Keys -Label $hintDef.Label -MaxKeysLen $maxHintKeysLen
                }
            )

            $maxNameLen = ($items | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
            $menuWidth = $maxNameLen + 4

            for ($i = 0; $i -lt @($items).Count; $i++) {
                $indent = if ($i -eq $selected) { '  ' } else { '    ' }
                $leftText = ($indent + $items[$i].Name).PadRight($menuWidth)
                $hintText = if ($i -lt @($hints).Count) { $hints[$i] } else { '' }

                Write-MenuLine -LeftText $leftText -HintText $hintText -Selected:($i -eq $selected) `
                    -Foreground $oldForeground -Background $oldBackground
            }

            Write-Host ''

            $key = [System.Console]::ReadKey($true)

            switch ($key.Key) {
                {
                    $_ -eq [System.ConsoleKey]::UpArrow -or
                    $_ -eq [System.ConsoleKey]::D8 -or
                    $_ -eq [System.ConsoleKey]::NumPad8
                } {
                    if ($selected -le 0) { $selected = @($items).Count - 1 }
                    else { $selected-- }
                    break
                }
                {
                    $_ -eq [System.ConsoleKey]::DownArrow -or
                    $_ -eq [System.ConsoleKey]::D2 -or
                    $_ -eq [System.ConsoleKey]::NumPad2
                } {
                    if ($selected -ge (@($items).Count - 1)) { $selected = 0 }
                    else { $selected++ }
                    break
                }
                'Home' {
                    $selected = 0
                    break
                }
                'End' {
                    $selected = @($items).Count - 1
                    break
                }
                'Enter' {
                    Clear-Host
                    return $items[$selected].Value
                }
                { $_ -eq [System.ConsoleKey]::Escape -or $_ -eq [System.ConsoleKey]::Backspace } {
                    Clear-Host
                    return $null
                }
            }
        }
    }
    finally {
        [System.Console]::ForegroundColor = $oldForeground
        [System.Console]::BackgroundColor = $oldBackground
        [System.Console]::CursorVisible = $oldCursor
    }
}

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Bad 'Run this script as Administrator.'
        exit 1
    }
}

function Get-WarpCliPath {
    $cmd = Get-Command 'warp-cli' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Invoke-WarpCli {
    param([string[]]$ArgsList)

    $path = Get-WarpCliPath
    if (-not $path) {
        return [pscustomobject]@{ ExitCode = -1; Output = '' }
    }

    $output = & $path @ArgsList 2>&1 | Out-String
    $lastExit = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    $exitCode = if ($lastExit) { [int]$lastExit.Value } else { 0 }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output.Trim()
    }
}

function Invoke-WarpCommandLine {
    param([string]$CommandLine)

    $parts = $CommandLine -split '\s+'
    return Invoke-WarpCli -ArgsList $parts
}

function Try-WarpCommandLines {
    param([string[]]$CommandLines)

    foreach ($line in $CommandLines) {
        $result = Invoke-WarpCommandLine -CommandLine $line
        if ($result.ExitCode -eq 0) { return $true }
    }

    return $false
}

function Test-WarpConnectedText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }

    if ($Text -match '(?i)\bDisconnected\b|\bNot connected\b|\bUnable to connect\b') {
        return $false
    }

    return ($Text -match '(?i)(^|[^a-z])Connected([^a-z]|$)')
}

function Get-WarpProxyPortFromText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

    if ($Text -match '(?i)\bWarpProxy\b.*?\bport\s+(\d+)') {
        return [int]$Matches[1]
    }

    if ($Text -match '(?i)\bproxy\b.*?\bport\s*[:=]?\s*(\d+)') {
        return [int]$Matches[1]
    }

    return $null
}

function Test-LocalTcpPort {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMs = 800
    )

    $client = [System.Net.Sockets.TcpClient]::new()

    try {
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        $ready = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $ready) { return $false }

        $client.EndConnect($async)
        return $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Get-WarpInfo {
    $path = Get-WarpCliPath
    $installed = [bool]$path
    $statusText = ''
    $settingsText = ''
    $connected = $false
    $settingsPort = $null
    $proxyListening = $false

    if ($installed) {
        $statusText = (Invoke-WarpCli -ArgsList @('status')).Output
        $settingsText = (Invoke-WarpCli -ArgsList @('settings')).Output
        $connected = Test-WarpConnectedText -Text $statusText
        $settingsPort = Get-WarpProxyPortFromText -Text $settingsText
        $proxyListening = Test-LocalTcpPort -HostName $ProxyHost -Port $ProxyPort
    }

    return [pscustomobject]@{
        Installed      = $installed
        Connected      = $connected
        ProxyPort      = $settingsPort
        ProxyListening = $proxyListening
        StatusText     = $statusText
        SettingsText   = $settingsText
    }
}

function Get-NrptRules {
    try {
        return @(Get-DnsClientNrptRule -ErrorAction Stop | Where-Object { $_.Comment -eq $NrptTag })
    }
    catch {
        return @()
    }
}

function Set-DiscordNrptRules {
    $oldRules = @(Get-NrptRules)
    if (@($oldRules).Count -gt 0) {
        foreach ($rule in $oldRules) {
            Remove-DnsClientNrptRule -Name $rule.Name -Force | Out-Null
        }
    }

    foreach ($domain in $Domains) {
        Add-DnsClientNrptRule -Namespace ".$domain" -NameServers $DnsServers -Comment $NrptTag | Out-Null
    }

    Clear-DnsClientCache
}

function Remove-DiscordNrptRules {
    $rules = @(Get-NrptRules)
    if (@($rules).Count -gt 0) {
        foreach ($rule in $rules) {
            Remove-DnsClientNrptRule -Name $rule.Name -Force | Out-Null
        }
        Clear-DnsClientCache
    }

    return @($rules).Count
}

function Get-LatestDiscordAppFolder {
    $root = Join-Path $env:LOCALAPPDATA 'Discord'
    if (-not (Test-Path -LiteralPath $root)) { return $null }

    $folders = @(
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'app-*' }
    )

    if (@($folders).Count -eq 0) { return $null }

    return $folders |
        Sort-Object @{ Expression = {
            try { [version]($_.Name -replace '^app-', '') }
            catch { [version]'0.0.0.0' }
        }} -Descending |
        Select-Object -First 1
}

function Get-DroverConfigProxy {
    param([string]$IniPath)

    if (-not $IniPath -or -not (Test-Path -LiteralPath $IniPath)) { return $null }

    $line = Get-Content -LiteralPath $IniPath -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '^\s*proxy\s*=' } |
        Select-Object -First 1

    if ($line -and $line -match '^\s*proxy\s*=\s*(.+?)\s*$') {
        return $Matches[1]
    }

    return $null
}

function Get-DroverLoaded {
    $processes = @(Get-Process -Name 'Discord' -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        try {
            foreach ($module in $process.Modules) {
                if ($module.ModuleName -ieq 'version.dll' -and $module.FileName -like '*\Discord\app-*\version.dll') {
                    return $true
                }
            }
        }
        catch {}
    }

    return $false
}

function Get-DroverInfo {
    $latest = Get-LatestDiscordAppFolder
    $latestPath = if ($latest) { $latest.FullName } else { $null }
    $latestDll = if ($latestPath) { Join-Path $latestPath 'version.dll' } else { $null }
    $latestIni = if ($latestPath) { Join-Path $latestPath 'drover.ini' } else { $null }

    $root = Join-Path $env:LOCALAPPDATA 'Discord'
    $installedFolders = @()

    if (Test-Path -LiteralPath $root) {
        $installedFolders = @(
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'app-*' } |
            Where-Object {
                (Test-Path -LiteralPath (Join-Path $_.FullName 'version.dll')) -or
                (Test-Path -LiteralPath (Join-Path $_.FullName 'drover.ini'))
            } |
            Select-Object -ExpandProperty FullName
        )
    }

    $installedInLatest = if ($latestDll) { Test-Path -LiteralPath $latestDll } else { $false }
    $configProxy = if ($latestIni) { Get-DroverConfigProxy -IniPath $latestIni } else { $null }

    return [pscustomobject]@{
        LatestAppPath     = $latestPath
        LatestDllPath     = $latestDll
        LatestIniPath     = $latestIni
        Installed         = (@($installedFolders).Count -gt 0)
        InstalledInLatest = $installedInLatest
        InstalledFolders  = $installedFolders
        Loaded            = Get-DroverLoaded
        ConfigProxy       = $configProxy
    }
}

function Set-DroverProxyConfig {
    param([string]$IniPath)

    $lines = @()
    if (Test-Path -LiteralPath $IniPath) {
        $lines = @(Get-Content -LiteralPath $IniPath -ErrorAction Stop)
    }

    if (@($lines).Count -eq 0) {
        $lines = @('[drover]', "proxy = $DroverProxy")
    }
    else {
        $hasDroverSection = $false
        $proxyUpdated = $false

        for ($i = 0; $i -lt @($lines).Count; $i++) {
            if ($lines[$i] -match '^\s*\[drover\]\s*$') {
                $hasDroverSection = $true
            }

            if ($lines[$i] -match '^\s*proxy\s*=') {
                $lines[$i] = "proxy = $DroverProxy"
                $proxyUpdated = $true
            }
        }

        if (-not $hasDroverSection) {
            $lines = @('[drover]') + $lines
        }

        if (-not $proxyUpdated) {
            $insertAt = 1
            for ($i = 0; $i -lt @($lines).Count; $i++) {
                if ($lines[$i] -match '^\s*\[drover\]\s*$') {
                    $insertAt = $i + 1
                    break
                }
            }

            $before = @($lines[0..($insertAt - 1)])
            $after = if ($insertAt -lt @($lines).Count) { @($lines[$insertAt..(@($lines).Count - 1)]) } else { @() }
            $lines = $before + "proxy = $DroverProxy" + $after
        }
    }

    Set-Content -LiteralPath $IniPath -Value $lines -Encoding ASCII
}

function Repair-DroverConfig {
    param([switch]$Quiet)

    $drover = Get-DroverInfo

    if (-not $drover.LatestAppPath) {
        if (-not $Quiet) { Write-Warn 'Discord install folder was not found.' }
        return $false
    }

    if (-not $drover.InstalledInLatest) {
        if (-not $Quiet) { Write-Warn 'Drover is not installed in the latest Discord app folder.' }
        return $false
    }

    Set-DroverProxyConfig -IniPath $drover.LatestIniPath

    if (-not $Quiet) {
        Write-Ok "Drover proxy set to $DroverProxy"
    }

    return $true
}

function Get-CurrentState {
    $nrptRules = @(Get-NrptRules)
    $warp = Get-WarpInfo
    $drover = Get-DroverInfo
    $discordRunning = [bool](Get-Process -Name 'Discord' -ErrorAction SilentlyContinue)

    return [pscustomobject]@{
        NrptRules      = $nrptRules
        NrptActive     = (@($nrptRules).Count -gt 0)
        Warp           = $warp
        Drover         = $drover
        DiscordRunning = $discordRunning
    }
}

function Show-Status {
    param($State)

    Write-Host ''
    Write-Host '  Discord WARP Route' -ForegroundColor Cyan
    Write-Host '  ------------------' -ForegroundColor DarkGray

    if ($State.NrptActive) {
        Write-Ok "DNS rules active ($(@($State.NrptRules).Count))"
    }
    else {
        Write-Warn 'DNS rules inactive'
    }

    if (-not $State.Warp.Installed) {
        Write-Bad 'WARP not installed'
    }
    elseif ($State.Warp.Connected) {
        Write-Ok 'WARP connected'
    }
    else {
        Write-Warn 'WARP not connected'
    }

    if ($State.Warp.Installed -and $State.Warp.ProxyPort) {
        if ($State.Warp.ProxyPort -eq $ProxyPort) {
            Write-Ok "WARP proxy port is $ProxyPort"
        }
        else {
            Write-Warn "WARP proxy port is $($State.Warp.ProxyPort), expected $ProxyPort"
        }
    }
    elseif ($State.Warp.Installed) {
        Write-Warn "WARP proxy port was not detected"
    }

    if ($State.Warp.Installed) {
        if ($State.Warp.ProxyListening) {
            Write-Ok "Local proxy is listening on $($ProxyHost):$ProxyPort"
        }
        else {
            Write-Warn "Local proxy is not listening on $($ProxyHost):$ProxyPort"
        }
    }

    if ($State.Drover.Loaded) {
        Write-Ok 'Drover loaded inside Discord'
    }
    elseif ($State.Drover.InstalledInLatest -and $State.DiscordRunning) {
        Write-Warn 'Drover installed but not loaded. Restart Discord.'
    }
    elseif ($State.Drover.InstalledInLatest) {
        Write-Warn 'Drover installed. Start Discord to load it.'
    }
    elseif ($State.Drover.Installed) {
        Write-Warn 'Drover exists in an older Discord folder. Reinstall it after Discord update.'
    }
    else {
        Write-Warn 'Drover not installed'
    }

    if ($State.Drover.InstalledInLatest) {
        if ($State.Drover.ConfigProxy -eq $DroverProxy) {
            Write-Ok "Drover proxy is $DroverProxy"
        }
        elseif ($State.Drover.ConfigProxy) {
            Write-Warn "Drover proxy is $($State.Drover.ConfigProxy), expected $DroverProxy"
        }
        else {
            Write-Warn 'Drover proxy is not configured'
        }
    }

    if ($State.DiscordRunning) {
        Write-Ok 'Discord is running'
    }
    else {
        Write-Note 'Discord is closed'
    }

    Write-Host ''
}

function Show-Hints {
    param($State)

    $shown = $false

    if (-not $State.Warp.Installed) {
        Write-Note 'Install Cloudflare WARP first: https://1.1.1.1'
        $shown = $true
    }
    elseif (-not $State.Warp.Connected -or -not $State.Warp.ProxyListening) {
        Write-Note "Open WARP once if it is not registered, then run: .\Discord-WARP-Drover.ps1 Enable"
        $shown = $true
    }

    if (-not $State.Drover.InstalledInLatest) {
        Write-Note 'Install Drover into the latest Discord app folder, then run RepairDrover.'
        Write-Note 'Drover: https://github.com/hdrover/discord-drover/releases/latest'
        $shown = $true
    }
    elseif ($State.Drover.ConfigProxy -ne $DroverProxy) {
        Write-Note "Run RepairDrover to set Drover to $DroverProxy"
        $shown = $true
    }

    if ($shown) { Write-Host '' }
}

function Enable-Setup {
    Write-Host ''
    Write-Note 'Applying Discord DNS rules...'
    Set-DiscordNrptRules
    Write-Ok "DNS rules refreshed for $(@($Domains).Count) domains"

    if (Get-WarpCliPath) {
        Write-Note "Setting WARP local proxy to $($ProxyHost):$ProxyPort..."

        [void](Try-WarpCommandLines -CommandLines @('mode proxy', 'set-mode proxy'))
        [void](Try-WarpCommandLines -CommandLines @("proxy port $ProxyPort", "set-proxy-port $ProxyPort"))
        [void](Try-WarpCommandLines -CommandLines @('connect'))

        Start-Sleep -Seconds 2
    }
    else {
        Write-Warn 'WARP is not installed. DNS rules were applied only.'
    }

    [void](Repair-DroverConfig -Quiet)

    $state = Get-CurrentState
    Show-Status -State $state
    Show-Hints -State $state
}

function Disable-Setup {
    Write-Host ''

    $removed = Remove-DiscordNrptRules
    if ($removed -gt 0) {
        Write-Ok "Removed $removed DNS rule(s)"
    }
    else {
        Write-Note 'No DNS rules to remove'
    }

    if (-not $KeepWarpConnectedOnDisable -and (Get-WarpCliPath)) {
        [void](Try-WarpCommandLines -CommandLines @('disconnect'))
        [void](Try-WarpCommandLines -CommandLines @('mode warp', 'set-mode warp'))
        Write-Ok 'WARP returned to normal mode'
    }
    elseif ($KeepWarpConnectedOnDisable) {
        Write-Note 'WARP was left untouched'
    }

    Write-Note 'To fully remove Drover, open drover.exe and click Uninstall.'
    Show-Status -State (Get-CurrentState)
}

function Invoke-MenuAction {
    param([string]$SelectedAction)

    switch ($SelectedAction) {
        'Enable' {
            Enable-Setup
            return $true
        }
        'Disable' {
            Disable-Setup
            return $true
        }
        'Status' {
            Show-Status -State (Get-CurrentState)
            Show-Hints -State (Get-CurrentState)
            return $true
        }
        'RepairDrover' {
            [void](Repair-DroverConfig)
            Show-Status -State (Get-CurrentState)
            return $true
        }
        'Exit' {
            return $false
        }
        default {
            Write-Bad 'Invalid choice'
            return $true
        }
    }
}

function Show-Menu {
    try { $Host.UI.RawUI.WindowTitle = 'Discord WARP Route' } catch {}

    $entries = [ordered]@{
        'Enable Discord WARP route' = 'Enable'
        'Disable Discord WARP route' = 'Disable'
        'Show current status'        = 'Status'
        'Repair Drover config'      = 'RepairDrover'
        'Exit'                      = 'Exit'
    }

    while ($true) {
        $selected = Write-Menu -Title 'Discord WARP Route' -Entries $entries

        if ([string]::IsNullOrWhiteSpace($selected)) {
            return
        }

        $continueMenu = Invoke-MenuAction -SelectedAction $selected
        if (-not $continueMenu) { return }

        Pause-Key
    }
}

Assert-Administrator

switch ($Action) {
    'Menu'         { Show-Menu }
    'Enable'       { Enable-Setup }
    'Disable'      { Disable-Setup }
    'Status'       { Show-Status -State (Get-CurrentState); Show-Hints -State (Get-CurrentState) }
    'RepairDrover' { [void](Repair-DroverConfig); Show-Status -State (Get-CurrentState) }
}
