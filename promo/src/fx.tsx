import React from 'react';
import { AbsoluteFill, random, useCurrentFrame } from 'remotion';

export const Weave: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const f = useCurrentFrame();
  const x = (random(`wx${f}`) - 0.5) * 3;
  const y = (random(`wy${Math.floor(f / 2)}`) - 0.5) * 4 + Math.sin(f / 9) * 0.8;
  return <AbsoluteFill style={{ transform: `translate(${x}px, ${y}px) scale(1.012)` }}>{children}</AbsoluteFill>;
};

export const BoilDefs: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <svg width={0} height={0} style={{ position: 'absolute' }}>
      <defs>
        <filter id="boil">
          <feTurbulence type="fractalNoise" baseFrequency="0.018" numOctaves={2} seed={Math.floor(f / 3) % 50} />
          <feDisplacementMap in="SourceGraphic" scale={5} xChannelSelector="R" yChannelSelector="G" />
        </filter>
        <filter id="boilSoft">
          <feTurbulence type="fractalNoise" baseFrequency="0.012" numOctaves={1} seed={Math.floor(f / 3) % 50} />
          <feDisplacementMap in="SourceGraphic" scale={3} xChannelSelector="R" yChannelSelector="G" />
        </filter>
        <filter id="ink">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves={2} seed={3} result="n" />
          <feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.4 1.45" result="holes" />
          <feComposite in="SourceGraphic" in2="holes" operator="in" />
        </filter>
      </defs>
    </svg>
  );
};

export const FilmFX: React.FC = () => {
  const f = useCurrentFrame();
  const flicker = 0.03 + random(`fl${f}`) * 0.08 + (random(`flb${f}`) < 0.03 ? 0.12 : 0);
  const scratches = [0, 1, 2].flatMap((k) => {
    const g = Math.floor(f / 5) + k * 1000;
    if (random(`s${g}`) > 0.2) return [];
    const x = random(`sx${g}`) * 1920 + (f % 5) * (random(`sd${g}`) - 0.5) * 6;
    const light = random(`sl${g}`) > 0.5;
    return [
      <div
        key={k}
        style={{
          position: 'absolute',
          left: x,
          top: random(`st${g}`) * -300,
          width: 1 + random(`sw${g}`) * 1.2,
          height: 1400,
          background: light ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.4)',
        }}
      />,
    ];
  });
  const dust = Array.from({ length: 7 }).flatMap((_, k) => {
    if (random(`d${f}-${k}`) > 0.28) return [];
    const x = random(`dx${f}-${k}`) * 1920;
    const y = random(`dy${f}-${k}`) * 1080;
    const r = 1.5 + random(`dr${f}-${k}`) * 4;
    const light = random(`dl${f}-${k}`) > 0.7;
    if (random(`dh${f}-${k}`) > 0.8) {
      const a = random(`da${f}-${k}`) * 360;
      return [
        <svg key={k} style={{ position: 'absolute', left: x, top: y, overflow: 'visible' }} width={1} height={1}>
          <path
            d={`M0 0 c 12 -8 20 6 34 -2 s 16 10 26 4`}
            transform={`rotate(${a})`}
            stroke={light ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.7)'}
            strokeWidth={1.4}
            fill="none"
          />
        </svg>,
      ];
    }
    return [
      <div
        key={k}
        style={{
          position: 'absolute',
          left: x,
          top: y,
          width: r * 2,
          height: r * 1.6,
          borderRadius: '50%',
          background: light ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.75)',
        }}
      />,
    ];
  });
  return (
    <AbsoluteFill style={{ pointerEvents: 'none' }}>
      <svg width={1920} height={1080} style={{ position: 'absolute', mixBlendMode: 'overlay', opacity: 0.55 }}>
        <filter id="grain">
          <feTurbulence type="fractalNoise" baseFrequency="0.78" numOctaves={2} seed={f % 113} stitchTiles="stitch" />
          <feColorMatrix type="matrix" values="0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0.33 0.33 0.33 0 0  0 0 0 0 1" />
        </filter>
        <rect width="100%" height="100%" filter="url(#grain)" />
      </svg>
      {scratches}
      {dust}
      <AbsoluteFill style={{ background: `rgba(0,0,0,${flicker})` }} />
      <AbsoluteFill
        style={{ background: 'radial-gradient(ellipse 75% 70% at 50% 50%, transparent 50%, rgba(0,0,0,0.55) 85%, rgba(0,0,0,0.9) 100%)' }}
      />
    </AbsoluteFill>
  );
};
