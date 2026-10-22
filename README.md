# The Star Games

A collection of party and solo games built with Godot 4.7. Host on Windows, macOS, or Android, and let up to 16 players join with browser controllers on the same Wi-Fi network.

## Features

- A shared host screen and phone or tablet controllers.
- Local play with offline browser controls and QR-code joining.
- Solo play and computer opponents in supported games.
- Saved profiles, scores, and host preferences.
- Responsive layouts, reduced motion, and customizable artwork and audio.

## Current games

| Game | Description |
| --- | --- |
| [Battleship](Games/battleship) | Place a secret fleet and sink your opponent's ships. |
| [Checkers](Games/checkers) | Jump opposing pieces, crown kings, and control the board. |
| [Chess](Games/chess) | Classic chess with computer opponents and optional clocks. |
| [Four in a Row](Games/four-in-a-row) | Drop discs and connect four before your opponent. |
| [Mafia](Games/mafia) | Use discussion, secret roles, and votes to uncover the Mafia. |
| [Monopoly Classic](Games/monopoly-classic) | Buy, trade, and develop properties on the original US board. |
| [Monopoly Deal](Games/monopoly-deal) | Bank, trade, and steal cards to complete three property sets. |
| [Pictionary](Games/pictionary) | Draw on your phone while the other players guess the word. |
| [Poker: Texas Hold'em](Games/poker-texas-holdem) | No-Limit Texas Hold'em tournaments with friends or computers. |
| [Poker: Omaha](Games/poker-omaha) | Four-card Pot-Limit Omaha High tournaments. |
| [Quoridor](Games/quoridor) | Race across the board while placing walls to slow your rivals. |
| [Spyfall](Games/spyfall) | Ask questions and find the spy who doesn't know the location. |
| [Tic Tac Toe](Games/tic-tac-toe) | Get three in a row against a friend or computer. |
| [UNO](Games/uno) | Match cards and empty your hand in Classic, Flip, or No Mercy. |

Player limits and solo options vary by game. Monopoly and Poker each have a chooser for their two variants.

## Run locally

1. Install [Godot 4.7](https://godotengine.org/download/archive/) and download or clone this repository.
2. Open `project.godot` in Godot and press **F5**. Windows and macOS users can also use `launch_windows.bat` or `launch_macos.command`.
3. For party play, open a lobby and connect each phone or tablet to the same Wi-Fi network.
4. Scan the lobby's QR code or open its local join URL in a browser.
5. Once everyone has joined, press **Play** in the lobby and choose a game.

Allow local-network access if your firewall prompts you. No controller app is required.

## Customization

Host Settings includes sound, reduced motion, and other preferences. On desktop, **Settings > Asset Editor** lets you replace artwork, backgrounds, and audio, with previous files saved in `Backups/`.

Install FFmpeg on the host for desktop media that needs conversion. Original media stays in `asset/`; converted files are cached in user data.

## Development

- [Creating a Game](docs/CREATING_A_GAME.md): module structure, shared UI, and controller APIs.
- [New Game Prompt](docs/NEW_GAME_PROMPT.md): a starting outline for new modules.
- [Contributor Instructions](AGENTS.md): coding conventions and verification requirements.
- `Games/` contains modules, `scripts/` shared host code, and `web/` shared browser assets.

With Godot available as `godot` on your PATH, run these checks from the repository root:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/network_smoke.gd
godot --headless --path . --script res://tests/ui_smoke.gd
```

Export presets are included for Windows, macOS, and Android. Install the matching Godot export templates to build them; keep generated builds in `builds/`.
