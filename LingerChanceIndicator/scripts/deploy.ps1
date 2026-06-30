# Deploys the mod into the game's AngelScript mods folder.
# Edit $GameModsDir if your Steam library lives elsewhere.
# Usage:  ./scripts/deploy.ps1

$ErrorActionPreference = 'Stop'

$GameModsDir = 'Z:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source   = Join-Path $RepoRoot 'Mods\LingerChanceIndicator.as'

if (-not (Test-Path $GameModsDir)) {
    Write-Error "Game mods folder not found: $GameModsDir`nEdit `$GameModsDir in this script to match your install."
}

Copy-Item -Path $Source -Destination $GameModsDir -Force
Write-Host "Deployed LingerChanceIndicator.as -> $GameModsDir"
Write-Host "Now fully restart the game so AngelScript recompiles the mods."
