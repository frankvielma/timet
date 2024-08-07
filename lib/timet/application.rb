# frozen_string_literal: true

require_relative "version"
require "thor"
require "byebug"
module Timet
  # Tracks time spent on various tasks.
  class Application < Thor
    def initialize(*args)
      super
      @db = Timet::Database.new
    end

    desc "start <tag>", "start time tracking"
    def start(tag)
      start = Time.now.to_i
      @db.insert_item(start, tag) if %i[no_items complete].include?(@db.item_status)
      report
    end

    desc "stop", "stop time tracking"
    def stop
      stop = Time.now.to_i
      @db.update(stop) if @db.item_status == :incomplete
      result = @db.last_item

      return if result.nil?

      report
    end

    desc "report", "Display a report of tracked time"
    def report
      items = @db.all_items

      if items.empty?
        puts "No tracked time found."
        return
      end

      format_table_header
      items.each do |item|
        start_time = format_time(item[1])
        end_time = format_time(item[2]) || "-".ljust(21)
        duration = calculate_duration(item[1], item[2])

        puts format_table_row(item[0], item[3][0..5], start_time, end_time, duration)
      end

      puts format_table_separator
    end

    def self.exit_on_failure?
      true
    end

    private

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
  end
end
