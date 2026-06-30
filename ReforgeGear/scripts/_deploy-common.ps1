# Shared deploy logic for the Reforge Gear editions. Dot-sourced by deploy.ps1,
# deploy-altar.ps1 and deploy-gui.ps1 -- so the $GameModsDir path and the install
# logic live in ONE place. Edit $GameModsDir below if your Steam library is elsewhere.

$ErrorActionPreference = 'Stop'

$GameModsDir = 'Z:\Program Files (x86)\Steam\steamapps\common\Witchspire\Hercules\Script\Mods'

# Filename -> short description. Exactly one edition is installed at a time; the
# others are removed from the game folder so only one ever compiles.
$ReforgeEditions = [ordered]@{
    'ReforgeGear.as'     = 'full edition: altar F9 + GUI F7'
    'ReforgeAltar.as'    = 'altar edition: summon F9, reforge with Interact'
    'ReforgeCheatGui.as' = 'cheat GUI edition: open panel with F7'
}

function Deploy-ReforgeEdition {
    param(
        [Parameter(Mandatory)] [string] $Install,    # which edition's .as to install
        [Parameter(Mandatory)] [string] $ScriptsDir  # the calling wrapper's $PSScriptRoot
    )

    if (-not $ReforgeEditions.Contains($Install)) {
        Write-Error "Unknown edition '$Install'. Known: $($ReforgeEditions.Keys -join ', ')"
    }
    if (-not (Test-Path $GameModsDir)) {
        Write-Error "Game mods folder not found: $GameModsDir`nEdit `$GameModsDir in scripts/_deploy-common.ps1 to match your install."
    }

    $Source = Join-Path (Split-Path -Parent $ScriptsDir) "Mods\$Install"
    if (-not (Test-Path $Source)) {
        Write-Error "Mod source not found: $Source"
    }

    foreach ($Other in $ReforgeEditions.Keys) {
        if ($Other -eq $Install) { continue }
        $p = Join-Path $GameModsDir $Other
        if (Test-Path $p) { Remove-Item $p -Force; Write-Host "Removed other edition: $Other" }
    }

    Copy-Item -Path $Source -Destination $GameModsDir -Force
    Write-Host "Deployed $Install ($($ReforgeEditions[$Install])) -> $GameModsDir"
    Write-Host "Now fully restart the game so AngelScript recompiles the mods."
}
