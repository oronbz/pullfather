import React, { useMemo } from 'react';
import { AbsoluteFill, Easing, interpolate, random } from 'remotion';
import { Hat } from '../Hat';
import { color, font } from '../theme';
import { C, S, frameRandom, ramp, useAbs } from '../time';

export const Typed: React.FC<{ t: number; cue: { start: number; perChar: number; text: string }; caret?: boolean; style?: React.CSSProperties }> = ({ t, cue, caret = true, style }) => {
  const n = Math.max(0, Math.min(cue.text.length, Math.floor((t - cue.start) / cue.perChar) + 1));
  const shown = t < cue.start ? '' : cue.text.slice(0, n);
  const blink = Math.floor(t * 2.2) % 2 === 0;
  return (
    <span style={style}>
      {shown}
      <span style={{ opacity: caret && t >= cue.start - 0.4 && (n < cue.text.length || blink) ? 1 : 0 }}>▌</span>
      <span style={{ visibility: 'hidden' }}>{cue.text.slice(shown.length)}</span>
    </span>
  );
};

export const Reveal = () => {
  const t = useAbs('reveal');
  const [, b] = S.reveal;
  const on = C.spotlight;
  const light = t < on ? 0 : t < on + 0.06 ? 1 : t < on + 0.12 ? 0.15 : t < on + 0.2 ? 1 : 0.92 + 0.08 * frameRandom('spot', t);
  const slam = ramp(t, C.titleSlam - 0.12, C.titleSlam, Easing.in(Easing.quad));
  const shake = t > C.titleSlam && t < C.titleSlam + 0.45 ? (1 - (t - C.titleSlam) / 0.45) * 16 : 0;
  const sx = (frameRandom('shx', t) - 0.5) * shake;
  const sy = (frameRandom('shy', t) - 0.5) * shake;
  const bob = Math.sin(t * 1.6) * 10;
  const glow = 0.6 + 0.4 * Math.sin(t * 3);
  const motes = useMemo(
    () => Array.from({ length: 70 }).map((_, i) => ({ u: random(`mu${i}`), v: random(`mv${i}`), s: 1 + random(`ms${i}`) * 2.5, sp: 10 + random(`mp${i}`) * 25 })),
    [],
  );
  const hs = 0.82;
  return (
    <AbsoluteFill style={{ background: '#000', opacity: 1 - ramp(t, b - 0.4, b) }}>
      <AbsoluteFill style={{ transform: `translate(${sx}px, ${sy}px)` }}>
        <svg width={1920} height={1080} style={{ position: 'absolute', opacity: light }}>
          <defs>
            <linearGradient id="beam" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#fff" stopOpacity={0.34} />
              <stop offset="1" stopColor="#fff" stopOpacity={0.05} />
            </linearGradient>
            <radialGradient id="floor">
              <stop offset="0" stopColor="#fff" stopOpacity={0.3} />
              <stop offset="1" stopColor="#fff" stopOpacity={0} />
            </radialGradient>
          </defs>
          <polygon points="880,-20 1040,-20 1420,1100 500,1100" fill="url(#beam)" />
          <ellipse cx={960} cy={640} rx={420} ry={70} fill="url(#floor)" />
          {motes.map((m, i) => {
            const y = ((m.v * 1100 - t * m.sp) % 1100 + 1100) % 1100;
            const half = 80 + (y / 1100) * 460;
            const x = 960 + (m.u - 0.5) * 2 * half + Math.sin(t + i) * 8;
            return <circle key={i} cx={x} cy={y} r={m.s} fill="#fff" opacity={0.35} />;
          })}
        </svg>
        <svg width={1920} height={1080} style={{ position: 'absolute', opacity: light, filter: 'url(#boilSoft)' }}>
          <ellipse cx={960} cy={380 + (776 - 505) * hs} rx={260 * hs * (1 - bob / 200)} ry={22} fill="#000" opacity={0.7} />
          <g transform={`translate(${960 - 512 * hs} ${380 - 505 * hs + bob}) scale(${hs})`}>
            <Hat glow={glow} lit={light} />
          </g>
        </svg>
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: 690,
            textAlign: 'center',
            fontFamily: font.playfair,
            fontWeight: 900,
            fontSize: 168,
            letterSpacing: '0.035em',
            color: color.bone,
            opacity: slam,
            transform: `scale(${interpolate(slam, [0, 1], [1.8, 1])})`,
            textShadow: '0 10px 40px rgba(0,0,0,0.9)',
            lineHeight: 1,
          }}
        >
          THE PULLFATHER
        </div>
        <div style={{ position: 'absolute', left: 0, right: 0, top: 895, textAlign: 'center', fontFamily: font.elite, fontSize: 46, color: color.fog }}>
          <Typed t={t} cue={C.tagline} caret={t < b - 0.8} />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
