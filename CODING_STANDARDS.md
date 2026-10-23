# Coding standards

Judgement calls a reviewer checks on every diff.

## Domain language

- **Names follow `GLOSSARY.md`.** A type, folder or test named after a glossary term does only what that term means. When its job outgrows the term, rename it to one that covers the whole job, as `ArrivalNotifier` became `Notifier` once it also posted Verdicts.
- **The glossary matches the code.** A diff that changes when something happens updates the term's definition in the same commit, down to its edges: what resets it, what it ignores.

## Tests

- **Settings tests read as behaviour.** A test for a setting names its default and that it is remembered across launches, as `theThemeIsNoirByDefaultAndRememberedAcrossLaunches` does, and lives in `PreferencesTests`.
- **One suite per concern.** A new `SyncStore` test goes in the `PullfatherTests/Sync/` suite named for its concern.
- **Tests build state through the support helpers.** `UserDefaults` comes from `TestDefaults`, and a hand-built row from `BusinessRow.fixture` or `FamilyRow.fixture`, so a new field or a leaked suite stays a one-file change.
