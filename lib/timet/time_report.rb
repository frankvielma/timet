# frozen_string_literal: true

require 'date'
require 'csv'
require_relative 'status_helper'
require_relative 'formatter'

module Timet
  # The TimeReport class is responsible for displaying a report of tracked time
  # entries. It allows filtering the report by time periods and displays
  # a formatted table with the relevant information.
  class TimeReport
    include Formatter

    # Provides access to the database instance.
    attr_reader :db

    # Provides access to the filtered items.
    attr_reader :items

    # Provides access to the CSV filename.
    attr_reader :filename

    # Initializes a new instance of the TimeReport class.
    #
    # @param db [Database] The database instance to use for fetching data.
    # @param filter [String, nil] The filter to apply when fetching items. Possible values include 'today', 'yesterday', 'week', 'month', or a date range in the format 'YYYY-MM-DD..YYYY-MM-DD'.
    # @param tag [String, nil] The tag to filter the items by.
    # @param csv [String, nil] The filename to use when exporting the report to CSV.
    #
    # @return [void] This method does not return a value; it performs side effects such as initializing the instance variables.
    #
    # @example Initialize a new TimeReport instance with a filter and tag
    #   TimeReport.new(db, 'today', 'work', 'report.csv')
    def initialize(db, filter = nil, tag = nil, csv = nil)
      @db = db
      @filename = csv
      @filter = formatted_filter(filter)
      @items = filter ? filter_items(@filter, tag) : @db.all_items
    end

    # Displays the report of tracked time entries.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing the report.
    #
    # @example Display the report
    #   time_report.display
    #
    # @note The method formats and prints the table header, rows, and total duration.
    def display
      return puts 'No tracked time found for the specified filter.' if items.empty?

      format_table_header
      items.each_with_index do |item, idx|
        date = TimeHelper.extract_date(items, idx)
        display_time_entry(item, date)
      end
      puts format_table_separator
      total
    end

    # Displays a single row of the report.
    #
    # @param item [Array] The item to display.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing the row.
    #
    # @example Display a single row
    #   time_report.show_row(item)
    #
    # @note The method formats and prints the table header, row, and total duration.
    def show_row(item)
      format_table_header
      display_time_entry(item)
      puts format_table_separator
      total
    end

    # Exports the report to a CSV file.
    #
    # @return [void] This method does not return a value; it performs side effects such as writing the CSV file.
    #
    # @example Export the report to a CSV file
    #   time_report.export_sheet
    #
    # @note The method writes the items to a CSV file and prints a confirmation message.
    def export_sheet
      file_name = "#{filename}.csv"
      write_csv(file_name)

      puts "The #{file_name} has been exported."
    end

    private

    # Writes the items to a CSV file.
    #
    # @param file_name [String] The name of the CSV file to write.
    #
    # @return [void] This method does not return a value; it performs side effects such as writing the CSV file.
    #
    # @example Write items to a CSV file
    #   write_csv('report.csv')
    #
    # @note The method writes the items to the specified CSV file.
    def write_csv(file_name)
      CSV.open(file_name, 'w') do |csv|
        csv << %w[ID Start End Tag Notes]
        items.each do |item|
          csv << format_item(item)
        end
      end
    end

    # Formats an item for CSV export.
    #
    # @param item [Array] The item to format.
    #
    # @return [Array] The formatted item.
    #
    # @example Format an item for CSV export
    #   format_item(item)
    #
    # @note The method formats the item's ID, start time, end time, tag, and notes.
    def format_item(item)
      id, start_time, end_time, tags, notes = item
      [
        id,
        TimeHelper.format_time(start_time),
        TimeHelper.format_time(end_time),
        tags,
        notes
      ]
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
      end_time = TimeHelper.format_time(end_time_value) || '- -'
      start_date = date || (' ' * 10)
      puts format_table_row(id, tag_name[0..5], start_date, start_time, end_time, duration, notes)
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
      puts "|#{' ' * 43}\033[94mTotal:  | #{@db.seconds_to_hms(total).rjust(8)} |\033[0m                          |"
      puts format_table_separator
    end

    # Filters the items based on the specified filter and tag.
    #
    # @param filter [String] The filter to apply.
    # @param tag [String, nil] The tag to filter the items by.
    #
    # @return [Array] The filtered items.
    #
    # @example Filter items by date range and tag
    #   filter_items('2021-10-01..2021-10-31', 'work')
    #
    # @note The method filters the items based on the specified date range and tag.
    def filter_items(filter, tag)
      if date_ranges.key?(filter)
        start_date, end_date = date_ranges[filter]
        filter_by_date_range(start_date, end_date, tag)
      elsif valid_date_format?(filter)
        start_date, end_date = filter.split('..').map { |x| Date.parse(x) }
        filter_by_date_range(start_date, end_date, tag)
      else
        puts 'Invalid filter. Supported filters: today, yesterday, week, month'
        []
      end
    end

    # Provides predefined date ranges for filtering.
    #
    # @return [Hash] A hash containing predefined date ranges.
    #
    # @example Get the predefined date ranges
    #   date_ranges
    #
    # @note The method returns a hash with predefined date ranges for 'today', 'yesterday', 'week', and 'month'.
    def date_ranges
      today = Date.today
      {
        'today' => [today, nil],
        'yesterday' => [today - 1, nil],
        'week' => [today - 7, today + 1],
        'month' => [today - 30, today + 1]
      }
    end

    # Filters the items by date range and tag.
    #
    # @param start_date [Date] The start date of the range.
    # @param end_date [Date, nil] The end date of the range. If nil, the end date is the start date + 1 day.
    # @param tag [String, nil] The tag to filter the items by.
    #
    # @return [Array] The filtered items.
    #
    # @example Filter items by date range and tag
    #   filter_by_date_range(Date.new(2021, 10, 1), Date.new(2021, 10, 31), 'work')
    #
    # @note The method filters the items based on the specified date range and tag.
    def filter_by_date_range(start_date, end_date = nil, tag = nil)
      start_time = TimeHelper.date_to_timestamp(start_date)
      end_time = TimeHelper.calculate_end_time(start_date, end_date)
      query = "start >= #{start_time} and start < #{end_time} and tag like '%#{tag}%'"
      @db.execute_sql(
        "select * from items where #{query} ORDER BY id DESC"
      )
    end

    # Formats the filter string.
    #
    # @param filter [String, nil] The filter string to format.
    #
    # @return [String] The formatted filter string.
    #
    # @example Format the filter string
    #   formatted_filter('t') # => 'today'
    #
    # @note The method maps shorthand filters to their full names and validates date formats.
    def formatted_filter(filter)
      filter_map = {
        'today' => %w[today t],
        'yesterday' => %w[yesterday y],
        'week' => %w[week w],
        'month' => %w[month m]
      }

      filter_map.each do |key, values|
        return key if values.include?(filter)
      end

      return filter if filter && valid_date_format?(filter)

      'today'
    end

    # Validates the date format.
    #
    # @param date_string [String] The date string to validate.
    #
    # @return [Boolean] True if the date format is valid, otherwise false.
    #
    # @example Validate the date format
    #   valid_date_format?('2021-10-01') # => true
    #
    # @note The method validates the date format for single dates and date ranges.
    def valid_date_format?(date_string)
      date_format_single = /^\d{4}-\d{2}-\d{2}$/
      date_format_range = /^\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}$/

      date_string.match?(date_format_single) || date_string.match?(date_format_range)
    end
  end
end
