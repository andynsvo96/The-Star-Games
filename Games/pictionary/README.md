# Pictionary

An offline drawing and guessing game for 3–16 human browser players. The shared
launcher owns joining, identities, reconnection and return navigation. This
module uses `BaseGame`, `GameSessionContext`, `GameScreen` and
`StarGamesController`; the host owns all rules, timers, drawing and scoring.

## Play and scoring

Each player draws once per lap. The drawer has ten seconds to pick from up to
three private words; the host picks the first offered word if that expires.
The default drawing time is 60 seconds. Everyone else types guesses on their
phone while the shared host canvas displays the drawing and scores.

A fixed pool of 100 points per drawing turn is split among correct guessers when
the turn ends, ranked by the order the host accepts their correct answers.
Linear weights decrease from the number of correct guessers down to one: four
correct guessers receive 40, 30, 20 and 10 points. The host can adjust the pool
and choose steeper (squared) rank weights in Settings. Integer shares total the
exact pool, with rounding ties favoring earlier guessers and at least one point
for every correct guesser. The drawer has no separate bonus. Turns with no correct
guesses award zero. Orange near-misses, red incorrect guesses and absent guesses
earn nothing and do not take a rank. Case, spacing and punctuation are ignored;
curated aliases also count as correct. Successful guess times are seconds since
drawing began, excluding disconnect pauses and word-selection time; repeated
guesses never reset this clock. Incorrect or missing guesses receive the full
configured turn duration.
The drawing turn ends when all guessers succeed or time expires. Its answer
appears on the canvas for six seconds; the host may select Next Turn sooner.

After all drawing turns, the highest match score wins. Tied leaders each receive
one session win; a match with no points is a draw. Only the host has Play Again.
Replay rotates the first drawer and preserves completed session wins and internal
match history. Match scores reset. Profile points and results are recorded only
when a match completes, once per match; abandoning a match awards nothing.

## Screens and controls

The host uses the approved warm studio artwork, a larger square paper canvas
with a thin shared border, and ivory turn/result and score panels. The turn table
lists who has guessed correctly without showing the answer. Accepted incorrect
and near-miss guesses appear for four active seconds in speech bubbles beside
their players' scoreboard names, then expire; a correct guess clears its bubble.
Bubbles hug the name, size to their text, and use white with a light blue outline.
Long names and guesses wrap while scores remain aligned on the right.
Pauses hide the bubbles and freeze their lifetime, and reconnect restores any
unexpired bubble. It has Settings, Next Turn during reveals,
and Play Again at completion. There are no Help or History controls. The reveal
status is `Turn complete` with a stable timer; the full answer stays on the canvas.

Phones prioritize the canvas. The drawer receives private word choices and then
the selected word, Undo, Clear, seven ink colors (navy, blue, red, green,
yellow, brown and purple), and labelled Brush and Eraser buttons with circles.
Selecting an inactive tool activates its retained size; tapping the active tool
cycles Medium → Large → Small. Brush uses a solid dot and Eraser a hollow circle.
Each keeps its own size; returning to Brush restores the selected ink color.
Erasers use wider 18/36/60-unit strokes versus the brush's 4/9/18 units, with the
same normalized canvas on host and phones. Dots and accessible names change
together. Guessers have a guess field and
colored feedback. After a correct guess, the success message stays centered
just below the canvas without moving the board. Phones omit the bottom player
status strip, individual points
and guessed-player counts. A compact inline private word and smaller title leave
room for a substantially taller canvas. Short landscape screens put the same live drawing
tools beside the canvas. All controls work offline and have accessible names.

Green means an exact answer or accepted alias. Orange means a spelling near-miss:
one insertion, deletion, substitution or adjacent transposition for answers of
at least three normalized characters, or up to two edits for answers of eight
or more characters. Shorter answers require an exact match. Red means incorrect.
Only green guesses award points. Near-misses remain playable so the guesser can
correct the spelling after the normal cooldown.

Last guesses appear only when the whole match concludes, including through
refresh/reconnect. The host uses aligned Name, Last Guess and Time columns.
Each row describes that player's most recent completed guessing turn; the final
drawer retains their preceding guessing turn. A later turn without a submission
replaces an older guess with No guess. Correct guesses sort first, fastest to
slowest; unsuccessful rows follow with the full turn duration. Scores always sort
from most to fewest points, with stable roster order for ties. Phones show their
own final guess and duration in its result color. During drawing, phones keep
personal correct/close/incorrect feedback; the host turn table shows success
indications and the scoreboard alone displays temporary incorrect-guess text.

