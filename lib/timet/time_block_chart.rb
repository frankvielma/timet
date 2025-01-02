# frozen_string_literal: true

module Timet
  # This module is responsible for formatting the output of the `timet` application.
  # It provides methods for formatting the table header, separators, and rows.
  module TimeBlockChart
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

    SEPARATOR_CHAR = '░'

    # Prints a time block chart based on the provided time block and colors.
    #
    # @param time_block [Hash] A hash where the keys are time blocks and the values are hashes of time slots and their
    # corresponding values.
    #   Example: { "block1" => { 10 => "value1", 11 => "value2" }, "block2" => { 12 => "value3" } }
    # @param colors [Hash] A hash where the keys are time slots and the values are the colors to be used
    # for those slots.
    #   Example: { 10 => "red", 11 => "blue", 12 => "green" }
    #
    # @return [void] This method does not return a value; it prints the chart directly to the output.
    #
    # @example
    #   time_block = { "block1" => { 10 => "value1", 11 => "value2" }, "block2" => { 12 => "value3" } }
    #   colors = { 10 => "red", 11 => "blue", 12 => "green" }
    #   print_time_block_chart(time_block, colors)
    #
    # @note This method relies on two helper methods: `print_header` and `print_blocks`.
    #   Ensure these methods are defined and available in the scope where `print_time_block_chart` is called.
    #
    # @see #print_header
    # @see #print_blocks
    def print_time_block_chart(time_block, colors)
      start_hour = time_block.values.map(&:keys).flatten.uniq.min.to_i
      print_header(start_hour)
      print_blocks(time_block, colors, start_hour)
    end

    # Prints the header of the time block chart.
    #
    # The header includes a visual representation of the time slots from the given start time to 23.
    # Each time slot is formatted as a two-digit number and aligned to the right within a fixed width.
    #
    # @param start_hour [Integer] The starting time for the chart. This should be an integer between 0 and 23.
    #
    # @return [void] This method does not return a value; it prints the header directly to the output.
    #
    # @example
    #   print_header(10)
    #   # Output:
    #   #
    #   #      ⏳ ↦ [ 10  11  12  13  14  15  16  17  18  19  20  21  22  23]
    #
    # @note The method assumes that the start_hour is within the valid range of 0 to 23.
    #   If the start_hour is outside this range, the output may not be as expected.
    def print_header(start_hour)
      puts
      print ' ' * 19
      (start_hour..23).each { |hour| print format('%02d', hour).rjust(4) }
      puts
      puts '┌╴W ╴╴╴╴╴╴⏰╴╴╴╴╴╴┼'.gray + "#{'╴' * (24 - start_hour) * 4}╴╴╴┼".gray
    end

    # Prints the time blocks for each date in the given time block data structure.
    #
    # @param time_block [Hash] A hash where keys are date strings and values are time block data.
    # @param colors [Hash] A hash containing color codes for formatting.
    # @param start_hour [Integer] The starting hour for the time blocks.
    # @return [void]
    def print_blocks(time_block, colors, start_hour)
      return unless time_block

      weeks = []
      time_block.each_key do |date_string|
        date = Date.parse(date_string)
        day = date.strftime('%a')[0..2]

        format_and_print_date_info(date_string, day, weeks, start_hour)

        time_block_initial = time_block[date_string]
        print_time_blocks(start_hour, time_block_initial, colors)

        calculate_and_print_hours(time_block_initial)
      end
      print_footer(start_hour)
    end

    # Calculates the total hours from the given time block data and prints it.
    #
    # @param time_block_initial [Hash] A hash containing time block data for a specific date.
    # @return [void]
    def calculate_and_print_hours(time_block_initial)
      total_seconds = time_block_initial.values.map { |item| item[0] }.sum
      hours_per_day = (total_seconds / 3600.0).round(1)
      print "-┆#{hours_per_day}h".gray
      puts
    end

    # Formats and prints the date information including the week and day.
    #
    # @param date_string [String] The date string in a parsable format.
    # @param day [String] The abbreviated day of the week (e.g., "Mo" for Monday).
    # @param weeks [Array<Integer>] An array storing the week numbers.
    # @param start_hour [Integer] The starting hour for the time blocks.
    # @return [void]
    def format_and_print_date_info(date_string, day, weeks, start_hour)
      weekend = date_string
      day = day.red if %w[Sa Su].include?(day)
      weekend = weekend.red if %w[Sa Su].include?(day)

      week = format_and_print_week(date_string, weeks, start_hour)

      print '┆'.gray + "#{week} #{weekend} #{day}" + '┆- '.gray
    end

    # Formats and prints the week information including the separator if necessary.
    #
    # @param date_string [String] The date string in a parsable format.
    # @param weeks [Array<Integer>] An array storing the week numbers.
    # @param start_hour [Integer] The starting hour for the time blocks.
    # @return [String] The formatted week string.
    def format_and_print_week(date_string, weeks, start_hour)
      week, current_index = determine_week(date_string, weeks)
      print_separator(start_hour, week, current_index)
      week
    end

    # Determines the week string based on the date and the previous week.
    #
    # @param date_string [String] The date string in a parsable format.
    # @param weeks [Array<Integer>] An array storing the week numbers.
    # @return [Array<String, Integer>] An array containing the formatted week string and the current index.
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

    # Prints the separator line if the week string is not empty and the current index is positive.
    #
    # @param start_hour [Integer] The starting hour for the time blocks.
    # @param week [String] The formatted week string.
    # @param current_index [Integer] The current index in the weeks array.
    # @return [void]
    def print_separator(start_hour, week, current_index)
      return unless week != '  ' && current_index.positive?

      sep = SEPARATOR_CHAR
      puts "┆#{sep * 17}┼#{sep * (24 - start_hour) * 4}#{sep * 3}┼#{sep * 4}".gray
    end

    # Prints the footer of the report.
    #
    # @param start_hour [Integer] The start time used to calculate the footer length.
    # @return [void] This method does not return a value; it prints directly to the standard output.
    def print_footer(start_hour)
      timet = "\e]8;;https://github.com/frankvielma/timet/\aTimet\e]8;;\a".green
      puts '└╴╴╴╴╴╴╴'.gray + timet + "╴╴╴╴╴┴#{'╴' * (24 - start_hour) * 4}╴╴╴┴".gray
      puts
    end

    # Prints time blocks for each hour from the start time to 23.
    #
    # @param start_time [Integer] The starting hour for printing time blocks.
    # @param time_block_initial [Hash] A hash containing time block data, where keys are formatted hours and values
    # are arrays containing block data.
    # @param colors [Hash] A hash mapping tags to color codes.
    # @return [void]
    #
    # @example
    #   time_block_initial = {
    #     '01' => ['block_char_data', 'tag']
    #   }
    #   colors = { 'tag' => 1 }
    #   print_time_blocks(1, time_block_initial, colors) # Prints time blocks for hours 1 to 23
    def print_time_blocks(start_time, time_block_initial, colors)
      (start_time..23).each do |hour|
        tag, block_char = get_formatted_block_char(hour, time_block_initial)
        print_colored_block(block_char, tag, colors)
      end
    end

    # Returns the formatted block character and its associated tag for a given hour.
    #
    # @param hour [Integer] The hour for which to retrieve the block character.
    # @param time_block_initial [Hash] A hash containing time block data, where keys are formatted hours and values
    # are arrays containing block data.
    # @return [Array<(String, String)>] An array containing the tag and the block character.
    #
    # @example
    #   time_block_initial = {
    #     '01' => ['block_char_data', 'tag']
    #   }
    #   get_formatted_block_char(1, time_block_initial) #=> ['tag', 'block_char']
    def get_formatted_block_char(hour, time_block_initial)
      formatted_hour = format('%02d', hour)
      hour_data = time_block_initial[formatted_hour]
      tag = hour_data&.last
      [tag, get_block_char(hour_data&.first)]
    end

    # Prints a colored block character based on the provided tag and block character.
    #
    # @param block_char [String] The block character to be printed.
    # @param tag [String] The tag associated with the block character, used to determine the color.
    # @param colors [Hash] A hash mapping tags to color codes.
    #
    # @example
    #   colors = { 'tag' => 1 }
    #   print_colored_block('X', 'tag', colors) # Prints a colored block character 'XX'
    def print_colored_block(block_char, tag, colors)
      color_code = colors[tag]
      block = block_char * 2
      colored_block = color_code ? "#{block.color(color_code + 1)}  " : block
      print colored_block.rjust(4)
    end

    # Determines the block character based on the value.
    #
    # @param value [Integer] The value to determine the block character for.
    # @return [String] The block character corresponding to the value.
    def get_block_char(value)
      return ' ' unless value

      CHAR_MAPPING.find { |range, _| range.include?(value) }&.last || ' '
    end
  end
end
