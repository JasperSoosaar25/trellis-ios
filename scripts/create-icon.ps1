$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$iconDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) 'App\Assets.xcassets\AppIcon.appiconset'
New-Item -ItemType Directory -Path $iconDirectory -Force | Out-Null
$bitmap = New-Object System.Drawing.Bitmap 1024,1024
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$rectangle = New-Object System.Drawing.Rectangle 0,0,1024,1024
$background = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rectangle,([System.Drawing.Color]::FromArgb(7,38,46)),([System.Drawing.Color]::FromArgb(11,105,109)),45
$graphics.FillRectangle($background, $rectangle)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(228,252,242)),56
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLine($pen, 360,760,360,300)
$curve = New-Object System.Drawing.Drawing2D.GraphicsPath
$curve.AddBezier(360,600,360,470,650,540,650,325)
$graphics.DrawPath($pen,$curve)
$leafBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(104,232,178))
$graphics.FillEllipse($leafBrush,276,212,168,168)
$graphics.FillEllipse($leafBrush,566,237,168,168)
$graphics.FillEllipse($leafBrush,276,692,168,168)
$bitmap.Save((Join-Path $iconDirectory 'AppIcon.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$curve.Dispose(); $pen.Dispose(); $leafBrush.Dispose(); $background.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
