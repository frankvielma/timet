# frozen_string_literal: true

require_relative 'time_helper'

module Timet
  # The Utils module provides a collection of general utility methods used across the Timet gem.
  module Utils
    # Merges two hashes, summing the numeric values of corresponding keys.
    #
    # @param base_hash [Hash] The base hash to which the additional hash will be merged.
    # @param additional_hash [Hash] The additional hash whose values will be added to the base hash.
    # @return [Hash] A new hash with the summed values.
    #
    # @example
    #   base_hash = { 'key1' => [10, 'tag1'], 'key2' => [20, 'tag2'] }
    #   additional_hash = { 'key1' => [5, 'tag1'], 'key3' => [15, 'tag3'] }
    #   Utils.add_hashes(base_hash, additional_hash)
    #   #=> { 'key1' => [15, 'tag1'], 'key2' => [20, 'tag2'], 'key3' => [15, 'tag3'] }
    def self.add_hashes(base_hash, additional_hash)
      base_hash.merge(additional_hash) do |_key, old_value, new_value|
        summed_number = old_value[0] + new_value[0]
        [summed_number, old_value[1]]
      end
    end

    # Converts a timestamp to a DateTime object.
    #
    # @param timestamp [Integer] the timestamp to convert
    # @return [DateTime] the converted DateTime object
    def self.convert_to_datetime(timestamp)
      Time.at(timestamp).to_datetime
    end

    # Provides predefined date ranges for filtering.
    #
    # @return [Hash] A hash containing predefined date ranges.
    #
    # @example Get the predefined date ranges
    #   Utils.date_ranges
    #
    # @note The method returns a hash with predefined date ranges for 'today', 'yesterday', 'week', and 'month'.
    def self.date_ranges
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
    #   Utils.format_item(item)
    #
    # @note The method formats the item's ID, start time, end time, tag, and notes.
    def self.format_item(item)
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
    #   Utils.valid_date_format?('2021-10-01') # => true
    #
    # @note The method validates the date format for single dates and date ranges.
    def self.valid_date_format?(date_string)
      date_format_single = /^\d{4}-\d{2}-\d{2}$/
      date_format_range = /^\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}$/

      date_string.match?(date_format_single) || date_string.match?(date_format_range)
    end

    # Assigns attributes to an iCalendar event.
    #
    # @param event [Icalendar::Event] the event object
    # @param item [Array] the item containing event details
    def self.assign_event_attributes(event, item)
      dtstart = convert_to_datetime(item[1])
      dtend = convert_to_datetime(item[2] || TimeHelper.current_timestamp)

      event.dtstart     = dtstart
      event.dtend       = dtend
      event.summary     = item[3]
      event.description = item[4]
      event.ip_class    = 'PRIVATE'
    end

    # Creates an iCalendar event from the given item.
    #
    # @param item [Array] the item containing event details
    # @return [Icalendar::Event] the created event
    def self.create_event(item)
      event = Icalendar::Event.new
      assign_event_attributes(event, item)
      event
    end

    # Creates an iCalendar object and adds events to it.
    #
    # @param items [Array] the items containing event details
    # @return [Icalendar::Calendar] the populated iCalendar object
    def self.add_events(items)
      cal = Icalendar::Calendar.new
      items.each do |item|
        event = create_event(item)
        cal.add_event(event)
      end
      cal.publish
      cal
    end
  end
end
