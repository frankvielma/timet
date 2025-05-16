# frozen_string_literal: true

# require_relative 'color_codes'
require 'timet/time_report_helper'
require_relative 'utils'
module Timet
  # This class is responsible for formatting the output of the `timet` application.
  # It provides methods for formatting the table header, separators, and rows.
  class Table
    include TimeReportHelper

    attr_reader :filter, :items

    def initialize(filter, items, db)
      @filter = filter
      @items = items
      @db = db
    end

    # Generates and displays a table summarizing time entries, including headers, time blocks, and total durations.
    #
    # @example
    #   table
    #
    # @return [String] The time block string.
    #
    # @note
    #   - The method relies on the `header`, `process_time_entries`, `separator`, and `total` methods.
    #   - The `header` method is responsible for printing the table header.
    #   - The `process_time_entries` method processes the time entries and returns the time block.
    #   - The `separator` method returns a string representing the separator line.
    #   - The `total` method prints the total duration.
    #
    # @see #header
    # @see #process_time_entries
    # @see #separator
    # @see #total
    def table
      header
      time_block = process_time_entries
      puts separator
      total
      time_block
    end

    # Formats the header of the time tracking report table.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing
    # the formatted header.
    #
    # @example Format and print the table header
    #   header
    #
    # @note The method constructs a string representing the table header and prints it.
    def header
      title = "Tracked time report [#{@filter.blink.red}]:"
      header = <<~TABLE
        #{title}
        #{separator}
        \033[32m| Id    | Date       | Tag    | Start    | End      | Duration | Notes\033[0m
        #{separator}
      TABLE
      puts header
    end

    # Formats the separator line for the time tracking report table.
    #
    # @return [String] The formatted separator line.
    #
    # @example Get the formatted table separator
    #   separator # => '+-------+------------+--------+----------+----------+----------+------------+'
    #
    # @note The method returns a string representing the separator line for the table.
    def separator
      '+-------+------------+--------+----------+----------+----------+'
    end

    # Processes time entries and generates a time block structure.
    #
    # This method iterates over each item in the `items` array, displays the time entry (if enabled),
    # and processes the time block item to build a nested hash representing the time block structure.
    #
    # @param display [Boolean] Whether to display the time entry during processing. Defaults to `true`.
    # @return [Hash] A nested hash representing the time block structure, where keys are dates and values
    #                are processed time block items.
    #
    # @note
    #   - The method uses `display_time_entry` to display the time entry if `display` is `true`.
    #   - It processes each time block item using `process_time_block_item`.
    #   - The `TimeHelper.extract_date` method is used to extract the date from the items.
    #
    # @see #display_time_entry
    # @see #process_time_block_item
    # @see TimeHelper#extract_date
    def process_time_entries(display: true)
      time_block = Hash.new { |hash, key| hash[key] = {} }

      @items.each_with_index do |item, idx|
        display_time_entry(item, TimeHelper.extract_date(@items, idx)) if display
        time_block = process_time_block_item(item, time_block)
      end

      time_block
    end

    # Processes a single time block item and updates the time block structure.
    #
    # @param item [Array] An array containing the item details, including start time, end time, and tag.
    # @param time_block [Hash] The current time block structure.
    #
    # @return [Hash] The updated time block structure.
    #
    # @note
    #   - The method extracts the start time, end time, and tag from the item.
    #   - It calculates the number of seconds per hour block using `TimeHelper.count_seconds_per_hour_block`.
    #   - It converts the start time to a date using `TimeHelper.timestamp_to_date`.
    #   - It updates the time block structure by adding the new block hour to the existing structure.
    #
    # @see TimeHelper#count_seconds_per_hour_block
    # @see TimeHelper#timestamp_to_date
    # @see #add_hashes
    def process_time_block_item(item, time_block)
      _, start_time, end_time, tag = item

      block_hour = TimeHelper.count_seconds_per_hour_block(start_time, end_time, tag)
      date_line = TimeHelper.timestamp_to_date(start_time)
      time_block[date_line] = Timet::Utils.add_hashes(time_block[date_line], block_hour)
      time_block
    end

    # Displays a single time entry in the report.
    #
    # @param item [Array] The item to display.
    # @param date [String, nil] The date to display. If nil, the date is not displayed.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing the row.
    #
    # @example Display a time entry
    #   display_time_entry(item, '2021-10-01')
    #
    # @note The method formats and prints the row for the time entry.
    def display_time_entry(item, date = nil)
      return puts 'Missing time entry data.' unless item

      id, start_time_value, end_time_value, tag_name, notes = item
      duration = TimeHelper.calculate_duration(start_time_value, end_time_value)
      start_time = TimeHelper.format_time(start_time_value)
      end_time = TimeHelper.format_time(end_time_value)
      start_date = date || (' ' * 10)
      puts format_table_row(id, tag_name[0..5], start_date, start_time, end_time, duration, notes)
    end

    # Formats a table row with the given row data.
    #
    # @param row [Array] The row data to format, containing the following elements:
    #   - id [Integer] The ID of the time entry.
    #   - tag [String] The tag associated with the time entry.
    #   - start_date [String] The start date of the time entry.
    #   - start_time [String] The start time of the time entry.
    #   - end_time [String] The end time of the time entry.
    #   - duration [Integer] The duration of the time entry in seconds.
    #   - notes [String] Any notes associated with the time entry.
    #
    # @return [String] The formatted table row.
    #
    # @example
    #   row = [1, 'work', '2024-10-21', '08:00:00', '09:00:00', 3600, 'Completed task A']
    #   format_table_row(*row)
    #   #=> "|      1| 2024-10-21 | work   | 08:00:00 | 09:00:00 |   1:00:00 | Completed task A  |"
    #
    # @note
    #   - The method relies on the `@db` instance variable, which should be an object with `find_item`
    #   and `seconds_to_hms` methods.
    #   - The `format_end_time`, `format_mark`, and `format_notes` methods are used to format specific parts of the row.
    #
    # @see #format_end_time
    # @see #format_mark
    # @see #format_notes
    def format_table_row(*row)
      id, tag, start_date, start_time, end_time, duration, notes = row
      end_time = format_end_time(end_time, id, duration)
      mark = format_mark(id)

      "| #{id.to_s.rjust(6)}| #{start_date} | #{tag.ljust(6)} | #{start_time.split[1]} | " \
        "#{end_time.rjust(8)} | #{@db.seconds_to_hms(duration).rjust(8)} #{mark} #{format_notes(notes)}"
    end

    # Formats the end time of the time entry.
    #
    # @param end_time [String] The end time of the time entry.
    # @param id [Integer] The ID of the time entry.
    # @param duration [Integer] The duration of the time entry in seconds.
    #
    # @return [String] The formatted end time.
    #
    # @example
    #   format_end_time('09:00:00', 1, 3600)
    #   #=> "09:00:00"
    #
    # @note
    #   - The method relies on the `@db` instance variable, which should be an object with a `find_item` method.
    #   - If the `pomodoro` value is positive and the end time is not set, a blinking `timet` is added.
    #
    # @see #format_table_row
    def format_end_time(end_time, id, duration)
      end_time = end_time ? end_time.split[1] : '-'
      pomodoro = @db.find_item(id)[5] || 0

      if pomodoro.positive? && end_time == '-'
        delta = @db.seconds_to_hms((@db.find_item(id)[5] * 60) - duration)
        timet = "\e]8;;Session ends\a#{delta}\e]8;;\a".green
        end_time = timet.to_s.blink
      end

      end_time
    end

    # Formats the mark for the time entry.
    #
    # @param id [Integer] The ID of the time entry.
    #
    # @return [String] The formatted mark.
    #
    # @example
    #   format_mark(1)
    #   #=> "|"
    #
    # @note
    #   - The method relies on the `@db` instance variable, which should be an object with a `find_item` method.
    #   - If the `pomodoro` value is positive, a special mark is added.
    #
    # @see #format_table_row
    def format_mark(id)
      pomodoro = @db.find_item(id)[5] || 0
      mark = '|'
      mark = "#{'├'.white}#{'P'.blue.blink}" if pomodoro.positive?
      mark
    end

    # Formats the notes column of the time tracking report table.
    #
    # @param notes [String, nil] The notes to be formatted.
    # @return [String] The formatted notes.
    #
    # @example Format notes
    #   format_notes('This is a long note that needs to be truncated')
    #
    # @note The method truncates the notes to a maximum of 20 characters and pads them to a fixed width.
    def format_notes(notes)
      spaces = 80
      return ' ' * spaces unless notes

      max_length = spaces - 3
      notes = "#{notes.slice(0, max_length)}..." if notes.length > max_length
      notes.ljust(spaces)
    end

    # Displays the total duration of the tracked time entries.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing the total duration.
    #
    # @example Display the total duration
    #   total
    #
    # @note The method calculates and prints the total duration of the tracked time entries.
    def total
      total = @items.map do |item|
        TimeHelper.calculate_duration(item[1], item[2])
      end.sum
      puts "|#{' ' * 43}#{'Total:'.blue}  | #{@db.seconds_to_hms(total).rjust(8).blue} |"
      puts separator
      display_pomodoro_label
    end

    # Displays a blinking "Pomodoro" label if the sum of the compacted values in the 6th column of @items is positive.
    #
    # @example
    #   display_pomodoro_label
    #
    # @return [void] This method returns nothing.
    #
    # @note
    #   - The method relies on the `@items` instance variable, which should be an array of arrays.
    #   - The 6th column of each sub-array in `@items` is expected to contain numeric values.
    #   - The method uses the `blue.blink` color formatting, which assumes the presence of a `String` extension or
    #   gem that supports color formatting.
    #
    # @see #@items
    # @see String#blue
    # @see String#blink
    def display_pomodoro_label
      return unless @items.map { |x| x[5] }.compact.sum.positive?

      puts "#{'P'.blue.blink}omodoro"
    end
  end
end
