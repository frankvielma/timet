# frozen_string_literal: true

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
    # Character mapping for different time ranges
    CHAR_MAPPING = {
      0..120 => '_',
      121..450 => '▁',
      451..900 => '▂',
      901..1350 => '▃',
      1351..1800 => '▄',
      1801..2250 => '▅',
      2251..2700 => '▆',
      2701..3150 => '▇',
      3151..3600 => '█'
    }.freeze

    # Separator character for the chart
    SEPARATOR_CHAR = '░'

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
      @start_hour = @time_block.values.map(&:keys).flatten.uniq.min.to_i
      @end_hour = @time_block.values.map(&:keys).flatten.uniq.max.to_i
    end

    # Prints the time block chart.
    #
    # This method formats and prints the time block chart, including the header and the time blocks
    # for each entry. The chart is color-coded based on the provided color mapping for different tags.
    #
    # @param table [Hash] The time block data to be displayed in the chart.
    # @param colors [Hash] A mapping of tags to colors, used to color-code the time blocks.
    # @return [void] This method does not return a value; it performs side effects such as printing the chart.
    #
    # @example Print a time block chart
    #   chart = TimeBlockChart.new(table)
    #   chart.print_time_block_chart(table, colors)
    #
    # @note
    #   - The method first prints the header of the chart, which includes the time range.
    #   - It then prints the time blocks, using the provided color mapping to visually distinguish
    #     between different tags.
    #
    # @see #print_header
    # @see #print_blocks
    def print_time_block_chart(table, colors)
      print_header
      print_blocks(table, colors)
    end

    private

    # Prints the header of the chart
    #
    # @return [void]
    def print_header
      puts
      print ' ' * 19
      (@start_hour..@end_hour + 1).each { |hour| print format('%02d', hour).rjust(4) }
      puts
      puts '┌╴W ╴╴╴╴╴╴⏰╴╴╴╴╴╴┼'.gray + "#{'╴' * (@end_hour - @start_hour + 1) * 4}╴╴╴┼".gray
    end

    # Prints the time blocks for each date in the time block data.
    #
    # This method iterates over the time block data, formats and prints the date information,
    # prints the time blocks for each date using the provided color mapping, and calculates
    # and prints the total hours for each day. It also prints a footer at the end.
    #
    # @param table [Hash] The time block data containing the time entries for each date.
    # @param colors [Hash] A mapping of tags to colors, used to color-code the time blocks.
    # @return [void] This method does not return a value; it performs side effects such as printing
    #   the time blocks and related information.
    #
    # @example Print time blocks
    #   chart = TimeBlockChart.new(table)
    #   chart.print_blocks(table, colors)
    #
    # @note
    #   - The method skips processing if the `table` parameter is `nil`.
    #   - For each date in the time block data, it formats and prints the date and day of the week.
    #   - It prints the time blocks using the provided color mapping to visually distinguish
    #     between different tags.
    #   - It calculates and prints the total hours for each day.
    #   - A footer is printed at the end to provide a visual separation.
    #
    # @see #format_and_print_date_info
    # @see #print_time_blocks
    # @see #calculate_and_print_hours
    # @see #print_footer
    def print_blocks(table, colors)
      return unless table

      weeks = []
      @time_block.each_key do |date_string|
        date = Date.parse(date_string)
        day = date.strftime('%a')[0..2]

        format_and_print_date_info(date_string, day, weeks)

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

    # Formats and prints the date information
    #
    # @param [String] date_string The date string
    # @param [String] day The day of the week
    # @param [Array] weeks The list of weeks
    # @return [void]
    def format_and_print_date_info(date_string, day, weeks)
      weekend = date_string
      day = day.red if %w[Sa Su].include?(day)
      weekend = weekend.red if %w[Sa Su].include?(day)

      week = format_and_print_week(date_string, weeks)

      print '┆'.gray + "#{week} #{weekend} #{day}" + '┆- '.gray
    end

    # Formats and prints the week information
    #
    # @param [String] date_string The date string
    # @param [Array] weeks The list of weeks
    # @return [String] The formatted week string
    def format_and_print_week(date_string, weeks)
      week, current_index = determine_week(date_string, weeks)
      print_separator(week, current_index)
      week
    end

    # Determines the week for a given date
    #
    # @param [String] date_string The date string
    # @param [Array] weeks The list of weeks
    # @return [Array] The week string and current index
    def determine_week(date_string, weeks)
      weeks << Date.parse(date_string).cweek
      current_index = weeks.size - 1
      current_week = weeks[current_index]
      week = if current_week == weeks[current_index - 1] && current_index.positive?
               '  '
             else
               format('%02d', current_week).to_s.underline
             end
      [week, current_index]
    end

    # Prints the separator line
    #
    # @param [String] week The week string
    # @param [Integer] current_index The current index
    # @return [void]
    def print_separator(week, current_index)
      return unless week != '  ' && current_index.positive?

      sep = SEPARATOR_CHAR
      puts "┆#{sep * 17}┼#{sep * (@end_hour - @start_hour + 1) * 4}#{sep * 3}┼#{sep * 4}".gray
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
      [tag, get_block_char(hour_data&.first)]
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

    # Gets the block character for a given value
    #
    # @param [Integer, nil] value The value
    # @return [String] The block character
    def get_block_char(value)
      return ' ' unless value

      CHAR_MAPPING.find { |range, _| range.include?(value) }&.last || ' '
    end
  end
end
