# God Forge -- grant any gear with hand-picked substats (ImGui panel, F8).
# Unlike the Reforge editions, God Forge uses entirely distinct class names and
# the F8 hotkey, so it installs ALONGSIDE any Reforge edition (or on its own).
# The $GameModsDir path lives in scripts/_deploy-common.ps1.
# Usage:  ./scripts/deploy-godforge.ps1

. "$PSScriptRoot\_deploy-common.ps1"

$Source = Join-Path (Split-Path -Parent $PSScriptRoot) 'Mods\GodForge.as'
if (-not (Test-Path $Source)) {
    Write-Error "Mod source not found: $Source"
}
if (-not (Test-Path $GameModsDir)) {
    Write-Error "Game mods folder not found: $GameModsDir`nEdit `$GameModsDir in scripts/_deploy-common.ps1 to match your install."
}

Copy-Item -Path $Source -Destination $GameModsDir -Force
Write-Host "Deployed GodForge.as (grant gear with chosen substats, F8) -> $GameModsDir"
Write-Host "Runs alongside any Reforge edition. Now fully restart the game so AngelScript recompiles."
