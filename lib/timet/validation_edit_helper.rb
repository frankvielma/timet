# frozen_string_literal: true

require_relative 'time_helper'
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

    # Processes and updates a time field (start or end) of a tracking item.
    #
    # @param item [Array] The tracking item to be updated.
    # @param field [String] The time field to be updated.
    # @param date_value [String] The new value for the time field.
    # @param id [Integer] The ID of the tracking item.
    #
    # @return [void] This method does not return a value; it performs side effects such as updating the time field.
    #
    # @note The method formats the date value and checks if it is valid.
    # @note If the date value is valid, it updates the time field with the new value.
    # @note If the date value is invalid, it prints an error message.
    def process_and_update_time_field(*args)
      item, field, date_value, id = args
      formatted_date = TimeHelper.format_time_string(date_value)

      return print_error(date_value) unless formatted_date

      new_date = update_time_field(item, field, formatted_date)
      new_value_epoch = new_date.to_i

      if valid_time_value?(item, field, new_value_epoch, id)
        @db.update_item(id, field, new_value_epoch)
      else
        print_error(new_date)
      end
    end

    # Prints an error message for an invalid date.
    #
    # @param message [String] The error message to be printed.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing an error message.
    #
    # @example Print an error message for an invalid date
    #   print_error('Invalid date: 2023-13-32')
    def print_error(message)
      puts "Invalid date: #{message}".red
    end

    # Updates a time field (start or end) of a tracking item with a formatted date value.
    #
    # @param item [Array] The tracking item to be updated.
    # @param field [String] The time field to be updated.
    # @param new_time [String] The new time value.
    #
    # @return [Time] The updated time value.
    #
    # @example Update the 'start' field of a tracking item with a formatted date value
    #   update_time_field(item, 'start', '11:10:00')
    def update_time_field(item, field, new_time)
      field_index = Timet::Application::FIELD_INDEX[field]
      timestamp = item[field_index]
      edit_time = Time.at(timestamp || item[1]).to_s.split
      edit_time[1] = new_time
      DateTime.strptime(edit_time.join(' '), '%Y-%m-%d %H:%M:%S %z').to_time
    end

    # Validates if a new time value is valid for a specific time field (start or end).
    #
    # @param item [Array] The tracking item to be validated.
    # @param field [String] The time field to be validated.
    # @param new_value_epoch [Integer] The new time value in epoch format.
    # @param id [Integer] The ID of the tracking item.
    #
    # @return [Boolean] Returns true if the new time value is valid, otherwise false.
    #
    # @example Validate a new 'start' time value
    #   valid_time_value?(item, 'start', 1633072800, 1)
    def valid_time_value?(*args)
      item, field, new_value_epoch, id = args
      item_start = fetch_item_start(item)
      item_end = fetch_item_end(item)
      item_before_end = fetch_item_before_end(id, item_start)
      item_after_start = fetch_item_after_start(id)

      if field == 'start'
        new_value_epoch.between?(item_before_end, item_end)
      else
        new_value_epoch.between?(item_start, item_after_start)
      end
    end

    # Fetches the start time of a tracking item.
    #
    # @param item [Array] The tracking item.
    #
    # @return [Integer] The start time in epoch format.
    #
    # @example Fetch the start time of a tracking item
    #   fetch_item_start(item)
    def fetch_item_start(item)
      item[Timet::Application::FIELD_INDEX['start']]
    end

    # Fetches the end time of a tracking item.
    #
    # @param item [Array] The tracking item.
    #
    # @return [Integer] The end time in epoch format.
    #
    # @example Fetch the end time of a tracking item
    #   fetch_item_end(item)
    def fetch_item_end(item)
      item[Timet::Application::FIELD_INDEX['end']] || TimeHelper.current_timestamp
    end

    # Fetches the end time of the tracking item before the current one.
    #
    # @param id [Integer] The ID of the current tracking item.
    # @param item_start [Integer] The start time of the current tracking item.
    #
    # @return [Integer] The end time of the previous tracking item in epoch format.
    #
    # @example Fetch the end time of the previous tracking item
    #   fetch_item_before_end(1, 1633072800)
    def fetch_item_before_end(id, item_start)
      @db.find_item(id - 1)&.dig(Timet::Application::FIELD_INDEX['end']) || item_start
    end

    # Fetches the start time of the tracking item after the current one.
    #
    # @param id [Integer] The ID of the current tracking item.
    #
    # @return [Integer] The start time of the next tracking item in epoch format.
    #
    # @example Fetch the start time of the next tracking item
    #   fetch_item_after_start(1)
    def fetch_item_after_start(id)
      @db.find_item(id + 1)&.dig(Timet::Application::FIELD_INDEX['start']) || TimeHelper.current_timestamp
    end
  end
end
