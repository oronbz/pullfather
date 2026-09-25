import React, { useMemo } from 'react';
import { AbsoluteFill, interpolate, random } from 'remotion';
import { color, font } from '../theme';
import { C, S, flickIn, frameRandom, ramp, span, useAbs } from '../time';

const GROUND = 890;

type Building = { x: number; w: number; h: number; windows: { x: number; y: number; lit: boolean; flick: boolean }[]; tower: boolean };

const buildings = (layer: string, count: number, minW: number, maxW: number, minH: number, maxH: number, litRate: number): Building[] => {
  const out: Building[] = [];
  let x = -120;
  for (let i = 0; i < count && x < 2100; i++) {
    const w = minW + random(`${layer}w${i}`) * (maxW - minW);
    const h = minH + random(`${layer}h${i}`) * (maxH - minH);
    const windows = [];
    const cols = Math.floor((w - 24) / 22);
    const rows = Math.floor((h - 50) / 30);
    for (let r = 0; r < rows; r++)
      for (let c = 0; c < cols; c++) {
        const k = `${layer}${i}-${r}-${c}`;
        windows.push({ x: 14 + c * 22, y: 30 + r * 30, lit: random(k) < litRate, flick: random(`f${k}`) < 0.04 });
      }
    out.push({ x, w, h, windows, tower: random(`${layer}t${i}`) < 0.3 });
    x += w + random(`${layer}g${i}`) * 30 - 6;
  }
  return out;
};

const Skyline: React.FC<{ data: Building[]; fill: string; lit: string; t: number; flash: number }> = ({ data, fill, lit, t, flash }) => (
  <g>
    {data.map((b, i) => (
      <g key={i} transform={`translate(${b.x} ${GROUND - b.h})`}>
        <rect width={b.w} height={b.h + 10} fill={fill} />
        {b.tower && (
          <g fill={fill}>
            <rect x={b.w * 0.3} y={-46} width={44} height={36} rx={6} />
            <rect x={b.w * 0.3 + 6} y={-10} width={4} height={10} />
            <rect x={b.w * 0.3 + 34} y={-10} width={4} height={10} />
            <path d={`M${b.w * 0.3 - 4} -46 L${b.w * 0.3 + 22} -62 L${b.w * 0.3 + 48} -46 Z`} />
          </g>
        )}
        {b.windows.map((w, j) =>
          w.lit && !(w.flick && frameRandom(`win${i}-${j}`, t, 4) < 0.5) ? (
            <rect key={j} x={w.x + 2} y={w.y} width={7} height={11} fill={lit} opacity={1 - flash * 0.7} />
          ) : null,
        )}
      </g>
    ))}
  </g>
);

