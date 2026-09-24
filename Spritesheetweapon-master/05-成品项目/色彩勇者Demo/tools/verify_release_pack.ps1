param(
    [Parameter(Mandatory = $true)]
    [string]$PackPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedPack = Resolve-Path -LiteralPath $PackPath -ErrorAction Stop
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPack.Path)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName })
    $forbidden = @(
        "tests/*",
        "tools/*",
        "--/*",
        "assets/audio/bg.ogg",
        "assets/audio/bg.ogg.import",
        ".godot/imported/bg.ogg-*"
    )
    $leaks = @($entries | Where-Object {
        $entry = $_
        $forbidden | Where-Object { $entry -like $_ }
    })
    $required = @(
        "project.binary",
        "scripts/Main.gdc",
        "scripts/GameManager.gdc"
    )
    $missing = @($required | Where-Object { $_ -notin $entries })
    $mainSceneExports = @($entries | Where-Object { $_ -like ".godot/exported/*/export-*-Main.scn" })

    Write-Host "PACK=$($resolvedPack.Path)"
    Write-Host "ENTRY_COUNT=$($entries.Count)"
    Write-Host "FORBIDDEN_LEAKS=$($leaks.Count)"
    Write-Host "MISSING_REQUIRED=$($missing.Count)"
    Write-Host "MAIN_SCENE_EXPORTS=$($mainSceneExports.Count)"
    if ($leaks.Count -gt 0) {
        Write-Host ("LEAKED_ENTRIES=" + ($leaks -join ",")) -ForegroundColor Red
    }
    if ($missing.Count -gt 0) {
        Write-Host ("MISSING_ENTRIES=" + ($missing -join ",")) -ForegroundColor Red
    }
    if ($leaks.Count -gt 0 -or $missing.Count -gt 0 -or $mainSceneExports.Count -ne 1) {
        if ($mainSceneExports.Count -ne 1) {
            Write-Host "MAIN_SCENE_EXPORT_ENTRIES=$($mainSceneExports -join ',')" -ForegroundColor Red
        }
        exit 1
    }
    Write-Host "PASS release pack manifest" -ForegroundColor Green
} finally {
    $archive.Dispose()
}
