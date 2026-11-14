# Games Catalog

The launcher scans each direct child folder here for `game.json`, then any mode
subfolders declared by that manifest. Folders beginning with `_` are ignored, so
copy `_Template` to a lowercase game folder before customizing it.

Keep separately packaged modes inside their menu game's folder. For example,
`checkers/` contains `regular/`, `chinese-checkers/`, `draughts/`, and `alquerque/`;
`chess/` contains `classic/`, `chess960/`, `crazyhouse/`, `bughouse/`, and
`free-for-all/`; Monopoly uses `classic/` and `deal/`; Poker uses `texas-holdem/`
and `omaha/`. Shared family code/media belongs in the parent, outside removable
mode folders. Every mode keeps its own `game.json`, `host/`, and `controller/`.

Removing a mode folder disables its declared choice after restarting or using
**Scan for Games**. The parent manifest retains the mode's name, so its choice
stays visible and greyed out. Restoring the folder and scanning enables it again.
Saved settings, standings, and `/game/<id>/` controller URLs use stable IDs,
independently of folder names. See the collection example in the module guide.

The public repository includes only this catalog note and `_Template`. Playable modules are local additions excluded from Git, along with their game-specific source assets and tests. A fresh clone therefore has no playable games. See the root [README](../README.md#current-local-game-catalog) for the documented local catalog.

See [`docs/CREATING_A_GAME.md`](../docs/CREATING_A_GAME.md) for the complete module contract. Create your own module from the template before launching a game; only modules present when you build are bundled in an export.
