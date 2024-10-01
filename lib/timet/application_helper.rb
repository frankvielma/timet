# frozen_string_literal: true

module Timet
  # Provides helper methods for the Timet application.
  module ApplicationHelper
    def display_item(item)
      TimeReport.new(@db).show_row(item)
    end

    def prompt_for_new_value(item, field)
      current_value = field_value(item, field)
      prompt = TTY::Prompt.new(active_color: :green)
      prompt.ask("Update #{field} (#{current_value}):")
    end

    def select_field_to_edit
      prompt = TTY::Prompt.new(active_color: :green)
      prompt.select('Edit Field?', Timet::Application::FIELD_INDEX.keys.map(&:capitalize), active_color: :cyan).downcase
    end

    def field_value(item, field)
      index = Timet::Application::FIELD_INDEX[field]
      value = item[index]
      return TimeHelper.timestamp_to_time(value) if %w[start end].include?(field)

      value
    end
  end
end
