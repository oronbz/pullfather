import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const T = JSON.parse(fs.readFileSync(path.join(here, '../src/timeline.json'), 'utf8'));
const C = T.cues;
const SR = 48000;
const N = Math.ceil(T.duration * SR);
const BEAT = 60 / T.bpm;
const BAR = BEAT * 3;
const W0 = T.waltzStart;
const bar = (k, beat = 0) => W0 + k * BAR + beat * BEAT;

let seed = 1937;
const rnd = () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const rn = () => rnd() * 2 - 1;

const NOTE = { C: 0, 'C#': 1, Db: 1, D: 2, 'D#': 3, Eb: 3, E: 4, F: 5, 'F#': 6, Gb: 6, G: 7, 'G#': 8, Ab: 8, A: 9, 'A#': 10, Bb: 10, B: 11 };
const hz = (name) => {
  const m = /^([A-G][b#]?)(-?\d)$/.exec(name);
  return 440 * 2 ** ((NOTE[m[1]] + (Number(m[2]) + 1) * 12 - 69) / 12);
};

const bus = () => [new Float32Array(N), new Float32Array(N)];
const music = bus();
const sfx = bus();
const amb = bus();
const send = bus();

function add(b, t, sig, gain = 1, pan = 0, wet = 0) {
  const s0 = Math.round(t * SR);
  const gl = gain * Math.cos(((pan + 1) * Math.PI) / 4);
  const gr = gain * Math.sin(((pan + 1) * Math.PI) / 4);
  for (let i = 0; i < sig.length; i++) {
    const j = s0 + i;
    if (j < 0 || j >= N) continue;
    b[0][j] += sig[i] * gl;
    b[1][j] += sig[i] * gr;
    if (wet) {
      send[0][j] += sig[i] * gl * wet;
      send[1][j] += sig[i] * gr * wet;
    }
  }
}

const len = (d) => Math.max(1, Math.floor(d * SR));
const white = (d) => Float32Array.from({ length: len(d) }, rn);
function brown(d) {
  const o = new Float32Array(len(d));
  let v = 0;
  for (let i = 0; i < o.length; i++) {
    v = (v + 0.02 * rn()) * 0.998;
    o[i] = v * 3.5;
  }
  return o;
}

function coeffs(type, f, q) {
  const w = (2 * Math.PI * Math.min(f, SR * 0.45)) / SR;
  const cs = Math.cos(w);
  const a = Math.sin(w) / (2 * q);
  let b0, b1, b2;
  if (type === 'lp') [b0, b1, b2] = [(1 - cs) / 2, 1 - cs, (1 - cs) / 2];
  else if (type === 'hp') [b0, b1, b2] = [(1 + cs) / 2, -(1 + cs), (1 + cs) / 2];
  else [b0, b1, b2] = [a, 0, -a];
  const a0 = 1 + a;
  return [b0 / a0, b1 / a0, b2 / a0, (-2 * cs) / a0, (1 - a) / a0];
}

function filt(sig, type, f, q = 0.707) {
  const fAt = typeof f === 'function' ? f : () => f;
  let c = coeffs(type, fAt(0), q);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < sig.length; i++) {
    if (typeof f === 'function' && i % 32 === 0) c = coeffs(type, fAt(i / SR), q);
    const x = sig[i];
    const y = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2;
    x2 = x1; x1 = x; y2 = y1; y1 = y;
    sig[i] = y;
  }
  return sig;
}

function env(sig, fn) {
  for (let i = 0; i < sig.length; i++) sig[i] *= fn(i / SR, sig.length / SR);
  return sig;
}
const expDecay = (tau) => (t) => Math.exp(-t / tau);
const ar = (a, r) => (t, d) => Math.min(1, t / a) * Math.min(1, Math.max(0, (d - t) / r));

function pluck(f, dur, { decay = 0.996, bright = 0.55 } = {}) {
  const n = len(dur);
  const y = new Float32Array(n);
  const D = SR / f - 0.5;
  const P = Math.ceil(D);
  const burst = new Float32Array(P);
  let lp = 0, mean = 0;
  for (let i = 0; i < P; i++) { lp += bright * (rn() - lp); burst[i] = lp; mean += lp; }
  mean /= P;
  const at = (x) => {
    if (x < 0) return 0;
    const i = Math.floor(x);
    const fr = x - i;
    return y[i] * (1 - fr) + (i + 1 < n ? y[i + 1] : 0) * fr;
  };
  for (let i = 0; i < n; i++) {
    const x = i < P ? burst[i] - mean : 0;
    y[i] = x + decay * 0.5 * (at(i - D) + at(i - D - 1));
  }
  const fade = Math.min(n, 480);
  for (let i = 0; i < fade; i++) y[n - 1 - i] *= i / fade;
  return y;
}

function polyblep(t, dt) {
  if (t < dt) { t /= dt; return t + t - t * t - 1; }
  if (t > 1 - dt) { t = (t - 1) / dt; return t * t + t + t + 1; }
  return 0;
}

function pad(t0, dur, notes, amp, { attack = 0.5, release = 0.8, cutoff = 1300, pan = 0, wet = 0.5, b = music, vib = 0.003 } = {}) {
  const n = len(dur + release);
  const o = new Float32Array(n);
  for (const name of notes) {
    const f = hz(name);
    for (const det of [-0.0045, 0, 0.0052]) {
      let ph = rnd();
      const lfo = rnd() * 6;
      for (let i = 0; i < n; i++) {
        const inc = (f * (1 + det + vib * Math.sin(lfo + (i / SR) * 5.1))) / SR;
        ph += inc;
        if (ph >= 1) ph -= 1;
        o[i] += 2 * ph - 1 - polyblep(ph, inc);
      }
    }
  }
  filt(o, 'lp', cutoff, 0.6);
  filt(o, 'lp', cutoff * 1.6, 0.6);
  env(o, (t) => Math.min(1, t / attack) ** 2 * (t < dur ? 1 : Math.max(0, 1 - (t - dur) / release)));
  add(b, t0, o, amp / Math.sqrt(notes.length * 3), pan, wet);
}

function tremolo(t0, name, dur, amp, { pan = -0.2, fadeTo = 1, rate = 11.5 } = {}) {
  const f = hz(name);
  let t = 0, k = 0;
  while (t < dur) {
    const shape = 1 + (fadeTo - 1) * (t / dur);
    const a = amp * shape * (k % 2 ? 0.72 : 1) * (0.85 + 0.3 * rnd()) * (k === 0 ? 1.35 : 1);
    add(music, t0 + t, pluck(f, 0.45, { decay: 0.993, bright: 0.62 }), a * 0.5, pan - 0.05, 0.35);
    add(music, t0 + t + 0.004, pluck(f * 1.0035, 0.45, { decay: 0.993, bright: 0.62 }), a * 0.5, pan + 0.05, 0.35);
    k++;
    t += (1 / rate) * (0.9 + 0.2 * rnd());
  }
}

function bass(t0, name, amp) {
  const s = filt(pluck(hz(name), 1.3, { decay: 0.997, bright: 0.3 }), 'lp', 700);
  add(music, t0, s, amp, 0, 0.15);
}

function chunk(t0, notes, amp) {
  notes.forEach((name, i) => add(music, t0 + i * 0.009, pluck(hz(name), 0.35, { decay: 0.985, bright: 0.5 }), amp, 0.3, 0.25));
}

function bell(t0, name, amp, { b = music, pan = 0, wet = 0.7 } = {}) {
  const f = hz(name);
  const o = new Float32Array(len(3));
  [[1, 1, 2.2], [3.93, 0.22, 0.7], [9.2, 0.06, 0.25], [2.02, 0.1, 1.1]].forEach(([r, a, tau]) => {
    for (let i = 0; i < o.length; i++) o[i] += a * Math.sin((2 * Math.PI * f * r * i) / SR) * Math.exp(-i / SR / tau);
  });
  for (let i = 0; i < 96; i++) o[i] *= i / 96;
  add(b, t0, o, amp, pan, wet);
}

function theremin(t0, path, dur, amp) {
  const n = len(dur);
  const o = new Float32Array(n);
  let ph = 0, f = hz(path[0][1]);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    let target = f;
    for (const [pt, name] of path) if (t >= pt) target = hz(name);
    f += (target - f) * 0.00012;
    const fv = f * (1 + 0.012 * Math.sin(2 * Math.PI * 5.6 * t));
    ph += (2 * Math.PI * fv) / SR;
    o[i] = Math.sin(ph) + 0.18 * Math.sin(2 * ph) + 0.05 * Math.sin(3 * ph);
  }
  env(o, ar(1.2, 1.4));
  add(music, t0, o, amp, 0.25, 0.9);
}

