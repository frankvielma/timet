# frozen_string_literal: true

require 'sqlite3'

module Timet
  # Provides database access for managing time tracking data.
  class Database
    DEFAULT_DATABASE_PATH = File.join(Dir.home, '.timet.db')

    def initialize(database_path = DEFAULT_DATABASE_PATH)
      @db = SQLite3::Database.new(database_path)
      create_table
      add_notes
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

    # Adds a new column named "notes" to the "items" table if it doesn't exist.
    def add_notes
      table_name = 'items'
      new_column_name = 'notes'
      result = execute_sql("SELECT count(*) FROM pragma_table_info('items') where name='#{new_column_name}'")
      column_exists = result[0][0].positive?
      return if column_exists

      execute_sql("ALTER TABLE #{table_name} ADD COLUMN #{new_column_name} TEXT")
      puts "Column '#{new_column_name}' added to table '#{table_name}'."
    end

    # Inserts a new item into the items table
    def insert_item(start, tag, notes)
      execute_sql('INSERT INTO items (start, tag, notes) VALUES (?, ?, ?)', [start, tag, notes])
    end

    # Updates the end time of the last item
    def update(stop)
      last_id = fetch_last_id
      return unless last_id

      execute_sql('UPDATE items SET end = ? WHERE id = ?', [stop, last_id])
    end

    def delete_item(id)
      execute_sql("DELETE FROM items WHERE id = #{id}")
    end

    def update_item(id, field, value)
      execute_sql("UPDATE items SET #{field}='#{value}' WHERE id = #{id}")
    end

    # Fetches the ID of the last inserted item
    def fetch_last_id
      result = execute_sql('SELECT id FROM items ORDER BY id DESC LIMIT 1').first
      result ? result[0] : nil
    end

    def last_item
      execute_sql('SELECT * FROM items ORDER BY id DESC LIMIT 1').first
    end

    def last_item_status
      result = execute_sql('SELECT id, end FROM items ORDER BY id DESC LIMIT 1')
      StatusHelper.determine_status(result)
    end

    def find_item(id)
      execute_sql("select * from items where id=#{id}").first
    end

    # Calculates the total time elapsed since the last recorded time.
    def total_time
      last_item = execute_sql('SELECT * FROM items ORDER BY id DESC LIMIT 1').first
      return '00:00:00' unless last_item

      start_time = last_item[1]
      end_time = last_item[2]

      total_seconds = end_time ? end_time - start_time : Time.now.to_i - start_time
      seconds_to_hms(total_seconds)
    end

    def all_items
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

      format '%<hours>02d:%<minutes>02d:%<seconds>02d', hours: hours, minutes: minutes, seconds: seconds
    end
  end
end
