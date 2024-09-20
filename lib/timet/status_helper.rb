# frozen_string_literal: true

# Determines the status of a time tracking result based on the presence and end time of items.
module StatusHelper
  def self.determine_status(result)
    return :no_items if result.empty?

    last_item_end = result.first[1]
    return :incomplete unless last_item_end

    :complete
  end
end