## [Unreleased]

## [1.3.0] - 2024-10-22

**Improvements:**

- **Refactor `TimeReport` to use `TimeReportHelper` module for utility methods:**

  - Extracted utility methods (`add_hashes`, `date_ranges`, `format_item`, `valid_date_format?`) into a new `TimeReportHelper` module.
  - Updated `TimeReport` class to include `TimeReportHelper` module.
  - Removed redundant utility methods from `TimeReport` class.
  - Updated `display` method to use `process_time_entries` from `TimeReportHelper`.
  - Updated `write_csv` method to use `write_csv_rows` from `TimeReportHelper`.
  - Updated `print_time_block_chart` method to pass `colors` parameter to `format_tag_distribution`.
  - Adjusted formatting in `total` method for better alignment.

- **Refactor `Timet::Formatter` to improve readability and modularity:**

  - Introduced a constant `CHAR_MAPPING` to store block characters for different value ranges.
  - Refactored `format_notes` method to use a more descriptive variable name for the maximum length.
  - Updated `format_tag_distribution` method to accept `colors` parameter and pass it to `process_and_print_tags`.
  - Extracted the logic for calculating `value` and `bar_length` into a separate method `calculate_value_and_bar_length`.
  - Refactored `process_and_print_tags` to accept `colors` parameter and use the new `calculate_value_and_bar_length` method.
  - Updated `print_time_block_chart` method to accept `colors` parameter and pass it to `print_blocks`.
  - Refactored `print_blocks` method to accept `colors` and `start_time` parameters and use the new `print_time_blocks` method.
  - Introduced `print_time_blocks` method to handle the printing of time blocks for each hour from the start time to 23.
  - Introduced `get_formatted_block_char` method to retrieve the formatted block character and its associated tag for a given hour.
  - Refactored `print_colored_block` method to use the `block` variable for clarity.
  - Updated `get_block_char` method to use the `CHAR_MAPPING` constant for determining the block character.

- **Refactor `TimeHelper` methods and add new functionality:**
  - Simplified nil checks in `format_time`, `timestamp_to_date`, and `timestamp_to_time` methods by using `unless` instead of `if`.
  - Extracted the logic for calculating block end time and seconds into a new method `calculate_block_end_time_and_seconds`.
  - Updated `count_seconds_per_hour_block` to use the new `calculate_block_end_time_and_seconds` method.
  - Added a new method `append_tag_to_hour_blocks` to append a tag to each value in the `hour_blocks` hash.
  - Removed the `aggregate_hash_values` method as it is no longer needed.
  - Updated YARD documentation for all methods to reflect the changes.

**Bug fixes:**

- [ ] No bug fixes in this PR.

**Tasks:**

- Update `README.md` to reflect the changes.
- Update `Gemfile` and version to reflect the latest changes.

## [1.2.1] - 2024-10-18

**Improvements:**

- Updated the time block chart formatting to use square brackets for better visual representation.
- Refactored the `play_sound_and_notify` method to avoid redundant platform checks and introduced platform-specific session runners.
- Improved readability and maintainability of the `format_tag_distribution` method by extracting logic into a new private method.
- Updated the `rubocop` gem from `~> 1.65` to `~> 1.67`.

### Bug fixes:

- Fixed a `NoMethodError` caused by an undefined method `process_and_print_tags` in the `format_tag_distribution` method.
- Fixed line length violations in several files to comply with `rubocop` rules.

### Additional Considerations:

- The changes in this pull request should be thoroughly tested to ensure that they do not introduce any regressions.
- Future improvements could include further refactoring to extract more logic into separate methods or classes, depending on the complexity and requirements of the application.

## [1.2.0] - 2024-10-11

**Improvements:**

- Enhanced the README to provide more detailed and user-friendly information about the tool.
- Added a visually appealing title and logo to make the README more engaging.
- Organized key features into bullet points for better readability.
- Provided clear and concise installation instructions.
- Made the command reference more user-friendly by adding a table of contents.
- Added more details about data storage and development guidelines.
- Encouraged contributions and provided guidelines for contributing.
- Made the support section more prominent.
- Ensured the license and code of conduct are clearly stated.
- Updated the `timet` gem version to 1.2.0 in `Gemfile.lock`.
- Refactored the `play_sound_and_notify` condition to use the `positive?` method for better readability.
- Enhanced table header formatting with a blinking effect for better user interaction.
- Added new methods for tag distribution and time block chart visualization:
  - `format_tag_distribution`: Displays tag distribution with progress bars.
  - `print_time_block_chart`: Prints the entire time block chart.
  - `print_header`: Prints the header of the time block chart.
  - `print_blocks`: Prints the block characters for each hour.
  - `get_block_char`: Determines the block character based on value.