function boom(t0, amp, { from = 120, to = 38, tau = 0.9, b = music, wet = 0.4 } = {}) {
  const n = len(tau * 5);
  const o = new Float32Array(n);
  let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    ph += (2 * Math.PI * (to + (from - to) * Math.exp(-t / 0.12))) / SR;
    o[i] = Math.tanh(1.6 * Math.sin(ph)) * Math.exp(-t / tau);
  }
  const nz = env(filt(white(0.25), 'lp', 900), expDecay(0.05));
  for (let i = 0; i < nz.length; i++) o[i] += nz[i] * 0.6;
  add(b, t0, o, amp, 0, wet);
}

function cymbal(t0, amp, tau = 1.8) {
  const s = env(filt(filt(white(tau * 4), 'hp', 4500), 'lp', 11000), (t) => Math.exp(-t / tau) * Math.min(1, t / 0.004));
  add(music, t0, s, amp, 0.15, 0.5);
}

function click(t0, amp, { f = 2600, q = 2, tau = 0.006, b = sfx, pan = 0, wet = 0.1 } = {}) {
  add(b, t0, env(filt(white(tau * 8), 'bp', f, q), expDecay(tau)), amp, pan, wet);
}

function typewriterKey(t0, amp, space = false) {
  const p = rn() * 0.3;
  if (space) {
    click(t0, amp * 0.9, { f: 900, q: 1.2, tau: 0.012, pan: p });
  } else {
    click(t0, amp, { f: 2400 + 900 * rnd(), q: 1.8, tau: 0.007, pan: p });
    click(t0 + 0.012, amp * 0.5, { f: 1200, q: 1, tau: 0.01, pan: p });
    const ping = new Float32Array(len(0.05));
    const pf = 3800 + 800 * rnd();
    for (let i = 0; i < ping.length; i++) ping[i] = Math.sin((2 * Math.PI * pf * i) / SR) * Math.exp(-i / SR / 0.012);
    add(sfx, t0 + 0.003, ping, amp * 0.12, p, 0.1);
  }
  const body = new Float32Array(len(0.05));
  for (let i = 0; i < body.length; i++) body[i] = Math.sin((2 * Math.PI * 160 * i) / SR) * Math.exp(-i / SR / 0.012);
  add(sfx, t0, body, amp * 0.5, p, 0.05);
}

