[CmdletBinding()]
param(
    [string]$LogoPngPath = '',
    [string]$IconPath = '',
    [switch]$ForceRegenerate
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedLogoPath = if ([string]::IsNullOrWhiteSpace($LogoPngPath)) {
    Join-Path $repoRoot 'docs\images\logo.png'
} else {
    [System.IO.Path]::GetFullPath($LogoPngPath)
}

$resolvedIconPath = if ([string]::IsNullOrWhiteSpace($IconPath)) {
    Join-Path $repoRoot 'src\Gui\app.ico'
} else {
    [System.IO.Path]::GetFullPath($IconPath)
}

Add-Type -AssemblyName System.Drawing

function New-RoundedRectPath {
    param(
        [float]$X,
        [float]$Y,
        [float]$W,
        [float]$H,
        [float]$Radius
    )
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $Radius * 2.0
    $path.AddArc($X, $Y, $d, $d, 180, 90)
    $path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
    $path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Render-MascotLogoBitmap {
    param([int]$Size = 256)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)

        $s = $Size / 256.0
        $g.ScaleTransform([float]$s, [float]$s)

        # 1. Dark slate #1E1E1E rounded-square base with subtle #3794FF accent border
        $bgPath = New-RoundedRectPath -X 10 -Y 10 -W 236 -H 236 -Radius 44
        $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.PointF(10, 10)),
            (New-Object System.Drawing.PointF(246, 246)),
            [System.Drawing.Color]::FromArgb(255, 37, 37, 40),
            [System.Drawing.Color]::FromArgb(255, 22, 22, 24)
        )
        $g.FillPath($bgBrush, $bgPath)

        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 55, 148, 255), 5.0)
        $g.DrawPath($borderPen, $bgPath)

        # Subtle inner dark slate glow ring
        $innerPath = New-RoundedRectPath -X 18 -Y 18 -W 220 -H 220 -Radius 38
        $innerPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 55, 148, 255), 2.0)
        $g.DrawPath($innerPen, $innerPath)

        # Floor sweep shadow
        $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(110, 0, 0, 0))
        $g.FillEllipse($shadowBrush, 38, 206, 180, 22)

        # 2. Broken residual ID card being swept away (bottom-right)
        $g.TranslateTransform(182, 186)
        $g.RotateTransform(18)

        $cardPath = New-RoundedRectPath -X -30 -Y -20 -W 60 -H 40 -Radius 6
        $cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 241, 245, 249))
        $cardPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 239, 68, 68), 3.0)
        $g.FillPath($cardBrush, $cardPath)
        $g.DrawPath($cardPen, $cardPath)

        # Card mini avatar + text lines
        $avatarBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 248, 113, 113))
        $g.FillRectangle($avatarBrush, -22, -11, 16, 18)
        $linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 100, 116, 139), 3.0)
        $g.DrawLine($linePen, 0, -8, 20, -8)
        $g.DrawLine($linePen, 0, 0, 18, 0)
        $g.DrawLine($linePen, 0, 8, 14, 8)

        # Jagged crack across the ID card
        $crackPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 185, 28, 28), 3.2)
        [System.Drawing.PointF[]]$crackPts = @(
            (New-Object System.Drawing.PointF(-6, -20)),
            (New-Object System.Drawing.PointF(2, -6)),
            (New-Object System.Drawing.PointF(-5, 5)),
            (New-Object System.Drawing.PointF(5, 20))
        )
        $g.DrawLines($crackPen, $crackPts)

        $g.RotateTransform(-18)
        $g.TranslateTransform(-182, -186)

        # Sweep motion arcs in #3794FF and #22C55E
        $arcPenBlue = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 55, 148, 255), 3.5)
        $arcPenBlue.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $arcPenBlue.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawArc($arcPenBlue, 130, 184, 52, 28, 175, 100)

        $arcPenGreen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 34, 197, 94), 3.0)
        $arcPenGreen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $arcPenGreen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawArc($arcPenGreen, 146, 198, 40, 22, 185, 85)

        # 3. Playful Orange-Terracotta Geometric Robot Mascot (left-center)
        $terracottaMain = [System.Drawing.Color]::FromArgb(255, 217, 119, 87)
        $terracottaDark = [System.Drawing.Color]::FromArgb(255, 180, 83, 57)
        $terracottaBrush = New-Object System.Drawing.SolidBrush($terracottaMain)
        $terracottaShadeBrush = New-Object System.Drawing.SolidBrush($terracottaDark)
        $robotOutlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 254, 215, 170), 2.5)

        # Robot body torso
        $bodyPath = New-RoundedRectPath -X 60 -Y 134 -W 74 -H 62 -Radius 16
        $g.FillPath($terracottaShadeBrush, $bodyPath)
        $g.DrawPath($robotOutlinePen, $bodyPath)

        # Chest shield badge (#3794FF)
        $chestPath = New-RoundedRectPath -X 79 -Y 148 -W 36 -H 30 -Radius 7
        $chestBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 30, 41, 59))
        $chestPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 55, 148, 255), 2.5)
        $g.FillPath($chestBrush, $chestPath)
        $g.DrawPath($chestPen, $chestPath)
        $checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 34, 197, 94), 3.5)
        $checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($checkPen, 88, 163, 95, 170)
        $g.DrawLine($checkPen, 95, 170, 107, 156)

        # Robot feet
        $footBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 55, 148, 255))
        $foot1 = New-RoundedRectPath -X 68 -Y 192 -W 22 -H 18 -Radius 7
        $foot2 = New-RoundedRectPath -X 104 -Y 192 -W 22 -H 18 -Radius 7
        $g.FillPath($footBrush, $foot1)
        $g.FillPath($footBrush, $foot2)

        # Robot head (geometric rounded rectangle)
        $headPath = New-RoundedRectPath -X 52 -Y 62 -W 90 -H 68 -Radius 18
        $g.FillPath($terracottaBrush, $headPath)
        $g.DrawPath($robotOutlinePen, $headPath)

        # Side ear bolts
        $earBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 55, 148, 255))
        $g.FillEllipse($earBrush, 42, 86, 12, 20)
        $g.FillEllipse($earBrush, 140, 86, 12, 20)

        # Face visor (#161618)
        $visorPath = New-RoundedRectPath -X 64 -Y 76 -W 66 -H 38 -Radius 10
        $visorBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 20, 24, 32))
        $visorPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 55, 148, 255), 2.5)
        $g.FillPath($visorBrush, $visorPath)
        $g.DrawPath($visorPen, $visorPath)

        # Happy bright cyan-blue eyes & smile
        $eyeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 56, 189, 248))
        $g.FillEllipse($eyeBrush, 74, 84, 14, 14)
        $g.FillEllipse($eyeBrush, 106, 84, 14, 14)
        $sparkleBrush = [System.Drawing.Brushes]::White
        $g.FillEllipse($sparkleBrush, 77, 86, 5, 5)
        $g.FillEllipse($sparkleBrush, 109, 86, 5, 5)

        $smilePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 134, 239, 172), 3.0)
        $smilePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $smilePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawArc($smilePen, 84, 93, 26, 14, 15, 150)

        # 4. Tiny playful janitor cap tilted on robot's head!
        $g.TranslateTransform(96, 56)
        $g.RotateTransform(-12)

        $capCrown = New-RoundedRectPath -X -28 -Y -22 -W 56 -H 26 -Radius 10
        $capBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 120, 212))
        $capPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 147, 197, 253), 2.5)
        $g.FillPath($capBrush, $capCrown)
        $g.DrawPath($capPen, $capCrown)

        # Cap badge dot
        $g.FillEllipse($sparkleBrush, -6, -15, 12, 12)
        $g.FillEllipse($terracottaBrush, -3, -12, 6, 6)

        # Cap visor brim
        $brimPath = New-RoundedRectPath -X -20 -Y -1 -W 56 -H 9 -Radius 4
        $brimBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 55, 148, 255))
        $g.FillPath($brimBrush, $brimPath)

        $g.RotateTransform(12)
        $g.TranslateTransform(-96, -56)

        # 5. Broom held by robot arm sweeping the broken ID card
        $handlePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 245, 158, 11), 6.0)
        $handlePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $handlePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($handlePen, 118, 108, 150, 178)

        # Robot arm gripping broom
        $armPen = New-Object System.Drawing.Pen($terracottaMain, 11.0)
        $armPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $armPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($armPen, 128, 146, 138, 142)

        # Broom head & bristles
        $g.TranslateTransform(154, 184)
        $g.RotateTransform(-24)
        $broomHead = New-RoundedRectPath -X -20 -Y -8 -W 40 -H 12 -Radius 4
        $broomHeadBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 55, 148, 255))
        $g.FillPath($broomHeadBrush, $broomHead)

        $bristleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 253, 224, 71))
        $bristlePath = New-RoundedRectPath -X -22 -Y 2 -W 44 -H 18 -Radius 4
        $g.FillPath($bristleBrush, $bristlePath)
        $bristleLinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 217, 119, 6), 2.0)
        foreach ($bx in @(-14, -7, 0, 7, 14)) {
            $g.DrawLine($bristleLinePen, $bx, 4, $bx, 18)
        }
        $g.RotateTransform(24)
        $g.TranslateTransform(-154, -184)

        # Clean sparkles
        $sparkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 134, 239, 172), 2.5)
        $sparkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $sparkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($sparkPen, 206, 56, 206, 70)
        $g.DrawLine($sparkPen, 199, 63, 213, 63)
        $g.DrawLine($sparkPen, 222, 82, 222, 92)
        $g.DrawLine($sparkPen, 217, 87, 227, 87)

        # Dispose local GDI objects cleanly
        foreach ($obj in @($bgPath,$bgBrush,$borderPen,$innerPath,$innerPen,$shadowBrush,$cardPath,$cardBrush,$cardPen,$avatarBrush,$linePen,$crackPen,$arcPenBlue,$arcPenGreen,$terracottaBrush,$terracottaShadeBrush,$robotOutlinePen,$bodyPath,$chestPath,$chestBrush,$chestPen,$checkPen,$footBrush,$foot1,$foot2,$headPath,$earBrush,$visorPath,$visorBrush,$visorPen,$eyeBrush,$smilePen,$capCrown,$capBrush,$capPen,$brimPath,$brimBrush,$handlePen,$armPen,$broomHead,$broomHeadBrush,$bristleBrush,$bristlePath,$bristleLinePen,$sparkPen)) {
            if ($null -ne $obj) { $obj.Dispose() }
        }
    } finally {
        $g.Dispose()
    }
    return $bmp
}

