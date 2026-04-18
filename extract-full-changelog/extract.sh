#!/usr/bin/env bash
set -eu

OUTPUT_FILE="FULL_CHANGELOG.md"
echo "# Project Changelog" > "$OUTPUT_FILE"

# Get tags newest first
TAGS=$(git tag --sort=-creatordate)

for TAG_NAME in $TAGS; do
    DATE=$(git log -1 --format=%as "$TAG_NAME")
    PREV_TAG=$(git describe --tags --abbrev=0 "$TAG_NAME^" 2>/dev/null || git rev-list --max-parents=0 HEAD)

    if [ "$TAG_NAME" = "$PREV_TAG" ]; then continue; fi

    echo -e "\n## Release $TAG_NAME ($DATE)" >> "$OUTPUT_FILE"

    # Capture changelog content into a variable
    CONTENT=$(git log "$PREV_TAG..$TAG_NAME" --pretty=format:"%B%n@@@" | awk '
      {
        if (tolower($0) ~ /changelog:/) {
          p=1;
          sub(/^.*[Cc][Hh][Aa][Nn][Gg][Ee][Ll][Oo][Gg]:[ \t]*/, "");
        }
        if ($0 ~ /@@@/) { p=0; }
        if (p && $0 !~ /@@@/) { print $0; }
      }')

    if [ -n "$(echo "$CONTENT" | tr -d '[:space:]')" ]; then
        # Standard Output
        echo "$CONTENT" >> "$OUTPUT_FILE"
    else
        # Fallback Output
        echo -e "\n> [!NOTE]\n> **Legacy Fallback:** No structured changelog entries found. Listing commits instead." >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
        git log "$PREV_TAG..$TAG_NAME" --pretty=format:"* %s" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
done

echo "Done! Generated $OUTPUT_FILE"