function typeText(cue, amp) {
  [...cue.text].forEach((ch, i) => typewriterKey(cue.start + i * cue.perChar + rn() * 0.004, amp * (0.8 + 0.3 * rnd()), ch === ' '));
}

function whoosh(t0, dur, amp, flutter = 0) {
  const s = filt(white(dur + 0.1), 'bp', (t) => 250 * (12 ** Math.min(1, t / dur)), 1.4);
  env(s, (t) => (Math.min(1, t / dur) ** 2) * (t < dur ? 1 : Math.max(0, 1 - (t - dur) / 0.1)) * (flutter ? 0.55 + 0.45 * Math.sin(2 * Math.PI * flutter * t * (0.5 + t / dur)) : 1));
  add(sfx, t0, s, amp, 0, 0.3);
}

function slap(t0, amp) {
  click(t0, amp, { f: 1500, q: 0.8, tau: 0.045, wet: 0.35 });
  boom(t0, amp * 0.8, { from: 160, to: 55, tau: 0.18, b: sfx, wet: 0.3 });
}

function projector(t0, t1, amp) {
  let t = t0;
  let k = 0;
  while (t < t1) {
    click(t, amp * (k % 2 ? 0.55 : 1) * (0.7 + 0.5 * rnd()), { f: 1800 + 1400 * rnd(), q: 1.3, tau: 0.004, b: amb, wet: 0 });
    t += 1 / 24 + rn() * 0.002;
    k++;
  }
  const n = len(t1 - t0);
  const o = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const tt = i / SR;
    const w = 1 + 0.01 * Math.sin(2 * Math.PI * 0.7 * tt);
    o[i] = 0.5 * Math.sin(2 * Math.PI * 48 * w * tt) + 0.3 * Math.sin(2 * Math.PI * 96 * w * tt) + 0.12 * Math.sin(2 * Math.PI * 144 * w * tt);
  }
  env(o, ar(0.05, 0.05));
  add(amb, t0, o, amp * 0.35);
}

