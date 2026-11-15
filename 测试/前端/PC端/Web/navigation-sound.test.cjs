const test = require("node:test");
const assert = require("node:assert/strict");
const createNavigationSound = require("../../../../代码/前端/PC端/Web/维修工作台/navigation-sound.js");

class Target {
  listeners = new Map();
  addEventListener(name, handler) {
    if (!this.listeners.has(name)) this.listeners.set(name, new Set());
    this.listeners.get(name).add(handler);
  }
  removeEventListener(name, handler) { this.listeners.get(name)?.delete(handler); }
  emit(name, values = {}) {
    for (const handler of this.listeners.get(name) || []) handler({ isTrusted: true, ...values });
  }
}
function fixture(initial = "on") {
  const doc = new Target(), env = new Target(), toggle = new Target(), media = new Target();
  const nav = [new Target(), new Target()], attributes = {}, label = {}, stored = new Map([["repair-navigation-sound", initial]]);
  const footer = { prepend(node) { node.parentElement = this; } }, actions = { append(node) { node.parentElement = this; } };
  Object.assign(toggle, { parentElement: footer, setAttribute(key, value) { attributes[key] = value; }, querySelector() { return label; } });
  Object.assign(doc, { hidden: false, querySelector(selector) { return { "#navigationSoundToggle": toggle, ".sidebar-bottom": footer, ".topbar-actions": actions }[selector]; }, querySelectorAll() { return nav; } });
  const starts = [], buffers = [], contexts = [];
  let clock = 0, resumeBarrier;
  class Audio {
    state = "suspended"; sampleRate = 48000; currentTime = 2; destination = {};
    constructor() { contexts.push(this); }
    async resume() { if (resumeBarrier) await resumeBarrier; this.state = "running"; }
    async suspend() { this.state = "suspended"; }
    async close() { this.state = "closed"; }
    createBuffer(_, length) { const data = new Float32Array(length); buffers.push(data); return { getChannelData() { return data; } }; }
    createBufferSource() {
      return { playbackRate: {}, connect() {}, disconnect() {}, start(at) { starts.push({ source: this, at }); }, stop() { this.stopped = true; } };
    }
  }
  Object.assign(env, { document: doc, AudioContext: Audio, localStorage: { getItem(key) { return stored.get(key); }, setItem(key, value) { stored.set(key, value); } }, matchMedia() { return media; }, performance: { now() { return clock; } } });
  const controller = createNavigationSound(env);
  const flush = async () => { await new Promise(resolve => setImmediate(resolve)); };
  return { env, doc, nav, toggle, media, footer, actions, label, attributes, stored, starts, buffers, contexts, controller, flush,
    advance(ms) { clock += ms; }, barrier(value) { resumeBarrier = value; }, finish() { starts.forEach(({ source }) => source.onended?.()); } };
}

test("requires a trusted user gesture before scheduling four wood knocks", async () => {
  const f = fixture();
  f.nav[0].emit("pointerenter"); await f.flush();
  f.doc.emit("pointerdown", { isTrusted: false }); await f.flush();
  assert.equal(f.contexts.length, 0);
  f.doc.emit("keydown"); await f.flush();
  f.nav[0].emit("pointerenter"); await f.flush();
  assert.equal(f.starts.length, 4);
  assert.ok(f.starts.every((entry, index) => Math.abs(entry.at - (2.008 + index * .053)) < 1e-8));
  assert.equal(f.buffers.length, 1);
  assert.ok(f.buffers[0].some(sample => sample !== 0));
  assert.ok(f.buffers[0].every(sample => Number.isFinite(sample) && Math.abs(sample) < .3));
  f.controller.destroy();
});

test("does not overlap, flood on rapid entry, or trigger for touch/untrusted entry", async () => {
  const f = fixture(); f.doc.emit("pointerdown"); await f.flush();
  f.nav[0].emit("pointerenter", { pointerType: "touch" });
  f.nav[0].emit("pointerenter", { isTrusted: false }); await f.flush();
  assert.equal(f.starts.length, 0);
  f.nav[0].emit("pointerenter"); f.nav[1].emit("pointerenter"); await f.flush();
  assert.equal(f.starts.length, 4);
  f.advance(600); f.nav[1].emit("pointerenter"); await f.flush();
  assert.equal(f.starts.length, 4);
  f.finish(); f.nav[1].emit("pointerenter"); await f.flush();
  assert.equal(f.starts.length, 8);
  f.finish(); f.advance(200); f.nav[0].emit("pointerenter"); await f.flush();
  assert.equal(f.starts.length, 8);
  f.controller.destroy();
});

test("off preference prevents audio creation and toggle stops an in-flight phrase", async () => {
  const f = fixture("off"); f.doc.emit("pointerdown"); await f.flush();
  assert.equal(f.contexts.length, 0); assert.equal(f.attributes["aria-pressed"], "false");
  f.toggle.emit("click"); await f.flush(); f.nav[0].emit("pointerenter"); await f.flush();
  assert.equal(f.starts.length, 4);
  f.toggle.emit("click"); await f.flush();
  assert.ok(f.starts.every(({ source }) => source.stopped));
  assert.equal(f.stored.get("repair-navigation-sound"), "off");
  assert.equal(f.attributes["aria-label"], "开启导航音效");
  f.advance(1000); f.nav[1].emit("pointerenter"); await f.flush(); assert.equal(f.starts.length, 4);
  f.controller.destroy();
});

test("hiding or leaving cancels playback, including an unfinished resume", async () => {
  const f = fixture(); f.doc.emit("pointerdown"); await f.flush();
  let release; f.barrier(new Promise(resolve => { release = resolve; }));
  f.nav[0].emit("pointerenter"); f.doc.hidden = true; f.doc.emit("visibilitychange"); release(); await f.flush();
  assert.equal(f.starts.length, 0);
  f.barrier(null); f.doc.hidden = false; f.nav[0].emit("pointerenter"); await f.flush();
  assert.equal(f.starts.length, 4); f.env.emit("pagehide"); await f.flush();
  assert.ok(f.starts.every(({ source }) => source.stopped));
  f.controller.destroy();
});

test("keeps the same accessible toggle reachable on narrow layouts and updates its locale", () => {
  const f = fixture(); f.media.matches = true; f.media.emit("change");
  assert.equal(f.toggle.parentElement, f.actions);
  f.env.RepairI18n = { translate(source) { return "translated:" + source; } }; f.doc.emit("repair-locale-change");
  assert.equal(f.label.textContent, "translated:导航音效");
  assert.equal(f.attributes["aria-label"], "translated:关闭导航音效");
  f.media.matches = false; f.media.emit("change"); assert.equal(f.toggle.parentElement, f.footer);
  f.controller.destroy(); assert.equal(f.contexts.length, 0);
});

test("unavailable or rejected Web Audio leaves navigation usable", async () => {
  const f = fixture(); f.controller.destroy();
  f.env.AudioContext = undefined;
  const unsupported = createNavigationSound(f.env); assert.equal(f.toggle.hidden, true); unsupported.destroy();
  f.env.AudioContext = class { async resume() { throw Error("unavailable"); } async close() {} };
  const unavailable = createNavigationSound(f.env);
  f.doc.emit("pointerdown"); await f.flush(); f.nav[0].emit("pointerenter"); await f.flush();
  assert.equal(f.starts.length, 0); unavailable.destroy();
});
