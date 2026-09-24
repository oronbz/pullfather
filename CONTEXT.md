# The Pullfather

A macOS menu bar app that shows the GitHub pull requests waiting on you and the ones you opened, kept fresh enough to trust at a glance.

## Language

### Sections

**Business**:
Open, non-draft pull requests where your review is requested, either by name or through a team you belong to.
_Avoid_: Review queue, inbox, to-review, review requests (as a section name)

**Family**:
Open pull requests you authored, drafts included.
_Avoid_: Assigned, mine, my PRs

**Count**:
The number shown next to the menu bar glyph: the size of Business by default, or of Family, or nothing, as the user chooses. Hidden when zero.
_Avoid_: Badge, counter

### Review

**Review Request**:
A pending ask for your review on a pull request. It ends when you submit a review or the author withdraws it.

**Team Review Request**:
A Review Request that reaches you through a team you belong to rather than by name.

**Review State**:
The overall review verdict on a Family pull request: Approved, Changes requested, or none yet.

**Checks**:
The combined CI result on a pull request's latest commit: passing, running, or failing.
_Avoid_: Build, CI status, pipeline

### Time

**Waiting Time**:
How long a Business pull request has waited since the most recent Review Request to you or your team; a re-request restarts it.
_Avoid_: Age

**Last Activity**:
How long since a Family pull request was last updated.
_Avoid_: Age

### Sync

**Sync**:
One refresh of Business, Family and Count together from GitHub, so they never disagree.
_Avoid_: Poll, fetch, reload

**Arrival**:
A pull request entering Business that was not there on the previous Sync.
