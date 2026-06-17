#Requires -Version 5.1
param(
    [switch]$Native
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = $PSScriptRoot
$Dist = Join-Path $Root 'dist'
$Assets = Join-Path $Root 'assets'
$InstallerDir = Join-Path $Root 'installer'
$NativeDir = Join-Path $Root 'native'

$UpstreamZip = Join-Path $env:TEMP 'drover-v0.9.zip'
$UpstreamDir = Join-Path $env:TEMP 'drover-v0.9\drover'
$ReleaseUrl = 'https://github.com/hdrover/discord-drover/releases/download/v0.9/drover-v0.9.zip'

function Write-PatchedUnicodeString {
    param([byte[]]$Bytes, [int]$Offset, [string]$NewValue)

    $lengthOffset = $Offset - 4
    $oldLen = [BitConverter]::ToInt32($Bytes, $lengthOffset)
    if ($NewValue.Length -gt ($oldLen + 2)) {
        throw "Not enough padding to patch '$NewValue' at offset $Offset"
    }

    [BitConverter]::GetBytes([int32]$NewValue.Length).CopyTo($Bytes, $lengthOffset)
    $encoded = [Text.Encoding]::Unicode.GetBytes($NewValue)
    [Array]::Copy($encoded, 0, $Bytes, $Offset, $encoded.Length)
}

function Get-PatchedDroverBinary {
    param([string]$SourcePath)

    $bytes = [IO.File]::ReadAllBytes($SourcePath)

    $iniPattern = [Text.Encoding]::Unicode.GetBytes('drover.ini')
    $iniOffsets = @()
    for ($i = 0; $i -le $bytes.Length - $iniPattern.Length; $i++) {
        $match = $true
        for ($j = 0; $j -lt $iniPattern.Length; $j++) {
            if ($bytes[$i + $j] -ne $iniPattern[$j]) { $match = $false; break }
        }
        if ($match) { $iniOffsets += $i }
    }
    foreach ($offset in $iniOffsets) {
        Write-PatchedUnicodeString -Bytes $bytes -Offset $offset -NewValue 'onecord.ini'
    }

    # UTF-16 "drover" section header: 4-byte length + wchar string
    $sectionPattern = [byte[]](0x06, 0, 0, 0, 0x64, 0, 0x72, 0, 0x6F, 0, 0x76, 0, 0x65, 0, 0x72, 0)
    for ($i = 0; $i -le $bytes.Length - $sectionPattern.Length; $i++) {
        $match = $true
        for ($j = 0; $j -lt $sectionPattern.Length; $j++) {
            if ($bytes[$i + $j] -ne $sectionPattern[$j]) { $match = $false; break }
        }
        if ($match) {
            Write-PatchedUnicodeString -Bytes $bytes -Offset ($i + 4) -NewValue 'onecord'
            break
        }
    }

    return $bytes
}

function Ensure-UpstreamBinaries {
    if (Test-Path -LiteralPath (Join-Path $UpstreamDir 'version.dll')) { return }

    Write-Host 'Downloading drover v0.9...' -ForegroundColor Yellow
    Invoke-WebRequest -Uri $ReleaseUrl -OutFile $UpstreamZip -UseBasicParsing
    $extractRoot = Split-Path -Parent $UpstreamDir
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    Expand-Archive -Path $UpstreamZip -DestinationPath $extractRoot -Force
}

function Build-Installer {
    param([string]$OutputExe)

    $proj = Join-Path $InstallerDir 'OneCord.Installer.csproj'
    if (-not (Test-Path -LiteralPath $proj)) { throw "Missing $proj" }

    dotnet publish $proj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o (Join-Path $InstallerDir 'publish')
    if ($LASTEXITCODE -ne 0) { throw 'dotnet publish failed' }

    $built = Join-Path $InstallerDir 'publish\Installer.exe'
    if (-not (Test-Path -LiteralPath $built)) { throw 'Installer.exe not found after publish' }
    Copy-Item -LiteralPath $built -Destination $OutputExe -Force
}

function Build-NativeDll {
    param([string]$OutputDll)

    $cmake = Get-Command cmake -ErrorAction SilentlyContinue
    if (-not $cmake) { return $false }

    $buildDir = Join-Path $NativeDir 'build'
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

    & cmake -S $NativeDir -B $buildDir -A x64
    if ($LASTEXITCODE -ne 0) { return $false }

    & cmake --build $buildDir --config Release
    if ($LASTEXITCODE -ne 0) { return $false }

    $candidates = @(
        (Join-Path $buildDir 'bin\Release\version.dll'),
        (Join-Path $buildDir 'bin\version.dll'),
        (Join-Path $buildDir 'Release\version.dll')
    )
    $built = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    if (-not $built) {
        $built = Get-ChildItem -LiteralPath $buildDir -Recurse -Filter 'version.dll' -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 4096 } |
            Sort-Object Length -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $built -or -not (Test-Path -LiteralPath $built)) { return $false }
    if ((Get-Item -LiteralPath $built).Length -lt 4096) { return $false }

    Copy-Item -LiteralPath $built -Destination $OutputDll -Force
    return $true
}

function Install-PatchedDroverDll {
    param([string]$OutputDll)

    Ensure-UpstreamBinaries
    $patched = Get-PatchedDroverBinary -SourcePath (Join-Path $UpstreamDir 'version.dll')
    [IO.File]::WriteAllBytes($OutputDll, $patched)
}

Write-Host 'Building OneCord...' -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

Write-Host '[1/3] Installer' -ForegroundColor Yellow
Build-Installer -OutputExe (Join-Path $Dist 'Installer.exe')

Write-Host '[2/3] version.dll' -ForegroundColor Yellow
$dllOut = Join-Path $Dist 'version.dll'
if ($Native -and (Build-NativeDll -OutputDll $dllOut)) {
    Write-Host '  built native DLL' -ForegroundColor Yellow
} else {
    if ($Native) {
        Write-Host '  native build failed, using patched drover' -ForegroundColor Yellow
    } else {
        Write-Host '  patched drover' -ForegroundColor Green
    }
    Install-PatchedDroverDll -OutputDll $dllOut
}

Write-Host '[3/3] Assets' -ForegroundColor Yellow
Copy-Item -LiteralPath (Join-Path $Assets 'onecord.ini') -Destination (Join-Path $Dist 'onecord.ini') -Force

$packet = Join-Path $Assets 'onecord-packet.bin'
if (-not (Test-Path -LiteralPath $packet)) { $packet = Join-Path $UpstreamDir 'drover-packet.bin' }
if (Test-Path -LiteralPath $packet) {
    Copy-Item -LiteralPath $packet -Destination (Join-Path $Dist 'drover-packet.bin') -Force
}

$zipPath = Join-Path $Root 'release.zip'
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $Dist '*') -DestinationPath $zipPath -Force

Write-Host ''
Write-Host 'Done:' -ForegroundColor Green
Get-ChildItem -LiteralPath $Dist | Format-Table Name, Length -AutoSize
Write-Host "ZIP: $zipPath"
