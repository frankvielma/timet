# frozen_string_literal: true

require_relative 'version'
require 'thor'
require 'tty-prompt'
require 'byebug'

module Timet
  # Tracks time spent on various tasks.
  class Application < Thor
    def initialize(*args)
      super
      @db = Timet::Database.new
    end

    FIELD_INDEX = {
      'notes' => 4,
      'tag' => 3,
      'start' => 1,
      'end' => 2
    }.freeze

    desc "start [tag] --notes='...'", "start time tracking  --notes='my notes...'"
    option :notes, type: :string, desc: 'Add a note'
    def start(tag, notes = nil)
      start = Time.now.to_i
      notes = options[:notes] || notes
      @db.insert_item(start, tag, notes) if %i[no_items complete].include?(@db.last_item_status)
      summary
    end

    desc 'stop', 'stop time tracking'
    def stop
      stop = Time.now.to_i
      @db.update(stop) if @db.last_item_status == :incomplete
      result = @db.last_item

      return unless result

      summary
    end

    desc 'resume (r)', 'resume last task'
    def resume
      if @db.last_item_status == :incomplete
        puts 'A task is currently being tracked.'
      elsif @db.last_item.any?
        tag = @db.last_item[3]
        notes = @db.last_item[4]
        start(tag, notes)
      end
    end

    desc 'summary (su) [filter] [tag] --csv=csv_filename',
         "Display a summary of tracked time filter => [today (t), yesterday (y), week (w), month (m)] [tag]
          and export to csv_filename"
    option :csv, type: :string, desc: 'Export to CSV file'
    def summary(filter = nil, tag = nil)
      csv_filename = options[:csv]
      summary = TimeReport.new(@db, filter, tag, csv_filename)
      summary.display
      summary.export_sheet if csv_filename
    end

    desc 'edit (e) [id]', 'edit a task'
    def edit(id)
      item = @db.find_item(id)
      return puts "No tracked time found for id: #{id}" unless item

      TimeReport.new(@db).show_row(item)

      prompt = TTY::Prompt.new(active_color: :green)
      field = prompt.select('Edit Field?', FIELD_INDEX.keys.map(&:capitalize), active_color: :cyan).downcase

      current_value = field_value(item, field)
      new_value = prompt.ask("Update #{field} (#{current_value}):")
      validate_and_update(item, field, new_value)

      summary.display
    end

    desc 'delete (d) [id]', 'delete a task'
    def delete(id)
      item = @db.find_item(id)
      return puts "No tracked time found for id: #{id}" unless item

      TimeReport.new(@db).show_row(item)
      return unless TTY::Prompt.new.yes?('Are you sure you want to delete this entry?')

      delete_item_and_print_message(id, "Deleted #{id}")
    end

    desc 'cancel (c)', 'cancel active time tracking'
    def cancel
      id = @db.fetch_last_id
      return puts 'There is no active time tracking' if @db.last_item_status == :complete

      delete_item_and_print_message(id, "Canceled active time tracking #{id}")
    end

    def self.exit_on_failure?
      true
    end

    private

    def field_value(item, field)
      if %w[start end].include?(field)
        TimeHelper.timestamp_to_time(item[FIELD_INDEX[field]])
      else
        item[FIELD_INDEX[field]]
      end
    end

    def validate_and_update(item, field, new_value)
      if %w[start end].include?(field)
        id = item[0]
        begin
          return if new_value.nil?

          filter_value = format_time_string(new_value)
          value = Time.at(item[FIELD_INDEX[field]]).to_s.split
          value[1] = filter_value
          new_date = DateTime.strptime(value.join(' '), '%Y-%m-%d %H:%M:%S %z').to_time
          new_value = new_date.to_i

          item_before = @db.find_item(id - 1)
          item_after = @db.find_item(id + 1)

          condition_start = field == 'start' && new_value >= item_before[FIELD_INDEX['end']] && new_value <= item[FIELD_INDEX['end']]
          condition_end = field == 'end' && new_value >= item[FIELD_INDEX['start']] && new_value <= item_after[FIELD_INDEX['start']]

          if condition_start || condition_end
            @db.update_item(id, field, new_value)
          else
            puts "\u001b[31mInvalid date: #{new_date}\033[0m"
          end
        rescue ArgumentError => e
          puts "Invalid time format: #{e.message}"
        end
      else
        @db.update_item(id, field, new_value)
      end
    end

    def format_time_string(input)
      cleaned_input = input.gsub(/\D/, '')
      padded_input = cleaned_input.ljust(6, '0')
      "#{padded_input[0, 2]}:#{padded_input[2, 2]}:#{padded_input[4, 2]}"
    end

    def delete_item_and_print_message(id, message)
      @db.delete_item(id)
      puts message
    end
  end
end
