# frozen_string_literal: true

require_relative 'time_helper'
require_relative 'time_validation_helper'

module Timet
  # Handles validation and editing of time tracking items.
  class ValidationEditor
    include TimeValidationHelper

    TIME_FIELDS = %w[start end].freeze

    def initialize(item, db)
      @item = item
      @db = db
    end

    def update(field, new_value)
      case field
      when 'notes' then update_notes(new_value)
      when 'tag' then update_tag(new_value)
      when 'start' then update_start_time(new_value)
      when 'end' then update_end_time(new_value)
      else raise ArgumentError, "Invalid field: #{field}"
      end
      @item
    end

    private

    def update_notes(value)
      @item[4] = value
    end

    def update_tag(value)
      @item[3] = value
    end

    def update_start_time(time_str)
      @item[1] = process_start_time(time_str)
    end

    def update_end_time(time_str)
      @item[2] = process_end_time(time_str)
    end

    def process_start_time(time_str)
      return @item[1] if time_str.nil? || time_str.strip.empty?

      build_and_validate_start_time(time_str)
    end

    def process_end_time(time_str)
      return @item[2] if time_str.nil? || time_str.strip.empty?

      build_and_validate_end_time(time_str)
    end

    def start_timestamp
      @item[1]
    end

    def end_timestamp
      @item[2]
    end

    def item_id
      @item[0]
    end

    def build_and_validate_start_time(time_str)
      new_epoch = parse_to_epoch(time_str, :start)
      run_start_validations(new_epoch)
      new_epoch
    end

    def build_and_validate_end_time(time_str)
      new_epoch = parse_to_epoch(time_str, :end)
      run_end_validations(new_epoch)
      new_epoch
    end

    def parse_to_epoch(time_str, field_type)
      parsed_time = parse_time_string(time_str)
      base = determine_base_date_time(@item, field_type.to_s, start_timestamp)
      new_dt = create_new_datetime(base, parsed_time)
      adjusted_dt = field_type == :end ? adjust_end_datetime_for_next_day(start_timestamp, new_dt) : new_dt
      adjusted_dt.to_i
    end

    def run_start_validations(new_epoch)
      validate_start_not_future(new_epoch)
      validate_start_collision_with_previous(new_epoch)
      validate_start_collision_with_next(new_epoch)
      validate_start_before_end(new_epoch)
    end

    def run_end_validations(new_epoch)
      validate_end_not_future(new_epoch)
      validate_end_collision_with_previous(new_epoch)
      validate_end_collision_with_next(new_epoch)
      validate_end_after_start(new_epoch)
    end

    def validate_start_not_future(new_epoch)
      validate_future_date(Time.at(new_epoch))
    end

    def validate_end_not_future(new_epoch)
      validate_future_date(Time.at(new_epoch))
    end

    def validate_start_collision_with_previous(new_epoch)
      prev = @db.find_item(item_id - 1)
      return unless prev

      prev_end = prev[2]
      return unless new_epoch < prev_end

      raise ArgumentError, "New start time collides with previous item (ends at #{format_time(prev_end)})."
    end

    def validate_end_collision_with_previous(new_epoch)
      prev = @db.find_item(item_id - 1)
      return unless prev

      prev_end = prev[2]
      return unless new_epoch < prev_end

      raise ArgumentError, "New end time collides with previous item (ends at #{format_time(prev_end)})."
    end

    def validate_start_collision_with_next(new_epoch)
      next_item = @db.find_item(item_id + 1)
      return unless next_item

      next_start = next_item[1]
      return unless new_epoch >= next_start

      raise ArgumentError, "New start time collides with next item (starts at #{format_time(next_start)})."
    end

    def validate_end_collision_with_next(new_epoch)
      next_item = @db.find_item(item_id + 1)
      return unless next_item

      next_start = next_item[1]
      return unless new_epoch > next_start

      raise ArgumentError, "New end time collides with next item (starts at #{format_time(next_start)})."
    end

    def format_time(epoch)
      Time.at(epoch).strftime('%Y-%m-%d %H:%M:%S')
    end

    def validate_start_before_end(new_epoch)
      return unless end_timestamp

      new_dt = Time.at(new_epoch)
      validate_start_time(new_epoch, end_timestamp, new_dt)
    end

    def validate_end_after_start(new_epoch)
      new_dt = Time.at(new_epoch)
      validate_end_time(new_epoch, start_timestamp, new_dt)
    end
  end
end