The final ten drawing seconds blink red with a quiet wooden pencil tick each
second. Reduced motion keeps a static red timer. New turns and correct guesses
use the original mallet cues. Incorrect guesses use one quiet 140 ms note on the
host speaker only. A 400 ms cooldown discards extra sound triggers without
queuing them, and other game cues take priority. Phones do not echo the note.
The studio cues for
time expiry and match completion remain. Pause, refresh, replay and exit cannot replay old
sound events; phones need a user gesture before audio can play.

## Host settings and word editor

Settings opens a full-screen shared modal. Close, Escape or a tap outside its
panel dismisses it. Options are staged until Apply:

- Turn length: 30–180 seconds, default 60.
- Drawing laps: 1–3, default 1.
- Points per turn: 15–10,000, default 100. The minimum supports a positive award
  for all fifteen possible guessers.
- Rank weights: Linear (default) or Steeper (squared weights).
- Category: Mixed or any saved category.
- Difficulty: Mixed, Easy, Medium or Hard.
- Hints: None, Word length, or Length + timed letters.

The adjacent word editor lets the host add, rename and remove categories, add
words with a difficulty, and remove words using ×. Save Words stays disabled
until there is a valid change. Keep at least one category and three words across
the bank. Category names must be unique; names and words are limited to 40
characters. Up to 24 categories and 2,000 words are supported. A category can be
empty, but Apply is unavailable if its selected difficulty has no words.

Apply and Save Words save independently. Each starts a fresh match without
awarding the abandoned one, preserving completed session wins/history. Settings
and the edited bank survive relaunch in `user://game_settings/pictionary.json` through
the shared settings API. Saving never modifies `words.json` or profile files.
Invalid saved categories fall back to the bundled bank of 120 original words.

## Authority, privacy and reconnects

Word choices and the active answer go only to the drawer's admitted connection.
Public snapshots omit guess feeds and completed guess results until the match
finishes. Temporary scoreboard bubbles contain only accepted non-correct guesses,
their quality, seat and remaining lifetime. Successful guesses never expose the
answer during drawing; answers appear on the canvas after each turn.
The host validates sender, phase, revision, turn, brush/ink indexes, finite
coordinates, point/chunk limits, stroke sequence and rate limits. Controllers
submit actions, never authoritative scores or profile identifiers.

A disconnect pauses the match clock and input. Refresh/reconnect restores the
same seat, word, drawing, remaining time and points from the host snapshot.
Stale strokes are discarded; undo/clear invalidate earlier drawing epochs.
Phone private cards hide while disconnected or when leaving the page. The
launcher and SDK continue to own sockets and navigation.

## Assets and verification

`game.json.background` uses the extensionless `art/studio` stem. The shared media
resolver supports an image or video with that same stem; images cover without
stretching, videos loop silently and reduced motion freezes video artwork.
The original approved mockup and generated source art are retained in
`asset/pictionary/`. [Artwork provenance and prompt specifications](art/GENERATION.md)
and [original sound sources](audio/SOURCES.md) describe the production assets.

From the repository root, use Godot 4.7 for the native tests:

```powershell
& 'C:/Users/Administrator/Desktop/Godot_v4.7-stable_win64.exe' --headless --editor --path . --quit
& 'C:/Users/Administrator/Desktop/Godot_v4.7-stable_win64.exe' --headless --path . --script res://tests/pictionary.gd
& 'C:/Users/Administrator/Desktop/Godot_v4.7-stable_win64.exe' --headless --path . --script res://tests/pictionary_network.gd
& 'C:/Users/Administrator/Desktop/Godot_v4.7-stable_win64.exe' --path . --script res://tests/pictionary_visual.gd
node tests/pictionary_controller.mjs
```

The rendered native test writes host previews to `.test_data/pictionary-visual/`;
Chromium fixtures write phone previews to `.test_data/pictionary-controller/`.
These generated fixtures and profiles remain ignored. Also run the project's
standard import, core, network and UI smoke commands before shipping.
