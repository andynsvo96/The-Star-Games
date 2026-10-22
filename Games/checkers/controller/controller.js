(() => {
	"use strict";
	const $ = id => document.getElementById(id);
	const motion = matchMedia("(prefers-reduced-motion: reduce)");
	let player = null, state = null, shownState = null;
	let online = false, pending = false, selected = -1;
	let receivedAt = 0;
	let shownTimerResult = "";
	const owner = piece => piece ? (piece - 1) % 2 + 1 : 0;
	const buttons = Array.from({length: 64}, (_, cell) => {
		const button = document.createElement("button");
		button.type = "button";
		button.disabled = true;
		button.className = (Math.floor(cell / 8) + cell % 8) % 2 ? "dark" : "light";
		button.addEventListener("click", () => choose(cell));
		$("board").append(button);
		return button;
	});
	const celebration = new StarGamesCelebration($("board"));
	const boardMotion = new CheckersBoardMotion($("board"), buttons, (step, outcome) => {
		if ([1, 2].includes(outcome)) celebration.show([], "KING OF THE BOARD!", outcome === 1 ? "#ff4262" : "#39435a", !motion.matches);
	}, () => render());
	const controller = new StarGamesController("checkers", {
		connected: identity => {
			player = identity; online = true; pending = false;
			state = null; shownState = null; selected = -1; shownTimerResult = "";
			$("connection").textContent = `Connected as ${identity.display_name}`;
			render();
			controller.send({action: "sync"});
		},
		disconnected: () => {
			online = false;
			$("connection").textContent = "Reconnecting... Play is paused.";
			render();
		},
		error: error => {
			online = false;
			$("connection").textContent = error.message;
			render();
		},
		message: payload => {
			if (!Array.isArray(payload.board) || payload.board.length !== 64) return;
			if (!state || state.revision !== payload.revision || state.round_id !== payload.round_id) selected = -1;
			state = payload; pending = false; receivedAt = performance.now();
			render();
		}
	});
	function seat() { return state && player ? state.players.findIndex(p => p.id === player.id) + 1 : 0; }
	function canPlay() { return online && !pending && !boardMotion.busy && state && !state.paused && !state.outcome && seat() === state.turn; }
	function choose(cell) {
		if (!canPlay()) return;
		const legal = state.legal_moves || [];
		if (selected >= 0 && legal.some(step => step.from === selected && step.to === cell)) {
			send("move", {from: selected, to: cell});
			return;
		}
		if (state.forced_from < 0) {
			selected = legal.some(step => step.from === cell) ? cell : -1;
			render();
		}
	}
	function send(action, input = {}) {
		if (!online || !state || pending || state.paused) return;
		pending = true;
		render();
		controller.send({action, revision: state.revision, ...input});
	}
	function render() {
		const mark = seat();
		const legal = state?.legal_moves || [];
		const newRound = state?.round_id !== shownState?.round_id;
		const changedBoard = !!state && (!shownState || state.board.some((piece, cell) => piece !== shownState.board[cell]));
		const moved = changedBoard && !!shownState && !newRound && Number.isInteger(state.last_move?.to) && !!shownState.board[state.last_move.from] && !!state.board[state.last_move.to];
		buttons.forEach((button, cell) => button.style.order = String(mark === 2 ? 63 - cell : cell));
		if (!state || newRound || (changedBoard && !moved)) boardMotion.reset(state?.board || Array(64).fill(0));
		else if (moved) {
			if (motion.matches) boardMotion.reset(state.board);
			else boardMotion.enqueue(state.board, state.last_move, shownState.board[state.last_move.from], state.outcome);
		}
		if (canPlay() && state.forced_from >= 0) selected = state.forced_from;
		if (!state || newRound || !state.outcome) celebration.clear();
		const timerResult = state?.result_reason === "Time expired" && shownTimerResult !== state.round_id;
		if (!boardMotion.busy && state && [1, 2].includes(state.outcome) && (newRound || shownState?.outcome !== state.outcome || timerResult)) {
			celebration.show([], "KING OF THE BOARD!", state.outcome === 1 ? "#ff4262" : "#39435a", !!shownState && !newRound && !motion.matches);
			if (timerResult) shownTimerResult = state.round_id;
		}
		buttons.forEach((button, cell) => {
			const piece = state?.board[cell] || 0;
			button.dataset.piece = String(piece);
			const source = legal.some(step => step.from === cell);
			const destination = selected >= 0 && legal.some(step => step.from === selected && step.to === cell);
			const last = Number.isInteger(state?.last_move?.to) && [state.last_move.from, state.last_move.to].includes(cell);
			button.classList.toggle("selected", selected === cell && canPlay());
			button.classList.toggle("game-selection-ring", selected === cell && canPlay());
			button.classList.toggle("destination", destination && canPlay());
			button.classList.toggle("movable", source && canPlay());
			button.classList.toggle("last-move", last);
			button.classList.toggle("winning-piece", !!state && [1, 2].includes(state.outcome) && owner(piece) === state.outcome);
			button.disabled = !canPlay() || !(source || destination);
			button.setAttribute("aria-pressed", String(selected === cell));
			const coordinate = `${String.fromCharCode(65 + cell % 8)}${8 - Math.floor(cell / 8)}`;
			const description = piece ? `${owner(piece) === 1 ? "Red" : "Black"} ${piece >= 3 ? "king" : "piece"}` : "empty";
			button.setAttribute("aria-label", `${coordinate}: ${description}${destination && canPlay() ? ", legal destination" : ""}`);
		});
		$("replay").hidden = !state?.outcome;
		$("replay").disabled = !online || pending || !!state?.paused;
		["red", "black"].forEach((side, index) => $(`${side}-player`).classList.toggle("is-active-player", online && !!state && !state.paused && !state.outcome && state.turn === index + 1));
		if (!state) return;
		["red", "black"].forEach((side, index) => {
			$(`${side}-player`).textContent = state.players[index].display_name;
			$(`${side}-player`).style.borderColor = state.players[index].color;
			$(`${side}-score`).textContent = `${state.session_wins[index]} ${state.session_wins[index] === 1 ? "WIN" : "WINS"}`;
			$(`${side}-men`).textContent = `x ${state.counts[index].men}`;
			$(`${side}-kings`).textContent = `x ${state.counts[index].kings}`;
		});
		$("status").textContent = state.status;
		shownState = state;
		renderClocks();
	}
	function clockText(seconds) {
		const total = Math.max(0, Math.ceil(seconds));
		return (total >= 3600 ? Math.floor(total / 3600) + ":" + String(Math.floor(total / 60) % 60).padStart(2, "0") : String(Math.floor(total / 60))) + ":" + String(total % 60).padStart(2, "0");
	}
	function renderClocks() {
		["red", "black"].forEach((side, index) => {
			const clock = $(side + "-clock");
			clock.hidden = !state?.clock_seconds;
			if (clock.hidden) return;
			const elapsed = online && state.clock_running && state.turn === index + 1 ? (performance.now() - receivedAt) / 1000 : 0;
			clock.textContent = clockText(state.remaining[index] - elapsed);
		});
	}
	motion.addEventListener("change", () => {
		if (motion.matches) {
			celebration.clear();
			boardMotion.reset(state?.board || Array(64).fill(0));
			render();
		}
	});
	window.addEventListener("resize", () => {
		if (boardMotion.busy) { boardMotion.reset(state.board); render(); }
	});
	window.addEventListener("gameboardresize", () => {
		if (boardMotion.busy) { boardMotion.reset(state.board); render(); }
	});
	window.addEventListener("pagehide", () => { celebration.clear(); boardMotion.reset(Array(64).fill(0)); });
	$("replay").addEventListener("click", () => send("play_again"));
	setInterval(renderClocks, 100);
	controller.connect();
})();
