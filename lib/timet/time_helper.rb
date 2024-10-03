# frozen_string_literal: true

module Timet
  # This module provides helper functions for working with time and dates.
  # It includes methods for:
  # - formatting timestamps into a specific format
  # - calculating the duration between two timestamps
  # - converting a Date object to a timestamp
  module TimeHelper
    def self.format_time(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).strftime('%Y-%m-%d %H:%M:%S')
    end

    def self.timestamp_to_date(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).strftime('%Y-%m-%d')
    end

    def self.timestamp_to_time(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).strftime('%H:%M:%S')
    end

    def self.calculate_duration(start_time, end_time)
      end_time = end_time ? Time.at(end_time) : current_timestamp
      (end_time - start_time).to_i
    end

    def self.date_to_timestamp(date)
      date.to_time.to_i
    end

    def self.calculate_end_time(start_date, end_date)
      end_date = end_date ? end_date + 1 : start_date + 1
      date_to_timestamp(end_date)
    end

    def self.extract_date(items, idx)
      current_start_date = items[idx][1]
      date = TimeHelper.timestamp_to_date(current_start_date)

      last_start_date = items[idx - 1][1] if idx.positive?
      date if idx.zero? || date != TimeHelper.timestamp_to_date(last_start_date)
    end

    # Formats a time string into a standard HH:MM:SS format.
    #
    # @param input [String] The input string to format.
    # @return [String] The formatted time string in HH:MM:SS format, or nil if the input is invalid.
    #
    # @example
    #  TimeHelper.format_time_string('123456') # => "12:34:56"
    #  TimeHelper.format_time_string('1234567') # => "12:34:56"
    #  TimeHelper.format_time_string('1234') # => "12:34:00"
    #  TimeHelper.format_time_string('123') # => "12:30:00"
    #  TimeHelper.format_time_string('12') # => "12:00:00"
    #  TimeHelper.format_time_string('1') # => "01:00:00"
    #  TimeHelper.format_time_string('127122') # => nil
    #  TimeHelper.format_time_string('abc') # => nil
    def self.format_time_string(input)
      return nil if input.nil? || input.empty?

      digits = input.gsub(/\D/, '')[0..5]
      return nil if digits.empty?

      hours, minutes, seconds = parse_time_components(digits)
      return nil unless valid_time?(hours, minutes, seconds)

      format('%<hours>02d:%<minutes>02d:%<seconds>02d', hours: hours, minutes: minutes, seconds: seconds)
    end

    def self.parse_time_components(digits)
      padded_digits = case digits.size
                      when 1 then "0#{digits}0000"
                      when 2 then "#{digits}0000"
                      when 3 then "#{digits}000"
                      when 4 then "#{digits}00"
                      else digits.ljust(6, '0')
                      end

      padded_digits.scan(/.{2}/).map(&:to_i)
    end

    def self.valid_time?(hours, minutes, seconds)
      hours < 24 && minutes < 60 && seconds < 60
    end

    def self.current_timestamp
      Time.now.utc.to_i
    end
  end
end
