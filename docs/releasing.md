# Releasing

The Pullfather ships as a zipped `Pullfather.app` on this repository's GitHub Releases, installed by the `pullfather` cask in [oronbz/tap](https://github.com/oronbz/homebrew-tap). The app is ad-hoc signed, not notarized, like Sitter and Shepherd.

One number names a release: `MARKETING_VERSION` on every target in `Pullfather.xcodeproj`, the `v`-prefixed tag, and the cask's `version`.

## Cutting a release

You need Xcode, and `gh` signed in with push access to `oronbz/pullfather` and `oronbz/homebrew-tap`. From the repo root, on a clean `main`:

```sh
make release 0.2.0
```

`make release VERSION=0.2.0` works too; leave the version off to be prompted for it. `make release` runs `scripts/release.sh`, which:

1. Checks its tools, the clean tree, the branch, and that the version is semver and not already tagged on origin.
2. Sets `MARKETING_VERSION` on every target, commits "Bump version to 0.2.0", and pushes `main`. If the project already carries that version, as it does for 0.1.0, there is nothing to commit and it only pushes.
3. Archives the Release configuration, ad-hoc signed and universal, and verifies the signature.
4. Zips the app with `ditto` and takes its sha256.
5. Creates the `v0.2.0` GitHub Release on the pushed commit, with the zip and generated notes.
6. Sets `version` and `sha256` in `Casks/pullfather.rb` in the tap and pushes it, or writes the cask there first if it is missing.

If a step fails after the push, fix the cause and finish the remaining steps by hand; running the script again for a version that is already tagged is refused.

## The cask

The cask requires Tahoe, because Homebrew's `depends_on macos:` only names major releases. `brew uninstall --cask pullfather` quits the app before removing it, and `--zap` also removes `~/Library/Application Support/Pullfather`, which holds the token, and the app's preferences.

After a release, check it the way a user gets it:

```sh
brew update && brew install --cask oronbz/tap/pullfather
```
