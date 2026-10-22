extends RefCounted

# Rules contain no presentation or network code. Ships may touch, never overlap.
enum Difficulty { EASY, MEDIUM, HARD }
const LENGTHS := [5, 4, 3, 3, 2]
const NAMES := ["Carrier", "Battleship", "Cruiser", "Submarine", "Destroyer"]
const TOTAL_CELLS := 17
var fleets: Array = [[], []]
# shots[seat] contains that seat's outgoing fire: 0 unknown, 1 miss, 2 hit, 3 sunk.
var shots: Array = [[], []]
var ready := [false, false]
var phase := "setup"
var turn := 1
var starter := 1
var outcome := 0
var revision := 0
var round_number := 1
var session_wins := [0, 0]
var history: Array = []
var last_shot: Dictionary = {}


func _init() -> void:
	_reset_board()


func _reset_board() -> void:
	fleets = [[], []]
	shots = [[], []]
	for board in shots:
		board.resize(100)
		board.fill(0)
	ready = [false, false]
	phase = "setup"
	turn = starter
	outcome = 0
	last_shot = {}


static func ship_cells(cell: int, length: int, vertical: bool) -> Array:
	if cell < 0 or cell >= 100 or length < 2 or length > 5:
		return []
	if (int(cell / 10) + length > 10) if vertical else (cell % 10 + length > 10):
		return []
	var cells: Array = []
	for offset in length:
		cells.append(cell + offset * (10 if vertical else 1))
	return cells


static func can_place(fleet: Array, ship: int, cell: int, vertical: bool) -> bool:
	if ship < 0 or ship >= LENGTHS.size():
		return false
	var cells := ship_cells(cell, LENGTHS[ship], vertical)
	if cells.is_empty():
		return false
	for existing in fleet:
		if existing.ship != ship and existing.cells.any(func(index: int) -> bool: return cells.has(index)):
			return false
	return true


func place_ship(seat: int, ship: int, cell: int, vertical: bool) -> bool:
	if seat not in [1, 2] or phase != "setup" or ready[seat - 1] or not can_place(fleets[seat - 1], ship, cell, vertical):
		return false
	var placement := {"ship": ship, "cell": cell, "vertical": vertical, "length": LENGTHS[ship], "cells": ship_cells(cell, LENGTHS[ship], vertical)}
	var fleet: Array = fleets[seat - 1]
	for index in fleet.size():
		if fleet[index].ship == ship:
			if fleet[index] == placement:
				return false
			fleet[index] = placement
			revision += 1
			return true
	fleet.append(placement)
	revision += 1
	return true


func rotate_ship(seat: int, cell: int) -> bool:
	if seat not in [1, 2] or phase != "setup" or ready[seat - 1] or cell < 0 or cell >= 100:
		return false
	for ship in fleets[seat - 1]:
		if ship.cells.has(cell):
			return place_ship(seat, ship.ship, ship.cell, not ship.vertical)
	return false


static func random_fleet() -> Array:
	var fleet: Array = []
	for ship in LENGTHS.size():
		var candidates: Array = []
		for cell in 100:
			for vertical in [false, true]:
				if can_place(fleet, ship, cell, vertical):
					candidates.append({"ship": ship, "cell": cell, "vertical": vertical, "length": LENGTHS[ship], "cells": ship_cells(cell, LENGTHS[ship], vertical)})
		# A 10x10 board always has room after these four longer ships.
		if candidates.is_empty():
			return []
		fleet.append(candidates.pick_random())
	return fleet


func auto_place(seat: int) -> bool:
	if seat not in [1, 2] or phase != "setup" or ready[seat - 1]:
		return false
	var fleet := random_fleet()
	if fleet.size() != 5:
		return false
	fleets[seat - 1] = fleet
	revision += 1
	return true


func clear_fleet(seat: int) -> bool:
	if seat not in [1, 2] or phase != "setup" or ready[seat - 1] or fleets[seat - 1].is_empty():
		return false
	fleets[seat - 1] = []
	revision += 1
	return true


func lock_fleet(seat: int) -> bool:
	if seat not in [1, 2] or phase != "setup" or ready[seat - 1]:
		return false
	var fleet: Array = fleets[seat - 1]
	if fleet.size() != 5:
		return false
	var ids: Array = []
	for placement in fleet:
		if ids.has(placement.ship) or not can_place(fleet, placement.ship, placement.cell, placement.vertical):
			return false
		ids.append(placement.ship)
	ready[seat - 1] = true
	if ready[0] and ready[1]:
		phase = "battle"
		turn = starter
	revision += 1
	return true