function staticBed(t0, dur, amp) {
  const s = filt(filt(white(dur), 'hp', 900), 'lp', 5200);
  let g = 0.5;
  env(s, (t, d) => {
    g += (rnd() - 0.5) * 0.02;
    g = Math.max(0.25, Math.min(1, g));
    return g * (0.8 + 0.2 * Math.sin(2 * Math.PI * 0.37 * t)) * ar(0.8, 0.8)(t, d);
  });
  add(amb, t0, s, amp, 0.1);
}

function tuning(t0, amp) {
  const d = 0.9;
  const n = len(d);
  const o = new Float32Array(n);
  let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const f = 3200 * 0.12 ** (t / d) + 180 * Math.sin(2 * Math.PI * 7 * t);
    ph += (2 * Math.PI * f) / SR;
    o[i] = Math.sin(ph) * 0.35;
  }
  const nz = filt(white(d), 'bp', (t) => 3500 * 0.2 ** (t / d), 0.9);
  for (let i = 0; i < n; i++) o[i] = (o[i] + nz[i] * 1.6) * Math.sin((Math.PI * i) / n) ** 0.7;
  add(amb, t0, o, amp, -0.1, 0.2);
}

function crackle(amp) {
  const s = new Float32Array(N);
  for (let i = 0; i < N; i++) {
    if (rnd() < 18 / SR) s[i] += rn() * (rnd() < 0.08 ? 1 : 0.25);
  }
  filt(s, 'hp', 1500);
  const hiss = filt(filt(white(T.duration), 'hp', 3000), 'lp', 9000);
  for (let i = 0; i < N; i++) s[i] = s[i] * 2 + hiss[i] * 0.05;
  add(amb, 0, s, amp);
}

function rain(t0, dur, amp) {
  const s = filt(filt(white(dur), 'hp', 500), 'lp', 5500);
  for (let i = 0; i < s.length; i++) if (rnd() < 40 / SR) {
    const f = 2200 + 2400 * rnd(), a = 0.4 + rnd();
    for (let j = 0; j < 600 && i + j < s.length; j++) s[i + j] += a * Math.sin((2 * Math.PI * f * j) / SR) * Math.exp(-j / 90);
  }
  env(s, ar(1.2, 1.0));
  add(amb, t0, s, amp, 0, 0.1);
}

function thunder(t0, amp) {
  add(amb, t0, env(filt(white(0.5), 'hp', 900), expDecay(0.06)), amp * 0.9, -0.3, 0.6);
  const r = filt(brown(5), 'lp', 220);
  let bump = 1;
  env(r, (t) => {
    if (rnd() < 0.0004) bump = 0.6 + rnd() * 0.9;
    return Math.min(1, t / 0.35) * Math.exp(-t / 1.6) * bump;
  });
  add(amb, t0 + 0.08, r, amp * 1.4, 0.2, 0.5);
}

function hum(t0, dur, amp) {
  const n = len(dur);
  const o = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    o[i] = [60, 120, 180, 240].reduce((acc, f, k) => acc + Math.sin(2 * Math.PI * f * t) / (k + 1), 0);
  }
  env(o, ar(0.02, 1.5));
  add(sfx, t0, o, amp, 0, 0.2);
}

