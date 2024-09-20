# frozen_string_literal: true

require "date"
require "csv"
require_relative "time_helper"
require_relative "status_helper"

module Timet
  # The TimeReport class is responsible for displaying a report of tracked time
  # entries. It allows filtering the report by time periods (today, yesterday,
  # week) and displays a formatted table with the relevant information.
  class TimeReport
    attr_reader :db, :items, :filename

    def initialize(db, filter, tag, csv)
      @db = db
      @filename = csv
      @items = filter ? filter_items(filter, tag) : @db.all_items
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

    def row(item)
      format_table_header
      display_time_entry(item)
      puts format_table_separator
      total
    end

    def export_sheet
      header = %w[ID Start End Tag]

      CSV.open("#{filename}.csv", "w") do |csv|
        csv << header

        items.each do |row|
          # Convert start and end times from timestamps to ISO 8601 format
          start_time = Time.at(row[1]).strftime("%Y-%m-%d %H:%M:%S")
          end_time = Time.at(row[2]).strftime("%Y-%m-%d %H:%M:%S")

          # Write the row with formatted times
          csv << [row[0], start_time, end_time, row[3]]
        end
      end
    end

    private

    def display_time_entry(item)
      return puts "Missing time entry data." unless item

      id, start_time_value, end_time_value, tag_name = item
      duration = TimeHelper.calculate_duration(start_time_value, end_time_value)
      start_time = TimeHelper.format_time(start_time_value)
      end_time = TimeHelper.format_time(end_time_value) || "-".rjust(19)
      puts format_table_row(id, tag_name[0..5], start_time, end_time, duration)
    end

    def total
      total = @items.map do |item|
        TimeHelper.calculate_duration(item[1], item[2])
      end.sum
      puts "|#{" " * 52}\033[94mTotal:  | #{@db.seconds_to_hms(total).rjust(10)} |\033[0m"
      puts format_table_separator
    end

    def format_table_header
      header = <<~TABLE
        Tracked time report:
        #{format_table_separator}
        \033[32m| Id    | Tag    | Start Time          | End Time            | Duration   |\033[0m
        #{format_table_separator}
      TABLE
      puts header
    end

    def format_table_separator
      "+-------+--------+---------------------+---------------------+------------+"
    end

    def format_table_row(*row)
      id, tag, start_time, end_time, duration = row
      "| #{id.to_s.rjust(5)} | #{tag.ljust(6)} | #{start_time} | #{end_time} | " \
        "#{@db.seconds_to_hms(duration).rjust(10)} |"
    end

    def filter_items(filter, tag)
      today = Date.today
      case filter
      when "today", "t"
        filter_by_date_range(today, nil, tag)
      when "yesterday", "y"
        filter_by_date_range(today - 1, nil, tag)
      when "week", "w"
        filter_by_date_range(today - 7, today + 1, tag)
      when "month", "m"
        filter_by_date_range(today - 30, today + 1, tag)
      else
        puts "Invalid filter. Supported filters: today, yesterday, week"
        []
      end
    end

    def filter_by_date_range(start_date, end_date = nil, tag = nil)
      start_time = TimeHelper.date_to_timestamp(start_date)
      end_time = TimeHelper.calculate_end_time(start_date, end_date)
      query = "start >= #{start_time} and start < #{end_time} and tag like '%#{tag}%'"
      @db.execute_sql(
        "select * from items where #{query} ORDER BY id DESC"
      )
    end
  end
end
