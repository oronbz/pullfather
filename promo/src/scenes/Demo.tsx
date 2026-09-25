import React from 'react';
import { AbsoluteFill, Easing, interpolate, staticFile, Img } from 'remotion';
import { color, font } from '../theme';
import { C, S, flickIn, ramp, useAbs } from '../time';

const K = 1.8;
const W = 1920 / K;
const P = {
  surface: 'rgba(28,26,26,0.97)',
  text: '#F1EFEB',
  secondary: '#B3AEA8',
  muted: '#8B8782',
  label: '#D5CEC2',
  line: 'rgba(255,255,255,0.09)',
};

type Checks = 'pass' | 'running' | 'fail';

const Status: React.FC<{ s: Checks; t: number }> = ({ s, t }) => {
  if (s === 'pass')
    return (
      <svg width={15} height={15} viewBox="0 0 16 16">
        <circle cx={8} cy={8} r={8} fill="#D9D5CF" />
        <path d="M4.5 8.2 L7 10.6 L11.6 5.6" stroke="#1a1818" strokeWidth={1.9} fill="none" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  if (s === 'running')
    return (
      <svg width={15} height={15} viewBox="0 0 16 16" style={{ transform: `rotate(${t * 240}deg)` }}>
        <circle cx={8} cy={8} r={6.4} stroke="#9D9892" strokeWidth={2} fill="none" strokeDasharray="30 10" />
        <circle cx={8} cy={8} r={2.4} fill="#9D9892" />
      </svg>
    );
  return (
    <svg width={15} height={15} viewBox="0 0 16 16">
      <circle cx={8} cy={8} r={8} fill={color.hot} />
      <path d="M5.3 5.3 L10.7 10.7 M10.7 5.3 L5.3 10.7" stroke="#fff" strokeWidth={1.9} strokeLinecap="round" />
    </svg>
  );
};

const Avatar: React.FC<{ initials: string; shade: number }> = ({ initials, shade }) => (
  <div
    style={{
      width: 28,
      height: 28,
      borderRadius: 14,
      background: `rgb(${shade},${shade},${shade})`,
      color: '#f4f1ec',
      fontSize: 10.5,
      fontWeight: 700,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
      letterSpacing: '0.02em',
    }}
  >
    {initials}
  </div>
);

type Row = { title: string; meta: string; checks: Checks; avatar?: [string, number]; badge?: 'Approved' | 'Changes requested' | 'Draft' };

const BUSINESS: Row[] = [
  { title: 'Fix race in token refresh', meta: 'your-org/api #412 · 2h', checks: 'pass', avatar: ['MK', 88] },
  { title: 'Migrate settings screen to SwiftUI', meta: 'your-org/ios #1088 · 5h', checks: 'running', avatar: ['SR', 70] },
  { title: 'Bump fastlane to latest', meta: 'your-org/ios #1091 · 1d', checks: 'fail', avatar: ['DB', 104] },
];
const ARRIVAL: Row = { title: 'Remove Fredo from CODEOWNERS', meta: 'corleone/family #1946 · now', checks: 'running', avatar: ['VC', 60] };
const FAMILY: Row[] = [
  { title: 'Add offline banner', meta: 'your-org/ios #1079 · 3d', checks: 'pass', badge: 'Approved' },
  { title: 'Refactor push routing', meta: 'your-org/ios #1084 · 1d', checks: 'fail', badge: 'Changes requested' },
];

const Badge: React.FC<{ kind: NonNullable<Row['badge']> }> = ({ kind }) => {
  const style: React.CSSProperties =
    kind === 'Approved'
      ? { background: 'rgba(237,227,209,0.9)', color: '#161414' }
      : kind === 'Changes requested'
        ? { background: 'rgba(255,255,255,0.1)', color: '#E9E4DC', boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.25)' }
        : { color: P.muted };
  return <div style={{ fontSize: 11, fontWeight: 600, padding: '3px 9px', borderRadius: 99, ...style }}>{kind}</div>;
};

const RowView: React.FC<{ row: Row; t: number; selected?: boolean; flash?: number; height?: number }> = ({ row, t, selected, flash = 0, height = 48 }) => (
  <div style={{ height, overflow: 'hidden' }}>
    <div
      style={{
        height: 48,
        margin: '0 -8px',
        padding: '0 12px 0 12px',
        borderRadius: 7,
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        background: flash > 0 ? `rgba(179,32,42,${0.5 * flash})` : selected ? 'rgba(255,255,255,0.08)' : 'transparent',
        boxShadow: flash > 0 ? `inset 0 0 0 1.5px rgba(227,49,60,${flash})` : 'none',
      }}
    >
      {row.avatar && <Avatar initials={row.avatar[0]} shade={row.avatar[1]} />}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, color: P.text, whiteSpace: 'nowrap' }}>{row.title}</div>
        <div style={{ fontSize: 11.5, color: P.secondary, marginTop: 2 }}>{row.meta}</div>
      </div>
      {row.badge && <Badge kind={row.badge} />}
      <Status s={row.checks} t={t} />
    </div>
  </div>
);

