(() => {
  "use strict";

  /* ================= constants ================= */
  const MAX_DESK = 5;
  const AREAS = ["Work", "Study", "Health", "Money", "Home", "People", "Self"];
  const TAPE = { Work: "#7fa8f5", Study: "#b9a2f0", Health: "#7fd6a2", Money: "#f5d36a", Home: "#f6ae72", People: "#f5a3c4", Self: "#b8bcc2" };
  const DOCS = {
    tasks: () => ({ items: [] }),
    habits: () => ({ items: [] }),
    bills: () => ({ items: [], currency: "₹" }),
    review: () => ({ lastDone: "", checks: {}, outcomes: ["", "", ""] }),
    day: () => ({ date: "", plan: "", focus: 0 }),
  };
  const LS = "clear-desk-v1";
  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const fine = matchMedia("(pointer: fine)").matches;

  const LAYOUTS = {
    wide: {
      w: 1600, h: 1090, deskH: 1000,
      calendar: { x: 60, y: 58, w: 190, h: 226, r: -5 },
      plant: { x: 1420, y: 26, w: 160, h: 160, r: 0 },
      pad: { x: 448, y: 72, w: 160, h: 160, r: 7 },
      tray: { x: 640, y: 44, w: 530, h: 200, r: -1 },
      envs: [{ ex: 14, ey: 22, er: -3 }, { ex: 146, ey: 28, er: 2 }, { ex: 268, ey: 20, er: -1.5 }],
      legal: { x: 58, y: 316, w: 340, h: 480, r: 2 },
      notebook: { x: 84, y: 748, w: 330, h: 236, r: -6 },
      phone: { x: 1188, y: 66, w: 250, h: 512, r: 5 },
      habits: { x: 1212, y: 626, w: 330, h: 232, r: -4 },
      mug: { x: 968, y: 792, w: 150, h: 150, r: 0 },
      stain: { x: 872, y: 812, w: 156 },
      airpods: { x: 1468, y: 296, w: 96, h: 120, r: 16 },
      bin: { x: 1396, y: 846, w: 180, h: 180, r: 0 },
      drawer: { x: 640, y: 1000, w: 330 },
      slots: [{ x: 466, y: 300, r: -2.5 }, { x: 702, y: 288, r: 1.8 }, { x: 940, y: 306, r: -1.2 }, { x: 574, y: 540, r: 2.4 }, { x: 814, y: 530, r: -1.8 }],
      slotSize: 208,
      cleared: { x: 466, y: 420, w: 690 },
      penRest: { px: 104, py: 690, pr: -38 },
    },
    tall: {
      w: 800, h: 3170, deskH: 3080,
      calendar: { x: 40, y: 50, w: 176, h: 210, r: -5 },
      pad: { x: 268, y: 72, w: 156, h: 156, r: 6 },
      plant: { x: 590, y: 30, w: 180, h: 180, r: 0 },
      tray: { x: 36, y: 300, w: 728, h: 220, r: -1 },
      envs: [{ ex: 18, ey: 30, er: -4 }, { ex: 240, ey: 24, er: 2 }, { ex: 462, ey: 34, er: -1 }],
      slots: [{ x: 46, y: 600, r: -2.5 }, { x: 440, y: 612, r: 2 }, { x: 40, y: 966, r: 1.6 }, { x: 452, y: 976, r: -2 }, { x: 250, y: 1334, r: 1 }],
      slotSize: 304,
      cleared: { x: 60, y: 850, w: 680 },
      airpods: { x: 640, y: 1380, w: 100, h: 124, r: 16 },
      phone: { x: 40, y: 1730, w: 320, h: 652, r: 4 },
      habits: { x: 404, y: 1760, w: 368, h: 270, r: -3 },
      mug: { x: 470, y: 2110, w: 180, h: 180, r: 0 },
      stain: { x: 404, y: 2160, w: 186 },
      legal: { x: 40, y: 2470, w: 440, h: 560, r: 2 },
      notebook: { x: 524, y: 2400, w: 240, h: 320, r: -3 },
      bin: { x: 540, y: 2800, w: 200, h: 200, r: 0 },
      drawer: { x: 236, y: 3080, w: 330 },
      penRest: { px: 96, py: 2950, pr: -40 },
    },
  };

  /* ================= dates ================= */
  const pad = (n) => String(n).padStart(2, "0");
  const keyOf = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  const fromKey = (k) => { const [y, m, d] = k.split("-").map(Number); return new Date(y, m - 1, d); };
  const today = () => { const d = new Date(); d.setHours(0, 0, 0, 0); return d; };
  const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
  const daysBetween = (a, b) => Math.round((b - a) / 86400000);
  const tk = () => keyOf(today());
  const DOW = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  const hash = (s) => { let h = 7; for (const c of String(s)) h = (h * 31 + c.charCodeAt(0)) | 0; return Math.abs(h); };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const rand = (a, b) => a + Math.random() * (b - a);

  function parseQuick(text, base) {
    let area = "", due = "";
    const words = [];
    for (const w of text.trim().split(/\s+/)) {
      const lw = w.toLowerCase();
      if (lw.startsWith("#") && lw.length > 1) {
        const hit = AREAS.find((a) => a.toLowerCase().startsWith(lw.slice(1)));
        if (hit) { area = hit; continue; }
      }
      if (lw.startsWith("!") && lw.length > 1) {
        const v = lw.slice(1);
        let d = null;
        if (v === "today" || v === "tod") d = base;
        else if (v === "tomorrow" || v === "tmr" || v === "tom") d = addDays(base, 1);
        else if (/^\+\d{1,3}$/.test(v)) d = addDays(base, Number(v.slice(1)));
        else if (/^\d{4}-\d{2}-\d{2}$/.test(v)) d = fromKey(v);
        else { const i = DOW.findIndex((x) => v.startsWith(x)); if (i >= 0) d = addDays(base, (i - base.getDay() + 7) % 7); }
        if (d && !isNaN(d)) { due = keyOf(d); continue; }
      }
      words.push(w);
    }
    return { title: words.join(" "), area, due };
  }
  function dueInfo(due) {
    if (!due) return null;
    const n = daysBetween(today(), fromKey(due));
    if (n < 0) return { text: `${-n}d late`, cls: "bad" };
    if (n === 0) return { text: "today", cls: "warn" };
    if (n === 1) return { text: "tomorrow", cls: "" };
    if (n < 7) return { text: fromKey(due).toLocaleDateString(undefined, { weekday: "short" }), cls: "" };
    return { text: fromKey(due).toLocaleDateString(undefined, { month: "short", day: "numeric" }), cls: "" };
  }

  /* ================= state + storage ================= */
  const S = {};
  for (const k of Object.keys(DOCS)) S[k] = DOCS[k]();
  const lsGet = (k) => { try { return localStorage.getItem(k); } catch (e) { return null; } };
  const lsSet = (k, v) => { try { localStorage.setItem(k, v); } catch (e) {} };
  try {
    const cached = JSON.parse(lsGet(LS));
    if (cached) for (const k of Object.keys(DOCS)) if (cached[k]) S[k] = Object.assign(DOCS[k](), cached[k]);
  } catch (e) {}
  function normalize() { S.tasks.items.forEach((t) => { if (t.onDesk === undefined) t.onDesk = !t.done && t.top === tk(); }); }
  normalize();

  const store = { mode: "local", refs: {}, dirty: {}, inflight: {}, again: {}, timers: {}, retried: {}, readOnly: false };
  const $ = (id) => document.getElementById(id);
  const setSync = (t) => { $("sync").textContent = t; };
  const banner = (t) => { $("banner").textContent = t; $("banner").hidden = !t; };
  function save(name) {
    lsSet(LS, JSON.stringify(S));
    if (store.mode !== "db" || store.readOnly) return;
    store.dirty[name] = true;
    setSync("Saving…");
    clearTimeout(store.timers[name]);
    store.timers[name] = setTimeout(() => flush(name), 400);
  }
  async function flush(name) {
    if (store.inflight[name]) { store.again[name] = true; return; }
    store.inflight[name] = true; store.dirty[name] = false;
    try {
      await store.refs[name].set(JSON.parse(JSON.stringify(S[name])));
      store.retried[name] = false;
      setSync("Saved");
    } catch (e) {
      const code = e && e.code;
      if (code === "unavailable" && !store.retried[name]) { store.retried[name] = true; store.dirty[name] = true; setTimeout(() => flush(name), 1000 + Math.random() * 1500); }
      else if (code === "invalid_argument") { store.readOnly = true; banner("You can look at this desk but not change it. Changes stay in this browser only."); setSync("Read-only"); }
      else if (code === "quota_exceeded") banner("Storage is full. Delete some finished tasks or old bills, then try again.");
      else { banner("Couldn’t save to your account just now. Your changes are kept in this browser; reload to try again."); setSync("Not saved"); }
    }
    store.inflight[name] = false;
    if (store.again[name] || store.dirty[name]) { store.again[name] = false; if (!store.readOnly) flush(name); }
  }
  async function connectStore() {
    if (!window.claude || !window.claude.use) { setSync("Saved in this browser"); return; }
    const [db, user] = await Promise.all([claude.use("db"), claude.use("user")]);
    const id = user ? await user.id() : null;
    if (!db || !id) { setSync("Saved in this browser"); return; }
    store.mode = "db";
    const col = db.collection("data/users/" + id);
    for (const name of Object.keys(DOCS)) {
      const ref = col.doc("desk-" + name);
      store.refs[name] = ref;
      ref.onSnapshot((snap) => {
        if (snap.metadata.hasPendingWrites || store.dirty[name] || store.inflight[name]) return;
        if (snap.exists) S[name] = Object.assign(DOCS[name](), structuredClone(snap.data()));
        else if (JSON.stringify(S[name]) !== JSON.stringify(DOCS[name]())) save(name);
        if (name === "tasks") normalize();
        setSync("Saved to your account");
        render();
      }, (e) => { if (e && e.code === "revoked") { store.mode = "local"; setSync("Saved in this browser"); } });
    }
  }

  /* ================= helpers ================= */
  function el(tag, props, ...kids) {
    const n = document.createElement(tag);
    if (props) for (const [k, v] of Object.entries(props)) {
      if (v === undefined || v === null || v === false) continue;
      if (k === "class") n.className = v;
      else if (k === "text") n.textContent = v;
      else if (k === "style") n.setAttribute("style", v);
      else if (k.startsWith("on")) n.addEventListener(k.slice(2), v);
      else n.setAttribute(k, v === true ? "" : v);
    }
    for (const c of kids) if (c !== null && c !== undefined && c !== false) n.append(c);
    return n;
  }
  const SVGNS = "http://www.w3.org/2000/svg";
  function svg(tag, attrs, ...kids) {
    const n = document.createElementNS(SVGNS, tag);
    for (const [k, v] of Object.entries(attrs || {})) n.setAttribute(k, v);
    kids.forEach((c) => c && n.append(c));
    return n;
  }
  const open = () => S.tasks.items.filter((t) => !t.done);
  const deskNotes = () => S.tasks.items.filter((t) => t.onDesk && !t.done).sort((a, b) => (a.deskAt || 0) - (b.deskAt || 0));
  const freeSpots = () => Math.max(0, MAX_DESK - deskNotes().length);
  const isOverdue = (t) => !t.done && t.due && t.due < tk();
  const doneToday = () => S.tasks.items.filter((t) => t.done && t.doneAt === tk());
  function money(n) { const v = Number(n) || 0; return S.bills.currency + v.toLocaleString(undefined, { maximumFractionDigits: v % 1 ? 2 : 0 }); }
  function billDue(b) {
    const t = today();
    const ym = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}`;
    const dayIn = (y, m) => new Date(y, m, Math.min(b.day, new Date(y, m + 1, 0).getDate()));
    const thisDue = dayIn(t.getFullYear(), t.getMonth());
    if (!(b.paid && b.paid[ym(t)])) return { date: thisDue, days: daysBetween(t, thisDue), paid: false, month: ym(t) };
    const next = dayIn(t.getFullYear(), t.getMonth() + 1);
    return { date: next, days: daysBetween(t, next), paid: true, month: ym(t) };
  }
  const wait = (ms) => new Promise((r) => setTimeout(r, reduced ? 0 : ms));
  let toastTimer = null;
  function toast(text, action, fn) {
    $("toastText").textContent = text;
    const b = $("toastBtn");
    b.textContent = action || "";
    b.onclick = fn ? () => { fn(); $("toast").classList.remove("on"); } : null;
    $("toast").classList.add("on");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => $("toast").classList.remove("on"), 4600);
  }

  /* ================= textures (generated once) ================= */
  function canvasTex(w, h, draw) {
    const c = document.createElement("canvas");
    c.width = w; c.height = h;
    const g = c.getContext("2d");
    if (!g) return "none";
    draw(g, w, h);
    return `url(${c.toDataURL("image/png")})`;
  }
  function speckle(g, w, h, density, maxA, tone) {
    const img = g.createImageData(w, h);
    for (let i = 0; i < img.data.length; i += 4) {
      if (Math.random() < density) { img.data[i] = img.data[i + 1] = img.data[i + 2] = tone; img.data[i + 3] = Math.random() * maxA; }
    }
    g.putImageData(img, 0, 0);
  }
  const tex = {};
  function makeTextures() {
    tex.paper = canvasTex(180, 180, (g, w, h) => {
      speckle(g, w, h, .55, 16, 110);
      g.lineCap = "round";
      for (let i = 0; i < 46; i++) {
        g.strokeStyle = `rgba(90,80,70,${rand(.03, .07)})`; g.lineWidth = rand(.3, .8);
        const x = rand(0, w), y = rand(0, h), a = rand(0, Math.PI * 2), l = rand(4, 14);
        g.beginPath(); g.moveTo(x, y); g.quadraticCurveTo(x + Math.cos(a + .6) * l / 2, y + Math.sin(a + .6) * l / 2, x + Math.cos(a) * l, y + Math.sin(a) * l); g.stroke();
      }
    });
    tex.desk = canvasTex(240, 240, (g, w, h) => speckle(g, w, h, .4, 7, 120));
    tex.felt = canvasTex(120, 120, (g, w, h) => speckle(g, w, h, .9, 26, 90));
    tex.leather = canvasTex(220, 220, (g, w, h) => {
      for (let i = 0; i < 2600; i++) {
        const x = rand(0, w), y = rand(0, h), r = rand(1.2, 3.6);
        g.fillStyle = Math.random() < .5 ? `rgba(255,255,255,${rand(.04, .12)})` : `rgba(0,0,0,${rand(.1, .25)})`;
        g.beginPath(); g.ellipse(x, y, r, r * rand(.6, 1), rand(0, 3), 0, Math.PI * 2); g.fill();
      }
    });
    tex.ink = canvasTex(160, 160, (g, w, h) => {
      g.fillStyle = "#000"; g.fillRect(0, 0, w, h);
      g.globalCompositeOperation = "destination-out";
      for (let i = 0; i < 900; i++) { g.fillStyle = `rgba(0,0,0,${rand(.2, .9)})`; g.beginPath(); g.arc(rand(0, w), rand(0, h), rand(.4, 1.6), 0, Math.PI * 2); g.fill(); }
      for (let i = 0; i < 14; i++) { g.fillStyle = `rgba(0,0,0,${rand(.2, .5)})`; g.beginPath(); g.ellipse(rand(0, w), rand(0, h), rand(4, 14), rand(1, 4), rand(0, 3), 0, Math.PI * 2); g.fill(); }
    });
    tex.balls = Array.from({ length: 6 }, () => canvasTex(128, 128, (g) => {
      const pts = [];
      for (let i = 0; i < 26; i++) { const a = (i / 26) * Math.PI * 2, r = rand(44, 58); pts.push([64 + Math.cos(a) * r, 64 + Math.sin(a) * r]); }
      g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y))); g.closePath();
      const grad = g.createRadialGradient(52, 46, 6, 64, 64, 64);
      grad.addColorStop(0, "#ffffff"); grad.addColorStop(.6, "#f0efec"); grad.addColorStop(1, "#d6d5d1");
      g.fillStyle = grad; g.fill(); g.save(); g.clip();
      for (let i = 0; i < 22; i++) {
        const x = rand(14, 114), y = rand(14, 114), a = rand(0, Math.PI), l = rand(14, 44);
        const x2 = x + Math.cos(a) * l, y2 = y + Math.sin(a) * l;
        g.strokeStyle = `rgba(0,0,0,${rand(.06, .16)})`; g.lineWidth = rand(.8, 1.6);
        g.beginPath(); g.moveTo(x, y); g.lineTo(x2, y2); g.stroke();
        g.strokeStyle = `rgba(255,255,255,${rand(.5, .9)})`; g.lineWidth = 1;
        g.beginPath(); g.moveTo(x + 1.2, y - 1); g.lineTo(x2 + 1.2, y2 - 1); g.stroke();
        g.fillStyle = `rgba(0,0,0,${rand(.02, .06)})`;
        g.beginPath(); g.moveTo(x, y); g.lineTo(x2, y2); g.lineTo(x2 + rand(-16, 16), y2 + rand(-16, 16)); g.closePath(); g.fill();
      }
      for (let i = 0; i < 5; i++) { g.strokeStyle = "rgba(27,42,82,.28)"; g.lineWidth = 1.4; g.beginPath(); const x = rand(30, 90), y = rand(30, 90); g.moveTo(x, y); g.bezierCurveTo(x + 6, y - 4, x + 10, y + 3, x + rand(12, 22), y + rand(-4, 4)); g.stroke(); }
      g.restore();
      g.strokeStyle = "rgba(0,0,0,.12)"; g.lineWidth = 1; g.beginPath(); pts.forEach(([x, y], i) => (i ? g.lineTo(x, y) : g.moveTo(x, y))); g.closePath(); g.stroke();
    }));
    const root = document.documentElement.style;
    root.setProperty("--tex-paper", tex.paper);
    root.setProperty("--tex-desk", tex.desk);
    root.setProperty("--tex-felt", tex.felt);
    root.setProperty("--tex-leather", tex.leather);
    root.setProperty("--tex-ink", tex.ink);
  }

  /* ================= sound (synthesised, nothing loaded) ================= */
  const Sound = {
    ctx: null, on: lsGet("clear-desk-sound") !== "off", noise: null, brown: null, focusSrc: null, focusGain: null,
    ensure() {
      if (!this.on) return null;
      try {
        if (!this.ctx) {
          const AC = window.AudioContext || window.webkitAudioContext;
          if (!AC) return null;
          this.ctx = new AC();
          const n = this.ctx.createBuffer(1, this.ctx.sampleRate * 2, this.ctx.sampleRate);
          const d = n.getChannelData(0);
          for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
          this.noise = n;
          const b = this.ctx.createBuffer(1, this.ctx.sampleRate * 4, this.ctx.sampleRate);
          const bd = b.getChannelData(0);
          let last = 0;
          for (let i = 0; i < bd.length; i++) { last = (last + .02 * (Math.random() * 2 - 1)) / 1.02; bd[i] = last * 3.2; }
          this.brown = b;
        }
        if (this.ctx.state === "suspended") this.ctx.resume();
        return this.ctx;
      } catch (e) { return null; }
    },
    burst(t, dur, f, q, gain, type = "bandpass") {
      const c = this.ctx;
      const s = c.createBufferSource(); s.buffer = this.noise;
      const fl = c.createBiquadFilter(); fl.type = type; fl.frequency.value = f; fl.Q.value = q;
      const g = c.createGain();
      g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(gain, t + .004); g.gain.exponentialRampToValueAtTime(.0001, t + dur);
      s.connect(fl).connect(g).connect(c.destination);
      s.start(t, Math.random() * 1.5, dur + .05);
    },
    tone(t, f0, f1, dur, gain, type = "sine") {
      const c = this.ctx;
      const o = c.createOscillator(); o.type = type;
      o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f1, t + dur);
      const g = c.createGain();
      g.gain.setValueAtTime(gain, t); g.gain.exponentialRampToValueAtTime(.0001, t + dur);
      o.connect(g).connect(c.destination); o.start(t); o.stop(t + dur + .05);
    },
    play(name) {
      const c = this.ensure();
      if (!c) return;
      const t = c.currentTime + .01;
      if (name === "crumple") for (let i = 0; i < 18; i++) this.burst(t + Math.pow(Math.random(), 1.4) * .5, rand(.015, .06), rand(1400, 5200), rand(.8, 2.2), rand(.08, .3));
      else if (name === "tear") { for (let i = 0; i < 26; i++) this.burst(t + i * .011, .03, 900 + i * 110, 2.5, .18); this.burst(t + .3, .05, 2500, 1, .1); }
      else if (name === "thump") { this.tone(t, 120, 48, .18, .55); this.burst(t, .05, 500, .7, .25, "lowpass"); }
      else if (name === "stamp") { this.tone(t, 150, 55, .14, .7); this.burst(t, .07, 900, .6, .4, "lowpass"); this.burst(t + .005, .03, 3000, 1, .1); }
      else if (name === "scratch") this.burst(t, rand(.03, .06), rand(3800, 5600), 3, .07);
      else if (name === "write") for (let i = 0; i < 3; i++) this.burst(t + i * .07, rand(.04, .07), rand(3500, 5500), 3, .06);
      else if (name === "drop") { this.tone(t, 220, 90, .1, .3); for (let i = 0; i < 5; i++) this.burst(t + rand(0, .12), .03, rand(1500, 3500), 1.5, .08); }
      else if (name === "whoosh") { const s = c.createBufferSource(); s.buffer = this.noise; const f = c.createBiquadFilter(); f.type = "lowpass"; f.frequency.setValueAtTime(300, t); f.frequency.exponentialRampToValueAtTime(1600, t + .3); f.frequency.exponentialRampToValueAtTime(400, t + .55); const g = c.createGain(); g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(.22, t + .2); g.gain.exponentialRampToValueAtTime(.001, t + .6); s.connect(f).connect(g).connect(c.destination); s.start(t, 0, .7); }
      else if (name === "tick") this.tone(t, 2200, 1800, .025, .05, "square");
      else if (name === "nope") { this.tone(t, 220, 200, .08, .12, "triangle"); this.tone(t + .1, 180, 160, .1, .12, "triangle"); }
      else if (name === "chime") { this.tone(t, 880, 880, 1.4, .12); this.tone(t + .18, 1318.5, 1318.5, 1.6, .1); this.tone(t + .36, 1760, 1760, 1.8, .06); }
      else if (name === "pop") this.tone(t, 600, 1200, .06, .08);
    },
    focus(on) {
      const c = this.ensure();
      if (!c) return;
      if (on && !this.focusSrc) {
        const s = c.createBufferSource(); s.buffer = this.brown; s.loop = true;
        const f = c.createBiquadFilter(); f.type = "lowpass"; f.frequency.value = 700;
        const g = c.createGain(); g.gain.setValueAtTime(0, c.currentTime); g.gain.linearRampToValueAtTime(.16, c.currentTime + 2.5);
        s.connect(f).connect(g).connect(c.destination); s.start();
        this.focusSrc = s; this.focusGain = g;
      } else if (!on && this.focusSrc) {
        const s = this.focusSrc, g = this.focusGain;
        g.gain.cancelScheduledValues(c.currentTime); g.gain.setValueAtTime(g.gain.value, c.currentTime); g.gain.linearRampToValueAtTime(0, c.currentTime + 1.2);
        setTimeout(() => { try { s.stop(); } catch (e) {} }, 1400);
        this.focusSrc = null;
      }
    },
  };
  const SPEAKER_ON = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M2 6h2.5L8 3v10L4.5 10H2z" fill="currentColor"/><path d="M10.5 5.5a3.5 3.5 0 0 1 0 5M12.5 3.5a6.3 6.3 0 0 1 0 9" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>';
  const SPEAKER_OFF = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M2 6h2.5L8 3v10L4.5 10H2z" fill="currentColor"/><path d="M10.5 6l4 4M14.5 6l-4 4" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>';
  function renderSoundBtn() {
    const b = $("soundBtn");
    b.innerHTML = Sound.on ? SPEAKER_ON : SPEAKER_OFF;
    b.setAttribute("aria-pressed", String(Sound.on));
    b.setAttribute("aria-label", Sound.on ? "Sound on" : "Sound off");
  }
  $("soundBtn").addEventListener("click", () => {
    Sound.on = !Sound.on;
    lsSet("clear-desk-sound", Sound.on ? "on" : "off");
    if (!Sound.on) Sound.focus(false); else { Sound.play("pop"); if (focus.end) Sound.focus(true); }
    renderSoundBtn();
  });

  /* ================= layout ================= */
  let L = LAYOUTS.wide, layoutName = "wide", K = 1;
  const stage = $("stage");
  function place(id, r) {
    const n = $(id);
    if (!n || !r) return;
    n.style.setProperty("--x", r.x); n.style.setProperty("--y", r.y);
    if (r.w !== undefined) n.style.setProperty("--w", r.w);
    if (r.h !== undefined) n.style.setProperty("--h", r.h);
    if (r.r !== undefined) n.style.setProperty("--r", r.r + "deg");
  }
  function applyLayout() {
    const wrapW = $("wrap").clientWidth;
    const name = wrapW < 760 ? "tall" : "wide";
    const changed = name !== layoutName || !stage.dataset.laid;
    layoutName = name; L = LAYOUTS[name];
    K = wrapW / L.w;
    const root = document.documentElement.style;
    root.setProperty("--k", K.toFixed(4)); root.setProperty("--dw", L.w); root.setProperty("--dh", L.h);
    stage.classList.toggle("tall", name === "tall");
    if (!changed) return;
    stage.dataset.laid = "1";
    $("surface").style.height = L.deskH + "px";
    $("edge").style.height = L.deskH + "px";
    ["calendar", "plant", "pad", "tray", "legal", "notebook", "phone", "habits", "mug", "airpods", "bin"].forEach((id) => place(id, L[id]));
    place("stain", L.stain);
    place("drawerFront", L.drawer);
    penRest();
    render();
  }
  addEventListener("resize", () => { clearTimeout(applyLayout.t); applyLayout.t = setTimeout(applyLayout, 80); });

  /* ================= light: follows the real time of day ================= */
  function setLight() {
    const now = new Date();
    const h = now.getHours() + now.getMinutes() / 60;
    const root = document.documentElement.style;
    const dayTime = h >= 6.5 && h < 19.3;
    let lx, ly, tint, lamp, blinds, leafO, so;
    if (dayTime) {
      const p = clamp((h - 6.5) / 12.8, 0, 1);
      const len = .75 + Math.abs(p - .5) * 1.3;
      lx = (1.05 - 2.1 * p) * len; ly = .85 * len;
      blinds = .55 + Math.sin(p * Math.PI) * .4;
      leafO = .32 + Math.sin(p * Math.PI) * .2;
      so = .17 + Math.abs(p - .5) * .06;
      lamp = 0;
      tint = h < 9 ? "rgb(242,246,255)" : h > 16.3 ? `rgb(255,${Math.round(246 - (h - 16.3) * 6)},${Math.round(232 - (h - 16.3) * 14)})` : "transparent";
      root.setProperty("--blind-angle", `${116 - p * 52}deg`);
      root.setProperty("--blind-fade", `${110 + p * 140}deg`);
      root.setProperty("--leaf-x", `${L === LAYOUTS.tall ? 120 : (p < .5 ? -120 : 940)}px`);
    } else {
      lx = .35; ly = .8; tint = "rgb(214,216,226)"; lamp = 1; blinds = 0; leafO = 0; so = .26;
    }
    root.setProperty("--lx", lx.toFixed(3)); root.setProperty("--ly", ly.toFixed(3));
    root.setProperty("--tint", tint); root.setProperty("--lamp", lamp);
    root.setProperty("--blinds", blinds.toFixed(2)); root.setProperty("--leaf-o", leafO.toFixed(2)); root.setProperty("--so", so.toFixed(3));
  }
  function buildLeaves() {
    const s = $("leafshade");
    const g = svg("g", { fill: "rgba(40,55,45,.55)" });
    const branch = (x, y, a, len, depth) => {
      const x2 = x + Math.cos(a) * len, y2 = y + Math.sin(a) * len;
      g.append(svg("path", { d: `M${x},${y} Q${(x + x2) / 2 + 8},${(y + y2) / 2} ${x2},${y2}`, stroke: "rgba(40,55,45,.5)", "stroke-width": 3 - depth * .7, fill: "none" }));
      const n = 5 - depth;
      for (let i = 1; i <= n; i++) {
        const t = i / (n + 1), px = x + (x2 - x) * t, py = y + (y2 - y) * t;
        [-1, 1].forEach((side) => {
          const la = a + side * rand(.6, 1.1), ll = rand(26, 46);
          g.append(svg("ellipse", { cx: px + Math.cos(la) * ll / 2, cy: py + Math.sin(la) * ll / 2, rx: ll / 2, ry: ll / 5.5, transform: `rotate(${(la * 180) / Math.PI} ${px + Math.cos(la) * ll / 2} ${py + Math.sin(la) * ll / 2})` }));
        });
      }
      if (depth < 2) { branch(x2, y2, a + rand(.3, .6), len * .7, depth + 1); branch(x2, y2, a - rand(.3, .6), len * .7, depth + 1); }
    };
    branch(560, -20, 2.2, 190, 0);
    branch(700, 60, 2.6, 160, 0);
    s.append(g);
  }
  function buildPlant() {
    const s = $("plantsvg");
    const defs = svg("defs", {}, svg("radialGradient", { id: "lg", cx: "30%", cy: "30%", r: "80%" }, svg("stop", { offset: "0", "stop-color": "#8fd19a" }), svg("stop", { offset: ".55", "stop-color": "#3f9b58" }), svg("stop", { offset: "1", "stop-color": "#256b3a" })));
    s.append(defs);
    const g = svg("g", {});
    const leaves = 13;
    for (let i = 0; i < leaves; i++) {
      const a = (i / leaves) * 360 + rand(-10, 10), len = rand(52, 78), wdt = rand(13, 19);
      const leaf = svg("g", { transform: `rotate(${a})` },
        svg("path", { d: `M0,0 C${wdt},-${len * .3} ${wdt * .8},-${len * .8} 0,-${len} C-${wdt * .8},-${len * .8} -${wdt},-${len * .3} 0,0Z`, fill: "url(#lg)", stroke: "rgba(20,60,30,.35)", "stroke-width": ".6" }),
        svg("path", { d: `M0,-4 L0,-${len - 6}`, stroke: "rgba(220,255,225,.45)", "stroke-width": "1.1", fill: "none" }));
      g.append(leaf);
    }
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * 360 + 30, len = rand(28, 40), wdt = rand(9, 12);
      g.append(svg("path", { transform: `rotate(${a})`, d: `M0,0 C${wdt},-${len * .3} ${wdt * .8},-${len * .8} 0,-${len} C-${wdt * .8},-${len * .8} -${wdt},-${len * .3} 0,0Z`, fill: "#6cc283", stroke: "rgba(20,60,30,.3)", "stroke-width": ".5" }));
    }
    s.append(g);
  }

  /* ================= pointer: phone glass reflection ================= */
  if (fine && !reduced) addEventListener("pointermove", (e) => { $("phone").style.setProperty("--gx", ((e.clientX / innerWidth) * 40 - 20).toFixed(1)); });

  /* ================= summary + drawer front ================= */
  function renderSummary() {
    const s = $("summary");
    s.replaceChildren();
    const notes = deskNotes().length;
    const od = open().filter((t) => isOverdue(t) && !t.onDesk).length;
    const inbox = open().filter((t) => !t.area && !t.onDesk).length;
    const bills = S.bills.items.map(billDue).filter((d) => !d.paid && d.days <= 7);
    const late = bills.filter((d) => d.days < 0).length;
    const parts = [[notes ? `${notes} of ${MAX_DESK} spots taken` : "Your desk is clear", ""]];
    if (od) parts.push([`${od} late in the drawer`, "bad"]);
    if (late) parts.push([`${late} ${late === 1 ? "bill" : "bills"} overdue`, "bad"]);
    else if (bills.length) parts.push([`${bills.length} ${bills.length === 1 ? "bill" : "bills"} due this week`, ""]);
    if (inbox) parts.push([`${inbox} unsorted`, ""]);
    parts.forEach(([t, cls], i) => { if (i) s.append(i === parts.length - 1 ? " and " : ", "); s.append(el("b", { class: cls || null, text: t })); });
    s.append(".");
    const inDrawer = open().filter((t) => !t.onDesk).length;
    $("drawerText").replaceChildren(el("b", { text: "Drawer" }), ` · ${inDrawer} inside`, od ? el("span", { class: "bad", text: ` · ${od} late` }) : null);
  }

  /* ================= calendar (tear-off) ================= */
  function cpage(d, extra) {
    return el("div", { class: "cpage paper" + (extra ? " " + extra : "") },
      el("div", { class: "band", text: d.toLocaleDateString(undefined, { month: "long" }).toUpperCase() }),
      el("div", { class: "perf" }),
      el("div", { class: "num", text: String(d.getDate()) }),
      el("div", { class: "dow", text: d.toLocaleDateString(undefined, { weekday: "long" }) }));
  }
  let calShown = "";
  function renderCalendarBlock(animate) {
    const k = tk();
    if (calShown === k && !animate) return;
    const box = $("cpages");
    box.replaceChildren(cpage(today()));
    if (animate && !reduced) {
      const y = cpage(addDays(today(), -1));
      box.append(y);
      setTimeout(() => { y.classList.add("tearing"); Sound.play("tear"); }, 1100);
      setTimeout(() => y.remove(), 2600);
    }
    calShown = k;
  }

  /* ================= notes ================= */
  let draft = null, selected = null, arriving = null, dragging = false, pendingRender = false;
  function slotRect(i) { const s = L.slots[i]; return { x: s.x, y: s.y, w: L.slotSize, h: L.slotSize, r: s.r }; }
  function roughCircle() {
    const p = svg("path", { d: "M8 30 C 2 14, 30 2, 60 4 C 92 6, 104 18, 100 30 C 96 44, 60 48, 34 44 C 14 41, 4 34, 12 22" });
    return svg("svg", { viewBox: "0 0 108 50", preserveAspectRatio: "none", "aria-hidden": "true" }, p);
  }
  const ICON_CHECK = '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M4.5 10.5l3.5 3.5 7.5-8" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  const ICON_DOWN = '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M10 4v10M5.5 9.5L10 14l4.5-4.5M4 17h12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  const ICON_EDIT = '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M4 16l1-4 8.5-8.5 3 3L8 15z M12 5l3 3" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg>';
  function nbtn(cls, html, label, fn) {
    const b = el("button", { class: "nbtn " + cls, type: "button", "aria-label": label, title: label });
    b.innerHTML = html;
    b.addEventListener("click", (e) => { e.stopPropagation(); fn(); });
    b.addEventListener("pointerdown", (e) => e.stopPropagation());
    return b;
  }
  function noteEl(t, i) {
    const s = slotRect(i);
    const d = dueInfo(t.due);
    const n = el("article", { class: "obj note" + (selected === t.id ? " sel" : ""), "data-id": t.id, tabindex: "0", "aria-label": `${t.title}. Press Enter when done, Delete to put it back in the drawer.`,
      style: `--x:${s.x};--y:${s.y};--w:${s.w};--h:${s.h};--r:${s.r}deg;--i:${i + 3};--tape:${TAPE[t.area] || "#d6d6db"};--tr:${(hash(t.id) % 9) - 4}deg` });
    const body = el("div", { class: "body paper" },
      t.example ? el("span", { class: "ex", text: "example" }) : null,
      el("p", { class: "nt", text: t.title }),
      el("div", { class: "foot" }, el("span", { class: "area", text: t.area || "unsorted" }),
        d ? el("span", { class: "due " + d.cls }, d.text, d.cls === "bad" ? roughCircle() : null) : null));
    const strike = svg("svg", { class: "strike", viewBox: "0 0 200 60", preserveAspectRatio: "none", "aria-hidden": "true" }, svg("path", { d: "M4 34 C 40 22, 70 40, 104 28 S 160 18, 196 30" }));
    body.append(strike);
    n.append(el("div", { class: "cast" }), body, el("div", { class: "fold" }), el("span", { class: "tape" }),
      el("div", { class: "acts" }, nbtn("done", ICON_CHECK, "Done", () => finish(t, n)), nbtn("", ICON_EDIT, "Edit", () => editNote(t, n)), nbtn("", ICON_DOWN, "Back in the drawer", () => toDrawer(t, n))));
    if (arriving && arriving.id === t.id) {
      n.style.setProperty("--fx", arriving.fx); n.style.setProperty("--fy", arriving.fy);
      n.classList.add("arrive");
    }
    n.addEventListener("keydown", (e) => {
      if (e.target !== n) return;
      if (e.key === "Enter") { e.preventDefault(); finish(t, n); }
      if (e.key === "Backspace" || e.key === "Delete") { e.preventDefault(); toDrawer(t, n); }
    });
    attachDrag(n, t);
    return n;
  }
  function editNote(t, n) {
    const p = n.querySelector(".nt");
    if (!p) return;
    const ta = el("textarea", { "aria-label": "Edit note", maxlength: "90" });
    ta.value = t.title;
    p.replaceWith(ta);
    ta.focus();
    const sr = slotRect(deskNotes().indexOf(t));
    penTo(sr.x + 40, sr.y + 90, true);
    ta.addEventListener("input", () => { penWrite(sr, ta.value.length); Sound.play("scratch"); });
    let closed = false;
    const done = (commit) => { if (closed) return; closed = true; if (commit && ta.value.trim()) { t.title = ta.value.trim(); save("tasks"); } penRest(); render(); };
    ta.addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); done(true); } if (e.key === "Escape") done(false); });
    ta.addEventListener("blur", () => done(true));
  }
  function renderNotes() {
    const box = $("notes");
    const notes = deskNotes();
    box.replaceChildren();
    if (!notes.length && !draft && doneToday().length) {
      const c = L.cleared;
      box.append(el("div", { class: "cleared", style: `left:${c.x}px;top:${c.y}px;width:${c.w}px` }, el("h2", { text: "Clear desk." }),
        el("p", { text: `${doneToday().length} finished today. Take the next thing from the drawer, or call it a day.` })));
    }
    notes.forEach((t, i) => box.append(noteEl(t, i)));
    let next = notes.length;
    if (draft && next < MAX_DESK) {
      const s = slotRect(next);
      const ta = el("textarea", { id: "draftText", "aria-label": "New note", maxlength: "90", placeholder: "" });
      ta.value = draft.text || "";
      const n = el("article", { class: "obj note arrive", id: "draftNote", style: `--x:${s.x};--y:${s.y};--w:${s.w};--h:${s.h};--r:${s.r}deg;--tape:#d6d6db;--fx:${draft.fx};--fy:${draft.fy};--tr:-2deg` },
        el("div", { class: "cast" }),
        el("div", { class: "body paper" }, ta, el("div", { class: "foot" }, el("span", { class: "area", text: "Return to stick it" }))),
        el("div", { class: "fold" }), el("span", { class: "tape" }));
      box.append(n);
      wireDraft(ta, s);
      next++;
    }
    for (let i = next; i < MAX_DESK; i++) {
      const s = slotRect(i);
      box.append(el("button", { class: "slot", type: "button", style: `--x:${s.x};--y:${s.y};--w:${s.w};--h:${s.h};--r:${s.r}deg`, onclick: () => tearNote() },
        el("span", {}, el("b", { text: "Free spot" }), i === next ? el("span", { text: "Tap to write a note, or take one from the drawer" }) : null)));
    }
    const full = notes.length >= MAX_DESK || (draft && notes.length + 1 >= MAX_DESK);
    $("pad").classList.toggle("full", !!full);
    $("padCap").textContent = full ? "desk is full" : "new note";
    arriving = null;
  }
  function wireDraft(ta, s) {
    let committed = false;
    const commit = () => {
      if (committed || !draft) return;
      committed = true;
      const p = parseQuick(ta.value, today());
      draft = null;
      if (p.title) {
        S.tasks.items.push(Object.assign({ id: uid(), top: "", done: false, doneAt: "", created: tk(), onDesk: true, deskAt: Date.now() }, p));
        save("tasks");
        Sound.play("thump");
      }
      penRest();
      render();
    };
    ta.addEventListener("input", () => { draft && (draft.text = ta.value); penWrite(s, ta.value.length); Sound.play("scratch"); });
    ta.addEventListener("keydown", (e) => {
      if (e.key === "Enter") { e.preventDefault(); commit(); }
      if (e.key === "Escape") { committed = true; draft = null; penRest(); render(); }
    });
    ta.addEventListener("blur", () => setTimeout(commit, 150));
    setTimeout(() => { ta.focus(); penTo(s.x + 34, s.y + 92, true); }, reduced ? 0 : 520);
  }
  function tearNote() {
    if (draft) { const d = $("draftText"); if (d) d.focus(); return; }
    if (freeSpots() === 0) {
      const p = $("pad");
      p.classList.remove("shake"); void p.offsetWidth; p.classList.add("shake");
      Sound.play("nope");
      toast("The desk is full. Finish something first.");
      return;
    }
    const s = slotRect(deskNotes().length);
    draft = { text: "", fx: L.pad.x - s.x, fy: L.pad.y - s.y };
    selected = null;
    Sound.play("tear");
    render();
  }
  $("padBtn").addEventListener("click", tearNote);

  /* ---- pen ---- */
  const pen = $("pen");
  function penTo(x, y, writing) {
    pen.style.setProperty("--px", x); pen.style.setProperty("--py", y);
    pen.style.setProperty("--pr", "-38deg");
    pen.classList.toggle("writing", false);
    if (writing) setTimeout(() => pen.classList.add("writing"), 700);
  }
  function penWrite(s, len) {
    const perLine = Math.max(6, Math.round((s.w - 60) / 19));
    const line = Math.floor(len / perLine), col = len % perLine;
    pen.style.setProperty("--px", s.x + 30 + col * 19 + rand(-2, 2));
    pen.style.setProperty("--py", s.y + 82 + Math.min(line, 3) * 39 + rand(-2, 2));
    pen.style.setProperty("--pr", `${-38 + rand(-3, 3)}deg`);
  }
  function penRest() {
    const r = L.penRest;
    pen.classList.remove("writing");
    pen.style.setProperty("--px", r.px); pen.style.setProperty("--py", r.py); pen.style.setProperty("--pr", r.pr + "deg");
  }

  /* ---- finishing: strike, crumple, throw ---- */
  function stageXY(node) {
    const sr = stage.getBoundingClientRect(), r = node.getBoundingClientRect();
    return { x: (r.left - sr.left) / K, y: (r.top - sr.top) / K, w: r.width / K, h: r.height / K };
  }
  async function throwBall(from) {
    const to = stageXY($("bin"));
    const size = layoutName === "tall" ? 96 : 74;
    const ball = el("div", { class: "ball", style: `left:${from.x + from.w / 2 - size / 2}px;top:${from.y + from.h / 2 - size / 2}px;width:${size}px;height:${size}px;background-image:${tex.balls[Math.floor(Math.random() * tex.balls.length)]}` });
    stage.append(ball);
    if (reduced) { ball.remove(); return; }
    await ball.animate([{ transform: "scale(.3) rotate(0deg)", opacity: .4 }, { transform: "scale(1.1) rotate(80deg)", opacity: 1, offset: .7 }, { transform: "scale(1) rotate(100deg)" }], { duration: 260, easing: "ease-out", fill: "forwards" }).finished.catch(() => {});
    const dx = to.x + to.w / 2 - (from.x + from.w / 2), dy = to.y + to.h / 2 - (from.y + from.h / 2);
    const H = 160 + Math.abs(dx) * .18;
    const frames = [];
    for (let i = 0; i <= 12; i++) {
      const t = i / 12;
      frames.push({ transform: `translate(${dx * t}px, ${dy * t - 4 * H * t * (1 - t)}px) rotate(${100 + t * 520}deg) scale(${1 - t * .25})` });
    }
    await ball.animate(frames, { duration: 640 + Math.abs(dx) * .15, easing: "cubic-bezier(.35,.0,.65,1)", fill: "forwards" }).finished.catch(() => {});
    ball.remove();
    const b = $("bin");
    b.classList.remove("wobble"); void b.offsetWidth; b.classList.add("wobble");
    Sound.play("drop");
  }
  let finishing = false;
  async function finish(t, n, fromDrag) {
    if (finishing) return;
    finishing = true;
    selected = null;
    const prev = { done: t.done, doneAt: t.doneAt, onDesk: t.onDesk };
    if (n && !reduced) {
      if (!fromDrag) { n.classList.add("striking"); Sound.play("write"); await wait(420); }
      Sound.play("crumple");
      const from = stageXY(n);
      n.style.transition = "transform .28s cubic-bezier(.5,0,.8,.4), opacity .28s";
      n.style.transform = `${n.style.transform || ""} scale(.3) rotate(40deg)`;
      n.style.opacity = "0";
      await throwBall(from);
    } else Sound.play("crumple");
    t.done = true; t.doneAt = tk(); t.onDesk = false;
    const cutoff = keyOf(addDays(today(), -30));
    S.tasks.items = S.tasks.items.filter((x) => !x.done || (x.doneAt || "") >= cutoff);
    save("tasks");
    finishing = false;
    render();
    const free = freeSpots();
    toast(free === 1 ? "Done. There’s room for one new thing." : `Done. ${free} spots free.`, "Undo", () => {
      Object.assign(t, prev);
      if (!S.tasks.items.includes(t)) S.tasks.items.push(t);
      save("tasks"); render();
    });
  }
  async function toDrawer(t, n) {
    selected = null;
    Sound.play("whoosh");
    if (n && !reduced) {
      const from = stageXY(n), to = stageXY($("drawerFront"));
      const dx = to.x + to.w / 2 - (from.x + from.w / 2), dy = to.y + 10 - (from.y + from.h / 2);
      await n.animate([{ transform: n.style.transform || `rotate(var(--r))` }, { transform: `translate(${dx}px, ${dy}px) rotate(8deg) scale(.25)`, opacity: .1 }], { duration: 520, easing: "cubic-bezier(.5,0,.75,0)", fill: "forwards" }).finished.catch(() => {});
    }
    const f = $("drawerFront"); f.classList.add("hot"); setTimeout(() => f.classList.remove("hot"), 260);
    t.onDesk = false;
    save("tasks"); render();
    toast("Back in the drawer.", "Undo", () => { if (freeSpots() > 0) { t.onDesk = true; t.deskAt = Date.now(); save("tasks"); render(); } });
  }
  function toDesk(t) {
    if (freeSpots() === 0) { Sound.play("nope"); toast("The desk is full. Finish something first."); return false; }
    const s = slotRect(deskNotes().length);
    t.onDesk = true; t.deskAt = Date.now();
    arriving = { id: t.id, fx: L.drawer.x + 100 - s.x, fy: L.drawer.y - s.y };
    save("tasks");
    return true;
  }

  /* ---- drag with a little physics ---- */
  function attachDrag(n, t) {
    let sx = 0, sy = 0, moved = false, pid = null, lastX = 0, vx = 0, rot = 0, raf = 0, dx = 0, dy = 0, base = 0;
    const near = (x, y, node, pad) => { const r = node.getBoundingClientRect(); return x > r.left - pad && x < r.right + pad && y > r.top - pad && y < r.bottom + pad; };
    const other = (x, y) => document.elementsFromPoint(x, y).map((e) => e.closest(".note")).find((m) => m && m !== n && m.dataset.id);
    n.addEventListener("pointerdown", (e) => {
      if (e.button !== 0 || e.target.closest("button, textarea")) return;
      sx = e.clientX; sy = e.clientY; lastX = e.clientX; moved = false; pid = e.pointerId; vx = 0;
      base = parseFloat(getComputedStyle(n).getPropertyValue("--r")) || 0; rot = base;
      n.setPointerCapture(pid);
    });
    const frame = () => {
      vx *= .82;
      const target = base + clamp(vx * .9, -16, 16);
      rot += (target - rot) * .25;
      n.style.transform = `translate(${dx}px, ${dy}px) rotate(${rot}deg) scale(1.05)`;
      raf = pid !== null ? requestAnimationFrame(frame) : 0;
    };
    n.addEventListener("pointermove", (e) => {
      if (pid !== e.pointerId) return;
      const mx = e.clientX - sx, my = e.clientY - sy;
      if (!moved && Math.hypot(mx, my) < 7) return;
      if (!moved) { moved = true; dragging = true; n.classList.add("lifted"); Sound.play("tick"); if (!raf) raf = requestAnimationFrame(frame); }
      dx = mx / K; dy = my / K;
      vx += (e.clientX - lastX) * .5; lastX = e.clientX;
      $("bin").classList.toggle("hot", near(e.clientX, e.clientY, $("bin"), 30 * K));
      $("drawerFront").classList.toggle("hot", near(e.clientX, e.clientY, $("drawerFront"), 30 * K));
      document.querySelectorAll(".note.swap").forEach((m) => m.classList.remove("swap"));
    });
    const end = (e) => {
      if (pid !== e.pointerId) return;
      pid = null;
      cancelAnimationFrame(raf); raf = 0;
      const toBin = $("bin").classList.contains("hot"), toDr = $("drawerFront").classList.contains("hot");
      $("bin").classList.remove("hot"); $("drawerFront").classList.remove("hot");
      if (!moved) { selected = selected === t.id ? null : t.id; document.querySelectorAll(".note.sel").forEach((m) => m !== n && m.classList.remove("sel")); n.classList.toggle("sel", selected === t.id); return; }
      dragging = false;
      n.classList.remove("lifted");
      if (toBin) { finish(t, n, true); return; }
      if (toDr) { toDrawer(t, n); return; }
      const o = other(e.clientX, e.clientY);
      if (o) {
        const u = S.tasks.items.find((x) => x.id === o.dataset.id);
        if (u) { const a = t.deskAt; t.deskAt = u.deskAt; u.deskAt = a; save("tasks"); Sound.play("thump"); render(); return; }
      }
      n.style.transition = "transform .55s cubic-bezier(.2,1.5,.4,1)";
      n.style.transform = "";
      Sound.play("thump");
      setTimeout(() => { n.style.transition = ""; if (pendingRender) { pendingRender = false; render(); } }, 560);
    };
    n.addEventListener("pointerup", end);
    n.addEventListener("pointercancel", end);
  }

  /* ================= letter tray ================= */
  function renderTray() {
    const box = $("envs");
    box.replaceChildren();
    const due = S.bills.items.map((b) => ({ b, d: billDue(b) })).filter((x) => !x.d.paid && x.d.days <= 7).sort((a, b) => a.d.days - b.d.days).slice(0, 3);
    $("trayLabel").textContent = due.length ? "" : (S.bills.items.length ? "nothing due this week" : "bills go here");
    due.forEach(({ b, d }, i) => {
      const slot = due.length - 1 - i;
      const p = L.envs[slot];
      const label = d.days < 0 ? `${-d.days}d late` : d.days === 0 ? "due today" : d.days === 1 ? "due tomorrow" : `due ${d.date.toLocaleDateString(undefined, { weekday: "short" })}`;
      const postmark = svg("svg", { class: "postmark", viewBox: "0 0 70 40", "aria-hidden": "true" },
        svg("circle", { cx: 20, cy: 20, r: 16, fill: "none", stroke: "#6b6f80", "stroke-width": 1.4 }),
        ...[10, 17, 24, 31].map((y) => svg("path", { d: `M30 ${y} q 5 -4 10 0 t 10 0 t 10 0 t 10 0`, fill: "none", stroke: "#6b6f80", "stroke-width": 1.3 })));
      const env = el("div", { class: "env", style: `--ex:${p.ex};--ey:${p.ey};--er:${p.er}deg;z-index:${3 + slot}`, onclick: (e) => { if (!e.target.closest("button")) { env.classList.toggle("sel"); Sound.play("tick"); } } },
        el("div", { class: "cast" }),
        el("div", { class: "body paper" },
          el("div", { class: "flap" }),
          el("div", { class: "stamp" }, el("i")),
          postmark,
          el("div", { class: "addr" }, el("b", { text: b.name }), el("span", { text: money(b.amount) })),
          el("span", { class: "rubber " + (d.days < 0 ? "late" : "soon"), text: d.days < 0 ? `${-d.days}d late` : label })));
      const pay = el("button", { class: "chip pay", type: "button", text: "Mark paid", onclick: async () => {
        const r = env.querySelector(".rubber");
        r.className = "rubber paid"; r.textContent = "paid";
        Sound.play("stamp");
        b.paid = b.paid || {}; b.paid[d.month] = true;
        save("bills");
        await wait(750);
        env.classList.add("filed"); Sound.play("whoosh");
        await wait(800);
        render();
        toast(`${b.name} paid.`, "Undo", () => { delete b.paid[d.month]; save("bills"); render(); });
      } });
      env.append(pay);
      box.append(env);
    });
  }

  /* ================= habit card ================= */
  function streak(h) {
    let d = today();
    if (!(h.log && h.log[keyOf(d)])) d = addDays(d, -1);
    let n = 0;
    while (h.log && h.log[keyOf(d)]) { n++; d = addDays(d, -1); }
    return n;
  }
  function tally(n) {
    const shown = Math.min(n, 10), groups = Math.ceil(shown / 5);
    const w = groups * 34 + (n > 10 ? 26 : 0);
    const s = svg("svg", { class: "tally" + (n >= 3 ? " hot" : ""), viewBox: `0 0 ${Math.max(w, 1)} 26`, width: Math.max(w, 1), "aria-label": `${n} days in a row` });
    for (let i = 0; i < shown; i++) {
      const g = Math.floor(i / 5), j = i % 5, x0 = g * 34;
      if (j < 4) s.append(svg("path", { d: `M${x0 + 4 + j * 6} ${3 + (i % 2)} L${x0 + 3 + j * 6} 23` }));
      else s.append(svg("path", { d: `M${x0} 19 L${x0 + 26} 6` }));
    }
    if (n > 10) s.append(svg("text", { x: groups * 34 + 2, y: 20, "font-size": 15, fill: "#8a90a6", "font-family": "Caveat, cursive" }, document.createTextNode("+" + (n - 10))));
    return s;
  }
  function renderHabitCard() {
    const ul = $("habList");
    ul.replaceChildren();
    if (!S.habits.items.length) {
      ul.append(el("li", {}, el("button", { class: "habit", type: "button", onclick: () => openDrawer("habits") }, el("span"), el("span", { class: "name", style: "color:#a1a1a6", text: "Add a habit" }), el("span"))));
      return;
    }
    S.habits.items.slice(0, 4).forEach((h) => {
      const on = !!(h.log && h.log[tk()]);
      const box = svg("svg", { viewBox: "0 0 44 44", "aria-hidden": "true" },
        svg("path", { class: "sq", d: "M9 10 L35 8.5 L36 34 L8.5 35.5 Z" }),
        svg("path", { class: "ck", d: "M12 22 L19 31 L38 4" }));
      ul.append(el("li", {}, el("button", { class: "habit", type: "button", "aria-pressed": String(on), "aria-label": h.name + (on ? ", done today" : ""),
        onclick: () => { h.log = h.log || {}; if (on) delete h.log[tk()]; else { h.log[tk()] = true; Sound.play("write"); } save("habits"); render(); } },
        el("span", { class: "box" }, box), el("span", { class: "name", text: h.name }), tally(streak(h)))));
    });
  }
  $("habEdit").addEventListener("click", () => openDrawer("habits"));

  /* ================= notebook ================= */
  function renderNotebook() {
    const last = S.review.lastDone;
    const ago = last ? daysBetween(fromKey(last), today()) : null;
    const due = ago === null || ago >= 7;
    $("nbWhen").textContent = ago === null ? "Not done yet" : ago === 0 ? "Closed today" : `Last closed ${ago} days ago`;
    $("nbFlag").hidden = !due;
    const wk = S.review.outcomes.filter((o) => o && o.trim());
    $("nbWeek").textContent = wk.join(" · ");
    $("bookSub").textContent = ago === null ? "Fifteen minutes, once a week. It keeps the drawer honest." : `Last closed ${ago === 0 ? "today" : ago + " days ago"}.`;
    const inbox = open().filter((t) => !t.area).length;
    const od = open().filter(isOverdue).length;
    const soon = S.bills.items.filter((b) => { const d = billDue(b); return !d.paid && d.days <= 14; }).length;
    const steps = [
      ["inbox", inbox ? `Sort the ${inbox} unsorted ${inbox === 1 ? "thing" : "things"} in the drawer` : "Drawer is sorted"],
      ["overdue", od ? `Reschedule or throw away ${od} late ${od === 1 ? "task" : "tasks"}` : "Nothing is late"],
      ["calendar", "Look at next week’s calendar. Add a note for anything that needs prep."],
      ["bills", soon ? `Check the ${soon} ${soon === 1 ? "bill" : "bills"} due in two weeks` : "No bills due in two weeks"],
      ["habits", "Look at the habits. Keep, change, or drop one."],
    ];
    const ul = $("steps");
    ul.replaceChildren();
    steps.forEach(([k, label]) => {
      const box = svg("svg", { viewBox: "0 0 40 40", "aria-hidden": "true" }, svg("path", { class: "sq", d: "M8 9 L32 7.5 L33 31 L7.5 32.5 Z" }), svg("path", { class: "ck", d: "M11 20 L18 29 L36 3" }));
      ul.append(el("li", {}, el("label", {}, el("input", { type: "checkbox", id: "rv-" + k, checked: !!S.review.checks[k],
        onchange: (e) => { S.review.checks[k] = e.target.checked; if (e.target.checked) Sound.play("write"); save("review"); } }), el("span", { class: "bx" }, box), el("span", { text: label }))));
    });
    const outs = $("outs");
    outs.replaceChildren();
    [0, 1, 2].forEach((i) => outs.append(el("label", {}, el("span", { text: `${i + 1}.` }),
      el("input", { id: "oc-" + i, maxlength: "60", value: S.review.outcomes[i] || "", "aria-label": `Outcome ${i + 1}`,
        oninput: (e) => { S.review.outcomes[i] = e.target.value; save("review"); $("nbWeek").textContent = S.review.outcomes.filter((o) => o && o.trim()).join(" · "); if (Math.random() < .5) Sound.play("scratch"); } }))));
    $("sign").classList.remove("signed");
  }
  $("nbBtn").addEventListener("click", openBook);
  $("bookClose").addEventListener("click", closeSheets);
  $("signBtn").addEventListener("click", async () => {
    $("sign").classList.add("signed");
    Sound.play("write"); setTimeout(() => Sound.play("write"), 350); setTimeout(() => Sound.play("write"), 700);
    S.review.lastDone = tk(); S.review.checks = {};
    save("review");
    await wait(1300);
    closeSheets(); render();
    toast("Week closed. See you in seven days.");
  });

  /* ================= sheets ================= */
  let lastFocus = null, activeTab = "tasks";
  function showScrim() { const s = $("scrim"); s.hidden = false; requestAnimationFrame(() => s.classList.add("on")); }
  function openDrawer(tab) {
    lastFocus = document.activeElement;
    Sound.play("whoosh");
    showScrim();
    const d = $("drawer"); d.hidden = false;
    selectTab(tab || "tasks");
    renderDrawer();
    requestAnimationFrame(() => requestAnimationFrame(() => d.classList.add("on")));
  }
  function openBook() {
    lastFocus = document.activeElement;
    Sound.play("tick");
    showScrim();
    const b = $("book"); b.hidden = false;
    renderNotebook();
    b.classList.remove("opened");
    requestAnimationFrame(() => requestAnimationFrame(() => b.classList.add("on")));
    setTimeout(() => Sound.play("whoosh"), 200);
    setTimeout(() => b.classList.add("opened"), reduced ? 0 : 1300);
  }
  function closeSheets() {
    ["drawer", "book"].forEach((id) => { const x = $(id); if (!x.hidden) { x.classList.remove("on"); setTimeout(() => { x.hidden = true; }, 650); } });
    const s = $("scrim"); s.classList.remove("on"); setTimeout(() => { s.hidden = true; }, 420);
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }
  $("scrim").addEventListener("click", closeSheets);
  $("drawerClose").addEventListener("click", closeSheets);
  $("drawerFront").addEventListener("click", () => openDrawer());
  $("binBtn").addEventListener("click", () => { filter = "done"; openDrawer("tasks"); });
  addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !$("scrim").hidden) { closeSheets(); return; }
    const typing = e.target.closest && e.target.closest("input, textarea, select, [contenteditable]");
    if (!typing && $("scrim").hidden && (e.key === "n" || e.key === "N") && !e.metaKey && !e.ctrlKey && !e.altKey) { e.preventDefault(); tearNote(); }
  });
  function selectTab(name) {
    activeTab = name;
    ["tasks", "bills", "habits"].forEach((k) => { $("tab-" + k).setAttribute("aria-selected", String(k === name)); $("pane-" + k).hidden = k !== name; });
  }
  ["tasks", "bills", "habits"].forEach((k) => $("tab-" + k).addEventListener("click", () => { Sound.play("tick"); selectTab(k); renderDrawer(); }));

  /* ---- drawer: tasks as index cards ---- */
  let filter = null, editing = null;
  const FILTERS = [
    ["late", "Late", (t) => !t.done && !t.onDesk && isOverdue(t)],
    ["unsorted", "Unsorted", (t) => !t.done && !t.onDesk && !t.area],
    ["soon", "Next 14 days", (t) => !t.done && !t.onDesk && t.due >= tk() && t.due <= keyOf(addDays(today(), 14))],
    ["nodate", "No date", (t) => !t.done && !t.onDesk && !t.due && t.area],
    ["all", "Everything", (t) => !t.done && !t.onDesk],
    ["done", "Finished", (t) => t.done],
  ];
  function sortTasks(list) {
    return list.slice().sort((a, b) => a.done ? (b.doneAt || "").localeCompare(a.doneAt || "") : (a.due || "9999").localeCompare(b.due || "9999") || (a.created || "").localeCompare(b.created || ""));
  }
  function card(t) {
    const d = dueInfo(t.done ? "" : t.due);
    const full = freeSpots() === 0;
    const c = el("div", { class: "icard" + (t.done ? " done" : ""), style: `--tape:${TAPE[t.area] || "#d1d1d6"}` });
    if (editing === t.id) {
      const title = el("input", { class: "field", id: "ed-title-" + t.id, value: t.title, "aria-label": "Task" });
      const area = el("select", { class: "field", id: "ed-area-" + t.id, "aria-label": "Area" }, el("option", { value: "", text: "Unsorted" }), ...AREAS.map((a) => el("option", { value: a, text: a, selected: t.area === a })));
      const due = el("input", { class: "field", id: "ed-due-" + t.id, type: "date", value: t.due || "", "aria-label": "Due date" });
      c.append(el("div", { class: "editor" }, title, area, due, el("div", { class: "row" },
        el("button", { class: "btn", type: "button", text: "Save", onclick: () => { t.title = title.value.trim() || t.title; t.area = area.value; t.due = due.value; editing = null; save("tasks"); render(); } }),
        el("button", { class: "ghost", type: "button", text: "Delete", onclick: () => { S.tasks.items = S.tasks.items.filter((x) => x !== t); editing = null; save("tasks"); render(); toast("Deleted.", "Undo", () => { S.tasks.items.push(t); save("tasks"); render(); }); } }),
        el("button", { class: "link", type: "button", text: "Cancel", onclick: () => { editing = null; renderDrawer(); } }))));
      return c;
    }
    c.append(el("div", { class: "tt", text: t.title }),
      el("div", { class: "mt" }, el("span", { text: t.area || "Unsorted" }), d ? el("span", { class: "due " + d.cls, text: d.text }) : null, t.example ? el("span", { text: "example" }) : null));
    if (!t.area && !t.done) {
      const tri = el("div", { class: "triage", "aria-label": "File under" });
      AREAS.forEach((a) => tri.append(el("button", { type: "button", text: a, onclick: () => { t.area = a; Sound.play("tick"); save("tasks"); render(); } })));
      c.append(tri);
    }
    c.append(el("div", { class: "ac" },
      t.done
        ? el("button", { class: "ghost", type: "button", text: "Not done", onclick: () => { t.done = false; t.doneAt = ""; save("tasks"); render(); } })
        : el("button", { class: "btn", type: "button", disabled: full, title: full ? "The desk is full. Finish something first." : null, text: full ? "Desk is full" : "Put on desk",
            onclick: () => { if (toDesk(t)) { closeSheets(); setTimeout(() => { Sound.play("tear"); render(); }, 350); } } }),
      !t.done ? el("button", { class: "ghost", type: "button", text: "Done", onclick: () => { t.done = true; t.doneAt = tk(); save("tasks"); Sound.play("crumple"); render(); } }) : null,
      el("button", { class: "icon", type: "button", "aria-label": "Edit", text: "⋯", onclick: () => { editing = t.id; renderDrawer(); } })));
    return c;
  }
  function renderDrawer() {
    if ($("drawer").hidden) return;
    const inDrawer = open().filter((t) => !t.onDesk).length;
    $("drawerSub").textContent = freeSpots() ? `${inDrawer} waiting. ${freeSpots()} ${freeSpots() === 1 ? "spot" : "spots"} free on the desk.` : `${inDrawer} waiting. The desk is full; finish something to bring one up.`;
    const counts = Object.fromEntries(FILTERS.map(([k, , f]) => [k, S.tasks.items.filter(f).length]));
    if (!filter) filter = counts.late ? "late" : counts.unsorted ? "unsorted" : "all";
    $("chips").replaceChildren(...FILTERS.map(([k, label]) => el("button", { type: "button", "aria-pressed": String(filter === k), onclick: () => { filter = k; renderDrawer(); } }, label, el("span", { class: "n", text: String(counts[k]) }))));
    const f = FILTERS.find((x) => x[0] === filter)[2];
    const list = sortTasks(S.tasks.items.filter(f));
    const box = $("cards");
    box.replaceChildren(...list.map(card));
    if (!list.length) box.append(el("p", { class: "empty", text: { late: "Nothing late.", unsorted: "Everything is sorted.", soon: "Nothing due in the next two weeks.", nodate: "No undated tasks.", all: "The drawer is empty.", done: "Finished tasks stay here for 30 days." }[filter] }));
    if (S.tasks.items.some((t) => t.example)) box.append(el("p", { class: "empty" }, el("button", { class: "link", type: "button", text: "Remove the example tasks", onclick: () => { S.tasks.items = S.tasks.items.filter((t) => !t.example); save("tasks"); render(); } })));
    renderLedger(); renderHabitGrid();
  }
  $("capForm").addEventListener("submit", (e) => {
    e.preventDefault();
    const p = parseQuick($("capture").value, today());
    if (!p.title) return;
    S.tasks.items.push(Object.assign({ id: uid(), top: "", done: false, doneAt: "", created: tk(), onDesk: false }, p));
    $("capture").value = "";
    Sound.play("tick");
    save("tasks"); render();
  });

  /* ---- brain dump ---- */
  let sampleFn = null, sortCtl = null, sorted = [];
  const SAMPLE_COPY = {
    not_granted: "Claude isn’t allowed on this page, so sorting is off. Use “Add each line as a task”.",
    sampling_disabled: "Claude isn’t available on this account. Use “Add each line as a task”.",
    rate_limited: "Too many requests right now. Try again in a minute.",
    session_expired: "Sign in to claude.ai again, then try.",
    invalid_json: "The answer came back in the wrong shape. Try again.",
    refused: "Claude declined to sort this text. Try rewording it.",
    prompt_too_large: "That’s too much at once. Split it in two.",
  };
  const sampleError = (e) => SAMPLE_COPY[e && e.code] || "Something went wrong talking to Claude. Try again.";
  function hideSampleIfGone(e) { if (["not_granted", "sampling_disabled", "not_declared", "capability_disabled", "capability_removed"].includes(e && e.code)) { $("sortBtn").hidden = true; $("planBtn").hidden = true; } }
  $("splitBtn").addEventListener("click", () => {
    const lines = $("dump").value.split(/\n|;/).map((l) => l.trim()).filter(Boolean);
    if (!lines.length) return;
    lines.forEach((l) => S.tasks.items.push(Object.assign({ id: uid(), top: "", done: false, doneAt: "", created: tk(), onDesk: false }, parseQuick(l, today()))));
    $("dump").value = "";
    $("sortStatus").textContent = `${lines.length} things are in the drawer.`;
    filter = "unsorted"; save("tasks"); render();
  });
  $("sortBtn").addEventListener("click", async () => {
    const text = $("dump").value.trim();
    if (!text || !sampleFn) return;
    const t = today();
    const prompt = `Today is ${t.toLocaleDateString("en-US", { weekday: "long" })}, ${keyOf(t)}. Turn this brain dump into a clean task list.
Rules:
- One task per distinct action. Start each with a verb. At most 8 words, so it fits on a sticky note.
- "area" is exactly one of: ${AREAS.join(", ")}.
- "due" is YYYY-MM-DD only when the text names or implies a day or deadline (resolve "tomorrow", "Friday", "next week" against today). Otherwise "".
- "urgent" is true only when it has to happen today or is already late.
- Leave out feelings and non-actions. When a worry implies an action, write the action.
Reply with only a JSON array, like [{"title":"Pay the electricity bill","area":"Money","due":"${keyOf(addDays(t, 2))}","urgent":false}].

Brain dump:
"""
${text.slice(0, 8000)}
"""`;
    sortCtl = new AbortController();
    $("sortBtn").disabled = true; $("stopSort").hidden = false;
    $("sortStatus").textContent = "Sorting… this can take half a minute.";
    try {
      const out = await sampleFn.json(prompt, { signal: sortCtl.signal });
      sorted = (Array.isArray(out) ? out : []).filter((x) => x && x.title).slice(0, 40).map((x) => ({
        keep: true, title: String(x.title).slice(0, 90), area: AREAS.includes(x.area) ? x.area : "",
        due: /^\d{4}-\d{2}-\d{2}$/.test(x.due || "") ? x.due : (x.urgent ? keyOf(t) : ""), urgent: !!x.urgent,
      }));
      $("sortStatus").textContent = sorted.length ? `${sorted.length} tasks. Untick any you don’t want.` : "Didn’t find any actions in that.";
    } catch (e) { $("sortStatus").textContent = e && e.code !== "cancelled" ? sampleError(e) : ""; hideSampleIfGone(e); }
    $("sortBtn").disabled = false; $("stopSort").hidden = true;
    renderSorted();
  });
  $("stopSort").addEventListener("click", () => sortCtl && sortCtl.abort());
  function renderSorted() {
    const box = $("sorted");
    box.replaceChildren();
    if (!sorted.length) return;
    sorted.forEach((s, i) => box.append(el("div", { class: "srow" },
      el("input", { type: "checkbox", id: "keep-" + i, checked: s.keep, "aria-label": "Keep", onchange: (e) => { s.keep = e.target.checked; } }),
      el("input", { type: "text", class: "field", id: "st-" + i, value: s.title, "aria-label": "Task", oninput: (e) => { s.title = e.target.value; } }),
      el("select", { class: "field", id: "sa-" + i, "aria-label": "Area", onchange: (e) => { s.area = e.target.value; } }, el("option", { value: "", text: "Unsorted" }), ...AREAS.map((a) => el("option", { value: a, text: a, selected: s.area === a }))),
      el("input", { type: "date", class: "field", id: "sd-" + i, value: s.due, "aria-label": "Due", onchange: (e) => { s.due = e.target.value; } }))));
    box.append(el("div", { class: "row" },
      el("button", { class: "btn blue", type: "button", text: "Put them in the drawer", onclick: () => {
        const keep = sorted.filter((s) => s.keep && s.title.trim());
        let room = freeSpots(), placed = 0;
        keep.forEach((s) => {
          const onDesk = s.urgent && room > 0;
          if (onDesk) { room--; placed++; }
          S.tasks.items.push({ id: uid(), title: s.title.trim(), area: s.area, due: s.due, top: "", done: false, doneAt: "", created: tk(), onDesk, deskAt: onDesk ? Date.now() + placed : 0 });
        });
        $("sortStatus").textContent = placed ? `${keep.length} saved. ${placed} urgent ${placed === 1 ? "one is" : "ones are"} already on the desk.` : `${keep.length} saved in the drawer.`;
        sorted = []; $("dump").value = ""; save("tasks"); renderSorted(); render();
      } }),
      el("button", { class: "link", type: "button", text: "Discard", onclick: () => { sorted = []; renderSorted(); $("sortStatus").textContent = ""; } })));
  }

  /* ---- drawer: bills + habits ---- */
  function renderLedger() {
    $("currency").value = S.bills.currency;
    const ul = $("ledger");
    ul.replaceChildren();
    const rows = S.bills.items.map((b) => ({ b, d: billDue(b) })).sort((x, y) => x.d.days - y.d.days);
    if (!rows.length) ul.append(el("li", { style: "display:block" }, el("p", { class: "empty", text: "Add rent, phone, internet and subscriptions. They land in the letter tray a week before they’re due." })));
    rows.forEach(({ b, d }) => {
      const label = d.paid ? `Paid · next ${d.date.toLocaleDateString(undefined, { month: "short", day: "numeric" })}` : d.days < 0 ? `${-d.days}d overdue` : d.days === 0 ? "Due today" : `Due in ${d.days} days`;
      ul.append(el("li", {},
        el("div", { style: "min-width:0" }, el("div", { text: b.name }), el("div", { class: "due-s " + (d.paid ? "" : d.days < 0 ? "bad" : d.days <= 3 ? "warn" : ""), text: label })),
        el("span", { class: "amt", text: money(b.amount) }),
        el("button", { class: "ghost", type: "button", text: d.paid ? "Undo paid" : "Mark paid", onclick: () => { b.paid = b.paid || {}; if (d.paid) delete b.paid[d.month]; else { b.paid[d.month] = true; Sound.play("stamp"); } save("bills"); render(); } }),
        el("button", { class: "icon", type: "button", "aria-label": "Remove " + b.name, text: "✕", onclick: () => { S.bills.items = S.bills.items.filter((x) => x !== b); save("bills"); render(); } })));
    });
    const tot = $("totals");
    tot.replaceChildren();
    if (rows.length) {
      const all = rows.reduce((s, r) => s + (Number(r.b.amount) || 0), 0);
      const left = rows.filter((r) => !r.d.paid).reduce((s, r) => s + (Number(r.b.amount) || 0), 0);
      tot.append(el("span", {}, "Every month ", el("b", { text: money(all) })), el("span", {}, "Left to pay this month ", el("b", { text: money(left) })));
    }
  }
  $("currency").addEventListener("change", (e) => { S.bills.currency = e.target.value; save("bills"); render(); });
  $("billForm").addEventListener("submit", (e) => {
    e.preventDefault();
    const name = $("billName").value.trim();
    const amount = parseFloat($("billAmt").value.replace(/[^\d.]/g, ""));
    const day = parseInt($("billDay").value, 10);
    if (!name || !(amount >= 0) || !(day >= 1 && day <= 31)) { toast("Give it a name, an amount, and the day of the month it’s due."); return; }
    S.bills.items.push({ id: uid(), name, amount, day, paid: {} });
    $("billName").value = ""; $("billAmt").value = ""; $("billDay").value = "";
    save("bills"); render();
  });
  function renderHabitGrid() {
    const g = $("hgrid");
    g.replaceChildren();
    if (!S.habits.items.length) { g.style.display = "block"; g.append(el("p", { class: "empty", text: "No habits yet. Two or three is plenty." })); return; }
    g.style.display = "";
    const days = Array.from({ length: 7 }, (_, i) => addDays(today(), i - 6));
    g.append(el("span"));
    days.forEach((d) => g.append(el("span", { class: "dh", text: d.toLocaleDateString(undefined, { weekday: "narrow" }) })));
    g.append(el("span", { class: "dh", text: "run" }), el("span"));
    S.habits.items.forEach((h) => {
      g.append(el("span", { text: h.name, style: "min-width:0;overflow-wrap:anywhere" }));
      days.forEach((d) => {
        const k = keyOf(d), on = !!(h.log && h.log[k]);
        g.append(el("button", { class: "cell", type: "button", "aria-pressed": String(on), "aria-label": `${h.name}, ${d.toLocaleDateString(undefined, { weekday: "long" })}`,
          onclick: () => { h.log = h.log || {}; if (on) delete h.log[k]; else h.log[k] = true; Sound.play("tick"); save("habits"); render(); } }));
      });
      const n = streak(h);
      g.append(el("span", { class: "dh", text: n ? n + "d" : "–" }),
        el("button", { class: "icon", type: "button", "aria-label": "Remove " + h.name, text: "✕", onclick: () => { S.habits.items = S.habits.items.filter((x) => x !== h); save("habits"); render(); } }));
    });
  }
  $("habForm").addEventListener("submit", (e) => {
    e.preventDefault();
    const v = $("habName").value.trim();
    if (!v) return;
    S.habits.items.push({ id: uid(), name: v, log: {} });
    $("habName").value = "";
    save("habits"); render();
  });

  /* ================= phone ================= */
  let cal = { status: "idle", events: [] }, mcpNs = null, calUnsub = null, calKey = "";
  const CAL = "Google Calendar";
  function parseEvents(p) {
    const arr = Array.isArray(p) ? p : (p && (p.items || p.events)) || [];
    return arr.filter((e) => e && e.status !== "cancelled").map((e) => {
      const s = e.start || {}, en = e.end || {};
      return { title: e.summary || e.title || "(No title)", start: s.dateTime || e.startTime || "", end: en.dateTime || e.endTime || "",
        allDay: !!(s.date && !s.dateTime), link: typeof e.htmlLink === "string" && e.htmlLink.startsWith("https://") ? e.htmlLink : null };
    }).sort((a, b) => (a.allDay ? "" : a.start).localeCompare(b.allDay ? "" : b.start));
  }
  const CAL_DENIED = {
    needs_reauth: "Reconnect Google Calendar in claude.ai Settings → Connectors.",
    server_not_connected: "Add Google Calendar in claude.ai Settings → Connectors to see your day here.",
    selection_required: "Pick which Google Calendar to use when claude.ai asks, then reload.",
    not_in_manifest: "Calendar access is off for this page. Turn it on in the page’s permissions.",
    blocked_by_policy: "Your organization doesn’t allow calendar access here.",
  };
  const calInput = () => ({ startTime: tk() + "T00:00:00", endTime: keyOf(addDays(today(), 1)) + "T00:00:00", orderBy: "startTime", pageSize: 50 });
  function watchCalendar() {
    if (!mcpNs) return;
    const k = tk();
    if (k === calKey) return;
    calKey = k;
    if (calUnsub) calUnsub();
    cal = { status: "loading", events: [] };
    calUnsub = mcpNs.watchTool(CAL, "list_events", calInput(), (ev) => {
      if (ev.type === "data") cal = { status: "ok", events: parseEvents(ev.result.payload), at: (ev.result.cache && ev.result.cache.storedAt) || Date.now() };
      else {
        const code = ev.error && ev.error.code;
        if (CAL_DENIED[code]) cal = { status: "denied", events: [], msg: CAL_DENIED[code] };
        else if (code === "approval_required") cal = { status: "approval", events: [] };
        else if (cal.status === "ok") cal = Object.assign({}, cal, { stale: true });
        else cal = { status: "error", events: [], msg: "Couldn’t reach Google Calendar. Trying again in a few minutes." };
      }
      renderPhone();
    }, { refetchInterval: 5 * 60 * 1000 });
  }
  const hm = (s) => new Date(s).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
  function nextEvent() {
    const now = Date.now();
    return cal.status === "ok" ? cal.events.find((e) => !e.allDay && e.start && new Date(e.start) > now) : null;
  }
  function renderPhone() {
    const now = new Date();
    $("phDate").textContent = now.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });
    $("phTime").textContent = now.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" }).replace(/\s?[AP]M$/i, "");
    $("dayDow").textContent = now.toLocaleDateString(undefined, { weekday: "long", month: "short", day: "numeric" });
    const box = $("cal");
    box.replaceChildren();
    $("calStamp").textContent = cal.at ? (cal.stale ? "offline" : "") : "";
    const notif = $("phNotif");
    const nx = nextEvent();
    const mins = nx ? Math.round((new Date(nx.start) - now) / 60000) : null;
    if (nx && mins <= 120) {
      const key = nx.title + nx.start;
      if (notif.dataset.k !== key) {
        notif.dataset.k = key;
        notif.replaceChildren(el("div", { class: "notif" }, el("div", { class: "ic" }, el("small", { text: now.toLocaleDateString(undefined, { weekday: "short" }).toUpperCase() }), el("b", { text: String(now.getDate()) })),
          el("p", {}, el("b", { text: nx.title }), el("span", { id: "notifWhen" }))));
      }
      const w = $("notifWhen"); if (w) w.textContent = `${hm(nx.start)} · in ${mins < 60 ? mins + " min" : Math.floor(mins / 60) + " h " + (mins % 60) + " min"}`;
    } else { notif.replaceChildren(); notif.dataset.k = ""; }
    const msg = (t) => box.append(el("p", { class: "msg", text: t }));
    if (cal.status === "idle") msg("Your Google Calendar shows up here when this page is open on claude.ai.");
    else if (cal.status === "loading") msg("Loading today…");
    else if (cal.status === "denied" || cal.status === "error") msg(cal.msg);
    else if (cal.status === "approval") {
      msg("Google Calendar needs your OK first.");
      const b = el("button", { class: "chip", type: "button", text: "Show my day", style: "margin-top:8px;font-size:13px;padding:7px 14px;position:relative;z-index:8", onclick: async (e) => {
        e.stopPropagation();
        try { const r = await mcpNs.callTool(CAL, "list_events", calInput()); cal = { status: "ok", events: parseEvents(r.payload), at: Date.now() }; }
        catch (err) { cal = { status: "denied", events: [], msg: CAL_DENIED[err && err.code] || "Calendar access wasn’t allowed." }; }
        renderPhone();
      } });
      box.append(b);
    } else if (!cal.events.length) msg("Nothing on the calendar. The whole day is yours.");
    else {
      cal.events.slice(0, layoutName === "tall" ? 5 : 4).forEach((e) => {
        const past = !e.allDay && e.end && new Date(e.end) < now;
        const live = !e.allDay && e.start && new Date(e.start) <= now && (!e.end || new Date(e.end) > now);
        box.append(el("div", { class: "ev" + (past ? " past" : live ? " now" : "") }, el("div", {}, el("time", { text: e.allDay ? "All day" : hm(e.start) + (e.end ? " – " + hm(e.end) : "") }), e.title)));
      });
      if (cal.events.length > 4) box.append(el("p", { class: "msg", style: "color:#6e6e73;font-size:12px;margin-top:4px", text: `+${cal.events.length - 4} more · tap for the day` }));
    }
    renderTimeline();
    renderIsland();
  }
  function renderTimeline() {
    const tl = $("tl");
    tl.replaceChildren();
    const now = new Date();
    const evs = cal.status === "ok" ? cal.events.filter((e) => !e.allDay && e.start) : [];
    let h0 = Math.min(now.getHours() - 1, ...evs.map((e) => new Date(e.start).getHours()));
    h0 = clamp(h0, 0, 18);
    const h1 = Math.min(24, h0 + 10);
    const pos = (d) => ((d.getHours() + d.getMinutes() / 60 - h0) / (h1 - h0)) * 100;
    for (let h = h0; h <= h1; h++) {
      const lbl = new Date(2000, 0, 1, h % 24).toLocaleTimeString(undefined, { hour: "numeric" });
      tl.append(el("div", { class: "h", style: `top:${((h - h0) / (h1 - h0)) * 100}%` }, el("span", { text: lbl })));
    }
    evs.forEach((e) => {
      const s = new Date(e.start), en = e.end ? new Date(e.end) : new Date(s.getTime() + 30 * 60000);
      const top = pos(s), bot = pos(en);
      if (bot < 0 || top > 100) return;
      tl.append(el("div", { class: "blk", style: `top:${clamp(top, 0, 100)}%;height:${Math.max(3, clamp(bot, 0, 100) - clamp(top, 0, 100))}%` }, el("b", { text: e.title }), el("br"), hm(e.start)));
    });
    if (cal.status === "ok" && !evs.length) tl.append(el("p", { class: "msg", style: "position:absolute;left:46px;top:30%;color:#6e6e73", text: "No events today." }));
    tl.append(el("div", { class: "nowl", style: `top:${clamp(pos(now), 0, 100)}%` }));
  }
  $("phoneBtn").addEventListener("click", () => { $("phone").classList.toggle("open"); Sound.play("tick"); });

  /* ---- dynamic island ---- */
  let planning = false;
  function renderIsland() {
    const isl = $("island"), a = $("islandA"), b = $("islandB");
    let live = false;
    if (focus.end) {
      const left = Math.max(0, focus.end - Date.now());
      const m = Math.floor(left / 60000), s = Math.floor((left % 60000) / 1000);
      a.replaceChildren(el("span", { class: "ring", style: `--p:${(1 - left / focus.len) * 100}` }), "Focus");
      b.textContent = `${m}:${pad(s)}`;
      live = true;
    } else if (planning) {
      a.replaceChildren("✎ Writing your plan");
      b.textContent = "";
      live = true;
    } else {
      const nx = nextEvent();
      const mins = nx ? Math.round((new Date(nx.start) - Date.now()) / 60000) : null;
      if (nx && mins <= 30) { a.replaceChildren(el("span", { text: nx.title.slice(0, 14) })); b.textContent = `${mins}m`; live = true; }
    }
    isl.classList.toggle("live", live);
  }

  /* ================= focus: the AirPods ================= */
  const focus = { end: 0, len: 25 * 60000, timer: 0 };
  function startFocus() {
    focus.end = Date.now() + focus.len;
    $("airpods").classList.add("on");
    stage.classList.add("focusing");
    Sound.play("pop");
    Sound.focus(true);
    toast("Focus. 25 minutes. Only the notes matter now.", "Stop", stopFocus);
    focus.timer = setInterval(() => {
      if (Date.now() >= focus.end) {
        const mins = Math.round(focus.len / 60000);
        S.day = Object.assign(DOCS.day(), S.day.date === tk() ? S.day : { date: tk() }, { date: tk() });
        S.day.focus = (S.day.focus || 0) + mins;
        save("day");
        stopFocus(true);
        Sound.play("chime");
        toast(`Focus done. ${S.day.focus} minutes today.`);
      }
      renderIsland();
    }, 1000);
    renderIsland();
  }
  function stopFocus(silent) {
    clearInterval(focus.timer);
    focus.end = 0;
    $("airpods").classList.remove("on");
    stage.classList.remove("focusing");
    Sound.focus(false);
    if (silent !== true) toast("Focus stopped.");
    renderIsland();
  }
  $("podsBtn").addEventListener("click", () => (focus.end ? stopFocus() : startFocus()));

  /* ================= mug ================= */
  function renderMug() {
    const now = new Date();
    const mins = now.getHours() * 60 + now.getMinutes();
    $("mug").style.setProperty("--left", Math.max(.16, 1 - mins / 1440).toFixed(3));
  }
  $("mugBtn").addEventListener("click", () => {
    const m = $("mug");
    m.classList.remove("sip"); void m.offsetWidth; m.classList.add("sip");
    const now = new Date();
    const left = 1440 - (now.getHours() * 60 + now.getMinutes());
    const tip = $("mugtip");
    tip.textContent = `${Math.floor(left / 60)}h ${pad(left % 60)}m of today left. The coffee goes down with the day.`;
    const r = L.mug;
    tip.style.left = Math.max(10, r.x - (layoutName === "tall" ? 360 : 260)) + "px";
    tip.style.top = (r.y - (layoutName === "tall" ? 70 : 52)) + "px";
    tip.classList.add("on");
    clearTimeout(tip.t); tip.t = setTimeout(() => tip.classList.remove("on"), 3200);
  });

  /* ================= legal pad: the plan ================= */
  let planCtl = null, planLive = "";
  function renderPlan() {
    const p = $("plan");
    const text = planLive || (S.day.date === tk() ? S.day.plan : "");
    p.classList.toggle("faint", !text);
    p.replaceChildren(text ? text : sampleFn ? "Tap “Plan my day” and the rest of today gets written here, around your calendar and the notes on your desk." : "Day planning works when this page is open on claude.ai.");
    if (planLive) {
      const caret = el("span", { style: "display:inline-block;width:1px;height:1px" });
      p.append(caret);
      const r = L.legal;
      const x = r.x + 72 + caret.offsetLeft, y = r.y + 56 + caret.offsetTop;
      pen.classList.add("writing");
      pen.style.setProperty("--px", x + rand(-2, 2)); pen.style.setProperty("--py", y + 8 + rand(-2, 2)); pen.style.setProperty("--pr", `${-38 + rand(-3, 3)}deg`);
    }
  }
  $("planBtn").addEventListener("click", async () => {
    if (!sampleFn) return;
    const now = new Date();
    const t24 = (s) => new Date(s).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
    const evs = cal.status === "ok" ? (cal.events.map((e) => `- ${e.allDay ? "All day" : t24(e.start) + "–" + (e.end ? t24(e.end) : "")}: ${e.title}`).join("\n") || "(nothing)") : "(calendar not available)";
    const notes = deskNotes().map((t) => `- ${t.title}${t.due ? ` (${dueInfo(t.due).text})` : ""}`).join("\n") || "(desk is empty)";
    const late = sortTasks(open().filter((t) => !t.onDesk && t.due && t.due <= tk())).slice(0, 10).map((t) => `- ${t.title} (${dueInfo(t.due).text})`).join("\n") || "(none)";
    const habits = S.habits.items.filter((h) => !(h.log && h.log[tk()])).map((h) => `- ${h.name}`).join("\n") || "(all done)";
    const prompt = `It is ${t24(now)} on ${now.toLocaleDateString("en-US", { weekday: "long" })}. Plan the rest of my day. It will be handwritten on a legal pad, so keep every line short.

Calendar today:
${evs}

On my desk (what I committed to today):
${notes}

Due or late but still in the drawer:
${late}

Habits still to do today:
${habits}

Rules: start from now. Fit the desk notes into the gaps between events, hardest first. Add one break. If it won't all fit, say what waits.
Format: one line per block, "HH:MM  what" (start time only, under 28 characters per line). At most 8 lines. Then, only if needed, one line "Waits: ...". No intro, no closing line.`;
    planCtl = new AbortController();
    planning = true; renderIsland();
    $("planBtn").disabled = true; $("stopPlan").hidden = false;
    planLive = " "; renderPlan();
    let lastLen = 0;
    try {
      const { text } = await sampleFn(prompt, { signal: planCtl.signal, cache: false, onText: ({ text }) => { planLive = text; if (text.length - lastLen > 3) { Sound.play("scratch"); lastLen = text.length; } renderPlan(); } });
      S.day = Object.assign(DOCS.day(), S.day.date === tk() ? S.day : {}, { date: tk(), plan: text.trim() });
      save("day");
    } catch (e) { if (e && e.code !== "cancelled") toast(sampleError(e)); hideSampleIfGone(e); }
    planLive = ""; planning = false;
    $("planBtn").disabled = false; $("stopPlan").hidden = true;
    $("planBtn").textContent = "Plan again";
    penRest(); renderPlan(); renderIsland();
  });
  $("stopPlan").addEventListener("click", () => planCtl && planCtl.abort());

  /* ================= bin ================= */
  function renderBin() {
    const pile = $("pile");
    pile.replaceChildren();
    const n = doneToday().length;
    const w = L.bin.w * .86, c = w / 2;
    const size = layoutName === "tall" ? 64 : 56;
    for (let i = 0; i < Math.min(n, 12); i++) {
      const a = i * 2.4, r = Math.min(c - size / 2 - 8, 10 + Math.sqrt(i) * 17);
      const x = c + Math.cos(a) * r - size / 2, y = c + Math.sin(a) * r - size / 2;
      pile.append(el("i", { style: `left:${x}px;top:${y}px;width:${size}px;height:${size}px;background-image:${tex.balls[i % tex.balls.length]};transform:rotate(${i * 67}deg)` }));
    }
    const f = S.day.date === tk() ? S.day.focus || 0 : 0;
    $("binTag").textContent = n ? `${n} done today${f ? ` · ${f} min focus` : ""}` : "nothing finished yet";
    $("binBtn").setAttribute("aria-label", `${n} finished today. Open the list.`);
  }

  /* ================= render ================= */
  function render() {
    if (dragging || finishing) { pendingRender = true; return; }
    renderSummary(); renderCalendarBlock(false); renderNotes(); renderTray(); renderHabitCard(); renderNotebook(); renderPhone(); renderPlan(); renderBin(); renderMug(); renderDrawer();
  }

  /* ================= boot ================= */
  makeTextures();
  buildLeaves();
  buildPlant();
  renderSoundBtn();
  setLight();
  applyLayout();
  const lastCal = lsGet("clear-desk-cal");
  renderCalendarBlock(lastCal !== tk());
  lsSet("clear-desk-cal", tk());
  setTimeout(() => stage.classList.remove("boot"), 2000);
  setInterval(() => { if (pendingRender && !dragging && !finishing) { pendingRender = false; render(); } }, 500);

  connectStore();
  if (window.claude && window.claude.use) {
    claude.use("sample").then((s) => { sampleFn = s; $("sortBtn").hidden = !s; $("planBtn").hidden = !s; renderPlan(); });
    claude.use("mcp").then((m) => { mcpNs = m; if (m) watchCalendar(); else { cal = { status: "denied", events: [], msg: "Calendar isn’t available in this view." }; renderPhone(); } });
  }

  let lastDay = tk();
  setInterval(() => {
    setLight(); renderMug(); renderPhone();
    if (tk() !== lastDay) { lastDay = tk(); renderCalendarBlock(true); watchCalendar(); render(); }
  }, 30000);
  window.__desk = { parseQuick, S };
})();
