# frozen_string_literal: true

# This module provides helper functions for working with time and dates.
# It includes methods for:
# - formatting timestamps into a specific format
# - calculating the duration between two timestamps
# - converting a Date object to a timestamp
module TimeHelper
  def self.format_time(timestamp)
    timestamp ? Time.at(timestamp).strftime("%Y-%m-%d %H:%M:%S").ljust(19) : ""
  end

  def self.calculate_duration(start_time, end_time)
    start_time = Time.at(start_time)
    end_time = end_time ? Time.at(end_time) : Time.now

    (end_time - start_time).to_i
  end

  def self.date_to_timestamp(date)
    date.to_time.to_i
  end

  def self.calculate_end_time(start_date, end_date)
    end_date ||= start_date + 1
    date_to_timestamp(end_date)
  end
end
