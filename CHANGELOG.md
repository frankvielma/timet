## [Unreleased]

## [0.2.0] - 2024-09-24

* **Improved code quality:**
    * Enforces consistent quoting style with `RuboCop` integration.
    * Removes unused gems (`mini_portile2`) from the `Gemfile`.
* **Database enhancements:**
    * Adds a new column named "notes" to the `items` table to store additional information about tracked time entries.
* **Command-line improvements:**
    * Allows adding notes to a new time entry using the `start` command with the `--notes` option (e.g., `timet start work --notes="meeting with client"`).
    * Improves formatting and clarity of some command descriptions.
* **General code formatting:**
    * Uses single quotes (`'`) for strings and source paths in the `Gemfile`.

## [0.1.0] - 2024-08-01

- Initial release
