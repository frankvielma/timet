# frozen_string_literal: true

module Timet
  # Provides helper methods to determine the status of time tracking results.
  module StatusHelper
    # Determines the status of a time tracking result based on the presence and end time of items.
    #
    # @param result [Array] The result set containing time tracking items.
    #
    # @return [Symbol] The status of the time tracking result. Possible values are :no_items, :in_progress, or :complete.
    #
    # @example Determine the status of an empty result set
    #   StatusHelper.determine_status([]) # => :no_items
    #
    # @example Determine the status of a result set with an in-progress item
    #   StatusHelper.determine_status([[1, nil]]) # => :in_progress
    #
    # @example Determine the status of a result set with a completed item
    #   StatusHelper.determine_status([[1, 1633072800]]) # => :complete
    #
    # @note The method checks if the result set is empty and returns :no_items if true.
    # @note If the last item in the result set has no end time, it returns :in_progress.
    # @note If the last item in the result set has an end time, it returns :complete.
    def self.determine_status(result)
      return :no_items if result.empty?

      last_item_end = result.first[1]
      return :in_progress unless last_item_end

      :complete
    end
  end
end
