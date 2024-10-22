# frozen_string_literal: true

module Timet
  # The TimeReportHelper module provides a collection of utility methods for processing and formatting time report data.
  # It includes methods for processing time entries, handling time blocks, formatting items for CSV export,
  # and validating date formats.
  # This module is designed to be included in classes that require time report processing functionalities.
  module TimeReportHelper
    # Processes each time entry in the items array and updates the time block and duration by tag.
    #
    # @return [Array<(Hash, Hash)>] An array containing the updated time block and duration by tag.
    #
    # @example
    #   items = [
    #     [start_time1, end_time1, tag1],
    #     [start_time2, end_time2, tag2]
    #   ]
    #   process_time_entries
    #   #=> [{ '2024-10-21' => { 8 => [duration1, tag1], 9 => [duration2, tag2] } }, { tag1 => total_duration1,
    #   tag2 => total_duration2 }]
    def process_time_entries
      duration_by_tag = Hash.new(0)
      time_block = Hash.new { |hash, key| hash[key] = {} }

      items.each_with_index do |item, idx|
        display_time_entry(item, TimeHelper.extract_date(items, idx))
        start_time = item[1]
        end_time = item[2]
        tag = item[3]
        time_block = process_time_block_item(start_time, end_time, tag, time_block)

        duration_by_tag[tag] += TimeHelper.calculate_duration(start_time, end_time)
      end
      [time_block, duration_by_tag]
    end

    # Processes a time block item and updates the time block hash.
    #
    # @param start_time [Time] The start time of the time block.
    # @param end_time [Time] The end time of the time block.
    # @param tag [String] The tag associated with the time block.
    # @param time_block [Hash] A hash containing time block data, where keys are dates and values are hashes of time
    # slots and their corresponding values.
    # @return [Hash] The updated time block hash.
    #
    # @example
    #   start_time = Time.new(2024, 10, 21, 8, 0, 0)
    #   end_time = Time.new(2024, 10, 21, 9, 0, 0)
    #   tag = 'work'
    #   time_block = {}
    #   process_time_block_item(start_time, end_time, tag, time_block)
    #   #=> { '2024-10-21' => { 8 => [duration, 'work'] } }
    def process_time_block_item(*args)
      start_time, end_time, tag, time_block = args
      block_hour = TimeHelper.count_seconds_per_hour_block(start_time, end_time, tag)
      date_line = TimeHelper.timestamp_to_date(start_time)
      time_block[date_line] = add_hashes(time_block[date_line], block_hour)
      time_block
    end

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

    # Writes the CSV rows for the time report.
    #
    # @param csv [CSV] The CSV object to which the rows will be written.
    # @return [void]
    #
    # @example
    #   csv = CSV.new(file)
    #   write_csv_rows(csv)
    def write_csv_rows(csv)
      items.each do |item|
        csv << format_item(item)
      end
    end
  end
end
