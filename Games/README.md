# Games Catalog

The launcher scans each direct child folder here for `game.json`. Folders beginning with `_` are ignored, so copy `_Template` to a lowercase game folder before customizing it.

The public repository includes only this catalog note and `_Template`. Playable modules are local additions excluded from Git, along with their game-specific source assets and tests. A fresh clone therefore has no playable games. See the root [README](../README.md#current-local-game-catalog) for the documented local catalog.

See [`docs/CREATING_A_GAME.md`](../docs/CREATING_A_GAME.md) for the complete module contract. Create your own module from the template before launching a game; only modules present when you build are bundled in an export.
