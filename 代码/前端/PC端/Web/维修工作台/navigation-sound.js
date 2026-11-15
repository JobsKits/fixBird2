// Created by Jobs. 导航音效只保存开关偏好，音色在本机合成。
((root, factory) => {
  if (typeof module === "object" && module.exports) module.exports = factory;
  else factory(root);
})(typeof window === "object" ? window : globalThis, function createNavigationSound(env) {
  const doc = env.document, toggle = doc.querySelector("#navigationSoundToggle");
  const Audio = env.AudioContext || env.webkitAudioContext;
  if (!toggle || !Audio) {
    if (toggle) toggle.hidden = true;
    return { destroy() {} };
  }
  const preference = "repair-navigation-sound", sources = new Set(), listeners = [];
  const compact = env.matchMedia("(max-width: 900px)");
  const footer = doc.querySelector(".sidebar-bottom"), actions = doc.querySelector(".topbar-actions");
  let enabled = true, context, buffer, unlocked = false, resuming = false;
  let generation = 0, lastStarted = -Infinity;
  try { enabled = env.localStorage.getItem(preference) !== "off"; } catch (_) {}
  const ui = source => env.RepairI18n?.translate(source) || source;
  function on(target, name, handler, options) {
    target.addEventListener(name, handler, options);
    listeners.push(() => target.removeEventListener(name, handler, options));
  }
  function render() {
    toggle.setAttribute("aria-pressed", String(enabled));
    toggle.setAttribute("aria-label", ui(enabled ? "关闭导航音效" : "开启导航音效"));
    toggle.title = ui(enabled ? "关闭导航音效" : "开启导航音效") + " · " + ui("首次点击页面后可播放导航音效。");
    toggle.querySelector("span").textContent = ui("导航音效");
  }
  function placeToggle() {
    const parent = compact.matches ? actions : footer;
    if (parent && toggle.parentElement !== parent) {
      if (compact.matches) parent.append(toggle);
      else parent.prepend(toggle);
    }
  }
  function stop() {
    generation++;
    for (const source of sources) {
      source.onended = null;
      try { source.stop(); } catch (_) {}
      source.disconnect();
    }
    sources.clear();
    if (context?.state === "running") context.suspend().catch(() => {});
  }
  function woodBuffer() {
    const value = context.createBuffer(1, Math.ceil(context.sampleRate * .042), context.sampleRate);
    const samples = value.getChannelData(0);
    // 衰减共振加短促撞击，避免持续音与尖锐电子提示音。
    for (let i = 0; i < samples.length; i++) {
      const t = i / context.sampleRate, attack = Math.min(1, t / .0006);
      const resonance = Math.sin(2 * Math.PI * 720 * t) * Math.exp(-t * 140)
        + .48 * Math.sin(2 * Math.PI * 1390 * t) * Math.exp(-t * 205)
        + .2 * Math.sin(2 * Math.PI * 2340 * t) * Math.exp(-t * 310);
      const impact = (Math.random() * 2 - 1) * .32 * Math.exp(-t * 950);
      samples[i] = (resonance + impact) * attack * .13;
    }
    return value;
  }
  async function unlock(event) {
    if (!event.isTrusted || event.ctrlKey || event.metaKey || event.altKey || !enabled || doc.hidden) return;
    try {
      context ||= new Audio();
      await context.resume();
      unlocked = context.state === "running";
    } catch (_) { unlocked = false; }
  }
  async function play(event) {
    const instant = env.performance.now();
    if (!event.isTrusted || event.pointerType === "touch" || !enabled || !unlocked || doc.hidden
      || resuming || sources.size || instant - lastStarted < 500) return;
    const mark = generation;
    resuming = true;
    try {
      await context.resume();
      if (mark !== generation || !enabled || doc.hidden || context.state !== "running") return;
      buffer ||= woodBuffer();
      lastStarted = env.performance.now();
      const start = context.currentTime + .008;
      for (const [index, rate] of [1, .98, 1.03, .96].entries()) {
        const source = context.createBufferSource();
        source.buffer = buffer;
        source.playbackRate.value = rate;
        source.connect(context.destination);
        source.onended = () => { sources.delete(source); source.disconnect(); };
        sources.add(source);
        source.start(start + index * .053);
      }
    } catch (_) { stop(); }
    finally { resuming = false; }
  }
  on(doc, "pointerdown", unlock, { capture: true, passive: true });
  on(doc, "keydown", unlock, { capture: true });
  for (const item of doc.querySelectorAll(".sidebar nav .nav-item")) on(item, "pointerenter", play, { passive: true });
  on(toggle, "click", event => {
    enabled = !enabled;
    try { env.localStorage.setItem(preference, enabled ? "on" : "off"); } catch (_) {}
    if (!enabled) stop();
    else unlock(event);
    render();
  });
  on(doc, "visibilitychange", () => { if (doc.hidden) stop(); });
  on(env, "pagehide", stop);
  on(doc, "repair-locale-change", render);
  on(compact, "change", placeToggle);
  placeToggle();
  render();
  return {
    destroy() {
      stop();
      for (const remove of listeners) remove();
      context?.close().catch(() => {});
    }
  };
});
