$ErrorActionPreference = "Stop"

$workDir = "D:\GodotGameDemo\ColorMatch-3\production\gameplay-design"
$docxPath = (Get-ChildItem -LiteralPath $workDir -Filter "*.docx" | Select-Object -First 1).FullName
$pdfPath = Join-Path $workDir "rendered_word\qa_export.pdf"

if (-not $docxPath) {
    throw "No DOCX file found in $workDir"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pdfPath) | Out-Null

$word = $null
$doc = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $doc = $word.Documents.Open($docxPath, $false, $true)
    $doc.ExportAsFixedFormat($pdfPath, 17)
}
finally {
    if ($doc -ne $null) {
        $doc.Close($false)
    }
    if ($word -ne $null) {
        $word.Quit()
    }
}

Write-Output $pdfPath
