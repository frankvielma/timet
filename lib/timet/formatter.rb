# frozen_string_literal: true

# This module is responsible for formatting the output of the `timet` application.
# It provides methods for formatting the table header, separators, and rows.
module Timet
  module Formatter
    def format_table_header
      header = <<~TABLE
        Tracked time report \u001b[31m[#{@filter}]\033[0m:
        #{format_table_separator}
        \033[32m| Id    | Date       | Tag    | Start    | End      | Duration | Notes                    |\033[0m
        #{format_table_separator}
      TABLE
      puts header
    end

    def format_table_separator
      '+-------+------------+--------+----------+----------+----------+--------------------------+'
    end

    def format_table_row(*row)
      id, tag, start_date, start_time, end_time, duration, notes = row
      "| #{id.to_s.rjust(5)} | #{start_date} | #{tag.ljust(6)} | #{start_time.split[1]} | " \
        "#{end_time.split[1].rjust(8)} | #{@db.seconds_to_hms(duration).rjust(8)} | #{format_notes(notes)}  |"
    end

    def format_notes(notes)
      return ' ' * 23 if notes.nil?

      notes = "#{notes.slice(0, 20)}..." if notes.length > 20
      notes.ljust(23)
    end
  end
end