function radioVoice(t0, amp) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-'));
  const aiff = path.join(tmp, 'v.aiff');
  const wav = path.join(tmp, 'v.wav');
  execFileSync('say', ['-v', 'Daniel', '-r', '165', '-o', aiff, 'Calling all cars. Calling all cars. Pull request four-twelve... still waiting on review.']);
  execFileSync('afconvert', ['-f', 'WAVE', '-d', `LEI16@${SR}`, '-c', '1', aiff, wav]);
  const buf = fs.readFileSync(wav);
  let off = 12;
  while (buf.toString('ascii', off, off + 4) !== 'data') off += 8 + buf.readUInt32LE(off + 4);
  const size = buf.readUInt32LE(off + 4);
  const v = new Float32Array(size / 2);
  for (let i = 0; i < v.length; i++) v[i] = buf.readInt16LE(off + 8 + i * 2) / 32768;
  filt(v, 'hp', 450, 0.9);
  filt(v, 'lp', 2600, 0.9);
  filt(v, 'hp', 450, 0.9);
  filt(v, 'lp', 2600, 0.9);
  for (let i = 0; i < v.length; i++) {
    const t = i / SR;
    v[i] = Math.tanh(v[i] * 9) * (0.75 + 0.25 * Math.sin(2 * Math.PI * 3.3 * t));
  }
  console.log(`radio voice ${(v.length / SR).toFixed(2)}s`);
  add(amb, t0, v, amp, -0.15, 0.25);
  staticBed(t0 - 0.3, v.length / SR + 0.6, amp * 0.25);
  return v.length / SR;
}

function freeverb(inL, inR, { room = 0.86, damp = 0.35 } = {}) {
  const sc = SR / 44100;
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
  const aps = [556, 441, 341, 225];
  const run = (spread) => {
    const cb = combs.map((c) => ({ b: new Float32Array(Math.round((c + spread) * sc)), i: 0, f: 0 }));
    const ab = aps.map((a) => ({ b: new Float32Array(Math.round((a + spread) * sc)), i: 0 }));
    const out = new Float32Array(N);
    for (let n = 0; n < N; n++) {
      const x = (inL[n] + inR[n]) * 0.015;
      let y = 0;
      for (const c of cb) {
        const o = c.b[c.i];
        c.f = o * (1 - damp) + c.f * damp;
        c.b[c.i] = x + c.f * room;
        c.i = (c.i + 1) % c.b.length;
        y += o;
      }
      for (const a of ab) {
        const o = a.b[a.i];
        const z = -y + o;
        a.b[a.i] = y + o * 0.5;
        a.i = (a.i + 1) % a.b.length;
        y = z;
      }
      out[n] = y;
    }
    return out;
  };
  return [run(0), run(23)];
}

const S = T.scenes;

crackle(0.05);
projector(0, S.leader[1] + 0.3, 0.5);
projector(S.leader[1] + 0.3, C.runout, 0.06);
projector(C.runout, T.duration, 0.45);
[0.0, 0.3, 0.55, 0.76].forEach((d) => slap(C.runout + d, 0.35 - d * 0.2));

C.countdown.forEach((t) => {
  const o = new Float32Array(len(0.08));
  for (let i = 0; i < o.length; i++) o[i] = Math.sin((2 * Math.PI * 1000 * i) / SR) * Math.min(1, (o.length - i) / 200);
  add(sfx, t + 0.02, o, 0.22);
});
whoosh(2.9, 0.35, 0.2, 0);

C.tuning.forEach((t) => tuning(t, 0.28));
staticBed(3.9, S.city[1] - 3.9 + 0.5, 0.06);
staticBed(S.papers[1], T.duration - S.papers[1], 0.022);
radioVoice(C.radioVoice, 0.2);

rain(S.city[0], S.city[1] - S.city[0] + 0.5, 0.08);
thunder(C.thunderFlash + 0.1, 0.9);

C.paperSpins.forEach(([a, b]) => {
  whoosh(a, b - a, 0.45, 5);
  slap(b, 0.7);
});

C.stamps.forEach((t) => {
  slap(t, 0.6);
  boom(t, 0.5, { from: 200, to: 70, tau: 0.12, b: sfx, wet: 0.3 });
});
C.arrowKeys.forEach((t) => click(t, 0.3, { f: 1400, q: 1, tau: 0.008 }));
click(C.enterRow, 0.4, { f: 1100, q: 1, tau: 0.012 });

click(C.spotlight, 0.9, { f: 3200, q: 3, tau: 0.01, wet: 0.8 });
boom(C.spotlight, 0.8, { from: 90, to: 45, tau: 0.35, b: sfx, wet: 0.9 });
hum(C.spotlight, S.reveal[1] - C.spotlight, 0.035);

