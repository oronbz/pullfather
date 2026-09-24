# The Pullfather

macOS menu bar app for GitHub pull requests. Tagline: "It's not personal. It's just business logic."

Design is settled. The app icon, menu bar template glyph and popover spec are in `design/`, starting from `design/README.md`. The live canvas is https://claude.ai/artifact/6n3ccwQSHFF257kD9uLvPf. Don't redesign the icon unless asked.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
