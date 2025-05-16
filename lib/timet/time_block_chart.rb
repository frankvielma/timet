# frozen_string_literal: true

require_relative 'week_info'
require_relative 'block_char_helper'

module Timet
  #
  # The TimeBlockChart class is responsible for generating and printing a visual representation
  # of time blocks for a given set of data. It uses character mapping to represent different
  # time ranges and provides methods to print the chart with headers, footers, and colored blocks.
  #
  # Example usage:
  #   time_block = {
  #     "2023-10-01" => { "08" => [3600, "work"], "09" => [1800, "break"] },
  #     "2023-10-02" => { "10" => [4500, "work"] }
  #   }
  #   colors = { "work" => 31, "break" => 32 }
  #   chart = TimeBlockChart.new(table)
  #   chart.print_time_block_chart(table, colors)
  #
  # @attr_reader [Integer] start_hour The starting hour of the time block
  # @attr_reader [Integer] end_hour The ending hour of the time block
  class TimeBlockChart
    # Separator character for the chart
    SEPARATOR_CHAR = '░'

    # Width of the date/week string content (e.g., "02 2023-10-01 Fri")
    DATE_WEEK_CONTENT_WIDTH = 17

    # Width of the '┆- ' part after the date/week string
    DATE_WEEK_BORDER_WIDTH = 3

    # Width of the total hours column including the border
    TOTAL_HOURS_COLUMN_WIDTH = 4

    # Initializes a new TimeBlockChart instance.
    #
    # This method sets up the time block chart by processing the time entries from the provided table
    # and determining the start and end hours for the chart based on the time block data.
    #
    # @param table [Table] The table instance containing the time entries to be processed.
    # @return [void] This method does not return a value; it initializes the instance variables.
    #
    # @note
    #   - The `@time_block` instance variable is populated by processing the time entries from the table.
    #   - The `@start_hour` and `@end_hour` instance variables are calculated based on the earliest and latest
    #     hours present in the time block data.
    #
    # @see Table#process_time_entries
    def initialize(table)
      @time_block = table.process_time_entries(display: false)
      hours = @time_block.values.map(&:keys).flatten.uniq
      if hours.empty?
        @start_hour = @end_hour = 0
        return
      end
      @start_hour = hours.min.to_i
      @end_hour   = hours.max.to_i
    end

    # Prints the time block chart.
    #
    # This method formats and prints the time block chart, including the header and the time blocks
    # for each entry. The chart is color-coded based on the provided color mapping for different tags.
    #
    # @param colors [Hash] A mapping of tags to colors, used to color-code the time blocks.
    # @return [void] This method does not return a value; it performs side effects such as printing the chart.
    #
    # @example Print a time block chart
    #   # Assuming 'table' is an instance of Timet::Table
    #   chart = TimeBlockChart.new(table)
    #   colors = { "work" => 0, "break" => 1 } # Example color mapping
    #   chart.print_time_block_chart(colors)
    #
    # @note
    #   - The method first prints the header of the chart, which includes the time range.
    #   - It then prints the time blocks, using the provided color mapping to visually distinguish
    #     between different tags.
    #
    # @see #print_header
    # @see #print_blocks
    def print_time_block_chart(colors)
      print_header
      print_blocks(colors)
    end

    private

    # Prints the header of the chart
    #
    # @return [void]
    def print_header
      puts
      print_hours_row
      puts '┌╴W ╴╴╴╴╴╴⏰╴╴╴╴╴╴┼'.gray + "#{'╴' * (@end_hour - @start_hour + 1) * 4}╴╴╴┼".gray
    end

    # Prints the hours row in the header.
    #
    # @return [void]
    def print_hours_row
      print ' ' * 19
      (@start_hour..@end_hour + 1).each { |hour| print format('%02d', hour).rjust(4) }
      puts
    end

    # Prints the main body of the time block chart, including date rows and corresponding time blocks.
    #
    # This method iterates over each date present in the `@time_block` instance variable,
    # which is expected to be a hash mapping date strings to hourly time block data.
    # For each date, it:
    #   1. Displays week and date information using `WeekInfo`.
    #   2. Prints the visual time blocks for the hours of the day using `#print_time_blocks`.
    #   3. Calculates and prints the total hours logged for that day using `#calculate_and_print_hours`.
    # After processing all dates, it prints a chart footer using `#print_footer`.
    #
    # @param colors [Hash] A mapping of tags to color indices. This is used by `#print_time_blocks`
    #   to color-code the visual time blocks. Example: `{ "work" => 0, "break" => 1 }`
    # @return [void] This method does not return a value; it prints directly to the console.
    #
    # @note
    #   - This is a private method, primarily called by `#print_time_block_chart`.
    #   - It returns early if `@time_block` is `nil`. If `@time_block` is an empty hash,
    #     no date-specific rows are printed, but the chart footer is still rendered.
    #   - Relies on `@start_hour` and `@end_hour` instance variables being correctly set
    #     during the `TimeBlockChart`'s initialization.
    #
    # @see WeekInfo#format_and_print_date_info
    # @see #print_time_blocks
    # @see #calculate_and_print_hours
    # @see #print_footer
    def print_blocks(colors)
      return unless @time_block

      weeks = []
      @time_block.keys.sort.each do |date_string|  # ISO-date strings sort naturally
        date = Date.parse(date_string)
        day = date.strftime('%a')[0..2]

        week_info = WeekInfo.new(date_string, weeks) # Removed start_hour, end_hour
        print_inter_week_separator if week_info.needs_inter_week_separator?
        week_info.format_and_print_date_info(day)

        time_block_initial = @time_block[date_string]
        print_time_blocks(time_block_initial, colors)

        calculate_and_print_hours(time_block_initial)
      end
      print_footer
    end

    # Calculates and prints the total hours for a day
    #
    # @param [Hash] time_block_initial The initial time block data for a day
    # @return [void]
    def calculate_and_print_hours(time_block_initial)
      total_seconds = time_block_initial.values.map { |item| item[0] }.sum
      hours_per_day = (total_seconds / 3600.0).round(1)
      print "-┆#{hours_per_day}h".gray
      puts
    end

    # Prints the footer of the chart
    #
    # @return [void]
    def print_footer
      timet = "\e]8;;https://github.com/frankvielma/timet/\aTimet\e]8;;\a".green
      puts '└╴╴╴╴╴╴╴'.gray + timet + "╴╴╴╴╴┴#{'╴' * (@end_hour - @start_hour + 1) * 4}╴╴╴┴".gray
      puts
    end

    # Prints the time blocks for a given day
    #
    # @param [Hash] time_block_initial The initial time block data for a day
    # @param [Hash] colors The color mapping for different tags
    # @return [void]
    def print_time_blocks(time_block_initial, colors)
      (@start_hour..@end_hour).each do |hour|
        tag, block_char = get_formatted_block_char(hour, time_block_initial)
        print_colored_block(block_char, tag, colors)
      end
    end

    # Gets the formatted block character for a given hour
    #
    # @param [Integer] hour The hour
    # @param [Hash] time_block_initial The initial time block data for a day
    # @return [Array] The tag and block character
    def get_formatted_block_char(hour, time_block_initial)
      formatted_hour = format('%02d', hour)
      hour_data = time_block_initial[formatted_hour]
      tag = hour_data&.last
      [tag, BlockCharHelper.get_block_char(hour_data&.first)]
    end

    # Prints the colored block character
    #
    # @param [String] block_char The block character
    # @param [String] tag The tag
    # @param [Hash] colors The color mapping for different tags
    # @return [void]
    def print_colored_block(block_char, tag, colors)
      color_code = colors[tag]
      block = block_char * 2
      colored_block = color_code ? "#{block.color(color_code + 1)}  " : block
      print colored_block.rjust(4)
    end

    # Prints the separator line between different weeks in the chart.
    #
    # @return [void]
    def print_inter_week_separator
      sep = SEPARATOR_CHAR
      puts "┆#{sep * DATE_WEEK_CONTENT_WIDTH}┼#{sep * (@end_hour - @start_hour + 1) * 4}#{sep * DATE_WEEK_BORDER_WIDTH}┼#{sep * TOTAL_HOURS_COLUMN_WIDTH}".gray
    end
  end
end
