# frozen_string_literal: true

require_relative 'time_helper'
require_relative 'item_data_helper'
require_relative 'time_update_helper'
module Timet
  # Validates and updates a specific field of an item based on certain conditions.
  # If the field is 'start' or 'end', it checks and updates the value accordingly.
  # Otherwise, it directly updates the field with the new value.
  module ValidationEditHelper
    # Constants for time fields.
    TIME_FIELDS = %w[start end].freeze

    # Validates and updates an item's attribute based on the provided field and new value.
    #
    # @param item [Array] The item to be updated.
    # @param field [String] The field to be updated.
    # @param new_value [String] The new value for the field.
    #
    # @return [Array] The updated item.
    #
    # @raise [ArgumentError] If the field is invalid or the new value is invalid.
    def validate_and_update(item, field, new_value)
      case field
      when 'notes'
        item[4] = new_value
      when 'tag'
        item[3] = new_value
      when 'start'
        item[1] = validate_time(item, 'start', new_value)
      when 'end'
        item[2] = validate_time(item, 'end', new_value)
      else
        raise ArgumentError, "Invalid field: #{field}"
      end
      item
    end

    # Validates if a given time string is in a valid format.
    #
    # @param item [Array] The item being modified.
    # @param field [String] The field being validated ('start' or 'end').
    # @param time_str [String, nil] The new time string (e.g., "HH:MM" or "HH:MM:SS").
    #                               If nil or empty, it signifies that the original time should be kept.
    #
    # @return [Integer, nil] The validated time as an integer epoch.
    #                        Returns the original timestamp for the field if time_str is nil/empty.
    #                        Returns nil if the original field was nil and time_str is nil/empty.
    #
    # @raise [ArgumentError] If the time string is not in a valid format.
    def validate_time(item, field, time_str)
      # If time_str is nil or empty, user pressed Enter, meaning no change to this field.
      return field == 'start' ? item[1] : item[2] if time_str.nil? || time_str.strip.empty?

      parsed_time_component = parse_time_string(time_str)

      start_timestamp = item[1]
      end_timestamp = item[2]

      base_date_time = determine_base_date_time(item, field, start_timestamp)
      new_datetime = create_new_datetime(base_date_time, parsed_time_component)

      new_datetime = adjust_end_datetime(field, start_timestamp, new_datetime)

      new_epoch = new_datetime.to_i

      perform_validation(field, new_epoch, start_timestamp, end_timestamp, new_datetime)

      new_epoch
    end

    private

    # Performs the appropriate validation based on the field.
    #
    # @param field [String] The field being validated ('start' or 'end').
    # @param new_epoch [Integer] The new time in epoch format.
    # @param start_timestamp [Integer, nil] The start timestamp of the item.
    # @param end_timestamp [Integer, nil] The end timestamp of the item.
    # @param new_datetime [Time] The new datetime object.
    def perform_validation(field, new_epoch, start_timestamp, end_timestamp, new_datetime)
      if field == 'end'
        validate_end_time(new_epoch, start_timestamp, new_datetime)
      elsif field == 'start' && end_timestamp # If start is being updated and end already exists
        validate_start_time(new_epoch, end_timestamp, new_datetime)
      end
    end

    # Parses the time string and raises an ArgumentError if the format is invalid.
    #
    # @param time_str [String] The time string to parse.
    #
    # @return [Time] The parsed time component.
    #
    # @raise [ArgumentError] If the time string is not in a valid format.
    def parse_time_string(time_str)
      Time.parse(time_str)
    rescue ArgumentError
      raise ArgumentError, "Invalid time format: #{time_str}"
    end

    # Adjusts the end datetime if it's earlier than or same as the start time, assuming it's for the next day.
    #
    # @param field [String] The field being validated ('start' or 'end').
    # @param start_timestamp [Integer, nil] The start timestamp of the item.
    # @param new_datetime [Time] The new datetime object.
    #
    # @return [Time] The adjusted datetime object.
    def adjust_end_datetime(field, start_timestamp, new_datetime)
      # If setting 'end' time and the parsed new_datetime (based on start_date)
      # is earlier than or same as start_time, assume it's for the next calendar day.
      if field == 'end' && start_timestamp && (new_datetime.to_i <= start_timestamp)
        new_datetime += (24 * 60 * 60) # Add one day
      end
      new_datetime
    end

    # Determines the base date and time for creating a new datetime object.
    #
    # @param item [Array] The item being modified.
    # @param field [String] The field being validated ('start' or 'end').
    # @param start_timestamp [Integer, nil] The start timestamp of the item.
    #
    # @return [Time] The base date and time.
    #
    # @raise [ArgumentError] If the field is 'end' and the start timestamp is not set.
    def determine_base_date_time(_item, field, start_timestamp)
      if field == 'start'
        start_timestamp ? Time.at(start_timestamp) : Time.now
      elsif field == 'end'
        # This ensures that start_timestamp is not nil when setting/editing an end time.
        unless start_timestamp
          raise ArgumentError,
                "Cannot set 'end' time because 'start' time is not set."
        end

        Time.at(start_timestamp)
      end
    end

    # Creates a new datetime object based on the base date and parsed time component.
    #
    # @param base_date_time [Time] The base date and time.
    # @param parsed_time_component [Time] The parsed time component.
    #
    # @return [Time] The new datetime object.
    def create_new_datetime(base_date_time, parsed_time_component)
      Time.new(
        base_date_time.year,
        base_date_time.month,
        base_date_time.day,
        parsed_time_component.hour,
        parsed_time_component.min,
        parsed_time_component.sec,
        base_date_time.utc_offset # Preserve timezone context
      )
    end

    # Validates the end time against the start time.
    #
    # @param new_epoch [Integer] The new end time in epoch format.
    # @param start_timestamp [Integer] The start timestamp of the item.
    # @param new_datetime [Time] The new datetime object.
    #
    # @raise [ArgumentError] If the end time is not after the start time or the difference is >= 24 hours.
    def validate_end_time(new_epoch, start_timestamp, new_datetime)
      if new_epoch <= start_timestamp
        raise ArgumentError,
              "End time (#{new_datetime.strftime('%Y-%m-%d %H:%M:%S')}) must be after start time " \
              "(#{Time.at(start_timestamp).strftime('%Y-%m-%d %H:%M:%S')})."
      end
      return unless (new_epoch - start_timestamp) >= 24 * 60 * 60

      raise ArgumentError, 'The difference between start and end time must be less than 24 hours.'
    end

    # Validates the start time against the end time.
    #
    # @param new_epoch [Integer] The new start time in epoch format.
    # @param end_timestamp [Integer] The end timestamp of the item.
    # @param new_datetime [Time] The new datetime object.
    #
    # @raise [ArgumentError] If the start time is not before the end time or the difference is >= 24 hours.
    def validate_start_time(new_epoch, end_timestamp, new_datetime)
      if new_epoch >= end_timestamp
        raise ArgumentError,
              "Start time (#{new_datetime.strftime('%Y-%m-%d %H:%M:%S')}) must be before end time " \
              "(#{Time.at(end_timestamp).strftime('%Y-%m-%d %H:%M:%S')})."
      end
      return unless (end_timestamp - new_epoch) >= 24 * 60 * 60

      raise ArgumentError, 'The difference between start and end time must be less than 24 hours.'
    end
  end
end