typeText(C.tagline, 0.3);
bell(C.tagline.start + C.tagline.text.length * C.tagline.perChar + 0.15, 'F6', 0.12, { b: sfx, wet: 0.3 });

click(C.glyphClick, 0.4, { f: 3500, q: 2, tau: 0.004 });
click(C.glyphClick + 0.07, 0.3, { f: 3000, q: 2, tau: 0.004 });
whoosh(C.glyphClick + 0.02, 0.18, 0.08);
click(C.refresh, 0.25, { f: 3500, q: 2, tau: 0.004 });
bell(C.arrival, 'E6', 0.16, { b: sfx, wet: 0.4, pan: 0.4 });
bell(C.arrival + 0.12, 'B6', 0.13, { b: sfx, wet: 0.4, pan: 0.4 });
C.keyPresses.forEach((t) => {
  click(t, 0.45, { f: 1400, q: 1, tau: 0.01 });
  click(t + 0.06, 0.2, { f: 2000, q: 1.5, tau: 0.006 });
});
whoosh(C.popoverReopen - 0.05, 0.16, 0.08);

typeText(C.terminal, 0.22);
click(C.enter, 0.55, { f: 1100, q: 1, tau: 0.018, wet: 0.3 });

pad(S.presents[0], C.spotlight - S.presents[0], ['C2', 'G2'], 0.35, { attack: 3, release: 0.05, cutoff: 500, wet: 0.6 });
pad(S.city[0], C.spotlight - S.city[0], ['Eb3'], 0.16, { attack: 3, release: 0.05, cutoff: 800, wet: 0.7 });
pad(C.paperSpins[1][0], C.spotlight - C.paperSpins[1][0], ['Db3'], 0.14, { attack: 2, release: 0.05, cutoff: 900, wet: 0.7 });
pad(21.9, C.spotlight - 21.9, ['C3', 'Db3', 'G3', 'C4'], 0.45, { attack: 1.4, release: 0.03, cutoff: 2400, wet: 0.5 });
const riser = filt(white(1.4), 'bp', (t) => 200 * 20 ** (t / 1.4), 2);
env(riser, (t) => (t / 1.4) ** 2);
add(music, 21.9, riser, 0.5, 0, 0.3);

[['G5', 4.6], ['Ab5', 5.5], ['G5', 6.4], ['D5', 7.4], ['Eb5', 12.0], ['D5', 12.9], ['C5', 13.8], ['B4', 14.9]].forEach(([n, t]) => bell(t, n, 0.13));
theremin(10.6, [[0, 'C5'], [1.8, 'Eb5'], [3.1, 'D5'], [4.3, 'B4']], 5.2, 0.05);

for (let t = S.papers[0], k = 0; t < C.spotlight - 0.05; t += BEAT, k++) {
  const late = t >= C.paperSpins[1][0];
  const name = k % 4 === 3 ? (late ? 'Db2' : 'G1') : 'C2';
  bass(t, name, 0.35 + 0.35 * ((t - S.papers[0]) / (C.spotlight - S.papers[0])));
  bell(t, 'C7', 0.015, { wet: 0.2 });
}

for (let k = 0; k < 14; k++) {
  const t = C.titleSlam - 0.7 + k * 0.05;
  boom(t, 0.08 + k * 0.02, { from: 90, to: 65, tau: 0.25 });
}

boom(C.titleSlam, 1.1, { from: 140, to: 40, tau: 1.1 });
cymbal(C.titleSlam, 0.25, 2.2);
pad(C.titleSlam, 1.2, ['C3', 'Eb3', 'G3', 'C4'], 0.5, { attack: 0.01, release: 1.6, cutoff: 2600, wet: 0.7 });
chunk(C.titleSlam, ['C3', 'G3', 'C4', 'Eb4', 'G4'], 0.35);

