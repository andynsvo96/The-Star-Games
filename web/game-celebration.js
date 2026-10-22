/* Shared input-transparent victory overlay. All geometry is normalized 0..1. */
window.StarGamesCelebration = class {
  constructor(board) {
    this.board = board;
    this.layer = document.createElement("div");
    this.layer.className = "game-celebration";
    this.layer.setAttribute("aria-hidden", "true");
    board.append(this.layer);
  }
  clear() { this.layer.replaceChildren(); this.layer.classList.remove("is-celebrating"); }
  show(segments, headline, color, animate) {
    this.clear();
    this.layer.style.setProperty("--winner-color", color);
    this.layer.classList.toggle("is-celebrating", animate);
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 100 100");
    svg.setAttribute("preserveAspectRatio", "none");
    for (const [start, end] of segments) {
      const line = document.createElementNS(svg.namespaceURI, "line");
      for (const [key, value] of Object.entries({x1:start[0]*100, y1:start[1]*100, x2:end[0]*100, y2:end[1]*100, pathLength:1})) line.setAttribute(key, value);
      svg.append(line);
    }
    this.layer.append(svg);
    if (!animate) return;
    const ring = document.createElement("i");
    ring.className = "game-victory-ring";
    this.layer.append(ring);
    for (let index = 0; index < 64; index++) {
      const spark = document.createElement("i");
      spark.className = `game-confetti${index % 3 === 0 ? " is-star" : ""}`;
      const angle = -Math.PI + index / 63 * Math.PI;
      const speed = .35 + index % 7 * .075;
      const width = this.board.clientWidth;
      spark.style.setProperty("--dx", `${Math.cos(angle) * speed * width * 2.2}px`);
      spark.style.setProperty("--dy", `${Math.sin(angle) * speed * width * 2.2}px`);
      spark.style.setProperty("--fall", `${width * 1.35}px`);
      spark.style.setProperty("--spin", `${index * 73}deg`);
      spark.style.background = ["#ffdb36", color, "#fff", "#00b9ef"][index % 4];
      this.layer.append(spark);
    }
    const banner = document.createElement("div");
    banner.className = "game-victory-banner";
    const title = document.createElement("strong");
    title.textContent = headline;
    banner.append(title);
    this.layer.append(banner);
  }
};
