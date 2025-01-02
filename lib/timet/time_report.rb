# frozen_string_literal: true

require 'date'
require 'csv'
require 'icalendar'
require_relative 'time_report_helper'
require_relative 'table'
require_relative 'time_block_chart'
require_relative 'tag_distribution'

module Timet
  # The TimeReport class is responsible for displaying a report of tracked time
  # entries. It allows filtering the report by time periods and displays
  # a formatted table with the relevant information.
  class TimeReport
    include TimeReportHelper
    include Table
    include TagDistribution

    # Provides access to the database instance.
    attr_reader :db

    # Provides access to the filtered items.
    attr_reader :items

    # Provides access to the CSV filename.
    attr_reader :csv_filename

    # Provides access to the ICS filename.
    attr_reader :ics_filename

    # Initializes a new instance of the TimeReport class.
    #
    # @param db [Database] The database instance to use for fetching data.
    # @param options [Hash] A hash containing optional parameters.
    # @option options [String, nil] :filter The filter to apply when fetching items. Possible values include 'today',
    #   'yesterday', 'week', 'month', or a date range in the format 'YYYY-MM-DD..YYYY-MM-DD'.
    # @option options [String, nil] :tag The tag to filter the items by.
    # @option options [String, nil] :csv The filename to use when exporting the report to CSV.
    # @option options [String, nil] :ics The filename to use when exporting the report to iCalendar.
    #
    # @return [void] This method does not return a value; it performs side effects such as initializing the
    # instance variables.
    #
    # @example Initialize a new TimeReport instance with a filter and tag
    #   TimeReport.new(db, filter: 'today', tag: 'work', csv: 'report.csv', ics: 'icalendar.ics')
    def initialize(db, options = {})
      @db = db
      @csv_filename = options[:csv]
      @ics_filename = options[:ics]
      @filter = formatted_filter(options[:filter])
      @items = options[:filter] ? filter_items(@filter, options[:tag]) : @db.all_items
    end

    # Displays the report of tracked time entries.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing the report.
    #
    # @example Display the report
    #   time_report.display
    #
    # @note The method formats and prints the table header, rows, and total duration.
    #
    # @param items [Array<Hash>] The list of time entries to be displayed.
    # @param options [Hash] Additional options for customizing the display (e.g., color scheme).
    #
    # @see #table
    # @see #print_time_block_chart
    # @see #tag_distribution
    def display
      return puts 'No tracked time found for the specified filter.' if @items.empty?

      time_block = table

      colors = @items.map { |x| x[3] }.uniq.each_with_index.to_h
      chart = TimeBlockChart.new(time_block)
      chart.print_time_block_chart(time_block, colors)

      tag_distribution(colors)
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
      header
      display_time_entry(item)
      puts separator
      total
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
        write_csv_rows(csv)
      end
    end

    # Writes the CSV rows for the time report.
    #
    # @param csv [CSV] The CSV object to which the rows will be written.
    # @return [void]
    #
    # @example
    #   csv = CSV.new(file)
    #   write_csv_rows(csv)
    def write_csv_rows(csv)
      items.each do |item|
        csv << format_item(item)
      end
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
      query = [
        "start >= #{start_time}",
        "start < #{end_time}",
        "tag like '%#{tag}%'",
        '(deleted IS NULL OR deleted = 0)'
      ].join(' and ')
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
  end
end
