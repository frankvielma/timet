# frozen_string_literal: true

require_relative 'time_helper'
module Timet
  # Validates and updates a specific field of an item based on certain conditions.
  # If the field is 'start' or 'end', it checks and updates the value accordingly.
  # Otherwise, it directly updates the field with the new value.
  module ValidationEditHelper
    # Constants for time fields.
    TIME_FIELDS = %w[start end].freeze

    # Validates and updates a tracking item's field with a new value.
    #
    # @param item [Array] The tracking item to be updated.
    # @param field [String] The field to be updated.
    # @param new_value [String, nil] The new value to be set for the specified field.
    #
    # @return [Array, nil] The updated tracking item if the update was successful, otherwise nil.
    #
    # @example Validate and update the 'notes' field of a tracking item
    #   validate_and_update(item, 'notes', 'Updated notes')
    #
    # @note The method checks if the field is a time field (start or end) and processes it accordingly.
    # @note If the field is not a time field, it directly updates the field with the new value.
    # @note The method returns the updated tracking item if the update was successful.
    def validate_and_update(item, field, new_value)
      return if new_value.nil?

      id = item[0]

      if TIME_FIELDS.include?(field)
        process_and_update_time_field(item, field, new_value, id)
      else
        @db.update_item(id, field, new_value)
      end

      @db.find_item(id)
    end

    private

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
    def process_and_update_time_field(item, field, date_value, id)
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
      puts "\u001b[31mInvalid date: #{message}\033[0m"
    end

    # Updates a time field (start or end) of a tracking item with a formatted date value.
    #
    # @param item [Array] The tracking item to be updated.
    # @param field [String] The time field to be updated.
    # @param formatted_value [String] The formatted date value.
    #
    # @return [Time] The updated time value.
    #
    # @example Update the 'start' field of a tracking item with a formatted date value
    #   update_time_field(item, 'start', '2023-10-01 12:00:00')
    def update_time_field(item, field, formatted_value)
      field_index = Timet::Application::FIELD_INDEX[field]
      timestamp = item[field_index]
      current_time = Time.at(timestamp || TimeHelper.current_timestamp).to_s.split
      current_time[1] = formatted_value
      DateTime.strptime(current_time.join(' '), '%Y-%m-%d %H:%M:%S %z').to_time
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
    def valid_time_value?(item, field, new_value_epoch, id)
      item_start = fetch_item_start(item)
      item_end = fetch_item_end(item)
      item_before_end = fetch_item_before_end(id, item_start)
      item_after_start = fetch_item_after_start(id)

      if field == 'start'
        new_value_epoch >= item_before_end && new_value_epoch <= item_end
      else
        new_value_epoch >= item_start && new_value_epoch <= item_after_start
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
