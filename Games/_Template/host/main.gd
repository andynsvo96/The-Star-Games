extends BaseGame

# game.json protects host/ with private_paths. Store host-only rule data and
# hidden answer banks here, and send only each player's permitted snapshot.

var screen: GameScreen
var phase_dialog: Dictionary
var example_choice: OptionButton
var example_toggle: Button
var example_length: SpinBox
var debug_sample_turn := 0


func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("Template Game")
	# Reusable composed cards use GameCard with semantic text and a separate
	# RuntimeAssets texture. Keep theme-slots.json and themes/default/theme.json:
	# the launcher pins the saved skin before creating this scene, and BaseGame
	# adds its public revision to snapshots. The SDK restores it on reconnect.
	# Declare canonical artwork/audio paths in theme-slots.json when adding media.
	# Card tables may select use_playful_style(background, "card-table") for
	# walnut controls/gold status, and GameLook.card_table_sheet(active) for zones.
	# GameCard's optional layout="deal" uses a 2:3 full face with a live name
	# overlay; kind/colors/value remain authoritative data, never read from art.
	# add_corner_details(["SETTINGS"]) supports a single centered disclosure.
	# Pass top_right=true as its sixth argument to dock Settings beside music.
	# Seventh argument modal_settings=true always centers Settings over a dim,
	# input-blocking backdrop. corners[0].get_meta("toggle_button").toggled
	# lets the module pause its own clocks, AI, movement and accepted input.
	# GameCardReader provides full-screen show_card(data, art, tint, commands)
	# and show_reference(front, back), with shared Back/Flip and action controls.
	# Use the same extensionless stem as game.json; images and videos interchange.
	screen.use_playful_style("res://Games/_Template/art/background")
	# Hidden reusable character-card example. Module artwork is cosmetic; names,
	# rules and accessibility remain semantic. Readers/grids accept the same data.
	var character_example := GameCard.new()
	character_example.card = {"layout": "character", "caption_style":"paper", "name": "Envoy", "detail": "An original character ability.", "foot": "A public reference"}
	character_example.custom_minimum_size = Vector2(112, 168)
	screen.content.add_child(character_example)
	character_example.hide()
	# "studio" selects shared ivory/walnut controls, serif type and teal actions.
	# Module artwork may frame any shared card without replacing its controls:
	# screen.add_card(layout.sidebar, "framed", RuntimeAssets.texture(panel_path)).
	# A status containing a clock can reserve a stable plaque across phases:
	# screen.reserve_status_plaque(520, 60).
	# A settings editor can use screen.add_phase_dialog(false, true) for a
	# full-screen modal with the same shared Close/navigation/scrolling layout.
	# Browser bodies combine game-royal game-studio. Color choices use the shared
	# game-ink-swatch class; identity footers use game-identity-strip.
	# Optional social-game palettes: "noir" (serif) or "dossier" (spy briefing).
	# Their cards inherit shared paper styling; the connection lifecycle is unchanged.
	# Optional shared navy/steel chrome: use_playful_style(background, "naval").
	# Optional midnight/cyan chrome: use_playful_style(background, "covert").
	# Board palettes: "royal" (walnut/ivory serif), "arcade" (ivory/navy),
	# or "admiral" (navy/brass). Shared controls retain focus and disabled states.
	# "garden" adds carved wood controls. Use GameLook.illustrated_control(button,
	# RuntimeAssets.texture("res://ui/playful/control-wall.svg")) for icon decisions.
	# GameLook.set_illustrated_control_disabled(button, unavailable) also greys icons.
	screen.add_wordmark(["YOUR", "GAME"], [GameLook.BLUE, GameLook.RED])
	# Third argument true gives a prominent responsive text wordmark.
	# Alternatively: screen.add_title_art(RuntimeAssets.texture("res://Games/your-game/art/title.svg"))
	# A larger responsive title opts into add_title_art(texture, 180.0, true).
	# A fourth true argument adds compact art and a content-sized turn plaque:
	# The plaque reserves a fixed two-line height to avoid movement on new text.
	# screen.add_title_art(texture, 56.0, false, true).
	# GameLook.fit_illustrated_control(button, compact) adapts icon decisions on resize.
	# An optional third true argument keeps smaller text/icons inside larger buttons:
	# GameLook.fit_illustrated_control(button, compact, true).
	screen.exit_requested.connect(return_to_lobby)
	# set_score_card_active(card, active, true) adds a static gold name highlight
	# to shared ledger/ornate cards; other calls retain their usual underline.
	# set_score_card_compact(card, true, true) trims decoration in dense host stacks.
	# Optional shared layout for games with session scores and history.
	var layout := screen.add_centered_layout()
	# Optional question/reference media uses shared contain-fit artwork and explicit
	# Play/Pause/Sound controls. It never autoplays. Pass native local paths:
	# media.show_media({"sources":[image_or_video], "poster":"", "alt":"Description"}).
	# Connect playback_changed to the game's clock/input pause policy; call
	# set_suspended(true) for settings/disconnects and clear() on exit.
	# BackgroundPreparer also prepares clip videos with audio on desktop hosts;
	# bundle .ogv plus optional MP4/WebM for Android hosts/browser controllers.
	var media_example := GameMediaView.new()
	layout.playfield.add_child(media_example)
	media_example.hide()
	# Host-only media under private_paths can be exposed phase by phase through
	# BaseGame.set_controller_media([native_path]), which returns path -> opaque
	# URL. Send only authorized URLs through send_state/broadcast_state. Replace
	# the set when clues change and clear it with set_controller_media([]) on exit.
	# Optional collection choices retain each child's stable ID and SDK route.
	# Read session.game_choices; the launcher validates game_selected requests.
	var choice_example := GameChoiceCard.new()
	choice_example.caption = "EXAMPLE"
	choice_example.reduced_motion = true
	choice_example.caption_on_top = true; choice_example.overlay_cards = true
	choice_example.board_data.append({"layout": "standard", "rank": "A", "suit": "spades", "name": "Ace of spades"})
	choice_example.custom_minimum_size = Vector2(240, 180)
	layout.playfield.add_child(choice_example); choice_example.hide()
	# A collection would emit game_selected.emit(validated_choice.id).
	var card_example := GameCard.new()
	# GameCard.artwork(path) retains SVG source and scales all artwork with display
	# DPI and card size. Raster theme replacements keep their original resolution.
	card_example.texture = GameCard.artwork("res://Games/_Template/thumbnail.svg")
	card_example.card = {"id": 1, "name": "EXAMPLE", "value": 1, "foot": "Semantic text"}
	card_example.custom_minimum_size = Vector2(112, 165)
	layout.playfield.add_child(card_example)
	card_example.hide()
	# An optional live face_schedule replaces a normalized artwork region with
	# active/muted semantic rows, after rotation. Only table cards need this;
	# enlarged readers can keep the original printed schedule unchanged.
	var schedule_example := GameCard.new(); layout.playfield.add_child(schedule_example); schedule_example.hide()
	schedule_example.card = {"layout":"deal", "kind":"property", "name":"EXAMPLE", "face_schedule":{"area":Rect2(.11,.29,.79,.63), "accent":"#2463eb", "rows":[{"label":"1", "count":1, "value":"$1", "active":false}, {"label":"2", "count":2, "value":"$2", "active":true}]}}
	# Full title deeds can instead supply JSON-safe live rows and a mortgage stamp.
	var deed_example := GameCard.new(); layout.playfield.add_child(deed_example); deed_example.hide()
	deed_example.card = {"layout":"deal", "kind":"property", "name":"EXAMPLE", "mortgaged":true, "deed_state":{"area":[25,122,190,147], "accent":"#2463eb", "badge":"1 HOUSE", "icon":"house", "rows":[{"label":"RENT", "value":"$2", "active":false},{"label":"With 1 House", "value":"$10", "active":true}]}}
	var card_panel_example := PanelContainer.new()
	card_panel_example.add_theme_stylebox_override("panel", GameLook.card_table_sheet())
	layout.playfield.add_child(card_panel_example); card_panel_example.hide()
	# Party tables select use_playful_style(background, "party-table"). They keep
	# the modern palette, circular profile avatars and draw_table_stats counters.
	# Their complete composition still uses screen.center_board(...).
	var party_example := PanelContainer.new()
	# Asset games can opt into token/cash plaques without changing other scores.
	var asset_example := screen.add_asset_score(layout.playfield, RuntimeAssets.texture("res://ui/playful/table-house.svg"), Color("2463eb"))
	asset_example.panel.name = "AssetScoreExample"; asset_example.panel.hide()
	asset_example.player.text = "Example player"; asset_example.score.text = GameLook.money_text(1500)
	asset_example.wealth.text = "Public wealth and collection summary"
	screen.fit_asset_score(asset_example, false, true)
	screen.set_score_card_active(asset_example, true)
	var asset_action := Button.new(); asset_action.text = "ROLL DICE"
	asset_action.icon = RuntimeAssets.texture("res://ui/playful/table-dice.svg")
	GameLook.asset_action(asset_action, "primary"); asset_example.content.add_child(asset_action)
	# Compact short-host plaques hide the token and summary; callers bound their
	# collection's height to the remaining panel space. No board fitting changes.
	party_example.add_theme_stylebox_override("panel", GameLook.party_player_sheet(Color("2463eb"), true))
	party_example.draw.connect(func() -> void: GameLook.draw_party_player(party_example, Rect2(Vector2.ZERO, party_example.size), Color("2463eb"), true))
	var party_face := Control.new()
	party_face.custom_minimum_size = Vector2(100, 150)
	party_example.add_child(party_face)
	party_face.draw.connect(func() -> void: GameLook.draw_party_card(party_face, RuntimeAssets.texture("res://ui/playful/table-cards.svg"), Rect2(Vector2.ZERO, party_face.size), Color.WHITE, 8, true))
	party_face.draw.connect(func() -> void:
		# The final flag crowns a confirmed winner above the avatar artwork.
		GameLook.draw_table_avatar(party_face, Rect2(0, 0, 32, 32), Color.WHITE, 0, true, true)
		GameLook.draw_party_hand_hint(party_face, Rect2(0, 48, 44, 90), 1, 3)
	)
	layout.playfield.add_child(party_example); party_example.hide()
	var rules_example := GameRulesPanel.new()
	layout.playfield.add_child(rules_example); rules_example.hide()
	rules_example.set_items([{"title":"Example rule", "detail":"A short public explanation", "icon":"res://ui/playful/table-cards.svg", "section":"House Rules"}])
	rules_example.fit(280, 240, false)
	# Player-target decisions can use this floating focus without footer space.
	var player_focus_example := GamePlayerFocus.new()
	add_child(player_focus_example)
	player_focus_example.present([], [], [], "Choose a player.", [], true)
	# Context-only actions float without a scrim or a footer. Validate action IDs.
	player_focus_example.present_context("Special actions", [{"id":"example", "label":"EXAMPLE"}], [], true)
	player_focus_example.hide()
	# Inside a phase dialog, fit(width, INF, true) lets the dialog own scrolling.
	var party_call := Button.new()
	party_call.text = "CALL"
	GameLook.party_action(party_call, "call")
	party_example.add_child(party_call)
	var party_settings := Button.new()
	party_settings.icon = RuntimeAssets.texture("res://ui/playful/table-settings.svg")
	party_settings.accessibility_name = "Settings"
	party_example.add_child(party_settings)
	# add_corner_details(..., top_right=true, modal_settings=true, icon_only=true)
	# uses this shared gear while preserving the settings dialog and keyboard flow.
	# Other party_action kinds are "play" (blue) and "sort" (purple). Use the
	# shared draw_turn_glow for an eligible call, with a fixed reduced-motion pulse.
	var party_draw := Button.new()
	party_draw.text = "DRAW"
	party_draw.icon = RuntimeAssets.texture("res://ui/playful/table-cards.svg")
	party_draw.expand_icon = true
	party_draw.add_theme_constant_override("icon_max_width", 22)
	GameLook.party_action(party_draw)
	party_example.add_child(party_draw)
	# Refit after sizing so the icon and text stay together in the button center.
	party_draw.resized.connect(func() -> void: GameLook.center_button_contents(party_draw))
	# Modern tables opt into use_playful_style(background, "modern-table") and
	# use_table_header(). Reuse these shared surfaces/inspectors; keep rules local.
	# Table headers center status against the viewport and reserve both control edges.
	# A public turn strip can replace only the status area of a table header:
	# screen.set_table_header_content(turn_example); update its roster/turn on render.
	var turn_example := GameTurnStrip.new(); turn_example.tracked = true; layout.playfield.add_child(turn_example); turn_example.hide()
	# tracked opts into neutral names with a gold current-step dot/line, like Poker.
	turn_example.set_players([{"display_name":"Example player", "color":"#2463eb"}, {"display_name":"Eliminated player", "color":"#e53935", "alive":false}], 0)
	turn_example.set_actions(["Played a public card",""])
	# alive:false keeps the seat but mutes its name/dot. Dim canvas seat artwork
	# separately, retaining a readable OUT label and useful controls.
	var eliminated_example := Control.new(); layout.playfield.add_child(eliminated_example); eliminated_example.hide()
	eliminated_example.draw.connect(func() -> void: GameLook.draw_table_eliminated(eliminated_example, Rect2(0, 0, 160, 100)))
	# Alternatively, keep literal names below framed piece portraits (not tracked).
	var portrait_example := GameTurnStrip.new(); portrait_example.portraits = [RuntimeAssets.texture("res://ui/playful/table-house.svg")]
	layout.playfield.add_child(portrait_example); portrait_example.hide()
	portrait_example.set_players([{"display_name":"Example player", "color":"#2463eb"}], 0)
	# GameActionRow retains one line of buttons without changing the board's width.
	# A seventh true center_board argument gives an auxiliary toolbar viewport width
	# while keeping its replay/footer height reserved by the shared board fitter.
	var action_row_example := GameActionRow.new(); layout.playfield.add_child(action_row_example); action_row_example.hide()
	var action_example := Button.new(); action_example.text = "EXAMPLE"; GameLook.action(action_example)
	# fit_icons=true reserves shared button icons as well as their full labels.
	action_row_example.fit_icons = true
	action_example.icon = RuntimeAssets.texture("res://ui/playful/table-cards.svg"); action_example.expand_icon = true; action_example.add_theme_constant_override("icon_max_width", 22)
	action_row_example.add_child(action_example)
	# Canvas counters use GameLook.draw_table_stats(canvas, point, width,
	# [{"icon":"cash", "value":"$5"}, {"icon":"cards", "value":7},
	# {"icon":"house", "value":"1/3"}]); the browser uses the same offline SVGs.
	# add_phase_dialog(true, false, true) fits compact decisions to their contents.
	var inspector_example := GameTableInspector.new()
	inspector_example.theme = GameLook.make_theme("modern-table")
	layout.playfield.add_child(inspector_example); inspector_example.hide()
	inspector_example.set_content("Public cards", "Read-only inspection", [], [["Count", "0"]], "example")
	# Compact inspectable public rows avoid widening a dense board's sidebars.
	# add_centered_layout's fifth argument optionally sets a smaller sidebar floor.
	var player_row_example := GamePlayerRow.new(); layout.left_sidebar.add_child(player_row_example); player_row_example.hide()
	# Optional compact section and icon-only private inventory. Only pass values
	# this viewer may see; connect pressed to the game's explicit detail view.
	var inventory_section := GameSection.new(); inventory_section.caption = "Resources"; inventory_section.hide(); screen.content.add_child(inventory_section)
	# Public collection headers may include the same identity avatar as the table.
	inventory_section.set_identity({"display_name":"Example player", "color":"#2463eb", "pose":0})
	var rent_summary := GameRentSummary.new(); inventory_section.content.add_child(rent_summary)
	rent_summary.set_rent("Example set", 2, 7, ["house", "hotel"])
	var inventory_example := GameResourceHand.new(); inventory_section.content.add_child(inventory_example)
	var inventory_flip := Button.new(); inventory_flip.icon = RuntimeAssets.texture("res://ui/playful/control-rotate.svg"); inventory_flip.toggle_mode = true; inventory_flip.accessibility_name = "Show development cards"; inventory_section.set_header_action(inventory_flip)
	# A card-face quickview shares all five resource slots and badge anchors.
	# Connect pressed to the full private inventory UI, including when empty.
	var inventory_cards := GameResourceHand.new(); inventory_cards.inspect_caption = "Inspect development cards"; inventory_section.content.add_child(inventory_cards)
	var empty_inventory: Array = []
	for index in 5: empty_inventory.append({"card":{},"empty":true,"label":"Empty card slot","amount":0})
	inventory_cards.set_items(empty_inventory); inventory_cards.hide()
	inventory_flip.toggled.connect(func(show_cards: bool) -> void:
		inventory_section.heading.text = "Development" if show_cards else "Resources"
		inventory_flip.accessibility_name = "Show resources" if show_cards else "Show development cards"
		inventory_example.visible = not show_cards; inventory_cards.visible = show_cards
	)
	var compact_cost_example := GameCostRow.new(); compact_cost_example.dark = true; compact_cost_example.icon_only = true; compact_cost_example.compact = true; inventory_section.content.add_child(compact_cost_example)
	compact_cost_example.set_items([{"texture":RuntimeAssets.texture("res://ui/playful/stat-resources.svg"),"label":"Example material","owned":1,"required":1,"available":true}])
	inventory_section.center_heading = true
	inventory_section.set_summary_metric(RuntimeAssets.texture("res://ui/playful/stat-victory.svg"),10,"Points to win: 10")
	var exchange_example := GameExchangeButton.new(); exchange_example.confirmation_text = "CONFIRM"; inventory_section.content.add_child(exchange_example)
	exchange_example.set_exchanges([{"give_texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"take_texture":RuntimeAssets.texture("res://ui/playful/stat-resources.svg"),"owned":3,"rate":3,"label":"Have 3 cards. Exchange 3 for 1 resource."}])
	# set_inline_header(true) puts a section's header beside its contents on short
	# landscape views; compact=true on the inventory retains the same input target.
	var example_resources: Array = []
	for index in 5: example_resources.append({"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"label":"Example resource %d" % index,"amount":3,"color":Color("27ad68")})
	inventory_example.set_items(example_resources)
	player_row_example.leader = "silver" # Explicit tied-lead feedback; not turn state.
	player_row_example.set_player({"display_name":"Example player","color":"#2463eb","pose":0},[{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"value":7,"label":"Public card count"}],true)
	player_row_example.pressed.connect(func() -> void: inspector_example.show())
	# detailed=true shows six labelled counters in a larger public roster row.
	# compact still reduces its height; show_labels labels the ordinary small row.
	player_row_example.detailed = true; player_row_example.show_labels = true; player_row_example._layout()
	# grid_counters omits captions and gives an optional fourth set_player
	# argument its own top-right icon/value slot, independent of the name.
	player_row_example.grid_counters = true
	# Optional identity-colored turn outline; highlighted metrics mark awards.
	player_row_example.active_identity_outline = true
	# dark opts into the shared navy asset surface; identity colors stay intact.
	player_row_example.dark = true
	player_row_example.set_player({"display_name":"Example player","color":"#2463eb","pose":0},[{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"value":7,"label":"Public card count"}],true,{"texture":RuntimeAssets.scalable_texture("res://ui/playful/stat-victory.svg"),"value":2,"label":"Public points"})
	var stat_grid_example := GameStatGrid.new(); layout.playfield.add_child(stat_grid_example); stat_grid_example.hide()
	stat_grid_example.maximum_columns = 4
	stat_grid_example.dark = true
	stat_grid_example.set_metrics([{"texture":RuntimeAssets.scalable_texture("res://ui/playful/stat-victory.svg"),"value":2,"label":"Public points","highlighted":true}])
	var cost_example := GameCostRow.new(); layout.playfield.add_child(cost_example); cost_example.hide()
	cost_example.set_items([{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"label":"One required card","available":false}])
	# Optional owned/required values group materials into counted progress cards.
	var counted_cost := GameCostRow.new(); counted_cost.dark = true; counted_cost.highlight_counts = true; counted_cost.icon_only = true; layout.playfield.add_child(counted_cost); counted_cost.hide()
	counted_cost.set_items([{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"label":"Example material","owned":2,"required":3,"available":false}])
	# A green check confirmation inherits its theme through GameLook.confirm_control.
	var badge_example := GameButtonBadge.new(); player_row_example.add_child(badge_example); badge_example.count = 2
	# A camera transforms presentation only. Route its tapped signal to the game's
	# ordinary preview handler; never turn a drag release into a game command.
	var camera_example := GameBoardCamera.new()
	var camera_view := Control.new(); camera_view.custom_minimum_size = Vector2(180,180); camera_view.clip_contents = true; camera_view.focus_mode = Control.FOCUS_ALL
	layout.playfield.add_child(camera_view); camera_view.hide()
	var camera_art := TextureRect.new(); camera_art.texture = RuntimeAssets.texture("res://ui/playful/table-house.svg"); camera_art.size = Vector2(180,180); camera_art.mouse_filter = Control.MOUSE_FILTER_IGNORE; camera_view.add_child(camera_art)
	camera_view.resized.connect(func() -> void: camera_example.viewport_size = camera_view.size)
	camera_view.gui_input.connect(func(event: InputEvent) -> void: camera_example.handle_input(event,camera_view.get_local_mouse_position()))
	camera_example.changed.connect(func() -> void: camera_art.scale = Vector2.ONE*camera_example.zoom; camera_art.position = camera_example.project(Vector2.ZERO))
	camera_view.tree_exiting.connect(camera_example.cancel)
	# Optional full-screen map: keep a fitted anchor in the layout and paint the
	# camera behind shared chrome. Route _input through board_canvas_input_regions
	# before starting gestures so UI buttons retain priority.
	var backdrop_example := Control.new(); backdrop_example.hide()
	var backdrop_camera := GameBoardCamera.new()
	var backdrop_art := TextureRect.new(); backdrop_art.texture = camera_art.texture; backdrop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE; backdrop_example.add_child(backdrop_art)
	var refit_backdrop := func() -> void:
		if not is_instance_valid(backdrop_example) or not is_instance_valid(camera_view): return
		var fitted := screen.board_canvas_fit_rect(backdrop_example)
		backdrop_camera.set_frame(backdrop_example.size,fitted)
		backdrop_art.size = fitted.size; backdrop_art.scale = Vector2.ONE*backdrop_camera.zoom; backdrop_art.position = backdrop_camera.project(fitted.position)
	screen.mount_board_canvas(backdrop_example,camera_view,refit_backdrop)
	backdrop_example.resized.connect(refit_backdrop); backdrop_camera.changed.connect(refit_backdrop)
	backdrop_example.tree_exiting.connect(backdrop_camera.cancel)

	var reader_example := GameCardReader.new(); reader_example.theme = screen.theme; add_child(reader_example)
	# After show_card, set_subtitle("Owned by …") adds explicit public ownership.
	reader_example.set_preview([{"label":"Example action", "summary":"Public consequences", "players":[], "items":[]}])
	# Optional player choices expose every target and a bounded, hold-to-browse bank.
	reader_example.set_preview([{"players":[{"display_name":"Example player", "bank_total":1}], "label":"Example player", "items":[{"card":card_example.card, "texture":card_example.texture}]}], 0, "players")
	# Card choices show all public candidates per owner; matching keys preserve
	# the other side of a multi-card exchange. Selection never submits a command.
	reader_example.set_preview([{"label":"Take card", "summary":"Take a public card", "players":[], "groups":[{"key":"take", "value":1, "owner":1, "label":"Take", "player":{"display_name":"Example player"}, "items":[{"card":card_example.card, "texture":card_example.texture}]}]}], 0, "cards")
	# Reference readers place an accessible flip icon on the card's top right;
	# clicking outside the focused content closes them. Native decision sheets
	# can opt in with add_phase_dialog(true, false, true, true).
	# Independent decision flights can use GameCardMotion.append(items, elapsed).
	# GameLook.draw_table_building(canvas, rect, "house" or "hotel") draws badges.
	# The grid can show real faces, selectable payment tiles and missing slots.
	var grid_example := GameCardGrid.new(); layout.playfield.add_child(grid_example); grid_example.hide()
	grid_example.left_aligned = true
	# Optional maximum_height fits every public face within a bounded stats panel.
	grid_example.maximum_height = 180
	grid_example.fixed_columns = 3; grid_example.set_items([{"card":card_example.card, "texture":card_example.texture}, {"placeholder":true}, {"placeholder":true}])
	# Complete illustrated faces opt into layout="art" to avoid live money/text overlays.
	var art_grid_example := GameCardGrid.new(); layout.playfield.add_child(art_grid_example); art_grid_example.hide()
	art_grid_example.set_items([{"card":{"id":1,"layout":"art","display_name":"Artwork card"},"texture":card_example.texture}])
	# Symbol cards keep live instructions below contained artwork. art_region is
	# an optional normalized source crop; art_size supplies its browser design size.
	var symbol_example := GameCard.new(); symbol_example.card = {"id":"symbol","layout":"symbol","name":"Choose","detail":"Pick any two tokens.","foot":"Public reference","accent":"#397c91"}; symbol_example.texture = RuntimeAssets.scalable_texture("res://ui/playful/stat-resources.svg")
	layout.playfield.add_child(symbol_example); symbol_example.custom_minimum_size = Vector2(144,216); symbol_example.hide()
	# A public activity feed takes plain newest-first rows and stays in a supplied
	# rectangle. Initial/reconnected entries do not replay entrance motion.
	var activity_example := GameActivityLog.new(); activity_example.paper = true; layout.playfield.add_child(activity_example); activity_example.hide()
	# When an outer panel supplies the heading, hide the duplicate inner caption.
	activity_example.show_heading = false; activity_example.heading.hide(); activity_example.bold_latest = true
	activity_example.entry_font_size = 17; activity_example.maximum_entries = 5; activity_example.separators = true
	activity_example.set_entries([{"id":1, "text":"Example player banked a card","parts":[{"text":"Example player","color":GameLook.readable_text_color(Color("2463eb"),GameLook.CREAM)},{"text":" banked "},{"texture":RuntimeAssets.texture("res://ui/playful/table-cards.svg"),"width":20,"height":26}]}], true)
	# Set expandable=true before adding a compact log; connect expand_requested to
	# an enlarged phase dialog. show_reference(front,back,true) fits without scroll.
	var sectioned_activity := GameActivityLog.new(); sectioned_activity.sectioned = true; sectioned_activity.expandable = true; sectioned_activity.maximum_entries = 6; sectioned_activity.entry_font_size = 14; sectioned_activity.dense = true
	layout.playfield.add_child(sectioned_activity); sectioned_activity.heading.text = "Recent Activity"; sectioned_activity.hide()
	# sectioned=true supplies a separate compact sans-serif header and a 44px
	# Show All button. Both the panel and the button emit expand_requested.
	# GameLook.draw_table_winner(canvas, rect, elapsed, reduced) supplies a gold
	# WINNER label; keep its animation clock paused with the owning game.
	var winner_example := Control.new(); layout.playfield.add_child(winner_example); winner_example.hide()
	winner_example.draw.connect(func() -> void: GameLook.draw_table_winner(winner_example, Rect2(0, 0, 84, 24), 0, true))
	# Reader rotation restores statically by default; pass animate=true as the
	# sixth set_rotation_options argument only for an explicit Rotate press.
	# Optional public card effects share the host's motion timeline and pause state.
	var effect_example := GameCardEffect.new(); add_child(effect_example)
	effect_example.update({"revision":0, "effects":[]}, false, false)
	# Public cash changes use the same host clock. Resolve each seat's live balance
	# rectangle; an empty rectangle hides targets absent from this view.
	var money_example := GameMoneyEffect.new(); add_child(money_example)
	# Optional coin/token formatting; omit these two assignments for dollar cash.
	money_example.amount_prefix = ""; money_example.icon_texture = RuntimeAssets.texture("res://ui/playful/table-cash.svg")
	# Plain signed numbers rise above gains and fall below losses, without flights.
	money_example.amount_badge = false; money_example.show_transfers = false
	# change_placement="right" anchors signed feedback beside each live counter.
	money_example.resolve_rect = func(_seat: int) -> Rect2: return Rect2()
	# Resolve the live number label's font size when feedback must match it.
	money_example.resolve_font_size = func(_seat: int) -> int: return screen.get_theme_font_size("font_size","Label")
	money_example.resolve_font = func(_seat: int) -> Font: return screen.get_theme_font("font","Label")
	money_example.update({"revision":0, "money":[], "active":false}, false, false)
	var modal_example := screen.add_corner_details(["SETTINGS"], Callable(), true, false, false, true, true)
	screen.add_sidebar_text(modal_example[0], "Module-owned settings")
	# Opt in deliberately; keep the demonstration layer hidden in the template.
	modal_example[0].get_meta("toggle_button").get_parent().hide()
	# A card tap can call reader_example.show_card immediately; put the legal
	# Play/Bank choices in its commands, leaving navigation on the table.
	# Reversible cards: set_rotation_options(true, side, caption, validated_callback,
	# session.reduced_motion). Rotation stays on the inner card, never its container.
	var drag_example := GameDragScroll.new()
	card_example.set_meta("drag_scroll", drag_example)
	# Begin on pointer-down, move scroll by move(point), select only if end() is true.
	var motion_example := GameCardMotion.new(); motion_example.begin([])
	card_example.set_meta("card_motion", motion_example)
	# Supply from/to zones and card data. view(viewer, elapsed, active) redacts hidden
	# pickup faces; GameCardMotion.travel maps live rectangles without moving layout.
	# Optional flight hold=.22 keeps a face at its source, included in duration.
	# easing="smooth" uses smoothstep; pass it to travel as the fourth argument.
	# GameThemePreview.configure(ThemePacks.new(id), draft, phone, reduced_motion)
	# previews cosmetic slots on sample Table/Phone compositions without pinning.
	# add_centered_layout(true, true) vertically centers compact side score cards.
	# Its third argument 0 uses the available width for larger side panels; a
	# fourth argument supplies a smaller module board minimum (default 316px).
	# Use screen.board_width_limit() together with board_height_limit() to fit it.
	# Social games can use this shared pair instead of the board's three columns.
	# Its permanently open history wraps below the primary area on narrow hosts.
	var social_example := screen.add_social_layout(0.7)
	var social_public := screen.add_card(social_example.primary, "stacked")
	screen.add_section_heading(social_public, "PUBLIC STATE")
	# A sixth true argument selects closely grouped busts with neutral contrast rims.
	var assembly_example := screen.add_team_reveal(social_public)
	screen.set_team_reveal(assembly_example, [{"display_name": "PLAYER", "color": "#202020", "alive": true}], "", true, true, true)
	var social_history := screen.add_history_log(screen.add_card(social_example.history, "clipboard"))
	screen.set_history_text(social_history, "No completed rounds yet.")
	# set_history_entries(log, [{"heading": "Round 1: Team wins", "detail": "Public result"}])
	# add_details(parent, "SCORES", "", false) hides the +/- indicator; the returned
	# body exposes its toggle_button metadata for shared equal_control_sizes.
	social_example.root.hide()
	# Populate social_example.primary; put existing utility controls in its footer.
	# Persistent shared paper notes stay in their chosen column without disclosure.
	var note := screen.add_sticky_note(layout.playfield, "NOTES")
	note.text.text = "Plain public notes go here."
	note.panel.hide()
	# Optional phase scenery uses the same media resolver/player:
	# screen.background_media.transition_to("res://Games/your-game/art/day", true).
	# Reduced motion changes scenery immediately; shutdown cancels the fade.
	# "wood" adds an iron-chain slab; "scroll" retains the parchment variant.
	var example_score := screen.add_score_card(layout.sidebar, null, GameLook.RED, "ledger")
	# "ledger" adds a framed ivory sheet with safe 24px content insets;
	# returned name/score/content/underline properties keep the same contract.
	example_score.player.text = "PLAYER"
	# "ornate" adds a carved parchment card with laurel wins. Additional counters:
	# screen.add_score_stat(card, RuntimeAssets.texture("res://ui/playful/stat-walls.svg"), "10 WALLS").
	var ornate_example := screen.add_score_card(layout.sidebar, null, GameLook.RED, "ornate")
	ornate_example.player.text = "PLAYER"
	screen.add_score_stat(ornate_example, RuntimeAssets.texture("res://ui/playful/stat-walls.svg"), "10 WALLS")
	# Optional compact multi-seat stats, applied after adding the counters.
	screen.set_score_card_compact(ornate_example, true, true)
	screen.set_score_card_active(ornate_example, true, true)
	var roomy_example := Button.new()
	roomy_example.text = "PLACE"
	ornate_example.content.add_child(roomy_example)
	GameLook.illustrated_control(roomy_example, RuntimeAssets.texture("res://ui/playful/control-wall.svg"), true, true, true)
	roomy_example.hide()
	ornate_example.panel.hide()
	# A module can pass its own frame texture while retaining shared card controls.
	var framed_example := screen.add_card(layout.sidebar, "framed", RuntimeAssets.texture("res://ui/playful/score-ledger.svg"))
	screen.add_section_heading(framed_example, "ARTWORK PANEL")
	framed_example.get_parent_control().hide()
	var drawing_example := PanelContainer.new()
	layout.sidebar.add_child(drawing_example)
	drawing_example.add_theme_stylebox_override("panel", GameLook.drawing_sheet())
	var guess_example := screen.add_sidebar_text(drawing_example, "Close spelling")
	guess_example.add_theme_color_override("font_color", GameLook.guess_color("close"))
	drawing_example.hide()
	# Optional live speech beside a scoreboard name; expiry belongs to the game.
	var bubble_example := screen.add_speech_bubble(layout.sidebar)
	screen.set_speech_bubble(bubble_example, "A literal guess", "wrong")
	bubble_example.panel.hide()
	screen.set_score_card_identity(example_score, GameLook.RED)
	screen.set_score_card_active(example_score, true)
	# Circular board pieces can overlay this shared static, input-transparent ring.
	# Show only while selected and playable; hide during pause, movement or results.
	var ring_example := GameSelectionRing.new()
	add_child(ring_example)
	ring_example.size = Vector2(48, 48)
	ring_example.hide()
	screen.add_sidebar_text(layout.sidebar, "SESSION SCOREBOARD")
	# Use plain totals when illustrated score cards do not suit the playfield.
	var plain_score := screen.add_session_score(layout.sidebar)
	plain_score.player.text = "PLAYER"
	# This shared variant hugs the name and keeps the score aligned right.
	var score_speech := screen.add_score_speech_bubble(plain_score)
	screen.set_speech_bubble(score_speech, "A literal guess", "wrong")
	score_speech.panel.hide()
	# Preserve identity hues while adapting name text to the current panel color.
	plain_score.player.add_theme_color_override("font_color", GameLook.readable_text_color(Color("202020"), screen.get_theme_color("panel", "GamePalette")))
	screen.add_history_log(screen.add_details(layout.left_sidebar, "HISTORY", "scroll")).text = "No completed rounds yet."
	# Add game-specific controls to layout.playfield.
	# Board games call screen.center_board(board_frame, replay_button) once built.
	# An optional third argument places setup controls in that reserved slot:
	# screen.center_board(board_frame, replay_button, deployment_controls).
	# Optional fourth argument sets a shared vertical focus (default 0.5):
	# screen.center_board(board_frame, replay_button, null, 0.42).
	# A fifth true argument reserves auxiliary controls even while hidden; give a
	# multi-row decision group a stable custom_minimum_size.y to prevent board jumps.
	# Card tables can center the heading with their complete public/private field:
	# screen.center_board(table, replay_button, null, 0.5, false, true).
	# Keep sizing from screen.board_height_limit(); replay space stays reserved.
	# Optional adjacent options/history with a separate reserved replay row:
	# var panels := screen.add_board_details(["SETTINGS", "SESSION & HISTORY"])
	# Add selectors to panels[0] and plain scores/history to panels[1].
	# The shared helper centers these rows independently of wider action controls.
	# Or place independent disclosures in the host's bottom corners:
	# var corners := screen.add_corner_details(["SETTINGS", "SESSION & HISTORY"])
	# Garden utility buttons can use the same roomy sizing with the fifth argument:
	# screen.add_corner_details(["SETTINGS", "HISTORY"], Callable(), false, false, true).
	# Add controls to corners[0] and a played-card/event log to corners[1].
	# The shared corner sheets scroll, and narrow hosts show only one at a time.
	# Optionally pass a placement Callable returning a free Rect2 in host coordinates:
	# screen.add_corner_details(captions, free_area). A zero rect uses the corners.
	# Optional third argument true uses smaller shared buttons, sheet text and bounds:
	# screen.add_corner_details(captions, free_area, true).
	# Fourth argument true fits the first settings sheet to its contents without
	# scrolling; use compact controls and a two-column GridContainer for short forms.
	# In a short placement area, the shared sheet opens centered over a dim backdrop
	# with Close/Escape/outside dismissal so the disclosure buttons cannot overlap it.
	# History in the second sheet retains its shared scrollbar.
	# Use add_history_log(body, true) inside these scrollable sheets for one scrollbar.
	# For a canvas-owned identity: GameLook.draw_turn_glow(canvas, rect, accent, pulse).
	# Apply to the local active player; use a fixed pulse with reduced motion.
	# Choice targets may share this glow on the chooser's view with validated buttons.
	# Reserve replay space even while hidden; size cells using screen.board_height_limit().
	# Connect screen.board_space_changed to the same callback used for screen.resized.
	# Animate inner visuals with GameMotion.play(visual, session.reduced_motion, true).
	# Call GameMotion.reset(visual) when reusing a visual for a new round.
	# Optional board overlay: add GameCelebration as a sibling above the playfield.
	# show_win(normalized_segments, headline, color, not session.reduced_motion)
	# restores a static strike when its animate argument is false; clear on reset.
	# Optional host settings inherit the same theme as the game screen.
	example_choice = screen.add_choice_control(layout.sidebar, "MODE", ["Practice", "Match"])
	example_choice.item_selected.connect(func(index: int) -> void:
		if session != null and index in [0, 1]:
			save_game_settings({"mode": index})
	)
	# Fourth argument true places the label and selector on one compact row.
	# Optional for small artwork panels; pass false after wrapping to restore size.
	# GameLook.action buttons retain a grey disabled surface when compacted.
	var fit_choice := func() -> void: GameLook.compact_control(example_choice, screen.available_size().x >= 1100)
	screen.resized.connect(fit_choice)
	fit_choice.call_deferred()
	example_toggle = screen.add_toggle_control(layout.sidebar, "OPTIONAL RULE")
	# Optional semantic colors: ON green, OFF red, preserving shared geometry.
	GameLook.toggle_state(example_toggle, example_toggle.button_pressed)
	example_toggle.toggled.connect(func(enabled: bool) -> void:
		GameLook.toggle_state(example_toggle, enabled)
		if session != null:
			save_game_settings({"optional_rule": enabled})
	)
	# Also call toggle_state after set_pressed_no_signal when restoring state.
	# Call after styling a group to reserve ON/OFF labels and equal button sizes:
	GameLook.equal_control_sizes([example_toggle])
	example_length = screen.add_number_control(layout.sidebar, "CUSTOM ROUND LENGTH", 0.1, 1440.0, 0.1, 10.0, "min")
	example_length.value_changed.connect(func(minutes: float) -> void:
		if session != null and is_finite(minutes) and minutes >= 0.1 and minutes <= 1440.0:
			save_game_settings({"round_minutes": minutes})
	)
	# Persistent voting/results can use this shared responsive modal. The body
	# scrolls; actions and Back to Games stay reachable. The module owns visibility.
	# Pass true to fit short results to their contents, with scrolling when needed.
	phase_dialog = screen.add_phase_dialog(true, false, true)
	var player_header_example := screen.add_phase_dialog(true,false,true)
	screen.set_phase_dialog_header(player_header_example,"Example player",{"texture":RuntimeAssets.scalable_texture("res://ui/playful/stat-trophy.svg"),"value":3,"label":"Session wins"})
	screen.add_sidebar_text(player_header_example.body,"Put filtered public counters and activity here.")
	var close_player_example := Button.new(); close_player_example.text = "Close"; GameLook.action(close_player_example,false); player_header_example.actions.add_child(close_player_example); close_player_example.pressed.connect(func() -> void: player_header_example.overlay.hide())
	phase_dialog.heading.text = "ROUND RESULT"
	screen.add_sidebar_text(phase_dialog.body, "Add authoritative votes or results here.")
	# Full-screen editors share the same scroll/actions/navigation contract.
	var settings_example := screen.add_phase_dialog(false, true)
	settings_example.heading.text = "SETTINGS"
	screen.add_number_control(settings_example.body, "ROUND LENGTH", 30, 180, 15, 60, "sec")
	# Optional semantic result: screen.set_phase_dialog_tone(phase_dialog, "danger")
	# or "success"; an empty tone restores the game's regular palette on replay.
	# Winning avatars use the same identity colors and poses as the lobby:
	var team := screen.add_team_reveal(phase_dialog.body)
	screen.set_team_reveal(team, [{"display_name": "PLAYER", "color": "#2463eb", "pose": 0}])
	# Fourth argument true provides compact avatars for a public living-player row:
	# screen.set_team_reveal(team, public_living_players, "", true).
	# Fifth argument true keeps eliminated seats as tombstones using public alive flags:
	# screen.set_team_reveal(team, public_players, "", true, true).
	# Optional formatted names preserve literal text and support eliminated players.
	var formatted_score := screen.add_session_score(layout.sidebar, true)
	screen.set_text_parts(formatted_score.player, [{"text": "PLAYER", "strikethrough": true}])
	formatted_score.content.hide()
	# phase_dialog.overlay.show(); hide it when the host starts the next round.
	# Urgent clocks pulse once per new second with GameMotion.countdown(label,
	# session.reduced_motion); call GameMotion.reset on pause, replay and exit.
	# For a blinking red timer span, multiply its color alpha by
	# GameMotion.countdown_alpha(seconds, session.reduced_motion) while running.
	# Keep reduced-motion clocks static; deduplicate sound ticks per turn/second.
	# Validate selection callbacks and lock settings once their match begins.
	# Standard playing cards and dark brass chrome are shared opt-ins. Keep
	# rank/suit/back semantic, never bake dynamic cards or names into artwork.
	var standard_example := GameCard.new()
	standard_example.card = {"layout": "standard", "rank": "A", "suit": "spades", "name": "Ace of spades"}
	standard_example.custom_minimum_size = Vector2(80, 120)
	standard_example.hide(); screen.content.add_child(standard_example)
	# use_playful_style(background_stem, "casino") pairs with browser game-casino.
	# GameLook.casino_sheet(active) and casino_action(button,"fold"|"call"|"raise")
	# style real controls; GameChoiceCard.caption_on_top/overlay_cards optionally
	# place its caption first and semantic cards over a supplied illustration.
	var casino_example := PanelContainer.new(); casino_example.theme = GameLook.make_theme("casino")
	casino_example.add_theme_stylebox_override("panel", GameLook.casino_frame()); casino_example.hide(); screen.content.add_child(casino_example)
	var casino_controls := VBoxContainer.new(); casino_example.add_child(casino_controls)
	var casino_badge := Control.new(); casino_badge.custom_minimum_size = Vector2(200, 64); casino_controls.add_child(casino_badge)
	casino_badge.draw.connect(func() -> void:
		casino_badge.draw_style_box(GameLook.casino_player_sheet(true), Rect2(24, 2, 176, 60))
		GameLook.draw_table_avatar(casino_badge, Rect2(0, 2, 60, 60), Color("2463eb"), 0)
		GameLook.draw_table_text(casino_badge, "Example player", Vector2(68, 28), 120, 14, Color.WHITE))
	var casino_bet := Button.new(); casino_bet.text = "BET"; GameLook.casino_action(casino_bet, "raise"); casino_controls.add_child(casino_bet)
	var casino_slider := HSlider.new(); casino_slider.custom_minimum_size.y = 44; casino_slider.accessibility_name = "Example bet amount"; casino_controls.add_child(casino_slider)
	# A table can keep one replay Button inside its persistent auxiliary action
	# row: center_board(table,replay,toolbar,.47,true,false,true,true). The eighth
	# embedded_replay flag reserves the toolbar and leaves that button in its row.
	# If replay lives inside table itself, that same flag avoids a second footer
	# reservation: center_board(table,replay,null,.5,false,false,false,true).
	# An optional ninth bottom_auxiliary=true pins a wide toolbar 16px above the
	# viewport bottom and centers the board in the space above it. For example:
	# center_board(table,replay,toolbar,.5,true,false,true,true,true).
	# Use the existing casino_sheet for a themed panel inside that toolbar.
	var phase_example := GamePhaseTrack.new(); phase_example.steps = ["First", "Second"]
	# compact=true omits the caption and fits a 42px table-header progress row.
	phase_example.compact = true
	phase_example.hide(); screen.content.add_child(phase_example); phase_example.set_current(1)
	# A static voyage/count track is separate from the phase tracker. Values and
	# its accessible description come from an authorized public snapshot.
	var progress_example := GameProgressTrack.new(); progress_example.hide(); screen.content.add_child(progress_example)
	progress_example.set_progress(2,7,3,4,"Two of seven steps. Incoming 3; defense 4.")
	var option_card_example := GameCardGrid.new(); option_card_example.hide(); screen.content.add_child(option_card_example)
	option_card_example.set_items([{"card":{"id":"example","layout":"symbol","name":"Example option","detail":"","foot":"Active"},"texture":RuntimeAssets.texture("res://Games/_Template/thumbnail.svg"),"inline_choice":{"options":["First option","Second option"],"selected":0,"label":"Example card option"}}])
	option_card_example.choice_selected.connect(func(_id: String, _index: int) -> void: pass) # Stage a preference; never start play here.
	var guide_example := Button.new(); guide_example.text = "Read example guide"; guide_example.hide(); screen.content.add_child(guide_example)
	guide_example.pressed.connect(func() -> void:
		reader_example.show_reference_gallery([{"label":"Guide","pages":[{"label":"Overview","front":"res://Games/_Template/thumbnail.svg","back":"res://Games/_Template/thumbnail.svg","front_label":"Overview","back_label":"Scenario","description":"Literal accessible rules."}]}],"Rules & costs",false,0,true)
	)
	# Filter and merge pages to the active setup first. The final true selects
	# large, independently flippable cards; small screens scroll the collection.
	# Card taps do not open another view. Only Back exits this reference help.
	# Optional browse=true adds compact collection buttons for setup libraries.
	# GameLook.help_control(button) supplies a circular 44px question-mark action.
	# GameLook.instruction_control(button) makes a readable contextual instruction
	# that can reopen a dismissed required decision without another utility.
	# use_table_header(null, true) centers the title above progress. Optional
	# use_table_header(null, false, true) keeps title/progress in one compact row.
	# center_board(..., 0.53) can lower a private-card table within the shared fitter.
	# set_table_header_action(button) docks by music; set_table_header_summary(control)
	# keeps compact public facts below it, reserving their space on small screens.
	# set_table_header_summary(roster_grid, true) reserves a full-width compact
	# roster above the board while visible; hide it when moving rows to sidebars.
	var ranked_example := GameRankedResults.new(); ranked_example.theme = GameLook.make_theme("casino")
	ranked_example.maximum_height = 160; ranked_example.amount_icon = RuntimeAssets.texture("res://ui/playful/table-cash.svg")
	ranked_example.hide(); screen.content.add_child(ranked_example)
	ranked_example.set_entries([{"rank": 1, "seat": 0, "name": "Example winner", "color": "#2463eb", "category": "Royal Flush", "amount": 100, "marked_cards": [0], "card_mark": "HOLE", "cards": [{"layout":"standard", "rank":"A", "suit":"spades", "name":"Ace of spades"}]}, {"rank": 2, "seat": 1, "name": "Example loss", "category": "One Pair", "amount": -100, "cards": []}])


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	var saved := load_game_settings({"mode": 0, "optional_rule": false, "round_minutes": 10.0})
	example_choice.select(saved.mode if saved.mode in [0, 1] else 0)
	example_toggle.set_pressed_no_signal(saved.optional_rule)
	example_toggle.text = "OPTIONAL RULE: " + ("ON" if saved.optional_rule else "OFF")
	GameLook.toggle_state(example_toggle, saved.optional_rule)
	example_length.set_value_no_signal(saved.round_minutes if saved.round_minutes >= 0.1 and saved.round_minutes <= 1440.0 else 10.0)
	screen.scores.text = "Players ready: %d" % context.players.size()
	screen.status.text = "Ready to play"


func shutdown_game() -> void:
	screen.background_media.set_active(false)


func handle_controller_message(player_id: String, message: Dictionary) -> void:
	# Replace this finite sample and host/debug.gd with the game's real legal
	# actions/completion predicate. The shared runner never guesses game rules.
	if session.debug_mode and message.get("action") == "debug_sample":
		if debug_sample_turn >= session.players.size() or message.get("revision") != debug_sample_turn: return
		if str(session.players[debug_sample_turn].id) != player_id: return
		debug_sample_turn += 1
		screen.status.text = "Debug sample complete" if debug_sample_turn == session.players.size() else "Debug sample: %d / %d players acted" % [debug_sample_turn, session.players.size()]
	# Hidden-information modules may use send_state(player_id, private_view).
	# Build that view on the host; never broadcast secrets or another player's hand.
	broadcast_state({"status": "Ready to play"})
