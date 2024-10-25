# frozen_string_literal: true

module Timet
  # The TagDistribution module provides functionality to format and display the distribution of tags based on their
  # durations. This is particularly useful for visualizing how time is distributed across different tags in a project
  # or task management system.
  module TagDistribution
    # Formats and displays the tag distribution.
    #
    # @param duration_by_tag [Hash<String, Integer>] A hash where keys are tags and values are durations in seconds.
    # @return [void] This method outputs the formatted tag distribution to the console.
    #
    # @example
    #   duration_by_tag = { "timet" => 3600, "nextjs" => 1800 }
    #   Formatter.format_tag_distribution(duration_by_tag)
    #   # Output:
    #   #  timet:   66.67%  ====================
    #   #  nextjs:   33.33%  ==========
    def tag_distribution(duration_by_tag, colors)
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
        horizontal_bar = (block * bar_length).to_s.color(colors[tag] + 1)
        puts "#{tag.rjust(8)}: #{value.to_s.rjust(7)}%  #{horizontal_bar}"
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
  end
end
