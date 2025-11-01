#!/bin/bash

# Script to fix consecutive double-asterisk lines in markdown files
# Inserts blank lines between them to prevent line merging
#
# Usage: Run from anywhere in the repository
#   ./scripts/fix-markdown-formatting.sh

set -euo pipefail

# Get the repository root directory (parent of the scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$REPO_DIR"

# Find all .md files and check for consecutive ** lines
echo "Scanning for markdown files with consecutive ** lines..."
echo ""

found_issues=false

while IFS= read -r file; do
    # Use awk to find consecutive lines starting with **
    if awk '
        BEGIN { prev_is_double_star = 0; found = 0 }
        /^\*\*/ {
            if (prev_is_double_star) {
                found = 1
                exit 0
            }
            prev_is_double_star = 1
        }
        !/^\*\*/ {
            prev_is_double_star = 0
        }
        END { exit !found }
    ' "$file"; then
        echo "Found issue in: $file"
        found_issues=true

        # Create backup
        cp "$file" "$file.bak"

        # Fix the file: insert blank line before ** if previous line also starts with **
        awk '
            BEGIN { prev_line = "" }
            {
                current_line = $0
                # If current line starts with ** and previous line starts with **
                if (current_line ~ /^\*\*/ && prev_line ~ /^\*\*/) {
                    # Insert blank line before current line
                    print ""
                }
                print current_line
                prev_line = current_line
            }
        ' "$file.bak" > "$file"

        # Show what changed
        echo "  Fixed: inserted blank lines between consecutive ** lines"
        echo ""
    fi
done < <(find "$REPO_DIR" -name "*.md" -type f)

if [ "$found_issues" = false ]; then
    echo "No issues found! All markdown files are properly formatted."
else
    echo "---"
    echo "Done! Modified files have been updated."
    echo "Backups saved with .bak extension."
    echo ""
    echo "To remove backups after verifying:"
    echo "  find $REPO_DIR -name '*.md.bak' -delete"
fi
