# frozen_string_literal: true

require 'thor'
require 'tty-prompt'
require 'icalendar'
require_relative 's3_supabase'
require_relative 'validation_edit_helper'
require_relative 'application_helper'
require_relative 'time_helper'
require_relative 'version'
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
    include TimeHelper

    def initialize(*args)
      super
      @db = Database.new
    end

    FIELD_INDEX = {
      'notes' => 4,
      'tag' => 3,
      'start' => 1,
      'end' => 2
    }.freeze

    VALID_STATUSES_FOR_INSERTION = %i[no_items complete].freeze

    desc "start [tag] --notes='' --pomodoro=[min]",
         'Start time tracking for a task labeled with the provided [tag], notes and "pomodoro time"
        in minutes (optional).
        tt start project1 "Starting project1" --pomodoro=25'
    option :notes, type: :string, desc: 'Add a note'
    option :pomodoro, type: :numeric, desc: 'Pomodoro time in minutes'
    # Starts a new tracking session with the given tag and optional notes.
    #
    # This method initializes a new tracking session by inserting a new item into the database
    # with the provided tag and optional notes. If a Pomodoro time is specified, it will also
    # trigger a sound and notification after the specified time has elapsed.
    #
    # @param tag [String] The tag associated with the tracking session. This is a required parameter.
    # @param notes [String, nil] Optional notes to be associated with the tracking session. If not provided, it
    # defaults to the value in `options[:notes]`.
    # @param pomodoro [Numeric, nil] Optional Pomodoro time in minutes. If not provided, it defaults to the value in
    # `options[:pomodoro]`.
    #
    # @return [void] This method does not return a value; it performs side effects such as inserting a tracking item,
    # playing a sound, sending a notification, and generating a summary.
    #
    # @example Start a tracking session with a tag and notes
    #   start('work', 'Starting work on project X', 25)
    #
    # @example Start a tracking session with only a tag
    #   start('break')
    #
    # @note The method uses `TimeHelper.current_timestamp` to get the current timestamp for the start time.
    # @note The method calls `play_sound_and_notify` if a Pomodoro time is provided.
    # @note The method calls `summary` to generate a summary after inserting the tracking item.
    def start(tag, notes = nil, pomodoro = nil)
      start_time = TimeHelper.current_timestamp
      notes = options[:notes] || notes
      pomodoro = (options[:pomodoro] || pomodoro).to_i

      return puts 'A task is currently being tracked.' unless VALID_STATUSES_FOR_INSERTION.include?(@db.item_status)

      @db.insert_item(start_time, tag, notes, pomodoro)
      play_sound_and_notify(pomodoro * 60, tag) if pomodoro.positive?
      summary
    end

    desc 'stop', 'Stop time tracking'
    # Stops the current tracking session if there is one in progress.
    #
    # @return [void] This method does not return a value; it performs side effects such as updating the tracking item
    # and generating a summary.
    #
    # @example Stop the current tracking session
    #   stop
    #
    # @note The method checks if the last tracking item is in progress by calling `@db.item_status`.
    # @note If the last item is in progress, it fetches the last item's ID using `@db.fetch_last_id` and updates it
    # with the current timestamp.
    # @note The method then fetches the last item using `@db.last_item` and generates a summary if the result
    # is not nil.
    def stop(display = nil)
      return unless @db.item_status == :in_progress

      last_id = @db.fetch_last_id
      @db.update_item(last_id, 'end', TimeHelper.current_timestamp)

      summary unless display
    end

    desc 'resume (r) [id]', 'Resume last task (id is an optional parameter) => tt resume'
    # Resumes the last tracking session if it was completed.
    #
    # @return [void] This method does not return a value; it performs side effects such as resuming a tracking session
    # or providing feedback.
    #
    # @example Resume the last tracking session
    #   resume
    #
    # @example Resume a specific task by ID
    #   resume(123)
    #
    # @note The method checks the status of the last tracking item using `@db.item_status`.
    # @note If the last item is in progress, it prints a message indicating that a task is currently being tracked.
    # @note If the last item is complete, it fetches the last item using `@db.find_item` or `@db.last_item`,
    # retrieves the tag and notes,
    # and calls the `start` method to resume the tracking session.
    #
    # @param id [Integer, nil] The ID of the tracking item to resume. If nil, the last item is used.
    #
    # @see Database#item_status
    # @see Database#find_item
    # @see #start
    def resume(id = nil)
      case @db.item_status(id)
      when :in_progress
        puts 'A task is currently being tracked.'
      when :complete
        resume_complete_task(id)
      end
    end

    desc 'summary (su) [time_scope] [tag] --csv=csv_filename --ics=ics_filename',
         'Display a summary of tracked time and export to CSV.
          [time_scope] => [today (t), yesterday (y), week (w), month (m). => tt su yesterday
          [start_date]..[end_date]] => tt su 2024-10-03..2024-10-20
          [tag] => tt su Task1
          --csv=csv_filename => tt su month --csv=myfile
          --ics=ics_filename => tt su week --csv=mycalendar'
    option :csv, type: :string, desc: 'Export to CSV'
    option :ics, type: :string, desc: 'Export to iCalendar'
    # Generates a summary of tracking items based on the provided time_scope and tag, and optionally exports the summary
    # to a CSV file and/or an iCalendar file.
    #
    # @param time_scope [String, nil] The filter to apply when fetching items. Possible values include 'today',
    #   'yesterday', 'week', 'month', or a date range in the format 'YYYY-MM-DD..YYYY-MM-DD'.
    # @param tag [String, nil] The tag to filter the items by.
    #
    # @return [void] This method does not return a value; it performs side effects such as displaying
    # and exporting the report.
    def summary(time_scope = nil, tag = nil)
      options = build_options(time_scope, tag)
      report = TimeReport.new(@db, options)
      display_and_export_report(report, options)
    end

    desc 'edit (e) [id] [field] [value]',
         'Edit task, [field] (notes, tag, start or end) and [value] are optional parameters.
          Update notes => tt edit 12 notes "Update note"
          Update start time => tt edit 12 start 12:33'
    # Edits a specific tracking item by its ID, allowing the user to modify fields such as notes, tag, start time, or
    # end time.
    #
    # @param id [Integer] The ID of the tracking item to be edited.
    # @param field [String, nil] The field to be edited. Possible values include 'notes', 'tag', 'start', or 'end'.
    # If not provided, the user will be prompted to select a field.
    # @param new_value [String, nil] The new value to be set for the specified field. If not provided, the user will be
    # prompted to enter a new value.
    #
    # @return [void] This method does not return a value; it performs side effects such as updating the tracking item
    # and displaying the updated item.
    #
    # @example Edit the notes of a tracking item with ID 1
    #   edit(1, 'notes', 'Updated notes')
    #
    # @example Edit a tracking item with ID 2, prompting for the field and new value
    #   edit(2)
    #
    # @note The method first attempts to find the tracking item by its ID using `@db.find_item(id)`.
    # @note If the item is found, it displays the current item details using `display_item(item)`.
    # @note If the field or new value is not provided, the user is prompted to select a field to edit and enter
    # a new value.
    # @note The method then validates and updates the item using `validate_and_update(item, field, new_value)`.
    # @note Finally, it displays the updated item details using `display_item(updated_item)`.
    def edit(id, field = nil, new_value = nil)
      item = @db.find_item(id)
      return puts "No tracked time found for id: #{id}" unless item

      display_item(item)
      unless FIELD_INDEX.keys.include?(field&.downcase) || new_value
        field = select_field_to_edit
        new_value = prompt_for_new_value(item, field)
      end

      updated_item = validate_and_update(item, field, new_value)
      display_item(updated_item || item)
    end

    desc 'delete (d) [id]', 'Delete task => tt d 23'
    # Deletes a specific tracking item by its ID after confirming with the user.
    #
    # @param id [Integer] The ID of the tracking item to be deleted.
    #
    # @return [void] This method does not return a value; it performs side effects such as deleting the tracking item
    # and displaying a confirmation message.
    #
    # @example Delete a tracking item with ID 1
    #   delete(1)
    #
    # @note The method first attempts to find the tracking item by its ID using `@db.find_item(id)`.
    # @note If the item is found, it displays the item details using `TimeReport.new(@db).show_row(item)`.
    # @note The method then prompts the user for confirmation using `TTY::Prompt.new.yes?('Are you sure you want
    # to delete this entry?')`.
    # @note If the user confirms, the method deletes the item and prints a confirmation message using
    # `delete_item_and_print_message(id, "Deleted #{id}")`.
    def delete(id)
      item = @db.find_item(id)
      return puts "No tracked time found for id: #{id}" unless item

      TimeReport.new(@db).show_row(item)
      return unless TTY::Prompt.new.yes?('Are you sure you want to delete this entry?')

      delete_item_and_print_message(id, "Deleted #{id}")
    end

    desc 'cancel (c)', 'Cancel active time tracking => tt c'
    # Cancels the active time tracking session by deleting the last tracking item.
    #
    # @return [void] This method does not return a value; it performs side effects such as deleting the active tracking
    # item and displaying a confirmation message.
    #
    # @example Cancel the active time tracking session
    #   cancel
    #
    # @note The method fetches the ID of the last tracking item using `@db.fetch_last_id`.
    # @note It checks if the last item is in progress by comparing `@db.item_status` with `:complete`.
    # @note If the last item is in progress, it deletes the item and prints a confirmation message using
    # `delete_item_and_print_message(id, "Canceled active time tracking #{id}")`.
    # @note If there is no active time tracking, it prints a message indicating that there is no active time tracking.
    def cancel
      id = @db.fetch_last_id
      return puts 'There is no active time tracking' if @db.item_status == :complete

      delete_item_and_print_message(id, "Canceled active time tracking #{id}")
    end

    # Determines whether the application should exit when a command fails.
    #
    # @return [Boolean] Returns `true`, indicating that the application should exit when a command fails.
    #
    # @example Check if the application should exit on failure
    #   MyClass.exit_on_failure? # => true
    #
    # @note This method is typically used in command-line applications to control the behavior when a command fails.
    # @note Returning `true` means that the application will exit immediately if a command fails, which is useful for
    # ensuring that errors are handled gracefully.
    def self.exit_on_failure?
      true
    end

    #   Displays the current version of the Timet gem.
    #
    #   @example
    #     $ timet version
    #     1.0.0
    #
    #   @return [void] This method does not return a value; it prints the version to the standard output.
    desc 'version', 'version'
    def version
      puts Timet::VERSION
    end

    desc 'sync', 'Sync local db with supabase external db'
    def sync
      puts 'sync'
      s3 = S3Supabase.new
      s3.create_bucket('timet')

      result = s3.list_objects('timet')
      if result
        puts 'object exists'
        # compare local and remote db
      else
        s3.upload_file('timet', Timet::Database::DEFAULT_DATABASE_PATH, 'timet.db')
      end
    end
  end
end
