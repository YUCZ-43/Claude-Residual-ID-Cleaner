[CmdletBinding()]
param(
    [string]$ExePath = '',
    [string]$OutputPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Common-BuildHelpers.ps1')

function New-RoundedRectPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $Radius * 2.0
    $path.AddArc($X, $Y, $d, $d, 180, 90)
    $path.AddArc($X + $Width - $d, $Y, $d, $d, 270, 90)
    $path.AddArc($X + $Width - $d, $Y + $Height - $d, $d, $d, 0, 90)
    $path.AddArc($X, $Y + $Height - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-StepFrameBitmap {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$BaseA,
        [AllowNull()][System.Drawing.Bitmap]$BaseB = $null,
        [double]$BlendAlpha = 0.0,
        [int]$ActiveStepIndex = 0,
        [Parameter(Mandatory = $true)][string]$Caption,
        [Parameter(Mandatory = $true)][string[]]$StepLabels,
        [int]$TargetWidth = 1120,
        [int]$TargetHeight = 790
    )

    $headerHeight = 56
    $contentHeight = $TargetHeight - $headerHeight
    $canvas = New-Object System.Drawing.Bitmap($TargetWidth, $TargetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas)

    $headerBrush = $null
    $borderPen = $null
    $badgeBrush = $null
    $badgePath = $null
    $badgeFont = $null
    $captionFont = $null
    $pillFont = $null
    $whiteBrush = $null
    $mutedBrush = $null
    $centerFmt = $null
    $leftFmt = $null

    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $g.Clear([System.Drawing.Color]::FromArgb(24, 24, 27))

        $headerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 30, 34))
        $g.FillRectangle($headerBrush, 0, 0, $TargetWidth, $headerHeight)

        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(62, 62, 66), 1.0)
        $g.DrawLine($borderPen, 0, $headerHeight - 1, $TargetWidth, $headerHeight - 1)

        $badgeColor = if ($ActiveStepIndex -eq ($StepLabels.Count - 1)) {
            [System.Drawing.Color]::FromArgb(22, 163, 74)
        } else {
            [System.Drawing.Color]::FromArgb(59, 130, 246)
        }
        $badgeBrush = New-Object System.Drawing.SolidBrush($badgeColor)
        $badgePath = New-RoundedRectPath -X 16 -Y 13 -Width 86 -Height 30 -Radius 6
        $g.FillPath($badgeBrush, $badgePath)

        $badgeFont = New-Object System.Drawing.Font('Microsoft YaHei UI', 10.5, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $captionFont = New-Object System.Drawing.Font('Microsoft YaHei UI', 13.5, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $pillFont = New-Object System.Drawing.Font('Microsoft YaHei UI', 11.0, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(244, 244, 245))
        $mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(161, 161, 170))

        $centerFmt = New-Object System.Drawing.StringFormat
        $centerFmt.Alignment = [System.Drawing.StringAlignment]::Center
        $centerFmt.LineAlignment = [System.Drawing.StringAlignment]::Center

        $leftFmt = New-Object System.Drawing.StringFormat
        $leftFmt.Alignment = [System.Drawing.StringAlignment]::Near
        $leftFmt.LineAlignment = [System.Drawing.StringAlignment]::Center

        $stepBadgeText = "STEP $($ActiveStepIndex + 1)/$($StepLabels.Count)"
        $badgeRect = New-Object System.Drawing.RectangleF(16, 13, 86, 30)
        $g.DrawString($stepBadgeText, $badgeFont, $whiteBrush, $badgeRect, $centerFmt)

        $capRect = New-Object System.Drawing.RectangleF(114, 10, 550, 36)
        $g.DrawString($Caption, $captionFont, $whiteBrush, $capRect, $leftFmt)

        $pillW = 102
        $pillGap = 6
        $startX = $TargetWidth - 16 - ($StepLabels.Count * $pillW + ($StepLabels.Count - 1) * $pillGap)
        for ($i = 0; $i -lt $StepLabels.Count; $i++) {
            $px = $startX + $i * ($pillW + $pillGap)
            $isCurrent = ($i -eq $ActiveStepIndex)
            $isDone = ($i -lt $ActiveStepIndex)

            $fill = if ($isCurrent) {
                $badgeColor
            } elseif ($isDone) {
                [System.Drawing.Color]::FromArgb(30, 58, 42)
            } else {
                [System.Drawing.Color]::FromArgb(45, 45, 48)
            }
            $border = if ($isCurrent) {
                $badgeColor
            } elseif ($isDone) {
                [System.Drawing.Color]::FromArgb(34, 197, 94)
            } else {
                [System.Drawing.Color]::FromArgb(72, 72, 78)
            }

            $pBrush = New-Object System.Drawing.SolidBrush($fill)
            $pPen = New-Object System.Drawing.Pen($border, 1.0)
            $pPath = New-RoundedRectPath -X $px -Y 13 -Width $pillW -Height 30 -Radius 6
            try {
                $g.FillPath($pBrush, $pPath)
                $g.DrawPath($pPen, $pPath)
            } finally {
                $pBrush.Dispose()
                $pPen.Dispose()
                $pPath.Dispose()
            }

            $textBrush = if ($isCurrent -or $isDone) { $whiteBrush } else { $mutedBrush }
            $pillRect = New-Object System.Drawing.RectangleF($px, 13, $pillW, 30)
            $g.DrawString($StepLabels[$i], $pillFont, $textBrush, $pillRect, $centerFmt)
        }

        $destRect = New-Object System.Drawing.Rectangle(0, $headerHeight, $TargetWidth, $contentHeight)
        $g.DrawImage($BaseA, $destRect, 0, 0, $BaseA.Width, $BaseA.Height, [System.Drawing.GraphicsUnit]::Pixel)

        if ($null -ne $BaseB -and $BlendAlpha -gt 0.01) {
            $clampedAlpha = [float][Math]::Max(0.0, [Math]::Min(1.0, $BlendAlpha))
            $cm = New-Object System.Drawing.Imaging.ColorMatrix
            $cm.Matrix33 = $clampedAlpha
            $ia = New-Object System.Drawing.Imaging.ImageAttributes
            try {
                $ia.SetColorMatrix($cm, [System.Drawing.Imaging.ColorMatrixFlag]::Default, [System.Drawing.Imaging.ColorAdjustType]::Bitmap)
                $g.DrawImage($BaseB, $destRect, 0, 0, $BaseB.Width, $BaseB.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
            } finally {
                $ia.Dispose()
            }
        }
    } finally {
        if ($leftFmt) { $leftFmt.Dispose() }
        if ($centerFmt) { $centerFmt.Dispose() }
        if ($mutedBrush) { $mutedBrush.Dispose() }
        if ($whiteBrush) { $whiteBrush.Dispose() }
        if ($pillFont) { $pillFont.Dispose() }
        if ($captionFont) { $captionFont.Dispose() }
        if ($badgeFont) { $badgeFont.Dispose() }
        if ($badgePath) { $badgePath.Dispose() }
        if ($badgeBrush) { $badgeBrush.Dispose() }
        if ($borderPen) { $borderPen.Dispose() }
        if ($headerBrush) { $headerBrush.Dispose() }
        $g.Dispose()
    }

    return $canvas
}

