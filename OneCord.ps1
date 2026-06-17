[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Enable', 'Disable', 'Status', 'RepairDrover')]
    [string]$Action = 'Menu',

    [ValidateRange(1, 65535)]
    [int]$ProxyPort = 1080,

    [ValidateNotNullOrEmpty()]
    [string[]]$DnsServers = @('1.1.1.1', '1.0.0.1'),

    [switch]$KeepWarpConnectedOnDisable
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# config

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

$ESC = [char]27

$WarpCliPath       = 'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe'
$WarpMsiUrl        = 'https://1111-releases.cloudflareclient.com/windows/Cloudflare_WARP_Release-x64.msi'
$WarpServiceName   = 'CloudflareWARP'

$OneCordAppData    = Join-Path $env:APPDATA 'OneCord'
$DroverCacheDir    = Join-Path $OneCordAppData 'drover'
$RepairLogPath     = Join-Path $OneCordAppData 'repair.log'
$InstallLogPath    = Join-Path $OneCordAppData 'install.log'
$ScheduledTaskName = 'OneCord-Repair'
$DroverManualUrl   = 'https://github.com/hdrover/discord-drover/releases'

$Text = @{
    Title               = 'Discord WARP Route'
    PromptLine1         = 'OneCord needs to install Cloudflare WARP and Discord Drover'
    PromptLine2         = 'These are required for the proxy fix to work'
    PromptLine3         = 'Press ENTER to install automatically, or Q to quit'

    StepWarpDownload    = 'Downloading Cloudflare WARP'
    StepWarpInstall     = 'Installing WARP silently'
    StepWarpConfigure   = 'Configuring WARP proxy mode'
    StepDroverFetch     = 'Fetching latest Drover release'
    StepDroverInstall   = 'Installing Drover into Discord'
    StepTaskRegister    = 'Registering self healing task'

    MsgRunAdmin         = 'Run this script as Administrator'
    MsgDiscordMissing   = 'Discord install folder was not found'
    MsgDroverMissing    = 'Drover is not installed in the latest Discord app folder'
    MsgDroverCacheMiss  = 'Drover cache not found. Run prerequisites install first'
    MsgInvalidChoice    = 'Invalid choice'
}

# output helpers

function Write-Color {
    param(
        [string]$Text,
        [string]$Ansi
    )

    Write-Host ($ESC + $Ansi + $Text + $ESC + '[0m')
}

function Write-Ok {
    param([string]$Text)
    Write-Host "  OK   $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  WARN $Text" -ForegroundColor Yellow
}

function Write-Bad {
    param([string]$Text)
    Write-Host "  FAIL $Text" -ForegroundColor Red
}

function Write-Note {
    param([string]$Text)
    Write-Host "  $Text" -ForegroundColor DarkGray
}

function Write-InstallFail {
    param([string]$Text)
    Write-Color -Text $Text -Ansi '[91m'
}

function Write-InstallWarn {
    param([string]$Text)
    Write-Color -Text $Text -Ansi '[93m'
}

function Write-InstallInfo {
    param([string]$Text)
    Write-Color -Text $Text -Ansi '[90m'
}

function Write-StatusLine {
    param(
        [ValidateSet('OK', 'WARN', 'FAIL')]
        [string]$Level,

        [string]$Label,
        [string]$Value
    )

    switch ($Level) {
        'OK'   { $levelColor = 'Green' }
        'FAIL' { $levelColor = 'Red' }
        default { $levelColor = 'Yellow' }
    }

    Write-Host -NoNewline ($Level.PadRight(4) + '  ') -ForegroundColor $levelColor
    Write-Host -NoNewline $Label.PadRight(15) -ForegroundColor White
    Write-Host $Value -ForegroundColor DarkGray
}

function Write-InstallStepBegin {
    param(
        [int]$Number,
        [string]$Label
    )

    Write-Host -NoNewline ("[{0}/6] {1}... " -f $Number, $Label.PadRight(35))
}

function Write-InstallStepDone {
    $check = [string][char]0x2713
    Write-Host ($ESC + '[92m' + $check + $ESC + '[0m')
}

function Write-InstallStepFail {
    $cross = [string][char]0x2717
    Write-Host ($ESC + '[91m' + $cross + $ESC + '[0m')
}

function Invoke-InstallStep {
    param(
        [int]$Number,
        [string]$Label,
        [scriptblock]$ScriptBlock
    )

    Write-InstallStepBegin -Number $Number -Label $Label

    try {
        [void](& $ScriptBlock)
        Write-InstallStepDone
        return $true
    }
    catch {
        Write-InstallStepFail
        Write-InstallFail $_.Exception.Message
        return $false
    }
}

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
    param([string]$Message = 'Press any key to continue')

    Write-Host ''
    Write-Host $Message -NoNewline -ForegroundColor DarkGray
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

# common helpers

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $identity
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Bad $Text.MsgRunAdmin
        exit 1
    }
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-OneCordLog {
    param(
        [string]$Path,
        [string]$Message
    )

    $dir = Split-Path -Parent $Path
    if ($dir) {
        Ensure-Directory -Path $dir
    }

    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
}

