# How a pull request reaches a row

One Sync is one search request, then one review request per 100 Family pull requests. If any of them fails, the whole Sync fails and the last good one stays. Its data moves through these stages, each in one place:

1. **Query**: `SyncQuery.text` in `Pullfather/Sync/SyncQuery.swift`. Its searches share the `PullRequestFields` fragment.
2. **Decode**: `SyncQuery.decode` turns the response into a `SyncResult` of `PullRequest` values (same file, private `Response` and `Node` types).
3. **Reviews**: `ReviewQuery` in `Pullfather/Sync/ReviewQuery.swift` fetches reviews and review threads for the Family pull requests by ID, as `FetchedReviews`. It is a separate request because GitHub prices a query by how many connections it could open, from the searches' `first` limits down: nesting threads under the searches would cost about 20 times as much, however few pull requests there are. `ReviewActivity` (`Pullfather/Sync/ReviewActivity.swift`) turns a pull request and its `FetchedReviews` into a Review State.
4. **Rows**: `SyncStore.sync(token:)` in `Pullfather/Sync/SyncStore.swift` maps each `PullRequest` to a `BusinessRow` or `FamilyRow` (types in `Pullfather/Sync/Rows.swift`), then reports Arrivals and Verdicts through `onArrivals` and `onVerdicts`.
5. **Views**: `BusinessSection` and `FamilySection` in `Pullfather/Panel/` lay rows out with `PullRequestRow` and `RowText` from `PanelSection.swift`.

## Adding a field to a row

Touch every stage, in order:

- the `PullRequestFields` fragment, the `Node` decoding and `PullRequest` in `SyncQuery.swift`, or `ReviewQuery` for review data on Family rows
- the row type and its `previews` in `Rows.swift`, and the mapping in `SyncStore.sync(token:)`
- `SyncFixtures.recorded` and the `SyncFixture.PullRequest` builder in `PullfatherTests/Support/SyncFixtures.swift`; review data goes in their `reviews` map, which `FakeGitHub` answers `ReviewQuery` from
- `BusinessRow.fixture` / `FamilyRow.fixture` in `PullfatherTests/Support/RowFixtures.swift`, which every hand-built test row goes through
- the view that shows it

## Tests

The `SyncStore` suites in `PullfatherTests/Sync/`, one per concern, share `SyncStoreTestCase`: a signed-in account on a `FakeGitHub`. `ReviewerActionTests` covers removing yourself and approving, and `ReviewStateTests` covers every Review State rule and the review request.
