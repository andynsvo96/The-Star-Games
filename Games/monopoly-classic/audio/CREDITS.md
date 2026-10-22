# Classic board effects

`roll.wav`, `chest.wav` and `jail.wav` are original procedural effects for this
project: several dice impacts, a wooden chest creak, and a closing steel gate.
`doubles.wav` is an original three-note bell cue for the gold doubles burst.
The deterministic standard-library generator is `../art/board_art.py`; source
WAVs and the vector board illustrations remain in
`asset/monopoly-classic/originals/board-details/` at the repository root.

`card-draw.ogg` is the unchanged Kenney Casino Audio 1.1 `card-slide-1.ogg`, also
used by Monopoly Deal and UNO, licensed CC0. The original archive and license
are preserved in `asset/uno/audio/kenney_casino-audio.zip` and
`asset/uno/audio/Kenney-License.txt`. A copy of that license is included here.
Source: https://opengameart.org/content/54-casino-sound-effects-cards-dice-chips

The remaining WAV cues retain Classic's original generator in `../art/generate.py`.
No audio is sampled from another Monopoly game. All cues are local, follow the
host presentation clock, and use the shared Effects bus. Phones do not echo them.
