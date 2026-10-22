extends RefCounted

# Cards are stable integers 0..51; suits never break ties.
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS := ["clubs", "diamonds", "hearts", "spades"]
const NAMES := ["High Card", "One Pair", "Two Pair", "Three of a Kind", "Straight", "Flush", "Full House", "Four of a Kind", "Straight Flush"]


static func card_data(id: int) -> Dictionary:
	return {"id": id, "layout": "standard", "rank": RANKS[id % 13], "suit": SUITS[id / 13], "name": "%s of %s" % [RANKS[id % 13], SUITS[id / 13]]}


static func five(cards: Array) -> Dictionary:
	if cards.size() != 5: return {"score": -1, "category": -1, "name": "", "cards": []}
	var ranks: Array = []
	var counts: Dictionary = {}
	var flush := true
	for card: int in cards:
		var rank := card % 13 + 2
		ranks.append(rank); counts[rank] = int(counts.get(rank, 0)) + 1
		if card / 13 != int(cards[0]) / 13: flush = false
	ranks.sort(); ranks.reverse()
	var unique: Array = counts.keys(); unique.sort(); unique.reverse()
	var straight := 0
	if unique.size() == 5:
		if int(unique[0]) - int(unique[4]) == 4: straight = int(unique[0])
		elif unique == [14, 5, 4, 3, 2]: straight = 5
	var groups: Array = counts.keys()
	groups.sort_custom(func(a: int, b: int) -> bool: return int(counts[a]) > int(counts[b]) or (counts[a] == counts[b] and a > b))
	var category := 0
	var kickers: Array = ranks.duplicate()
	if flush and straight > 0: category = 8; kickers = [straight]
	elif counts[groups[0]] == 4: category = 7; kickers = [groups[0], groups[1]]
	elif counts[groups[0]] == 3 and counts[groups[1]] == 2: category = 6; kickers = [groups[0], groups[1]]
	elif flush: category = 5
	elif straight > 0: category = 4; kickers = [straight]
	elif counts[groups[0]] == 3: category = 3; kickers = groups
	elif counts[groups[0]] == 2 and counts[groups[1]] == 2: category = 2; kickers = groups
	elif counts[groups[0]] == 2: category = 1; kickers = groups
	var score := category
	for index in 5: score = score * 15 + (int(kickers[index]) if index < kickers.size() else 0)
	return {"score": score, "category": category, "name": "Royal Flush" if category == 8 and straight == 14 else NAMES[category], "cards": cards.duplicate()}


static func best(hand: Array, board: Array, variant: String) -> Dictionary:
	var result := {"score": -1, "category": -1, "name": "Pre-Flop", "cards": []}
	if board.size() < 3: return result
	if variant == "omaha":
		for a in hand.size():
			for b in range(a + 1, hand.size()):
				for c in board.size():
					for d in range(c + 1, board.size()):
						for e in range(d + 1, board.size()):
							var candidate := five([hand[a], hand[b], board[c], board[d], board[e]])
							if int(candidate.score) > int(result.score): result = candidate
	else:
		var pool := hand + board
		for a in pool.size():
			for b in range(a + 1, pool.size()):
				for c in range(b + 1, pool.size()):
					for d in range(c + 1, pool.size()):
						for e in range(d + 1, pool.size()):
							var candidate := five([pool[a], pool[b], pool[c], pool[d], pool[e]])
							if int(candidate.score) > int(result.score): result = candidate
	return result
