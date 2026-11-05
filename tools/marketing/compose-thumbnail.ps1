# Turns a game screenshot into a Roblox thumbnail (1920x1080) or icon (512x512) with a big,
# outlined headline like the top games use.
# Usage:
#   powershell -File tools/marketing/compose-thumbnail.ps1 -Source shot.jpg -Destination out.png -Title "BUILD YOUR MANOR!" [-Icon]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [string]$Title = "",
    [string]$Logo = "RELIC RUSH",
    [switch]$Icon,
    [double]$FocusX = 0.5  # where to centre the crop horizontally (0..1)
)

Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
try {
    $w = if ($Icon) { 512 } else { 1920 }
    $h = if ($Icon) { 512 } else { 1080 }
    $ratio = $w / $h
    $cropH = $img.Height
    $cropW = [int][Math]::Min($img.Width, [Math]::Round($cropH * $ratio))
    if ($cropW -lt [Math]::Round($cropH * $ratio)) { $cropH = [int][Math]::Round($cropW / $ratio) }
    $x = [int][Math]::Max(0, [Math]::Min($img.Width - $cropW, $img.Width * $FocusX - $cropW / 2))
    $y = [int](($img.Height - $cropH) / 2)

    $out = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), (New-Object System.Drawing.Rectangle $x, $y, $cropW, $cropH), [System.Drawing.GraphicsUnit]::Pixel)

    # Soft dark gradient at the bottom so the headline reads on any background.
    $band = [int]($h * 0.36)
    $rect = New-Object System.Drawing.Rectangle 0, ($h - $band), $w, $band
    $fade = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::FromArgb(0, 20, 10, 40)), ([System.Drawing.Color]::FromArgb(170, 20, 10, 40)), 90
    $g.FillRectangle($fade, $rect)

    function Draw-Outlined($text, $size, $cx, $cy, $fill, $outline, $width) {
        $family = New-Object System.Drawing.FontFamily "Arial Black"
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        # Shrink until the text fits 92 % of the width.
        do {
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddString($text, $family, [int][System.Drawing.FontStyle]::Bold, $size, (New-Object System.Drawing.PointF $cx, $cy), $format)
            $tooWide = $path.GetBounds().Width + $width -gt $w * 0.92
            if ($tooWide) { $path.Dispose(); $size -= 4 }
        } while ($tooWide -and $size -gt 20)
        $pen = New-Object System.Drawing.Pen $outline, $width
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPath($pen, $path)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($path.GetBounds()), $fill[0], $fill[1], 90
        $g.FillPath($brush, $path)
        $pen.Dispose(); $brush.Dispose(); $path.Dispose()
    }

    $gold = @([System.Drawing.Color]::FromArgb(255, 255, 240, 150), [System.Drawing.Color]::FromArgb(255, 255, 170, 40))
    $white = @([System.Drawing.Color]::White, [System.Drawing.Color]::FromArgb(255, 220, 230, 255))
    $dark = [System.Drawing.Color]::FromArgb(255, 60, 25, 90)
    if ($Icon) {
        Draw-Outlined $Logo 64 ($w / 2) ($h - 62) $gold $dark 14
    } else {
        if ($Title -ne "") {
            $size = 124
            Draw-Outlined $Title $size ($w / 2) ($h - 140) $white $dark 22
        }
        Draw-Outlined $Logo 70 270 80 $gold $dark 14
    }
    $out.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $out.Dispose()
} finally {
    $img.Dispose()
}
Write-Output "Saved $Destination"