const Detective: React.FC<{ t: number }> = ({ t }) => {
  const drag = t % 4.5 > 3.3 && t % 4.5 < 4.1 ? 1 : 0;
  const ember = 0.5 + 0.3 * Math.sin(t * 2.2) + drag * 0.8;
  const breathe = 1 + 0.006 * Math.sin(t * 1.7);
  const rim = '#8a857d';
  const seam = '#1f1e1e';
  return (
    <svg width={250} height={470} viewBox="0 0 250 470" style={{ position: 'absolute', left: 545, top: GROUND - 462, overflow: 'visible', filter: 'url(#boilSoft)' }}>
      {Array.from({ length: 14 }).map((_, k) => {
        const life = (t * 0.26 + k / 14) % 1;
        const x = 162 + Math.sin(life * 6 + k) * 16 * life + life * 46;
        const y = 108 - life * 320;
        return <circle key={k} cx={x} cy={y} r={3 + life * 28} fill="#d6d1c9" opacity={0.2 * (1 - life)} style={{ filter: 'blur(7px)' }} />;
      })}
      <g transform={`translate(0 ${470 * (1 - breathe)}) scale(1 ${breathe})`}>
        <g fill={color.ink}>
          <path d="M78 386 L75 450 L101 450 L105 386 Z" />
          <path d="M116 386 L120 450 L145 450 L143 386 Z" />
          <path d="M70 448 L102 448 Q116 450 119 458 L68 458 Z" />
          <path d="M116 448 L147 448 Q163 450 166 460 L114 460 Z" />
          <path d="M112 136 L84 146 Q66 152 64 172 L62 236 Q70 244 74 250 L58 380 Q56 388 66 390 L112 392 L118 384 L124 392 L168 388 Q176 386 172 378 L156 250 Q162 242 164 236 L166 180 Q166 154 150 146 L128 136 Z" />
          <path d="M70 150 Q52 162 52 200 L50 250 Q52 264 66 268 L82 262 L80 236 L78 196 Z" />
          <path d="M150 148 Q172 154 178 186 L186 226 Q186 240 172 238 L160 230 L156 196 Z" />
          <path d="M172 238 Q188 234 186 218 L154 128 Q148 118 140 122 L136 132 L160 206 Z" />
          <path d="M136 118 Q144 112 152 118 L156 128 Q148 136 138 130 Z" />
          <g transform="translate(120 140) scale(0.82) translate(-120 -140)">
            <path d="M112 116 L112 142 L134 142 L130 118 Z" />
            <path d="M104 84 L104 106 Q106 118 116 126 L130 128 Q138 126 140 120 L141 113 L146 110 L145 106 L157 101 L142 93 L141 84 Z" />
            <path d="M92 86 C90 60 98 42 116 38 C124 36 130 42 136 40 C146 37 158 44 164 58 C168 68 168 78 166 86 Z" />
            <path d="M58 86 Q76 76 126 76 Q176 76 202 90 Q188 98 158 94 Q128 91 98 94 Q72 96 58 86 Z" />
          </g>
          <path d="M98 152 L94 116 L114 134 Z" />
          <path d="M142 152 L148 118 L128 134 Z" />
        </g>
        <g transform="translate(120 140) scale(0.82) translate(-120 -140)">
          <path d="M94 72 C104 76 150 76 164 72 L166 84 C150 88 104 88 92 84 Z" fill="#262525" />
          <path d="M118 44 C124 52 132 52 138 44" stroke="#2a2929" strokeWidth={2.5} fill="none" />
          <g stroke={rim} fill="none" strokeLinecap="round" opacity={0.9}>
            <path d="M92 84 C90 60 98 42 116 38" strokeWidth={2.4} />
            <path d="M60 86 Q78 77 110 76" strokeWidth={2.2} />
          </g>
        </g>
        <g stroke={seam} strokeWidth={2} fill="none" strokeLinecap="round">
          <path d="M112 138 L118 204 M130 138 L122 204" />
          <path d="M120 204 L118 384" />
          <path d="M70 312 L96 310 M140 310 L162 312" />
        </g>
        <rect x={64} y={238} width={98} height={11} rx={2} fill="#171616" />
        <rect x={112} y={236} width={14} height={15} rx={2} fill="none" stroke="#2c2b2a" strokeWidth={2} />
        <circle cx={127} cy={222} r={2.4} fill="#2c2b2a" />
        <circle cx={126} cy={268} r={2.4} fill="#2c2b2a" />
        <g stroke={rim} fill="none" strokeLinecap="round" opacity={0.9}>
          <path d="M98 150 L94 116" strokeWidth={2} />
          <path d="M84 146 Q66 152 64 172" strokeWidth={2.4} />
          <path d="M70 152 Q53 164 52 200 L50 250 Q52 263 64 267" strokeWidth={2.6} />
          <path d="M72 254 L58 380" strokeWidth={2.6} />
          <path d="M78 390 L75 448" strokeWidth={1.8} opacity={0.7} />
        </g>
        <line x1={139} y1={115} x2={160} y2={110} stroke="#e4e0d8" strokeWidth={3.2} strokeLinecap="round" />
        <circle cx={162} cy={109.5} r={3 + ember * 1.4} fill={color.hot} style={{ filter: `drop-shadow(0 0 ${5 + ember * 10}px ${color.hot})` }} />
        <ellipse cx={146} cy={116} rx={14} ry={10} fill={color.hot} opacity={0.12 * ember} style={{ filter: 'blur(6px)' }} />
      </g>
    </svg>
  );
};

