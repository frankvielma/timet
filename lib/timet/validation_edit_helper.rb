# frozen_string_literal: true

require_relative 'time_helper'
module Timet
  # Validates and updates a specific field of an item based on certain conditions.
  # If the field is 'start' or 'end', it checks and updates the value accordingly.
  # Otherwise, it directly updates the field with the new value.
  module ValidationEditHelper
    TIME_FIELDS = %w[start end].freeze

    def validate_and_update(item, field, new_value)
      id = item[0]

      if TIME_FIELDS.include?(field)
        validate_and_update_time_field(item, field, new_value, id)
      else
        @db.update_item(id, field, new_value)
      end
    end

    private

    def validate_and_update_time_field(item, field, new_value, id)
      return if new_value.nil?

      process_and_update_time_field(item, field, new_value, id)
    end

    def process_and_update_time_field(item, field, new_value, id)
      formatted_value = format_time_string(new_value)
      new_date = update_time_field(item, field, formatted_value)
      new_value_epoch = new_date.to_i

      if valid_time_value?(item, field, new_value_epoch, id)
        @db.update_item(id, field, new_value_epoch)
      else
        puts "\u001b[31mInvalid date: #{new_date}\033[0m"
      end
    end

    def format_time_string(new_value)
      Timet::TimeHelper.format_time_string(new_value)
    end

    def update_time_field(item, field, formatted_value)
      field_index = Timet::Application::FIELD_INDEX[field]
      timestamp = item[field_index]
      current_time = Time.at(timestamp || TimeHelper.current_timestamp).to_s.split
      current_time[1] = formatted_value
      DateTime.strptime(current_time.join(' '), '%Y-%m-%d %H:%M:%S %z').to_time
    end

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

    def fetch_item_start(item)
      item[Timet::Application::FIELD_INDEX['start']]
    end

    def fetch_item_end(item)
      item[Timet::Application::FIELD_INDEX['end']] || TimeHelper.current_timestamp
    end

    def fetch_item_before_end(id, item_start)
      @db.find_item(id - 1)&.dig(Timet::Application::FIELD_INDEX['end']) || item_start
    end

    def fetch_item_after_start(id)
      @db.find_item(id + 1)&.dig(Timet::Application::FIELD_INDEX['start']) || TimeHelper.current_timestamp
    end
  end
end