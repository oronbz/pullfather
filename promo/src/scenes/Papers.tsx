import React from 'react';
import { AbsoluteFill, Easing, interpolate } from 'remotion';
import { color, font } from '../theme';
import { C, S, ramp, span, useAbs } from '../time';

const BODY =
  'The trouble started, as it always does, with a small favor. Just a quick look, they said. Then another. By Friday there were forty-seven, and nobody could say who was waiting on whom. Witnesses describe the review queue as “stale, like week-old cannoli.” Authors report pinging reviewers in three separate channels. Reviewers report never hearing a thing. “I would have looked,” said one engineer, who asked not to be named. “I just didn’t know.” Police have no suspects. The pull requests, for their part, keep piling up. ';

const Paper: React.FC<{
  headline: [string, string];
  sub: string;
  photo: React.ReactNode;
  caption: string;
  stamp: string;
  stampAt: number;
  t: number;
  issue: string;
}> = ({ headline, sub, photo, caption, stamp, stampAt, t, issue }) => {
  const s = ramp(t, stampAt, stampAt + 0.09, Easing.in(Easing.quad));
  return (
    <div
      style={{
        width: 1400,
        height: 900,
        background: `radial-gradient(ellipse at 50% 40%, #e2ddd3 0%, ${color.paper} 60%, #b9b3a8 100%)`,
        boxShadow: '0 40px 90px rgba(0,0,0,0.8), inset 0 0 80px rgba(60,50,40,0.35)',
        padding: '34px 48px',
        boxSizing: 'border-box',
        color: '#161412',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: font.oldStandard, fontSize: 19, letterSpacing: '0.12em', borderBottom: '2px solid #161412', paddingBottom: 6 }}>
        <span>{issue}</span>
        <span>LATE CITY EDITION</span>
        <span>TWO CENTS</span>
      </div>
      <div style={{ fontFamily: font.fraktur, fontSize: 118, textAlign: 'center', lineHeight: 1.12 }}>The Daily Diff</div>
      <div style={{ borderTop: '5px double #161412', borderBottom: '2px solid #161412', height: 4, marginBottom: 12 }} />
      <div style={{ fontFamily: font.bebas, fontSize: 138, lineHeight: 0.92, textAlign: 'center', letterSpacing: '0.01em' }}>
        {headline[0]}
        <br />
        {headline[1]}
      </div>
      <div style={{ fontFamily: font.oldStandard, fontStyle: 'italic', fontSize: 34, textAlign: 'center', margin: '12px 0 16px', borderBottom: '2px solid #161412', paddingBottom: 12 }}>
        {sub}
      </div>
      <div style={{ display: 'flex', gap: 30, height: 300 }}>
        <div style={{ width: 470, flexShrink: 0 }}>
          <div style={{ height: 250, position: 'relative', overflow: 'hidden', border: '2px solid #161412', background: '#2a2826' }}>
            {photo}
            <div style={{ position: 'absolute', inset: 0, backgroundImage: 'radial-gradient(rgba(0,0,0,0.35) 1px, transparent 1.6px)', backgroundSize: '5px 5px', mixBlendMode: 'multiply' }} />
          </div>
          <div style={{ fontFamily: font.oldStandard, fontStyle: 'italic', fontSize: 18, marginTop: 6 }}>{caption}</div>
        </div>
        <div style={{ columnCount: 2, columnGap: 26, columnRule: '1px solid #55504a', fontFamily: font.oldStandard, fontSize: 19, lineHeight: 1.32, textAlign: 'justify', overflow: 'hidden', height: 300 }}>
          {BODY + BODY}
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          right: 70,
          top: 560,
          transform: `rotate(-11deg) scale(${interpolate(s, [0, 1], [2.6, 1])})`,
          opacity: s,
          border: `8px solid ${color.red}`,
          outline: `3px solid ${color.red}`,
          outlineOffset: 6,
          padding: '4px 30px',
          fontFamily: font.bebas,
          fontSize: 150,
          letterSpacing: '0.08em',
          color: color.red,
          lineHeight: 1,
          filter: 'url(#ink)',
        }}
      >
        {stamp}
      </div>
    </div>
  );
};

