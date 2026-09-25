import React from 'react';
import { color } from './theme';

export const Hat: React.FC<{ glow: number; lit?: number }> = ({ glow, lit = 1 }) => (
  <g>
    <ellipse cx={512} cy={624} rx={322} ry={80} fill="#121010" />
    <ellipse cx={512} cy={618} rx={314} ry={72} fill="none" stroke="#fff" strokeWidth={3} opacity={0.12 * lit} />
    <path d="M324 616 C318 486 350 364 420 324 C462 302 492 332 512 324 C532 332 562 302 604 324 C674 364 706 486 700 616 A188 42 0 0 1 324 616 Z" fill="#1D1818" />
    <path d="M360 600 C356 490 380 390 424 346 C400 400 392 500 396 604 Z" fill="#fff" opacity={0.09 * lit} />
    <path d="M436 360 C476 342 548 342 588 360" stroke="#0D0A0A" fill="none" strokeWidth={10} strokeLinecap="round" />
    <path d="M330 548 C420 568 604 568 694 548 L698 604 C604 626 420 626 326 604 Z" fill={color.bone} />
    <path d="M668 578 L780 350" stroke={color.bone} fill="none" strokeWidth={16} strokeLinecap="round" />
    <path d="M722 470 C748 440 786 430 826 436" stroke={color.bone} fill="none" strokeWidth={14} strokeLinecap="round" />
    <circle cx={668} cy={580} r={18} fill="#1D1818" />
    <circle cx={826} cy={436} r={24} fill={color.bone} />
    <circle cx={784} cy={342} r={34 + glow * 30} fill={color.hot} opacity={0.25 * glow} style={{ filter: 'blur(14px)' }} />
    <circle cx={784} cy={342} r={34} fill={color.red} stroke={color.bone} strokeWidth={10} />
  </g>
);
