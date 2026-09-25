import { color, font } from '../theme';
import { S, flickIn, span, useAbs } from '../time';
import { Intertitle, Rule } from './Intertitle';

export const Presents = () => {
  const t = useAbs('presents');
  const [a, b] = S.presents;
  const card1 = Math.min(flickIn(t, a + 0.25), 1 - Math.min(1, Math.max(0, (t - (a + 2.2)) / 0.25)));
  const card2 = span(t, a + 2.55, b - 0.1, 0.35, 0.45);
  return (
    <Intertitle opacity={Math.max(0.0001, t < a + 2.5 ? card1 : card2)}>
      {t < a + 2.5 ? (
        <div style={{ textAlign: 'center', color: color.bone }}>
          <div style={{ fontFamily: font.limelight, fontSize: 84, letterSpacing: '0.28em', paddingLeft: '0.28em' }}>
            PULL REQUEST PICTURES
          </div>
          <Rule />
          <div style={{ fontFamily: font.playfair, fontStyle: 'italic', fontSize: 62 }}>presents</div>
        </div>
      ) : (
        <div style={{ textAlign: 'center', color: color.bone, fontFamily: font.playfair, fontStyle: 'italic', fontSize: 92, lineHeight: 1.25 }}>
          A tale of favors,
          <br />
          family,
          <br />
          <span style={{ fontWeight: 700 }}>and pull requests.</span>
        </div>
      )}
    </Intertitle>
  );
};
