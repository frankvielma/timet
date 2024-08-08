# frozen_string_literal: true

require "date"
require "byebug"
module Timet
  # This class represents a report of tracked time.
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
        start_time = format_time(item[1])
        end_time = format_time(item[2]) || "-".rjust(21)
        duration = calculate_duration(item[1], item[2])
        puts format_table_row(item[0], item[3][0..5], start_time, end_time, duration)
      end
      puts format_table_separator
      total
    end

    private

    def total
      total = @items.map do |item|
        calculate_duration(item[1], item[2])
      end.sum
      puts "|                                                        Total:  | #{@db.seconds_to_hms(total).rjust(10)} |"
      puts format_table_separator
    end

    def format_table_header
      puts "Tracked time report:"
      puts format_table_separator
      puts "| Id    | Task   | Start Time            | End Time              | Duration   |"
      puts format_table_separator
    end

    def format_table_separator
      "+-------+--------+-----------------------+-----------------------+------------+"
    end

    def format_table_row(id, task, start_time, end_time, duration)
      "| #{id.to_s.rjust(5)} | #{task.ljust(6)} | #{start_time} | #{end_time} | #{@db.seconds_to_hms(duration).rjust(10)} |"
    end

    def format_time(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).strftime("%Y-%m-%d %H:%M:%S").ljust(21)
    end

    def calculate_duration(start_time, end_time)
      return Time.now - Time.at(start_time) if end_time.nil?

      Time.at(end_time) - Time.at(start_time)
    end

    def filter_items(filter)
      case filter
      when "today"
        filter_by_date(Date.today)
      when "yesterday"
        filter_by_date(Date.today - 1)
      when "week"
        filter_by_date_range(Date.today - 7, Date.today + 1)
      else
        puts "Invalid filter. Supported filters: today, yesterday, week"
        []
      end
    end

    def filter_by_date(date)
      start_time = date.to_time.to_i
      end_time = (date + 1).to_time.to_i
      @db.execute_sql("select * from items where start >= #{start_time} and start < #{end_time}")
    end

    def filter_by_date_range(start_date, end_date)
      start_time = start_date.to_time.to_i
      end_time = end_date.to_time.to_i
      @db.execute_sql("select * from items where start >= #{start_time} and start < #{end_time}")
    end
  end
end
