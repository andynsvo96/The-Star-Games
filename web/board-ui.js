/* Shared illustrated references and public round summaries. No game authority. */
(() => {
	"use strict";
	const node = (tag, className, text) => {
		const element = document.createElement(tag);
		if (className) element.className = className;
		if (text !== undefined) element.textContent = String(text);
		return element;
	};
	function sheet(parent, heading, className) {
		const dialog = node("dialog", `game-dialog game-scroll-dialog ${className}`);
		const title = node("h2", "dialog-heading", heading);
		const body = node("div", "dialog-body"), actions = node("div", "dialog-actions game-action-row");
		dialog.append(title, body, actions); parent.append(dialog);
		dialog.setAttribute("aria-label", heading);
		return {dialog, title, body, actions};
	}
	class IllustratedGuide {
		constructor(parent, {heading = "How to play", onChange = () => {}} = {}) {
			Object.assign(this, sheet(parent, heading, "game-illustrated-guide"));
			this.onChange = onChange;
			const close = node("button", "game-secondary", "CLOSE"); close.type = "button";
			close.addEventListener("click", () => this.dialog.close()); this.actions.append(close);
			this.dialog.addEventListener("close", () => { this.trigger?.focus({preventScroll:true}); this.onChange(false); });
			this.key = "";
		}
		setItems(items) {
			const key = JSON.stringify(items); if (key === this.key) return;
			this.key = key; this.body.replaceChildren();
			for (const item of items) {
				const section = node("section", "game-guide-section");
				const image = node("img"); image.src = item.image; image.alt = item.description || "";
				section.append(node("h3", "", item.heading), image, node("p", "", item.detail)); this.body.append(section);
			}
		}
		open(trigger) { this.trigger = trigger; if (!this.dialog.open) { this.dialog.showModal(); this.actions.querySelector("button").focus({preventScroll:true}); this.onChange(true); } }
		close() { if (this.dialog.open) this.dialog.close(); }
	}
	class RoundResults {
		constructor(parent, replay, {onChange = () => {}} = {}) {
			Object.assign(this, sheet(parent, "Game results", "game-round-dialog"));
			this.onChange = onChange; this.key = "";
			this.summary = node("p", "game-round-summary"); this.grid = node("div", "game-round-results");
			this.body.append(this.summary, this.grid);
			this.review = node("button", "game-secondary", "VIEW BOARD"); this.review.type = "button";
			this.review.addEventListener("click", () => this.dialog.close());
			this.actions.append(this.review, replay); replay.style.maxWidth = "";
			this.dialog.addEventListener("close", () => this.onChange(false));
		}
		update({key, heading, summary, players}, ready) {
			if (!ready) return;
			if (key === this.key) return;
			this.key = key; this.title.textContent = heading; this.summary.textContent = summary; this.grid.replaceChildren();
			for (const player of players) {
				const card = node("article", "game-round-player"), header = node("header");
				const name = node("strong", "", player.display_name);
				name.style.borderLeft = `3px solid ${player.color}`;
				const crown = node("img"); crown.alt = player.winner ? "Winner" : "";
				if (player.winner) crown.src = "/ui/playful/table-crown.svg"; else crown.style.visibility = "hidden";
				header.append(name, crown); card.append(header);
				const list = node("dl");
				for (const metric of player.metrics) list.append(node("dt", "", metric.label), node("dd", "", metric.value));
				card.append(list); this.grid.append(card);
			}
			this.open();
		}
		open() { if (this.key && !this.dialog.open) { this.dialog.showModal(); queueMicrotask(() => this.onChange(true)); } }
		reset() { this.key = ""; if (this.dialog.open) this.dialog.close(); }
	}
	window.StarGamesIllustratedGuide = IllustratedGuide;
	window.StarGamesRoundResults = RoundResults;
})();
