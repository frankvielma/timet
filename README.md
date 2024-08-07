# Timet

Timet is a time tracking gem with time reports. Using timet, you can keep track of how much time you spend on various activities. It's simple to track your hours for work with timet, whether you're curious about how you allocate your time.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add timet

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install timet

## Usage

- **timet start [tag]**: Starts tracking time for a task labeled with the provided [tag].

- **timet stop**: Stops tracking the current task, records the elapsed time, and displays the total time spent on all tasks.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/frankvielma/timet. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/frankvielma/timet/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Timet project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/frankvielma/timet/blob/master/CODE_OF_CONDUCT.md).
