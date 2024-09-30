# frozen_string_literal: true

module Timet
  # This module provides helper functions for working with time and dates.
  # It includes methods for:
  # - formatting timestamps into a specific format
  # - calculating the duration between two timestamps
  # - converting a Date object to a timestamp
  module TimeHelper
    def self.format_time(timestamp)
      timestamp&.then { |time| Time.at(time).strftime('%Y-%m-%d %H:%M:%S ') }
    end

    def self.timestamp_to_date(timestamp)
      timestamp&.then { |time| Time.at(time).strftime('%Y-%m-%d') }
    end

    def self.timestamp_to_time(timestamp)
      timestamp&.then { |time| Time.at(time).strftime('%H:%M:%S') }
    end

    def self.calculate_duration(start_time, end_time)
      # debugger
      # start_time = Time.at(start_time)
      end_time = end_time ? Time.at(end_time) : current_timestamp
      (end_time - start_time).to_i
    end

    def self.date_to_timestamp(date)
      date.to_time.to_i
    end

    def self.calculate_end_time(start_date, end_date)
      end_date ||= start_date + 1
      date_to_timestamp(end_date)
    end

    def self.extract_date(items, idx)
      current_start_date = items[idx][1]
      date = TimeHelper.timestamp_to_date(current_start_date)

      last_start_date = items[idx - 1][1] if idx.positive?
      date if idx.zero? || date != TimeHelper.timestamp_to_date(last_start_date)
    end

    def self.format_time_string(input)
      return '' if input.nil?

      cleaned_input = input.gsub(/\D/, '')
      cleaned_input = "0#{cleaned_input}" if cleaned_input.size == 1
      padded_input = cleaned_input.ljust(6, '0')
      "#{padded_input[0, 2]}:#{padded_input[2, 2]}:#{padded_input[4, 2]}"
    end

    def self.current_timestamp
      Time.now.utc.to_i
    end
  end
end
