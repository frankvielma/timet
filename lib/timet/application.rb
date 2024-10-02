# frozen_string_literal: true

require_relative 'version'
require 'thor'
require 'tty-prompt'
require_relative 'validation_edit_helper'
require_relative 'application_helper'
require_relative 'time_helper'

module Timet
  # Application class that defines CLI commands for time tracking:
  # - start: Start time tracking with optional notes
  # - stop: Stop time tracking
  # - resume: Resume the last task
  # - summary: Display a summary of tracked time and export to CSV
  # - edit: Edit a task
  # - delete: Delete a task
  # - cancel: Cancel active time tracking
  class Application < Thor
    include ValidationEditHelper
    include ApplicationHelper

    def initialize(*args)
      super
      @db = Timet::Database.new
    end

    FIELD_INDEX = {
      'notes' => 4,
      'tag' => 3,
      'start' => 1,
      'end' => 2
    }.freeze

    VALID_STATUSES_FOR_INSERTION = %i[no_items complete].freeze

    desc "start [tag] --notes='...'", "start time tracking  --notes='my notes...'"
    option :notes, type: :string, desc: 'Add a note'
    def start(tag, notes = nil)
      start_time = TimeHelper.current_timestamp
      notes = options[:notes] || notes

      insert_item_if_valid(start_time, tag, notes)
      summary
    end

    desc 'stop', 'stop time tracking'
    def stop
      stop = TimeHelper.current_timestamp
      @db.update(stop) if @db.last_item_status == :in_progress
      result = @db.last_item

      return unless result

      summary
    end

    desc 'resume (r)', 'resume last task'
    def resume
      status = @db.last_item_status

      case status
      when :in_progress
        puts 'A task is currently being tracked.'
      when :complete
        last_item = @db.last_item
        if last_item
          tag = last_item[FIELD_INDEX['tag']]
          notes = last_item[FIELD_INDEX['notes']]
          start(tag, notes)
        end
      end
    end

    desc 'summary (su) [filter] [tag] --csv=csv_filename',
         "Display a summary of tracked time filter => [today (t), yesterday (y), week (w), month (m)] [tag]
          and export to csv_filename"
    option :csv, type: :string, desc: 'Export to CSV file'
    def summary(filter = nil, tag = nil)
      csv_filename = options[:csv].split('.')[0] if options[:csv]
      summary = TimeReport.new(@db, filter, tag, csv_filename)
      summary.display
      if csv_filename && summary.items.any?
        summary.export_sheet
      elsif summary.items.empty?
        puts 'No items found to export'
      end
    end

    desc 'edit (e) [id]', 'edit a task'
    def edit(id, field = nil, new_value = nil)
      item = @db.find_item(id)
      return puts "No tracked time found for id: #{id}" unless item

      display_item(item)
      unless FIELD_INDEX.keys.include?(field&.downcase) || new_value
        field = select_field_to_edit
        new_value = prompt_for_new_value(item, field)
      end

      validate_and_update(item, field, new_value)

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

    def insert_item_if_valid(start_time, tag, notes)
      return unless VALID_STATUSES_FOR_INSERTION.include?(@db.last_item_status)

      @db.insert_item(start_time, tag, notes)
    end

    def delete_item_and_print_message(id, message)
      @db.delete_item(id)
      puts message
    end
  end
end
