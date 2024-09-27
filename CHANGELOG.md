## [Unreleased]

## [0.2.2] - 2024-09-27

* **Improvements**:
    * Updated SQLite3 gem version to 2.1.0

## [0.2.1] - 2024-09-24

* **Improved `resume` behavior:**
    * If no notes are provided, it will attempt to retrieve them from the last tracked task.
* **Enhanced `export_sheet` functionality:**
    * A new `notes` column has been added to the exported CSV file.
* **Minor bug fixes:**
    * Resolved issues related to resuming tasks with notes and deleting items.


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
