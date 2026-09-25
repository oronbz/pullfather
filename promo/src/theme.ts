import { loadFont as loadPlayfair } from '@remotion/google-fonts/PlayfairDisplay';
import { loadFont as loadLimelight } from '@remotion/google-fonts/Limelight';
import { loadFont as loadElite } from '@remotion/google-fonts/SpecialElite';
import { loadFont as loadFraktur } from '@remotion/google-fonts/UnifrakturMaguntia';
import { loadFont as loadOldStandard } from '@remotion/google-fonts/OldStandardTT';
import { loadFont as loadBebas } from '@remotion/google-fonts/BebasNeue';
import { loadFont as loadMono } from '@remotion/google-fonts/JetBrainsMono';
import { loadFont as loadRye } from '@remotion/google-fonts/Rye';

const latin = { subsets: ['latin' as const] };

export const font = {
  playfair: loadPlayfair('normal', { weights: ['400', '700', '900'], ...latin }).fontFamily,
  limelight: loadLimelight('normal', { weights: ['400'], ...latin }).fontFamily,
  elite: loadElite('normal', { weights: ['400'], ...latin }).fontFamily,
  fraktur: loadFraktur('normal', { weights: ['400'], ...latin }).fontFamily,
  oldStandard: loadOldStandard('normal', { weights: ['400', '700'], ...latin }).fontFamily,
  bebas: loadBebas('normal', { weights: ['400'], ...latin }).fontFamily,
  mono: loadMono('normal', { weights: ['400', '700'], ...latin }).fontFamily,
  rye: loadRye('normal', { weights: ['400'], ...latin }).fontFamily,
  system: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
};
loadPlayfair('italic', { weights: ['400', '700', '900'], ...latin });
loadOldStandard('italic', { weights: ['400'], ...latin });

export const color = {
  ink: '#070707',
  coal: '#141313',
  smoke: '#2a2828',
  ash: '#6f6b67',
  fog: '#aaa49d',
  bone: '#EDE3D1',
  paper: '#d9d4ca',
  red: '#B3202A',
  hot: '#E3313C',
};
