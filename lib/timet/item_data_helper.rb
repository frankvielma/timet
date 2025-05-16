# frozen_string_literal: true

module Timet
  # Helper methods for fetching item data.
  module ItemDataHelper
    module_function

    # Fetches the start time of a tracking item.
    #
    # @param item [Array] The tracking item.
    #
    # @return [Integer] The start time in epoch format.
    #
    # @example Fetch the start time of a tracking item
    #   fetch_item_start(item)
    def fetch_item_start(item)
      item[Timet::Application::FIELD_INDEX['start']]
    end

    # Fetches the end time of a tracking item.
    #
    # @param item [Array] The tracking item.
    #
    # @return [Integer] The end time in epoch format.
    #
    # @example Fetch the end time of a tracking item
    #   fetch_item_end(item)
    def fetch_item_end(item)
      item[Timet::Application::FIELD_INDEX['end']] || TimeHelper.current_timestamp
    end

    # Fetches the end time of the tracking item before the current one.
    #
    # @param db [Timet::Database] The database instance.
    # @param id [Integer] The ID of the current tracking item.
    # @param item_start [Integer] The start time of the current tracking item.
    #
    # @return [Integer] The end time of the previous tracking item in epoch format.
    #
    # @example Fetch the end time of the previous tracking item
    #   fetch_item_before_end(db, 1, 1633072800)
    def fetch_item_before_end(db, id, item_start)
      db.find_item(id - 1)&.dig(Timet::Application::FIELD_INDEX['end']) || item_start
    end

    # Fetches the start time of the tracking item after the current one.
    #
    # @param db [Timet::Database] The database instance.
    # @param id [Integer] The ID of the current tracking item.
    #
    # @return [Integer] The start time of the next tracking item in epoch format.
    #
    # @example Fetch the start time of the next tracking item
    #   fetch_item_after_start(db, id)
    def fetch_item_after_start(db, id)
      db.find_item(id + 1)&.dig(Timet::Application::FIELD_INDEX['start']) || TimeHelper.current_timestamp
    end
  end
end
