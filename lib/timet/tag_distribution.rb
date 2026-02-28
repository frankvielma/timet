# frozen_string_literal: true

# Helper module for formatting tag distribution displays
require_relative 'time_statistics'
require_relative 'color_codes'

module Timet
  # Helper module for formatting tag distribution displays
  module TagDistributionFormatting
    module_function

    def calculate_value_and_bar_length(duration, total)
      value = duration.to_f / total
      percentage_value = (value * 100).round(1)
      bar_length = (value * TagDistribution::MAX_BAR_LENGTH).round
      [percentage_value, bar_length]
    end

    def generate_horizontal_bar(bar_length, color_index)
      (TagDistribution::BLOCK_CHAR * bar_length).to_s.color(color_index + 1)
    end

    def generate_stats(tag, time_stats)
      total_hours = (time_stats.total_duration_by_tag[tag] / 3600.0).round(1)
      avg_minutes = (time_stats.average_by_tag[tag] / 60.0).round(1)
      sd_minutes = (time_stats.standard_deviation_by_tag[tag] / 60).round(1)
      "T: #{total_hours}h, AVG: #{avg_minutes}min SD: #{sd_minutes}min".gray
    end

    def introduction(total)
      total_hours = (total / 3600.0).round(1)
      [
        "\n---",
        'Time Report Summary'.bold,
        'This report provides a detailed breakdown of time spent ' \
        "across various categories, totaling #{"#{total_hours}h".bold} of tracked work.".white,
        "\n"
      ]
    end

    def build_duration_part(duration)
      total_hours = (duration / 3600.0).round(1)
      " The cumulative time spent was #{"#{total_hours}h".bold}, " \
        'indicating the overall effort dedicated to this area.'
    end

    def build_average_part(metrics)
      " On average, each task took #{"#{metrics[:avg_minutes]}min".bold}, " \
        'which helps in understanding the typical time commitment per task.'
    end

    def high_sd_message(sd_min)
      " A high standard deviation of #{"#{sd_min}min".bold} " \
      'relative to the average suggests significant variability in task durations. ' \
      'This could imply inconsistent task definitions, varying complexity, ' \
      'or frequent interruptions.'.red
    end

    def moderate_sd_message(sd_min)
      " A moderate standard deviation of #{"#{sd_min}min".bold} " \
      'indicates some variation in task durations.'.blue
    end

    def low_sd_message(sd_min)
      " A low standard deviation of #{"#{sd_min}min".bold} " \
      'suggests that task durations were quite consistent and predictable.'.green
    end

    def build_major_summary(major_categories)
      total_percentage = major_categories.sum(&:last)
      category_names = major_categories.map { |c, _| "'#{c.capitalize}'" }.join(' and ')
      ["\nTogether, #{category_names} dominate the time spent, " \
       "accounting for nearly #{"#{total_percentage.round}%".bold} of the total.".white]
    end
  end

  # The TagDistribution module provides functionality to format and display
  # the distribution of tags based on their durations.
  module TagDistribution
    MAX_BAR_LENGTH = 70
    BLOCK_CHAR = '▅'
    TAG_SIZE = 12

    # Context object for tag distribution formatting
    Context = Struct.new(:time_stats, :total, :colors) do
      include TagDistributionFormatting

      # Formats the overall average and standard deviation from the time statistics.
      # @return [Hash] A hash with :avg and :sd keys, values in minutes rounded to 1 decimal place.
      def format_avg
        time_stats.totals.slice(:avg, :sd).transform_values { |val| (val / 60.0).round(1) }
      end

      # Formats the total duration in hours.
      # @return [Float] Total duration in hours rounded to 1 decimal place.
      def format_total_hours
        (total / 3600.0).round(1)
      end

      # Calculates metrics for a specific tag.
      # @param tag [String] The tag name.
      # @param duration [Numeric] The duration for the tag.
      # @return [Hash] A hash of metrics for the tag.
      def tag_metrics(tag, duration)
        stats = time_stats
        value = duration.to_f / total
        avg_sec = stats.average_by_tag[tag]
        sd_sec = stats.standard_deviation_by_tag[tag]

        {
          tag: tag, duration: duration, percentage: (value * 100).round(1),
          avg_minutes: (avg_sec / 60.0).round(1), sd_minutes: (sd_sec / 60.0).round(1),
          avg_seconds: avg_sec, sd_seconds: sd_sec, value: value
        }
      end

      def category_breakdown
        time_stats.sorted_duration_by_tag.each_with_object(['Category Breakdown'.bold]) do |(tag, duration), parts|
          parts << build_category_explanation(tag, duration).white
        end
      end

      def build_category_explanation(tag, duration)
        metrics = tag_metrics(tag, duration)
        [
          "#{tag.capitalize.to_s.bold}:",
          " This category consumed #{"#{metrics[:percentage]}%".bold} of the total tracked time.",
          build_duration_part(duration), build_average_part(metrics),
          sd_variation_message(metrics)
        ].join
      end

      def sd_variation_message(metrics)
        sd_min = metrics[:sd_minutes]
        avg_hour = metrics[:avg_minutes] / 60.0
        return high_sd_message(sd_min) if sd_min > avg_hour * 0.5
        return moderate_sd_message(sd_min) if sd_min > avg_hour * 0.2

        low_sd_message(sd_min)
      end

      def build_sorted_categories
        time_stats.sorted_duration_by_tag.map do |tag, duration|
          [tag, tag_metrics(tag, duration)[:percentage]]
        end.sort_by(&:last).reverse
      end

      def overall_summary
        return [] unless time_stats.sorted_duration_by_tag.any?

        major_categories = build_sorted_categories.select { |_, pct| pct > 10 }
        return [] if major_categories.size <= 1

        build_major_summary(major_categories)
      end

      def print_summary
        f_avg = format_avg
        summary = "#{' ' * TAG_SIZE} #{'Summary'.underline}: "
        summary += "[T: #{format_total_hours}, AVG: #{f_avg[:avg]}min SD: #{f_avg[:sd]}min]".white
        puts summary
      end

      def print_explanation
        parts = []
        parts << introduction(total)
        parts << category_breakdown
        parts << overall_summary
        puts parts.flatten.join("\n")
      end

      def print_tags_info
        stats = time_stats
        stats.sorted_duration_by_tag.each do |tag, duration|
          value, bar_length = calculate_value_and_bar_length(duration, total)
          horizontal_bar = generate_horizontal_bar(bar_length, colors[tag])
          formatted_tag = tag[0...TAG_SIZE].rjust(TAG_SIZE)
          tag_stats = generate_stats(tag, stats)

          puts "#{formatted_tag}: #{value.to_s.rjust(5)}%  #{horizontal_bar} [#{tag_stats}]"
        end
      end

      def render
        print_summary
        print_tags_info
      end
    end

    include TagDistributionFormatting

    def tag_distribution(colors)
      time_stats = TimeStatistics.new(@items)
      total = time_stats.total_duration

      return unless total.positive?

      ctx = Context.new(time_stats, total, colors)
      ctx.render
      print_footer
    end

    def print_footer
      puts '-' * 45
      puts 'T:'.rjust(4).red + 'The total duration'.gray
      puts 'AVG:'.rjust(4).red + 'The average duration'.gray
      puts 'SD:'.rjust(4).red + 'The standard deviation of the durations'.gray
    end
  end
end
