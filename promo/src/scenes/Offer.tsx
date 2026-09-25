import { AbsoluteFill, Easing } from 'remotion';
import { color, font } from '../theme';
import { C, S, flickIn, ramp, useAbs } from '../time';
import { Intertitle } from './Intertitle';
import { Typed } from './Reveal';

const OUTPUT = [
  ['==>', ' Downloading https://github.com/oronbz/pullfather/releases/latest'],
  ['==>', ' Installing Cask pullfather'],
  ['==>', " Moving App 'Pullfather.app' to '/Applications/Pullfather.app'"],
  ['', 'pullfather was successfully installed!'],
];

export const Offer = () => {
  const t = useAbs('offer');
  const [a, b] = S.offer;
  const [l1, l2] = C.offerLines;
  if (t < C.terminalIn) {
    const out = 1 - ramp(t, C.terminalIn - 0.3, C.terminalIn);
    return (
      <Intertitle opacity={Math.max(0.0001, Math.min(ramp(t, a, a + 0.3), out))}>
        <div style={{ textAlign: 'center', fontFamily: font.playfair, fontStyle: 'italic', color: color.bone }}>
          <div style={{ fontSize: 96, opacity: flickIn(t, l1) }}>I&rsquo;m gonna make you an offer</div>
          <div
            style={{
              fontSize: 130,
              fontWeight: 900,
              color: color.hot,
              textShadow: `0 0 40px rgba(227,49,60,0.35)`,
              opacity: ramp(t, l2, l2 + 0.12),
              transform: `scale(${1.25 - 0.25 * ramp(t, l2, l2 + 0.15, Easing.out(Easing.cubic))})`,
              marginTop: 18,
            }}
          >
            you can&rsquo;t refuse.
          </div>
        </div>
      </Intertitle>
    );
  }
  const win = ramp(t, C.terminalIn, C.terminalIn + 0.35, Easing.out(Easing.cubic));
  return (
    <AbsoluteFill style={{ background: 'radial-gradient(ellipse at 50% 45%, #242221 0%, #0a0909 70%)', alignItems: 'center', justifyContent: 'center', opacity: 1 - ramp(t, b - 0.3, b) }}>
      <div
        style={{
          width: 1420,
          height: 560,
          borderRadius: 18,
          background: 'rgba(16,15,15,0.96)',
          boxShadow: '0 40px 120px rgba(0,0,0,0.8), inset 0 0 0 1px rgba(255,255,255,0.12)',
          overflow: 'hidden',
          opacity: win,
          transform: `translateY(${(1 - win) * 40}px) scale(${0.96 + 0.04 * win})`,
        }}
      >
        <div style={{ height: 52, display: 'flex', alignItems: 'center', gap: 10, padding: '0 20px', background: 'rgba(255,255,255,0.05)', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
          {[color.hot, '#8a8580', '#5a5652'].map((c) => (
            <div key={c} style={{ width: 16, height: 16, borderRadius: 8, background: c }} />
          ))}
          <div style={{ flex: 1, textAlign: 'center', fontFamily: font.system, fontSize: 20, color: color.fog, marginRight: 70 }}>zsh — the family business</div>
        </div>
        <div style={{ padding: '36px 44px', fontFamily: font.mono, fontVariantLigatures: 'none', fontSize: 38, lineHeight: 1.55, color: color.bone }}>
          <div>
            <span style={{ color: color.hot }}>~ </span>
            <Typed t={t} cue={C.terminal} caret={t < C.enter} />
          </div>
          {OUTPUT.map(([p, text], i) => {
            const at = C.enter + 0.12 + i * 0.22;
            if (t < at) return null;
            const last = i === OUTPUT.length - 1;
            return (
              <div key={i} style={{ fontSize: last ? 36 : 26, color: last ? color.bone : color.fog, fontWeight: last ? 700 : 400, whiteSpace: 'nowrap', marginTop: last ? 10 : 0 }}>
                <span style={{ color: color.hot }}>{p}</span>
                {text}
              </div>
            );
          })}
        </div>
      </div>
    </AbsoluteFill>
  );
};
