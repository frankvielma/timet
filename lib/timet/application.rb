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

    desc "start [tag]", "start time tracking"
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

    desc "report [filter]", "Display a report of tracked time (today), filter => [today, yestarday, week]"
    def report(filter = nil)
      report = TimeReport.new(@db, filter)
      report.display
    end

    def self.exit_on_failure?
      true
    end
  end
end
