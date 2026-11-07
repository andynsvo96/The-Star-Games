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
	class MovePreview {
		constructor(parent,{rectFor,createVisual}) { Object.assign(this,{parent,rectFor,createVisual,key:"",visual:null,frame:0,elapsed:0,paused:false}); }
		update(record,{paused=false,reduced=false,restore=false}={}) {
			this.paused=paused;
			if(!record || !Number.isInteger(record.to) || record.to<0) {this.clear();return;}
			const key=record.key??JSON.stringify([record.from,record.to,record.path]);
			if(key!==this.key) {
				this.clear();this.key=key;this.route=record.path?.length>1?record.path:[record.from,record.to];
				this.duration=Math.min(1500,Math.max(350,(this.route.length-1)*320));this.elapsed=reduced||restore?this.duration:0;
				this.visual=this.createVisual(record);this.visual.classList.add('game-guide-ghost');this.visual.setAttribute('aria-hidden','true');this.parent.append(this.visual);
			}
			if(reduced||restore)this.elapsed=this.duration;
			this.last=performance.now();this.refresh();this.schedule();
		}
		schedule(){cancelAnimationFrame(this.frame);if(this.visual&&!this.paused&&this.elapsed<this.duration)this.frame=requestAnimationFrame(now=>{this.elapsed=Math.min(this.duration,this.elapsed+now-this.last);this.last=now;this.refresh();this.schedule();});}
		refresh(){
			if(!this.visual)return;
			const p=Math.min(1,this.elapsed/this.duration)*(this.route.length-1),index=Math.min(Math.floor(p),this.route.length-2),t=p-index,ease=t*t*(3-2*t);
			const a=this.rectFor(this.route[index]),b=this.rectFor(this.route[index+1]),parent=this.parent.getBoundingClientRect();
			const width=a.width+(b.width-a.width)*t,height=a.height+(b.height-a.height)*t;
			Object.assign(this.visual.style,{left:(a.x+a.width/2+(b.x+b.width/2-a.x-a.width/2)*ease-parent.left-this.parent.clientLeft-width/2)+'px',top:(a.y+a.height/2+(b.y+b.height/2-a.y-a.height/2)*ease-parent.top-this.parent.clientTop-height/2-Math.sin(t*Math.PI)*height*.15)+'px',width:width+'px',height:height+'px'});
		}
		clear(){cancelAnimationFrame(this.frame);this.visual?.remove();this.visual=null;this.key="";}
	}
	window.StarGamesMovePreview=MovePreview;
	// Taps and keyboard clicks keep their normal handlers. Only a deliberate drag
	// suppresses its follow-up click; authority always stays with onDrop's caller.
	class PieceDrag {
		constructor(surface, options) {
			this.surface = surface; this.options = options; this.gesture = null; this.suppressUntil = 0;
			surface.addEventListener("dragstart", event => event.preventDefault());
			surface.addEventListener("pointerdown", event => {
				if (this.gesture && this.gesture.id !== event.pointerId) this.cancel();
				if (!event.isPrimary || event.button !== 0 || this.gesture) return;
				const from = options.hitTest(event.clientX, event.clientY);
				if (from < 0 || !options.canStart(from)) return;
				this.gesture = {id:event.pointerId, from, x:event.clientX, y:event.clientY, revision:options.revision(), dragging:false};
			});
			window.addEventListener("pointermove", event => {
				const g = this.gesture; if (!g || g.id !== event.pointerId) return;
				if (!this.valid()) { this.cancel(); return; }
				if (!g.dragging && Math.hypot(event.clientX-g.x, event.clientY-g.y) >= 8) {
					g.dragging = true; this.suppressUntil = performance.now()+400;
					g.preview = options.createPreview(g.from); g.preview.classList.add("game-piece-drag-preview");
					surface.append(g.preview); options.onStart?.(g.from);
					try { surface.setPointerCapture(g.id); } catch {}
				}
				if (g.dragging) {
					g.preview.style.left = event.clientX+"px"; g.preview.style.top = event.clientY+"px";
					event.preventDefault();
				}
			}, {passive:false});
			window.addEventListener("pointerup", event => {
				const g = this.gesture; if (!g || g.id !== event.pointerId) return;
				const to = options.hitTest(event.clientX, event.clientY);
				const commit = g.dragging && this.valid() && to >= 0 && to !== g.from;
				this.clear(); if (commit) options.onDrop(g.from, to);
			});
			window.addEventListener("pointercancel", event => { if (this.gesture?.id === event.pointerId) this.cancel(); });
			surface.addEventListener("lostpointercapture", event => { if (event.target === surface && event.pointerId === this.gesture?.id) this.cancel(); });
			surface.addEventListener("click", event => {
				if (event.detail && performance.now() < this.suppressUntil) { event.preventDefault(); event.stopImmediatePropagation(); }
			}, true);
			for (const name of ["blur", "resize", "pagehide"]) window.addEventListener(name, () => this.cancel());
			new ResizeObserver(() => this.cancel()).observe(surface);
		}
		valid() { const g=this.gesture; return !!g && g.revision===this.options.revision() && this.options.canStart(g.from); }
		blocksTap() { return !!this.gesture?.dragging || performance.now()<this.suppressUntil; }
		validate() { if (this.gesture && !this.valid()) this.cancel(); }
		cancel() { if (this.gesture) this.clear(); }
		clear() {
			const g=this.gesture; this.gesture=null; if(!g) return;
			if(g.dragging) { this.suppressUntil=performance.now()+400; g.preview.remove(); this.options.onEnd?.(g.from); }
			try { if(this.surface.hasPointerCapture(g.id)) this.surface.releasePointerCapture(g.id); } catch {}
		}
	}
	window.StarGamesPieceDrag = PieceDrag;
})();
