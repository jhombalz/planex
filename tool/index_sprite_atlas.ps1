# Read alpha bounds only; the generated PNG remains unchanged.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$atlasPath = Join-Path $PSScriptRoot '../assets/images/arcade_atlas.png'
$atlas = [System.Drawing.Bitmap]::FromFile((Resolve-Path $atlasPath))
$names = @('swift','striker','enemyScout','enemyInterceptor','enemyGunship','bossCoral','bossHarbor','bossStorm','pulse','enemyBullet','missile','plasma','laser','bossTurret','bossCore','bomb')
$rects = @{}
try {
  for ($index = 0; $index -lt 16; $index++) {
    $left = [int][Math]::Floor(($index % 4) * $atlas.Width / 4.0)
    $top = [int][Math]::Floor([Math]::Floor($index / 4.0) * $atlas.Height / 4.0)
    $right = [int][Math]::Floor((($index % 4) + 1) * $atlas.Width / 4.0)
    $bottom = [int][Math]::Floor(([Math]::Floor($index / 4.0) + 1) * $atlas.Height / 4.0)
    $minX = $right; $maxX = $left; $minY = $bottom; $maxY = $top
    for ($y = $top; $y -lt $bottom; $y++) {
      for ($x = $left; $x -lt $right; $x++) {
        if ($atlas.GetPixel($x,$y).A -gt 24) {
          if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
          if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
        }
      }
    }
    if ($maxX -lt $minX -or $maxY -lt $minY) { throw "Empty sprite: $($names[$index])" }
    $rects[$names[$index]] = @($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
  }
  $manifest = @{ width = $atlas.Width; height = $atlas.Height; sprites = $rects }
  $json = $manifest | ConvertTo-Json -Depth 4
  [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot '../assets/images/arcade_atlas.json'), $json, [System.Text.UTF8Encoding]::new($false))
  Write-Output $json
} finally { $atlas.Dispose() }
