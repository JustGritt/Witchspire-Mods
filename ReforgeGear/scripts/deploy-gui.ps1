# Reforge Gear -- CHEAT GUI edition (ImGui debug panel, F7; auto Developer Mode).
# Shared logic and the $GameModsDir path live in scripts/_deploy-common.ps1.
# Usage:  ./scripts/deploy-gui.ps1

. "$PSScriptRoot\_deploy-common.ps1"
Deploy-ReforgeEdition -Install 'ReforgeCheatGui.as' -ScriptsDir $PSScriptRoot
