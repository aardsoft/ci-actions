#!/usr/bin/env bash
set -eu

# Get the tag from the environment
TAG_NAME=$1
DATE=$(date +'%Y-%m-%d')

# Find previous tag or use first commit if no previous tag exists
PREV_TAG=$(git describe --tags --abbrev=0 "$TAG_NAME^" 2>/dev/null || git rev-list --max-parents=0 HEAD)

# Header for the file
echo "## Release $TAG_NAME ($DATE)" > RELEASE_CHANGELOG.md
echo "" >> RELEASE_CHANGELOG.md

# Extract blocks using the friendly/primitive awk logic
git log $PREV_TAG..$TAG_NAME --pretty=format:"%B%n@@@" | awk '
  {
    # Case-insensitive search for "changelog:" anywhere on the line
    if (tolower($0) ~ /changelog:/) {
      p=1;
      # Strip everything up to and including "changelog:"
      sub(/^.*[Cc][Hh][Aa][Nn][Gg][Ee][Ll][Oo][Gg]:[ \t]*/, "");
    }
    # Hard stop at the delimiter
    if ($0 ~ /@@@/) {
      p=0;
    }
    # If the print flag is on and we are not on the delimiter line, print
    if (p && $0 !~ /@@@/) {
      print $0;
    }
  }' >> RELEASE_CHANGELOG.md

# Delete from line 1 until the first empty line is found
BODY_CONTENT=$(sed '1,/^$/d' RELEASE_CHANGELOG.md | tr -d '[:space:]')
if [ -z "$BODY_CONTENT" ]; then
    echo "ERROR: No 'Changelog:' content found in commits since $PREV_TAG."
    echo "Tried: git log $PREV_TAG..$TAG_NAME --pretty=format:'%B%n@@@':"
    git log $PREV_TAG..$TAG_NAME --pretty=format:"%B%n@@@"
    echo "Deleting remote tag and failing release..."
    # Clean up using the GH_TOKEN provided in the environment
    git push origin --delete "$TAG_NAME"
    gh release delete "$TAG_NAME" --cleanup-tag --yes
    exit 1
fi
