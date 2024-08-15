# frozen_string_literal: true

require "date"
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
        display_time_entry(item)
      end
      puts format_table_separator
      total
    end

    private

    def display_time_entry(item)
      start_time = format_time(item[1])
      end_time = format_time(item[2]) || "-".rjust(19)
      duration = calculate_duration(item[1], item[2])
      puts format_table_row(item[0], item[3][0..5], start_time, end_time, duration)
    end

    def total
      total = @items.map do |item|
        calculate_duration(item[1], item[2])
      end.sum
      puts "|                                                    Total:  | #{@db.seconds_to_hms(total).rjust(10)} |"
      puts format_table_separator
    end

    def format_table_header
      puts "Tracked time report:"
      puts format_table_separator
      puts "| Id    | Task   | Start Time          | End Time            | Duration   |"
      puts format_table_separator
    end

    def format_table_separator
      "+-------+--------+---------------------+---------------------+------------+"
    end

    def format_table_row(id, task, start_time, end_time, duration)
      "| #{id.to_s.rjust(5)} | #{task.ljust(6)} | #{start_time} | #{end_time} | " \
        "#{@db.seconds_to_hms(duration).rjust(10)} |"
    end

    def format_time(timestamp)
      return nil if timestamp.nil?

      Time.at(timestamp).strftime("%Y-%m-%d %H:%M:%S").ljust(19)
    end

    def calculate_duration(start_time, end_time)
      start_time = Time.at(start_time)
      end_time = end_time ? Time.at(end_time) : Time.now

      (end_time - start_time).to_i
    end

    def filter_items(filter)
      case filter
      when "today", "t"
        filter_by_date_range(Date.today, nil)
      when "yesterday", "y"
        filter_by_date_range(Date.today - 1, nil)
      when "week", "w"
        filter_by_date_range(Date.today - 7, Date.today + 1)
      else
        puts "Invalid filter. Supported filters: today, yesterday, week"
        []
      end
    end

    def filter_by_date_range(start_date, end_date = nil)
      start_time = start_date.to_time.to_i
      end_time = end_date ? end_date.to_time.to_i : (start_date + 1).to_time.to_i
      @db.execute_sql("select * from items where start >= #{start_time} and start < #{end_time} ORDER BY id DESC")
    end
  end
end
