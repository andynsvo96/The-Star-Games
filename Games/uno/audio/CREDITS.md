# Card sounds

Card placement, sliding and shuffling use Kenney's **Casino Audio**
card-handling effects, licensed CC0. These offline OGG files are unmodified:
`card-place-1.ogg`, `card-place-2.ogg`, `card-slide-1.ogg`, `card-fan-1.ogg`,
and `card-shuffle.ogg`.

Source: https://opengameart.org/content/54-casino-sound-effects-cards-dice-chips

Credit: Kenney.nl. The original archive and license are preserved in
`asset/uno/audio/kenney_casino-audio.zip` and `asset/uno/audio/Kenney-License.txt`.
UNO declarations are now silent and use a persistent animated logo instead of
speech. The following retired voice files remain as source history; the game
does not load or play them.

`uno-voice.ogg` uses the first spoken word from **"Uno, Dos, Tres, Cuatro" -
Counting Male (Spanish)** by **Iceofdoom**, published December 22, 2019 on
[Freesound](https://freesound.org/people/Iceofdoom/sounds/499634/).
Licensed [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
The enthusiastic human delivery replaces the Windows SAPI voice. Adaptation:
crop 2.43–2.96 seconds, filter low rumble/high noise, fade the edges, normalize,
and encode mono OGG. `generate_voice.ps1` recreates the cue offline with FFmpeg.
The downloaded high-quality preview is preserved unchanged in
`asset/uno/audio/iceofdoom-counting-spanish-source.mp3`; the older SAPI WAV remains
in `asset/uno/audio/uno-voice-source.wav` for provenance. This is a licensed human
recording with a playful delivery; it contains no Ubisoft game audio.

`victory.ogg` is an original rising bell fanfare, separate from the shuffle
foley used by the opening deal. Run `node Games/uno/audio/generate_victory.mjs`
then `ffmpeg -i asset/uno/audio/victory-source.wav -c:a libvorbis -q:a 6 Games/uno/audio/victory.ogg`
to recreate it. The generated WAV is retained in `asset/uno/audio` as its source.

No speech service is used at runtime; the current card and victory OGG files play on
Windows, macOS and Android through the Effects bus.

All effects inherit the host's Effects volume. The old generated WAV cues are
retained as earlier source assets but are no longer played by UNO.