function Get-FileSha256 {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    try {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
    }
    catch {
        return $null
    }
}

function Invoke-FileDownload {
    param(
        [string]$Url,
        [string]$Destination
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        throw 'Download URL is empty'
    }

    $dir = Split-Path -Parent $Destination
    if ($dir) {
        Ensure-Directory -Path $dir
    }

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Force
    }

    $oldProgress = $ProgressPreference
    $oldSecurityProtocol = [Net.ServicePointManager]::SecurityProtocol

    try {
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop

        if (-not (Test-Path -LiteralPath $Destination)) {
            throw "Download failed: $Url"
        }

        $length = (Get-Item -LiteralPath $Destination).Length
        if ($length -le 0) {
            throw "Downloaded file is empty: $Url"
        }
    }
    finally {
        $ProgressPreference = $oldProgress
        [Net.ServicePointManager]::SecurityProtocol = $oldSecurityProtocol
    }
}

function Invoke-ExternalFile {
    param(
        [string]$FilePath,
        [string[]]$ArgsList
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return [pscustomobject]@{
            ExitCode = -1
            Output   = ''
        }
    }

    $global:LASTEXITCODE = 0
    $output = & $FilePath @ArgsList 2>&1 | Out-String
    $exitCode = if ($null -ne $global:LASTEXITCODE) { [int]$global:LASTEXITCODE } else { 0 }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output.Trim()
    }
}

function Test-LocalTcpPort {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMs = 900
    )

    $client = New-Object System.Net.Sockets.TcpClient

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

function Wait-LocalTcpPort {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutSec = 45
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)

    while ((Get-Date) -lt $deadline) {
        if (Test-LocalTcpPort -HostName $HostName -Port $Port) {
            return $true
        }

        Start-Sleep -Milliseconds 700
    }

    return $false
}

