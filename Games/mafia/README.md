# Mafia

A host-authoritative social deduction game for **4–16 human browser players**.
The shared screen is a public moderator; each phone receives its owner's secret
role and eligible actions through `BaseGame.send_state`. Discussion takes place
aloud. There is no AI, extra host seat, separate server, or internet dependency.

## Roles and setup

The host selects optional roles under **Settings**, which shows the current
role counts without assigned identities. Godfather and Boxer default off and
unlock at seven players. Edits stay pending until **Apply**, which immediately
abandons the current game and redeals roles without scoring it. Completed wins
and history remain. With unchanged default settings, press **Start Game**.

| Players | Mafia team | Detective | Doctor | Other seats |
| --- | --- | --- | --- | --- |
| 4–6 | 1 | 1 | 1 | Civilians |
| 7–10 | 2 | 1 | 1 | Civilians; optional Boxer |
| 11–13 | 3 | 1 | 1 | Civilians; optional Boxer |
| 14–16 | 4 | 1 | 1 | Civilians; optional Boxer |

Godfather replaces **one** mafia, without increasing the team's size. Boxer
replaces one civilian. Every game randomly assigns the complete role pool.
Settings remain available during play and from the results popup. **Ejection
Reveal** defaults on. Every decisive vote plays a 6.5-second ejection before the next
night or result; turning Reveal off hides alignment while keeping the animation.
With Reveal on, it shows whether that player is Mafia or innocent. The alignment appears behind
the tumbling figure on a starfield, in white regardless of the player's color.
The flight lasts five seconds and the final verdict holds for another 1.5 seconds.
Reduced motion shows the full message with
the figure still. Skips and tied votes never trigger an ejection.

- **Mafia:** knows the mafia team and confirms one living town target each night.
- **Godfather:** acts and votes as mafia, but Detective sees them as civilian.
- **Detective:** investigates one other living player per night. The private
  report says mafia only for an ordinary Mafia; all other roles read civilian.
- **Doctor:** protects any living player, including themself, each night.
  Consecutive protection of the same player is allowed.
- **Boxer:** blocks one other living player's night action. It cancels a
  Detective investigation, Doctor protection, or **one mafioso's vote**.
- **Civilian:** chooses a suspicion at night, then discusses and votes during
  the day. Suspicions are public information, not elimination ballots.

## Night and day

Games begin at **Night 1**. Living night roles select a player icon and press
**Confirm**. Mafia, Godfather and Boxer may **Pass**; Detective and Doctor must
choose a target. The host rejects passes from these two roles. Confirmed actions cannot change. Mafia phones
show their team's identities and each confirmed vote under **Show Role**.
Phones start with roles hidden and auto-hide the private reveal after three
seconds, on disconnect, page hide, pause, and phase changes. Snapshot updates
do not extend that reveal. Dead players retain their private information while
spectating, but cannot use night powers or vote. After investigation, Detective's
button reads **Show Role/View Results**, with reports available during voting.
Each eliminated player can submit one **last will** suspicion during a night or day vote. It appears
at the following dawn. The one-use limit survives refresh and reconnect.

Living civilians use **Suspect Players** to select another living player each
night, or **No One**. Night waits for their choices alongside role actions.
Choices lock on Confirm and remain private until dawn. The host's wider left column
then shows the unique suspected players on an ivory parchment panel with a ruled
heading, or **No one is
suspected**. It never identifies authors, submission counts, roles, or last wills;
the history and public snapshots preserve the same anonymity. The latest list
stays visible through the following night. Phones keep only their own submission
controls and do not show this shared list. Last wills are
optional and never delay night resolution. New nights collect fresh civilian
choices; starting a new game resets all suspicions and wills.

When all living night roles and civilians have submitted, the host resolves the
night simultaneously:

1. Boxer cancels the selected **actor's** action.
2. The remaining mafia votes are counted. The target with the greatest count
   is attacked; a tie randomly selects one of the tied leading targets. Lower
   vote counts cannot win that selection. With no remaining votes, nobody is
   attacked.
3. An unblocked Doctor's protection prevents the selected attack. Detective
   reports are delivered privately; a blocked investigation returns no alignment.

For example, if two mafia vote for Alice and Boxer blocks one of them, Alice
still receives the other vote and is attacked. If the only voting mafia is
blocked, nobody is attacked. If mafia vote separately for Alice and Bob and
Boxer blocks Alice's voter, only Bob is attacked. Blocking a victim does not
protect them. An actor killed that same night still performs their night action.

