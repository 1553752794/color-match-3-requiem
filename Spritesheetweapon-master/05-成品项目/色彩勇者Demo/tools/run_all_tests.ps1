param(
    [string]$GodotCommand = "godot",
    [string]$TestPattern = "*.gd",
    [switch]$SkipEditorCheck,
    [string]$ProfileRoot = "",
    [string]$AudioDriver = "Dummy"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$failures = [System.Collections.Generic.List[string]]::new()
$profileRootPath = if ($ProfileRoot -ne "") {
    $resolvedProfileRoot = Resolve-Path -LiteralPath $ProfileRoot -ErrorAction SilentlyContinue
    if ($null -eq $resolvedProfileRoot) {
        New-Item -ItemType Directory -Force -Path $ProfileRoot | Out-Null
        (Resolve-Path -LiteralPath $ProfileRoot).Path
    } else {
        $resolvedProfileRoot.Path
    }
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) "ColorMatch3-test-profiles"
}
New-Item -ItemType Directory -Force -Path $profileRootPath | Out-Null

function Invoke-GodotChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    Write-Host "RUN $Label"
	$previousPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	$effectiveArguments = if ($AudioDriver -ne "") {
		@("--audio-driver", $AudioDriver) + $Arguments
	} else {
		$Arguments
	}
	$lines = @(& $GodotCommand @effectiveArguments 2>&1)
	$exitCode = $LASTEXITCODE
	$ErrorActionPreference = $previousPreference
    $lines | ForEach-Object { Write-Host $_ }

    $engineErrors = @($lines | Where-Object {
        $text = [string]$_
        $startup_noise = $text -match "EditorSettings not instantiated yet when getting setting"
        (-not $startup_noise) -and (
            $text -match "SCRIPT ERROR:" -or
            $text -match "(^|\s)ERROR:\s" -or
            $text -match "signal 11" -or
            $text -match "access violation" -or
            $text -match "Godot Engine.*crashed"
        )
    })
    if ($exitCode -ne 0 -or $engineErrors.Count -gt 0) {
        $failures.Add($Label)
        Write-Host "FAIL $Label (exit=$exitCode, engine_errors=$($engineErrors.Count))" -ForegroundColor Red
        return
    }
    Write-Host "PASS $Label" -ForegroundColor Green
}

if (-not $SkipEditorCheck) {
    $editorProfile = Join-Path $profileRootPath "editor-parse"
    New-Item -ItemType Directory -Force -Path $editorProfile | Out-Null
    $previousAppData = $env:APPDATA
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:APPDATA = $editorProfile
        $env:LOCALAPPDATA = $editorProfile
        Invoke-GodotChecked -Label "editor-parse" -Arguments @(
            "--headless", "--disable-crash-handler", "--path", $projectRoot, "--editor", "--quit"
        )
    } finally {
        $env:APPDATA = $previousAppData
        $env:LOCALAPPDATA = $previousLocalAppData
    }
}

$tests = @(Get-ChildItem (Join-Path $projectRoot "tests") -Filter $TestPattern | Sort-Object Name)
foreach ($test in $tests) {
    $testProfile = Join-Path $profileRootPath ([System.IO.Path]::GetFileNameWithoutExtension($test.Name))
    New-Item -ItemType Directory -Force -Path $testProfile | Out-Null
    $previousAppData = $env:APPDATA
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:APPDATA = $testProfile
        $env:LOCALAPPDATA = $testProfile
        Invoke-GodotChecked -Label $test.Name -Arguments @(
            "--headless", "--disable-crash-handler", "--path", $projectRoot, "--script", "res://tests/$($test.Name)"
        )
    } finally {
        $env:APPDATA = $previousAppData
        $env:LOCALAPPDATA = $previousLocalAppData
    }
}

Write-Host "TOTAL=$($tests.Count) FAILED=$($failures.Count)"
if ($failures.Count -gt 0) {
    Write-Host "FAILED_TESTS=$($failures -join ',')" -ForegroundColor Red
    exit 1
}
exit 0