function Wait-ProcessRunning {
    param(
        [string]$Name,
        [int]$TimeoutSec = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)

    while ((Get-Date) -lt $deadline) {
        if (Get-Process -Name $Name -ErrorAction SilentlyContinue) {
            return $true
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}

# warp helpers

function Get-WarpCliPath {
    if (Test-Path -LiteralPath $WarpCliPath) {
        return $WarpCliPath
    }

    $cmd = Get-Command 'warp-cli.exe' -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $root = 'C:\Program Files\Cloudflare'
    if (Test-Path -LiteralPath $root) {
        $found = Get-ChildItem -LiteralPath $root -Filter 'warp-cli.exe' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Invoke-WarpCli {
    param([string[]]$ArgsList)

    $path = Get-WarpCliPath
    if (-not $path) {
        return [pscustomobject]@{
            ExitCode = -1
            Output   = ''
            Command  = ''
        }
    }

    $result = Invoke-ExternalFile -FilePath $path -ArgsList $ArgsList
    $result | Add-Member -NotePropertyName Command -NotePropertyValue ($ArgsList -join ' ') -Force
    return $result
}

function Invoke-WarpCommandLine {
    param([string]$CommandLine)

    $parts = @($CommandLine -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    return Invoke-WarpCli -ArgsList $parts
}

function Invoke-WarpAny {
    param(
        [string[]]$CommandLines,
        [switch]$IgnoreFailure
    )

    $last = $null

    foreach ($line in $CommandLines) {
        $result = Invoke-WarpCommandLine -CommandLine $line
        $last = $result

        if ($result.ExitCode -eq 0) {
            return [pscustomobject]@{
                Success = $true
                Result  = $result
            }
        }
    }

    if ($IgnoreFailure) {
        return [pscustomobject]@{
            Success = $false
            Result  = $last
        }
    }

    $message = 'warp-cli command failed'
    if ($last -and $last.Command) {
        $message = "$($message): $($last.Command)"
    }
    if ($last -and $last.Output) {
        $message = "$message`n$($last.Output)"
    }

    throw $message
}

function Test-WarpConnectedText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }

    if ($Text -match '(?i)\b(disconnected|not connected|unable to connect)\b') {
        return $false
    }

    return ($Text -match '(?i)\bconnected\b')
}

function Get-WarpProxyPortFromText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

    if ($Text -match '(?i)\b127\.0\.0\.1\s*:\s*(\d+)') {
        return [int]$Matches[1]
    }

    if ($Text -match '(?i)\blocalhost\s*:\s*(\d+)') {
        return [int]$Matches[1]
    }

    if ($Text -match '(?i)\bproxy\b.*?\bport\s*[:=]?\s*(\d+)') {
        return [int]$Matches[1]
    }

    if ($Text -match '(?i)\bport\s*[:=]?\s*(\d+)') {
        return [int]$Matches[1]
    }

    return $null
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

function Test-WarpInstalled {
    return [bool](Get-WarpCliPath)
}

function Test-WarpProxyReady {
    if (-not (Get-WarpCliPath)) { return $false }

    if (-not (Test-LocalTcpPort -HostName $ProxyHost -Port $ProxyPort)) {
        return $false
    }

    try {
        $tcp = Test-NetConnection -ComputerName $ProxyHost -Port $ProxyPort -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        return [bool]$tcp.TcpTestSucceeded
    }
    catch {
        return $true
    }
}

function Wait-WarpService {
    param([int]$TimeoutSec = 30)

    $service = Get-Service -Name $WarpServiceName -ErrorAction SilentlyContinue

    if (-not $service) {
        $deadline = (Get-Date).AddSeconds($TimeoutSec)

        while ((Get-Date) -lt $deadline) {
            $service = Get-Service -Name $WarpServiceName -ErrorAction SilentlyContinue
            if ($service) { break }
            Start-Sleep -Milliseconds 500
        }
    }

    if (-not $service) {
        throw 'Cloudflare WARP service was not found'
    }

    if ($service.Status -ne 'Running') {
        Start-Service -Name $WarpServiceName -ErrorAction SilentlyContinue
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSec)

    while ((Get-Date) -lt $deadline) {
        $service.Refresh()

        if ($service.Status -eq 'Running') {
            [void](Wait-ProcessRunning -Name 'warp-svc' -TimeoutSec 5)
            return $true
        }

        Start-Sleep -Milliseconds 700
    }

    throw 'Cloudflare WARP service did not start'
}

function Restart-WarpServiceSafe {
    try {
        Restart-Service -Name $WarpServiceName -Force -ErrorAction Stop
        [void](Wait-WarpService -TimeoutSec 25)
        return $true
    }
    catch {
        return $false
    }
}

function Initialize-WarpRegistration {
    [void](Invoke-WarpAny -CommandLines @(
        '--accept-tos registration new',
        '--accept-tos register',
        'registration new',
        'register'
    ) -IgnoreFailure)
}

function Set-WarpModeProxyCommands {
    [void](Invoke-WarpAny -CommandLines @(
        'mode proxy',
        'set-mode proxy'
    ))

    [void](Invoke-WarpAny -CommandLines @(
        "proxy port $ProxyPort",
        "set-proxy-port $ProxyPort"
    ))

    [void](Invoke-WarpAny -CommandLines @(
        'connect'
    ) -IgnoreFailure)
}

function Set-WarpProxyMode {
    [void](Wait-WarpService -TimeoutSec 35)
    Initialize-WarpRegistration
    Set-WarpModeProxyCommands

    if (Wait-LocalTcpPort -HostName $ProxyHost -Port $ProxyPort -TimeoutSec 55) {
        return $true
    }

    [void](Restart-WarpServiceSafe)
    Initialize-WarpRegistration
    Set-WarpModeProxyCommands

    if (Wait-LocalTcpPort -HostName $ProxyHost -Port $ProxyPort -TimeoutSec 35) {
        return $true
    }

    $statusText = (Invoke-WarpCli -ArgsList @('status')).Output
    $settingsText = (Invoke-WarpCli -ArgsList @('settings')).Output

    $message = "WARP proxy is not listening on ${ProxyHost}:$ProxyPort"
    if ($statusText) {
        $message = "$message`nstatus: $statusText"
    }
    if ($settingsText) {
        $message = "$message`nsettings: $settingsText"
    }

    $message = "$message`nOpen Cloudflare WARP and make sure local proxy mode is available, then run OneCord again"
    throw $message
}

function Install-WarpMsi {
    param([string]$MsiPath)

    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', $MsiPath, '/quiet', '/norestart') -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "msiexec failed with exit code $($process.ExitCode). Run this script as Administrator"
    }

    $deadline = (Get-Date).AddSeconds(45)

    while ((Get-Date) -lt $deadline) {
        if (Get-WarpCliPath) {
            return $true
        }

        Start-Sleep -Seconds 1
    }

    throw 'WARP was installed but warp-cli.exe was not found'
}

# nrpt helpers

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

    foreach ($rule in $oldRules) {
        Remove-DnsClientNrptRule -Name $rule.Name -Force | Out-Null
    }

    foreach ($domain in $Domains) {
        Add-DnsClientNrptRule -Namespace ".$domain" -NameServers $DnsServers -Comment $NrptTag | Out-Null
    }

    Clear-DnsClientCache
}

function Remove-DiscordNrptRules {
    $rules = @(Get-NrptRules)

    foreach ($rule in $rules) {
        Remove-DnsClientNrptRule -Name $rule.Name -Force | Out-Null
    }

    if (@($rules).Count -gt 0) {
        Clear-DnsClientCache
    }

    return @($rules).Count
}

# drover helpers

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

function Set-DroverIniContent {
    param([string]$IniPath)

    $content = @(
        '[drover]'
        "proxy = $DroverProxy"
    ) -join "`r`n"

    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($IniPath, $content, $utf8NoBom)
}

function Set-DroverProxyConfig {
    param([string]$IniPath)

    Set-DroverIniContent -IniPath $IniPath
}

function Repair-DroverConfig {
    param([switch]$Quiet)

    $drover = Get-DroverInfo

    if (-not $drover.LatestAppPath) {
        if (-not $Quiet) { Write-Warn $Text.MsgDiscordMissing }
        return $false
    }

    if (-not $drover.InstalledInLatest) {
        if (-not $Quiet) { Write-Warn $Text.MsgDroverMissing }
        return $false
    }

    Set-DroverProxyConfig -IniPath $drover.LatestIniPath
    return $true
}

function Test-DroverInstalled {
    $latest = Get-LatestDiscordAppFolder
    if (-not $latest) { return $false }

    return Test-Path -LiteralPath (Join-Path $latest.FullName 'version.dll')
}

function Get-DroverReleaseZipUrl {
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/hdrover/discord-drover/releases/latest' -UseBasicParsing -ErrorAction Stop
    }
    catch {
        $statusCode = $null

        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        }
        catch {}

        if ($statusCode -eq 403) {
            throw "GitHub API rate limit reached. Manual download: $DroverManualUrl"
        }

        throw "Failed to fetch Drover release. Manual download: $DroverManualUrl"
    }

    $asset = @($release.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1)

    if (@($asset).Count -eq 0 -or -not $asset[0].browser_download_url) {
        throw "No Drover ZIP asset found. Manual download: $DroverManualUrl"
    }

    return [string]$asset[0].browser_download_url
}

