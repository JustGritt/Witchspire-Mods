# Installs (or reverts) the "Skip Intro Movies" config override for Witchspire.
#
# Witchspire plays its startup logos via Unreal's engine MoviePlayer at launch,
# BEFORE the AngelScript mods load -- so this can't be a .as mod. Instead it drops
# a user-layer Game.ini that clears the startup-movie list, which boots the game
# straight to the menu. The user config layer overrides the packaged DefaultGame.ini.
#
# The override is written between managed markers, so applying is idempotent and
# reverting removes ONLY our block (any settings you added yourself are left alone).
#
# Usage:
#   ./scripts/skip-intro.ps1            # apply (boot straight to menu)
#   ./scripts/skip-intro.ps1 -Revert    # restore the intro movies
#
# Edit $ConfigDir below if your Steam library lives elsewhere.

param(
    [switch]$Revert
)

$ErrorActionPreference = 'Stop'

# The game's USER config folder. Witchspire (UE5) resolves its writable Saved
# dir to %LOCALAPPDATA%\Hercules\Saved -- that's where GameUserSettings.ini lives
# and where Unreal reads the user-layer Game.ini that overrides the packaged
# DefaultGame.ini. (The install's Hercules\Saved holds only SaveGames and is NOT
# read for config.) Override this if your build puts user config elsewhere.
$ConfigDir = Join-Path $env:LOCALAPPDATA 'Hercules\Saved\Config\Windows'
$TargetIni = Join-Path $ConfigDir 'Game.ini'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source   = Join-Path $RepoRoot 'SkipIntroMovies\Game.ini'

$BeginMarker = '; >>> Witchspire SkipIntroMovies (managed - do not edit between markers) >>>'
$EndMarker   = '; <<< Witchspire SkipIntroMovies (managed) <<<'

# Remove any previously-installed managed block from existing ini text.
function Remove-ManagedBlock([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return '' }
    $pattern = [regex]::Escape($BeginMarker) + '.*?' + [regex]::Escape($EndMarker)
    $stripped = [regex]::Replace($text, $pattern, '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return $stripped.Trim()
}

$existing = ''
if (Test-Path $TargetIni) {
    $existing = [System.IO.File]::ReadAllText($TargetIni)
}

if ($Revert) {
    if (-not (Test-Path $TargetIni)) {
        Write-Host "Nothing to revert: $TargetIni does not exist."
        return
    }
    $cleaned = Remove-ManagedBlock $existing
    if ([string]::IsNullOrWhiteSpace($cleaned)) {
        Remove-Item -Path $TargetIni -Force
        Write-Host "Reverted: removed $TargetIni (it held only our override)."
    } else {
        [System.IO.File]::WriteAllText($TargetIni, $cleaned + "`r`n")
        Write-Host "Reverted: stripped the SkipIntroMovies block from $TargetIni (your other settings kept)."
    }
    Write-Host "Restart the game; the intro movies will play again."
    return
}

# --- Apply ---
if (-not (Test-Path $Source)) {
    Write-Error "Override source not found: $Source"
}
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

$body  = ([System.IO.File]::ReadAllText($Source)).Trim()
$block = "$BeginMarker`r`n$body`r`n$EndMarker"

$base = Remove-ManagedBlock $existing   # drop a prior copy so re-running is idempotent
if ([string]::IsNullOrWhiteSpace($base)) {
    $out = $block + "`r`n"
} else {
    $out = $base + "`r`n`r`n" + $block + "`r`n"
}

# UTF-8 without BOM -- a BOM can trip Unreal's ini parser on the first section.
[System.IO.File]::WriteAllText($TargetIni, $out)
Write-Host "Applied SkipIntroMovies override -> $TargetIni"
Write-Host "Restart the game; it should boot straight to the main menu."
