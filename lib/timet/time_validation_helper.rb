# frozen_string_literal: true

require 'time'

module Timet
  # Helper module for time validation logic.
  module TimeValidationHelper
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
    # @param start_timestamp [Integer, nil] The start timestamp of the item.
    # @param new_datetime [Time] The new datetime object.
    #
    # @return [Time] The adjusted datetime object.
    def adjust_end_datetime_for_next_day(start_timestamp, new_datetime)
      return new_datetime unless start_timestamp && (new_datetime.to_i <= start_timestamp)

      new_datetime + (24 * 60 * 60)
    end

    # Determines the base date and time for creating a new datetime object.
    #
    # @param item [Array] The item being modified.
    # @param field [String] The field being validated ('start' or 'end').
    # @param start_timestamp [Integer, nil] The start timestamp of the item.
    #
    # @return [Time] The base date and time.
    #
    # @raise [ArgumentError] If the field is 'end' and the start timestamp is not set or if the field is invalid.
    def determine_base_date_time(_item, field, start_timestamp)
      case field
      when 'start'
        determine_start_base_date_time(start_timestamp)
      when 'end'
        determine_end_base_date_time(start_timestamp)
      else
        raise ArgumentError, "Invalid field: #{field}"
      end
    end

    # Determines the base date and time for the 'start' field.
    #
    # @param start_timestamp [Integer, nil] The start timestamp of the item.
    #
    # @return [Time] The base date and time.
    def determine_start_base_date_time(start_timestamp)
      start_timestamp ? Time.at(start_timestamp) : Time.now
    end
    private :determine_start_base_date_time

    # Determines the base date and time for the 'end' field.
    #
    # @param start_timestamp [Integer, nil] The start timestamp of the item.
    #
    # @return [Time] The base date and time.
    #
    # @raise [ArgumentError] If the start timestamp is not set.
    def determine_end_base_date_time(start_timestamp)
      # This ensures that start_timestamp is not nil when setting/editing an end time.
      raise ArgumentError, "Cannot set 'end' time because 'start' time is not set." unless start_timestamp

      Time.at(start_timestamp)
    end
    private :determine_end_base_date_time

    # Creates a new datetime object based on the parsed time component.
    #
    # @param _base_date_time [Time] The base date and time (not used for date components).
    # @param parsed_time_component [Time] The parsed time component.
    #
    # @return [Time] The new datetime object.
    def create_new_datetime(_base_date_time, parsed_time_component)
      Time.new(
        parsed_time_component.year,
        parsed_time_component.month,
        parsed_time_component.day,
        parsed_time_component.hour,
        parsed_time_component.min,
        parsed_time_component.sec,
        parsed_time_component.utc_offset # Preserve timezone context
      )
    end

    # Validates that the new datetime is not in the future.
    #
    # @param new_datetime [Time] The new datetime object.
    #
    # @raise [ArgumentError] If the new datetime is in the future.
    def validate_future_date(new_datetime)
      # Ensure the new datetime is not in the future relative to the current time.
      return unless new_datetime > Time.now.getlocal

      raise ArgumentError, "Cannot set time to a future date or time: #{new_datetime.strftime('%Y-%m-%d %H:%M:%S')}"
    end

    # Validates that the difference between two timestamps is less than 24 hours.
    #
    # @param earlier_timestamp [Integer] The earlier timestamp.
    # @param later_timestamp [Integer] The later timestamp.
    #
    # @raise [ArgumentError] If the difference is >= 24 hours.
    def validate_time_difference(earlier_timestamp, later_timestamp)
      return unless (later_timestamp - earlier_timestamp).abs >= 24 * 60 * 60

      raise ArgumentError, 'The difference between start and end time must be less than 24 hours.'
    end
    private :validate_time_difference

    # Validates that end time is after start time.
    #
    # @param new_epoch [Integer] The new end time in epoch format.
    # @param start_timestamp [Integer] The start timestamp.
    # @param new_datetime [Time] The new datetime object.
    #
    # @raise [ArgumentError] If the end time is not after the start time.
    def validate_end_time_order(new_epoch, start_timestamp, new_datetime)
      reference_time = Time.at(start_timestamp)
      formatted_new = new_datetime.strftime('%Y-%m-%d %H:%M:%S')
      formatted_ref = reference_time.strftime('%Y-%m-%d %H:%M:%S')

      return unless new_epoch <= start_timestamp

      raise ArgumentError,
            "End time (#{formatted_new}) must be after start time (#{formatted_ref})."
    end
    private :validate_end_time_order

    # Validates that start time is before end time.
    #
    # @param new_epoch [Integer] The new start time in epoch format.
    # @param end_timestamp [Integer] The end timestamp.
    # @param new_datetime [Time] The new datetime object.
    #
    # @raise [ArgumentError] If the start time is not before the end time.
    def validate_start_time_order(new_epoch, end_timestamp, new_datetime)
      reference_time = Time.at(end_timestamp)
      formatted_new = new_datetime.strftime('%Y-%m-%d %H:%M:%S')
      formatted_ref = reference_time.strftime('%Y-%m-%d %H:%M:%S')

      return unless new_epoch >= end_timestamp

      raise ArgumentError,
            "Start time (#{formatted_new}) must be before end time (#{formatted_ref})."
    end
    private :validate_start_time_order

    # Validates the end time against the start time.
    #
    # @param new_epoch [Integer] The new end time in epoch format.
    # @param start_timestamp [Integer] The start timestamp of the item.
    # @param new_datetime [Time] The new datetime object.
    #
    # @raise [ArgumentError] If the end time is not after the start time or the difference is >= 24 hours.
    def validate_end_time(new_epoch, start_timestamp, new_datetime)
      validate_end_time_order(new_epoch, start_timestamp, new_datetime)
      validate_time_difference(start_timestamp, new_epoch)
    end

    # Validates the start time against the end time.
    #
    # @param new_epoch [Integer] The new start time in epoch format.
    # @param end_timestamp [Integer] The end timestamp of the item.
    # @param new_datetime [Time] The new datetime object.
    #
    # @raise [ArgumentError] If the start time is not before the end time or the difference is >= 24 hours.
    def validate_start_time(new_epoch, end_timestamp, new_datetime)
      validate_start_time_order(new_epoch, end_timestamp, new_datetime)
      validate_time_difference(new_epoch, end_timestamp)
    end
  end
end
