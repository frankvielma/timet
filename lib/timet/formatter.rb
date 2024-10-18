# frozen_string_literal: true

module Timet
  # This module is responsible for formatting the output of the `timet` application.
  # It provides methods for formatting the table header, separators, and rows.
  module Formatter
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
      return ' ' * spaces if notes.nil?

      notes = "#{notes.slice(0, spaces - 3)}..." if notes.length > spaces - 3
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
    def format_tag_distribution(duration_by_tag)
      total = duration_by_tag.values.sum
      return unless total.positive?

      factor = duration_by_tag.size < 3 ? 2 : 1
      sorted_duration_by_tag = duration_by_tag.sort_by { |_, duration| -duration }
      process_and_print_tags(sorted_duration_by_tag, factor, total)
    end

    # Processes and prints the tag distribution information.
    #
    # @param sorted_duration_by_tag [Array<Array(String, Numeric)>] An array of arrays where each inner array contains a
    # tag and its corresponding duration, sorted by duration in descending order.
    # @param factor [Numeric] The factor used to adjust the bar length.
    # @param total [Numeric] The total duration of all tags combined.
    # @return [void] This method outputs the tag distribution information to the standard output.
    def process_and_print_tags(sorted_duration_by_tag, factor, total)
      block = '▅'
      sorted_duration_by_tag.each do |tag, duration|
        value = (duration.to_f / total * 100).round(2)
        bar_length = (value / factor).to_i
        color = rand(256)
        puts "#{tag.rjust(8)}: #{value.to_s.rjust(7)}%  \u001b[38;5;#{color}m#{block * bar_length}\u001b[0m"
      end
    end

    # Prints the entire time block chart.
    #
    # This method orchestrates the printing of the entire time block chart by calling
    # the `print_header` and `print_blocks` methods. It also prints the separator line
    # between the header and the blocks, and adds a double newline at the end for
    # separation.
    #
    # @param time_block [Hash] A hash where the keys are formatted hour strings
    #                          (e.g., "00", "01") and the values are the corresponding
    #                          values to determine the block character.
    # @example
    #   time_block = { "00" => 100, "01" => 200, ..., "23" => 300 }
    #   print_time_block_chart(time_block)
    #   # Output:
    #   # ⏳ ↦ [ 00  01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20  21  22  23 ]
    #   #      [ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █
    #   #
    #   # (followed by two newlines)
    #
    def print_time_block_chart(time_block)
      print_header
      print '     [ '
      print_blocks(time_block)
    end

    # Prints the header of the time block chart.
    #
    # This method outputs the header line of the chart, which includes the hours
    # from 00 to 23, formatted and aligned for readability.
    #
    # @example
    #   print_header
    #   # Output:
    #   # ⏳ ↦ [ 00  01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20  21  22  23
    #
    def print_header
      puts
      print '⏳ ↦ [ '
      (0..23).each { |hour| print format('%02d', hour).ljust(4) }
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
    def print_blocks(time_block)
      return unless time_block

      (0..23).each do |hour|
        block_char = get_block_char(time_block[format('%02d', hour)])
        print (block_char * 2).ljust(4)
      end
      print ']'
      puts "\n\n"
    end

    # Determines the block character based on the value.
    #
    # @param value [Integer] The value to determine the block character for.
    # @return [String] The block character corresponding to the value.
    def get_block_char(value)
      range_to_char = {
        0..120 => ' ',
        121..450 => '▁',
        451..900 => '▂',
        901..1350 => '▃',
        1351..1800 => '▄',
        1801..2250 => '▅',
        2251..2700 => '▆',
        2701..3150 => '▇',
        3151..3600 => '█'
      }

      range_to_char.find { |range, _| range.include?(value) }&.last || ' '
    end
  end
end
