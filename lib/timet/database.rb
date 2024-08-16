# frozen_string_literal: true

require "sqlite3"

module Timet
  # Provides database access for managing time tracking data.
  class Database
    def initialize(database_path = "#{Dir.home}/.timet.db")
      @db = SQLite3::Database.new(database_path)
      create_table
    end

    # Creates the items table if it doesn't already exist
    def create_table
      execute_sql(<<-SQL)
        CREATE TABLE IF NOT EXISTS items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start INTEGER,
          end INTEGER,
          tag TEXT
        );
      SQL
    end

    # Inserts a new item into the items table
    def insert_item(start, tag)
      execute_sql("INSERT INTO items (start, tag) VALUES (?, ?)", [start, tag])
    end

    # Updates the end time of the last item
    def update(stop)
      last_id = fetch_last_id
      return unless last_id

      execute_sql("UPDATE items SET end = ? WHERE id = ?", [stop, last_id])
    end

    # Fetches the ID of the last inserted item
    def fetch_last_id
      result = execute_sql("SELECT id FROM items ORDER BY id DESC LIMIT 1").first
      result ? result[0] : nil
    end

    def last_item
      execute_sql("SELECT * FROM items ORDER BY id DESC LIMIT 1").first
    end

    def item_status
      result = execute_sql("SELECT id, end FROM items ORDER BY id DESC LIMIT 1")
      StatusHelper.determine_status(result)
    end

    # Calculates the total time elapsed since the last recorded time.
    def total_time
      last_item = execute_sql("SELECT * FROM items ORDER BY id DESC LIMIT 1").first
      return "00:00:00" unless last_item

      start_time = last_item[1]
      end_time = last_item[2]

      total_seconds = end_time ? end_time - start_time : Time.now.to_i - start_time
      seconds_to_hms(total_seconds)
    end

    def all_items(_tag = nil)
      execute_sql("SELECT * FROM items where start >= '#{Date.today.to_time.to_i}' ORDER BY id DESC")
    end

    # Executes a SQL query and returns the result
    def execute_sql(sql, params = [])
      @db.execute(sql, params)
    rescue SQLite3::SQLException => e
      puts "Error: #{e.message}"
      []
    end

    # Closes the database connection
    def close
      @db&.close
    end

    # Converts a given number of seconds into a human-readable HH:MM:SS format.
    def seconds_to_hms(seconds)
      hours, remainder = seconds.divmod(3600)
      minutes, seconds = remainder.divmod(60)

      format "%<hours>02d:%<minutes>02d:%<seconds>02d", hours: hours, minutes: minutes, seconds: seconds
    end
  end
end
