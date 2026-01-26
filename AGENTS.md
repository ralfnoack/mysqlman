# Agent Coding Guidelines for This Repository

Welcome! This document is for automated coding agents (e.g., Copilot, GPT-4, Cursor) contributing to this repository. Please follow these practices for writing, refactoring, and testing code in this project.

---

## 1. Build, Lint, and Test

**Project Type:**  
This is a Bash shell tool for querying MySQL/MariaDB databases based on YAML configuration.

**Key Files:**  
- `mysqlman.sh` — main CLI script
- `mysqlman-connections.yaml` — stores DSNs and names
- `mysqlman-queries.yaml` — stores reusable queries

### Running the tool

- Show help:
  ```bash
  bash ./mysqlman.sh help
  ```

- List configured databases:
  ```bash
  bash ./mysqlman.sh list
  ```

- Example query (see README for more):
  ```bash
  bash ./mysqlman.sh query --db dev --query "SELECT 1;"
  ```

### Linting/Formatting

- **ShellCheck:**  
  Run ShellCheck to lint and catch issues:
  ```bash
  shellcheck mysqlman.sh
  ```
- **shfmt (optional):**  
  Format code with:
  ```bash
  shfmt -w mysqlman.sh
  ```

### Testing

- No formal test suite is included, but to check a single config/database:
  - Dry run:
    ```bash
    bash ./mysqlman.sh query --db dev --query "SELECT 1;" --dry-run
    ```
  - Real query (works as an integration test if DB is live):
    ```bash
    bash ./mysqlman.sh query --db dev --query "SELECT 1;"
    ```

- For shell script unit testing (future, if needed):
  - Use [bats](https://github.com/bats-core/bats-core):
    ```
    bats test/
    ```
    (No test directory yet.)

---

## 2. Code Style Guidelines

### General

- Write robust, portable Bash (see [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html))
- Use `#!/bin/bash` (bashisms allowed, but keep POSIX in mind if refactoring).
- Prefer long-form flags (e.g., `--db`, not `-d`).
- Use double-brackets `[[ ... ]]` for conditionals.
- Indent with 2 spaces (or project norm); no tabs.
- Functions are lower_snake_case with underscores.

### Imports (tool dependencies)

- All tools needed must be checked for existence at script start (e.g. `command -v yq` etc).
- The tool expects:
  - `yq` (YAML query, v3+ syntax)
  - `jq` (JSON filter)
  - `mysql` or `mariadb` (MariaDB/MySQL CLI)
- Any new dependencies require a check and an error message for missing tools.

### Formatting, Output

- Output should be column-aligned for listings.
- When showing credentials in DSNs, mask passwords by default.
- Output error messages in red (use ANSI codes; see script for examples).
- Help/usage text should be kept up to date with all new flags and examples.
- When adding new flags, update both parser and help text.

### Types & Error Handling

- Always check for errors and exit with nonzero code on fatal errors.
- Gracefully handle missing YAML keys, missing files, and missing tools.
- For string parsing, robustly handle edge cases (e.g., empty password, empty DB, odd DSN shapes).
- When shelling out to CLI tools, check for their exit statuses when writing new capabilities.
- When modifying, ensure queries cannot leak passwords to logs or debug output.

### Naming conventions

- Variables: lower_snake_case, ALL_CAPS for constants (e.g., `CONFIG_FILE`).
- Functions: lower_snake_case.
- YAML keys: `name`, `dsn`, `query`, `description`.

### Logging & Debug

- Always log queries run (with masked credentials).
- Use `--debug` flag to print real commands (but mask passwords).
- For future logging, keep log output append-only and timestamped if extended.

### Configuration & Extension

- YAML is used for databases and queries.
- Any new config (global options, default databases, etc.) should use YAML for consistency.
- Maintain backwards-compatible change to flag names and DSN structure.

### Comments

- Use block comments for functions and sections.
- Keep inline comments for complex parsing or bash gotchas.
- Whenever adding advanced regex or sed, explain all captures briefly.

---

## 3. Cursor or Copilot Rules

- **No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` are found as of this analysis.**
- If such rules are added by humans, summarize and incorporate their intent here.
- Do not hardcode username, password, or host in committed code or tests.

---

## 4. General Guidance for Agents

- Never commit secrets (YAML files should always be sample or redacted in git).
- Never add test files that might leak real production endpoints or data.
- Always update AGENTS.md and README.md if adding/removing major features, flags, or config options.
- If bootstrapping new features, always validate with a dry run first.
- Preserve and improve robustness: prefer over-explaining to ambiguous automation.
