# Reforge Gear -- FULL edition (altar F9 + ImGui panel F7).
# Shared logic and the $GameModsDir path live in scripts/_deploy-common.ps1.
# Usage:  ./scripts/deploy.ps1

. "$PSScriptRoot\_deploy-common.ps1"
Deploy-ReforgeEdition -Install 'ReforgeGear.as' -ScriptsDir $PSScriptRoot
