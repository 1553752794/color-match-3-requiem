param(
    [string]$GodotCommand = "godot",
    [string]$AudioDriver = "Dummy"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$arguments = @("--path", $projectRoot, "--editor")
if ($AudioDriver -ne "") {
    $arguments = @("--audio-driver", $AudioDriver) + $arguments
}

& $GodotCommand @arguments
exit $LASTEXITCODE