const QueuePhoto = () => (
  <div style={{ position: 'absolute', inset: 0, fontFamily: font.system, background: '#1b1a1a', padding: '12px 18px', filter: 'grayscale(1) contrast(1.15)' }}>
    {[
      ['Fix race in token refresh', '3d'],
      ['Bump fastlane to latest', '4d'],
      ['Migrate settings to SwiftUI', '5d'],
      ['Add offline banner', '6d'],
      ['Refactor push routing', '1w'],
      ['Update privacy manifest', '2w'],
    ].map(([title, age], i) => (
      <div key={title} style={{ display: 'flex', alignItems: 'center', gap: 10, height: 36, opacity: 1 - i * 0.13, color: '#e2ded8', fontSize: 16 }}>
        <div style={{ width: 22, height: 22, borderRadius: 11, background: ['#777', '#555', '#888', '#666', '#4a4a4a', '#707070'][i] }} />
        <div style={{ flex: 1 }}>{title}</div>
        <div style={{ color: '#9a958f', fontSize: 14 }}>review requested · {age}</div>
      </div>
    ))}
    <div style={{ color: '#9a958f', fontSize: 14, marginTop: 2 }}>+ 41 more</div>
  </div>
);

const WantedPhoto = () => (
  <div style={{ position: 'absolute', inset: 0, background: '#cfc8bb', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: '#1a1714' }}>
    <div style={{ fontFamily: font.rye, fontSize: 46, lineHeight: 1 }}>WANTED</div>
    <svg width={120} height={120} viewBox="0 0 120 120" style={{ margin: '6px 0' }}>
      <circle cx={60} cy={44} r={28} fill="#1a1714" />
      <path d="M10 120 C14 80 40 72 60 72 C80 72 106 80 110 120 Z" fill="#1a1714" />
      <text x={60} y={58} textAnchor="middle" fontSize={40} fontFamily={font.playfair} fontWeight={900} fill="#cfc8bb">?</text>
    </svg>
    <div style={{ fontFamily: font.oldStandard, fontSize: 18, letterSpacing: '0.1em' }}>FOR QUESTIONING IN PR #412</div>
  </div>
);

const spin = (t: number, a: number, b: number) => {
  const p = ramp(t, a, b, Easing.out(Easing.cubic));
  const settle = ramp(t, b, b + 0.25, Easing.out(Easing.back(3)));
  return {
    transform: `rotate(${(1 - p) * 1260 - 4}deg) scale(${0.04 + 0.86 * p + 0.04 * (1 - settle) * (p === 1 ? 1 : 0)})`,
    opacity: p > 0 ? 1 : 0,
  };
};

export const Papers = () => {
  const t = useAbs('papers');
  const [a, b] = S.papers;
  const [[s1, l1], [s2, l2]] = C.paperSpins;
  const drift1 = 1 + 0.05 * ramp(t, l1, s2 + 1, (x) => x);
  const drift2 = 1 + 0.05 * ramp(t, l2, b, (x) => x);
  return (
    <AbsoluteFill style={{ background: 'radial-gradient(ellipse at 50% 50%, #3b3836 0%, #121111 75%)', opacity: span(t, a, b, 0.15, 0.4) }}>
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', ...spin(t, s1, l1) }}>
        <div style={{ transform: `scale(${drift1})`, filter: `brightness(${1 - 0.45 * ramp(t, s2 + 0.3, l2)})` }}>
          <Paper
            t={t}
            issue="VOL. XLVII — No. 412"
            headline={['47 FAVORS ASKED.', 'NOBODY ANSWERED.']}
            sub="Pull Requests Pile Up Across Town; Reviewer “Never Saw a Thing”"
            photo={<QueuePhoto />}
            caption="EVIDENCE: The review queue, as found Tuesday morning."
            stamp="OVERDUE"
            stampAt={C.stamps[0]}
          />
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', ...spin(t, s2, l2) }}>
        <div style={{ transform: `scale(${drift2}) rotate(7deg)` }}>
          <Paper
            t={t}
            issue="VOL. XLVII — No. 413"
            headline={['REVIEWER MISSING', 'FOR THREE DAYS']}
            sub="Author “Just Wanted a Quick Look”; Pull Request Now 4,000 Lines"
            photo={<WantedPhoto />}
            caption="Last seen leaving the review queue, Tuesday."
            stamp="UNREVIEWED"
            stampAt={C.stamps[1]}
          />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
