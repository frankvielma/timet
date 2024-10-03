# frozen_string_literal: true

require 'date'
require 'csv'
require_relative 'status_helper'
require_relative 'formatter'

module Timet
  # The TimeReport class is responsible for displaying a report of tracked time
  # entries. It allows filtering the report by time periods and displays
  # a formatted table with the relevant information.
  class TimeReport
    include Formatter

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
      file_name = "#{filename}.csv"
      write_csv(file_name)

      puts "The #{file_name} has been exported."
    end

    private

    def write_csv(file_name)
      CSV.open(file_name, 'w') do |csv|
        csv << %w[ID Start End Tag Notes]
        items.each do |item|
          csv << format_item(item)
        end
      end
    end

    def format_item(item)
      id, start_time, end_time, tags, notes = item
      [
        id,
        TimeHelper.format_time(start_time),
        TimeHelper.format_time(end_time),
        tags,
        notes
      ]
    end

    def display_time_entry(item, date = nil)
      return puts 'Missing time entry data.' unless item

      id, start_time_value, end_time_value, tag_name, notes = item
      duration = TimeHelper.calculate_duration(start_time_value, end_time_value)
      start_time = TimeHelper.format_time(start_time_value)
      end_time = TimeHelper.format_time(end_time_value) || '- -'
      start_date = date || (' ' * 10)
      puts format_table_row(id, tag_name[0..5], start_date, start_time, end_time, duration, notes)
    end

    def total
      total = @items.map do |item|
        TimeHelper.calculate_duration(item[1], item[2])
      end.sum
      puts "|#{' ' * 43}\033[94mTotal:  | #{@db.seconds_to_hms(total).rjust(8)} |\033[0m                          |"
      puts format_table_separator
    end

    def filter_items(filter, tag)
      if date_ranges.key?(filter)
        start_date, end_date = date_ranges[filter]
        filter_by_date_range(start_date, end_date, tag)
      elsif valid_date_format?(filter)
        start_date, end_date = filter.split('..').map { |x| Date.parse(x) }
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
      filter_map = {
        'today' => %w[today t],
        'yesterday' => %w[yesterday y],
        'week' => %w[week w],
        'month' => %w[month m]
      }

      filter_map.each do |key, values|
        return key if values.include?(filter)
      end

      return filter if filter && valid_date_format?(filter)

      'today'
    end

    def valid_date_format?(date_string)
      date_format_single = /^\d{4}-\d{2}-\d{2}$/
      date_format_range = /^\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}$/

      date_string.match?(date_format_single) || date_string.match?(date_format_range)
    end
  end
end