function Save-DroverCache {
    param(
        [string]$DllSource,
        [string]$PacketSource,
        [string]$IniPath
    )

    Ensure-Directory -Path $DroverCacheDir

    Copy-Item -LiteralPath $DllSource -Destination (Join-Path $DroverCacheDir 'version.dll') -Force

    if ($PacketSource -and (Test-Path -LiteralPath $PacketSource)) {
        Copy-Item -LiteralPath $PacketSource -Destination (Join-Path $DroverCacheDir 'drover-packet.bin') -Force
    }

    Copy-Item -LiteralPath $IniPath -Destination (Join-Path $DroverCacheDir 'drover.ini') -Force
}

function Stop-DiscordApp {
    $processes = @(Get-Process -Name 'Discord' -ErrorAction SilentlyContinue)
    $wasRunning = @($processes).Count -gt 0

    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
        }
        catch {}
    }

    if ($wasRunning) {
        Start-Sleep -Seconds 2
    }

    return $wasRunning
}

function Start-DiscordApp {
    $updateExe = Join-Path $env:LOCALAPPDATA 'Discord\Update.exe'

    if (Test-Path -LiteralPath $updateExe) {
        Start-Process -FilePath $updateExe -ArgumentList '--processStart', 'Discord.exe' -ErrorAction SilentlyContinue | Out-Null
    }
}

function Restart-DiscordApp {
    $wasRunning = Stop-DiscordApp

    if ($wasRunning) {
        Start-DiscordApp
    }
}

function Install-DroverFromZip {
    param(
        [string]$ZipPath,
        [string]$AppDir
    )

    if (-not (Test-Path -LiteralPath $ZipPath)) {
        throw 'Drover ZIP was not downloaded'
    }

    if (-not (Test-Path -LiteralPath $AppDir)) {
        throw 'Discord app folder was not found'
    }

    $extractDir = Join-Path $env:TEMP 'onecord_drover_extracted'

    if (Test-Path -LiteralPath $extractDir) {
        Remove-Item -LiteralPath $extractDir -Recurse -Force
    }

    Ensure-Directory -Path $extractDir

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $extractDir)

    $dllSource = @(Get-ChildItem -LiteralPath $extractDir -Recurse -Filter 'version.dll' -ErrorAction SilentlyContinue | Select-Object -First 1)

    if (@($dllSource).Count -eq 0) {
        throw 'version.dll was not found inside the Drover ZIP'
    }

    $packetSource = @(Get-ChildItem -LiteralPath $extractDir -Recurse -Filter 'drover-packet.bin' -ErrorAction SilentlyContinue | Select-Object -First 1)
    $packetPath = if (@($packetSource).Count -gt 0) { $packetSource[0].FullName } else { $null }

    $wasRunning = Stop-DiscordApp

    $dllDest = Join-Path $AppDir 'version.dll'
    Copy-Item -LiteralPath $dllSource[0].FullName -Destination $dllDest -Force

    if ($packetPath) {
        Copy-Item -LiteralPath $packetPath -Destination (Join-Path $AppDir 'drover-packet.bin') -Force
    }

    $iniPath = Join-Path $AppDir 'drover.ini'
    Set-DroverIniContent -IniPath $iniPath
    Save-DroverCache -DllSource $dllSource[0].FullName -PacketSource $packetPath -IniPath $iniPath

    if ($wasRunning) {
        Start-DiscordApp
    }

    return $true
}

