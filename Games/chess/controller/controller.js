(() => {
	"use strict";
	const $ = id => document.getElementById(id);
	const motion = matchMedia("(prefers-reduced-motion: reduce)");
	const names = ["", "pawn", "knight", "bishop", "rook", "queen", "king"];
	let player = null, state = null, shown = null, online = false, pending = false;
	let selected = -1, promotionMove = null, receivedAt = 0, animateResult = false;
	const owner = piece => piece ? (piece > 0 ? 1 : 2) : 0;
	const coordinate = cell => String.fromCharCode(97 + cell % 8) + (8 - Math.floor(cell / 8));
	const buttons = Array.from({length: 64}, (_, cell) => {
		const button = document.createElement("button");
		button.type = "button"; button.disabled = true;
		button.className = (Math.floor(cell / 8) + cell % 8) % 2 ? "dark" : "light";
		button.addEventListener("click", () => choose(cell));
		$("board").append(button); return button;
	});
	const edgeLabels = ["top", "bottom", "left", "right"].map(edge => {
		const strip = document.createElement("div");
		strip.className = "board-coordinates " + edge; strip.setAttribute("aria-hidden", "true");
		for (let index = 0; index < 8; index++) strip.append(document.createElement("span"));
		$("board").append(strip); return strip;
	});
	function renderCoordinates() {
		const flipped = seat() === 2;
		edgeLabels.forEach((strip, edge) => [...strip.children].forEach((label, index) => {
			label.textContent = edge < 2 ? String.fromCharCode(97 + (flipped ? 7 - index : index)) : String(flipped ? index + 1 : 8 - index);
		}));
	}
	["white", "black"].forEach((side, index) => {
		for (let kind = 1; kind <= 6; kind++) {
			const img = document.createElement("img");
			img.src = ChessBoardMotion.source((index ? -1 : 1) * kind); img.alt = names[kind];
			const count = document.createElement("span"); count.id = side + "-count-" + kind;
			const item = document.createElement("div"); item.className = "game-stat-item";
			count.textContent = "x 0"; item.append(img, count); $(side + "-material").append(item);
		}
	});
	const celebration = new StarGamesCelebration($("board"));
	const boardMotion = new ChessBoardMotion($("board"), buttons, () => { resultFeedback(); render(); });
	const controller = new StarGamesController("chess", {
		connected: identity => {
			player = identity; online = true; pending = false; selected = -1;
			state = null; shown = null; closePromotion();
			$("connection").textContent = "Connected as " + identity.display_name;
			render(); controller.send({action: "sync"});
		},
		disconnected: () => {
			online = false; closePromotion();
			$("connection").textContent = "Reconnecting... Play is paused."; render();
		},
		error: error => {
			online = false; closePromotion(); $("connection").textContent = error.message; render();
		},
		message: payload => {
			if (!Array.isArray(payload.board) || payload.board.length !== 64 || !Array.isArray(payload.players)) return;
			if (state && (state.round_id !== payload.round_id || state.revision !== payload.revision)) {
				selected = -1; closePromotion();
			}
			const previous = state;
			state = payload; receivedAt = performance.now(); pending = false;
			const newRound = !previous || previous.round_id !== state.round_id;
			animateResult = !!previous && !newRound && !previous.outcome && !!state.outcome;
			const changed = !previous || state.board.some((piece, cell) => piece !== previous.board[cell]);
			buttons.forEach((button, cell) => button.style.order = String(seat() === 2 ? 63 - cell : cell));
			if (newRound) { celebration.clear(); boardMotion.reset(state.board); shown = null; }
			else if (changed) {
				if (motion.matches || !previous.board[state.last_move?.from]) boardMotion.reset(state.board);
				else boardMotion.play(previous.board, state.board, state.last_move);
			}
			if (!state.outcome) { celebration.clear(); shown = null; }
			if (!boardMotion.busy) resultFeedback();
			render();
		}
	});
	function seat() { return state && player ? state.players.findIndex(p => p.id === player.id) + 1 : 0; }
	function available() { return online && state && seat() && !pending && !state.paused && !state.outcome && !state.animating && !boardMotion.busy; }
	function canPlay() { return available() && seat() === state.turn; }
	function choose(cell) {
		if (!canPlay() || promotionMove) return;
		const matching = state.legal_moves.filter(step => step.from === selected && step.to === cell);
		if (matching.length) {
			if (matching[0].promotion) {
				promotionMove = {from: selected, to: cell, revision: state.revision};
				$("promotion").showModal();
			} else send("move", {from: selected, to: cell, promotion: 0});
			return;
		}
		selected = owner(state.board[cell]) === seat() ? cell : -1; render();
	}
	function closePromotion() {
		promotionMove = null;
		if ($("promotion").open) $("promotion").close();
	}
	function send(action, input = {}) {
		if (!online || !state || pending || state.paused) return;
		pending = true; render();
		controller.send({action, revision: state.revision, ...input});
	}
	function resultFeedback() {
		if (!state?.outcome || shown === state.outcome) return;
		shown = state.outcome;
		if ([1, 2].includes(state.outcome)) {
			celebration.show([], state.result_reason === "Checkmate" ? "CHECKMATE!" : "VICTORY!", state.outcome === 1 ? "#cf2337" : "#195fc0", !motion.matches && animateResult);
		}
	}
	function clockText(seconds) {
		const total = Math.max(0, Math.ceil(seconds));
		return (total >= 3600 ? Math.floor(total / 3600) + ":" + String(Math.floor(total / 60) % 60).padStart(2, "0") : String(Math.floor(total / 60))) + ":" + String(total % 60).padStart(2, "0");
	}
	function renderClocks() {
		if (!state) return;
		["white", "black"].forEach((side, index) => {
			const elapsed = online && state.clock_running && state.turn === index + 1 ? (performance.now() - receivedAt) / 1000 : 0;
			$(side + "-clock").hidden = !state.clock_seconds;
			$(side + "-clock").textContent = state.clock_seconds ? clockText(state.remaining[index] - elapsed) : "";
		});
	}
	function render() {
		renderCoordinates();
		const legal = state?.legal_moves || [];
		buttons.forEach((button, cell) => {
			const piece = state?.board[cell] || 0;
			const destination = selected >= 0 && legal.some(step => step.from === selected && step.to === cell);
			button.classList.toggle("selected", selected === cell && canPlay());
			button.classList.toggle("destination", destination && canPlay() && state.guidance);
			button.classList.toggle("last-move", !!state?.last_move && [state.last_move.from, state.last_move.to].includes(cell));
			button.classList.toggle("in-check", !!state?.check && piece === (state.turn === 1 ? 6 : -6));
			button.disabled = !canPlay();
			button.setAttribute("aria-pressed", String(selected === cell));
			button.setAttribute("aria-label", coordinate(cell) + ": " + (piece ? (piece > 0 ? "White " : "Black ") + names[Math.abs(piece)] : "empty") + (destination && state?.guidance ? ", legal destination" : ""));
		});
		$("replay").hidden = !state?.outcome;
		$("replay").disabled = !online || pending || !!state?.paused || !!state?.animating || boardMotion.busy;
		if (!state) return;
		["white", "black"].forEach((side, index) => {
			$(side + "-player").textContent = state.players[index].display_name + " (" + (index ? "Black" : "White") + ")";
			$(side + "-player").style.borderColor = state.players[index].color;
			$(side + "-player").classList.toggle("is-active-player", online && !state.paused && !state.outcome && state.turn === index + 1);
			const wins = state.session_wins[index];
			$(side + "-score").textContent = wins + (wins === 1 ? " WIN" : " WINS");
			for (let kind = 1; kind <= 6; kind++) $(side + "-count-" + kind).textContent = "x " + state.board.filter(p => p === (index ? -kind : kind)).length;
		});
		$("status").textContent = state.status;
		renderClocks();
	}
	document.querySelectorAll("[data-promotion]").forEach(button => button.addEventListener("click", () => {
		const move = promotionMove; closePromotion();
		if (move && move.revision === state?.revision && canPlay()) send("move", {from: move.from, to: move.to, promotion: Number(button.dataset.promotion)});
	}));
	$("cancel-promotion").addEventListener("click", closePromotion);
	$("promotion").addEventListener("cancel", () => { promotionMove = null; });
	$("replay").addEventListener("click", () => send("play_again"));
	motion.addEventListener("change", () => {
		if (motion.matches) { boardMotion.reset(state?.board || Array(64).fill(0)); celebration.clear(); shown = null; resultFeedback(); render(); }
	});
	window.addEventListener("resize", () => { if (boardMotion.busy) { boardMotion.reset(state.board); resultFeedback(); render(); } });
	window.addEventListener("gameboardresize", () => { if (boardMotion.busy) { boardMotion.reset(state.board); resultFeedback(); render(); } });
	window.addEventListener("pagehide", () => { celebration.clear(); boardMotion.reset(Array(64).fill(0)); closePromotion(); });
	setInterval(renderClocks, 100);
	controller.connect();
})();

