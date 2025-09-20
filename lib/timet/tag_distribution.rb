# frozen_string_literal: true

require_relative 'time_statistics'
require_relative 'color_codes' # Ensure color methods are available
module Timet
  # The TagDistribution module provides functionality to format and display the distribution of tags based on their
  # durations. This is particularly useful for visualizing how time is distributed across different tags in a project
  # or task management system.
  module TagDistribution
    MAX_BAR_LENGTH = 70
    BLOCK_CHAR = '▅'
    TAG_SIZE = 12

    # Formats and displays the tag distribution.
    #
    # @param duration_by_tag [Hash<String, Integer>] A hash where keys are tags and values are durations in seconds.
    # @param colors [Hash<String, String>] A hash where keys are tags and values are color codes for display.
    # @return [void] This method outputs the formatted tag distribution to the console.
    #
    # @example
    #   duration_by_tag = { "timet" => 3600, "nextjs" => 1800 }
    #   colors = { "timet" => "\e[31m", "nextjs" => "\e[32m" }
    #   Formatter.format_tag_distribution(duration_by_tag, colors)
    #   # Output:
    #   #  \e[31m timet:   66.67%  ==================== \e[0m
    #   #  \e[32m nextjs:   33.33%  ========== \e[0m
    def tag_distribution(colors)
      time_stats = TimeStatistics.new(@items)
      total = time_stats.total_duration

      return unless total.positive?

      process_and_print_tags(time_stats, total, colors)
    end

    # Processes and prints the tag distribution information.
    #
    # @param time_stats [Object] An object containing the time statistics, including totals and sorted durations by tag.
    # @param total [Numeric] The total duration of all tags combined.
    # @param colors [Object] An object containing color formatting methods.
    # @return [void] This method outputs the tag distribution information to the standard output.
    def process_and_print_tags(time_stats, total, colors)
      print_summary(time_stats, total)
      print_tags_info(time_stats, total, colors)
      print_footer
      print_explanation(time_stats, total)
    end

    # Prints the footer information.
    #
    # @return [void] This method outputs the footer information to the standard output.
    def print_footer
      puts '-' * 45
      puts 'T:'.rjust(4).red + 'The total duration'.gray
      puts 'AVG:'.rjust(4).red + 'The average duration'.gray
      puts 'SD:'.rjust(4).red + 'The standard deviation of the durations'.gray
    end

    # Generates and prints an explanation of the time report based on tag distribution.
    #
    # @param time_stats [Object] An object containing the time statistics.
    # @param total [Numeric] The total duration of all tags combined in seconds.
    # @return [void] This method outputs the explanation to the standard output.
    def print_explanation(time_stats, total)
      explanations = []
      high_sd_threshold = 0.5
      moderate_sd_threshold = 0.2

      # --- Introduction ---
      total_duration_hours = (total / 3600.0).round(1)
      explanations << "\n---"
      explanations << 'Time Report Summary'.bold
      explanations << "This report provides a detailed breakdown of time spent across various categories, totaling #{"#{total_duration_hours}h".bold} of tracked work.".white
      explanations << "\n"

      # --- Individual Category Explanations ---
      explanations << 'Category Breakdown'.bold
      time_stats.sorted_duration_by_tag.each do |tag, duration|
        explanation = "#{"#{tag.capitalize}".bold}:"

        # Percentage
        percentage = (duration.to_f / total * 100).round(1)
        explanation += " This category consumed #{"#{percentage}%".bold} of the total tracked time."

        # Total Duration
        total_hours = (duration / 3600.0).round(1)
        explanation += " The cumulative time spent was #{"#{total_hours}h".bold}, indicating the overall effort dedicated to this area."

        # Average Duration
        avg_minutes = (time_stats.average_by_tag[tag] / 60.0).round(1)
        explanation += " On average, each task took #{"#{avg_minutes}min".bold}, which helps in understanding the typical time commitment per task."

        # Standard Deviation
        sd_minutes = (time_stats.standard_deviation_by_tag[tag] / 60.0).round(1)
        avg_duration_seconds = time_stats.average_by_tag[tag]

        if sd_minutes > avg_duration_seconds / 60.0 * high_sd_threshold
          explanation += " A high standard deviation of #{"#{sd_minutes}min".bold} relative to the average suggests significant variability in task durations. This could imply inconsistent task definitions, varying complexity, or frequent interruptions.".red
        elsif sd_minutes > avg_duration_seconds / 60.0 * moderate_sd_threshold
          explanation += " A moderate standard deviation of #{"#{sd_minutes}min".bold} indicates some variation in task durations.".blue
        else
          explanation += " A low standard deviation of #{"#{sd_minutes}min".bold} suggests that task durations were quite consistent and predictable.".green
        end

        explanations << explanation.white
      end

      # --- Overall Summary ---
      if time_stats.sorted_duration_by_tag.any?
        sorted_categories = time_stats.sorted_duration_by_tag.map do |tag, duration|
          [tag, (duration.to_f / total * 100).round(1)]
        end.sort_by { |_, percentage| -percentage }

        major_categories = sorted_categories.select { |_, percentage| percentage > 10 }
        if major_categories.size > 1
          total_percentage = major_categories.sum { |_, percentage| percentage }
          category_names = major_categories.map { |c, _| "'#{c.capitalize}'" }.join(' and ')
          explanations << "\nTogether, #{category_names} dominate the time spent, accounting for nearly #{"#{total_percentage.round}%".bold} of the total.".white
        end
      end
      puts explanations.join("\n")
    end

    # Prints the summary information including total duration, average duration, and standard deviation.
    #
    # @param time_stats [Object] An object containing the time statistics, including totals.
    # @param total [Numeric] The total duration of all tags combined.
    # @return [void] This method outputs the summary information to the standard output.
    def print_summary(time_stats, total)
      avg = (time_stats.totals[:avg] / 60.0).round(1)
      sd = (time_stats.totals[:sd] / 60.0).round(1)
      summary = "#{' ' * TAG_SIZE} #{'Summary'.underline}: "
      summary += "[T: #{(total / 3600.0).round(1)}h, AVG: #{avg}min SD: #{sd}min]".white
      puts summary
    end

    # Prints the detailed information for each tag.
    #
    # @param time_stats [Object] An object containing the time statistics, including sorted durations by tag.
    # @param total [Numeric] The total duration of all tags combined.
    # @param colors [Object] An object containing color formatting methods.
    # @return [void] This method outputs the detailed tag information to the standard output.
    def print_tags_info(time_stats, total, colors)
      time_stats.sorted_duration_by_tag.each do |tag, duration|
        value, bar_length = calculate_value_and_bar_length(duration, total)
        horizontal_bar = generate_horizontal_bar(bar_length, colors[tag])
        formatted_tag = tag[0...TAG_SIZE].rjust(TAG_SIZE)
        stats = generate_stats(tag, time_stats)

        puts "#{formatted_tag}: #{value.to_s.rjust(5)}%  #{horizontal_bar} [#{stats}]"
      end
    end

    # Generates a horizontal bar for display based on the bar length and color index.
    #
    # @param bar_length [Numeric] The length of the bar to generate.
    # @param color_index [Numeric] The color index to use for the bar.
    # @return [String] The generated horizontal bar string.
    def generate_horizontal_bar(bar_length, color_index)
      (BLOCK_CHAR * bar_length).to_s.color(color_index + 1)
    end

    # Generates the statistics string for a given tag.
    #
    # @param tag [String] The tag for which to generate the statistics.
    # @param time_stats [Object] An object containing time statistics for the tags.
    # @return [String] The generated statistics string.
    def generate_stats(tag, time_stats)
      total_hours = (time_stats.total_duration_by_tag[tag] / 3600.0).round(1)
      avg_minutes = (time_stats.average_by_tag[tag] / 60.0).round(1)
      sd_minutes = (time_stats.standard_deviation_by_tag[tag] / 60).round(1)
      "T: #{total_hours}h, AVG: #{avg_minutes}min SD: #{sd_minutes}min".gray
    end

    # Calculates the percentage value and bar length for a given duration and total duration.
    #
    # @param duration [Numeric] The duration for the current tag.
    # @param total [Numeric] The total duration.
    # @return [Array<(Float, Integer)>] An array containing the calculated value and bar length.
    #
    # @example
    #   calculate_value_and_bar_length(50, 100, 2) #=> [50.0, 25]
    def calculate_value_and_bar_length(duration, total)
      value = duration.to_f / total
      percentage_value = (value * 100).round(1)
      bar_length = (value * MAX_BAR_LENGTH).round
      [percentage_value, bar_length]
    end
  end
end
