/* Finite piece movement. Click targets stay fixed; snapshots remain authoritative. */
class ChessBoardMotion {
	constructor(board, buttons, settled) {
		this.board = board; this.buttons = buttons; this.settled = settled;
		this.busy = false; this.animations = []; this.sprites = []; this.ticket = 0;
	}
	static source(piece) {
		return '/game/chess/art/' + (piece > 0 ? 'white' : 'black') + '-' + ['', 'pawn', 'knight', 'bishop', 'rook', 'queen', 'king'][Math.abs(piece)] + '.svg';
	}
	reset(position) {
		this.ticket++;
		this.animations.forEach(a => a.cancel()); this.animations = [];
		this.sprites.forEach(s => s.remove()); this.sprites = []; this.busy = false;
		this.buttons.forEach((button, cell) => {
			button.querySelector('img')?.remove();
			if (position[cell]) {
				const img = document.createElement('img');
				img.src = ChessBoardMotion.source(position[cell]); img.alt = '';
				button.prepend(img);
			}
		});
	}
	play(previous, position, step) {
		this.reset(previous); this.busy = true;
		const ticket = this.ticket;
		const travels = [{from: step.from, to: step.to}];
		if (Number.isInteger(step.rook_from)) travels.push({from: step.rook_from, to: step.rook_to});
		const base = this.board.getBoundingClientRect();
		const promises = travels.map(travel => {
			const start = this.buttons[travel.from].getBoundingClientRect();
			const end = this.buttons[travel.to].getBoundingClientRect();
			this.buttons[travel.from].querySelector('img')?.remove();
			const sprite = document.createElement('img');
			sprite.src = ChessBoardMotion.source(previous[travel.from]); sprite.alt = ''; sprite.className = 'chess-moving';
			sprite.style.cssText = 'left:' + (start.left - base.left - this.board.clientLeft) + 'px;top:' + (start.top - base.top - this.board.clientTop) + 'px;width:' + start.width + 'px;height:' + start.height + 'px';
			this.board.append(sprite); this.sprites.push(sprite);
			const dx = end.left - start.left, dy = end.top - start.top;
			const animation = sprite.animate([{transform: 'translate(0,0)'}, {transform: 'translate(' + dx / 2 + 'px,' + (dy / 2 - start.height * .08) + 'px)'}, {transform: 'translate(' + dx + 'px,' + dy + 'px)'}], {duration: 300, easing: 'ease-in-out', fill: 'forwards'});
			this.animations.push(animation);
			return animation.finished.catch(() => {});
		});
		Promise.all(promises).then(() => {
			if (ticket !== this.ticket) return;
			this.reset(position); this.settled();
		});
	}
}

