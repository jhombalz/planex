$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$source=[System.Drawing.Bitmap]::FromFile((Resolve-Path (Join-Path $PSScriptRoot '../assets/images/launcher_source.png')))
try {
  $sizes=@{'mdpi'=48;'hdpi'=72;'xhdpi'=96;'xxhdpi'=144;'xxxhdpi'=192}
  foreach($entry in $sizes.GetEnumerator()) {
    $size=[int]$entry.Value
    $bitmap=[System.Drawing.Bitmap]::new($size,$size)
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#061B29'))
      $graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.DrawImage($source,0,0,$size,$size)
      $folder=Join-Path $PSScriptRoot "../android/app/src/main/res/mipmap-$($entry.Key)"
      [System.IO.Directory]::CreateDirectory($folder)|Out-Null
      $bitmap.Save((Join-Path $folder 'ic_launcher.png'),[System.Drawing.Imaging.ImageFormat]::Png)
      $bitmap.Save((Join-Path $folder 'ic_launcher_round.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    } finally {$graphics.Dispose();$bitmap.Dispose()}
  }
  $target=Join-Path $PSScriptRoot '../android/app/src/main/res/drawable-nodpi'
  [System.IO.Directory]::CreateDirectory($target)|Out-Null
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../assets/images/launcher_source.png') -Destination (Join-Path $target 'launcher_aircraft.png') -Force
} finally {$source.Dispose()}
