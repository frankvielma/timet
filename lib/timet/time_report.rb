# frozen_string_literal: true

require 'date'
require 'csv'
require_relative 'time_helper'
require_relative 'status_helper'

module Timet
  # The TimeReport class is responsible for displaying a report of tracked time
  # entries. It allows filtering the report by time periods and displays
  # a formatted table with the relevant information.
  class TimeReport
    attr_reader :db, :items, :filename

    def initialize(db, filter = nil, tag = nil, csv = nil)
      @db = db
      @filename = csv
      @filter = formatted_filter(filter)
      @items = filter ? filter_items(@filter, tag) : @db.all_items
    end

    def display
      return puts 'No tracked time found for the specified filter.' if items.empty?

      format_table_header
      items.each_with_index do |item, idx|
        date = TimeHelper.extract_date(items, idx)
        display_time_entry(item, date)
      end
      puts format_table_separator
      total
    end

    def show_row(item)
      format_table_header
      display_time_entry(item)
      puts format_table_separator
      total
    end

    def export_sheet
      CSV.open("#{filename}.csv", 'w') do |csv|
        csv << %w[ID Start End Tag Notes]

        items.each do |id, start_time, end_time, tags, notes|
          csv << [
            id,
            TimeHelper.format_time(start_time),
            TimeHelper.format_time(end_time),
            tags,
            notes
          ]
        end
      end
    end

    private

    def display_time_entry(item, date = nil)
      return puts 'Missing time entry data.' unless item

      id, start_time_value, end_time_value, tag_name, notes = item
      duration = TimeHelper.calculate_duration(start_time_value, end_time_value)
      start_time = TimeHelper.format_time(start_time_value)
      end_time = TimeHelper.format_time(end_time_value) || '- -'
      start_date = date.nil? ? ' ' * 10 : date
      puts format_table_row(id, tag_name[0..5], start_date, start_time, end_time, duration, notes)
    end

    def total
      total = @items.map do |item|
        TimeHelper.calculate_duration(item[1], item[2])
      end.sum
      puts "|#{' ' * 43}\033[94mTotal:  | #{@db.seconds_to_hms(total).rjust(8)} |\033[0m                          |"
      puts format_table_separator
    end

    def format_table_header
      header = <<~TABLE
        Tracked time report \u001b[31m[#{@filter}]\033[0m:
        #{format_table_separator}
        \033[32m| Id    | Date       | Tag    | Start    | End      | Duration | Notes                    |\033[0m
        #{format_table_separator}
      TABLE
      puts header
    end

    def format_table_separator
      '+-------+------------+--------+----------+----------+----------+--------------------------+'
    end

    def format_table_row(*row)
      id, tag, start_date, start_time, end_time, duration, notes = row
      "| #{id.to_s.rjust(5)} | #{start_date} | #{tag.ljust(6)} | #{start_time.split[1]} | " \
        "#{end_time.split[1].rjust(8)} | #{@db.seconds_to_hms(duration).rjust(8)} | #{format_notes(notes)}  |"
    end

    def format_notes(notes)
      return ' ' * 23 if notes.nil?

      notes = "#{notes.slice(0, 20)}..." if notes.length > 20
      notes.ljust(23)
    end

    def filter_items(filter, tag)
      if date_ranges.key?(filter)
        start_date, end_date = date_ranges[filter]
        filter_by_date_range(start_date, end_date, tag)
      else
        puts 'Invalid filter. Supported filters: today, yesterday, week, month'
        []
      end
    end

    def date_ranges
      today = Date.today
      {
        'today' => [today, nil],
        'yesterday' => [today - 1, nil],
        'week' => [today - 7, today + 1],
        'month' => [today - 30, today + 1]
      }
    end

    def filter_by_date_range(start_date, end_date = nil, tag = nil)
      start_time = TimeHelper.date_to_timestamp(start_date)
      end_time = TimeHelper.calculate_end_time(start_date, end_date)
      query = "start >= #{start_time} and start < #{end_time} and tag like '%#{tag}%'"
      @db.execute_sql(
        "select * from items where #{query} ORDER BY id DESC"
      )
    end

    def formatted_filter(filter)
      return 'today' if %w[today t].include?(filter)
      return 'yesterday' if %w[yesterday y].include?(filter)
      return 'week' if %w[week w].include?(filter)
      return 'month' if %w[month m].include?(filter)

      'today'
    end
  end
end