const SectionHead: React.FC<{ label: string; right: React.ReactNode }> = ({ label, right }) => (
  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', padding: '12px 0 7px' }}>
    <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.14em', color: P.label }}>{label}</div>
    <div style={{ fontSize: 11.5, color: P.muted }}>{right}</div>
  </div>
);

const Popover: React.FC<{ t: number; focus: { business: number; family: number; rest: number } }> = ({ t, focus }) => {
  const arrived = ramp(t, C.arrival, C.arrival + 0.28, Easing.out(Easing.cubic));
  const flash = t >= C.arrival ? Math.max(0, 1 - (t - C.arrival) / 1.8) : 0;
  const count = t >= C.arrival ? 4 : 3;
  const spin = ramp(t, C.refresh, C.refresh + 0.7, Easing.inOut(Easing.cubic)) * 360;
  const sel = t >= C.arrowKeys[1] ? 2 : t >= C.arrowKeys[0] ? 1 : 0;
  const enter = t >= C.enterRow && t < C.enterRow + 0.25;
  const rows = t >= C.arrival ? [ARRIVAL, ...BUSINESS] : BUSINESS;
  return (
    <div
      style={{
        width: 384,
        background: P.surface,
        borderRadius: 12,
        boxShadow: '0 22px 60px rgba(0,0,0,0.65), inset 0 0 0 0.5px rgba(255,255,255,0.14)',
        padding: '16px 16px 8px',
        fontFamily: font.system,
        color: P.text,
        boxSizing: 'border-box',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, paddingBottom: 12, borderBottom: `1px solid ${P.line}`, opacity: focus.rest }}>
        <Img src={staticFile('AppIcon.svg')} style={{ width: 48, height: 48, margin: -5 }} />
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: font.playfair, fontWeight: 700, fontSize: 20, lineHeight: 1.1 }}>The Pullfather</div>
          <div style={{ fontFamily: font.playfair, fontStyle: 'italic', fontSize: 13, color: P.secondary, marginTop: 2 }}>It&rsquo;s not personal. It&rsquo;s just business logic.</div>
        </div>
        <svg width={16} height={16} viewBox="0 0 16 16" style={{ transform: `rotate(${spin}deg)` }}>
          <path d="M13 8 A5 5 0 1 1 11.4 4.3" stroke={P.secondary} strokeWidth={1.6} fill="none" strokeLinecap="round" />
          <path d="M11.8 1.6 L11.8 4.8 L8.6 4.8" stroke={P.secondary} strokeWidth={1.6} fill="none" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
      <div style={{ opacity: focus.business }}>
        <SectionHead label="BUSINESS" right={`${count} awaiting your review`} />
        {rows.map((r, i) => (
          <RowView
            key={r.title}
            row={r}
            t={t}
            selected={i === sel && !(r === ARRIVAL && flash > 0.05)}
            flash={r === ARRIVAL ? flash : enter && i === sel ? 0.6 : 0}
            height={r === ARRIVAL ? 48 * arrived : 48}
          />
        ))}
      </div>
      <div style={{ opacity: focus.family }}>
        <SectionHead label="FAMILY" right="Your pull requests" />
        {FAMILY.map((r) => (
          <RowView key={r.title} row={r} t={t} />
        ))}
      </div>
      <div style={{ borderTop: `1px solid ${P.line}`, marginTop: 8, paddingTop: 5, opacity: focus.rest }}>
        {[
          ['Open GitHub', '⌘O'],
          ['Settings…', '⌘,'],
          ['Quit The Pullfather', '⌘Q'],
        ].map(([l, k]) => (
          <div key={l} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, height: 28, alignItems: 'center' }}>
            <span>{l}</span>
            <span style={{ color: P.secondary }}>{k}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

const Glyph = () => (
  <svg width={17} height={17} viewBox="0 0 18 18" fill="#f2f0ec">
    <path d="M3.2 9.3 C3.4 6.9 4.2 5 5.6 4.5 C6.6 4.2 7 5 7.5 4.8 C8 5 8.4 4.2 9.4 4.5 C10.8 5 11.6 6.9 11.8 9.3 Z" />
    <rect x={3.1} y={10.5} width={8.8} height={1.8} />
    <ellipse cx={7.5} cy={12.9} rx={7} ry={1.9} />
    <path d="M11 10.4 L15.2 3.4" fill="none" stroke="#f2f0ec" strokeWidth={1.4} strokeLinecap="round" />
    <path d="M13.3 7 C14.2 6.4 15.3 6.3 16.4 6.6" fill="none" stroke="#f2f0ec" strokeWidth={1.2} strokeLinecap="round" />
    <circle cx={15.5} cy={2.9} r={1.8} fill={color.hot} />
    <circle cx={16.5} cy={6.7} r={1.3} />
  </svg>
);

const MenuBar: React.FC<{ t: number; open: boolean }> = ({ t, open }) => {
  const arrived = t >= C.arrival;
  const roll = ramp(t, C.arrival, C.arrival + 0.22, Easing.out(Easing.back(2)));
  const pulse = arrived ? Math.max(0, 1 - (t - C.arrival) / 1.8) : 0;
  return (
    <div
      style={{
        height: 24,
        background: 'rgba(12,12,12,0.82)',
        display: 'flex',
        alignItems: 'center',
        padding: '0 12px',
        fontFamily: font.system,
        fontSize: 13,
        color: '#f2f0ec',
        gap: 20,
      }}
    >
      <span style={{ fontWeight: 700 }}>Terminal</span>
      {['Shell', 'Edit', 'View', 'Window', 'Help'].map((m) => (
        <span key={m}>{m}</span>
      ))}
      <div style={{ flex: 1 }} />
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 4,
          padding: '1px 8px',
          borderRadius: 5,
          background: open ? 'rgba(255,255,255,0.2)' : 'transparent',
          boxShadow: pulse > 0 ? `0 0 0 ${1.5 + 5 * (1 - pulse)}px rgba(227,49,60,${pulse})` : 'none',
        }}
      >
        <Glyph />
        <div style={{ height: 16, overflow: 'hidden', fontWeight: 600, width: 9 }}>
          <div style={{ transform: `translateY(${-16 * (arrived ? roll : 0)}px)` }}>
            <div style={{ height: 16, lineHeight: '16px' }}>3</div>
            <div style={{ height: 16, lineHeight: '16px', color: pulse > 0.2 ? '#ff8a90' : '#f2f0ec' }}>4</div>
          </div>
        </div>
      </div>
      <svg width={17} height={13} viewBox="0 0 17 13" fill="none" stroke="#f2f0ec" strokeWidth={1.7} strokeLinecap="round">
        <path d="M1.5 4.5 A10 10 0 0 1 15.5 4.5" />
        <path d="M4 7.3 A6.4 6.4 0 0 1 13 7.3" />
        <circle cx={8.5} cy={10.5} r={1.2} fill="#f2f0ec" stroke="none" />
      </svg>
      <svg width={26} height={13} viewBox="0 0 26 13">
        <rect x={0.75} y={0.75} width={21.5} height={11.5} rx={3.2} fill="none" stroke="#f2f0ec" strokeOpacity={0.6} strokeWidth={1.2} />
        <rect x={2.5} y={2.5} width={16} height={8} rx={1.8} fill="#f2f0ec" />
        <rect x={23.3} y={4.2} width={1.8} height={4.6} rx={0.9} fill="#f2f0ec" fillOpacity={0.6} />
      </svg>
      <span>Thu 24 Sep 9:41</span>
    </div>
  );
};