func fire(seat: int, cell: int) -> bool:
	if seat not in [1, 2] or phase != "battle" or turn != seat or cell < 0 or cell >= 100 or shots[seat - 1][cell] != 0:
		return false
	var result := 1
	var sunk_ship := -1
	for placement in fleets[2 - seat]:
		if placement.cells.has(cell):
			result = 2
			shots[seat - 1][cell] = 2
			if placement.cells.all(func(index: int) -> bool: return shots[seat - 1][index] >= 2):
				result = 3
				sunk_ship = placement.ship
				for index in placement.cells:
					shots[seat - 1][index] = 3
			break
	shots[seat - 1][cell] = result
	revision += 1
	last_shot = {"id": revision, "seat": seat, "cell": cell, "result": result, "ship": sunk_ship}
	if shots[seat - 1].count(3) == TOTAL_CELLS:
		phase = "finished"
		outcome = seat
		session_wins[seat - 1] += 1
		history.append({"round": round_number, "winner": seat, "shots": [100 - shots[0].count(0), 100 - shots[1].count(0)]})
	else:
		turn = 3 - seat
	return true


func play_again() -> bool:
	if phase != "finished":
		return false
	round_number += 1
	starter = 3 - starter
	revision += 1
	_reset_board()
	return true


func sunk_fleet(seat: int) -> Array:
	if seat not in [1, 2]:
		return []
	return fleets[seat - 1].filter(func(placement: Dictionary) -> bool: return placement.cells.all(func(cell: int) -> bool: return shots[2 - seat][cell] == 3)).duplicate(true)


# Never export all fleets. Each view contains its owner's ships plus public wrecks.
func view_for(seat: int) -> Dictionary:
	var visible_fleets: Array = [sunk_fleet(1), sunk_fleet(2)]
	for index in 2:
		if seat == index + 1 or phase == "finished":
			visible_fleets[index] = fleets[index].duplicate(true)
	return {"viewer": seat, "fleets": visible_fleets, "incoming": [shots[1].duplicate(), shots[0].duplicate()], "ready": ready.duplicate(), "phase": phase, "turn": turn, "starter": starter, "outcome": outcome, "revision": revision, "round_id": str(round_number), "round": round_number, "session_wins": session_wins.duplicate(), "remaining": [TOTAL_CELLS - shots[1].count(2) - shots[1].count(3), TOTAL_CELLS - shots[0].count(2) - shots[0].count(3)], "sunk": [sunk_fleet(1).size(), sunk_fleet(2).size()], "last_shot": last_shot.duplicate()}


func remaining_lengths(shooter: int) -> Array:
	var lengths := LENGTHS.duplicate()
	for wreck in sunk_fleet(3 - shooter):
		lengths.erase(wreck.length)
	return lengths


# This search accepts ONLY publicly known shots and remaining lengths. No peeking.
static func computer_target(known: Array, lengths: Array, difficulty: int) -> int:
	var available: Array = []
	var hits: Array = []
	for cell in 100:
		if known[cell] == 0:
			available.append(cell)
		elif known[cell] == 2:
			hits.append(cell)
	if available.is_empty():
		return -1
	if difficulty == Difficulty.EASY:
		return available.pick_random()
	var targets: Array = []
	for hit in hits:
		for neighbor in [hit - 10, hit + 10, hit - 1, hit + 1]:
			if neighbor in available and (abs(neighbor - hit) == 10 or int(neighbor / 10) == int(hit / 10)):
				targets.append(neighbor)
	if difficulty == Difficulty.MEDIUM:
		if not targets.is_empty():
			return targets.pick_random()
		var checkerboard := available.filter(func(cell: int) -> bool: return (cell % 10 + int(cell / 10)) % 2 == 0)
		return (available if checkerboard.is_empty() else checkerboard).pick_random()
	var density: Array = []
	density.resize(100)
	density.fill(0)
	for length in lengths:
		for cell in 100:
			for vertical in [false, true]:
				var cells := ship_cells(cell, int(length), vertical)
				if cells.is_empty() or cells.any(func(index: int) -> bool: return known[index] in [1, 3]):
					continue
				var covered: int = cells.filter(func(index: int) -> bool: return known[index] == 2).size()
				if not hits.is_empty() and covered == 0:
					continue
				for index in cells:
					if known[index] == 0:
						density[index] += 1 + covered * covered * 12
	var best := -1
	var choices: Array = []
	for cell in available:
		if density[cell] > best:
			best = density[cell]
			choices = [cell]
		elif density[cell] == best:
			choices.append(cell)
	return choices.pick_random()
