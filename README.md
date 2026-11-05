# The Star Games

A local party and solo game framework built with Godot 4.7. Host on Windows, macOS, or Android, and let up to 16 players join with browser controllers on the same Wi-Fi network.

This public repository contains the launcher, shared host UI, browser controller SDK, development tools, and [game template](Games/_Template). **Songs, music libraries, playable game modules, and their artwork, audio, and other game-specific assets are not included.** Music (including `asset/music/` and `asset/lobby_songs/`) and playable modules stay on the development PC and are excluded from future commits. A fresh clone needs your own locally supplied games and music.

## Features

- A shared host screen and phone or tablet controllers.
- Local play with offline browser controls and QR-code joining.
- Solo play and computer opponents in supported games.
- Saved profiles, scores, and host preferences.
- Responsive layouts, reduced motion, and customizable artwork and audio.
- A 16:9 host canvas and scalable portrait phone controllers with a 9:19.5 width-to-height ratio, including wide desktop browsers and internet-forwarded connections.
- A Debug menu with autoplay sessions and selectable local browser controllers for testing.

## Current local game catalog

The development installation currently has 16 menu entries covering the 19 games and variants below. This list describes that local installation; these modules are not distributed in this repository.

| Game | Description |
| --- | --- |
| Battleship | Place a secret fleet and sink your opponent's ships. |
| CATAN | Build and trade with 3–6 human/computer seats, including the current paired-turn extension. |
| Charades | Classic, Heads Up, Guess Who, and an in-person team Chain with editable word categories and shuffled prompts. |
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

The local Poker variants include optional cinematic community-card reveals,
all-in win odds, and individual player histories opened from their stat plaques
on the host or browser controller. Cinematic Reveals defaults on in Table Settings.

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

The title screen, lobby, and game selection share one shuffled playlist from
`asset/lobby_songs/`. Moving between these menus or opening and closing Host
Settings keeps the current song playing at its current position.

Entering a game from the menus starts a fresh shuffled song from `asset/music/`;
returning to game selection starts a fresh menu song. In-game settings, replays,
and collection variant changes keep the current game song. Songs do not repeat
until the shuffle is exhausted, and consecutive tracks differ when multiple songs
are available. A manual music pause remains in effect across navigation.

Every installed local game and collection chooser supports named cosmetic skins.
In **Asset Editor > Themes**, choose a game, duplicate its protected **Default**
skin (called **Classic** in Monopoly Classic), and replace artwork or sounds.
Save, then select **Use skin** to use it the next time that game opens. Default
keeps the game's current appearance; missing custom slots inherit it. Battleship's
top-right **Settings** button beside music contains a live **Skin** selector and
one **Special Powers** house rule, off by default. Skin changes apply immediately
on the host and connected phones, preserving the current battle. Monopoly's existing
in-game skin selectors remain available. Skin choices are saved per game.
The host can change Battleship's Special Powers rule at any time; changing it
during battle restarts fleet setup and preserves completed session wins/history.

The local Battleship installation also includes **Age of Sail** in that Skin
selector: a cinematic sailing-era fleet, stormy background, title, timber/brass
boards, period sounds and themed special-power effects. Its ship lengths,
targeting, costs, timing, scoring and private-state rules are identical to Default.
Like other playable modules and their media, this skin stays local and is not
bundled in the public repository.

**Galactic Warfare** is the third local Battleship skin: Mothership / Fighter
Squadron, Dreadnought / plasma Barrage, Battlecruiser / Twin Blasters, Starship /
Quantum Scanner, and Interceptor / Laser Cannon. The backdrop shows a space fleet
firing lasers. Ships warp into place, weapons use dry blaster sounds, and
destroyed ships have a reactor breakup cue. These cosmetic changes preserve the same rules,
costs, targets, timing and private state. It uses the same live Skin selector and
remains local with the playable module and its media.

The asset browser opens with **Launcher** and each detected game collapsed.
Expanding a category scans only that library in the background, then adds its
asset rows progressively. Older `asset/<game-id>/` source folders also appear
under their detected game. Reopening a loaded category reuses its inventory for
that editor session. **Search loaded assets** filters those loaded libraries;
**Expand All** explicitly loads every category. Each
asset has a **Skin** section, with existing source artwork shown as **Skins:
Default**. Protected game artwork opens its matching slot through **Edit skins
in Themes**. The **Themes** button is at the right of the editor header. Themes
separates game/skin controls, a blue asset browser with search, group and sorting
filters, and an asset preview. Skin validation runs in the background; asset
tiles and visible thumbnails load progressively so large libraries stay responsive.

Install FFmpeg on the host for desktop media that needs conversion. Original media stays in `asset/`; converted files are cached in user data.

## Development

- [Creating a Game](docs/CREATING_A_GAME.md): module structure, shared UI, and controller APIs.
- [New Game Prompt](docs/NEW_GAME_PROMPT.md): a starting outline for new modules.
- [Debug Tools](docs/DEBUG_AUTOPLAY.md): browser testing, autoplay controls, and the reusable module adapter.
- [Contributor Instructions](AGENTS.md): coding conventions and verification requirements.
- [Automatic GitHub Sync](docs/GITHUB_SYNC.md): background publishing, status, and pause controls.
- `Games/_Template/` contains the public module template, `scripts/` shared host code, and `web/` shared browser assets. Other `Games/` folders, all song libraries, and game-specific source media are ignored by Git.
- Public tests use shared framework code, the template, or synthetic fixtures. Module-dependent test suites stay local with the games; public CI runs without them.

With Godot available as `godot` on your PATH, run these checks from the repository root:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/network_smoke.gd
godot --headless --path . --script res://tests/ui_smoke.gd
godot --headless --path . --script res://tests/music_smoke.gd
godot --headless --path . --script res://tests/session_media.gd
godot --headless --path . --script res://tests/asset_editor_fixture.gd
```

Export presets are included for Windows, macOS, and Android. Install the matching Godot export templates to build them; keep generated builds in `builds/`.
