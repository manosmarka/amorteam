# Requires: Windows PowerShell
# Usage: Run from the project root (same level as blog.html)
# This script downloads Open Graph images for each blog post and generates thumbnails.

param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$HeroDir = "assets/images/hero",
    [string]$ThumbDir = "assets/images/thumbs"
)

$ErrorActionPreference = 'Stop'

# Ensure TLS 1.2 for modern endpoints
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Set a realistic browser User-Agent to avoid blocks
$Global:DownloaderHeaders = @{ 
    'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0 Safari/537.36'
    'Accept'      = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8'
    'Accept-Language' = 'en-US,en;q=0.9'
}

# Ensure directories
$heroPath = Join-Path $ProjectRoot $HeroDir
$thumbPath = Join-Path $ProjectRoot $ThumbDir
New-Item -ItemType Directory -Force -Path $heroPath | Out-Null
New-Item -ItemType Directory -Force -Path $thumbPath | Out-Null

# Post list: Source URL and local base filename (without extension)
$posts = @(
    @{ Url = 'https://amorteam.gr/%ce%b2%ce%bf%ce%b7%ce%b8%ce%b7%cf%84%ce%b9%ce%ba%ce%b1-%ce%b5%ce%bb%ce%b1%cf%84%ce%b7%cf%81%ce%b9%ce%b1-%ce%b7-%ce%b1%cf%80%cf%8c%ce%bb%cf%85%cf%84%ce%b7-%ce%bb%cf%8d%cf%83%ce%b7-%ce%b3%ce%b9%ce%b1/'; Base = 'voithitika-elatiria-mad' },
    @{ Url = 'https://amorteam.gr/%ce%b7-%cf%83%ce%b7%ce%bc%ce%b1%cf%83%ce%af%ce%b1-%cf%83%cf%89%cf%83%cf%84%ce%ae%cf%82-%ce%b5%cf%80%ce%b9%ce%bb%ce%bf%ce%b3%ce%ae%cf%82-%ce%b5%cf%80%ce%b9%cf%87%ce%b5%ce%af%cf%81%ce%b7%cf%83%ce%b7/'; Base = 'epilogi-epicheirisis-antallaktika' },
    @{ Url = 'https://amorteam.gr/%ce%b7-%cf%83%ce%b7%ce%bc%ce%ac%cf%83%ce%b9%ce%b1-%cf%84%ce%b7%cf%82-%cf%83%cf%89%cf%83%cf%84%ce%ae%cf%82-%ce%bb%ce%af%cf%80%ce%b1%ce%bd%cf%83%ce%b7%cf%82-%cf%84%ce%bf%cf%85-%ce%ba%ce%b9%ce%bd%ce%b7/'; Base = 'sosti-lipansi-kinitira' },
    @{ Url = 'https://amorteam.gr/%ce%b7-%cf%83%ce%b7%ce%bc%ce%ac%cf%83%ce%b9%ce%b1-%cf%84%ce%b7%cf%82-%ce%b5%cf%80%ce%b9%ce%bb%ce%bf%ce%b3%ce%ae%cf%82-%cf%84%ce%bf%cf%85-%cf%83%cf%89%cf%83%cf%84%ce%bf%cf%8d-%ce%b1%ce%bc%ce%bf%cf%81/'; Base = 'epilogi-amortiser' },
    @{ Url = 'https://amorteam.gr/arthro3/'; Base = 'arthro3' },
    @{ Url = 'https://amorteam.gr/arthro2/'; Base = 'arthro2' },
    @{ Url = 'https://amorteam.gr/arthro-1/'; Base = 'arthro-1' }
)

function Get-OgImageUrl {
    param([string]$Html)
    # Try og:image (any order of attributes)
    $patterns = @(
        '(?i)<meta[^>]+property=["'']og:image["''][^>]*content=["'']([^"'']+)["'']',
        '(?i)<meta[^>]+content=["'']([^"'']+)["''][^>]*property=["'']og:image["'']',
        '(?i)<meta[^>]+property=["'']og:image:secure_url["''][^>]*content=["'']([^"'']+)["'']',
        '(?i)<meta[^>]+content=["'']([^"'']+)["''][^>]*property=["'']og:image:secure_url["'']'
    )
    foreach ($p in $patterns) {
        $m = [regex]::Match($Html, $p)
        if ($m.Success) { return $m.Groups[1].Value }
    }
    # Fallback: first featured image commonly has wp-post-image class
    $m2 = [regex]::Match($Html, '(?i)<img[^>]+class=["''][^"'']*(wp-post-image|attachment-post-thumbnail)[^"'']*["''][^>]+src=["'']([^"'']+)["'']')
    if ($m2.Success) { return $m2.Groups[2].Value }
    return $null
}

Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

