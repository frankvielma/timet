# frozen_string_literal: true

require 'date'

module Timet
  #
  # The WeekInfo class encapsulates the date string and weeks array
  # and provides methods for formatting and determining week information.
  #
  # It is instantiated for each date entry in the TimeBlockChart and helps decide
  # how the week number is displayed and whether a separator line is needed before the entry.
  class WeekInfo
    # Initializes a new WeekInfo instance.
    #
    # @param date_object [Date] The Date object for the current entry.
    # @param date_string_for_display [String] The original date string for display (e.g., "2023-10-01").
    # @param weeks_array_ref [Array<Integer>] A reference to an array that accumulates the
    #   ISO 8601 week numbers of dates already processed. This array is mutated.

    WEEKEND_DAYS = %w[Sat Sun].freeze
    def initialize(date_object, date_string_for_display, weeks_array_ref)
      @date_string = date_string_for_display # Use the passed string for display
      @current_cweek = date_object.cweek

      # Determine if a separator line should be printed *before* this entry.
      # A separator is needed if this entry starts a new week group,
      # and it's not the very first week group in the chart.
      @print_separator_before_this = !weeks_array_ref.empty? && @current_cweek != weeks_array_ref.last

      # Determine how the week number string should be displayed for this entry.
      # It's underlined if it's the first time this cweek appears, otherwise blank.
      is_first_display_of_this_cweek = weeks_array_ref.empty? || @current_cweek != weeks_array_ref.last
      @week_display_string = if is_first_display_of_this_cweek
                               format('%02d', @current_cweek).underline
                             else
                               '  '
                             end

      weeks_array_ref << @current_cweek # Record this week as processed
    end

    # Indicates whether an inter-week separator line should be printed before this date's entry.
    #
    # @return [Boolean] True if a separator is needed, false otherwise.
    def needs_inter_week_separator?
      @print_separator_before_this
    end

    # Formats and prints the date information
    #
    # @param [String] day The day of the week
    # @return [void]
    def format_and_print_date_info(day)
      weekend_str = @date_string # Use the original date string for display
      is_weekend_day = WEEKEND_DAYS.include?(day)
      day_str = is_weekend_day ? day.red : day
      weekend_str = weekend_str.red if is_weekend_day

      print '┆'.gray + "#{@week_display_string} #{weekend_str} #{day_str}" + '┆- '.gray
    end
  end
end
