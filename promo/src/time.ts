import { Easing, interpolate, random, useCurrentFrame } from 'remotion';
import timeline from './timeline.json';

export const T = timeline;
export const S = timeline.scenes as Record<keyof typeof timeline.scenes, [number, number]>;
export const C = timeline.cues;

export const useAbs = (scene: keyof typeof S) => useCurrentFrame() / T.fps + S[scene][0];

export const ramp = (t: number, a: number, b: number, easing: (x: number) => number = Easing.inOut(Easing.cubic)) =>
  interpolate(t, [a, b], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing });

export const span = (t: number, a: number, b: number, fadeIn = 0.3, fadeOut = 0.3) =>
  Math.min(ramp(t, a, a + fadeIn), 1 - ramp(t, b - fadeOut, b));

export const flickIn = (t: number, a: number, len = 0.3) => {
  if (t < a) return 0;
  if (t > a + len) return 1;
  const r = random(`flick-${a}-${Math.floor(t * T.fps)}`);
  return 0.25 + 0.75 * r * ((t - a) / len) + 0.3 * ((t - a) / len);
};

export const frameRandom = (key: string, t: number, hold = 1) => random(`${key}-${Math.floor((t * T.fps) / hold)}`);