The public dawn announcement identifies an eliminated player or says everyone
survived. Individual roles remain hidden until the game ends. Town voting opens
automatically at dawn, before the first ballot. Players discuss aloud while
voting is open. The host shows voting progress and scrolling ballots in the
wider left column, above the suspicion note. The narrower right column keeps
History permanently open and scrollable. Settings and **SCORES** remain
in the bottom utility row, with matching button dimensions. SCORES keeps its
short label when expanded. Narrow screens stack the public panel and history.
There is no separate voting popup or voting timer.
Every living player presses red **VOTE** to choose a suspect and confirms, or
uses green **Skip**. Once
all ballots arrive, a unique leading suspect is eliminated. A tie, including a
tie with Skip, or a leading Skip eliminates nobody. The next night starts
automatically unless a team has won. Day ballots are public; night choices are
private to their owner, with mafia votes additionally shared with fellow mafia.
The shared screen and phones keep every player in their figure row; an eliminated
figure becomes a tombstone with crossed-out names and an accessible OUT caption.
Finished role lists also cross out dead names, color Mafia/Godfather names red,
and place winning awards directly after the role, for example `Mafia +1 point`.
Leaderboard names adapt their brightness to the paper panel through the shared
contrast helper, including black and dark green identities. Avatar colors stay
the same as the selected player colors.
The public host and phone assembly uses larger rounded busts in a closely grouped,
centered roster. Shared neutral outlines and highlights keep dark player colors
visible against the scenery and picker buttons; the selected identity colors
remain unchanged. Phone names stay visible on small screens. Eliminated seats
retain their tombstones. The host's compact serif MAFIA heading and two-column
layout use shared responsive components. Phone **Instructions** describe only
the owner's current role, plus their voting or last-will eligibility.

Host and phone scenery changes together: nights use the illustrated noir town
square and white crescent moon; daytime uses the golden town square and yellow
circular sun. Shared paper panels and warm dark controls match the approved UI.
Separate module-owned sun/moon artwork rotates on opposite arcs: the sun sets
as the moon rises at night, and the moon sets as the sun rises at dawn. Transparent
day/night city artwork covers the planets as they pass behind the buildings;
it uses the same centered cover geometry as the shared background media.
Duplicate snapshots retain the orbit; refresh restores the correct settled sky.
Live scenery changes
crossfade for 0.9 seconds through the shared background player. Refresh restores
the current phase without replaying the fade, and reduced motion switches
immediately. Both backgrounds use extensionless stems and support image/video
replacement through the existing resolver.

## Winning, replay and connections

Town wins immediately when all Mafia and Godfather players are eliminated.
Mafia wins immediately when its living members equal or outnumber living town
members. Each completed game awards **one point and one win** to every member
of the winning team, including eliminated members; losing team members receive
one loss. The host uses the admitted profile IDs and existing `award_points`
and `report_result` APIs exactly once. Abandoning a game awards nothing.

The host alone can **Play Again**. Replay keeps options, session wins and
completed history, restores everyone and randomly redeals roles. Fresh and
replayed games start with a new revision, rejecting stale inputs. Leaving
clears the session and returns through normal launcher navigation.

Living-player disconnects pause all decisions while preserving roles, ballots
and investigations. Refresh/reconnect uses the launcher identity and requests
the same authoritative private snapshot. Eliminated spectators do not pause
survivors; everyone must reconnect before replay. Host navigation remains usable
during a pause, night, voting and results.

`host/rules.gd` owns role assignment, action eligibility, simultaneous resolution,
win detection and snapshot privacy. `host/main.gd` adapts the existing lifecycle,
shared `GameScreen` components, result dialog, profile APIs and LAN hooks.
Controllers use `StarGamesController`, the shared player picker, panels and
noir palette. Game CSS contains layout only. Original vector artwork is retained
inside this module alongside generated town art; `art/town-night` and
`art/town-day` are extensionless image/video stems using
the shared resolver. Reduced motion is handled by shared UI/media components;
ejection keeps its white alignment message visible while holding the figure still.

## Verification

From the repository root with Godot 4.7:

```text
godot --headless --path . --script res://tests/mafia.gd
godot --headless --path . --script res://tests/mafia_network.gd
node tests/mafia_controller.mjs
godot --path . --script res://tests/mafia_visual.gd
```

Rules/session tests cover every supported player count, role options, privacy,
collaboration, single/multiple blocked mafia votes, protection, investigation,
random ties, simultaneous actions, day ties/Skip, civilian choices and private
publication, one-use wills, staged Apply restarts, ejection locks, parity,
scoring and replay.
The network test uses actual launcher sockets, refresh tokens, profile APIs,
clean return navigation and sixteen connected phones. Browser fixtures check
portrait, landscape, tablet, desktop, small screens and reduced motion with
Chromium (`CHROME_BIN` or an executable argument overrides its Windows default).
Visual captures stay in ignored `.test_data` directories. Native macOS/Android
and physical Safari/Android phone checks require those devices.
