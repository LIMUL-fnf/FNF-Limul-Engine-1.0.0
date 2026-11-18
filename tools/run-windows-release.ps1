$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

$lime = Get-Command lime.exe -ErrorAction Stop
& $lime.Source build windows -release
if ($LASTEXITCODE -ne 0) {
    throw "Lime release build failed with exit code $LASTEXITCODE."
}

$gamePath = Join-Path $projectRoot 'export\release\windows\bin\FNFLimulEngine.exe'
if (-not (Test-Path -LiteralPath $gamePath -PathType Leaf)) {
    throw "Release executable was not created: $gamePath"
}

Start-Process -FilePath $gamePath -WorkingDirectory (Split-Path -Parent $gamePath)
