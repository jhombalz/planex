# Read alpha bounds only; generated PNGs remain unchanged.
param([ValidateSet('arcade','expansion')][string]$AtlasKind='arcade')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$atlasPath = Join-Path $PSScriptRoot "../assets/images/${AtlasKind}_atlas.png"
$atlas = [System.Drawing.Bitmap]::FromFile((Resolve-Path $atlasPath))
$names = @('swift','striker','enemyScout','enemyInterceptor','enemyGunship','bossCoral','bossHarbor','bossStorm','pulse','enemyBullet','missile','plasma','laser','bossTurret','bossCore','bomb')
$columns=4
if($AtlasKind -eq 'expansion') { $names=@('wraith','bossSunset','bossArctic','bossVolcano'); $columns=2 }
$rects = @{}
try {
  for ($index = 0; $index -lt $names.Length; $index++) {
    $left = [int][Math]::Floor(($index % $columns) * $atlas.Width / $columns)
    $top = [int][Math]::Floor([Math]::Floor($index / $columns) * $atlas.Height / $columns)
    $right = [int][Math]::Floor((($index % $columns) + 1) * $atlas.Width / $columns)
    $bottom = [int][Math]::Floor(([Math]::Floor($index / $columns) + 1) * $atlas.Height / $columns)
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
  [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot "../assets/images/${AtlasKind}_atlas.json"), $json, [System.Text.UTF8Encoding]::new($false))
  Write-Output $json
} finally { $atlas.Dispose() }