function Write-RepairLog {
    param([string]$Message)

    Write-OneCordLog -Path $RepairLogPath -Message $Message
}

function Repair-Drover {
    param([switch]$Silent)

    $latest = Get-LatestDiscordAppFolder

    if (-not $latest) {
        Write-RepairLog 'Repair skipped: Discord app folder not found'
        if (-not $Silent) { Write-InstallWarn $Text.MsgDiscordMissing }
        return $false
    }

    $appDir = $latest.FullName
    $dllPath = Join-Path $appDir 'version.dll'
    $cachedDll = Join-Path $DroverCacheDir 'version.dll'

    if (Test-Path -LiteralPath $dllPath) {
        $iniPath = Join-Path $appDir 'drover.ini'
        Set-DroverIniContent -IniPath $iniPath
        Write-RepairLog "OK: Drover already present in $appDir"
        return $true
    }

    if (-not (Test-Path -LiteralPath $cachedDll)) {
        Write-RepairLog "Repair failed: Drover cache missing at $DroverCacheDir"
        if (-not $Silent) { Write-InstallWarn $Text.MsgDroverCacheMiss }
        return $false
    }

    $wasRunning = Stop-DiscordApp

    Copy-Item -LiteralPath $cachedDll -Destination $dllPath -Force

    $cachedPacket = Join-Path $DroverCacheDir 'drover-packet.bin'
    if (Test-Path -LiteralPath $cachedPacket) {
        Copy-Item -LiteralPath $cachedPacket -Destination (Join-Path $appDir 'drover-packet.bin') -Force
    }

    $iniPath = Join-Path $appDir 'drover.ini'
    $cachedIni = Join-Path $DroverCacheDir 'drover.ini'

    if (Test-Path -LiteralPath $cachedIni) {
        Copy-Item -LiteralPath $cachedIni -Destination $iniPath -Force
    }
    else {
        Set-DroverIniContent -IniPath $iniPath
    }

    Write-RepairLog "Repaired Drover in $appDir"

    if ($wasRunning) {
        Start-DiscordApp
    }

    if (-not $Silent) {
        Write-Host ''
        Write-Host "Drover proxy set to $DroverProxy" -ForegroundColor Yellow
    }

    return $true
}

# scheduled task helpers

function Test-ScheduledTaskRegistered {
    try {
        $task = Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction Stop
        return [bool]$task
    }
    catch {
        return $false
    }
}

