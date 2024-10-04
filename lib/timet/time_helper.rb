# frozen_string_literal: true

module Timet
  # This module provides helper functions for working with time and dates.
  # It includes methods for:
  # - formatting timestamps into a specific format
  # - calculating the duration between two timestamps
  # - converting a Date object to a timestamp
  module TimeHelper
    # Formats a timestamp into a specific format.
    #
    # @param timestamp [Integer] The timestamp to format.
    # @return [String, nil] The formatted time string in 'YYYY-MM-DD HH:MM:SS' format, or nil if the timestamp is nil.
    #
    # @example Format a timestamp
    #   TimeHelper.format_time(1633072800) # => '2021-10-01 12:00:00'
    def self.format_time(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).strftime('%Y-%m-%d %H:%M:%S')
    end

    # Converts a timestamp to a date string.
    #
    # @param timestamp [Integer] The timestamp to convert.
    # @return [String, nil] The date string in 'YYYY-MM-DD' format, or nil if the timestamp is nil.
    #
    # @example Convert a timestamp to a date string
    #   TimeHelper.timestamp_to_date(1633072800) # => '2021-10-01'
    def self.timestamp_to_date(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).strftime('%Y-%m-%d')
    end

    # Converts a timestamp to a time string.
    #
    # @param timestamp [Integer] The timestamp to convert.
    # @return [String, nil] The time string in 'HH:MM:SS' format, or nil if the timestamp is nil.
    #
    # @example Convert a timestamp to a time string
    #   TimeHelper.timestamp_to_time(1633072800) # => '12:00:00'
    def self.timestamp_to_time(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).strftime('%H:%M:%S')
    end

    # Calculates the duration between two timestamps.
    #
    # @param start_time [Integer] The start timestamp.
    # @param end_time [Integer, nil] The end timestamp. If nil, the current timestamp is used.
    # @return [Integer] The duration in seconds.
    #
    # @example Calculate the duration between two timestamps
    #   TimeHelper.calculate_duration(1633072800, 1633076400) # => 3600
    def self.calculate_duration(start_time, end_time)
      end_time = end_time ? Time.at(end_time) : current_timestamp
      (end_time - start_time).to_i
    end

    # Converts a Date object to a timestamp.
    #
    # @param date [Date] The Date object to convert.
    # @return [Integer] The timestamp.
    #
    # @example Convert a Date object to a timestamp
    #   TimeHelper.date_to_timestamp(Date.new(2021, 10, 1)) # => 1633072800
    def self.date_to_timestamp(date)
      date.to_time.to_i
    end

    # Calculates the end time based on the start date and end date.
    #
    # @param start_date [Date] The start date.
    # @param end_date [Date, nil] The end date. If nil, the start date + 1 day is used.
    # @return [Integer] The end timestamp.
    #
    # @example Calculate the end time
    #   TimeHelper.calculate_end_time(Date.new(2021, 10, 1), Date.new(2021, 10, 2)) # => 1633159200
    def self.calculate_end_time(start_date, end_date)
      end_date = end_date ? end_date + 1 : start_date + 1
      date_to_timestamp(end_date)
    end

    # Extracts the date from a list of items based on the index.
    #
    # @param items [Array] The list of items.
    # @param idx [Integer] The index of the current item.
    # @return [String, nil] The date string in 'YYYY-MM-DD' format, or nil if the date is the same as the previous item.
    #
    # @example Extract the date from a list of items
    #   items = [[1, 1633072800], [2, 1633159200]]
    #   TimeHelper.extract_date(items, 1) # => '2021-10-02'
    def self.extract_date(items, idx)
      current_start_date = items[idx][1]
      date = TimeHelper.timestamp_to_date(current_start_date)

      last_start_date = items[idx - 1][1] if idx.positive?
      date if idx.zero? || date != TimeHelper.timestamp_to_date(last_start_date)
    end

    # Formats a time string into a standard HH:MM:SS format.
    #
    # @param input [String] The input string to format.
    # @return [String, nil] The formatted time string in HH:MM:SS format, or nil if the input is invalid.
    #
    # @example Format a time string
    #   TimeHelper.format_time_string('123456') # => "12:34:56"
    #   TimeHelper.format_time_string('1234567') # => "12:34:56"
    #   TimeHelper.format_time_string('1234') # => "12:34:00"
    #   TimeHelper.format_time_string('123') # => "12:30:00"
    #   TimeHelper.format_time_string('12') # => "12:00:00"
    #   TimeHelper.format_time_string('1') # => "01:00:00"
    #   TimeHelper.format_time_string('127122') # => nil
    #   TimeHelper.format_time_string('abc') # => nil
    def self.format_time_string(input)
      return nil if input.nil? || input.empty?

      digits = input.gsub(/\D/, '')[0..5]
      return nil if digits.empty?

      hours, minutes, seconds = parse_time_components(digits)
      return nil unless valid_time?(hours, minutes, seconds)

      format('%<hours>02d:%<minutes>02d:%<seconds>02d', hours: hours, minutes: minutes, seconds: seconds)
    end

    # Parses time components from a string of digits.
    #
    # @param digits [String] The string of digits to parse.
    # @return [Array] An array containing the hours, minutes, and seconds.
    #
    # @example Parse time components
    #   TimeHelper.parse_time_components('123456') # => [12, 34, 56]
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

    # Validates the time components.
    #
    # @param hours [Integer] The hours component.
    # @param minutes [Integer] The minutes component.
    # @param seconds [Integer] The seconds component.
    # @return [Boolean] True if the time components are valid, otherwise false.
    #
    # @example Validate time components
    #   TimeHelper.valid_time?(12, 34, 56) # => true
    #   TimeHelper.valid_time?(25, 34, 56) # => false
    def self.valid_time?(hours, minutes, seconds)
      hours < 24 && minutes < 60 && seconds < 60
    end

    # Returns the current timestamp.
    #
    # @return [Integer] The current timestamp.
    #
    # @example Get the current timestamp
    #   TimeHelper.current_timestamp
    def self.current_timestamp
      Time.now.utc.to_i
    end
  end
end