function New-ResizedBitmap {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Image]$SourceImage,
        [Parameter(Mandatory = $true)][int]$TargetSize
    )
    $resized = New-Object System.Drawing.Bitmap($TargetSize, $TargetSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($resized)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($SourceImage, 0, 0, $TargetSize, $TargetSize)
    } finally {
        $g.Dispose()
    }
    return $resized
}

function ConvertTo-IcoDibEntryBytes {
    param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap)

    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $xorStride = $w * 4
    $andStride = [int]([Math]::Ceiling($w / 32.0)) * 4
    $totalSize = 40 + ($xorStride * $h) + ($andStride * $h)

    $ms = New-Object System.IO.MemoryStream($totalSize)
    $bw = New-Object System.IO.BinaryWriter($ms)
    try {
        # BITMAPINFOHEADER (40 bytes)
        $bw.Write([uint32]40)
        $bw.Write([int32]$w)
        $bw.Write([int32]($h * 2))
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]0)
        $bw.Write([uint32](($xorStride * $h) + ($andStride * $h)))
        $bw.Write([int32]0)
        $bw.Write([int32]0)
        $bw.Write([uint32]0)
        $bw.Write([uint32]0)

        # Bottom-up BGRA pixels
        for ($y = $h - 1; $y -ge 0; $y--) {
            for ($x = 0; $x -lt $w; $x++) {
                $px = $Bitmap.GetPixel($x, $y)
                $bw.Write([byte]$px.B)
                $bw.Write([byte]$px.G)
                $bw.Write([byte]$px.R)
                $bw.Write([byte]$px.A)
            }
        }

        # 1bpp AND mask (alpha == 0 => mask bit 1)
        for ($y = $h - 1; $y -ge 0; $y--) {
            $rowBytes = New-Object byte[] $andStride
            for ($x = 0; $x -lt $w; $x++) {
                $px = $Bitmap.GetPixel($x, $y)
                if ($px.A -eq 0) {
                    $byteIndex = [int][Math]::Floor($x / 8)
                    $bitMask = [byte](1 -shl (7 - ($x % 8)))
                    $rowBytes[$byteIndex] = [byte]($rowBytes[$byteIndex] -bor $bitMask)
                }
            }
            $bw.Write($rowBytes)
        }
        $bw.Flush()
        return , ([byte[]]$ms.ToArray())
    } finally {
        $bw.Dispose()
        $ms.Dispose()
    }
}

