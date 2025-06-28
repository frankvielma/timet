# frozen_string_literal: true

require_relative 'time_helper'
require_relative 'item_data_helper'
require 'date'

module Timet
  # Helper methods for processing and updating time fields.
  module TimeUpdateHelper
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

      new_date = TimeHelper.update_time_field(item, field, formatted_date)
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
      item_start = ItemDataHelper.fetch_item_start(item)
      item_end = ItemDataHelper.fetch_item_end(item)
      item_before_end = ItemDataHelper.fetch_item_before_end(@db, id, item_start)
      item_after_start = ItemDataHelper.fetch_item_after_start(@db, id)

      if field == 'start'
        new_value_epoch.between?(item_before_end, item_end)
      else
        new_value_epoch.between?(item_start, item_after_start)
      end
    end
  end
end
