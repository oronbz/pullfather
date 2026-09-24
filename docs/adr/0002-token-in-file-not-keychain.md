# GitHub token stored in a user-only file, not the Keychain

The GitHub token lives in a `0600` file under `~/Library/Application Support/Pullfather`, not in the Keychain. The app is ad-hoc signed for Homebrew distribution, so its code signature changes on every build and every update would trigger a "wants to use your keychain" prompt; a stable Team ID (which is how PullBar Pro avoids this) is not available. This matches how `gh` stores tokens on machines without a keyring. Do not move the token into the Keychain unless the app gains a stable Developer ID signature.
