import React from 'react';
import { AbsoluteFill, Audio, Sequence, staticFile } from 'remotion';
import { BoilDefs, FilmFX, Weave } from './fx';
import { City } from './scenes/City';
import { Demo } from './scenes/Demo';
import { End } from './scenes/End';
import { Leader } from './scenes/Leader';
import { Offer } from './scenes/Offer';
import { Papers } from './scenes/Papers';
import { Presents } from './scenes/Presents';
import { Reveal } from './scenes/Reveal';
import { S, T } from './time';

const SCENES: [keyof typeof S, React.FC][] = [
  ['leader', Leader],
  ['presents', Presents],
  ['city', City],
  ['papers', Papers],
  ['reveal', Reveal],
  ['demo', Demo],
  ['offer', Offer],
  ['end', End],
];

export const Promo = () => (
  <AbsoluteFill style={{ background: '#000' }}>
    <BoilDefs />
    <Weave>
      {SCENES.map(([name, Scene]) => {
        const from = Math.round(S[name][0] * T.fps);
        const to = Math.round(S[name][1] * T.fps);
        return (
          <Sequence key={name} from={from} durationInFrames={to - from} name={name}>
            <Scene />
          </Sequence>
        );
      })}
    </Weave>
    <FilmFX />
    <Audio src={staticFile('soundtrack.wav')} />
  </AbsoluteFill>
);
