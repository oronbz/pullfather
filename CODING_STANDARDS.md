# Coding standards

Judgement calls a reviewer checks on every diff. Mechanical rules live in the code (for example `TestDefaults` for test `UserDefaults`), not here.

## Domain language

- **Names follow `GLOSSARY.md`.** A type, folder or test named after a glossary term does only what that term means. When its job outgrows the term, rename it to one that covers the whole job, as `ArrivalNotifier` became `Notifier` once it also posted Verdicts.
- **The glossary matches the code.** A diff that changes when something happens updates the term's definition in the same commit, down to its edges: what resets it, what it ignores.

## Tests

- **Settings tests read as behaviour.** A test for a setting names its default and that it is remembered across launches, as `theThemeIsNoirByDefaultAndRememberedAcrossLaunches` does, and lives in `PreferencesTests`.
- **One suite per concern.** A new `SyncStore` test goes in the suite for its concern (see `docs/sync.md`), not in whichever file is open.
