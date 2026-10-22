(() => {
	"use strict";
	const board = document.querySelector('#board');
	const connection = document.querySelector('#connection');
	const status = document.querySelector('#status');
	const replay = document.querySelector('#replay');
	const controls = document.querySelector('#controls');
	const moveButton = document.querySelector('#move');
	const wallButton = document.querySelector('#wall');
	const rotateButton = document.querySelector('#rotate');
	const confirm = document.querySelector('#confirm');
	const celebration = new StarGamesCelebration(board);
	const motion = matchMedia('(prefers-reduced-motion: reduce)');
	let playerId = '', state = null, connected = false, mode = 'move', orientation = 'h', preview = null;
	let localMovement = [], localBusy = false, submittedRevision = -1, reconnecting = true, shownWin = '', animateWin = false;
	const cells = [], anchors = [], pawns = [], goals = [], wallsLayer = document.createElement('div');
	wallsLayer.className = 'quoridor-walls'; board.append(wallsLayer);
	const pct = value => `${value}%`;
	const viewer = () => state ? state.players.findIndex(player => player.id === playerId) + 1 : 0;
	const rotation = () => state?.players.length === 4 ? [0,0,3,2,1][viewer()] : viewer() === 2 ? 2 : 0;
	const rotatePoint = (row, col, maximum) => {
		for (let step = 0; step < rotation(); step++) [row,col] = [col,maximum-row];
		return {row,col};
	};
	const cellPoint = cell => {
		const visual = rotatePoint(Math.floor(cell / 9), cell % 9, 8);
		return {left: 5.5 + visual.col * 89 / 9 + .296667, top: 5.5 + visual.row * 89 / 9 + .296667};
	};
	const visualOrientation = value => rotation() % 2 ? (value === 'h' ? 'v' : 'h') : value;
	const reduced = () => motion.matches || state?.reduced_motion;
	const playable = () => connected && state && viewer() > 0 && viewer() === state.turn && !state.paused && !state.outcome && !state.animating && !localBusy && submittedRevision !== state.revision;
	const fitsPreview = wall => state?.legal_walls.some(option => option.row === wall.row && option.col === wall.col && option.orientation === wall.orientation);
	function styleRect(element, left, top, width, height) {
		Object.assign(element.style, {left:pct(left),top:pct(top),width:pct(width),height:pct(height)});
	}
	function wallRect(wall, element) {
		const {row,col} = rotatePoint(wall.row,wall.col,7), facing = visualOrientation(wall.orientation);
		const pitch = 89 / 9, gap = pitch * .06, thickness = Math.max(pitch * .30, 600 / Math.max(1,board.clientWidth)), x = 5.5 + (col + 1) * pitch, y = 5.5 + (row + 1) * pitch;
		styleRect(element, x - (facing === 'h' ? pitch - gap / 2 : thickness / 2), y - (facing === 'v' ? pitch - gap / 2 : thickness / 2), facing === 'h' ? pitch * 2 - gap : thickness, facing === 'v' ? pitch * 2 - gap : thickness);
	}
	function stopMovement() {
		localMovement.forEach(animation => animation.cancel()); localMovement = []; localBusy = false;
	}
	function send(input) {
		if (!playable()) return;
		controller.send({...input,revision:state.revision}); submittedRevision = state.revision;
		preview = null; mode = 'move'; render();
	}
	for (let cell = 0; cell < 81; cell++) {
		const button = document.createElement('button'); button.type = 'button'; button.className = 'quoridor-cell';
		button.dataset.cell = cell; button.setAttribute('aria-label', `Square ${String.fromCharCode(65 + cell % 9)}${9 - Math.floor(cell / 9)}`);
		button.style.setProperty('--tile-tone',String(.98 + (cell*17 + Math.floor(cell/9)*3)%7*.006));
		button.addEventListener('click', () => { if (mode === 'move' && state?.legal_moves.includes(cell)) send({action:'move',to:cell}); });
		board.append(button); cells.push(button);
	}
	for (let row = 0; row < 8; row++) for (let col = 0; col < 8; col++) {
		const button = document.createElement('button'); button.type = 'button'; button.className = 'quoridor-anchor';
		button.dataset.row = row; button.dataset.col = col;
		button.addEventListener('click', () => {
			const candidate = {row,col,orientation};
			if (!playable() || mode !== 'wall' || !fitsPreview(candidate)) return;
			preview = candidate; render();
		});
		board.append(button); anchors.push(button);
	}
	function fitPawns(count) {
		while (pawns.length > count) pawns.pop().remove();
		while (pawns.length < count) {
			const pawn = document.createElement('span'); pawn.className = 'quoridor-pawn'; pawn.setAttribute('aria-hidden','true');
			board.append(pawn); pawns.push(pawn);
		}
	}
	for (const top of [5.1,94.1]) for (let col=0; col<9; col++) { const goal = document.createElement('span'); goal.className = 'quoridor-goal'; styleRect(goal,5.5+col*89/9+.296667,top,9.295556,.8); goal.setAttribute('aria-hidden','true'); board.append(goal); }
	for (const left of [5.1,94.1]) for (let row=0; row<9; row++) { const goal = document.createElement('span'); goal.className = 'quoridor-goal'; styleRect(goal,left,5.5+row*89/9+.296667,.8,9.295556); goal.setAttribute('aria-hidden','true'); goal.hidden = true; board.append(goal); goals.push(goal); }
	moveButton.addEventListener('click', () => { if (playable()) { mode = 'move'; preview = null; render(); } });
	wallButton.addEventListener('click', () => { if (playable() && state.remaining[viewer() - 1] > 0 && state.legal_walls.length) { mode = 'wall'; preview = null; render(); } });
	rotateButton.addEventListener('click', () => {
		if (!playable() || mode !== 'wall') return;
		orientation = orientation === 'h' ? 'v' : 'h';
		if (preview) { preview = {...preview,orientation}; if (!fitsPreview(preview)) preview = null; }
		render();
	});
	confirm.addEventListener('click', () => { if (preview && fitsPreview(preview)) send({action:'wall',...preview}); });
	replay.addEventListener('click', () => {
		if (!connected || !viewer() || !state?.outcome || state.paused || state.animating || localBusy || submittedRevision === state.revision) return;
		controller.send({action:'play_again',revision:state.revision}); submittedRevision = state.revision; render();
	});
	function render() {
		if (!state) { cells.forEach(button => button.disabled = true); anchors.forEach(button => button.hidden = true); [moveButton,wallButton,rotateButton,confirm,replay].forEach(button => button.disabled = true); return; }
		const canPlay = playable(), side = viewer();
		for (let cell = 0; cell < 81; cell++) {
			const point = cellPoint(cell); styleRect(cells[cell],point.left,point.top,9.295556,9.295556);
			cells[cell].disabled = !canPlay || mode !== 'move' || !state.legal_moves.includes(cell);
			cells[cell].classList.toggle('destination', canPlay && mode === 'move' && state.legal_moves.includes(cell));
			cells[cell].classList.toggle('winner', Boolean(state.outcome && state.pawns[state.outcome - 1] === cell));
		}
		anchors.forEach(button => {
			const row = Number(button.dataset.row), col = Number(button.dataset.col), visual = rotatePoint(row,col,7);
			styleRect(button,5.5+(visual.col+.5)*89/9,5.5+(visual.row+.5)*89/9,89/9,89/9);
			button.hidden = mode !== 'wall'; button.disabled = !canPlay || !fitsPreview({row,col,orientation});
			button.classList.toggle('selected', Boolean(preview && preview.row === row && preview.col === col));
			button.setAttribute('aria-label', `Preview ${visualOrientation(orientation) === 'h' ? 'horizontal' : 'vertical'} wall at ${String.fromCharCode(65+col)}${8-row}`);
		});
		wallsLayer.replaceChildren();
		for (const wall of [...state.walls, ...(preview && canPlay ? [preview] : [])]) {
			const element = document.createElement('span'); element.className = 'quoridor-wall' + (wall === preview ? ' preview' : '');
			element.setAttribute('aria-hidden','true'); wallRect(wall,element); wallsLayer.append(element);
		}
		state.pawns.forEach((cell,index) => {
			const point = cellPoint(cell); styleRect(pawns[index],point.left,point.top,9.295556,9.295556);
			pawns[index].style.setProperty('--pawn-color',state.players[index].color);
		});
		goals.forEach(goal => goal.hidden = state.players.length !== 4);
		document.querySelectorAll('.game-score-stack').forEach(stack => stack.classList.toggle('game-score-dense', state.players.length === 4));
		for (let index = 0; index < 4; index++) {
			const prefix = ['one','two','three','four'][index], player = state.players[index], name = document.querySelector(`#${prefix}-player`);
			name.closest('aside').hidden = !player;
			if (!player) continue;
			name.textContent = player.display_name;
			name.closest('aside').style.setProperty('--score-color',player.color);
			name.classList.toggle('is-active-player', !state.paused && !state.outcome && state.turn === index + 1);
			name.classList.toggle('game-turn-glow', canPlay && side === index + 1);
			const wins = state.session_wins[index]; document.querySelector(`#${prefix}-score`).textContent = `${wins} ${wins === 1 ? 'WIN' : 'WINS'}`;
			document.querySelector(`#${prefix}-walls`).textContent = `${state.remaining[index]} ${state.remaining[index] === 1 ? 'WALL' : 'WALLS'}`;
		}
		const facing = visualOrientation(orientation);
		status.textContent = !side ? `Watching: ${state.status}` : mode === 'wall' && canPlay ? (preview ? `${facing === 'h' ? 'Horizontal' : 'Vertical'} wall ready to place` : `Choose a ${facing === 'h' ? 'horizontal' : 'vertical'} wall junction`) : canPlay ? 'Your turn' : state.status;
		controls.hidden = Boolean(state.outcome) || !side;
		moveButton.disabled = !canPlay; wallButton.disabled = !canPlay || state.remaining[side - 1] <= 0 || !state.legal_walls.length;
		moveButton.classList.toggle('game-primary',mode === 'move'); wallButton.classList.toggle('game-primary',mode === 'wall');
		moveButton.setAttribute('aria-pressed',String(mode === 'move')); wallButton.setAttribute('aria-pressed',String(mode === 'wall'));
		rotateButton.disabled = !canPlay || mode !== 'wall'; rotateButton.setAttribute('aria-label',`Rotate wall to ${facing === 'h' ? 'vertical' : 'horizontal'}`);
		confirm.hidden = mode !== 'wall' || !preview; confirm.disabled = !canPlay || !preview;
		wallButton.hidden = !confirm.hidden;
		replay.hidden = !state.outcome || !side; replay.disabled = !connected || !side || state.paused || state.animating || localBusy || submittedRevision === state.revision;
		const winKey = `${state.round_id}:${state.outcome}`;
		if (state.outcome && !state.animating && !localBusy && shownWin !== winKey) { shownWin = winKey; celebration.show([], 'GOAL REACHED!', state.players[state.outcome-1].color, animateWin && !reduced()); }
	}
	const controller = new StarGamesController('quoridor', {
		connected: player => { connected = true; reconnecting = true; submittedRevision = -1; playerId = player.id; connection.textContent = `Connected as ${player.display_name}`; controller.send({action:'sync'}); },
		disconnected: () => { connected = false; reconnecting = true; preview = null; mode = 'move'; stopMovement(); celebration.clear(); connection.textContent = 'Reconnecting...'; render(); },
		message: payload => {
			if (!Array.isArray(payload.pawns) || ![2,4].includes(payload.pawns.length) || !Array.isArray(payload.players) || payload.players.length !== payload.pawns.length) return;
			const previous = state, newRound = previous?.round_id !== payload.round_id;
			if (newRound) orientation = 'h';
			submittedRevision = -1;
			if (newRound || previous?.outcome !== payload.outcome) animateWin = !reconnecting && !newRound && Boolean(payload.outcome);
			if (reconnecting || newRound || payload.paused || payload.reduced_motion) stopMovement();
			if (newRound || previous?.revision !== payload.revision || payload.paused) { preview = null; mode = 'move'; submittedRevision = -1; }
			const previousSeat = viewer(); state = payload;
			fitPawns(state.pawns.length);
			document.body.classList.toggle('has-reduced-motion', Boolean(payload.reduced_motion));
			if (newRound || !state.outcome) { celebration.clear(); shownWin = ''; }
			const event = payload.last_action;
			const moving = !reconnecting && !newRound && !payload.paused && !reduced() && previousSeat === viewer() && event?.action === 'move' && previous.pawns[event.side-1] !== payload.pawns[event.side-1];
			if (moving) {
				stopMovement(); localBusy = true;
				const from = cellPoint(event.from), to = cellPoint(event.to), pixels = board.getBoundingClientRect().width;
				const animation = pawns[event.side-1].animate([{transform:`translate(${(from.left-to.left)*pixels/100}px,${(from.top-to.top)*pixels/100}px)`},{transform:'translate(0,0)'}],{duration:240,easing:'ease-in-out'});
				localMovement = [animation]; animation.finished.then(() => { if (localMovement.includes(animation)) { localMovement = []; localBusy = false; render(); } }).catch(() => {});
			}
			render(); reconnecting = false;
		},
		error: error => { connection.textContent = error.message || 'Connection error'; }
	});
	motion.addEventListener('change', () => { if (motion.matches) { stopMovement(); render(); } });
	window.addEventListener('gameboardresize', () => { stopMovement(); render(); });
	window.addEventListener('pagehide', () => { connected = false; preview = null; stopMovement(); celebration.clear(); });
	render(); controller.connect();
})();