function ConvertTo-PngEntryBytes {
    param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap)
    $ms = New-Object System.IO.MemoryStream
    try {
        $Bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        return , ([byte[]]$ms.ToArray())
    } finally {
        $ms.Dispose()
    }
}

function Save-MultiResolutionIcon {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Image]$MasterImage,
        [Parameter(Mandatory = $true)][string]$OutIconPath,
        [int[]]$Sizes = @(16, 32, 48, 256)
    )

    $parent = Split-Path -Parent $OutIconPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }

    $entries = New-Object 'System.Collections.Generic.List[object]'
    foreach ($sz in $Sizes) {
        $bmp = New-ResizedBitmap -SourceImage $MasterImage -TargetSize $sz
        try {
            $payload = if ($sz -ge 256) {
                ConvertTo-PngEntryBytes -Bitmap $bmp
            } else {
                ConvertTo-IcoDibEntryBytes -Bitmap $bmp
            }
            $entries.Add([pscustomobject]@{
                Size  = $sz
                Bytes = $payload
            })
        } finally {
            $bmp.Dispose()
        }
    }

    $fs = New-Object System.IO.FileStream($OutIconPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $bw = New-Object System.IO.BinaryWriter($fs)
    try {
        # ICONDIR header
        $bw.Write([uint16]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]$entries.Count)

        $offset = 6 + (16 * $entries.Count)
        foreach ($ent in $entries) {
            $dimByte = if ($ent.Size -ge 256) { [byte]0 } else { [byte]$ent.Size }
            $bw.Write($dimByte) # bWidth
            $bw.Write($dimByte) # bHeight
            $bw.Write([byte]0)  # bColorCount
            $bw.Write([byte]0)  # bReserved
            $bw.Write([uint16]1)  # wPlanes
            $bw.Write([uint16]32) # wBitCount
            $bw.Write([uint32]$ent.Bytes.Length)
            $bw.Write([uint32]$offset)
            $offset += $ent.Bytes.Length
        }

        foreach ($ent in $entries) {
            [byte[]]$payloadBytes = [byte[]]$ent.Bytes
            $bw.Write($payloadBytes, 0, $payloadBytes.Length)
        }
        $bw.Flush()
    } finally {
        $bw.Dispose()
        $fs.Dispose()
    }
}

