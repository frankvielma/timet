# frozen_string_literal: true

module Timet
  # The TimeReportHelper module provides a collection of utility methods for processing and formatting time report data.
  # It includes methods for processing time entries, handling time blocks, formatting items for CSV export,
  # and validating date formats.
  # This module is designed to be included in classes that require time report processing functionalities.
  module TimeReportHelper
    # Provides predefined date ranges for filtering.
    #
    # @return [Hash] A hash containing predefined date ranges.
    #
    # @example Get the predefined date ranges
    #   date_ranges
    #
    # @note The method returns a hash with predefined date ranges for 'today', 'yesterday', 'week', and 'month'.
    def date_ranges
      today = Date.today
      tomorrow = today + 1
      {
        'today' => [today, nil],
        'yesterday' => [today - 1, nil],
        'week' => [today - 7, tomorrow],
        'month' => [today - 30, tomorrow]
      }
    end

    # Formats an item for CSV export.
    #
    # @param item [Array] The item to format.
    #
    # @return [Array] The formatted item.
    #
    # @example Format an item for CSV export
    #   format_item(item)
    #
    # @note The method formats the item's ID, start time, end time, tag, and notes.
    def format_item(item)
      id, start_time, end_time, tags, notes = item
      [
        id,
        TimeHelper.format_time(start_time),
        TimeHelper.format_time(end_time),
        tags,
        notes
      ]
    end

    # Validates the date format.
    #
    # @param date_string [String] The date string to validate.
    #
    # @return [Boolean] True if the date format is valid, otherwise false.
    #
    # @example Validate the date format
    #   valid_date_format?('2021-10-01') # => true
    #
    # @note The method validates the date format for single dates and date ranges.
    def valid_date_format?(date_string)
      date_format_single = /^\d{4}-\d{2}-\d{2}$/
      date_format_range = /^\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}$/

      date_string.match?(date_format_single) || date_string.match?(date_format_range)
    end

    # Merges two hashes, summing the numeric values of corresponding keys.
    #
    # @param base_hash [Hash] The base hash to which the additional hash will be merged.
    # @param additional_hash [Hash] The additional hash whose values will be added to the base hash.
    # @return [Hash] A new hash with the summed values.
    #
    # @example
    #   base_hash = { 'key1' => [10, 'tag1'], 'key2' => [20, 'tag2'] }
    #   additional_hash = { 'key1' => [5, 'tag1'], 'key3' => [15, 'tag3'] }
    #   add_hashes(base_hash, additional_hash)
    #   #=> { 'key1' => [15, 'tag1'], 'key2' => [20, 'tag2'], 'key3' => [15, 'tag3'] }
    def add_hashes(base_hash, additional_hash)
      base_hash.merge(additional_hash) do |_key, old_value, new_value|
        summed_number = old_value[0] + new_value[0]
        [summed_number, old_value[1]]
      end
    end
  end
end
