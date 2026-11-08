# Construit l'installeur Windows de TimeLog (NSIS).
#
# À lancer SUR WINDOWS (Flutter ne compile pas l'application Windows depuis Linux).
# Prérequis : Flutter, Visual Studio 2022 (charge « Développement Desktop en C++ »), NSIS 3.x.
#
# Usage (PowerShell, depuis n'importe où) :
#   powershell -ExecutionPolicy Bypass -File packaging\windows\build-windows.ps1
#   powershell -ExecutionPolicy Bypass -File packaging\windows\build-windows.ps1 -SkipFlutter
#
# Résultat : packaging\dist\timelog-<version>-setup-x64.exe

[CmdletBinding()]
param(
    [switch]$SkipFlutter
)

$ErrorActionPreference = 'Stop'

function Write-Step($message) { Write-Host "==> $message" -ForegroundColor Cyan }

$Here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root    = (Resolve-Path (Join-Path $Here '..\..')).Path
$App     = Join-Path $Root 'app'
$Release = Join-Path $App 'build\windows\x64\runner\Release'
$Dist    = Join-Path $Here '..\dist'
$Script  = Join-Path $Here 'timelog.nsi'

# Version : « version: 1.1.0+2 » dans pubspec.yaml -> 1.1.0
$match = Select-String -Path (Join-Path $App 'pubspec.yaml') -Pattern '^version:\s*([0-9][^+\s]*)' | Select-Object -First 1
if (-not $match) { throw "Version introuvable dans app\pubspec.yaml" }
$Version = $match.Matches[0].Groups[1].Value
Write-Step "TimeLog $Version"

if (-not $SkipFlutter) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw "flutter introuvable dans le PATH" }
    Write-Step "Compilation Flutter (Windows, release)"
    Push-Location $App
    try { & flutter build windows --release; if ($LASTEXITCODE -ne 0) { throw "flutter build windows a échoué" } }
    finally { Pop-Location }
}

if (-not (Test-Path (Join-Path $Release 'timelog.exe'))) {
    throw "Build introuvable : $Release\timelog.exe (lancer sans -SkipFlutter)"
}

# Localiser makensis : PATH, puis les emplacements d'installation habituels.
$makensis = (Get-Command makensis -ErrorAction SilentlyContinue).Source
if (-not $makensis) {
    foreach ($candidate in @(
        "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
        "${env:ProgramFiles}\NSIS\makensis.exe")) {
        if ($candidate -and (Test-Path $candidate)) { $makensis = $candidate; break }
    }
}
if (-not $makensis) { throw "makensis introuvable : installer NSIS (https://nsis.sourceforge.io) ou ajouter NSIS au PATH" }

New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$DistFull = (Resolve-Path $Dist).Path

Write-Step "Création de l'installeur avec NSIS"
& $makensis "/DAPP_VERSION=$Version" "/DSOURCE_DIR=$Release" "/DOUTPUT_DIR=$DistFull" $Script
if ($LASTEXITCODE -ne 0) { throw "makensis a échoué (code $LASTEXITCODE)" }

$Setup = Join-Path $DistFull "timelog-$Version-setup-x64.exe"
Write-Step "-> $Setup"