const CH = {
  Cm: { root: 'C2', v: ['C3', 'Eb3', 'G3'], pad: ['C3', 'Eb3', 'G3'] },
  Fm: { root: 'F2', v: ['F3', 'Ab3', 'C4'], pad: ['F2', 'C3', 'Ab3'] },
  Ab: { root: 'Ab1', v: ['Ab3', 'C4', 'Eb4'], pad: ['Ab2', 'Eb3', 'C4'] },
  G7: { root: 'G1', v: ['G3', 'B3', 'F4'], pad: ['G2', 'B2', 'F3'] },
  Db: { root: 'Db2', v: ['Db3', 'F3', 'Ab3'], pad: ['Db3', 'F3', 'Ab3'] },
};
const PROG = ['Cm', 'Cm', 'Fm', 'Cm', 'Ab', 'Fm', 'G7', 'G7', 'Cm', 'Cm', 'Fm', 'Db', 'Ab', 'Fm', 'G7', 'G7', 'Cm', 'G7', 'Ab', 'G7'];
const MELODY = [
  [0, 0, 'G4', 2], [0, 2, 'C5', 1],
  [1, 0, 'Eb5', 1], [1, 1, 'D5', 1], [1, 2, 'C5', 1],
  [2, 0, 'Ab4', 2], [2, 2, 'C5', 1],
  [3, 0, 'G4', 3],
  [4, 0, 'Eb5', 2], [4, 2, 'C5', 1],
  [5, 0, 'F5', 1], [5, 1, 'Eb5', 1], [5, 2, 'C5', 1],
  [6, 0, 'D5', 2], [6, 2, 'B4', 1],
  [7, 0, 'G4', 2], [7, 2, 'F4', 1],
  [8, 0, 'G4', 1], [8, 1, 'C5', 1], [8, 2, 'Eb5', 1],
  [9, 0, 'G5', 2], [9, 2, 'F5', 0.5], [9, 2.5, 'Eb5', 0.5],
  [10, 0, 'F5', 2], [10, 2, 'Ab4', 1],
  [11, 0, 'Db5', 2], [11, 2, 'C5', 1],
  [12, 0, 'C5', 2], [12, 2, 'Eb5', 1],
  [13, 0, 'F5', 1], [13, 1, 'Ab5', 1], [13, 2, 'G5', 1],
  [14, 0, 'F5', 2], [14, 2, 'D5', 1],
  [15, 0, 'G4', 1], [15, 1, 'B4', 1], [15, 2, 'D5', 1],
  [16, 0, 'C5', 3],
  [17, 0, 'B4', 2], [17, 2, 'D5', 1],
  [18, 0, 'C5', 1], [18, 1, 'Eb5', 1], [18, 2, 'Ab5', 1],
  [19, 0, 'G5', 2], [19, 2, 'F5', 0.5], [19, 2.5, 'D5', 0.5],
];

PROG.forEach((name, k) => {
  const ch = CH[name];
  const breakdown = k === 16 || k === 17;
  const start = k === 0 ? 1 : 0;
  pad(bar(k), BAR, ch.pad, breakdown ? 0.3 : 0.22, { attack: 0.35, release: 0.5, cutoff: 1100, wet: 0.5 });
  if (breakdown) return;
  const lift = k >= 18 ? 1.15 : 1;
  if (start === 0) bass(bar(k), ch.root, 0.9 * lift);
  chunk(bar(k, 1), ch.v, 0.28 * lift);
  chunk(bar(k, 2), ch.v, 0.23 * lift);
  if (k === 19) bass(bar(k, 2), 'D2', 0.4);
});

MELODY.forEach(([k, b, n, beats]) => {
  const breakdown = k === 16 || k === 17;
  tremolo(bar(k, b), n, beats * BEAT - 0.03, breakdown ? 0.55 : 0.8);
});
cymbal(bar(8), 0.1, 1.6);
cymbal(bar(14), 0.1, 1.6);
cymbal(bar(18), 0.12, 1.6);

const F = C.finalChord;
const ring = C.irisClose[1] - F;
tremolo(F, 'C5', ring, 0.75, { fadeTo: 0.05 });
tremolo(F + 0.02, 'G4', ring, 0.5, { fadeTo: 0.05, pan: 0.1 });
tremolo(F + 0.04, 'Eb5', ring, 0.48, { fadeTo: 0.05, pan: -0.3 });
bass(F, 'C2', 0.7);
boom(F, 0.9, { from: 110, to: 42, tau: 1.3 });
cymbal(F, 0.22, 2.6);
pad(F, ring - 1.5, ['C2', 'G2', 'C3', 'Eb3', 'G3', 'C4'], 0.5, { attack: 0.05, release: 2.2, cutoff: 1800, wet: 0.7 });

