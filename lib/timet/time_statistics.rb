# frozen_string_literal: true

require 'descriptive_statistics'
require_relative 'time_helper'

module Timet
  # @!attribute [r] duration_by_tag
  #   @return [Hash] A hash where keys are tags and values are arrays of durations (in seconds) associated
  #   with each tag.
  # @!attribute [r] total_duration
  #   @return [Integer] The total duration (in seconds) of all time intervals across all tags.
  class TimeStatistics
    attr_reader :duration_by_tag, :total_duration

    # Initializes a new instance of TimeStatistics.
    #
    # @param data [Array<Array>] An array of arrays where each sub-array contains:
    #   - [0] An identifier (not used in calculations)
    #   - [1] The start time (in seconds since the epoch)
    #   - [2] The end time (in seconds since the epoch), or nil if the interval is ongoing
    #   - [3] The tag associated with the time interval
    # @return [TimeStatistics] A new instance of TimeStatistics.
    def initialize(data)
      @data = data
      @duration_by_tag = Hash.new { |hash, key| hash[key] = [] }
      @total_duration = 0
      calculate_durations_by_tag
    end

    # Calculates the duration for each tag and updates the @duration_by_tag and @total_duration attributes.
    #
    # @return [void]
    def calculate_durations_by_tag
      @data.each do |row|
        start_time = row[1]
        end_time = row[2] || Time.now.to_i
        tag = row[3]

        duration = end_time - start_time
        @duration_by_tag[tag] << duration
        @total_duration += duration
      end
    end

    # Returns a hash where keys are tags and values are the total duration (in seconds) for each tag.
    #
    # @return [Hash<String, Integer>] A hash mapping tags to their total durations.
    def total_duration_by_tag
      @duration_by_tag.transform_values(&:sum)
    end

    # Returns an array of arrays where each sub-array contains a tag and its total duration, sorted by duration in
    # descending order.
    #
    # @return [Array<Array>] An array of [tag, total_duration] pairs sorted by total_duration in descending order.
    def sorted_duration_by_tag
      @duration_by_tag.map { |tag, durations| [tag, durations.sum] }.sort_by { |_, sum| -sum }
    end

    # Returns a hash where keys are tags and values are the average duration (in seconds) for each tag.
    #
    # @return [Hash<String, Float>] A hash mapping tags to their average durations.
    def average_by_tag
      @duration_by_tag.transform_values { |durations| durations.sum.to_f / durations.size }
    end

    # Returns a hash where keys are tags and values are the standard deviation of durations for each tag.
    #
    # @return [Hash<String, Float>] A hash mapping tags to their standard deviations.
    def standard_deviation_by_tag
      @duration_by_tag.transform_values(&:standard_deviation)
    end

    # Returns a hash where keys are tags and values are additional descriptive statistics for the durations of each tag.
    #
    # @return [Hash<String, Hash>] A hash mapping tags to a hash of descriptive statistics
    # (e.g., min, max, median, etc.).
    def additional_stats_by_tag
      @duration_by_tag.transform_values(&:descriptive_statistics)
    end
  end
end