function New-RepairHelperScript {
    $helperPath = Join-Path $OneCordAppData 'RepairDrover.ps1'
    Ensure-Directory -Path $OneCordAppData

    $helper = @'
param(
    [int]$ProxyPort = __PROXY_PORT__
)

$ErrorActionPreference = 'Stop'
$ProxyHost = '127.0.0.1'
$DroverProxy = "socks5://$($ProxyHost):$ProxyPort"
$OneCordAppData = Join-Path $env:APPDATA 'OneCord'
$DroverCacheDir = Join-Path $OneCordAppData 'drover'
$RepairLogPath = Join-Path $OneCordAppData 'repair.log'

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-RepairLog {
    param([string]$Message)
    Ensure-Directory -Path $OneCordAppData
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $RepairLogPath -Value $line -Encoding UTF8
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

function Stop-DiscordApp {
    $processes = @(Get-Process -Name 'Discord' -ErrorAction SilentlyContinue)
    $wasRunning = @($processes).Count -gt 0

    foreach ($process in $processes) {
        try { Stop-Process -Id $process.Id -Force -ErrorAction Stop }
        catch {}
    }

    if ($wasRunning) {
        Start-Sleep -Seconds 2
    }

    return $wasRunning
}

function Start-DiscordApp {
    $updateExe = Join-Path $env:LOCALAPPDATA 'Discord\Update.exe'
    if (Test-Path -LiteralPath $updateExe) {
        Start-Process -FilePath $updateExe -ArgumentList '--processStart', 'Discord.exe' -ErrorAction SilentlyContinue | Out-Null
    }
}

function Set-DroverIniContent {
    param([string]$IniPath)

    $content = @(
        '[drover]'
        "proxy = $DroverProxy"
    ) -join "`r`n"

    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($IniPath, $content, $utf8NoBom)
}

try {
    $latest = Get-LatestDiscordAppFolder
    if (-not $latest) {
        Write-RepairLog 'Repair skipped: Discord app folder not found'
        exit 0
    }

    $appDir = $latest.FullName
    $dllPath = Join-Path $appDir 'version.dll'

    if (Test-Path -LiteralPath $dllPath) {
        Set-DroverIniContent -IniPath (Join-Path $appDir 'drover.ini')
        Write-RepairLog "OK: Drover already present in $appDir"
        exit 0
    }

    $cachedDll = Join-Path $DroverCacheDir 'version.dll'
    if (-not (Test-Path -LiteralPath $cachedDll)) {
        Write-RepairLog "Repair failed: Drover cache missing at $DroverCacheDir"
        exit 0
    }

    $wasRunning = Stop-DiscordApp

    Copy-Item -LiteralPath $cachedDll -Destination $dllPath -Force

    $cachedPacket = Join-Path $DroverCacheDir 'drover-packet.bin'
    if (Test-Path -LiteralPath $cachedPacket) {
        Copy-Item -LiteralPath $cachedPacket -Destination (Join-Path $appDir 'drover-packet.bin') -Force
    }

    $cachedIni = Join-Path $DroverCacheDir 'drover.ini'
    if (Test-Path -LiteralPath $cachedIni) {
        Copy-Item -LiteralPath $cachedIni -Destination (Join-Path $appDir 'drover.ini') -Force
    }
    else {
        Set-DroverIniContent -IniPath (Join-Path $appDir 'drover.ini')
    }

    if ($wasRunning) {
        Start-DiscordApp
    }

    Write-RepairLog "Repaired Drover in $appDir"
}
catch {
    Write-RepairLog "Repair failed: $($_.Exception.Message)"
}
'@

    $helper = $helper.Replace('__PROXY_PORT__', [string]$ProxyPort)
    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    [System.IO.File]::WriteAllText($helperPath, $helper, $utf8NoBom)

    return $helperPath
}

function Register-OneCordScheduledTask {
    if (Test-ScheduledTaskRegistered) {
        return $true
    }

    $scriptPath = $PSCommandPath

    if ($scriptPath -and (Test-Path -LiteralPath $scriptPath)) {
        $taskFile = $scriptPath
        $taskArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$taskFile`" -Action RepairDrover -ProxyPort $ProxyPort"
    }
    else {
        $taskFile = New-RepairHelperScript
        $taskArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$taskFile`" -ProxyPort $ProxyPort"
    }

    try {
        $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs

        $taskTrigger = New-ScheduledTaskTrigger `
            -Once `
            -At (Get-Date).AddMinutes(5) `
            -RepetitionInterval (New-TimeSpan -Hours 1) `
            -RepetitionDuration (New-TimeSpan -Days 3650)

        $userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name

        $taskPrincipal = New-ScheduledTaskPrincipal `
            -UserId $userId `
            -LogonType Interactive `
            -RunLevel Limited

        Register-ScheduledTask `
            -TaskName $ScheduledTaskName `
            -Action $taskAction `
            -Trigger $taskTrigger `
            -Principal $taskPrincipal `
            -Force | Out-Null

        return $true
    }
    catch {
        throw "Failed to register scheduled task: $($_.Exception.Message)"
    }
}

# install helpers

function Confirm-PrerequisitesInstall {
    Write-Host ''
    Write-Host $Text.PromptLine1
    Write-Host $Text.PromptLine2
    Write-Host $Text.PromptLine3
    Write-Host ''

    $key = [System.Console]::ReadKey($true)

    if ($key.Key -eq [System.ConsoleKey]::Q) { return $false }
    if ([char]::ToLowerInvariant($key.KeyChar) -eq 'q') { return $false }
    if ($key.Key -eq [System.ConsoleKey]::Enter) { return $true }

    return $false
}

function Test-PrerequisitesNeeded {
    if (-not (Test-WarpInstalled)) { return $true }
    if (-not (Test-WarpProxyReady)) { return $true }
    if (-not (Test-DroverInstalled)) { return $true }
    if (-not (Test-ScheduledTaskRegistered)) { return $true }

    return $false
}

function Install-Prerequisites {
    Write-Host ''

    Ensure-Directory -Path $OneCordAppData

    $msiPath = Join-Path $env:TEMP 'Cloudflare_WARP.msi'
    $droverZipPath = Join-Path $env:TEMP 'drover.zip'
    $droverZipUrl = $null
    $discordApp = $null
    $warnings = New-Object 'System.Collections.Generic.List[string]'

    if (-not (Invoke-InstallStep -Number 1 -Label $Text.StepWarpDownload -ScriptBlock {
        if (Test-WarpInstalled) { return }

        Invoke-FileDownload -Url $WarpMsiUrl -Destination $msiPath

        $hash = Get-FileSha256 -Path $msiPath
        if ($hash) {
            Write-OneCordLog -Path $InstallLogPath -Message "WARP MSI SHA256 $hash"
        }
    })) { return $false }

    if (-not (Invoke-InstallStep -Number 2 -Label $Text.StepWarpInstall -ScriptBlock {
        if (Test-WarpInstalled) { return }

        [void](Install-WarpMsi -MsiPath $msiPath)
    })) { return $false }

    if (-not (Invoke-InstallStep -Number 3 -Label $Text.StepWarpConfigure -ScriptBlock {
        if (Test-WarpProxyReady) { return }

        [void](Set-WarpProxyMode)

        if (-not (Test-WarpProxyReady)) {
            throw "WARP proxy is not listening on ${ProxyHost}:$ProxyPort"
        }
    })) { return $false }

    if (-not (Invoke-InstallStep -Number 4 -Label $Text.StepDroverFetch -ScriptBlock {
        $script:OneCordLatestDiscordApp = Get-LatestDiscordAppFolder

        if (-not $script:OneCordLatestDiscordApp) {
            $warnings.Add($Text.MsgDiscordMissing)
            return
        }

        $discordApp = $script:OneCordLatestDiscordApp

        if (Test-DroverInstalled) {
            $iniPath = Join-Path $discordApp.FullName 'drover.ini'
            Set-DroverIniContent -IniPath $iniPath

            $dllPath = Join-Path $discordApp.FullName 'version.dll'
            $packetPath = Join-Path $discordApp.FullName 'drover-packet.bin'
            $packetSource = if (Test-Path -LiteralPath $packetPath) { $packetPath } else { $null }

            Save-DroverCache -DllSource $dllPath -PacketSource $packetSource -IniPath $iniPath
            return
        }

        $droverZipUrl = Get-DroverReleaseZipUrl
        Invoke-FileDownload -Url $droverZipUrl -Destination $droverZipPath

        Write-OneCordLog -Path $InstallLogPath -Message "Drover release $droverZipUrl"

        $hash = Get-FileSha256 -Path $droverZipPath
        if ($hash) {
            Write-OneCordLog -Path $InstallLogPath -Message "Drover ZIP SHA256 $hash"
        }
    })) { return $false }

    foreach ($warning in $warnings) {
        Write-InstallWarn $warning
    }

    if (-not (Invoke-InstallStep -Number 5 -Label $Text.StepDroverInstall -ScriptBlock {
        $discordApp = Get-LatestDiscordAppFolder

        if (-not $discordApp) {
            return
        }

        if (Test-DroverInstalled) {
            $iniPath = Join-Path $discordApp.FullName 'drover.ini'
            Set-DroverIniContent -IniPath $iniPath
            return
        }

        [void](Install-DroverFromZip -ZipPath $droverZipPath -AppDir $discordApp.FullName)
    })) { return $false }

    if (-not (Invoke-InstallStep -Number 6 -Label $Text.StepTaskRegister -ScriptBlock {
        [void](Register-OneCordScheduledTask)
    })) { return $false }

    Start-Sleep -Seconds 2
    return $true
}

# status helpers

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
    Write-Host $Text.Title -ForegroundColor White
    Write-Host '------------------' -ForegroundColor DarkGray
    Write-Host ''

    if ($State.NrptActive) {
        Write-StatusLine -Level 'OK' -Label 'DNS rules' -Value 'active'
    }
    else {
        Write-StatusLine -Level 'WARN' -Label 'DNS rules' -Value 'inactive'
    }

    if (-not $State.Warp.Installed) {
        Write-StatusLine -Level 'FAIL' -Label 'WARP' -Value 'not installed'
    }
    elseif ($State.Warp.Connected) {
        Write-StatusLine -Level 'OK' -Label 'WARP' -Value 'connected'
    }
    else {
        Write-StatusLine -Level 'WARN' -Label 'WARP' -Value 'installed'
    }

    if (-not $State.Warp.Installed) {
        Write-StatusLine -Level 'WARN' -Label 'Proxy' -Value 'unavailable'
    }
    elseif ($State.Warp.ProxyListening) {
        Write-StatusLine -Level 'OK' -Label 'Proxy' -Value "$ProxyHost`:$ProxyPort"
    }
    elseif ($State.Warp.ProxyPort -and $State.Warp.ProxyPort -ne $ProxyPort) {
        Write-StatusLine -Level 'WARN' -Label 'Proxy' -Value "port $($State.Warp.ProxyPort)"
    }
    else {
        Write-StatusLine -Level 'WARN' -Label 'Proxy' -Value 'not listening'
    }

    if ($State.Drover.Loaded) {
        Write-StatusLine -Level 'OK' -Label 'Drover' -Value 'loaded'
    }
    elseif ($State.Drover.InstalledInLatest -and $State.DiscordRunning) {
        Write-StatusLine -Level 'WARN' -Label 'Drover' -Value 'restart Discord'
    }
    elseif ($State.Drover.InstalledInLatest) {
        Write-StatusLine -Level 'OK' -Label 'Drover' -Value 'installed'
    }
    elseif ($State.Drover.Installed) {
        Write-StatusLine -Level 'WARN' -Label 'Drover' -Value 'repair after update'
    }
    else {
        Write-StatusLine -Level 'WARN' -Label 'Drover' -Value 'not installed'
    }

    if ($State.DiscordRunning) {
        Write-StatusLine -Level 'OK' -Label 'Discord' -Value 'running'
    }
    else {
        Write-StatusLine -Level 'WARN' -Label 'Discord' -Value 'closed'
    }

    if ($State.Drover.ConfigProxy -eq $DroverProxy) {
        Write-StatusLine -Level 'OK' -Label 'Route' -Value $DroverProxy
    }
    elseif ($State.Drover.ConfigProxy) {
        Write-StatusLine -Level 'WARN' -Label 'Route' -Value $State.Drover.ConfigProxy
    }
    else {
        Write-StatusLine -Level 'WARN' -Label 'Route' -Value 'not configured'
    }

    Write-Host ''
}

