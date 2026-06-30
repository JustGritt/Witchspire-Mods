# Reforge Gear -- ALTAR edition (summon altar F9, reforge with Interact; no Dev Mode).
# Shared logic and the $GameModsDir path live in scripts/_deploy-common.ps1.
# Usage:  ./scripts/deploy-altar.ps1

. "$PSScriptRoot\_deploy-common.ps1"
Deploy-ReforgeEdition -Install 'ReforgeAltar.as' -ScriptsDir $PSScriptRoot
