# Regenerate the offline vector cards on Windows. Text becomes paths so Godot
# and browsers display the same artwork without a font dependency.
Add-Type -AssemblyName System.Drawing
$destination = Join-Path $PSScriptRoot 'cards'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$culture = [Globalization.CultureInfo]::InvariantCulture
function Number($value) { $value.ToString('0.##', $culture) }
function Lettering($label, $x, $y, $size, $fill, $stroke = '#15131a', $width = 2) {
  $path = New-Object Drawing.Drawing2D.GraphicsPath
  $font = New-Object Drawing.FontFamily 'Arial'
  $path.AddString($label, $font, [int][Drawing.FontStyle]::Bold, $size, [Drawing.PointF]::new(0,0), [Drawing.StringFormat]::GenericTypographic)
  $bounds = $path.GetBounds()
  $points = $path.PathPoints; $types = $path.PathTypes
  $dx = $x - $bounds.X - $bounds.Width / 2; $dy = $y - $bounds.Y - $bounds.Height / 2
  $data = [Text.StringBuilder]::new()
  for ($index = 0; $index -lt $points.Length; $index++) {
    $kind = $types[$index] -band 7
    $pair = (Number ($points[$index].X + $dx)) + ',' + (Number ($points[$index].Y + $dy))
    if ($kind -eq 0) { [void]$data.Append('M' + $pair) }
    elseif ($kind -eq 1) { [void]$data.Append('L' + $pair) }
    elseif ($kind -eq 3) {
      [void]$data.Append('C' + $pair + ' ')
      $index++; [void]$data.Append((Number ($points[$index].X + $dx)) + ',' + (Number ($points[$index].Y + $dy)) + ' ')
      $index++; [void]$data.Append((Number ($points[$index].X + $dx)) + ',' + (Number ($points[$index].Y + $dy)))
    }
    if (($types[$index] -band 128) -ne 0) { [void]$data.Append('Z') }
  }
  $path.Dispose(); $font.Dispose()
  return '<path d="' + $data.ToString() + '" fill="' + $fill + '" stroke="' + $stroke + '" stroke-width="' + $width + '" stroke-linejoin="round" paint-order="stroke fill"/>'
}
function ActionSymbol($kind, $x, $y, $scale) {
  $shape = if ($kind -eq 'skip') {
    '<circle cx="60" cy="90" r="24" fill="none" stroke="#13141d" stroke-width="13"/><circle cx="60" cy="90" r="24" fill="none" stroke="#fff" stroke-width="7"/><path d="M42 108L78 72" stroke="#13141d" stroke-width="13"/><path d="M42 108L78 72" stroke="#fff" stroke-width="7"/>'
  } else {
    '<path d="M41 111V78Q41 63 57 63H64V53L83 70L64 86V76H57Q53 76 53 80V111ZM79 69V102Q79 117 63 117H56V127L37 110L56 94V104H63Q67 104 67 100V69Z" fill="#fff" stroke="#14141a" stroke-width="3" stroke-linejoin="round"/>'
  }
  return '<g data-action-symbol="' + $kind + '" transform="translate(' + (Number $x) + ' ' + (Number $y) + ') scale(' + (Number $scale) + ') translate(-60 -90)">' + $shape + '</g>'
}
$suits = @{red='#ed202e';yellow='#f7cf05';green='#08a750';blue='#0869db';wild='#14151b'}
foreach ($suit in @('red','yellow','green','blue','wild')) {
  $kinds = if ($suit -eq 'wild') {@('wild','draw4','back')} else {@('0','1','2','3','4','5','6','7','8','9','skip','reverse','draw2')}
  foreach ($kind in $kinds) {
    $body = '<rect x="2" y="2" width="116" height="176" rx="11" fill="#fffdf2" stroke="#13141d" stroke-width="2"/><rect x="9" y="9" width="102" height="162" rx="6" fill="' + $suits[$suit] + '"/>'
    if ($kind -eq 'back') {
      $body += '<ellipse cx="60" cy="90" rx="46" ry="62" transform="rotate(28 60 90)" fill="#e61927"/>'
      $body += '<g transform="rotate(-20 60 90)">' + (Lettering 'UNO' 60 90 43 '#ffd72a' '#08080d' 4) + '</g>'
    } elseif ($suit -eq 'wild') {
      $body += '<g transform="rotate(25 60 90)"><path d="M60 33A37 57 0 0 0 23 90H60Z" fill="#ed202e"/><path d="M60 33A37 57 0 0 1 97 90H60Z" fill="#0869db"/><path d="M97 90A37 57 0 0 1 60 147V90Z" fill="#08a750"/><path d="M60 147A37 57 0 0 1 23 90H60Z" fill="#f7cf05"/><ellipse cx="60" cy="90" rx="37" ry="57" fill="none" stroke="#fff" stroke-width="4"/></g>'
      if ($kind -eq 'draw4') { $body += Lettering '+4' 26 26 23 '#fff'; $body += Lettering '+4' 60 90 47 '#fff' '#111' 4 }
      else { $body += '<circle cx="25" cy="25" r="10" fill="#ed202e"/><path d="M25 15A10 10 0 0 1 35 25H25Z" fill="#0869db"/><path d="M35 25A10 10 0 0 1 25 35V25Z" fill="#08a750"/><path d="M25 35A10 10 0 0 1 15 25H25Z" fill="#f7cf05"/>' }
    } else {
      $body += '<ellipse cx="60" cy="90" rx="39" ry="63" transform="rotate(25 60 90)" fill="none" stroke="#fffdf2" stroke-width="4"/>'
      if ($kind -in @('skip','reverse')) {
        $corner = ActionSymbol $kind 25 27 $(if ($kind -eq 'skip') {0.34} else {0.30})
        $body += $corner + '<g transform="rotate(180 60 90)">' + $corner + '</g>'
      } else {
        $label = if ($kind -eq 'draw2') {'+2'} else {$kind}
        $body += Lettering $label 27 27 24 '#fff'
        $body += '<g transform="rotate(180 60 90)">' + (Lettering $label 27 27 24 '#fff') + '</g>'
      }
      if ($kind -eq 'draw2') { $body += '<rect x="43" y="73" width="27" height="41" rx="3" transform="rotate(12 60 90)" fill="#fff" stroke="#111" stroke-width="3"/><rect x="56" y="57" width="27" height="41" rx="3" transform="rotate(12 60 90)" fill="#fff" stroke="#111" stroke-width="3"/>' }
      elseif ($kind -in @('skip','reverse')) { $body += ActionSymbol $kind 60 90 1 }
      else { $body += Lettering $kind 60 90 75 '#fff' '#16151d' 4; if ($kind -in @('6','9')) {$body += '<path d="M44 124H76" stroke="#fff" stroke-width="4"/>'} }
    }
    $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="180" viewBox="0 0 120 180">' + $body + '</svg>'
    [IO.File]::WriteAllText((Join-Path $destination ($suit + '-' + $kind + '.svg')), $svg)
  }
}
Write-Output 'Generated 55 offline vector card faces and backs.'
foreach ($suit in @('red','yellow','green','blue')) {
  foreach ($kind in @('wild','draw4')) {
    $chosen = [IO.File]::ReadAllText((Join-Path $destination ('wild-' + $kind + '.svg')))
    foreach ($original in @('red','yellow','green','blue')) {
      $chosen = $chosen.Replace('fill="' + $suits[$original] + '"', 'fill="SELECTED-COLOR"')
    }
    $chosen = $chosen.Replace('SELECTED-COLOR', $suits[$suit])
    [IO.File]::WriteAllText((Join-Path $destination ($suit + '-' + $kind + '-chosen.svg')), $chosen)
  }
}
Write-Output 'Generated eight chosen-color Wild/Draw Four table faces.'
$back = [IO.File]::ReadAllText((Join-Path $destination 'wild-back.svg')) -replace '^<svg[^>]+>', '' -replace '</svg>$', ''
$red = [IO.File]::ReadAllText((Join-Path $destination 'red-7.svg')) -replace '^<svg[^>]+>', '' -replace '</svg>$', ''
$yellow = [IO.File]::ReadAllText((Join-Path $destination 'yellow-draw2.svg')) -replace '^<svg[^>]+>', '' -replace '</svg>$', ''
$thumbnail = '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360"><rect width="640" height="360" rx="32" fill="#201738"/><ellipse cx="320" cy="270" rx="285" ry="145" fill="#ac561e" stroke="#ffcf32" stroke-width="8"/><g transform="translate(170 42) rotate(-15 60 90) scale(1.45)">' + $red + '</g><g transform="translate(268 27) scale(1.55)">' + $back + '</g><g transform="translate(381 44) rotate(15 60 90) scale(1.45)">' + $yellow + '</g>' + '</svg>'
[IO.File]::WriteAllText((Join-Path $PSScriptRoot '../thumbnail.svg'), $thumbnail)

