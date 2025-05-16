# frozen_string_literal: true

module Timet
  # The TimeReportHelper module provides a collection of utility methods for processing and formatting time report data.
  # It includes methods for processing time entries, handling time blocks, formatting items for CSV export,
  # and validating date formats.
  # This module is designed to be included in classes that require time report processing functionalities.
  module TimeReportHelper
    # Exports the report to a CSV file.
    #
    # @return [void] This method does not return a value; it performs side effects such as writing the CSV file.
    #
    # @example Export the report to a CSV file
    #   time_report.export_csv
    #
    # @note The method writes the items to a CSV file and prints a confirmation message.
    def export_csv
      file_name = "#{csv_filename}.csv"
      write_csv(file_name)

      puts "The #{file_name} has been exported."
    end

    # Generates an iCalendar file and writes it to disk.
    #
    # @return [void]
    def export_icalendar
      file_name = "#{ics_filename}.ics"
      cal = Timet::Utils.add_events(items)

      File.write(file_name, cal.to_ical)

      puts "The #{file_name} has been generated."
    end
  end
end