const mix = [new Float32Array(N), new Float32Array(N)];
for (const ch of [0, 1]) {
  filt(music[ch], 'hp', 70);
  filt(music[ch], 'lp', 7800, 0.6);
}
const [vl, vr] = freeverb(send[0], send[1]);
const stats = (name, b) => {
  let pk = 0, ss = 0;
  for (const ch of b) for (let i = 0; i < N; i++) { pk = Math.max(pk, Math.abs(ch[i])); ss += ch[i] * ch[i]; }
  console.log(`${name.padEnd(6)} peak ${pk.toFixed(3)} rms ${Math.sqrt(ss / (2 * N)).toFixed(4)}`);
};
stats('music', music);
stats('sfx', sfx);
stats('amb', amb);
stats('verb', [vl, vr]);
const rows = Object.entries(S).map(([k, [a, b]]) => {
  const r = (bb) => { let ss = 0; const i0 = Math.floor(a * SR), i1 = Math.floor(b * SR); for (let i = i0; i < i1; i++) ss += bb[0][i] ** 2 + bb[1][i] ** 2; return (10 * Math.log10(ss / (2 * (i1 - i0)) + 1e-12)).toFixed(1); };
  return `${k.padEnd(9)} music ${r(music)}  sfx ${r(sfx)}  amb ${r(amb)}  verb ${r([vl, vr])}`;
});
console.log(rows.join('\n'));

const G = { music: 1.0, sfx: 0.9, amb: 0.9, verb: 1.0 };
for (let i = 0; i < N; i++) {
  mix[0][i] = music[0][i] * G.music + sfx[0][i] * G.sfx + amb[0][i] * G.amb + vl[i] * G.verb;
  mix[1][i] = music[1][i] * G.music + sfx[1][i] * G.sfx + amb[1][i] * G.amb + vr[i] * G.verb;
}
const tail = len(0.6);
for (let i = 0; i < tail; i++) {
  mix[0][N - 1 - i] *= i / tail;
  mix[1][N - 1 - i] *= i / tail;
}

{
  const att = Math.exp(-1 / (0.004 * SR));
  const rel = Math.exp(-1 / (0.18 * SR));
  const thr = 10 ** (-14 / 20);
  let pk0 = 0;
  for (const ch of mix) for (let i = 0; i < N; i++) pk0 = Math.max(pk0, Math.abs(ch[i]));
  let e = 0;
  for (let i = 0; i < N; i++) {
    const x = Math.max(Math.abs(mix[0][i]), Math.abs(mix[1][i])) / pk0;
    e = x > e ? att * e + (1 - att) * x : rel * e + (1 - rel) * x;
    const g = e > thr ? (thr / e) ** (1 - 1 / 2) : 1;
    mix[0][i] *= g;
    mix[1][i] *= g;
  }
}
let peak = 0;
for (const ch of mix) for (let i = 0; i < N; i++) peak = Math.max(peak, Math.abs(ch[i]));
const drive = 1.1 / peak;
let outPeak = 0;
for (const ch of mix) for (let i = 0; i < N; i++) {
  ch[i] = Math.tanh(ch[i] * drive);
  outPeak = Math.max(outPeak, Math.abs(ch[i]));
}
const norm = 0.93 / outPeak;
stats('master', mix);

const out = Buffer.alloc(44 + N * 4);
out.write('RIFF', 0); out.writeUInt32LE(36 + N * 4, 4); out.write('WAVE', 8);
out.write('fmt ', 12); out.writeUInt32LE(16, 16); out.writeUInt16LE(1, 20); out.writeUInt16LE(2, 22);
out.writeUInt32LE(SR, 24); out.writeUInt32LE(SR * 4, 28); out.writeUInt16LE(4, 32); out.writeUInt16LE(16, 34);
out.write('data', 36); out.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) {
  out.writeInt16LE(Math.round(Math.max(-1, Math.min(1, mix[0][i] * norm)) * 32767), 44 + i * 4);
  out.writeInt16LE(Math.round(Math.max(-1, Math.min(1, mix[1][i] * norm)) * 32767), 46 + i * 4);
}
fs.writeFileSync(path.join(here, '../public/soundtrack.wav'), out);
console.log('wrote public/soundtrack.wav');
