# The Pullfather — design assets

macOS menu bar app for GitHub pull requests (a PullBar Pro alternative).

**Tagline:** "It's not personal. It's just business logic."

**Live design canvas:** https://claude.ai/artifact/6n3ccwQSHFF257kD9uLvPf
(app icon, menu bar glyph, popover mockup; the source of truth if these files drift)

## Files

| File | Use |
|---|---|
| `AppIcon.svg` | Master app icon, 1024×1024 vector, macOS squircle grid (824px body at 100px inset) |
| `AppIcon-1024.png` | Rendered master |
| `AppIcon.iconset/` | All macOS sizes 16–512 @1x/@2x, drop into an asset catalog AppIcon set |
| `AppIcon.icns` | Built from the iconset with `iconutil` |
| `MenuBarIcon.svg` | Menu bar glyph, 18×18 vector, black on transparent. Use as a **Template Image** (Render As: Template) with Preserve Vector Data |
| `MenuBarIcon.png`, `MenuBarIcon@2x.png` | Raster fallbacks of the glyph |
| `popover-reference.png` | Popover mockup render (2×) |
| `menubar-glyph-reference.png` | Glyph on light/dark bars, idle and with a count |

## Concept

A noir fedora with a git branch tucked in the hatband like a feather. The branch forks once and ends in a red commit node.

## Palette

| Token | Hex | Where |
|---|---|---|
| Oxblood light / mid / dark | `#A3222A` / `#6A1017` / `#3A070B` | Icon background radial |
| Hat black | `#1D1818` (crown), `#121010` (brim) | Icon |
| Bone | `#EDE3D1` | Hatband, branch |
| Commit red | `#B3202A` | Branch tip node, accent |
| Brass | `#C9A45C` | Popover section labels |
| Popover surface | `rgba(33,27,25,0.94)` | Popover background |
| Text primary / secondary / muted | `#F2E9DA` / `#B8AB98` / `#9C9083` | Popover text |
| CI pass / running / fail | `#4FA464` / `#D9A441` / `#D9534A` | Status icons (check / ring / cross) |

## Popover

- Header: mini app icon, "The Pullfather" in Playfair Display 700 at 20pt, tagline in Playfair Display italic at 13pt, refresh button.
- **BUSINESS**: PRs awaiting your review (avatar, title, repo #number · age, CI status).
- **FAMILY**: your own PRs (title, repo #number · age, review badge, CI status).
- Footer: Open GitHub ⌘O, Settings… ⌘,, Quit The Pullfather ⌘Q.
- Body text uses the system font (SF Pro) at 13pt, with 11.5pt metadata. Width 384pt, corner radius 12, row radius 7.
