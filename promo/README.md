# Promo video

A 67-second noir trailer for The Pullfather, built with [Remotion](https://www.remotion.dev). Everything is generated: the visuals are React and SVG, and the soundtrack (waltz, radio static, rain, typewriter) is synthesized by `audio/build.mjs`.

```sh
npm install
npm run studio   # live preview
npm run render   # writes out/pullfather-promo.mp4
```

`src/timeline.json` holds every scene boundary and cue. Both the picture and the soundtrack read it, so retiming happens there. The police radio voice uses the macOS `say` command, so the audio build needs a Mac.
