<#
.SYNOPSIS
    Converts a .docx file to Markdown and integrates it into the DocFX project.

.DESCRIPTION
    Uses Pandoc to convert a Word document (.docx) to GitHub-Flavored Markdown (GFM),
    extracts embedded images to the /images folder, fixes image paths, and updates
    the appropriate app toc.yml automatically.

    Filename convention: <version>_<appname>.docx
    Examples:
      1_5_1068_0_innovera.docx → articles/innovera/1_5_1068_0_innovera.md (toc title: 1.5.1068.0)
      1_5_1068_0_mydata.docx   → articles/mydata/1_5_1068_0_mydata.md     (toc title: 1.5.1068.0)
      2_0_0_0_premium.docx     → articles/premium/2_0_0_0_premium.md      (toc title: 2.0.0.0)

    Supported app names: innovera, mydata, premium

.PARAMETER DocxPath
    Full or relative path to the .docx file to convert.

.PARAMETER ArticleTitle
    Optional. Display name in toc.yml. Defaults to the version extracted from the filename.

.EXAMPLE
    .\Convert-DocxToMd.ps1 -DocxPath "C:\Docs\1_5_1068_0_innovera.docx"

.EXAMPLE
    .\Convert-DocxToMd.ps1 -DocxPath "C:\Docs\1_5_1068_0_mydata.docx"

.EXAMPLE
    .\Convert-DocxToMd.ps1 -DocxPath "C:\Docs\2_0_0_0_premium.docx" -ArticleTitle "Version 2.0"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, HelpMessage = 'Path to the .docx file')]
    [string]$DocxPath,

    [string]$ArticleTitle
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# App name mapping
# ---------------------------------------------------------------------------
$appMap = @{
    'innovera' = 'innovera'
    'mydata'   = 'mydata'
    'premium'  = 'premium'
}

# ---------------------------------------------------------------------------
# Validate input
# ---------------------------------------------------------------------------
if (-not (Test-Path $DocxPath)) {
    Write-Error "File not found: $DocxPath"
    exit 1
}

$docxFile = Get-Item -LiteralPath $DocxPath

if ($docxFile.Extension -ine '.docx') {
    Write-Error "Expected a .docx file, got: $($docxFile.Extension)"
    exit 1
}

# Verify Pandoc is available
if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    Write-Error "Pandoc is not installed or not in PATH.`nInstall it with: winget install JohnMacFarlane.Pandoc"
    exit 1
}

# ---------------------------------------------------------------------------
# Parse filename: <version>_<appname>  (e.g. 1_5_1068_0_mydata)
# ---------------------------------------------------------------------------
$baseName = $docxFile.BaseName

# Match: one or more digit groups separated by underscores, then underscore + appname
if ($baseName -notmatch '^((\d+_)*\d+)_([a-zA-Z]+)$') {
    Write-Error "Filename must follow pattern: <version>_<appname>.docx (e.g. 1_5_1068_0_mydata.docx).`nGot: $($docxFile.Name)"
    exit 1
}

$versionPart = $Matches[1]       # e.g. 1_5_1068_0
$appNameRaw = $Matches[3].ToLower()  # e.g. mydata

if (-not $appMap.ContainsKey($appNameRaw)) {
    Write-Error "Unknown app name: '$appNameRaw'. Supported: $($appMap.Keys -join ', ')"
    exit 1
}

$appFolder = $appMap[$appNameRaw]
$versionTitle = $versionPart -replace '_', '.'   # 1.5.1068.0

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$articleName = $baseName   # e.g. 1_5_1068_0_mydata

$projectRoot = $PSScriptRoot
$appDir = Join-Path $projectRoot "articles\$appFolder"
$imagesDir = Join-Path $projectRoot 'images'
$outputMd = Join-Path $appDir "$articleName.md"
$tocFile = Join-Path $appDir 'toc.yml'
$tempMedia = Join-Path ([System.IO.Path]::GetTempPath()) "docfx_convert_$articleName"

# ---------------------------------------------------------------------------
# Prepare directories
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Path $appDir    -Force | Out-Null
New-Item -ItemType Directory -Path $imagesDir -Force | Out-Null

if (Test-Path $tempMedia) {
    Remove-Item $tempMedia -Recurse -Force
}

# ---------------------------------------------------------------------------
# Run Pandoc conversion
# ---------------------------------------------------------------------------
Write-Host "Converting '$($docxFile.Name)'..." -ForegroundColor Cyan

$pandocArgs = @(
    $docxFile.FullName
    '--output', $outputMd
    '--to', 'gfm'
    '--wrap=none'
    "--extract-media=$tempMedia"
    '--markdown-headings=atx'
)

& pandoc @pandocArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Pandoc failed with exit code $LASTEXITCODE."
    exit 1
}

Write-Host "  Created : $(Split-Path $outputMd -Leaf)" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Move extracted images and fix paths in the Markdown
# ---------------------------------------------------------------------------
if (Test-Path $tempMedia) {
    $images = Get-ChildItem -Path $tempMedia -Recurse -File

    foreach ($img in $images) {
        $dest = Join-Path $imagesDir $img.Name
        Copy-Item -LiteralPath $img.FullName -Destination $dest -Force
        Write-Host "  Image   : $($img.Name)" -ForegroundColor Gray
    }

    Remove-Item $tempMedia -Recurse -Force

    if ($images.Count -gt 0) {
        # Fix paths: ![alt](old/path/file.ext)  →  ![alt](../../images/file.ext)
        $content = Get-Content -LiteralPath $outputMd -Raw -Encoding UTF8
        $content = [regex]::Replace(
            $content,
            '!\[([^\]]*)\]\(([^)]+)\)',
            {
                param($m)
                $alt = $m.Groups[1].Value
                $imgName = [System.IO.Path]::GetFileName($m.Groups[2].Value)
                "![$alt](../../images/$imgName)"
            }
        )
        Set-Content -LiteralPath $outputMd -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  Fixed   : $($images.Count) image path(s)" -ForegroundColor Gray
    }
}

# ---------------------------------------------------------------------------
# Update app toc.yml
# ---------------------------------------------------------------------------
$title = if ($ArticleTitle) { $ArticleTitle } else { $versionTitle }
$hrefEntry = "$articleName.md"

$tocContent = if (Test-Path $tocFile) {
    Get-Content -LiteralPath $tocFile -Raw -Encoding UTF8
}
else {
    "- name: Release Notes`n  href: index.md`n  items:`n"
}

if ($tocContent -match [regex]::Escape($hrefEntry)) {
    Write-Host "  toc.yml : entry already exists, skipped." -ForegroundColor Yellow
}
else {
    $newEntry = "  - name: $title`n    href: $hrefEntry"
    $tocContent = $tocContent.TrimEnd() + "`n$newEntry`n"
    Set-Content -LiteralPath $tocFile -Value $tocContent -Encoding UTF8 -NoNewline
    Write-Host "  toc.yml : added '$title' to $appFolder" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
Write-Host "`nDone! Run 'docfx build' to rebuild the site." -ForegroundColor Cyan
