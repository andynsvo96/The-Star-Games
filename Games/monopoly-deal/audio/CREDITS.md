# Card sounds

Monopoly Deal uses the same Kenney **Casino Audio 1.1** card recordings as UNO.
These offline OGG files are unmodified and licensed CC0:

- `card-shuffle.ogg`: opening shuffle and recycling the discard pile.
- `card-slide-1.ogg`: dealing, drawing and sliding public assets between players.
- `card-place-1.ogg`: playing, discarding, placing buildings and moving properties.
- `card-place-2.ogg`: banking and receiving bank payments.

Source: https://opengameart.org/content/54-casino-sound-effects-cards-dice-chips
Credit: Kenney.nl. The license is included beside these files. The unchanged
source archive and license are preserved at `asset/uno/audio/kenney_casino-audio.zip`
and `asset/uno/audio/Kenney-License.txt` for both games.

Sounds play once on the host through the shared Effects bus, following the
authoritative card-motion timeline. Private browser hands do not produce duplicate
audio on every phone. Pausing stops current playback and freezes upcoming cues;
resuming continues with the remaining card movements. Reduced motion collapses
each group of immediate placements to one cue of each kind. Leaving or starting
another game clears pending sounds. Simultaneous card voices are bounded, and
overdue cues of the same kind are combined after a stalled frame.

The existing theme slot IDs `sound-deal`, `sound-play`, `sound-bank`,
`sound-action` and `sound-win` are unchanged, so saved cosmetic packs retain
their replacements. The first four now default to these recordings. `win.wav`
remains the separate original victory cue. Earlier generated WAV card tones are
retained as source history in `asset/monopoly-deal/originals/audio` and are no
longer played by the default theme. No Ubisoft or Hasbro game audio is used.

`cash-register.wav` and `stop-buzzer.wav` are original procedural recordings
created for this project. They contain no samples from other games or libraries.
The register combines mechanical transients with a metallic bell; the buzzer
uses a descending pair of raspy tones. Their deterministic standard-library
generator and source WAVs are preserved in
`asset/monopoly-deal/audio/table-feedback/`; regenerate both source and runtime
copies with `python asset/monopoly-deal/audio/table-feedback/generate.py`.

The additive theme slots `sound-cash` and `sound-stop` control these cues.
Cash plays when payment cards land in another player's Bank, including banked
actions and buildings. Self-banking and property theft do not trigger it.
The buzzer plays on an accepted Just Say No counter. Both follow the same host
timeline, pause, reduced-motion, duplicate-sync and exit behavior described above.
The host mixes the buzzer at -7 dB (3 dB below its previous level); its source
recording and shared Effects volume are preserved.
