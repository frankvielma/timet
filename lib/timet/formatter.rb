# frozen_string_literal: true

module Timet
  # This module is responsible for formatting the output of the `timet` application.
  # It provides methods for formatting the table header, separators, and rows.
  module Formatter
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

    # Formats the header of the time tracking report table.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing
    # the formatted header.
    #
    # @example Format and print the table header
    #   format_table_header
    #
    # @note The method constructs a string representing the table header and prints it.
    def format_table_header
      header = <<~TABLE
        Tracked time report \e[5m\u001b[31m[#{@filter}]\033[0m:
        #{format_table_separator}
        \033[32m| Id    | Date       | Tag    | Start    | End      | Duration | Notes              |\033[0m
        #{format_table_separator}
      TABLE
      puts header
    end

    # Formats the separator line for the time tracking report table.
    #
    # @return [String] The formatted separator line.
    #
    # @example Get the formatted table separator
    #   format_table_separator # => '+-------+------------+--------+----------+----------+----------+------------+'
    #
    # @note The method returns a string representing the separator line for the table.
    def format_table_separator
      '+-------+------------+--------+----------+----------+----------+--------------------+'
    end

    # Formats a row of the time tracking report table.
    #
    # @param row [Array] The row data to be formatted.
    # @return [String] The formatted row.
    #
    # @example Format a table row
    #   format_table_row(1, 'work', '2023-10-01', '12:00:00', '14:00:00', 7200, 'Completed task X')
    #
    # @note The method formats each element of the row and constructs a string representing the formatted row.
    def format_table_row(*row)
      id, tag, start_date, start_time, end_time, duration, notes = row
      "| #{id.to_s.rjust(5)} | #{start_date} | #{tag.ljust(6)} | #{start_time.split[1]} | " \
        "#{end_time.split[1].rjust(8)} | #{@db.seconds_to_hms(duration).rjust(8)} | #{format_notes(notes)}  |"
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
      spaces = 17
      return ' ' * spaces unless notes

      max_length = spaces - 3
      notes = "#{notes.slice(0, max_length)}..." if notes.length > max_length
      notes.ljust(spaces)
    end

    # @!method format_tag_distribution(duration_by_tag)
    #   Formats and displays the tag distribution.
    #
    #   @example
    #     duration_by_tag = { "timet" => 3600, "nextjs" => 1800 }
    #     Formatter.format_tag_distribution(duration_by_tag)
    #     # Output:
    #     #    timet:   66.67%  \u001b[38;5;42m====================\u001b[0m
    #     #   nextjs:   33.33%  \u001b[38;5;42m==========\u001b[0m
    #
    #   @param duration_by_tag [Hash<String, Integer>] A hash where keys are tags and values are durations in seconds.
    #   @return [void] This method outputs the formatted tag distribution to the console.
    def format_tag_distribution(duration_by_tag, colors)
      total = duration_by_tag.values.sum
      return unless total.positive?

      factor = duration_by_tag.size < 3 ? 2 : 1
      sorted_duration_by_tag = duration_by_tag.sort_by { |_, duration| -duration }
      process_and_print_tags(sorted_duration_by_tag, factor, total, colors)
    end

    # Processes and prints the tag distribution information.
    #
    # @param sorted_duration_by_tag [Array<Array(String, Numeric)>] An array of arrays where each inner array contains a
    # tag and its corresponding duration, sorted by duration in descending order.
    # @param factor [Numeric] The factor used to adjust the bar length.
    # @param total [Numeric] The total duration of all tags combined.
    # @return [void] This method outputs the tag distribution information to the standard output.
    def process_and_print_tags(*args)
      sorted_duration_by_tag, factor, total, colors = args
      block = '▅'
      sorted_duration_by_tag.each do |tag, duration|
        value, bar_length = calculate_value_and_bar_length(duration, total, factor)
        puts "#{tag.rjust(8)}: #{value.to_s.rjust(7)}%  \u001b[38;5;#{colors[tag] + 1}m#{block * bar_length}\u001b[0m"
      end
    end

    # Calculates the value and bar length for a given duration, total duration, and factor.
    #
    # @param duration [Numeric] The duration for the current tag.
    # @param total [Numeric] The total duration.
    # @param factor [Numeric] A factor to adjust the formatting.
    # @return [Array<(Float, Integer)>] An array containing the calculated value and bar length.
    #
    # @example
    #   calculate_value_and_bar_length(50, 100, 2) #=> [50.0, 25]
    def calculate_value_and_bar_length(duration, total, factor)
      value = (duration.to_f / total * 100).round(2)
      bar_length = (value / factor).round
      [value, bar_length]
    end

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
      start_time = time_block.values.map(&:keys).flatten.uniq.min.to_i
      print_header(start_time)
      print_blocks(time_block, colors, start_time)
    end

    # Prints the header of the time block chart.
    #
    # The header includes a visual representation of the time slots from the given start time to 23.
    # Each time slot is formatted as a two-digit number and aligned to the right within a fixed width.
    #
    # @param start_time [Integer] The starting time for the chart. This should be an integer between 0 and 23.
    #
    # @return [void] This method does not return a value; it prints the header directly to the output.
    #
    # @example
    #   print_header(10)
    #   # Output:
    #   #
    #   #      ⏳ ↦ [ 10  11  12  13  14  15  16  17  18  19  20  21  22  23]
    #
    # @note The method assumes that the start_time is within the valid range of 0 to 23.
    #   If the start_time is outside this range, the output may not be as expected.
    def print_header(start_time)
      puts
      print '     ⏳ ↦ [ '
      (start_time..23).each { |hour| print format('%02d', hour).ljust(4) }
      print ']'
      puts
    end

    # Prints the block characters for each hour in the time block chart.
    #
    # This method iterates over each hour from 0 to 23, retrieves the corresponding
    # block character using the `get_block_char` method, and prints it aligned for
    # readability. It also adds a double newline at the end for separation.
    #
    # @param time_block [Hash] A hash where the keys are formatted hour strings
    #                          (e.g., "00", "01") and the values are the corresponding
    #                          values to determine the block character.
    # @example
    #   time_block = { "00" => 100, "01" => 200, ..., "23" => 300 }
    #   print_blocks(time_block)
    #   # Output:
    #   # ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █
    #   #
    #   # (followed by two newlines)
    #
    def print_blocks(time_block, colors, start_time)
      return unless time_block

      time_block.each_key do |item|
        print "#{item}  "
        time_block_initial = time_block[item]
        print_time_blocks(start_time, time_block_initial, colors)
        puts
      end
      puts "\n"
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
      colored_block = color_code ? "\u001b[38;5;#{color_code + 1}m#{block}\u001b[0m  " : block
      print colored_block.ljust(4)
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