function Show-Hints {
    param($State)

    $hints = New-Object 'System.Collections.Generic.List[object]'

    if (-not $State.Warp.Installed) {
        $hints.Add([pscustomobject]@{ Text = 'Install WARP or run OneCord prerequisites'; Color = 'Yellow' })
    }
    elseif (-not $State.Warp.ProxyListening) {
        $hints.Add([pscustomobject]@{ Text = 'Run OneCord again and let it configure WARP proxy mode'; Color = 'Yellow' })
    }

    if (-not $State.Drover.InstalledInLatest) {
        $hints.Add([pscustomobject]@{ Text = 'Run Repair Drover config after Discord updates'; Color = 'Yellow' })
    }
    elseif ($State.Drover.ConfigProxy -ne $DroverProxy) {
        $hints.Add([pscustomobject]@{ Text = 'Run Repair Drover config'; Color = 'Yellow' })
    }

    if ($hints.Count -eq 0) { return }

    Write-Host ''

    foreach ($hint in $hints) {
        Write-Host $hint.Text -ForegroundColor $hint.Color
    }
}

# actions

function Enable-Setup {
    Set-DiscordNrptRules

    if (Get-WarpCliPath) {
        try {
            if (-not (Test-WarpProxyReady)) {
                [void](Set-WarpProxyMode)
            }
        }
        catch {
            Write-Warn $_.Exception.Message
        }
    }

    [void](Repair-DroverConfig -Quiet)

    $state = Get-CurrentState
    Show-Status -State $state
    Show-Hints -State $state
}

