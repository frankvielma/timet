# Timet

Timet is a command line time tracking gem with time reports. Using it, you can keep track of how much time you spend on various activities. It's simple to track your hours for work with timet, whether you're curious about how you allocate your time.

Timet utilizes SQLite to store your time tracking data. This means your data is stored locally and securely, with no need for external databases or cloud storage. This makes Timet lightweight, fast, and perfect for users who value privacy and control over their data.


While a YAML file might seem like a simple option for storing time tracking data, Timet leverages SQLite for several key advantages:

- Structured Data
- Scalability
- Data Integrity
- Querying and Reporting

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add timet

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install timet

## Usage

- **timet start [tag]**: Starts tracking time for a task labeled with the provided [tag]. Example:
    ```shell
    timet start task1
    ```

    ```
    Tracked time report:
    +-------+--------+---------------------+-------------------+------------+
    | Id    | Task   | Start Time          | End Time          | Duration   |
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
    | Id    | Task   | Start Time          | End Time            | Duration   |
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
    | Id    | Task   | Start Time          | End Time            | Duration   |
    +-------+--------+---------------------+--------------------+-------------+
    |     2 | task1  | 2024-08-09 16:45:12 |                   - |   00:00:00 |
    |     1 | task1  | 2024-08-09 14:55:07 | 2024-08-09 14:56:20 |   00:01:13 |
    +-------+--------+---------------------+---------------------+------------+
    |                                                  Total:    |   00:01:13 |
    +-------+--------+---------------------+---------------------+------------+
    ```

- **timet report today (t)**: Display a report of tracked time for today.

```shell
timet report today

or

timet report t
```

- **timet report yesterday (y)**: Display a report of tracked time for yesterday.

```shell
timet report yesterday

or

timet report y
```

- **timet report week (w)**: Display a report of tracked time for the week.

```shell
timet report week

or

timet report w
```

- **timet report resume (r)**: Resume tracking the last task.

```shell
timet report resume

or

timet report r
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
