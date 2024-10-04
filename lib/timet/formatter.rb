# frozen_string_literal: true

module Timet
  # This module is responsible for formatting the output of the `timet` application.
  # It provides methods for formatting the table header, separators, and rows.
  module Formatter
    # Formats the header of the time tracking report table.
    #
    # @return [void] This method does not return a value; it performs side effects such as printing the formatted header.
    #
    # @example Format and print the table header
    #   format_table_header
    #
    # @note The method constructs a string representing the table header and prints it.
    def format_table_header
      header = <<~TABLE
        Tracked time report \u001b[31m[#{@filter}]\033[0m:
        #{format_table_separator}
        \033[32m| Id    | Date       | Tag    | Start    | End      | Duration | Notes                    |\033[0m
        #{format_table_separator}
      TABLE
      puts header
    end

    # Formats the separator line for the time tracking report table.
    #
    # @return [String] The formatted separator line.
    #
    # @example Get the formatted table separator
    #   format_table_separator # => '+-------+------------+--------+----------+----------+----------+--------------------------+'
    #
    # @note The method returns a string representing the separator line for the table.
    def format_table_separator
      '+-------+------------+--------+----------+----------+----------+--------------------------+'
    end

    # Formats a row of the time tracking report table.
    #
    # @param row [Array] The row data to be formatted.
    # @return [String] The formatted row.
    #
    # @example Format a table row
    #   format_table_row(1, 'work', '2023-10-01', '12:00:00', '14:00:00', 7200, 'Completed task X')
    #
    # @note The method formats each element of the row and constructs a string representing the formatted row.
    def format_table_row(*row)
      id, tag, start_date, start_time, end_time, duration, notes = row
      "| #{id.to_s.rjust(5)} | #{start_date} | #{tag.ljust(6)} | #{start_time.split[1]} | " \
        "#{end_time.split[1].rjust(8)} | #{@db.seconds_to_hms(duration).rjust(8)} | #{format_notes(notes)}  |"
    end

    # Formats the notes column of the time tracking report table.
    #
    # @param notes [String, nil] The notes to be formatted.
    # @return [String] The formatted notes.
    #
    # @example Format notes
    #   format_notes('This is a long note that needs to be truncated')
    #
    # @note The method truncates the notes to a maximum of 20 characters and pads them to a fixed width.
    def format_notes(notes)
      return ' ' * 23 if notes.nil?

      notes = "#{notes.slice(0, 20)}..." if notes.length > 20
      notes.ljust(23)
    end
  end
end
