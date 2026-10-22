# Reusable New-Game Prompt

Copy this prompt, replace every bracketed field, and attach your detailed rules or references.

```text
Create a new game module for The Star Games.

Game ID: [lowercase-kebab-case-id]
Title: [display title]
Description: [one or two sentences]
Visual style: [colors, typography, animation, references]
Shared UI: [existing GameLook presentation, matching browser classes, reference modules, and shared components to reuse; consult AGENTS.md's reference map]
Modes: [singleplayer, multiplayer, or both]
Players: [minimum] to [maximum, never above 16]

Rules and round flow:
[Explain setup, phases, timers, decisions, win/end conditions, ties, and replay.]

Host screen:
[Describe everything shown on the shared host display during each phase.]

Browser controller:
[Describe each controller screen, input, validation, feedback, and orientation behavior.]

Public and private information:
[Define host/phone roles and what each player may see in every phase, including previews, history, motion, and reconnect snapshots.]

Editable content and media:
[Define JSON schemas, catalog/category selection, values/difficulty, validation, reload/editor behavior, writable storage, and revision pinning. Put hidden banks/media behind private_paths; use shared media surfaces and phase-scoped controller capabilities for optional image/video clues.]

Settings and help:
[List host preferences, instant versus staged Apply behavior, persistence, pause/reset behavior, and reachable help/history.]

Scoring and lifetime points:
[Explain authoritative scoring, when award_points is called, bonuses, penalties, and limits.]

Animation, sound, and assets:
[List required transitions, effects, audio cues, supplied/missing assets, input locks during movement, pause/resume behavior, and static reduced-motion feedback.]

Errors and disconnects:
[Explain late joins, refresh/reconnect, player loss, malformed input, and host cancellation.]

Implementation constraints:
- Read docs/CREATING_A_GAME.md completely before editing.
- Copy Games/_Template to Games/[game-id].
- Keep all game-specific changes inside Games/[game-id] unless I explicitly authorize a launcher-contract change.
- Use schema version 1 and preserve the BaseGame, GameSessionContext, and StarGamesController interfaces.
- Reuse GameScreen/GameLook on the host and shared browser styles/SDK/components. Choose the layout and matching presentation for this game's input and privacy needs using AGENTS.md's references and the template examples.
- If a reusable UI hook is missing, add it compatibly in the shared layer, demonstrate it in Games/_Template, and document it in docs/CREATING_A_GAME.md.
- Keep the game completely offline and host-authoritative.
- Send host-filtered private views through BaseGame.send_state; keep secrets out of public snapshots, logs, previews, and effects.
- Never access profile save files directly; award through BaseGame.award_points.
- Persist only validated accepted host preferences through BaseGame.load_game_settings/save_game_settings. Restore controls without edit signals; keep live gameplay and secrets out of preferences.
- Make host and controller layouts responsive and support reduced motion where appropriate.
- Use the shared browser board fitter (#board and #replay), hand docks, social layouts, or asset layouts as appropriate. Keep controls inside artwork insets and actions reachable in scrolling dialogs. Preserve held controls during reflow and stable space for status/replay.
- Derive feedback from authoritative state, deduplicate animation/audio on sync, and clear effects on reset/exit. Modules own gameplay pause/resume; shared dialogs do not pause it automatically.
- Do not add hover tooltips; use accessible labels and visible explanations.
- Keep names/guesses/custom labels literal, use shared contrast helpers, pair color with text or symbols, and preserve keyboard access and browser touch targets of at least 44px.
- Omit simplified instructions below the title; use the shared centered UI and keep navigation reachable. Board games use GameScreen.center_board and board_height_limit, reserving space for replay.
- Set the background to an extensionless filename stem and use shared image/video playback, offline assets, silent loops, and reduced motion.
- Implement the specified win format. The existing board games count one win per decisive board and offer a single Play Again control; do not introduce first-to-two matches unless specified.
- Add focused tests or fixtures for rules and scoring.
- Run the catalog scan, standard import/core/network/UI checks, and relevant game/shared UI checks described in docs/CREATING_A_GAME.md and AGENTS.md.
- Launch and inspect host/controller views with small/large rosters, portrait/short landscape, reduced motion, reconnect, and clean return navigation. Verify new shared artwork through real LAN routes and raw-media exports. Report which runtime/platform checks actually ran.
```
