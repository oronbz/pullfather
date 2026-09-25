import React from 'react';
import { AbsoluteFill } from 'remotion';
import { color } from '../theme';

const Corner: React.FC<{ x: number; y: number; sx: number; sy: number }> = ({ x, y, sx, sy }) => (
  <g transform={`translate(${x} ${y}) scale(${sx} ${sy})`} stroke={color.bone} fill="none" strokeWidth={2.5}>
    <path d="M0 90 L0 0 L90 0" />
    <path d="M18 70 L18 18 L70 18" />
    <path d="M30 30 m0 0 a40 40 0 0 1 40 40" />
    <path d="M30 30 m0 0 a24 24 0 0 1 24 24" />
    <circle cx={30} cy={30} r={5} fill={color.bone} />
  </g>
);

export const Intertitle: React.FC<{ children: React.ReactNode; opacity?: number }> = ({ children, opacity = 1 }) => (
  <AbsoluteFill style={{ background: 'radial-gradient(ellipse at 50% 45%, #1d1b1a 0%, #0a0909 70%)' }}>
    <svg width={1920} height={1080} style={{ position: 'absolute', opacity: 0.9 * opacity }}>
      <rect x={70} y={60} width={1780} height={960} stroke={color.bone} strokeWidth={3} fill="none" />
      <rect x={88} y={78} width={1744} height={924} stroke={color.bone} strokeWidth={1} fill="none" opacity={0.6} />
      <Corner x={110} y={100} sx={1} sy={1} />
      <Corner x={1810} y={100} sx={-1} sy={1} />
      <Corner x={110} y={980} sx={1} sy={-1} />
      <Corner x={1810} y={980} sx={-1} sy={-1} />
      <g stroke={color.bone} strokeWidth={2} fill="none">
        <path d="M860 78 L960 110 L1060 78" />
        <path d="M860 1002 L960 970 L1060 1002" />
        <path d="M940 110 L960 128 L980 110" />
      </g>
    </svg>
    <AbsoluteFill style={{ alignItems: 'center', justifyContent: 'center', opacity }}>{children}</AbsoluteFill>
  </AbsoluteFill>
);

export const Rule: React.FC<{ width?: number }> = ({ width = 520 }) => (
  <svg width={width} height={24} style={{ margin: '28px 0' }}>
    <line x1={0} y1={12} x2={width / 2 - 26} y2={12} stroke={color.bone} strokeWidth={2} />
    <line x1={width / 2 + 26} y1={12} x2={width} y2={12} stroke={color.bone} strokeWidth={2} />
    <rect x={width / 2 - 9} y={3} width={18} height={18} transform={`rotate(45 ${width / 2} 12)`} fill={color.red} />
  </svg>
);
