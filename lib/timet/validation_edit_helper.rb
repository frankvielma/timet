# frozen_string_literal: true

require_relative 'time_helper'
require_relative 'item_data_helper'
require_relative 'time_update_helper'
require_relative 'time_validation_helper'

module Timet
  # Validates and updates a specific field of an item based on certain conditions.
  # If the field is 'start' or 'end', it checks and updates the value accordingly.
  # Otherwise, it directly updates the field with the new value.
  module ValidationEditHelper
    include TimeValidationHelper

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

      new_datetime = determine_and_create_datetime(item, field, time_str, start_timestamp, parsed_time_component)

      new_epoch = new_datetime.to_i

      perform_validation(
        item: item,
        field: field,
        new_epoch: new_epoch,
        start_timestamp: start_timestamp,
        end_timestamp: end_timestamp,
        new_datetime: new_datetime
      )

      new_epoch
    end

    protected

    # Validates that the new start time does not collide with existing entries.
    #
    # @param item [Array] The item being modified.
    # @param new_start_epoch [Integer] The new start time in epoch format.
    #
    # @raise [ArgumentError] If the new start time collides with a previous or next item.
    def validate_collision(item, new_start_epoch)
      item_id = item[0]
      prev_item = @db.find_item(item_id - 1)
      next_item = @db.find_item(item_id + 1)

      if prev_item && new_start_epoch < prev_item[2]
        raise ArgumentError,
              'New start time collides with previous item (ends at ' \
              "#{Time.at(prev_item[2]).strftime('%Y-%m-%d %H:%M:%S')})."
      end

      return unless next_item && new_start_epoch > next_item[1]

      raise ArgumentError,
            "New start time collides with next item (starts at #{Time.at(next_item[1]).strftime('%Y-%m-%d %H:%M:%S')})."
    end

    private

    # Determines the base date and time, creates a new datetime object, and adjusts it if necessary.
    #
    # @param item [Array] The item being modified.
    # @param field [String] The field being validated ('start' or 'end').
    # @param time_str [String, nil] The new time string.
    # @param start_timestamp [Integer, nil] The start timestamp of the item.
    # @param parsed_time_component [Time] The parsed time component.
    #
    # @return [Time] The new datetime object.
    def determine_and_create_datetime(item, field, _time_str, start_timestamp, parsed_time_component)
      base_date_time = determine_base_date_time(item, field, start_timestamp)
      new_datetime = create_new_datetime(base_date_time, parsed_time_component)
      adjust_end_datetime(field, start_timestamp, new_datetime)
    end

    # Performs the appropriate validation based on the field.
    #
    # @param options [Hash] A hash containing the parameters for validation.
    # @option options [Array] :item The item being modified.
    # @option options [String] :field The field being validated ('start' or 'end').
    # @option options [Integer] :new_epoch The new time in epoch format.
    # @option options [Integer, nil] :start_timestamp The start timestamp of the item.
    # @option options [Integer, nil] :end_timestamp The end timestamp of the item.
    # @option options [Time] :new_datetime The new datetime object.
    def perform_validation(options)
      item = options[:item]
      field = options[:field]
      new_epoch = options[:new_epoch]
      start_timestamp = options[:start_timestamp]
      end_timestamp = options[:end_timestamp]
      new_datetime = options[:new_datetime]

      validate_future_date(new_datetime)

      if field == 'end'
        validate_end_time(new_epoch, start_timestamp, new_datetime)
      elsif field == 'start' # If start is being updated
        validate_collision(item, new_epoch)
        validate_start_time(new_epoch, end_timestamp, new_datetime) if end_timestamp
      end
    end
  end
end
