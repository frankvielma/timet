# frozen_string_literal: true

require_relative "version"
require "thor"
require "tty-prompt"

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
      @db.insert_item(start, tag) if %i[no_items complete].include?(@db.last_item_status)
      report
    end

    desc "stop", "stop time tracking"
    def stop
      stop = Time.now.to_i
      @db.update(stop) if @db.last_item_status == :incomplete
      result = @db.last_item

      return unless result

      report
    end

    desc "resume", "resume last task"
    def resume
      if @db.last_item_status == :incomplete
        puts "A task is currently being tracked."
      else
        last_task = @db.last_item&.last
        start last_task if last_task
      end
    end

    desc "r", "alias for resume"
    alias r resume

    desc "report [filter]",
         "Display a report of tracked time (today), filter => [today (t), yestarday (y), week (w)], [tag]"
    def report(filter = nil, tag = nil)
      report = TimeReport.new(@db, filter, tag)
      report.display
    end

    desc "delete [id]", "delete a task"
    def delete(id)
      item = @db.find_item(id)
      return puts "No tracked time found for id: #{id}" unless item

      TimeReport.new(@db, nil, nil).row(item)
      return unless TTY::Prompt.new.yes?("Are you sure you want to delete this entry?")

      delete_item_and_print_message(id, "Deleted #{id}")
    end

    desc "d", "alias for delete"
    alias d delete

    desc "cancel", "cancel active time tracking"
    def cancel
      id = @db.fetch_last_id
      return puts "There is no active time tracking" if @db.last_item_status == :complete

      delete_item_and_print_message(id, "Canceled active time tracking #{id}")
    end

    desc "c", "alias for cancel"
    alias c cancel

    def self.exit_on_failure?
      true
    end

    private

    def delete_item_and_print_message(id, message)
      @db.delete_item(id)
      puts message
    end
  end
end
