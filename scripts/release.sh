#!/bin/bash
set -euo pipefail

REPO="oronbz/pullfather"
TAP_REPO="oronbz/homebrew-tap"
CASK_FILE="Casks/pullfather.rb"
PROJECT="Pullfather.xcodeproj"
SCHEME="Pullfather"
BUNDLE_ID="com.oronbz.Pullfather"
WORK_DIR="$(mktemp -d -t pullfather-release)"
ARCHIVE_PATH="$WORK_DIR/Pullfather.xcarchive"
ZIP_PATH="$WORK_DIR/Pullfather.zip"
TAP_CLONE="$WORK_DIR/homebrew-tap"

red()   { printf '\033[1;31m%s\033[0m\n' "$*"; }
green() { printf '\033[1;32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

die() { red "Error: $*" >&2; exit 1; }

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

write_cask() {
    local path="$1" version="$2" sha256="$3"
    cat > "$path" <<CASK
cask "pullfather" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/$REPO/releases/download/v#{version}/Pullfather.zip"
  name "The Pullfather"
  desc "Menu bar app for GitHub pull requests"
  homepage "https://github.com/$REPO"

  depends_on macos: :tahoe

  app "Pullfather.app"

  uninstall quit: "$BUNDLE_ID"

  zap trash: [
    "~/Library/Application Support/Pullfather",
    "~/Library/Preferences/$BUNDLE_ID.plist",
  ]
end
CASK
}

command -v gh         >/dev/null 2>&1 || die "gh CLI is required (brew install gh)"
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild is required (install Xcode)"
command -v ditto      >/dev/null 2>&1 || die "ditto is required"

[[ -f "$PROJECT/project.pbxproj" ]] || die "Run this script from the project root"

if [[ -n "$(git status --porcelain)" ]]; then
    die "Working tree is not clean. Commit or stash changes first."
fi

[[ "$(git branch --show-current)" == "main" ]] || die "Release from main"

CURRENT_VERSION=$(sed -nE 's/^[[:space:]]*MARKETING_VERSION = ([^;]+);$/\1/p' "$PROJECT/project.pbxproj" | sort -u)

[[ -n "$CURRENT_VERSION" ]] || die "Could not read MARKETING_VERSION from $PROJECT"
[[ "$(printf '%s\n' "$CURRENT_VERSION" | wc -l)" -eq 1 ]] \
    || die "Targets disagree on MARKETING_VERSION: $(echo $CURRENT_VERSION)"

if [[ -n "${1:-}" ]]; then
    NEW_VERSION="$1"
else
    bold "Current version: $CURRENT_VERSION"
    printf "New version: "
    read -r NEW_VERSION
fi

[[ -n "$NEW_VERSION" ]] || die "Version cannot be empty"
[[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version must be semver (e.g. 1.0.0)"

if [[ -n "$(git ls-remote --tags origin "refs/tags/v$NEW_VERSION")" ]]; then
    die "v$NEW_VERSION is already tagged on origin"
fi

bold "Releasing v$NEW_VERSION (current: $CURRENT_VERSION)"
echo

bold "[1/6] Bumping version to $NEW_VERSION..."

if [[ "$NEW_VERSION" == "$CURRENT_VERSION" ]]; then
    green "  Already at $NEW_VERSION, nothing to bump"
else
    sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION;/MARKETING_VERSION = $NEW_VERSION;/g" \
        "$PROJECT/project.pbxproj"
    green "  Version bumped in $PROJECT"
fi

bold "[2/6] Committing and pushing..."

if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git commit -m "Bump version to $NEW_VERSION"
fi
git push

green "  Pushed to origin/main"

bold "[3/6] Building Release archive..."

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    -quiet \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM= \
    || die "Archive build failed"

APP_PATH="$ARCHIVE_PATH/Products/Applications/Pullfather.app"
[[ -d "$APP_PATH" ]] || die "Archive produced no app at $APP_PATH"
codesign --verify --deep --strict "$APP_PATH" || die "Ad-hoc signature does not verify"

green "  Archive built ($(lipo -archs "$APP_PATH/Contents/MacOS/Pullfather"))"

bold "[4/6] Creating zip..."

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

green "  Zip created (sha256: $SHA256)"

bold "[5/6] Creating GitHub release v$NEW_VERSION..."

gh release create "v$NEW_VERSION" "$ZIP_PATH" \
    --repo "$REPO" \
    --target "$(git rev-parse HEAD)" \
    --title "The Pullfather v$NEW_VERSION" \
    --generate-notes

RELEASE_URL="https://github.com/$REPO/releases/tag/v$NEW_VERSION"
green "  Release created: $RELEASE_URL"

bold "[6/6] Updating Homebrew tap..."

gh repo clone "$TAP_REPO" "$TAP_CLONE" -- --depth 1 --quiet

CASK="$TAP_CLONE/$CASK_FILE"

if [[ -f "$CASK" ]]; then
    OLD_CASK_VERSION=$(grep -m1 'version "' "$CASK" | sed 's/.*version "//; s/".*//')
    sed -i '' "s/version \"$OLD_CASK_VERSION\"/version \"$NEW_VERSION\"/" "$CASK"

    OLD_SHA=$(grep -m1 'sha256 "' "$CASK" | sed 's/.*sha256 "//; s/".*//')
    sed -i '' "s/sha256 \"$OLD_SHA\"/sha256 \"$SHA256\"/" "$CASK"

    TAP_MESSAGE="Update pullfather to $NEW_VERSION"
    BREW_HINT="brew update && brew upgrade --cask pullfather"
else
    mkdir -p "$(dirname "$CASK")"
    write_cask "$CASK" "$NEW_VERSION" "$SHA256"
    TAP_MESSAGE="Add pullfather $NEW_VERSION"
    BREW_HINT="brew update && brew install --cask oronbz/tap/pullfather"
fi

(
    cd "$TAP_CLONE"
    git add -A
    git commit -m "$TAP_MESSAGE"
    git push
)

green "  Homebrew tap updated"

echo
green "========================================="
green "  Released The Pullfather v$NEW_VERSION"
green "========================================="
echo
echo "  GitHub:   $RELEASE_URL"
echo "  Homebrew: $BREW_HINT"
echo