const Cursor: React.FC<{ x: number; y: number; down: boolean }> = ({ x, y, down }) => (
  <svg width={22} height={30} viewBox="0 0 22 30" style={{ position: 'absolute', left: x - 3, top: y - 2, transform: `scale(${down ? 0.88 : 1})`, filter: 'drop-shadow(0 2px 3px rgba(0,0,0,0.6))' }}>
    <path d="M3 2 L3 24 L8.4 19 L12.2 27.6 L15.8 26 L12.1 17.6 L19.3 17.6 Z" fill="#000" stroke="#fff" strokeWidth={1.6} strokeLinejoin="round" />
  </svg>
);

const Key: React.FC<{ label: string; down: number; wide?: boolean }> = ({ label, down, wide }) => (
  <div
    style={{
      width: wide ? 150 : 128,
      height: 128,
      borderRadius: 22,
      background: 'linear-gradient(180deg, #2c2a29, #1a1918)',
      boxShadow: `0 ${14 - down * 10}px 0 #0a0a0a, 0 ${18 - down * 10}px 30px rgba(0,0,0,0.6), inset 0 2px 0 rgba(255,255,255,0.12)`,
      transform: `translateY(${down * 10}px)`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: font.system,
      fontSize: 62,
      color: down > 0.5 ? '#ff8a90' : color.bone,
      textShadow: down > 0.5 ? `0 0 18px ${color.hot}` : 'none',
    }}
  >
    {label}
  </div>
);

