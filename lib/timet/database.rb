# frozen_string_literal: true

require 'sqlite3'
require_relative 'status_helper'
module Timet
  # Provides database access for managing time tracking data.
  class Database
    include StatusHelper

    # The default path to the SQLite database file.
    DEFAULT_DATABASE_PATH = File.join(Dir.home, '.timet.db')

    # Initializes a new instance of the Database class.
    #
    # @param database_path [String] The path to the SQLite database file. Defaults to DEFAULT_DATABASE_PATH.
    #
    # @return [void] This method does not return a value; it performs side effects such as initializing the database connection and creating the necessary tables.
    #
    # @example Initialize a new Database instance with the default path
    #   Database.new
    #
    # @example Initialize a new Database instance with a custom path
    #   Database.new('/path/to/custom.db')
    #
    # @note The method creates a new SQLite3 database connection and initializes the necessary tables if they do not already exist.
    def initialize(database_path = DEFAULT_DATABASE_PATH)
      @db = SQLite3::Database.new(database_path)
      create_table
      add_notes
    end

    # Creates the items table if it doesn't already exist.
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL to create the table.
    #
    # @example Create the items table
    #   create_table
    #
    # @note The method executes SQL to create the 'items' table with columns for id, start, end, and tag.
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
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL to add the column.
    #
    # @example Add the notes column to the items table
    #   add_notes
    #
    # @note The method checks if the 'notes' column already exists and adds it if it does not.
    def add_notes
      table_name = 'items'
      new_column_name = 'notes'
      result = execute_sql("SELECT count(*) FROM pragma_table_info('items') where name='#{new_column_name}'")
      column_exists = result[0][0].positive?
      return if column_exists

      execute_sql("ALTER TABLE #{table_name} ADD COLUMN #{new_column_name} TEXT")
      puts "Column '#{new_column_name}' added to table '#{table_name}'."
    end

    # Inserts a new item into the items table.
    #
    # @param start [Integer] The start time of the item.
    # @param tag [String] The tag associated with the item.
    # @param notes [String] The notes associated with the item.
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL to insert the item.
    #
    # @example Insert a new item into the items table
    #   insert_item(1633072800, 'work', 'Completed task X')
    #
    # @note The method executes SQL to insert a new row into the 'items' table.
    def insert_item(start, tag, notes)
      execute_sql('INSERT INTO items (start, tag, notes) VALUES (?, ?, ?)', [start, tag, notes])
    end

    # Updates an existing item in the items table.
    #
    # @param id [Integer] The ID of the item to be updated.
    # @param field [String] The field to be updated.
    # @param value [String, Integer, nil] The new value for the specified field.
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL to update the item.
    #
    # @example Update the tag of an item with ID 1
    #   update_item(1, 'tag', 'updated_work')
    #
    # @note The method executes SQL to update the specified field of the item with the given ID.
    def update_item(id, field, value)
      return if %w[start end].include?(field) && value.nil?

      execute_sql("UPDATE items SET #{field}='#{value}' WHERE id = #{id}")
    end

    # Deletes an item from the items table.
    #
    # @param id [Integer] The ID of the item to be deleted.
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL to delete the item.
    #
    # @example Delete an item with ID 1
    #   delete_item(1)
    #
    # @note The method executes SQL to delete the item with the given ID from the 'items' table.
    def delete_item(id)
      execute_sql("DELETE FROM items WHERE id = #{id}")
    end

    # Fetches the ID of the last inserted item.
    #
    # @return [Integer, nil] The ID of the last inserted item, or nil if no items exist.
    #
    # @example Fetch the last inserted item ID
    #   fetch_last_id
    #
    # @note The method executes SQL to fetch the ID of the last inserted item.
    def fetch_last_id
      result = execute_sql('SELECT id FROM items ORDER BY id DESC LIMIT 1').first
      result ? result[0] : nil
    end

    # Fetches the last item from the items table.
    #
    # @return [Array, nil] The last item as an array, or nil if no items exist.
    #
    # @example Fetch the last item
    #   last_item
    #
    # @note The method executes SQL to fetch the last item from the 'items' table.
    def last_item
      execute_sql('SELECT * FROM items ORDER BY id DESC LIMIT 1').first
    end

    # Determines the status of the last item in the items table.
    #
    # @return [Symbol] The status of the last item. Possible values are :no_items, :in_progress, or :complete.
    #
    # @example Determine the status of the last item
    #   last_item_status
    #
    # @note The method executes SQL to fetch the last item and determines its status using the `StatusHelper` module.
    def last_item_status
      result = execute_sql('SELECT id, end FROM items ORDER BY id DESC LIMIT 1')
      StatusHelper.determine_status(result)
    end

    # Finds an item in the items table by its ID.
    #
    # @param id [Integer] The ID of the item to be found.
    #
    # @return [Array, nil] The item as an array, or nil if the item does not exist.
    #
    # @example Find an item with ID 1
    #   find_item(1)
    #
    # @note The method executes SQL to find the item with the given ID in the 'items' table.
    def find_item(id)
      execute_sql("select * from items where id=#{id}").first
    end

    # Fetches all items from the items table that have a start time greater than or equal to today.
    #
    # @return [Array] An array of items.
    #
    # @example Fetch all items from today
    #   all_items
    #
    # @note The method executes SQL to fetch all items from the 'items' table that have a start time greater than or equal to today.
    def all_items
      execute_sql("SELECT * FROM items where start >= '#{Date.today.to_time.to_i}' ORDER BY id DESC")
    end

    # Executes a SQL query and returns the result.
    #
    # @param sql [String] The SQL query to execute.
    # @param params [Array] The parameters to bind to the SQL query.
    #
    # @return [Array] The result of the SQL query.
    #
    # @example Execute a SQL query
    #   execute_sql('SELECT * FROM items WHERE id = ?', [1])
    #
    # @note The method executes the given SQL query with the provided parameters and returns the result.
    def execute_sql(sql, params = [])
      @db.execute(sql, params)
    rescue SQLite3::SQLException => e
      puts "Error: #{e.message}"
      []
    end

    # Closes the database connection.
    #
    # @return [void] This method does not return a value; it performs side effects such as closing the database connection.
    #
    # @example Close the database connection
    #   close
    #
    # @note The method closes the SQLite3 database connection.
    def close
      @db&.close
    end

    # Converts a given number of seconds into a human-readable HH:MM:SS format.
    #
    # @param seconds [Integer] The number of seconds to convert.
    #
    # @return [String] The formatted time in HH:MM:SS format.
    #
    # @example Convert 3661 seconds to HH:MM:SS format
    #   seconds_to_hms(3661) # => '01:01:01'
    #
    # @note The method converts the given number of seconds into hours, minutes, and seconds, and formats them as HH:MM:SS.
    def seconds_to_hms(seconds)
      hours, remainder = seconds.divmod(3600)
      minutes, seconds = remainder.divmod(60)

      format '%<hours>02d:%<minutes>02d:%<seconds>02d', hours: hours, minutes: minutes, seconds: seconds
    end
  end
end
