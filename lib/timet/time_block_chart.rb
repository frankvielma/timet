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
  #   chart = TimeBlockChart.new(time_block)
  #   chart.print_time_block_chart(time_block, colors)
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

    # Initializes a new TimeBlockChart
    #
    # @param [Hash] time_block The time block data
    def initialize(time_block)
      @start_hour = time_block.values.map(&:keys).flatten.uniq.min.to_i
      @end_hour = time_block.values.map(&:keys).flatten.uniq.max.to_i
    end

    # Prints the time block chart
    #
    # @param [Hash] time_block The time block data
    # @param [Hash] colors The color mapping for different tags
    # @return [void]
    def print_time_block_chart(time_block, colors)
      print_header
      print_blocks(time_block, colors)
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

    # Prints the time blocks
    #
    # @param [Hash] time_block The time block data
    # @param [Hash] colors The color mapping for different tags
    # @return [void]
    def print_blocks(time_block, colors)
      return unless time_block

      weeks = []
      time_block.each_key do |date_string|
        date = Date.parse(date_string)
        day = date.strftime('%a')[0..2]

        format_and_print_date_info(date_string, day, weeks)

        time_block_initial = time_block[date_string]
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
