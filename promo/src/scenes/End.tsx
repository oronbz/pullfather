import { AbsoluteFill, Easing, Img, interpolate, staticFile } from 'remotion';
import { color, font } from '../theme';
import { C, S, ramp, useAbs } from '../time';

export const End = () => {
  const t = useAbs('end');
  const [a] = S.end;
  const icon = ramp(t, a, a + 0.6, Easing.out(Easing.back(1.6)));
  const line = (i: number) => ramp(t, a + 0.45 + i * 0.25, a + 0.85 + i * 0.25, Easing.out(Easing.cubic));
  const [i0, i1] = C.irisClose;
  const r = interpolate(t, [i0, i0 + 0.45, i1 - 0.3, i1], [1300, 250, 225, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.inOut(Easing.cubic),
  });
  const rise = (i: number) => ({ opacity: line(i), transform: `translateY(${(1 - line(i)) * 24}px)` });
  return (
    <AbsoluteFill style={{ background: '#000' }}>
      <AbsoluteFill
        style={{
          background: 'radial-gradient(ellipse at 50% 32%, #2e2b29 0%, #0d0c0c 60%, #050505 100%)',
          clipPath: `circle(${r}px at 960px 300px)`,
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: 960 - 200,
            top: 300 - 200,
            width: 400,
            height: 400,
            transform: `scale(${0.6 + 0.4 * icon})`,
            opacity: Math.min(1, icon * 1.5),
            filter: `drop-shadow(0 0 ${40 + 20 * Math.sin(t * 2)}px rgba(179,32,42,0.45))`,
          }}
        >
          <Img src={staticFile('AppIcon.svg')} style={{ width: 400, height: 400 }} />
        </div>
        <div style={{ position: 'absolute', left: 0, right: 0, top: 520, textAlign: 'center', color: color.bone }}>
          <div style={{ fontFamily: font.playfair, fontWeight: 900, fontSize: 118, lineHeight: 1, ...rise(0) }}>The Pullfather</div>
          <div style={{ fontFamily: font.playfair, fontStyle: 'italic', fontSize: 44, color: color.fog, marginTop: 16, ...rise(1) }}>
            It&rsquo;s not personal. It&rsquo;s just business logic.
          </div>
          <div style={{ marginTop: 44, display: 'inline-block', ...rise(2) }}>
            <div style={{ fontFamily: font.mono, fontVariantLigatures: 'none', fontSize: 38, padding: '18px 34px', borderRadius: 14, background: 'rgba(255,255,255,0.06)', boxShadow: 'inset 0 0 0 1.5px rgba(237,227,209,0.35)' }}>
              <span style={{ color: color.hot }}>$ </span>brew install --cask oronbz/tap/pullfather
            </div>
          </div>
          <div style={{ fontFamily: font.system, fontSize: 28, color: color.ash, marginTop: 30, letterSpacing: '0.04em', ...rise(3) }}>
            github.com/oronbz/pullfather&nbsp;&nbsp;·&nbsp;&nbsp;free &amp; open source&nbsp;&nbsp;·&nbsp;&nbsp;macOS 26+
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
