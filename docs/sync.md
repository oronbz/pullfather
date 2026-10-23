# How a pull request reaches a row

One Sync is one GraphQL request. Its data moves through these stages, each in one place:

1. **Query**: `SyncQuery.text` in `Pullfather/Sync/SyncQuery.swift`. Its searches share the `PullRequestFields` fragment.
2. **Decode**: `SyncQuery.decode` turns the response into a `SyncResult` of `PullRequest` values (same file, private `Response` and `Node` types).
3. **Rows**: `SyncStore.sync(token:)` in `Pullfather/Sync/SyncStore.swift` maps each `PullRequest` to a `BusinessRow` or `FamilyRow` (types in `Pullfather/Sync/Rows.swift`), then reports Arrivals and Verdicts through `onArrivals` and `onVerdicts`.
4. **Views**: `BusinessSection` and `FamilySection` in `Pullfather/Panel/` lay rows out with `PullRequestRow` and `RowText` from `PanelSection.swift`.

## Adding a field to a row

Touch every stage, in order:

- the `PullRequestFields` fragment, the `Node` decoding and `PullRequest` in `SyncQuery.swift`
- the row type and its `previews` in `Rows.swift`, and the mapping in `SyncStore.sync(token:)`
- `SyncFixtures.recorded` and the `SyncFixture.PullRequest` builder in `PullfatherTests/Support/SyncFixtures.swift`
- `BusinessRow.fixture` / `FamilyRow.fixture` in `PullfatherTests/Support/RowFixtures.swift`, which every hand-built test row goes through
- the view that shows it

## Tests

The `SyncStore` suites in `PullfatherTests/Sync/`, one per concern, share `SyncStoreTestCase`: a signed-in account on a `FakeGitHub`. `ReviewerActionTests` covers removing yourself and approving.