export const City = () => {
  const t = useAbs('city');
  const [a, b] = S.city;
  const far = useMemo(() => buildings('far', 40, 90, 190, 240, 560, 0.14), []);
  const near = useMemo(() => buildings('near', 22, 150, 280, 380, 760, 0.07), []);
  const lf = C.thunderFlash;
  const flash = interpolate(t, [lf - 0.01, lf, lf + 0.06, lf + 0.13, lf + 0.2, lf + 0.3, lf + 0.6], [0, 1, 0.25, 0.95, 0.3, 0.5, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const push = 1 + 0.08 * ramp(t, a, b, (x) => x);
  const neonOn = frameRandom('neon', t, 2) > 0.1;
  const brokenOn = frameRandom('neonW', t, 3) > 0.45;
  const drops = useMemo(
    () =>
      Array.from({ length: 280 }).map((_, i) => ({
        x0: random(`rx${i}`) * 2200,
        y0: random(`ry${i}`) * 1300,
        v: 1500 + random(`rv${i}`) * 900,
        l: 26 + random(`rl${i}`) * 46,
        o: 0.14 + random(`ro${i}`) * 0.3,
        w: random(`rw${i}`) < 0.2 ? 2.4 : 1.3,
      })),
    [],
  );
  const cap = (i: number, until: number) => Math.min(flickIn(t, C.cityCaptions[i]), 1 - ramp(t, until - 0.35, until));
  const sky = (x: number, y: number) => interpolate(flash, [0, 1], [x, y]);
  const g = (v: number) => `rgb(${v},${v},${v + 2})`;
  return (
    <AbsoluteFill style={{ background: '#000', opacity: span(t, a, b, 0.5, 0.45) }}>
      <AbsoluteFill style={{ transform: `scale(${push})`, transformOrigin: '40% 70%' }}>
        <AbsoluteFill style={{ background: `linear-gradient(180deg, ${g(sky(14, 230))} 0%, ${g(sky(34, 250))} 60%, ${g(sky(58, 255))} 82%)` }} />
        <div
          style={{
            position: 'absolute',
            left: 1400,
            top: 110,
            width: 180,
            height: 180,
            borderRadius: '50%',
            background: 'radial-gradient(circle at 42% 40%, #f1eee8, #cfcbc4 70%, #b3aea7)',
            boxShadow: '0 0 140px 50px rgba(255,255,255,0.13)',
          }}
        />
        {[0, 1, 2, 3].map((k) => (
          <div
            key={k}
            style={{
              position: 'absolute',
              left: ((k * 520 + t * (22 + k * 9)) % 2400) - 400,
              top: 80 + k * 55,
              width: 620 - k * 60,
              height: 90 + k * 12,
              borderRadius: '50%',
              background: g(sky(18 + k * 4, 200)),
              filter: 'blur(22px)',
              opacity: 0.85,
            }}
          />
        ))}
        {flash > 0.5 && (
          <svg width={1920} height={1080} style={{ position: 'absolute' }}>
            <polyline points="1180,0 1150,120 1195,150 1120,300 1170,320 1090,480" stroke="#fff" strokeWidth={5} fill="none" style={{ filter: 'drop-shadow(0 0 16px #fff)' }} />
            <polyline points="1170,320 1230,400 1215,470" stroke="#fff" strokeWidth={3} fill="none" />
          </svg>
        )}
        <svg width={1920} height={1080} style={{ position: 'absolute', filter: 'url(#boilSoft)' }}>
          <Skyline data={far} fill={g(Math.round(sky(40, 70)))} lit="#77736c" t={t} flash={flash} />
        </svg>
        <AbsoluteFill style={{ background: 'linear-gradient(180deg, transparent 55%, rgba(120,120,122,0.18) 78%, transparent 84%)' }} />
        <svg width={1920} height={1080} style={{ position: 'absolute', filter: 'url(#boil)' }}>
          <Skyline data={near} fill={g(Math.round(sky(12, 16)))} lit="#c9c3b8" t={t} flash={flash} />
          <rect x={0} y={GROUND} width={1920} height={200} fill="#0b0b0c" />
        </svg>
        <div style={{ position: 'absolute', left: 1540, top: 250, width: 104, height: 560, border: '5px solid #1d1d1f', background: '#0d0d0e', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'space-around', padding: '14px 0' }}>
          {'REVIEWS'.split('').map((ch, i) => {
            const on = neonOn && (i !== 5 || brokenOn);
            return (
              <div
                key={i}
                style={{
                  fontFamily: font.limelight,
                  fontSize: 64,
                  lineHeight: 1,
                  color: on ? '#ff6b73' : '#3a1215',
                  textShadow: on ? `0 0 6px ${color.hot}, 0 0 18px ${color.hot}, 0 0 42px ${color.red}` : 'none',
                }}
              >
                {ch}
              </div>
            );
          })}
        </div>
        <div
          style={{
            position: 'absolute',
            left: 1480,
            top: GROUND + 10,
            width: 230,
            height: 170,
            background: `radial-gradient(ellipse, rgba(227,49,60,${neonOn ? 0.38 : 0.08}) 0%, transparent 70%)`,
            filter: 'blur(10px)',
          }}
        />
        <svg width={1920} height={1080} style={{ position: 'absolute' }}>
          <defs>
            <linearGradient id="cone" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#fff" stopOpacity={0.3} />
              <stop offset="1" stopColor="#fff" stopOpacity={0.04} />
            </linearGradient>
            <radialGradient id="pool">
              <stop offset="0" stopColor="#fff" stopOpacity={0.32} />
              <stop offset="1" stopColor="#fff" stopOpacity={0} />
            </radialGradient>
          </defs>
          <polygon points={`440,330 486,330 700,${GROUND} 230,${GROUND}`} fill="url(#cone)" />
          <ellipse cx={465} cy={GROUND + 20} rx={300} ry={46} fill="url(#pool)" />
          <g fill={color.ink} style={{ filter: 'url(#boilSoft)' }}>
            <rect x={455} y={320} width={16} height={GROUND - 320} />
            <rect x={443} y={GROUND - 30} width={40} height={30} />
            <path d="M424 330 L502 330 L488 300 L438 300 Z" />
            <rect x={456} y={286} width={14} height={16} />
          </g>
          <rect x={436} y={328} width={54} height={8} fill="#f4f1ea" style={{ filter: 'drop-shadow(0 0 12px #fff)' }} />
          {drops.map((d, i) => {
            const y = ((d.y0 + t * d.v) % 1300) - 80;
            const x = ((d.x0 - t * d.v * 0.2) % 2200 + 2200) % 2200 - 120;
            const inCone = x > 230 && x < 700 && y > 330;
            return (
              <line
                key={i}
                x1={x}
                y1={y}
                x2={x - d.l * 0.2}
                y2={y + d.l}
                stroke="#e6e3de"
                strokeWidth={d.w}
                opacity={Math.min(0.9, d.o * (inCone ? 2.6 : 1) + flash * 0.3)}
              />
            );
          })}
        </svg>
        <div style={{ position: 'absolute', left: 540, top: 430, width: 260, height: GROUND - 430, background: '#0a0a0a', padding: 12, boxSizing: 'border-box', filter: 'url(#boilSoft)' }}>
          <div style={{ width: '100%', height: '100%', borderRadius: '90px 90px 0 0', background: 'linear-gradient(180deg, rgba(236,232,224,0.78) 0%, rgba(200,196,188,0.55) 70%, rgba(170,166,160,0.45) 100%)', boxShadow: '0 0 60px 10px rgba(230,226,218,0.18)' }} />
        </div>
        <div style={{ position: 'absolute', left: 470, top: GROUND - 20, width: 400, height: 90, background: 'radial-gradient(ellipse at 50% 20%, rgba(230,226,218,0.3), transparent 70%)' }} />
        <Detective t={t} />
      </AbsoluteFill>
      <AbsoluteFill style={{ background: '#fff', opacity: flash * 0.18 }} />
      <AbsoluteFill style={{ background: 'linear-gradient(0deg, rgba(0,0,0,0.85) 0%, transparent 26%)' }} />
      {[
        ['This city runs on pull requests.', 0, C.cityCaptions[1] - 0.1],
        ['And everybody wants a favor.', 1, b - 0.2],
      ].map(([text, i, until]) => (
        <div
          key={i as number}
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 90,
            textAlign: 'center',
            fontFamily: font.playfair,
            fontStyle: 'italic',
            fontSize: 72,
            color: color.bone,
            textShadow: '0 4px 20px #000',
            opacity: cap(i as number, until as number),
          }}
        >
          {text}
        </div>
      ))}
    </AbsoluteFill>
  );
};
