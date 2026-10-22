# Original Pictionary sound cues

The active set combines the original mallet cues with the retained studio
countdown, time-expiry and match-completion sounds. Incorrect guesses use one
quiet 140 ms damped 185 Hz note, with no layered noise, taps or extra voices.
All cues were synthesized using Python's standard library. No recordings or
online audio are used.

- `turn.wav`: the original new-turn mallet cue, restored byte for byte.
- `correct.wav`: the original correct-guess mallet cue, restored byte for byte.
- `wrong.wav`: a single soft, short note, played only on the host speaker.
- `countdown.wav`: one short wooden pencil tick per second in the final ten seconds.
- `time_up.wav`: a pencil rub and three descending desk taps.
- `match.wav`: a paper flourish and a rising wooden-tap celebration.

Run `python Games/pictionary/audio/generate.py` from the repository root to
assemble the active set from preserved sources. The mallet originals remain
untouched in `asset/pictionary/audio/`; the studio WAVs and synthesis generator
remain in its `studio-v2/` folder, including the retired layered wrong-guess cue.
The new single-tone original is preserved as `asset/pictionary/audio/wrong-single.wav`
and synthesized by the active `generate.py`.
Mallet cues use mono 22.05 kHz 16-bit PCM; retained studio cues use mono 44.1 kHz
16-bit PCM. The host uses the shared Effects bus. Phone playback
starts only after a user gesture, deduplicates host sequence IDs, and never
replays old cues on refresh or reconnect. Rejected guesses make no sound.
Wrong-guess sounds have a 400 ms host cooldown and one playback voice: triggers
during playback or another game cue are discarded, never queued or restarted.
Other cues stop an active wrong-guess sound. No wrong-guess sound event is sent
to phones, avoiding a roomful of duplicate playback.
Countdown ticks are host-authoritative and deduplicated by turn/second; they
stop on pause, reveal, replay and exit. Reduced motion keeps audio but makes the
urgent red clock static.
