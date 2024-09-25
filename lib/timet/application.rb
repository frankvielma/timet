# frozen_string_literal: true

require_relative 'version'
require 'thor'
require 'tty-prompt'
require 'byebug'

module Timet
  # Tracks time spent on various tasks.
  class Application < Thor
    def initialize(*args)
      super
      @db = Timet::Database.new
    end

    desc "start [tag] --notes='...'", "start time tracking  --notes='my notes...'"
    option :notes, type: :string, desc: 'Add a note'
    def start(tag, notes = nil)
      start = Time.now.to_i
      notes = options[:notes] || notes
      @db.insert_item(start, tag, notes) if %i[no_items complete].include?(@db.last_item_status)
      summary
    end

    desc 'stop', 'stop time tracking'
    def stop
      stop = Time.now.to_i
      @db.update(stop) if @db.last_item_status == :incomplete
      result = @db.last_item

      return unless result

      summary
    end

    desc 'resume (r)', 'resume last task'
    def resume
      if @db.last_item_status == :incomplete
        puts 'A task is currently being tracked.'
      elsif @db.last_item.any?
        tag = @db.last_item[3]
        notes = @db.last_item[4]
        start(tag, notes)
      end
    end

    desc 'summary (su) [filter] [tag] --csv=csv_filename',
         "Display a summary of tracked time filter => [today (t), yesterday (y), week (w), month (m)] [tag]
          and export to csv_filename"
    option :csv, type: :string, desc: 'Export to CSV file'
    def summary(filter = nil, tag = nil)
      csv_filename = options[:csv]
      summary = TimeReport.new(@db, filter, tag, csv_filename)
      summary.display
      summary.export_sheet if csv_filename
    end

    desc 'edit (e) [id]', 'edit a note'
    def edit(id)
      item = @db.find_item(id)
      return puts "No tracked time found for id: #{id}" unless item

      TimeReport.new(@db).show_row(item)
      updated_notes = prompt_for_update(item[4])
      update_item_notes(item, updated_notes)
      summary.display
    end

    desc 'delete (d) [id]', 'delete a task'
    def delete(id)
      item = @db.find_item(id)
      return puts "No tracked time found for id: #{id}" unless item

      TimeReport.new(@db).show_row(item)
      return unless TTY::Prompt.new.yes?('Are you sure you want to delete this entry?')

      delete_item_and_print_message(id, "Deleted #{id}")
    end

    desc 'cancel (c)', 'cancel active time tracking'
    def cancel
      id = @db.fetch_last_id
      return puts 'There is no active time tracking' if @db.last_item_status == :complete

      delete_item_and_print_message(id, "Canceled active time tracking #{id}")
    end

    def self.exit_on_failure?
      true
    end

    private

    def update_item_notes(item, updated_notes)
      new_item = item.dup
      new_item[4] = updated_notes
      @db.update_item(new_item)
    end

    def prompt_for_update(current_notes)
      prompt = TTY::Prompt.new(active_color: :green)
      prompt.ask("Update notes (#{current_notes}):")
    end

    def delete_item_and_print_message(id, message)
      @db.delete_item(id)
      puts message
    end
  end
end
