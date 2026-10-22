# Card sounds

Poker uses the same unmodified Kenney Casino Audio effects as UNO:
`card-shuffle.ogg`, `card-slide-1.ogg`, and `card-place-1.ogg` (CC0).

Credit: Kenney.nl. Source:
https://opengameart.org/content/54-casino-sound-effects-cards-dice-chips

The original archive and license remain in `asset/uno/audio/kenney_casino-audio.zip`
and `asset/uno/audio/Kenney-License.txt`. These module-local copies work offline
on Windows, macOS, and Android, through the host's Effects bus at UNO's gain.
Shuffle plays once at the opening deal; slides follow each dealt card, and
community cards also use the placement cue when they land. Pauses freeze the
sound timeline; reduced motion uses a single card cue per reveal.

The original synthesized WAV effects remain as source history, generated with
`generate.py`. Chip transfers and wins still use `chips.wav` and `win.wav`.

`all-in.ogg` is the unmodified `Audio/chips-handle-4.ogg` from that same Kenney
CC0 archive. This short chip/money jingle plays once when the solo host's BET
control becomes ALL IN, including slider and typed amounts. Clock updates do
not repeat it; pauses suspend playback and reset/exit stop it. It uses its own
Effects player so it does not interrupt card handling or transfers.
