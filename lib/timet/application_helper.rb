# frozen_string_literal: true

module Timet
  # Provides helper methods for the Timet application.
  module ApplicationHelper
    # Displays the details of a tracking item.
    #
    # @param item [Hash] The tracking item to be displayed.
    #
    # @return [void] This method does not return a value; it performs side effects such as displaying the item details.
    #
    # @example Display the details of a tracking item
    #   display_item(item)
    #
    # @note The method initializes a `TimeReport` object with the database and calls `show_row` to display the
    # item details.
    def display_item(item)
      TimeReport.new(@db).show_row(item)
    end

    # Prompts the user to enter a new value for a specific field of a tracking item.
    #
    # @param item [Hash] The tracking item to be edited.
    # @param field [String] The field to be updated.
    #
    # @return [String] The new value entered by the user.
    #
    # @example Prompt for a new value for the 'notes' field
    #   prompt_for_new_value(item, 'notes')
    #
    # @note The method retrieves the current value of the field using `field_value`.
    # @note The method uses `TTY::Prompt.new` to prompt the user for a new value, displaying the current value
    # in the prompt.
    def prompt_for_new_value(item, field)
      current_value = field_value(item, field)
      prompt = TTY::Prompt.new(active_color: :green)
      prompt.ask("Update #{field} (#{current_value}):")
    end

    # Prompts the user to select a field to edit from a list of available fields.
    #
    # @return [String] The selected field in lowercase.
    #
    # @example Prompt for a field to edit
    #   select_field_to_edit
    #
    # @note The method uses `TTY::Prompt.new` to display a list of available fields for the user to select from.
    # @note The method returns the selected field in lowercase.
    def select_field_to_edit
      prompt = TTY::Prompt.new(active_color: :green)
      prompt.select('Edit Field?', Timet::Application::FIELD_INDEX.keys.map(&:capitalize), active_color: :cyan).downcase
    end

    # Retrieves the value of a specific field from a tracking item.
    #
    # @param item [Hash] The tracking item.
    # @param field [String] The field to retrieve the value for.
    #
    # @return [String, Time] The value of the specified field. If the field is 'start' or 'end', it returns the value
    # as a Time object.
    #
    # @example Retrieve the value of the 'notes' field
    #   field_value(item, 'notes')
    #
    # @note The method retrieves the index of the field from `Timet::Application::FIELD_INDEX`.
    # @note If the field is 'start' or 'end', the method converts the value to a Time object
    # using `TimeHelper.timestamp_to_time`.
    def field_value(item, field)
      index = Timet::Application::FIELD_INDEX[field]
      value = item[index]
      return TimeHelper.timestamp_to_time(value) if %w[start end].include?(field)

      value
    end

    # Plays a sound and sends a notification after a specified time.
    #
    # This method is designed to work on Linux and macOS. It triggers a sound and a notification
    # after the specified time has elapsed. On Linux, it also stops a Pomodoro session and sends
    # a desktop notification. On macOS, it plays a system sound and displays a notification.
    #
    # @param time [Integer] The duration in seconds to wait before playing the sound and sending the notification.
    # @param tag [String] The tag associated with the Pomodoro session.
    #
    # @example
    #   play_sound_and_notify(1500, 'work')
    #
    # @note This method uses platform-specific commands and assumes the presence of certain utilities
    #       (e.g., `notify-send` on Linux, `afplay` on macOS). Ensure these utilities are available
    #       on the respective operating systems.
    #
    # @raise [RuntimeError] If the operating system is not supported.
    #
    # @return [void]
    def play_sound_and_notify(time, tag)
      platform = RUBY_PLATFORM.downcase
      if platform.include?('linux')
        run_linux_session(time, tag)
      elsif platform.include?('darwin')
        run_mac_session(time, tag)
      else
        puts 'Unsupported operating system'
      end
    end

    # Runs a Pomodoro session on a Linux system.
    #
    # @param time [Integer] The duration of the Pomodoro session in seconds.
    # @param tag [String] A tag or label for the session, used in the notification message.
    # @return [void]
    def run_linux_session(time, tag)
      notification_command = "notify-send --icon=clock '#{show_message(tag)}'"
      command = "sleep #{time} && tput bel && tt stop 0 && #{notification_command} &"
      pid = spawn(command)
      Process.detach(pid)
    end

    # Runs a Pomodoro session on a macOS system.
    #
    # @param time [Integer] The duration of the Pomodoro session in seconds.
    # @param _tag [String] A tag or label for the session, not used in the notification message on macOS.
    # @return [void]
    def run_mac_session(time, tag)
      notification_command = "osascript -e 'display notification \"#{show_message(tag)}\"'"
      command = "sleep #{time} && afplay /System/Library/Sounds/Basso.aiff && tt stop 0 && #{notification_command} &"
      pid = spawn(command)
      Process.detach(pid)
    end

    # Generates a message indicating that a Pomodoro session is complete and it's time for a break.
    #
    # @param tag [String] The tag associated with the completed Pomodoro session.
    # @return [String] A message indicating the completion of the Pomodoro session and suggesting a break.
    #
    # @example
    #   show_message("work")
    #   # => "Pomodoro session complete (work). Time for a break."
    #
    def show_message(tag)
      "Pomodoro session complete (#{tag}). Time for a break."
    end

    # Deletes a tracking item from the database by its ID and prints a confirmation message.
    #
    # @param id [Integer] The ID of the tracking item to be deleted.
    # @param message [String] The message to be printed after the item is deleted.
    #
    # @return [void] This method does not return a value; it performs side effects such as deleting the tracking item
    # and printing a message.
    #
    # @example Delete a tracking item with ID 1 and print a confirmation message
    #   delete_item_and_print_message(1, 'Deleted item 1')
    #
    # @note The method deletes the tracking item from the database using `@db.delete_item(id)`.
    # @note After deleting the item, the method prints the provided message using `puts message`.
    def delete_item_and_print_message(id, message)
      @db.delete_item(id)
      puts message
    end

    # Resumes a tracking session for a completed task.
    #
    # @param id [Integer, nil] The ID of the tracking item to resume. If nil, the last completed item is used.
    #
    # @return [void] This method does not return a value; it performs side effects such as resuming a tracking session.
    #
    # @example Resume the last completed task
    #   resume_complete_task
    #
    # @example Resume a specific task by ID
    #   resume_complete_task(123)
    #
    # @note The method fetches the specified or last completed item using `@db.find_item` or `@db.last_item`.
    # @note If the item is found, it retrieves the tag and notes and calls the `start` method to resume the
    # tracking session.
    #
    # @see Database#find_item
    # @see Database#last_item
    # @see #start
    def resume_complete_task(id)
      item = id ? @db.find_item(id) : @db.last_item
      return unless item

      tag, notes = item.values_at(Application::FIELD_INDEX['tag'], Application::FIELD_INDEX['notes'])
      start(tag, notes)
    end

    # Builds a hash of options to be used when initializing a TimeReport instance.
    #
    # @param time_scope [String, nil] The filter to apply when fetching items. Possible values include 'today',
    #   'yesterday', 'week', 'month', or a date range in the format 'YYYY-MM-DD..YYYY-MM-DD'.
    # @param tag [String, nil] The tag to filter the items by.
    #
    # @return [Hash] A hash containing the filter, tag, CSV filename, and iCalendar filename.
    #
    # @example Build options with a filter and tag
    #   build_options('today', 'work') # => { filter: 'today', tag: 'work', csv: nil, ics: nil }
    def build_options(time_scope, tag)
      csv_filename = options[:csv]&.split('.')&.first
      ics_filename = options[:ics]&.split('.')&.first
      {
        filter: time_scope,
        tag: tag,
        csv: csv_filename,
        ics: ics_filename
      }
    end

    # @note This class is responsible for exporting reports to CSV and iCalendar formats.
    class ReportExporter
      # Exports the report to a CSV file if the `csv` option is provided.
      #
      # @param report [TimeReport] The report object to export.
      # @param options [Hash] The options hash containing export settings.
      # @option options [String] :csv The filename to use when exporting the report to CSV.
      # @return [void]
      def self.export_csv_report(report, options)
        report.export_csv if options[:csv]
      end

      # Exports the report to an iCalendar file if the `ics` option is provided.
      #
      # @param report [TimeReport] The report object to export.
      # @param options [Hash] The options hash containing export settings.
      # @option options [String] :ics The filename to use when exporting the report to iCalendar.
      # @return [void]
      def self.export_icalendar_report(report, options)
        report.export_icalendar if options[:ics]
      end
    end

    # Displays the report and exports it to a CSV file and/or an iCalendar file if specified.
    #
    # @param report [TimeReport] The TimeReport instance to display and export.
    # @param options [Hash] A hash containing the options for exporting the report.
    # @option options [String, nil] :csv The filename to use when exporting the report to CSV.
    # @option options [String, nil] :ics The filename to use when exporting the report to iCalendar.
    #
    # @return [void] This method does not return a value; it performs side effects such as displaying
    # and exporting the report.
    #
    # @example Display and export the report to CSV and iCalendar
    #   display_and_export_report(report, { csv: 'report.csv', ics: 'icalendar.ics' })
    def display_and_export_report(report, options)
      report.display
      export_report(report, options)
    end

    # Exports the given report in CSV and iCalendar formats if there are items, otherwise prints a message.
    #
    # @param report [Report] The report to be exported.
    # @param options [Hash] The options to pass to the exporter.
    # @return [void]
    def export_report(report, options)
      items = report.items
      if items.any?
        ReportExporter.export_csv_report(report, options)
        ReportExporter.export_icalendar_report(report, options)
      else
        puts 'No items found to export'
      end
    end
  end
end