# Flip adds its own actions and black-bordered dark faces; Classic art is unchanged.
$darkSuits = @{pink='#f03b8b';teal='#00a99d';orange='#f58220';purple='#8a4ed2'}
$flipSymbol = '<rect x="40" y="61" width="27" height="43" rx="4" fill="#fff" stroke="#15131a" stroke-width="3"/><rect x="54" y="78" width="27" height="43" rx="4" fill="#15131a" stroke="#fff" stroke-width="3"/><path d="M30 77Q23 45 67 43L65 34L85 44L66 55L67 46M90 105Q97 139 53 141L55 150L35 140L54 129L53 138" fill="none" stroke="#fff" stroke-width="5" stroke-linejoin="round"/>'
$skipAllSymbol = '<g fill="none" stroke="#fff" stroke-width="5"><circle cx="39" cy="72" r="13"/><circle cx="79" cy="72" r="13"/><circle cx="59" cy="112" r="13"/><path d="M30 81L48 63M70 81L88 63M50 121L68 103"/></g>'
function FlipFace($suit, $kind, $dark) {
  $border = if ($dark) {'#15131a'} else {'#fffdf2'}
  $fill = if ($suit -eq 'wild') {'#14151b'} elseif ($dark) {$darkSuits[$suit]} else {$suits[$suit]}
  $body = '<rect x="2" y="2" width="116" height="176" rx="11" fill="' + $border + '" stroke="#13141d" stroke-width="2"/><rect x="9" y="9" width="102" height="162" rx="6" fill="' + $fill + '"/>'
  if ($suit -eq 'wild') {
    $palette = if ($dark) {@('pink','purple','orange','teal')} else {@('red','blue','green','yellow')}
    $colors = if ($dark) {$darkSuits} else {$suits}
    $body += '<g transform="rotate(25 60 90)"><path d="M60 33A37 57 0 0 0 23 90H60Z" fill="'+$colors[$palette[0]]+'"/><path d="M60 33A37 57 0 0 1 97 90H60Z" fill="'+$colors[$palette[1]]+'"/><path d="M97 90A37 57 0 0 1 60 147V90Z" fill="'+$colors[$palette[2]]+'"/><path d="M60 147A37 57 0 0 1 23 90H60Z" fill="'+$colors[$palette[3]]+'"/><ellipse cx="60" cy="90" rx="37" ry="57" fill="none" stroke="#fff" stroke-width="4"/></g>'
    if ($kind -eq 'draw2') { $body += (Lettering '+2' 27 27 24 '#fff') + (Lettering '+2' 60 90 47 '#fff' '#111' 4) }
    elseif ($kind -eq 'draw_color') {
      $body += (Lettering '+' 25 25 28 '#fff') + '<path d="M38 99H73V88L92 106L73 124V113H38Z" fill="#fff" stroke="#15131a" stroke-width="3"/><rect x="39" y="64" width="26" height="35" rx="3" fill="#15131a" stroke="#fff" stroke-width="3"/>'
    } else { $body += '<circle cx="25" cy="25" r="9" fill="'+$colors[$palette[0]]+'" stroke="#fff" stroke-width="2"/>' }
  } else {
    $body += '<ellipse cx="60" cy="90" rx="39" ry="63" transform="rotate(25 60 90)" fill="none" stroke="#fffdf2" stroke-width="4"/>'
    if ($kind -eq 'reverse') { $symbol = ActionSymbol 'reverse' 60 90 1 }
    elseif ($kind -eq 'flip') { $symbol = $flipSymbol }
    elseif ($kind -eq 'skip_all') { $symbol = $skipAllSymbol }
    else { $symbol = '' }
    if ($symbol) {
      $body += '<g transform="translate(25 27) scale(.29) translate(-60 -90)">'+$symbol+'</g><g transform="rotate(180 60 90) translate(25 27) scale(.29) translate(-60 -90)">'+$symbol+'</g>'+$symbol
    } else {
      $label = if ($kind -eq 'draw1') {'+1'} elseif ($kind -eq 'draw5') {'+5'} else {$kind}
      $corner = Lettering $label 27 27 24 '#fff'
      $body += $corner + '<g transform="rotate(180 60 90)">' + $corner + '</g>'
      $body += Lettering $label 60 90 $(if ($kind -in @('draw1','draw5')) {53} else {75}) '#fff' '#16151d' 4
      if ($kind -in @('6','9')) {$body += '<path d="M44 124H76" stroke="#fff" stroke-width="4"/>'}
    }
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="180" viewBox="0 0 120 180">'+$body+'</svg>'
}
foreach ($suit in @('red','yellow','green','blue')) {
  foreach ($kind in @('draw1','flip')) { [IO.File]::WriteAllText((Join-Path $destination ($suit+'-'+$kind+'.svg')), (FlipFace $suit $kind $false)) }
}
foreach ($suit in @('pink','teal','orange','purple')) {
  foreach ($kind in @('1','2','3','4','5','6','7','8','9','draw5','reverse','skip_all','flip')) {
    [IO.File]::WriteAllText((Join-Path $destination ('flip-dark-'+$suit+'-'+$kind+'.svg')), (FlipFace $suit $kind $true))
  }
}
foreach ($dark in @($false,$true)) {
  $prefix = if ($dark) {'flip-dark-'} else {''}
  $palette = if ($dark) {$darkSuits} else {$suits}
  $wildKinds = if ($dark) {@('wild','draw_color')} else {@('draw2')}
  foreach ($kind in $wildKinds) {
    $face = FlipFace 'wild' $kind $dark
    [IO.File]::WriteAllText((Join-Path $destination ($prefix+'wild-'+$kind+'.svg')), $face)
    foreach ($suit in $palette.Keys) {
      if ($suit -eq 'wild') {continue}
      $chosen = $face
      foreach ($color in $palette.Keys) {if ($color -ne 'wild') {$chosen = $chosen.Replace('fill="'+$palette[$color]+'"','fill="SELECTED-COLOR"')}}
      $chosen = $chosen.Replace('SELECTED-COLOR',$palette[$suit])
      [IO.File]::WriteAllText((Join-Path $destination ($prefix+$suit+'-'+$kind+'-chosen.svg')), $chosen)
    }
  }
}
Write-Output 'Generated offline Flip light actions, dark faces and chosen Wild colors.'


# No Mercy shares the same card geometry and vector symbols.
function NoMercyFace($suit, $kind) {
  if ($suit -eq 'wild') {
    $body = (FlipFace 'wild' 'wild' $false) -replace '</svg>$', ''
    if ($kind -in @('draw6','draw10','reverse_draw4')) {
      $label = if ($kind -eq 'draw6') {'+6'} elseif ($kind -eq 'draw10') {'+10'} else {'+4'}
      $corner = Lettering $label 28 27 22 '#fff'
      $body += $corner + '<g transform="rotate(180 60 90)">' + $corner + '</g>'
      if ($kind -eq 'reverse_draw4') {
        $body += (ActionSymbol 'reverse' 60 79 .72) + (Lettering '+4' 60 126 33 '#fff' '#111' 3)
      } else { $body += Lettering $label 60 90 43 '#fff' '#111' 4 }
    } else {
      $roulette = '<path d="M37 75A26 26 0 1 1 35 104M37 75V57M37 75H55" fill="none" stroke="#15131a" stroke-width="10" stroke-linejoin="round"/><path d="M37 75A26 26 0 1 1 35 104M37 75V57M37 75H55" fill="none" stroke="#fff" stroke-width="5" stroke-linejoin="round"/><path d="M52 79L76 91L52 103Z" fill="#fff" stroke="#15131a" stroke-width="3"/>'
      $body += $roulette
    }
    return $body + '</svg>'
  }
  $body = '<rect x="2" y="2" width="116" height="176" rx="11" fill="#fffdf2" stroke="#13141d" stroke-width="2"/><rect x="9" y="9" width="102" height="162" rx="6" fill="'+$suits[$suit]+'"/><ellipse cx="60" cy="90" rx="39" ry="63" transform="rotate(25 60 90)" fill="none" stroke="#fffdf2" stroke-width="4"/>'
  if ($kind -eq 'draw4') {
    $corner = Lettering '+4' 27 27 24 '#fff'
    $body += $corner + '<g transform="rotate(180 60 90)">' + $corner + '</g>'
    $body += Lettering '+4' 60 90 53 '#fff' '#16151d' 4
  } else {
    $symbol = if ($kind -eq 'skip_all') {$skipAllSymbol} else {'<rect x="36" y="58" width="28" height="43" rx="4" fill="#fff" stroke="#15131a" stroke-width="3"/><rect x="47" y="67" width="28" height="43" rx="4" fill="#fff" stroke="#15131a" stroke-width="3"/><rect x="58" y="76" width="28" height="43" rx="4" fill="#fff" stroke="#15131a" stroke-width="3"/><path d="M29 127H71V119L90 133L71 147V139H29Z" fill="#fff" stroke="#15131a" stroke-width="3"/>'}
    $body += '<g transform="translate(25 27) scale(.29) translate(-60 -90)">'+$symbol+'</g><g transform="rotate(180 60 90) translate(25 27) scale(.29) translate(-60 -90)">'+$symbol+'</g>'+$symbol
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="180" viewBox="0 0 120 180">'+$body+'</svg>'
}
foreach ($suit in @('red','yellow','green','blue')) {
  foreach ($kind in @('draw4','discard_all','skip_all')) {
    [IO.File]::WriteAllText((Join-Path $destination ($suit+'-'+$kind+'.svg')), (NoMercyFace $suit $kind))
  }
}
foreach ($kind in @('reverse_draw4','draw6','draw10','color_roulette')) {
  $face = NoMercyFace 'wild' $kind
  [IO.File]::WriteAllText((Join-Path $destination ('wild-'+$kind+'.svg')), $face)
  foreach ($suit in @('red','yellow','green','blue')) {
    $chosen = $face
    foreach ($color in @('red','yellow','green','blue')) {$chosen = $chosen.Replace('fill="'+$suits[$color]+'"','fill="SELECTED-COLOR"')}
    $chosen = $chosen.Replace('SELECTED-COLOR',$suits[$suit])
    [IO.File]::WriteAllText((Join-Path $destination ($suit+'-'+$kind+'-chosen.svg')), $chosen)
  }
}
Write-Output 'Generated 32 offline No Mercy card faces and chosen Wild colors.'


# Dedicated No Mercy artwork: dark frames, black number ovals, and heavier actions.
# Keep the Classic and Flip filenames intact; mode-specific rendering uses this prefix.
function MercyStyledFace($suit, $kind) {
  $source = Join-Path $destination ($suit + '-' + $kind + '.svg')
  $face = [IO.File]::ReadAllText($source)
  $face = $face.Replace('fill="#fffdf2" stroke="#13141d" stroke-width="2"', 'fill="#101014" stroke="#f1eee7" stroke-width="2"')
  $face = $face.Replace('fill="none" stroke="#fffdf2" stroke-width="4"', 'fill="#101014" stroke="#fffdf2" stroke-width="3"')
  if ($kind -eq 'back') {
    $face = '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="180" viewBox="0 0 120 180"><rect x="2" y="2" width="116" height="176" rx="11" fill="#101014" stroke="#f1eee7" stroke-width="2"/><rect x="9" y="9" width="102" height="162" rx="6" fill="#e61927"/><path d="M12 119L102 29M16 149L107 59M25 164L108 82" stroke="#a40816" stroke-width="7"/><g transform="rotate(-20 60 90)">' + (Lettering 'UNO' 60 79 42 '#ffd72a' '#08080d' 4) + (Lettering 'NO MERCY' 60 119 14 '#fff' '#08080d' 1) + '</g></svg>'
  } elseif ($suit -eq 'wild' -and $kind -ne 'wild') {
    $label = if ($kind -eq 'draw6') {'+6'} elseif ($kind -eq 'draw10') {'+10'} elseif ($kind -in @('draw4','reverse_draw4')) {'+4'} else {''}
    $face = '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="180" viewBox="0 0 120 180"><rect x="2" y="2" width="116" height="176" rx="11" fill="#101014" stroke="#f1eee7" stroke-width="2"/><ellipse cx="60" cy="90" rx="39" ry="63" transform="rotate(25 60 90)" fill="#fffdf2"/>'
    if ($label) {
      $corner = Lettering $label 27 25 23 '#fff' '#08080d' 1
      $face += $corner + '<g transform="rotate(180 60 90)">' + $corner + '</g>'
      $face += Lettering $label 60 67 39 '#101014' '#fffdf2' 1
      $offset = 0
      foreach ($color in @('red','yellow','green','blue')) {
        $face += '<rect x="'+(34+$offset*10)+'" y="'+(95-$offset*4)+'" width="22" height="34" rx="3" fill="'+$suits[$color]+'" stroke="#101014" stroke-width="2" transform="rotate(12 60 110)"/>'
        $offset++
      }
      if ($kind -eq 'reverse_draw4') {$face += ActionSymbol 'reverse' 60 91 .38}
    } else {
      $offset = 0
      foreach ($color in @('red','yellow','green','blue')) {
        $x = 42 + ($offset % 2) * 34; $y = 70 + [Math]::Floor($offset / 2) * 38
        $face += '<g transform="translate('+ $x +' '+ $y +')"><circle r="16" fill="'+$suits[$color]+'" stroke="#101014" stroke-width="2"/><path d="M-9 -7L-3 -4M9 -7L3 -4M-8 9Q0 -1 8 9" fill="none" stroke="#101014" stroke-width="2.5" stroke-linecap="round"/><circle cx="-6" cy="-2" r="1.8" fill="#101014"/><circle cx="6" cy="-2" r="1.8" fill="#101014"/></g>'
        $offset++
      }
    }
    $face += '</svg>'
  } elseif ($kind -in @('0','7')) {
    # The two hand-transfer numbers are visibly marked even with house rules off.
    $transfer = if ($kind -eq '7') {'<path d="M39 132H74L67 125M81 145H46L53 152" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'} else {'<path d="M40 140A20 12 0 1 1 76 145M76 145L74 136M76 145L66 144" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'}
    $face = $face.Replace('</svg>', $transfer + '</svg>')
  }
  return $face
}
foreach ($suit in @('red','yellow','green','blue')) {
  foreach ($kind in @('0','1','2','3','4','5','6','7','8','9','skip','reverse','draw2','draw4','discard_all','skip_all')) {
    [IO.File]::WriteAllText((Join-Path $destination ('no-mercy-'+$suit+'-'+$kind+'.svg')), (MercyStyledFace $suit $kind))
  }
}
foreach ($kind in @('wild','draw4','reverse_draw4','draw6','draw10','color_roulette','back')) {
  $face = MercyStyledFace 'wild' $kind
  if ($kind -ne 'back') {
    # The explicit color choice retains visible sectors over the same hit region.
    $picker = [IO.File]::ReadAllText((Join-Path $destination ('wild-'+$kind+'.svg'))).Replace('fill="#fffdf2" stroke="#13141d" stroke-width="2"','fill="#101014" stroke="#f1eee7" stroke-width="2"')
    [IO.File]::WriteAllText((Join-Path $destination ('no-mercy-wild-'+$kind+'-picker.svg')), $picker)
  }
  [IO.File]::WriteAllText((Join-Path $destination ('no-mercy-wild-'+$kind+'.svg')), $face)
  if ($kind -eq 'back') { continue }
  foreach ($suit in @('red','yellow','green','blue')) {
    $chosen = $face
    foreach ($color in @('red','yellow','green','blue')) { $chosen = $chosen.Replace('fill="'+$suits[$color]+'"','fill="SELECTED-COLOR"') }
    $chosen = $chosen.Replace('SELECTED-COLOR',$suits[$suit])
    [IO.File]::WriteAllText((Join-Path $destination ('no-mercy-'+$suit+'-'+$kind+'-chosen.svg')), $chosen)
  }
}
Write-Output 'Generated dedicated No Mercy faces, backs, and chosen-color Wilds.'
