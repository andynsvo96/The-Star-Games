# Spyfall

Game ID: `spyfall`. Multiplayer only, 4–8 human browser players. The shared host
is a spectator; there are no computer seats or typed conversations.

Each round begins immediately, with a hidden private card on every phone. Exactly one
random spy gets no location; everyone else gets the same random place. Players
question one another aloud. The previous round's spy asks first; the first round
uses a random starter. The game does not track or require taps for spoken turns.

There are two independent clocks. **Round Timer** defaults to eight minutes and
starts with the round, counting down only during discussion. **Voting Timer**
defaults to one minute and starts on the first accepted ballot of each vote.
The early accuser's automatic Yes counts as that first ballot. Final voting waits
for its first ballot before counting down. Later ballots never reset the deadline.
Voting pauses the round clock; disconnects pause both clocks.
Host Settings accepts 0.1–1440 minutes for either clock,
including decimal minutes, staged until Apply. **Edit Locations** is the only
location control on the host: it opens a scrolling list with an × beside each
place, plus an input to add a new place. Edits remain pending until **Save**;
Save is grey and disabled when the list is unchanged. Saving locations applies
only the pool; Apply saves both timers and the voting preference. Either saves to
`user://spyfall/settings.json` and abandons the current round without scoring,
starting a fresh round immediately. Completed session points, wins and history stay.
Anonymous Voting is staged with both timers until Apply and defaults OFF. When OFF,
the host shows each voter under the suspect they chose. When ON, all public and
private snapshots omit voter identities and show only vote counts.
Both timers, voting preference and location pool survive
leaving the game and restarting the app. The bundled `locations.json` provides
30 default places. Pools need 2–200 unique nonempty names of at most 60 characters.

Each non-spy has one early accusation. The initiator automatically votes Yes;
the suspect cannot vote. One No resumes conversation. Unanimous agreement ends
the round: catch the spy to win as non-spies, or convict an innocent to give the
spy four points. An incomplete early vote that reaches its deadline is rejected,
consuming the initiator's accusation and resuming the same remaining round time.
Voting pauses the game clock and disables location guesses. During active
conversation the spy may submit one configured location: right earns four points;
wrong wins the round for non-spies.

Time expiry starts one final vote per player for another player. Everyone except
the suspect must name the same suspect for a conviction. Catching the spy wins;
an innocent conviction gives the spy four points; a split vote gives the spy two.
Final voting ends when everyone votes or its voting deadline expires. At expiry,
submitted ballots use the same unanimity rule: every player except the suspect
must have voted for that suspect. Missing or split required ballots let the spy escape.
Non-spies earn one point each when they win. The initiator of a successful early
accusation earns one additional point. Every completed round reports one win or
loss per player through BaseGame; each winning player's points persist through
the existing profile API. Abandoned rounds have no result.

Phones omit Locations and Players & Scores controls. The spy's teal Guess
Location button opens the full configured pool; the spy has no accusation button.
Non-spies have a red Accuse a Player button, and No votes are red. Accusations and
final votes open a grid of the other players' public lobby icons, colors and names.
Tap an icon to select it, then Confirm; no player is selected by default. Keyboard
arrows, Home/End, Enter and Space are supported. Confirm remains visible while
the icon list scrolls in short views. Phones omit
spoken instructions, How to Play and Play Again. The host omits
the status banner, How to Play and spoken instructions; its completed-round
panel is named History.
Show/Hide Card conceals private information after three seconds or when switching
away, disconnecting or starting another round. The spy's role text is red.
The shared display never contains the current spy or location until
completion, and the neutral background never varies with the selected location.
Time expiry replaces the central timer with a persistent host voting popup.
Votes appear live under each suspect, with names when voting is not anonymous.
Early accusations also show voting progress. Completion changes the same popup
to the winning team, point recipients, spy and location. Spy victories reveal the
spy's lobby avatar and name on a dark red screen. Civilian victories reveal every
civilian's avatar and name in blue/teal. Identity colors and poses are preserved.
Both result popups fit their contents, with Play Again directly below the awards;
short screens scroll the body while keeping replay visible. The host's Players
leaderboard forms a wrapping ribbon below the timer/history row. The timer sits
on the left and History is permanently visible inside an illustrated clipboard
on the right. Settings and Edit Locations stay in the bottom utility row. Narrow
host screens stack the two panels using the shared social layout.
The winning lineup replaces the ballot list. It stays until the host
presses Play Again, which restores the timer and refreshes assignments while
keeping totals. Controller replay/next requests are rejected by the host.
Every occurrence of the current spy's full name in the conclusion uses red text,
including point awards and the revealed lineup. Live voting never marks the spy publicly.
The phone result and the spy's completed connection name use the same red cue.
A new round clears the result and its red name markers.

Disconnects freeze the timer and all decisions, including outstanding votes.
Reconnecting restores the same seat, hidden card, phase and decision. Host Settings
remain usable during a paused conversation; voting/results use a persistent modal.
Inputs validate admitted sender, revision, phase,
value types, eligibility and bounds. Secrets are constructed per recipient via
`BaseGame.send_state`; the existing launcher and SDK own all connections.

The illustrated spy office, textured ivory paper and forest-teal controls use shared
GameScreen/GameLook's dossier palette, clipboard, semantic result surfaces and
team reveals, with matching browser styles. The compact SPYFALL logo uses local
distressed stencil lettering with a spy silhouette in `art/dossier-title.svg`;
original art is retained. Layered paper, ruled headings, larger dark timer type,
separated score entries and bold history headings match the briefing reference.
Phones use a dark timer card and a larger offline spy portrait on layered paper;
private reveal timing and eligible actions are unchanged.
No font download or installation is required.
Replay starts a fresh round clock and resets the voting clock to await a first vote.
Existing saved round durations remain in effect; older saves add a one-minute
voting timer. Both durations persist independently.
Background stem: `art/spy-office`, accepting images or video
without code changes. The final ten seconds show large red numbers, a finite
pulse and an original offline sound cue on both host and phones. Reduced motion
keeps the numbers static; pauses, page hiding and exit stop the effects. Duplicate
snapshots never replay a tick. Phone audio begins after a user gesture, as required
by browser audio policies. All host cues use Effects volume. Timer expiry rings a three-note bell; accepted
ballots play a short stamp; spy and non-spy victories play distinct minor and
major fanfares on host and phones. Host sound events contain only a sequence ID
and cue kind, preserving anonymous voting. Invalid inputs stay silent. Duplicate
snapshots and refresh/reconnect never replay old effects; pause, replay, page hide
and exit stop active effects. The local generator
is `audio/generate.py`; raw WAV audio is bundled for offline controllers.
Shared music and reduced-motion background behavior remain supported.

Validation:

```text
godot --headless --path . --script res://tests/spyfall.gd
godot --headless --path . --script res://tests/spyfall_network.gd
node tests/spyfall_controller.mjs
godot --path . --script res://tests/spyfall_visual.gd
```
