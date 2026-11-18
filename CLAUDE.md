# The Pullfather

macOS menu bar app for GitHub pull requests. Tagline: "It's not personal. It's just business logic."

Design is settled. The app icon, menu bar template glyph and popover spec are in `design/`, starting from `design/README.md`. The live canvas is https://claude.ai/artifact/6n3ccwQSHFF257kD9uLvPf. Don't redesign the icon unless asked.

Adding a field to a row, or tracing a pull request from the GitHub query to the popover: `docs/sync.md`.

Release: `make release x.y.z` on `main`; a feature bumps minor, a fix bumps patch. See `docs/releasing.md`.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Name domain concepts (identifiers, tests, tickets, PR text) with the terms in root `GLOSSARY.md`; never use a word from its _Avoid_ lists. ADRs live in `docs/adr/`; see `docs/agents/domain.md`.