const Caption: React.FC<{ t: number; from: number; to: number; act: string; title: React.ReactNode; body: React.ReactNode; children?: React.ReactNode }> = ({ t, from, to, act, title, body, children }) => {
  const o = Math.min(flickIn(t, from, 0.25), 1 - ramp(t, to - 0.3, to));
  if (o <= 0) return null;
  const rise = (1 - ramp(t, from, from + 0.5, Easing.out(Easing.cubic))) * 30;
  return (
    <div style={{ position: 'absolute', left: 130, top: 250, width: 1060, opacity: o, transform: `translateY(${rise}px)` }}>
      <div style={{ fontFamily: font.limelight, fontSize: 30, letterSpacing: '0.3em', color: color.hot }}>{act}</div>
      <div style={{ fontFamily: font.limelight, fontSize: 112, lineHeight: 1.05, color: color.bone, margin: '14px 0 26px' }}>{title}</div>
      <div style={{ fontFamily: font.playfair, fontStyle: 'italic', fontSize: 46, lineHeight: 1.3, color: color.fog, maxWidth: 1000 }}>{body}</div>
      {children}
    </div>
  );
};

export const Demo = () => {
  const t = useAbs('demo');
  const [a, b] = S.demo;
  const show = ramp(t, a, a + 0.45);
  const cx = interpolate(t, [a + 0.3, C.glyphClick - 0.08], [560, 856], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic) });
  const cy = interpolate(t, [a + 0.3, C.glyphClick - 0.08], [380, 12], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic) });
  const cursorOut = ramp(t, C.glyphClick + 0.5, C.glyphClick + 0.8);
  const hidden = t >= C.keysCaption + 0.2 && t < C.popoverReopen;
  const open = t >= C.glyphClick && !hidden;
  const openedAt = t >= C.popoverReopen ? C.popoverReopen : C.glyphClick;
  const pop = ramp(t, openedAt, openedAt + 0.18, Easing.out(Easing.cubic));
  const closing = t >= C.keysCaption + 0.05 && t < C.keysCaption + 0.2 ? 1 - ramp(t, C.keysCaption + 0.05, C.keysCaption + 0.2) : 1;
  const r3 = (x: number) => ramp(t, x, x + 0.3);
  const focus = {
    business: 1 - 0.7 * (r3(C.familyCaption) - r3(C.freshCaption)),
    family: 1 - 0.7 * (r3(C.businessCaption) - r3(C.familyCaption) + r3(C.freshCaption) - r3(C.keysCaption)),
    rest: 1 - 0.7 * (r3(C.businessCaption) - r3(C.keysCaption)),
  };
  const blinds = t * 6;
  const keyDown = (i: number) => (t >= C.keyPresses[i] && t < C.keyPresses[3] + 0.25 ? ramp(t, C.keyPresses[i], C.keyPresses[i] + 0.05) : 0);
  return (
    <AbsoluteFill style={{ background: '#000', opacity: show * (1 - ramp(t, b - 0.35, b)) }}>
      <AbsoluteFill style={{ background: 'radial-gradient(ellipse at 70% 30%, #2b2927 0%, #121111 60%, #070707 100%)' }} />
      <div style={{ position: 'absolute', left: 0, top: 0, width: W, height: 1080 / K, transform: `scale(${K})`, transformOrigin: '0 0' }}>
        <MenuBar t={t} open={open} />
        {open && (
          <div
            style={{
              position: 'absolute',
              right: 12,
              top: 30,
              opacity: pop * closing,
              transform: `translateY(${(1 - pop) * -8}px) scale(${0.97 + 0.03 * pop})`,
              transformOrigin: '70% 0',
            }}
          >
            <Popover t={t} focus={focus} />
          </div>
        )}
        {cursorOut < 1 && (
          <div style={{ opacity: 1 - cursorOut }}>
            <Cursor x={cx} y={cy} down={t >= C.glyphClick - 0.05 && t < C.glyphClick + 0.08} />
          </div>
        )}
      </div>
      <AbsoluteFill
        style={{
          background: `repeating-linear-gradient(-24deg, rgba(255,255,255,0) ${blinds}px, rgba(255,255,255,0) ${blinds + 48}px, rgba(255,250,240,0.075) ${blinds + 58}px, rgba(255,250,240,0.075) ${blinds + 104}px, rgba(255,255,255,0) ${blinds + 112}px)`,
          mixBlendMode: 'screen',
        }}
      />
      <AbsoluteFill style={{ background: 'linear-gradient(90deg, rgba(0,0,0,0.55) 0%, rgba(0,0,0,0.25) 45%, transparent 60%)' }} />
      <Caption t={t} from={C.businessCaption} to={C.familyCaption} act="ACT I" title="Business" body={<>Every pull request waiting on your review. Asked by name, or through a team you&rsquo;re on.</>} />
      <Caption t={t} from={C.familyCaption} to={C.freshCaption} act="ACT II" title="Family" body={<>The ones you brought into this world. Review verdict and CI on every one.</>} />
      <Caption
        t={t}
        from={C.freshCaption}
        to={C.keysCaption}
        act="ACT III"
        title="Always fresh."
        body={
          <>
            It updates itself, fast and automatically.
            <br />
            <span style={{ color: color.bone }}>New favors arrive with a notification.</span>
          </>
        }
      />
      <Caption t={t} from={C.keysCaption} to={b} act="ACT IV" title="Always a keystroke away" body={<>From anywhere. Arrows, Enter, ⌘R.</>}>
        <div style={{ display: 'flex', gap: 26, marginTop: 50 }}>
          <Key label="⌃" down={keyDown(0)} />
          <Key label="⇧" down={keyDown(1)} />
          <Key label="⌘" down={keyDown(2)} />
          <Key label="P" down={keyDown(3)} />
        </div>
      </Caption>
    </AbsoluteFill>
  );
};