function Disable-Setup {
    [void](Remove-DiscordNrptRules)

    if (-not $KeepWarpConnectedOnDisable -and (Get-WarpCliPath)) {
        [void](Invoke-WarpAny -CommandLines @('disconnect') -IgnoreFailure)
        [void](Invoke-WarpAny -CommandLines @('mode warp', 'set-mode warp') -IgnoreFailure)
    }

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
            $drover = Get-DroverInfo

            if ($drover.InstalledInLatest) {
                $repaired = Repair-DroverConfig
                Show-Status -State (Get-CurrentState)

                if ($repaired) {
                    Write-Host ''
                    Write-Host "Drover proxy set to $DroverProxy" -ForegroundColor Yellow
                }
            }
            else {
                [void](Repair-Drover)
                Show-Status -State (Get-CurrentState)
            }

            return $true
        }
        'Exit' {
            return $false
        }
        default {
            Write-Bad $Text.MsgInvalidChoice
            return $true
        }
    }
}

function Show-Menu {
    try { $Host.UI.RawUI.WindowTitle = $Text.Title } catch {}

    $entries = [ordered]@{
        'Enable Discord WARP route' = 'Enable'
        'Disable Discord WARP route' = 'Disable'
        'Show current status'        = 'Status'
        'Repair Drover config'      = 'RepairDrover'
        'Exit'                      = 'Exit'
    }

    while ($true) {
        $selected = Write-Menu -Title $Text.Title -Entries $entries

        if ([string]::IsNullOrWhiteSpace($selected)) {
            return
        }

        $continueMenu = Invoke-MenuAction -SelectedAction $selected
        if (-not $continueMenu) { return }

        Pause-Key
    }
}

# main

if ($Action -eq 'RepairDrover') {
    [void](Repair-Drover -Silent)
    exit 0
}

Assert-Administrator

switch ($Action) {
    'Menu' {
        if (Test-PrerequisitesNeeded) {
            if (-not (Confirm-PrerequisitesInstall)) { exit 0 }
            if (-not (Install-Prerequisites)) { exit 1 }
        }

        Show-Menu
    }
    'Enable' {
        Enable-Setup
    }
    'Disable' {
        Disable-Setup
    }
    'Status' {
        Show-Status -State (Get-CurrentState)
        Show-Hints -State (Get-CurrentState)
    }
}