- Added `count_seconds_per_hour_block` method to count seconds per hour block.
- Added `aggregate_hash_values` method to aggregate hash values.
- Integrated new methods into `time_report` to enhance time tracking visualization.
- Updated the version number in `lib/timet/version.rb` to 1.2.0.

**Additional Considerations:**

- The enhancements made in this pull request aim to improve the user experience and provide more powerful visualization and reporting capabilities for time tracking.
- Reviewers are encouraged to test the new visualization methods and provide feedback on their effectiveness and usability.
- The README updates should make it easier for new users to understand and use the `timet` tool.

## [1.1.0] - 2024-10-09

**Improvements:**

- Added a new `version` command to display the current version of the Timet gem.
- Introduced an alias `tt` for the `timet` command, providing a shorter alternative.
- Updated the README to include the `tt` alias and provide examples for both `timet` and `tt` commands.
- Updated the gem version to `1.1.0`.
- Added the `tt` executable to the gemspec.
- Updated the `rspec-mocks` dependency to version `3.13.2`.

**Tasks:**

- Update `Gemfile.lock` to reflect the new gem version and updated dependencies.
- Add the `tt` executable script to the `bin` directory.
- Update the `version` command in `lib/timet/application.rb` with Yardoc documentation.
- Update the `VERSION` constant in `lib/timet/version.rb` to `1.1.0`.
- Update the `timet.gemspec` to include the `tt` executable.
- Update the README to reflect the new `tt` alias and provide examples for both `timet` and `tt` commands.

## [1.0.0] - 2024-10-07

**Improvements:**

- Added a `pomodoro` option to the `start` command to specify Pomodoro time in minutes.
- Updated the `start` method to accept an optional `pomodoro` parameter and call `play_sound_and_notify` if Pomodoro time is provided.
- Improved the `stop` method to accept an optional `display` parameter and conditionally call `summary`.
- Added `play_sound_and_notify` method to `application_helper.rb` for playing a sound and sending a notification after a specified time.
- Updated RSpec tests to reflect the new `pomodoro` parameter and `display` parameter in the `start` and `stop` methods, respectively.
- Converted Pomodoro time from minutes to seconds before passing it to `play_sound_and_notify`.

### Bug fixes:

- Ensured Pomodoro time is a positive integer before invoking `play_sound_and_notify`.

#### Tasks:

- Update README.md to document the new Pomodoro feature.

### Additional Considerations:

- The `pomodoro` option is designed to be flexible, allowing users to specify any duration in minutes for their Pomodoro sessions. This flexibility caters to users who may prefer different interval lengths based on their work habits and preferences.
- The `play_sound_and_notify` method is a new addition to the `application_helper.rb` file, providing a mechanism for notifying users when their Pomodoro session ends. This feature includes both a sound notification and a system notification to ensure users are aware of the end of their work interval.
- The `stop` method has been improved to accept an optional `display` parameter, which allows users to conditionally call the `summary` method. This enhancement provides more control over when the summary of the time tracking session is displayed.
- The RSpec tests have been updated to reflect the new parameters and functionality introduced in this pull request, ensuring that the code remains robust and reliable.

## [0.9.2] - 2024-10-06

**Improvements:**

- Improved the description of the 'start' command to clarify the usage of optional notes.

**Bug fixes:**

- Modified the 'display_item' method to handle cases where 'updated_item' is nil, ensuring that the original 'item' is displayed instead.

## [0.9.1] - 2024-10-04

**Improvements:**

- Added YARD documentation
- Refactored the `start` method to use `@db.insert_item` directly if the last item status is valid for insertion.
- Removed the `insert_item_if_valid` private method as it is no longer needed.
- Updated the README.md to reflect the latest changes and improvements.
- Added a badge displaying the current gem version in the README.md.

