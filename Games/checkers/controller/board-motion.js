/* Module-owned board movement. Authoritative indexes and click targets stay fixed. */
class CheckersBoardMotion {
	constructor(board, buttons, landed, settled) {
		this.board = board;
		this.buttons = buttons;
		this.landed = landed;
		this.settled = settled;
		this.queue = [];
		this.active = null;
		this.token = 0;
	}
	get busy() { return !!this.active || !!this.queue.length; }
	image(piece) {
		const image = document.createElement("img");
		image.src = `/game/checkers/art/${["", "red", "black", "red-king", "black-king"][piece]}.svg`;
		image.alt = "";
		return image;
	}
	paint(board) {
		this.buttons.forEach((button, cell) => button.replaceChildren(...(board[cell] ? [this.image(board[cell])] : [])));
	}
	reset(board) {
		this.token++;
		this.active?.animation.cancel();
		this.active?.image.remove();
		this.active = null;
		this.queue = [];
		this.paint(board);
	}
	enqueue(board, step, piece, outcome) {
		this.queue.push({board: [...board], step: {...step}, piece, outcome});
		if (!this.active) this.startNext();
	}
	startNext() {
		if (!this.queue.length) { this.settled(); return; }
		const move = this.queue.shift(), {step} = move;
		const source = this.buttons[step.from].getBoundingClientRect();
		const target = this.buttons[step.to].getBoundingClientRect();
		const frame = this.board.getBoundingClientRect();
		const padding = parseFloat(getComputedStyle(this.buttons[step.to]).paddingLeft);
		const image = this.image(move.piece);
		image.className = "checker-moving";
		image.style.left = `${source.left - frame.left - this.board.clientLeft + padding}px`;
		image.style.top = `${source.top - frame.top - this.board.clientTop + padding}px`;
		image.style.width = `${target.width - padding * 2}px`;
		image.style.height = `${target.height - padding * 2}px`;
		this.buttons[step.from].replaceChildren();
		this.board.append(image);
		const dx = target.left - source.left, dy = target.top - source.top;
		const lift = target.height * (step.capture >= 0 ? .28 : .05);
		const animation = image.animate([
			{transform: "translate(0, 0)"},
			{transform: `translate(${dx / 2}px, ${dy / 2 - lift}px)`, offset: .5},
			{transform: `translate(${dx}px, ${dy}px)`}
		], {duration: step.capture >= 0 ? 400 : 320, easing: "cubic-bezier(.37, 0, .63, 1)", fill: "forwards"});
		const token = this.token;
		this.active = {image, animation};
		animation.finished.then(() => {
			if (token !== this.token) return;
			image.remove();
			this.paint(move.board);
			this.active = null;
			this.landed(step, move.outcome);
			this.startNext();
		}).catch(() => {}); // Reset, reconnect, resize and exit intentionally cancel.
	}
}
