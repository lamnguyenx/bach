# How to Format Bash Script Section Banners

1. **Start files with shebang and main header**. Use 62 equal signs for borders, UPPERCASE center-aligned title, followed by 1-2 line description.

2. **Use subsection headers for logical groupings**. Use 35 hyphens for borders, lowercase center-aligned title with ~12 leading spaces.

3. **Add one blank line before subsection headers**. This separates them from preceding code.

4. **Never add blank lines after subsection headers**. Code or comments should immediately follow.

5. **Add one blank line after file header descriptions**. This separates the main header from the first subsection.

6. **Center-align all banner text**. Main headers need ~25 total spaces of padding, subsection headers need ~12 leading spaces.

7. **Keep descriptions concise**. One line is ideal, two lines maximum for file headers.

## Example:

```bash
# RULE 1: Start files with shebang and main header
#!/bin/bash
# ==============================================================
#                         COMMON
# ==============================================================
# Consolidated common utilities for development environment

#!/bin/bash
# ==============================================================
#                         DATABASE UTILS
# ==============================================================
# Database connection helpers and query functions
# Supports PostgreSQL, MySQL, and SQLite

# RULE 2: Use subsection headers for logical groupings
# -----------------------------------
#            essentials
# -----------------------------------

# -----------------------------------
#            string utilities
# -----------------------------------

# RULE 3: Add one blank line before subsection headers
function reload_config() {
    source /etc/app/config.sh
}

# -----------------------------------
#            validation
# -----------------------------------

# RULE 4: Never add blank lines after subsection headers
# -----------------------------------
#            parsing
# -----------------------------------
function parse_json() {
    echo "$1" | jq -r "$2"
}

# RULE 5: Add one blank line after file header descriptions
#!/bin/bash
# ==============================================================
#                         NETWORK
# ==============================================================
# Network utilities and API helpers

# -----------------------------------
#            http requests
# -----------------------------------

# RULE 6: Center-align all banner text
# ==============================================================
#                         MAIN SECTION
# ==============================================================

# -----------------------------------
#            subsection name
# -----------------------------------

# RULE 7: Keep descriptions concise
# Good - one line:
# Database connection and query utilities

# Good - two lines with detail:
# Database connection and query utilities
# Supports PostgreSQL, MySQL, and SQLite

# Bad - too verbose:
# This file contains all the database-related functions
# that we use throughout the application including
# connection management and query execution
```