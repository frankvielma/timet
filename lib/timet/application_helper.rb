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
    # @note The method initializes a `TimeReport` object with the database and calls `show_row` to display the item details.
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
    # @note The method uses `TTY::Prompt.new` to prompt the user for a new value, displaying the current value in the prompt.
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
    # @return [String, Time] The value of the specified field. If the field is 'start' or 'end', it returns the value as a Time object.
    #
    # @example Retrieve the value of the 'notes' field
    #   field_value(item, 'notes')
    #
    # @note The method retrieves the index of the field from `Timet::Application::FIELD_INDEX`.
    # @note If the field is 'start' or 'end', the method converts the value to a Time object using `TimeHelper.timestamp_to_time`.
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
      if RUBY_PLATFORM.downcase.include?('linux')
        pid = spawn("sleep #{time} && tput bel && /home/frank/Software/frankvielma/gems/timet/bin/timet stop 0 && notify-send --icon=clock 'Pomodoro session complete! (tag: #{tag}) Time for a break.' &")
        Process.wait(pid)
      elsif RUBY_PLATFORM.downcase.include?('darwin')
        pid = spawn("(sleep #{time} && afplay /System/Library/Sounds/Basso.aiff && osascript -e 'display notification \"Pomodoro session complete! Time for a break.\"') &")
        Process.wait(pid)
      else
        puts 'Unsupported operating system'
      end
    end
  end
end
