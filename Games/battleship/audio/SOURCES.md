# Battleship audio

The cannon, water miss, metal impact and sinking effects use recorded Foley,
trimmed and faded for the game's animation timing. Playback remains offline on
the shared Effects bus. The victory cue is a locally modeled bronze ship bell.

Original, unmodified archives are preserved in `asset/battleship/audio/`:

- `qubodup-NavalBattleSoundSet-cc0.7z`: version 2 of
  [Tiny Naval Battle Sounds Set](https://opengameart.org/content/tiny-naval-battle-sounds-set)
  by Iwan Gabovitch / qubodup, released under
  [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
  `GunShot.wav` supplies cannon fire; `Splash.wav` (a water recording by
  Grzegorz Adam Hankiewicz) supplies misses; `ExplosionMetal.wav` and
  `ExplosionMetalGverb.wav` supply steel hits and sinking, with water layered
  into the sinking cue.
- `water-splash-slime-sfx.zip`:
  [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx)
  by rubberduck, released under CC0. `splash_04.ogg` supplies quiet deployment
  water movement.

Run `python Games/battleship/audio/generate.py` from the repository root to rebuild
the runtime WAVs. It requires FFmpeg and an archive-capable `tar` only during
asset preparation, not in the game or on phones/Android hosts. Archives are
validated and extracted into a temporary build directory; source files remain
unchanged. Runtime files are mono 44.1 kHz, 16-bit WAVs with no looping.