function New-Thumbnail {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [int]$Width = 800,
        [int]$Height = 450
    )
    try {
        $img = [System.Drawing.Image]::FromFile($SourcePath)
        # Compute crop to fill target aspect
        $targetRatio = $Width / $Height
        $srcRatio = $img.Width / $img.Height
        if ($srcRatio -gt $targetRatio) {
            # wider than target - crop width
            $newHeight = $img.Height
            $newWidth = [int]($img.Height * $targetRatio)
        } else {
            # taller than target - crop height
            $newWidth = $img.Width
            $newHeight = [int]($img.Width / $targetRatio)
        }
        $x = [int](($img.Width - $newWidth) / 2)
        $y = [int](($img.Height - $newHeight) / 2)
        $cropRect = New-Object System.Drawing.Rectangle $x, $y, $newWidth, $newHeight
        $src = New-Object System.Drawing.Bitmap $newWidth, $newHeight
        $g1 = [System.Drawing.Graphics]::FromImage($src)
        $g1.DrawImage($img, 0,0, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
        $thumb = New-Object System.Drawing.Bitmap $Width, $Height
        $g2 = [System.Drawing.Graphics]::FromImage($thumb)
        $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g2.DrawImage($src, 0,0, $Width, $Height)
        $thumb.Save($DestPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $g1.Dispose(); $g2.Dispose(); $src.Dispose(); $thumb.Dispose(); $img.Dispose()
    } catch {
        Write-Warning "Thumbnail generation failed for $SourcePath. Copying source instead. $_"
        Copy-Item -Force $SourcePath $DestPath
    }
}

foreach ($post in $posts) {
    try {
        Write-Host "Processing" $post.Url -ForegroundColor Cyan
        $resp = Invoke-WebRequest -Uri $post.Url -UseBasicParsing -Headers $Global:DownloaderHeaders
        $og = Get-OgImageUrl -Html $resp.Content
        if (-not $og) { Write-Warning "No image found (og/wp-post-image) for $($post.Url)"; continue }
        Write-Host "Found image:" $og -ForegroundColor DarkGray
        $ext = [System.IO.Path]::GetExtension(($og.Split('?')[0]))
        if (-not $ext) { $ext = '.jpg' }
        $heroFile = Join-Path $heroPath ("{0}{1}" -f $post.Base, $ext)
        Invoke-WebRequest -Uri $og -OutFile $heroFile -UseBasicParsing -Headers $Global:DownloaderHeaders
        Write-Host "Saved hero:" $heroFile -ForegroundColor Green
        # Normalize hero to jpg copy for consistency referenced in HTML
        $heroJpg = Join-Path $heroPath ("{0}.jpg" -f $post.Base)
        if ($ext -ne '.jpg') {
            try {
                $img = [System.Drawing.Image]::FromFile($heroFile)
                $img.Save($heroJpg, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $img.Dispose()
                Write-Host "Converted to JPG:" $heroJpg -ForegroundColor Green
            } catch {
                Copy-Item -Force $heroFile $heroJpg
                Write-Warning "Conversion failed, copied source to JPG: $heroJpg"
            }
        } else {
            Copy-Item -Force $heroFile $heroJpg
        }
        $thumbJpg = Join-Path $thumbPath ("{0}.jpg" -f $post.Base)
        New-Thumbnail -SourcePath $heroJpg -DestPath $thumbJpg -Width 800 -Height 450
        Write-Host "Created thumb:" $thumbJpg -ForegroundColor Green
    } catch {
        Write-Warning "Failed to process $($post.Url): $_"
    }
}

Write-Host "Done. Hero images in $HeroDir, thumbnails in $ThumbDir" -ForegroundColor Green