## [0.9.0] - 2024-10-03

**Improvements:**

- Enhanced the gemspec metadata by adding a documentation URI for better discoverability and reference.
- Improved the `summary` and `edit` methods for better readability and functionality.
- Simplified the `summary` method by using safe navigation operators and improved conditional checks.
- Modified the `edit` method to use the return value of `validate_and_update` for displaying the updated item.
- Updated the `validate_and_update` method to return the updated item after performing the update.
- Enhanced the `TimeReport` class and added comprehensive RSpec tests.
- Enhanced the `filter_items` method to support valid date range filters.
- Added a `valid_date_format?` method to validate date formats.
- Updated the `formatted_filter` method to handle valid date range filters.
- Removed the `helpers.rb` file as it was no longer needed.
- Added comprehensive RSpec tests for the `TimeReport` class, covering initialization, filtering, and date format validation.
- Modified the `stop` method in `Timet::Application` to use the `update_item` method from `Database` instead of the deprecated `update` method.
- Updated the `stop` method to fetch the last item's ID and update the 'end' field directly.
- Updated test cases in `application_spec.rb` to reflect the changes in the `stop` method.
- Removed test cases for the deprecated `update` method in `database_spec.rb`.

**Bug fixes:**

- Fix bug in calculate_end_time method

**Additional Considerations:**

- The changes in this PR aim to improve code quality, maintainability, and test coverage.
- The removal of the `helpers.rb` file and unused methods helps to streamline the codebase and reduce technical debt.
- The updated `stop` method now uses the `update_item` method, ensuring consistency across the codebase.
- Comprehensive tests have been added for the `TimeReport` class to ensure robust functionality and prevent regressions.

## [0.8.2] - 2024-10-02

**Improvements:**

- Added optional field and new_value parameters to the edit command.
- Updated the edit method logic to prompt for field and new_value if they are not provided.
- Enhanced test coverage to include scenarios where field and new_value are provided directly and when they are not.
- Updated the README to reflect the new features of the edit command, including both interactive and direct specification modes.

**Additional Considerations:**

- The changes ensure that the edit command is more versatile and user-friendly, catering to both interactive users and those who prefer scripting or automation.

## [0.8.1] - 2024-10-02

**Bug fixes:**

- Fixed a LoadError caused by the byebug gem being required after its removal.

## [0.8.0] - 2024-10-01

**Improvements:**

- Introduced TimeHelper module to encapsulate time-related functionalities.
- Replaced direct calls to Time.now.to_i with TimeHelper.current_timestamp for consistency and modularity.
- Moved current_timestamp method to TimeHelper to centralize time-related logic.
- Ensured all timestamps are handled in UTC to avoid timezone issues.
- Refactored ValidationEditHelper to use TimeHelper for time-related operations.
- Simplified the conditional logic in update_time_field by using a single assignment with the || operator.
- Introduced local variables field_index and timestamp to store intermediate results, reducing redundancy and improving readability.
- Added ApplicationHelper module to handle common application tasks.
- Moved display and prompt logic for editing items into helper methods.
- Removed redundant field_value method and integrated its functionality into the helper methods.
- Consolidated the validation logic for start and end fields into a single conditional statement.
- Removed redundant validate_start_field and validate_end_field methods.
- Added a check to ensure the CSV export only occurs if there are items to export.
- Added a message to inform the user if no items are found for export.
- Refactored the validate_and_update method from Timet::Application to a more modular approach.
- Created new helper methods in ValidationEditHelper for fetching item values and validating start/end times.
- Enhanced readability and maintainability of the code by isolating concerns and reusing logic.
- Renamed item to last_item for clarity in the context where it represents the last task.
- Added a new variable last_item_status to explicitly define the status of the last item.
- Extracted table formatting logic into a new Formatter module.
- Removed redundant methods (format_table_header, format_table_separator, format_table_row, format_notes) from the TimeReport class.
- Introduced current_timestamp method to encapsulate the logic for getting the current timestamp.
- Added insert_item_if_valid method to handle item insertion based on valid statuses.
- Introduced VALID_STATUSES_FOR_INSERTION constant to define valid statuses for item insertion.
- Updated StatusHelper to use :in_progress status instead of :incomplete.
- Ensured consistency in timestamp handling across methods.
- Added support for editing notes.
- Added the csv gem and moved the extract_date method to the TimeHelper module.
- Improved error handling by ensuring the CSV filename is correctly processed and validated.
- Added a confirmation message when the CSV file is successfully exported.

