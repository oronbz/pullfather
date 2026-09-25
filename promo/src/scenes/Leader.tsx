import { AbsoluteFill } from 'remotion';
import { color, font } from '../theme';
import { frameRandom, useAbs } from '../time';

export const Leader = () => {
  const t = useAbs('leader');
  if (t >= 3) {
    const white = (t < 3.1 || (t > 3.2 && t < 3.27)) ? 1 : 0;
    const burn = t > 3.4 && t < 3.62;
    return (
      <AbsoluteFill style={{ background: white ? '#e8e6e2' : '#000' }}>
        {burn && (
          <div
            style={{
              position: 'absolute',
              right: 150,
              top: 120,
              width: 70,
              height: 70,
              borderRadius: '50%',
              background: 'radial-gradient(circle, #fff 0%, #d9d2c4 45%, #3a3632 72%, transparent 76%)',
            }}
          />
        )}
      </AbsoluteFill>
    );
  }
  const idx = Math.floor(t);
  const frac = t - idx;
  const n = 3 - idx;
  const jitter = (frameRandom('lj', t) - 0.5) * 6;
  return (
    <AbsoluteFill style={{ background: 'radial-gradient(circle at 50% 50%, #b9b4ad 0%, #8c8781 55%, #4a4643 100%)' }}>
      <div
        style={{
          position: 'absolute',
          left: 960 - 440,
          top: 540 - 440,
          width: 880,
          height: 880,
          borderRadius: '50%',
          background: `conic-gradient(from 0deg, rgba(20,18,18,0.55) 0deg ${frac * 360}deg, transparent ${frac * 360}deg)`,
        }}
      />
      <svg width={1920} height={1080} style={{ position: 'absolute' }}>
        <g stroke={color.coal} fill="none" opacity={0.85}>
          <circle cx={960} cy={540} r={440} strokeWidth={6} />
          <circle cx={960} cy={540} r={380} strokeWidth={4} />
          <line x1={0} y1={540} x2={1920} y2={540} strokeWidth={3} />
          <line x1={960} y1={0} x2={960} y2={1080} strokeWidth={3} />
        </g>
      </svg>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: font.oldStandard,
          fontWeight: 700,
          fontSize: 560,
          color: color.coal,
          transform: `translateY(${jitter - 20}px)`,
        }}
      >
        {n}
      </div>
    </AbsoluteFill>
  );
};
