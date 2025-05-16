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
      return unless new_datetime > Time.now

      raise ArgumentError, "Cannot set time to a future date: #{new_datetime.strftime('%Y-%m-%d %H:%M:%S')}"
    end

    # Validates that the difference between two timestamps is less than 24 hours.
    #
    # @param timestamp1 [Integer] The first timestamp.
    # @param timestamp2 [Integer] The second timestamp.
    #
    # @raise [ArgumentError] If the difference is >= 24 hours.
    def validate_time_difference(timestamp1, timestamp2)
      return unless (timestamp2 - timestamp1).abs >= 24 * 60 * 60

      raise ArgumentError, 'The difference between start and end time must be less than 24 hours.'
    end
    private :validate_time_difference

    # Validates the time order (start before end, end after start).
    #
    # @param new_epoch [Integer] The new time in epoch format.
    # @param reference_timestamp [Integer] The reference timestamp (start or end).
    # @param new_datetime [Time] The new datetime object.
    # @param field [String] The field being validated ('start' or 'end').
    #
    # @raise [ArgumentError] If the time order is invalid.
    def validate_time_order(new_epoch, reference_timestamp, new_datetime, field)
      case field
      when 'end'
        if new_epoch <= reference_timestamp
          raise ArgumentError,
                "End time (#{new_datetime.strftime('%Y-%m-%d %H:%M:%S')}) must be after start time " \
                "(#{Time.at(reference_timestamp).strftime('%Y-%m-%d %H:%M:%S')})."
        end
      when 'start'
        if new_epoch >= reference_timestamp
          raise ArgumentError,
                "Start time (#{new_datetime.strftime('%Y-%m-%d %H:%M:%S')}) must be before end time " \
                "(#{Time.at(reference_timestamp).strftime('%Y-%m-%d %H:%M:%S')})."
        end
      end
    end
    private :validate_time_order

    # Validates the end time against the start time.
    #
    # @param new_epoch [Integer] The new end time in epoch format.
    # @param start_timestamp [Integer] The start timestamp of the item.
    # @param new_datetime [Time] The new datetime object.
    #
    # @raise [ArgumentError] If the end time is not after the start time or the difference is >= 24 hours.
    def validate_end_time(new_epoch, start_timestamp, new_datetime)
      validate_time_order(new_epoch, start_timestamp, new_datetime, 'end')
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
      validate_time_order(new_epoch, end_timestamp, new_datetime, 'start')
      validate_time_difference(new_epoch, end_timestamp)
    end
  end
end
