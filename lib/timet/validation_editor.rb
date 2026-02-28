# frozen_string_literal: true

require 'time'
require_relative 'time_helper'

module Timet
  # Helper module containing validation logic for time tracking items.
  module TimeValidationHelpers
    module_function

    def adjust_end_datetime_for_next_day(start_timestamp, new_datetime)
      return new_datetime unless start_timestamp && (new_datetime.to_i <= start_timestamp)

      new_datetime + (24 * 60 * 60)
    end

    def create_new_datetime(base_date_time, parsed_time_component)
      Time.new(
        base_date_time.year,
        base_date_time.month,
        base_date_time.day,
        parsed_time_component.hour,
        parsed_time_component.min,
        parsed_time_component.sec,
        base_date_time.utc_offset
      )
    end

    def determine_start_base_date_time(start_timestamp)
      start_timestamp ? Time.at(start_timestamp) : Time.now
    end

    def determine_end_base_date_time(start_timestamp)
      raise ArgumentError, "Cannot set 'end' time because 'start' time is not set." unless start_timestamp

      Time.at(start_timestamp)
    end

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

    def parse_time_string(time_str)
      Time.parse(time_str)
    rescue ArgumentError
      raise ArgumentError, "Invalid time format: #{time_str}"
    end

    def format_time(epoch)
      Time.at(epoch).strftime('%Y-%m-%d %H:%M:%S')
    end

    def validate_future_date(new_datetime)
      return unless new_datetime > Time.now.getlocal

      raise ArgumentError, "Cannot set time to a future date or time: #{new_datetime.strftime('%Y-%m-%d %H:%M:%S')}"
    end

    def validate_time_difference(earlier_timestamp, later_timestamp)
      return unless (later_timestamp - earlier_timestamp).abs >= 24 * 60 * 60

      raise ArgumentError, 'The difference between start and end time must be less than 24 hours.'
    end

    def validate_end_after_start(new_epoch, ref_timestamp, new_datetime)
      reference_time = Time.at(ref_timestamp)
      formatted_new = new_datetime.strftime('%Y-%m-%d %H:%M:%S')
      formatted_ref = reference_time.strftime('%Y-%m-%d %H:%M:%S')

      return unless new_epoch <= ref_timestamp

      raise ArgumentError, "End time (#{formatted_new}) must be after start time (#{formatted_ref})."
    end

    def validate_start_before_end(new_epoch, ref_timestamp, new_datetime)
      reference_time = Time.at(ref_timestamp)
      formatted_new = new_datetime.strftime('%Y-%m-%d %H:%M:%S')
      formatted_ref = reference_time.strftime('%Y-%m-%d %H:%M:%S')

      return unless new_epoch >= ref_timestamp

      raise ArgumentError, "Start time (#{formatted_new}) must be before end time (#{formatted_ref})."
    end

    def validate_end_time(new_epoch, ref_timestamp, new_datetime)
      validate_end_after_start(new_epoch, ref_timestamp, new_datetime)
      validate_time_difference(ref_timestamp, new_epoch)
    end

    def check_start_before_end(new_epoch, ref_timestamp, new_datetime)
      validate_start_before_end(new_epoch, ref_timestamp, new_datetime)
      validate_time_difference(new_epoch, ref_timestamp)
    end

    def fetch_item_start(item)
      item[Timet::Application::FIELD_INDEX['start']]
    end

    def fetch_item_end(item)
      item[Timet::Application::FIELD_INDEX['end']] || TimeHelper.current_timestamp
    end

    def fetch_item_before_end(db, id, item_start)
      db.find_item(id - 1)&.dig(Timet::Application::FIELD_INDEX['end']) || item_start
    end

    def fetch_item_after_start(db, id)
      db.find_item(id + 1)&.dig(Timet::Application::FIELD_INDEX['start']) || TimeHelper.current_timestamp
    end
  end

  # Handles validation and editing of time tracking items.
  class ValidationEditor
    include TimeValidationHelpers

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
      return @item[1] if time_str.to_s.strip.empty?

      build_and_validate_start_time(time_str)
    end

    def process_end_time(time_str)
      return @item[2] if time_str.to_s.strip.empty?

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
      validate_start_before_item_end(new_epoch)
    end

    def run_end_validations(new_epoch)
      validate_end_not_future(new_epoch)
      validate_end_collision_with_previous(new_epoch)
      validate_end_collision_with_next(new_epoch)
      validate_end_after_start_item(new_epoch)
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

    def validate_start_before_item_end(new_epoch)
      end_ts = end_timestamp
      return unless end_ts

      check_start_before_end(new_epoch, end_ts, Time.at(new_epoch))
    end

    def validate_end_after_start_item(new_epoch)
      start_ts = start_timestamp
      validate_end_time(new_epoch, start_ts, Time.at(new_epoch))
    end

    def process_and_update_time_field(item, field, date_value, id)
      formatted_date = TimeHelper.format_time_string(date_value)

      return print_error(date_value) unless formatted_date

      new_date = TimeHelper.update_time_field(item, field, formatted_date)
      new_value_epoch = new_date.to_i

      return @db.update_item(id, field, new_value_epoch) unless invalid_time_value?(item, field, new_value_epoch, id)

      print_error(new_date)
    end

    def print_error(message)
      puts "Invalid date: #{message}".red
    end

    def invalid_time_value?(item, field, new_value_epoch, id)
      is_start = field == 'start'
      item_start = fetch_item_start(item)
      item_end = fetch_item_end(item)
      min_val = is_start ? fetch_item_before_end(@db, id, item_start) : item_start
      max_val = is_start ? item_end : fetch_item_after_start(@db, id)
      !new_value_epoch.between?(min_val, max_val)
    end
  end
end
