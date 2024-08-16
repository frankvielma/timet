# frozen_string_literal: true

require_relative "version"
require "thor"

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

      return unless result

      report
    end

    desc "resume", "resume last task"
    def resume
      if @db.item_status == :incomplete
        puts "A task is currently being tracked."
      else
        last_task = @db.last_item&.last
        start last_task if last_task
      end
    end

    desc "r", "Alias for resume"
    alias r resume

    desc "report [filter]",
         "Display a report of tracked time (today), filter => [today (t), yestarday (y), week (w)], [tag]"
    def report(filter = nil, tag = nil)
      report = TimeReport.new(@db, filter, tag)
      report.display
    end

    def self.exit_on_failure?
      true
    end
  end
end
