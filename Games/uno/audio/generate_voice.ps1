# Crop the first spoken word from the preserved human recording (CC BY 4.0).
# See CREDITS.md. The old SAPI source remains in asset/ for provenance.
# No network or speech service is used by the generator or the game.
$unoSource = Join-Path $PSScriptRoot '../../../asset/uno/audio/iceofdoom-counting-spanish-source.mp3'
& ffmpeg -hide_banner -loglevel error -y -ss 2.43 -t 0.53 -i $unoSource -af 'highpass=f=90,lowpass=f=12000,afade=t=in:d=0.012,afade=t=out:st=0.49:d=0.04,loudnorm=I=-16:TP=-1.5:LRA=7' -ar 48000 -ac 1 -c:a libvorbis -q:a 6 (Join-Path $PSScriptRoot 'uno-voice.ogg')
if ($LASTEXITCODE -ne 0) { throw 'UNO voice encoding failed.' }