**Bug fixes:**

- Updated timestamp_to_time method to return nil if the input timestamp is nil.
- Removed unnecessary &.then syntax for clarity and consistency.
- Corrected the test expectations to use the correct Unix timestamp.
- Updated format_time and timestamp_to_date methods to return nil if the input timestamp is nil.
- Ensured that the formatted time string does not include an extra space at the end.
- Updated update_time_field to handle nil values for the time field by using a conditional assignment.
- Ensured that the method correctly handles cases where the time field is not set, defaulting to the current timestamp.
- Addressed the NilCheck warning and improved the robustness of the method.
- Added validation to prevent updating start or end times with nil values.

**Tasks:**

- Added ENV['TZ'] = 'UTC' to spec_helper.rb to ensure that all RSpec tests run in the UTC time zone.
- Updated tests to reflect the new structure and ensure items are returned for export.
- Updated and added tests to cover the new export logic.
- Updated the expectations to use the renamed variables, ensuring the code remains clear and maintainable.
- Included the Formatter module in the TimeReport class to utilize its formatted output.
- Updated README.md with alternative syntax for 'timet start' command.
- Update README.md with new command reference and edit functionality
- Refactored start method tests to use context blocks for better readability and organization.
- Added tests to verify the behavior of the start method when the database is empty, the last item is complete, or the last item is still in progress.
- Added tests to ensure the start method handles notes provided via the --notes option correctly.
- Refactored stop method tests to use context blocks and added tests to verify the behavior when the last item is in progress or complete.
- Refactored resume method tests to use context blocks and added tests to verify the behavior when a task is currently being tracked, when there is a last task, and when there are no items.
- Refactored summary method tests to use context blocks and added tests to verify the behavior for different combinations of arguments.
- Updated cancel method test to reflect the correct status for active time tracking.
- Updated database_spec.rb to reflect the correct status for in-progress items.

**Additional Considerations:**

- Ensured that all timestamps are handled in UTC to avoid timezone issues across different environments.
- Updated the test to reflect the correct UTC time zone.
- Ensured consistency in timestamp handling across methods.
- Improved overall structure, readability, and maintainability of the code.
- Made the application easier to maintain and extend in the future.

**Refactor and enhance time formatting methods**

- Refactored `format_time_string` method in `TimeHelper` to improve readability and maintainability.
- Added detailed documentation for the `format_time_string` method.
- Simplified the logic for parsing and validating time components.
- Updated `ValidationEditHelper` to use the refactored `format_time_string` method.
- Added comprehensive RSpec tests for the `format_time_string` method to cover various input scenarios, including edge cases.
- Fixed a bug where `nil` input was not handled correctly.
- Ensured that invalid time values return `nil` instead of an empty string.
- Refactored the CSV export logic in `TimeReport` to improve readability and maintainability.

## [0.2.2] - 2024-09-27

- **Improvements**:
  - Updated SQLite3 gem version to 2.1.0

## [0.2.1] - 2024-09-24

- **Improved `resume` behavior:**
  - If no notes are provided, it will attempt to retrieve them from the last tracked task.
- **Enhanced `export_sheet` functionality:**
  - A new `notes` column has been added to the exported CSV file.
- **Minor bug fixes:**
  - Resolved issues related to resuming tasks with notes and deleting items.

## [0.2.0] - 2024-09-24

- **Improved code quality:**
  - Enforces consistent quoting style with `RuboCop` integration.
  - Removes unused gems (`mini_portile2`) from the `Gemfile`.
- **Database enhancements:**
  - Adds a new column named "notes" to the `items` table to store additional information about tracked time entries.
- **Command-line improvements:**
  - Allows adding notes to a new time entry using the `start` command with the `--notes` option (e.g., `timet start work --notes="meeting with client"`).
  - Improves formatting and clarity of some command descriptions.
- **General code formatting:**
  - Uses single quotes (`'`) for strings and source paths in the `Gemfile`.

## [0.1.0] - 2024-08-01

- Initial release