function Convert-BitmapToSingleGifBytes {
    param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap)

    $pngStream = New-Object System.IO.MemoryStream
    $gifStream = New-Object System.IO.MemoryStream
    try {
        $Bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngStream.Position = 0
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
            $pngStream,
            [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $encoder = New-Object System.Windows.Media.Imaging.GifBitmapEncoder
        $encoder.Frames.Add($decoder.Frames[0])
        $encoder.Save($gifStream)
        return ,$gifStream.ToArray()
    } finally {
        $gifStream.Dispose()
        $pngStream.Dispose()
    }
}

function Read-ParsedSingleGif {
    param([Parameter(Mandatory = $true)][byte[]]$RawBytes)

    if ($RawBytes.Length -lt 14 -or $RawBytes[0] -ne 0x47 -or $RawBytes[1] -ne 0x49 -or $RawBytes[2] -ne 0x46) {
        throw 'Invalid single-frame GIF buffer.'
    }
    $pos = 6
    $width = [int]$RawBytes[$pos] -bor ([int]$RawBytes[$pos + 1] -shl 8)
    $height = [int]$RawBytes[$pos + 2] -bor ([int]$RawBytes[$pos + 3] -shl 8)
    $packedLsd = $RawBytes[$pos + 4]
    $pixelAspect = $RawBytes[$pos + 6]
    $pos += 7

    $gct = $null
    if (($packedLsd -band 0x80) -ne 0) {
        $gctEntries = 1 -shl (($packedLsd -band 0x07) + 1)
        $gctLen = $gctEntries * 3
        $gct = New-Object byte[] $gctLen
        [Buffer]::BlockCopy($RawBytes, $pos, $gct, 0, $gctLen)
        $pos += $gctLen
    }

    while ($pos -lt $RawBytes.Length) {
        $b = $RawBytes[$pos]
        if ($b -eq 0x21) {
            $pos += 2
            while ($pos -lt $RawBytes.Length) {
                $subLen = [int]$RawBytes[$pos++]
                if ($subLen -eq 0) { break }
                $pos += $subLen
            }
        } elseif ($b -eq 0x2C) {
            $imgStart = $pos
            $pos += 9
            $imgPacked = $RawBytes[$pos++]
            $lct = $null
            if (($imgPacked -band 0x80) -ne 0) {
                $lctEntries = 1 -shl (($imgPacked -band 0x07) + 1)
                $lctLen = $lctEntries * 3
                $lct = New-Object byte[] $lctLen
                [Buffer]::BlockCopy($RawBytes, $pos, $lct, 0, $lctLen)
                $pos += $lctLen
            }
            $pos++ # LZW min code size
            while ($pos -lt $RawBytes.Length) {
                $subLen = [int]$RawBytes[$pos++]
                if ($subLen -eq 0) { break }
                $pos += $subLen
            }
            $totalLen = $pos - $imgStart
            $imgBytes = New-Object byte[] $totalLen
            [Buffer]::BlockCopy($RawBytes, $imgStart, $imgBytes, 0, $totalLen)

            $colorTable = if ($null -ne $lct) { $lct } else { $gct }
            return [pscustomobject]@{
                Width          = $width
                Height         = $height
                PackedLsd      = $packedLsd
                PixelAspect    = $pixelAspect
                ColorTable     = $colorTable
                ImageDataBlock = $imgBytes
            }
        } else {
            break
        }
    }
    throw 'No image descriptor found in encoded GIF frame.'
}

