# frozen_string_literal: true

require "sqlite3"
module Timet
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

    # Executes a SQL query and returns the result
    def execute_sql(sql, params = [])
      @db.execute(sql, params)
    rescue SQLite3::Error => e
      puts "Error: #{e.message}"
      []
    end

    # Closes the database connection
    def close
      @db&.close
    end
  end
end
