# The Star Games

A local party and solo game framework built with Godot 4.7. Host on Windows, macOS, or Android, and let up to 16 players join with browser controllers on the same Wi-Fi network.

This public repository contains the launcher, shared host UI, browser controller SDK, development tools, and [game template](Games/_Template). **Playable game modules and their artwork, audio, and other game-specific assets are not included.** Existing local modules stay on the development PC and are excluded from future commits.

## Features

- A shared host screen and phone or tablet controllers.
- Local play with offline browser controls and QR-code joining.
- Solo play and computer opponents in supported games.
- Saved profiles, scores, and host preferences.
- Responsive layouts, reduced motion, and customizable artwork and audio.

## Current local game catalog

The development installation currently has 14 menu entries covering the 17 games and variants below. This list describes that local installation; these modules are not distributed in this repository.

| Game | Description |
| --- | --- |
| Battleship | Place a secret fleet and sink your opponent's ships. |
| Checkers | Jump opposing pieces, crown kings, and control the board. |
| Chinese Checkers | Race ten marbles across a star with 2-6 human/computer seats. |
| COUP | Bluff, challenge and eliminate rival influence with 2-6 human phone players. |
| Chess | Classic chess with computer opponents and optional clocks. |
| Four in a Row | Drop discs and connect four before your opponent. |
| Jeopardy | Buzz from your phone, answer aloud or type, and play editable trivia boards. |
| Mafia | Use discussion, secret roles, and votes to uncover the Mafia. |
| Monopoly Classic | Buy, trade, and develop properties on the original US board. |
| Monopoly Deal | Bank, trade, and steal cards to complete three property sets. |
| Pictionary | Draw on your phone while the other players guess the word. |
| Poker: Texas Hold'em | No-Limit Texas Hold'em tournaments with friends or computers. |
| Poker: Omaha | Four-card Pot-Limit Omaha High tournaments. |
| Quoridor | Race across the board while placing walls to slow your rivals. |
| Spyfall | Ask questions and find the spy who doesn't know the location. |
| Tic Tac Toe | Get three in a row against a friend or computer. |
| UNO | Match cards and empty your hand in Classic, Flip, or No Mercy. |

Player limits and solo options vary by game. Checkers, Monopoly, and Poker each have a chooser for their two games or variants.

Game-specific menu icons and their source artwork also remain local.

## Run locally

1. Install [Godot 4.7](https://godotengine.org/download/archive/) and download or clone this repository.
2. Add your own game module under `Games/<game-id>/`, starting with `Games/_Template` and the [Creating a Game](docs/CREATING_A_GAME.md) guide. The template is hidden from game selection, so a fresh clone has no playable games.
3. Open `project.godot` in Godot and press **F5**. Windows and macOS users can also use `launch_windows.bat` or `launch_macos.command`.
4. For party play, open a lobby and connect each phone or tablet to the same Wi-Fi network.
5. Scan the lobby's QR code or open its local join URL in a browser.
6. Once everyone has joined, press **Play** in the lobby and choose an installed game.

Allow local-network access if your firewall prompts you. No controller app is required.

## Customization

Host Settings includes sound, reduced motion, and other preferences. On desktop, **Settings > Asset Editor** lets you replace artwork, backgrounds, and audio, with previous files saved in `Backups/`.

Every installed local game and collection chooser supports named cosmetic skins.
In **Asset Editor > Themes**, choose a game, duplicate its protected **Default**
skin (called **Classic** in Monopoly Classic), and replace artwork or sounds.
Save, then select **Use skin** to use it the next time that game opens. Default
keeps the game's current appearance; missing custom slots inherit it. Monopoly's
existing in-game skin selectors remain available. Skin choices are saved per game.

Install FFmpeg on the host for desktop media that needs conversion. Original media stays in `asset/`; converted files are cached in user data.

## Development

- [Creating a Game](docs/CREATING_A_GAME.md): module structure, shared UI, and controller APIs.
- [New Game Prompt](docs/NEW_GAME_PROMPT.md): a starting outline for new modules.
- [Contributor Instructions](AGENTS.md): coding conventions and verification requirements.
- [Automatic GitHub Sync](docs/GITHUB_SYNC.md): background publishing, status, and pause controls.
- `Games/_Template/` contains the public module template, `scripts/` shared host code, and `web/` shared browser assets. Other `Games/` folders and game-specific source media are ignored by Git.
- Public tests use shared framework code, the template, or synthetic fixtures. Module-dependent test suites stay local with the games; public CI runs without them.

Press **F8** on the host, or choose **Settings > Debug Lab**, to inspect loaded UI,
including hidden controls. Select an element and **Preview selected**; restore it
or close the lab to return its visibility. The inspector blocks host UI interaction
while open; connected controllers and the game continue running. Host previews can
save screenshots in `user://debug_lab/`.

**Settings > Debug** still opens the four installed desktop browsers. Each now
includes a Debug Lab toolbar: change the exact controller viewport, rotate it, or
open **Tools** for hidden-element inspection, named UI scenarios, recent state,
and input summaries. **Hold view** and all browser previews block gameplay input
from that browser while the host continues. **Return to live** restores the view
and requests current host state. History stays in memory, is limited to that
player's received state, and clears on page navigation. These are visual testing
tools, not a separate game or profile sandbox. Use a disposable session when
testing actual scoring, saves, or destructive game actions.

Existing hidden panels and dialogs work automatically. UI created only after a
trigger needs a registered scenario or a real gameplay trigger. The template
demonstrates both host and browser scenario hooks; see
[Debug Lab scenarios](docs/CREATING_A_GAME.md#debug-lab-scenarios). A checked
element records manual review, not proof that its rules or trigger passed.

With Godot available as `godot` on your PATH, run these checks from the repository root:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/network_smoke.gd
godot --headless --path . --script res://tests/ui_smoke.gd
godot --headless --path . --script res://tests/session_media.gd
godot --headless --path . --script res://tests/debug_lab.gd
```

Run `tests/debug_lab.gd` with rendering for host screenshots. With Godot and
Chromium installed, `node tests/debug_lab_controller.mjs` checks browser previews
through the real LAN HTTP server. Set `GODOT_BIN` and `CHROME_BIN` if needed.

Export presets are included for Windows, macOS, and Android. Install the matching Godot export templates to build them; keep generated builds in `builds/`.