function Write-AnimatedGifFile {
    param(
        [Parameter(Mandatory = $true)][object[]]$Frames,
        [Parameter(Mandatory = $true)][int[]]$DelaysCentiseconds,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if ($Frames.Count -eq 0 -or $Frames.Count -ne $DelaysCentiseconds.Count) {
        throw 'Frames and DelaysCentiseconds must be non-empty and have matching lengths.'
    }

    $parsed = New-Object 'System.Collections.Generic.List[object]'
    foreach ($frameBmp in $Frames) {
        $singleBytes = Convert-BitmapToSingleGifBytes -Bitmap $frameBmp
        $parsed.Add((Read-ParsedSingleGif -RawBytes $singleBytes))
    }

    $first = $parsed[0]
    $fs = [System.IO.File]::Open($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $header = [byte[]]@(0x47, 0x49, 0x46, 0x38, 0x39, 0x61) # GIF89a
        $fs.Write($header, 0, $header.Length)

        $lsdPackedNoGct = [byte]($first.PackedLsd -band 0x70)
        $lsd = [byte[]]@(
            [byte]($first.Width -band 0xFF),
            [byte](($first.Width -shr 8) -band 0xFF),
            [byte]($first.Height -band 0xFF),
            [byte](($first.Height -shr 8) -band 0xFF),
            $lsdPackedNoGct,
            0x00,
            $first.PixelAspect
        )
        $fs.Write($lsd, 0, $lsd.Length)

        # NETSCAPE2.0 infinite loop application extension
        $netscape = [byte[]]@(
            0x21, 0xFF, 0x0B,
            0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2E, 0x30,
            0x03, 0x01, 0x00, 0x00, 0x00
        )
        $fs.Write($netscape, 0, $netscape.Length)

        for ($i = 0; $i -lt $parsed.Count; $i++) {
            $pf = $parsed[$i]
            $delay = [Math]::Max(2, [int]$DelaysCentiseconds[$i])
            $gce = [byte[]]@(
                0x21, 0xF9, 0x04,
                0x04,
                [byte]($delay -band 0xFF),
                [byte](($delay -shr 8) -band 0xFF),
                0x00, 0x00
            )
            $fs.Write($gce, 0, $gce.Length)

            $img = $pf.ImageDataBlock
            $origImgPacked = $img[9]
            if (($origImgPacked -band 0x80) -ne 0) {
                $fs.Write($img, 0, $img.Length)
            } elseif ($null -ne $pf.ColorTable -and $pf.ColorTable.Length -gt 0) {
                $entries = [int]($pf.ColorTable.Length / 3)
                $sizeBits = 0
                $v = $entries
                while ($v -gt 2) {
                    $v = $v -shr 1
                    $sizeBits++
                }
                $newImgPacked = [byte](($origImgPacked -band 0x40) -bor 0x80 -bor ($sizeBits -band 0x07))
                $fs.Write($img, 0, 9)
                $fs.WriteByte($newImgPacked)
                $fs.Write($pf.ColorTable, 0, $pf.ColorTable.Length)
                $fs.Write($img, 10, $img.Length - 10)
            } else {
                $fs.Write($img, 0, $img.Length)
            }
        }

        $fs.WriteByte(0x3B) # GIF Trailer
        $fs.Flush()
    } finally {
        $fs.Dispose()
    }
}

$repoRoot = (Split-Path -Parent $PSScriptRoot).TrimEnd('\', '/')
$buildScript = Join-Path $repoRoot 'scripts\Build-DesktopApp.ps1'

$resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Join-Path $repoRoot 'docs\images\demo-workflow.gif'
} else {
    Resolve-CallerPath -PathValue $OutputPath
}

$outDir = Split-Path -Parent $resolvedOutput
if ($outDir -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
    [System.IO.Directory]::CreateDirectory($outDir) | Out-Null
}

$sandboxRoot = Join-Path $repoRoot 'tests\sandbox'
$sandboxExisted = Test-Path -LiteralPath $sandboxRoot
$workDir = Join-Path $sandboxRoot ('demo-gif-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($workDir) | Out-Null

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$bitmapsToDispose = New-Object 'System.Collections.Generic.List[System.Drawing.Bitmap]'

try {
    $exeInfo = Resolve-CaptureDesktopExecutable -RepoRoot $repoRoot -ExePath $ExePath -SandboxWorkDir $workDir
    $resolvedExe = $exeInfo.ExePath

    $png1 = Join-Path $workDir 'step1-idle.png'
    $png2 = Join-Path $workDir 'step2-scan.png'
    $png3 = Join-Path $workDir 'step3-cleaning.png'
    $png4 = Join-Path $workDir 'step4-verified.png'

    Invoke-DesktopCapture -ExecutablePath $resolvedExe -ArgumentsLine "--dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`" --capture-png `"$png1`""
    Invoke-DesktopCapture -ExecutablePath $resolvedExe -ArgumentsLine "--demo-audit --dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`" --capture-png `"$png2`""
    try {
        Invoke-DesktopCapture -ExecutablePath $resolvedExe -ArgumentsLine "--demo-cleaning --dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`" --capture-png `"$png3`""
    } catch {
        Write-Warning "Desktop executable did not support --demo-cleaning directly; falling back to --demo-audit frame for Step 3: $($_.Exception.Message)"
        Invoke-DesktopCapture -ExecutablePath $resolvedExe -ArgumentsLine "--demo-audit --dry-run --language zh-CN --nav 0 --toolkit-root `"$repoRoot`" --capture-png `"$png3`""
    }
    Invoke-DesktopCapture -ExecutablePath $resolvedExe -ArgumentsLine "--demo-report --dry-run --language zh-CN --nav 1 --toolkit-root `"$repoRoot`" --capture-png `"$png4`""

    $stepBmps = @(
        (New-Object System.Drawing.Bitmap($png1)),
        (New-Object System.Drawing.Bitmap($png2)),
        (New-Object System.Drawing.Bitmap($png3)),
        (New-Object System.Drawing.Bitmap($png4))
    )
    foreach ($sb in $stepBmps) { $bitmapsToDispose.Add($sb) }

    $targetWidth = 1120
    $targetHeight = 790
    $stepLabels = @('1. 扫描面板', '2. 识别残余', '3. 实时清理', '4. 详情报告')
    $stepCaptions = @(
        '启动只读扫描面板 · 默认零写入、绝不改动 Windows 系统',
        '精准识别残余账号 UUID 与可清理缓存 · 严守安全红线',
        '实时流式清理进度 · 逐项状态徽章即时更新',
        '清理完成详情报告 · 账号/组织 ID 残留：0（已彻底清除）'
    )
    $holdDelays = @(160, 180, 180, 200)

    $gifFrames = New-Object 'System.Collections.Generic.List[System.Drawing.Bitmap]'
    $gifDelays = New-Object 'System.Collections.Generic.List[int]'

    for ($sIdx = 0; $sIdx -lt $stepBmps.Count; $sIdx++) {
        $nextIdx = ($sIdx + 1) % $stepBmps.Count
        $holdBmp = New-StepFrameBitmap -BaseA $stepBmps[$sIdx] -ActiveStepIndex $sIdx -Caption $stepCaptions[$sIdx] -StepLabels $stepLabels -TargetWidth $targetWidth -TargetHeight $targetHeight
        $bitmapsToDispose.Add($holdBmp); [void]$gifFrames.Add($holdBmp); [void]$gifDelays.Add($holdDelays[$sIdx])

        foreach ($alpha in @(0.30, 0.65)) {
            $fadeBmp = New-StepFrameBitmap -BaseA $stepBmps[$sIdx] -BaseB $stepBmps[$nextIdx] -BlendAlpha $alpha -ActiveStepIndex $nextIdx -Caption $stepCaptions[$nextIdx] -StepLabels $stepLabels -TargetWidth $targetWidth -TargetHeight $targetHeight
            $bitmapsToDispose.Add($fadeBmp); [void]$gifFrames.Add($fadeBmp); [void]$gifDelays.Add(8)
        }
    }

    Write-AnimatedGifFile -Frames @($gifFrames.ToArray()) -DelaysCentiseconds @($gifDelays.ToArray()) -DestinationPath $resolvedOutput

    $gifBytes = [System.IO.File]::ReadAllBytes($resolvedOutput)
    if ($gifBytes.Length -lt 20480 -or
        $gifBytes[0] -ne 0x47 -or $gifBytes[1] -ne 0x49 -or $gifBytes[2] -ne 0x46 -or
        $gifBytes[3] -ne 0x38 -or $gifBytes[4] -ne 0x39 -or $gifBytes[5] -ne 0x61) {
        throw "Generated file is not a valid GIF89a image: $resolvedOutput"
    }

    [pscustomobject]@{
        Succeeded  = $true
        OutputPath = $resolvedOutput
        SizeBytes  = [int64]$gifBytes.Length
        FrameCount = $gifFrames.Count
        Width      = $targetWidth
        Height     = $targetHeight
    }
} finally {
    foreach ($b in $bitmapsToDispose) {
        if ($null -ne $b) {
            try { $b.Dispose() } catch {}
        }
    }
    Remove-CaptureSandboxDirectory -WorkDir $workDir -SandboxRoot $sandboxRoot -SandboxExisted $sandboxExisted
}