$logoDir = Split-Path -Parent $resolvedLogoPath
if ($logoDir -and -not (Test-Path -LiteralPath $logoDir)) {
    [System.IO.Directory]::CreateDirectory($logoDir) | Out-Null
}

$generatedLogo = $false
$masterImage = $null
try {
    if ((-not $ForceRegenerate) -and (Test-Path -LiteralPath $resolvedLogoPath -PathType Leaf)) {
        [byte[]]$rawBytes = [System.IO.File]::ReadAllBytes($resolvedLogoPath)
        $msLoad = New-Object System.IO.MemoryStream($rawBytes, $false)
        try {
            $loaded = [System.Drawing.Image]::FromStream($msLoad)
            $masterImage = New-Object System.Drawing.Bitmap($loaded)
            $loaded.Dispose()
        } finally {
            $msLoad.Dispose()
        }
    } else {
        $masterImage = Render-MascotLogoBitmap -Size 256
        $masterImage.Save($resolvedLogoPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $generatedLogo = $true
    }

    Save-MultiResolutionIcon -MasterImage $masterImage -OutIconPath $resolvedIconPath -Sizes @(16, 32, 48, 256)
} finally {
    if ($null -ne $masterImage) {
        $masterImage.Dispose()
    }
}

$logoInfo = Get-Item -LiteralPath $resolvedLogoPath
$iconInfo = Get-Item -LiteralPath $resolvedIconPath
$logoSha = (Get-FileHash -LiteralPath $resolvedLogoPath -Algorithm SHA256).Hash.ToLowerInvariant()
$iconSha = (Get-FileHash -LiteralPath $resolvedIconPath -Algorithm SHA256).Hash.ToLowerInvariant()

[pscustomobject]@{
    Succeeded     = $true
    GeneratedLogo = $generatedLogo
    LogoPngPath   = $resolvedLogoPath
    LogoSizeBytes = [int64]$logoInfo.Length
    LogoSha256    = $logoSha
    IconPath      = $resolvedIconPath
    IconSizeBytes = [int64]$iconInfo.Length
    IconSha256    = $iconSha
    Resolutions   = @('16x16', '32x32', '48x48', '256x256')
}
