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

    VALID_STATUSES_FOR_INSERTION = %i[no_items complete].freeze

    desc "start [tag] --notes='...'", "start time tracking  --notes='my notes...'"
    option :notes, type: :string, desc: 'Add a note'
    def start(tag, notes = nil)
      start_time = current_timestamp
      notes = options[:notes] || notes

      insert_item_if_valid(start_time, tag, notes)
      summary
    end

    desc 'stop', 'stop time tracking'
    def stop
      stop = current_timestamp
      @db.update(stop) if @db.last_item_status == :in_progress
      result = @db.last_item

      return unless result

      summary
    end

    desc 'resume (r)', 'resume last task'
    def resume
      status = @db.last_item_status

      case status
      when :in_progress
        puts 'A task is currently being tracked.'
      when :complete
        last_item = @db.last_item
        if last_item
          tag = last_item[FIELD_INDEX['tag']]
          notes = last_item[FIELD_INDEX['notes']]
          start(tag, notes)
        end
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

    def current_timestamp
      Time.now.to_i
    end

    def insert_item_if_valid(start_time, tag, notes)
      return unless VALID_STATUSES_FOR_INSERTION.include?(@db.last_item_status)

      @db.insert_item(start_time, tag, notes)
    end

    def field_value(item, field)
      if %w[start end].include?(field)
        TimeHelper.timestamp_to_time(item[FIELD_INDEX[field]])
      else
        item[FIELD_INDEX[field]]
      end
    end

    def validate_and_update(item, field, new_value)
      id = item[0]
      if %w[start end].include?(field)
        begin
          return if new_value.nil?

          filter_value = TimeHelper.format_time_string(new_value)
          value = Time.at(item[FIELD_INDEX[field]]).to_s.split
          value[1] = filter_value
          new_date = DateTime.strptime(value.join(' '), '%Y-%m-%d %H:%M:%S %z').to_time
          new_value = new_date.to_i

          item_value_start = item[FIELD_INDEX['start']]
          item_value_end = item[FIELD_INDEX['end']]

          item_before_value = if @db.find_item(id - 1)
                                @db.find_item(id - 1)[FIELD_INDEX['end']]
                              else
                                @db.find_item(id)[FIELD_INDEX['start']]
                              end

          item_after_value = if @db.find_item(id + 1)
                               @db.find_item(id + 1)[FIELD_INDEX['start']]
                             else
                               current_timestamp
                             end

          condition_start = field == 'start' && new_value >= item_before_value && new_value <= item_value_end
          condition_end = field == 'end' && new_value >= item_value_start && new_value <= item_after_value

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

    def delete_item_and_print_message(id, message)
      @db.delete_item(id)
      puts message
    end
  end
end
