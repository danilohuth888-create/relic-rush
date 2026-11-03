# Crops a screenshot to 16:9 (centered) and scales it to 1920x1080 PNG for Roblox thumbnails.
# Usage: powershell -File tools/marketing/make-thumbnail.ps1 <input image> <output.png>
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
)

Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
try {
    $ratio = 16 / 9
    $cropW = [int][Math]::Min($img.Width, [Math]::Round($img.Height * $ratio))
    $cropH = [int][Math]::Round($cropW / $ratio)
    $x = [int](($img.Width - $cropW) / 2)
    $y = [int](($img.Height - $cropH) / 2)

    $out = New-Object System.Drawing.Bitmap 1920, 1080
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, 1920, 1080), (New-Object System.Drawing.Rectangle $x, $y, $cropW, $cropH), [System.Drawing.GraphicsUnit]::Pixel)
    $out.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $out.Dispose()
} finally {
    $img.Dispose()
}
Write-Output "Saved $Destination (1920x1080)"
