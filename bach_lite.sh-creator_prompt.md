Create a standalone bash script named `./bach_lite.sh` by extracting and consolidating functions from the `src/bach/` directory. Ensure the created script follows all conventions specified in `./coding_conventions/`.

## Target Functions
Locate and extract the following functions from anywhere within `src/bach/`:
- **archive**: Handles file archiving operations
- **echo_banner**: Displays formatted banner messages

## Dependencies
- Analyze the target functions to identify all their dependencies
- Trace through function calls recursively to find all required helper functions
- Include only the minimal set of dependencies needed for functionality
- Common dependencies might include: timestamp utilities, color codes, formatting helpers, etc.

## Script Organization
1. **Configuration/Constants**: ANSI codes, global variables, etc.
2. **Utility Functions**: Helper functions for formatting, display, etc.
3. **Core Functions**: The main `archive` and `echo_banner` functions
4. **Main Execution**: Add a dispatcher that allows users to call specific functions by name via command line arguments, providing usage help when no arguments are given and error handling for unknown functions.

## Simplifications
- Replace complex logging calls with direct `echo` statements where possible
- Replace log_color with echo_color with minimal set of ansi color codes
- Remove unnecessary abstractions and external dependencies
- Inline small functions if they're only used once
- Keep only what's essential for the two core functions to operate

## Output Requirements
- Self-contained script with no external dependencies
- Executable permissions (`chmod +x`)
- Brief header comment documenting the script's purpose and source files
- Clear section comments separating different parts of the script

## Validation
The final script should:
- Run without errors in a standard bash environment
- Successfully execute both archiving and banner display operations
- Be lightweight, readable, and maintainable

## Implementation Process
1. Search `src/bach/` directory to locate the target functions
2. Analyze each function to identify all dependencies (functions, variables, constants)
3. Recursively trace dependencies until you have the complete set
4. Extract and consolidate into the new script with logical organization
5. Test for completeness and functionality
