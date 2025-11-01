# Maintenance Scripts

This directory contains utility scripts for maintaining the SWFRecompDocs repository.

## Available Scripts

### fix-markdown-formatting.sh

Fixes markdown formatting issues where consecutive lines starting with `**` (bold text or metadata fields) get merged into a single line by markdown viewers.

**Problem:**

Without blank lines between consecutive `**` lines, markdown renderers merge them into a single line.

For example, this problematic format:
```markdown
**Date:** 2025-11-01

**Repository:** SWFRecomp
```

Gets rendered as: "**Date:** 2025-11-01 **Repository:** SWFRecomp"

> **Note:** We can't show the actual problem in this README because the script automatically fixes it! The example above already has a blank line inserted between the fields.

**Solution:**

The script automatically inserts blank lines between consecutive `**` lines:

```markdown
**Date:** 2025-11-01

**Repository:** SWFRecomp
```

**Usage:**

```bash
# Run from anywhere in the repository
./scripts/fix-markdown-formatting.sh
```

**What it does:**

1. Scans all `.md` files in the repository
2. Identifies files with consecutive lines starting with `**`
3. Inserts blank lines between them
4. Creates `.bak` backup files before modifying
5. Reports which files were fixed

**When to use:**

- After adding or updating documentation with metadata fields
- When you notice metadata fields appearing on one line in the markdown viewer
- As a maintenance task to ensure all docs render properly

**Note:** The script creates backups with `.bak` extension. After verifying the changes look correct, you can remove them with:

```bash
find . -name '*.md.bak' -delete
```

## Adding New Scripts

When adding new maintenance scripts to this directory:

1. Make the script executable: `chmod +x scripts/your-script.sh`
2. Add usage comments at the top of the script
3. Update this README with documentation
4. Use relative paths so scripts work from any directory
5. Consider creating backups before modifying files
