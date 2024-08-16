# frozen_string_literal: true

require "date"
require_relative "time_helper"
require_relative "status_helper"

module Timet
  # The TimeReport class is responsible for displaying a report of tracked time
  # entries. It allows filtering the report by time periods (today, yesterday,
  # week) and displays a formatted table with the relevant information.
  class TimeReport
    attr_reader :db, :items

    def initialize(db, filter)
      @db = db
      @items = filter ? filter_items(filter) : @db.all_items
    end

    def display
      return puts "No tracked time found for the specified filter." if items.empty?

      format_table_header
      items.each do |item|
        display_time_entry(item)
      end
      puts format_table_separator
      total
    end

    private

    def display_time_entry(item)
      id, start_time_value, end_time_value, task_name = item
      duration = TimeHelper.calculate_duration(start_time_value, end_time_value)
      start_time = TimeHelper.format_time(start_time_value)
      end_time = TimeHelper.format_time(end_time_value) || "-".rjust(19)
      puts format_table_row(id, task_name[0..5], start_time, end_time, duration)
    end

    def total
      total = @items.map do |item|
        TimeHelper.calculate_duration(item[1], item[2])
      end.sum
      puts "|                                                    Total:  | #{@db.seconds_to_hms(total).rjust(10)} |"
      puts format_table_separator
    end

    def format_table_header
      header = <<~TABLE
        Tracked time report:
        #{format_table_separator}
        | Id    | Task   | Start Time          | End Time            | Duration   |
        #{format_table_separator}
      TABLE
      puts header
    end

    def format_table_separator
      "+-------+--------+---------------------+---------------------+------------+"
    end

    def format_table_row(*row)
      id, task, start_time, end_time, duration = row
      "| #{id.to_s.rjust(5)} | #{task.ljust(6)} | #{start_time} | #{end_time} | " \
        "#{@db.seconds_to_hms(duration).rjust(10)} |"
    end

    def filter_items(filter)
      today = Date.today
      case filter
      when "today", "t"
        filter_by_date_range(today, nil)
      when "yesterday", "y"
        filter_by_date_range(today - 1, nil)
      when "week", "w"
        filter_by_date_range(today - 7, today + 1)
      else
        puts "Invalid filter. Supported filters: today, yesterday, week"
        []
      end
    end

    def filter_by_date_range(start_date, end_date = nil)
      start_time = TimeHelper.date_to_timestamp(start_date)
      end_time = TimeHelper.calculate_end_time(start_date, end_date)

      @db.execute_sql("select * from items where start >= #{start_time} and start < #{end_time} ORDER BY id DESC")
    end
  end
end
