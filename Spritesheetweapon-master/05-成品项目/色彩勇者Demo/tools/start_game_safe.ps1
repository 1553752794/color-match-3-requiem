param(
    [string]$ExecutablePath = "",
    [string]$AudioDriver = "Dummy"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($ExecutablePath -eq "") {
    $ExecutablePath = Join-Path $projectRoot "build\windows\ColorHero-Match3Requiem-2.3.0.exe"
}
$resolvedExecutable = (Resolve-Path -LiteralPath $ExecutablePath).Path
$arguments = @()
if ($AudioDriver -ne "") {
    $arguments = @("--audio-driver", $AudioDriver)
}

Start-Process -FilePath $resolvedExecutable -WorkingDirectory (Split-Path $resolvedExecutable) -ArgumentList $arguments
