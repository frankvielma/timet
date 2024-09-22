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

Install the gem and add to the application's Gemfile by executing:

    $ bundle add timet

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install timet

## Usage

Using timet or tt as an alias is possible

- **timet start [tag]**: Starts tracking time for a task labeled with the provided [tag]. Example:
    ```shell
    timet start task1

    or 

    tt start task1
    ```

    ```
    Tracked time report:
    +-------+--------+---------------------+-------------------+------------+
    | Id    | Tag    | Start Time          | End Time          | Duration   |
    +-------+--------+---------------------+-------------------+------------+
    |     1 | task1  | 2024-08-09 14:55:07 |                 - |   00:00:00 |
    +-------+--------+---------------------+-------------------+------------+
    |                                                  Total:  |   00:00:00 |
    +-------+--------+---------------------+-------------------+------------+
    ```

- **timet stop**: Stops tracking the current task, records the elapsed time, and displays the total time spent on all tasks.

    ```shell
    timet stop
    ```

    ```
    Tracked time report:
    +-------+--------+---------------------+---------------------+------------+
    | Id    | Tag    | Start Time          | End Time            | Duration   |
    +-------+--------+---------------------+--------------------+-------------+
    |     1 | task1  | 2024-08-09 14:55:07 | 2024-08-09 14:56:20 |   00:01:13 |
    +-------+--------+---------------------+---------------------+------------+
    |                                                  Total:    |   00:01:13 |
    +-------+--------+---------------------+---------------------+------------+
    ```

- **timet resume**: It allows users to quickly resume tracking a task that was previously in progress.
    ```
    Tracked time report:
    +-------+--------+---------------------+---------------------+------------+
    | Id    | Tag    | Start Time          | End Time            | Duration   |
    +-------+--------+---------------------+--------------------+-------------+
    |     2 | task1  | 2024-08-09 16:45:12 |                   - |   00:00:00 |
    |     1 | task1  | 2024-08-09 14:55:07 | 2024-08-09 14:56:20 |   00:01:13 |
    +-------+--------+---------------------+---------------------+------------+
    |                                                  Total:    |   00:01:13 |
    +-------+--------+---------------------+---------------------+------------+
    ```

- **timet summary today (t)**: Display a report of tracked time for today.

```shell
timet summary today

or

tt su t
```

- **timet summary yesterday (y)**: Display a report of tracked time for yesterday.

```shell
timet summary yesterday

or

tt su y
```

- **timet summary week (w)**: Display a report of tracked time for the week.

```shell
timet summary week

or

tt su w
```

- **timet summary resume (r)**: Resume tracking the last task.

```shell
timet summary resume

or

tt su r
```

- **timet summary resume (r)**: Resume tracking the last month.

```shell
timet summary month

or

tt su m
```

- **timet su t --csv=[filename]**:  Display a report of tracked time for today and export it to filename.csv

```shell
tt su t --csv=summary_today.csv
```

- **timet delete [id]**: Delete a task

```shell
timet delete [id]

or

tt d [id]
```

- **timet cancel**: Cancel active time tracking

```shell
timet cancel

or

tt c
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/frankvielma/timet. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/frankvielma/timet/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Timet project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/frankvielma/timet/blob/master/CODE_OF_CONDUCT.md).
