#Requires -Version 5.1
<#
Builds Aerox9_LayerOverlay.ahk into a standalone EXE and packages it into an
Inno Setup installer under dist\. Run from the repo root or anywhere - paths
are resolved relative to this script's location.
#>
param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$DistDir = Join-Path $RepoRoot "dist"
$StageDir = Join-Path $DistDir "stage"

function Find-Tool {
    param([string[]]$CandidatePaths, [string]$CommandName, [string]$FriendlyName)

    foreach ($path in $CandidatePaths) {
        if (Test-Path $path) { return $path }
    }

    $onPath = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    throw "Could not find $FriendlyName. Looked in: `n$($CandidatePaths -join "`n")`nand on PATH as '$CommandName'."
}

$Ahk2Exe = Find-Tool -CandidatePaths @(
    "$env:LOCALAPPDATA\Aerox9BuildTools\Ahk2Exe\Ahk2Exe.exe",
    "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
) -CommandName "Ahk2Exe.exe" -FriendlyName "Ahk2Exe compiler"

$AhkBase = Find-Tool -CandidatePaths @(
    "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
) -CommandName "AutoHotkey64.exe" -FriendlyName "AutoHotkey v2 runtime (base file)"

$Iscc = Find-Tool -CandidatePaths @(
    "$env:LOCALAPPDATA\Aerox9BuildTools\InnoSetup6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
) -CommandName "ISCC.exe" -FriendlyName "Inno Setup compiler (ISCC.exe)"

Write-Host "Using Ahk2Exe: $Ahk2Exe"
Write-Host "Using AHK base: $AhkBase"
Write-Host "Using ISCC:    $Iscc"

Write-Host "`nCleaning stage directory..."
if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $StageDir "Thumbnails") | Out-Null

Write-Host "Staging release files..."
Copy-Item (Join-Path $RepoRoot "README.md") (Join-Path $StageDir "README.md") -Force
Copy-Item (Join-Path $RepoRoot "Aerox9Layers.default.ini") (Join-Path $StageDir "Aerox9Layers.default.ini") -Force
Copy-Item (Join-Path $RepoRoot "Thumbnails\*") (Join-Path $StageDir "Thumbnails") -Recurse -Force

Write-Host "`nCompiling Aerox9_LayerOverlay.ahk -> EXE..."
$ScriptPath = Join-Path $RepoRoot "Aerox9_LayerOverlay.ahk"
$ExePath = Join-Path $StageDir "Aerox9_LayerOverlay.exe"

if (Test-Path $ExePath) { Remove-Item -Force $ExePath }

# Ahk2Exe does not block or report a usable exit code under Start-Process (it
# hands off to a helper process), so invoke it directly and poll for the
# output file instead of trusting its exit code.
& $Ahk2Exe /in $ScriptPath /out $ExePath /base $AhkBase

$waited = 0
while (-not (Test-Path $ExePath) -and $waited -lt 60) {
    Start-Sleep -Milliseconds 500
    $waited += 0.5
}
if (-not (Test-Path $ExePath)) { throw "Ahk2Exe did not produce $ExePath within 60 seconds." }
Write-Host "Compiled: $ExePath"

Write-Host "`nBuilding installer with Inno Setup..."
$InstallerScript = Join-Path $RepoRoot "installer\installer.iss"
& $Iscc "/DMyAppVersion=$Version" $InstallerScript
if ($LASTEXITCODE -ne 0) { throw "ISCC build failed (exit $LASTEXITCODE)." }

$InstallerExe = Join-Path $DistDir "Aerox9LayerManagerSetup.exe"
if (-not (Test-Path $InstallerExe)) { throw "ISCC reported success but $InstallerExe was not produced." }

Write-Host "`nRelease build complete:"
Write-Host "  EXE:       $ExePath"
Write-Host "  Installer: $InstallerExe"
