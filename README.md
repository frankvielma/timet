[![Gem Version](https://badge.fury.io/rb/timet.svg)](https://badge.fury.io/rb/timet)
![timet workflow](https://github.com/frankvielma/timet/actions/workflows/ci.yml/badge.svg)
[![Maintainability](https://api.codeclimate.com/v1/badges/44d57b6c561b9be717f5/maintainability)](https://codeclimate.com/github/frankvielma/timet/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/44d57b6c561b9be717f5/test_coverage)](https://codeclimate.com/github/frankvielma/timet/test_coverage)

# Timet

Timet is a command line time tracking with reports. It's simple to track your hours for work with Timet, whether you're curious about how you allocate your time.

Timet utilizes SQLite to store your time tracking data. This means your data is stored locally and securely, with no need for external databases or cloud storage. This makes Timet lightweight, fast, and perfect for users who value privacy and control over their data.

While a YAML file might seem like a simple option for storing time tracking data, Timet leverages SQLite for several key advantages:

- Structured Data
- Scalability
- Data Integrity
- Querying and Reporting

In addition, if possible, export your time tracking data to CSV for analysis and sharing.

## Requirements

* Ruby version: >= 3.0.0
* sqlite3: > 1.7


Old versions of Ruby and Sqlite:

* [Ruby >= 2.7](https://github.com/frankvielma/timet/tree/ruby-2.7.0)

* [Ruby >= 2.4](https://github.com/frankvielma/timet/tree/ruby-2.4.0)



## Installation

Install the gem by executing:
```bash
gem install timet
```

## Usage

- **timet start [tag] --notes='...'**: Starts tracking time for a task labeled with the provided [tag] and notes (optional). Example:
    ```bash
    timet start task1 --notes='Meeting with client'
    
    or

    timet start task1 'Meeting with client'
    ```

    ```
    Tracked time report [today]:
    +-------+------------+--------+----------+----------+----------+--------------------------+
    | Id    | Date       | Tag    | Start    | End      | Duration | Notes                    |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |     1 | 2024-08-09 | task1  | 14:55:07 |        - | 00:00:00 | Meeting with client      |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |                                           Total:  | 00:00:00 |                          |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    ```

- **timet stop**: Stops tracking the current task, records the elapsed time, and displays the total time spent on all tasks.

    ```bash
    timet stop
    ```

    ```
    Tracked time report [today]:
    +-------+------------+--------+----------+----------+----------+--------------------------+
    | Id    | Date       | Tag    | Start    | End      | Duration | Notes                    |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |     1 | 2024-08-09 | task1  | 14:55:07 | 15:55:07 | 01:00:00 | Meeting with client      |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |                                           Total:  | 01:00:00 |                          |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    ```

- **timet resume**: It allows users to quickly resume tracking a task that was previously in progress.
    ```
    Tracked time report [today]:
    +-------+------------+--------+----------+----------+----------+--------------------------+
    | Id    | Date       | Tag    | Start    | End      | Duration | Notes                    |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |     2 | 2024-08-09 | task1  | 16:15:07 |        - | 00:00:00 | Meeting with client      |
    |     1 |            | task1  | 14:55:07 | 15:55:07 | 01:00:00 | Meeting with client      |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |                                           Total:  | 01:00:00 |                          |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    ```


- **timet edit**: It allows users to update a task's notes, tag, start, or end fields. Users can either interactively select the field and provide a new value or specify them directly in the command.

- **Interactive Mode:**
    ```bash
    timet e 1
    ```

    ```
    Tracked time report [today]:
    +-------+------------+--------+----------+----------+----------+--------------------------+
    | Id    | Date       | Tag    | Start    | End      | Duration | Notes                    |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |     2 | 2024-08-09 | task1  | 16:15:07 |        - | 00:00:00 | Meeting with client      |
    |     1 |            | task1  | 14:55:07 | 15:55:07 | 01:00:00 | Meeting with client      |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |                                           Total:  | 01:00:00 |                          |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    Edit Field? (Press ↑/↓ arrow to move and Enter to select)
    ‣ Notes
      Tag
      Start
      End
    ```


- **Direct Specification Mode:**
    ```bash
    timet e 1 notes "New Meeting Notes"
    ```

    ```
    Tracked time report [today]:
    +-------+------------+--------+----------+----------+----------+--------------------------+
    | Id    | Date       | Tag    | Start    | End      | Duration | Notes                    |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |     2 | 2024-08-09 | task1  | 16:15:07 |        - | 00:00:00 | Meeting with client      |
    |     1 |            | task1  | 14:55:07 | 15:55:07 | 01:00:00 | New Meeting Note         |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    |                                           Total:  | 01:00:00 |                          |
    +-------+------------+--------+----------+----------+----------+--------------------------+
    ```



## Command Reference

| Command                                      | Description                                                                 | Example Usage                                      |
|----------------------------------------------|-----------------------------------------------------------------------------|---------------------------------------------------|
| `timet start [tag] --notes='...'`            | Start tracking time for a task labeled [tag] and notes (optional).          | `timet start Task "My notes"`                  |
| `timet stop`                                 | Stop tracking time.                                                         | `timet start Task "My notes"`                  |
| `timet summary today (t)`                    | Display a report of tracked time for today.                                 | `timet su t` or `timet su`         |
| `timet summary yesterday (y)`                | Display a report of tracked time for yesterday.                             | `timet su y`                         |
| `timet summary week (w)`                     | Display a report of tracked time for the week.                              | `timet su w`                              |
| `timet summary month (m)`                    | Resume tracking the last month.                                             | `timet su m`                             |
| `timet su t --csv=[filename]`                | Display a report of tracked time for today and export it to `filename.csv`. | `timet su t --csv=file.csv`              |
| `timet summary resume (r)`                   | Resume tracking the last task.                                              | `timet su r`                            |
| `timet delete [id]`                          | Delete a task by its ID.                                                    | `timet d [id]`       |
| `timet cancel`                               | Cancel active time tracking.                                                | `timet c`                 |
| `timet edit [id]`                            | Update a task's notes, tag, start or end fields.                            | `timet e [1]`                 |
| `timet su [date]`                            | Display a report of tracked time for a specific date.                       | `timet su 2024-01-03`                        |
| `timet su [start_date]..[end_date]`          | Display a report of tracked time for a date range.                          | `timet su 2024-01-02..2024-01-03`            |



### Date Range in Summary

The `timet summary` command now supports specifying a date range for generating reports. This allows users to filter and summarize data within specific date intervals. The date format is in ISO 8601 format (YYYY-MM-DD).

#### Examples:
- **Single Date**: Display a report for a specific date.
  ```sh
  timet su 2024-01-03
  ```

- **Date Range**: Display a report for a date range.
  ```sh
  timet su 2024-01-02..2024-01-03
  ```


## Data
Timet's data is stored in ~/.timet.db


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/frankvielma/timet. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/frankvielma/timet/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Timet project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/frankvielma/timet/blob/master/CODE_OF_CONDUCT.md).
