# frozen_string_literal: true

module Timet
  # Determines the status of a time tracking result based on the presence and end time of items.
  module StatusHelper
    def self.determine_status(result)
      return :no_items if result.empty?

      last_item_end = result.first[1]
      return :in_progress unless last_item_end

      :complete
    end
  end
end
