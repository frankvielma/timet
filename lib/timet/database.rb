# frozen_string_literal: true

require 'fileutils'
require 'sqlite3'
module Timet
  # Provides database access for managing time tracking data.
  class Database
    # The default path to the SQLite database file.
    DEFAULT_DATABASE_PATH = File.join(Dir.home, '.timet', 'timet.db')

    # Initializes a new instance of the Database class.
    #
    # @param database_path [String] The path to the SQLite database file. Defaults to DEFAULT_DATABASE_PATH.
    #
    # @return [void] This method does not return a value; it performs side effects such as initializing the database
    # connection and creating the necessary tables.
    #
    # @example Initialize a new Database instance with the default path
    #   Database.new
    #
    # @example Initialize a new Database instance with a custom path
    #   Database.new('/path/to/custom.db')
    #
    # @note The method creates a new SQLite3 database connection and initializes the necessary tables if they
    # do not already exist.
    def initialize(database_path = DEFAULT_DATABASE_PATH)
      move_old_database_file(database_path)

      @db = SQLite3::Database.new(database_path)
      create_table

      add_column('items', 'notes', 'TEXT')
      add_column('items', 'pomodoro', 'INTEGER')
      add_column('items', 'updated_at', 'INTEGER')
      add_column('items', 'created_at', 'INTEGER')
      add_column('items', 'deleted', 'INTEGER')
      update_time_columns
    end

    # Creates the items table if it doesn't already exist.
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL to
    # create the table.
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

    # Adds a new column to the specified table if it does not already exist.
    #
    # @param table_name [String] The name of the table to which the column will be added.
    # @param new_column_name [String] The name of the new column to be added.
    # @param date_type [String] The data type of the new column (e.g., 'INTEGER', 'TEXT', 'BOOLEAN').
    # @return [void] This method does not return a value; it performs side effects such as adding the column and
    # printing a message.
    #
    # @example Add a new 'completed' column to the 'tasks' table
    #   add_column('tasks', 'completed', 'INTEGER')
    #
    # @note The method first checks if the column already exists in the table using `pragma_table_info`.
    # @note If the column exists, the method returns without making any changes.
    # @note If the column does not exist, the method executes an SQL `ALTER TABLE` statement to add the column.
    # @note The method prints a message indicating that the column has been added.
    def add_column(table_name, new_column_name, date_type)
      result = execute_sql("SELECT count(*) FROM pragma_table_info('items') where name='#{new_column_name}'")
      column_exists = result[0][0].positive?
      return if column_exists

      execute_sql("ALTER TABLE #{table_name} ADD COLUMN #{new_column_name} #{date_type}")
      puts "Column '#{new_column_name}' added to table '#{table_name}'."
    end

    # Inserts a new item into the items table.
    #
    # @param start [Integer] The start time of the item.
    # @param tag [String] The tag associated with the item.
    # @param notes [String] The notes associated with the item.
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL
    # to insert the item.
    #
    # @example Insert a new item into the items table
    #   insert_item(1633072800, 'work', 'Completed task X')
    #
    # @note The method executes SQL to insert a new row into the 'items' table.
    def insert_item(start, tag, notes, pomodoro = nil, updated_at = nil, created_at = nil)
      execute_sql('INSERT INTO items (start, tag, notes, pomodoro, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?)',
                  [start, tag, notes, pomodoro, updated_at, created_at])
    end

    # Updates an existing item in the items table.
    #
    # @param id [Integer] The ID of the item to be updated.
    # @param field [String] The field to be updated.
    # @param value [String, Integer, nil] The new value for the specified field.
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL
    # to update the item.
    #
    # @example Update the tag of an item with ID 1
    #   update_item(1, 'tag', 'updated_work')
    #
    # @note The method executes SQL to update the specified field of the item with the given ID.
    def update_item(id, field, value)
      return if %w[start end].include?(field) && value.nil?

      execute_sql("UPDATE items SET #{field}='#{value}', updated_at=#{Time.now.utc.to_i} WHERE id = #{id}")
    end

    # Deletes an item from the items table.
    #
    # @param id [Integer] The ID of the item to be deleted.
    #
    # @return [void] This method does not return a value; it performs side effects such as executing SQL
    # to delete the item.
    #
    # @example Delete an item with ID 1
    #   delete_item(1)
    #
    # @note The method executes SQL to delete the item with the given ID from the 'items' table.
    def delete_item(id)
      current_time = Time.now.to_i
      execute_sql('UPDATE items SET deleted = 1, updated_at = ? WHERE id = ?', [current_time, id])
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
      result = execute_sql('SELECT id FROM items WHERE deleted IS NULL OR deleted = 0 ORDER BY id DESC LIMIT 1')
      result.empty? ? nil : result[0][0]
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
      result = execute_sql('SELECT * FROM items WHERE deleted IS NULL OR deleted = 0 ORDER BY id DESC LIMIT 1')
      result.empty? ? nil : result[0]
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
      result = execute_sql('SELECT * FROM items WHERE id = ? AND (deleted IS NULL OR deleted = 0)', [id])
      result.empty? ? nil : result[0]
    end

    # Fetches all items from the items table that have a start time greater than or equal to today.
    #
    # @return [Array] An array of items.
    #
    # @example Fetch all items from today
    #   all_items
    #
    # @note The method executes SQL to fetch all items from the 'items' table that have a start time greater than
    # or equal to today.
    def all_items
      today = Time.now.to_i - (Time.now.to_i % 86_400)
      execute_sql('SELECT * FROM items WHERE start >= ? AND (deleted IS NULL OR deleted = 0) ORDER BY start DESC',
                  [today])
    end

    # Determines the status of the last item in the items table.
    #
    # @return [Symbol] The status of the last item. Possible values are :no_items, :in_progress, or :complete.
    #
    # @example Determine the status of the last item
    #   item_status
    #
    # @note The method executes SQL to fetch the last item and determines its status using the `StatusHelper` module.
    #
    # @param id [Integer, nil] The ID of the item to check. If nil, the last item in the table is used.
    #
    def item_status(id = nil)
      id = fetch_last_id if id.nil?
      determine_status(find_item(id))
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
    # @return [void] This method does not return a value; it performs side effects such as closing the
    # database connection.
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
    # @note The method converts the given number of seconds into hours, minutes, and seconds, and formats
    # them as HH:MM:SS.
    def seconds_to_hms(seconds)
      hours, remainder = seconds.divmod(3600)
      minutes, seconds = remainder.divmod(60)

      format '%<hours>02d:%<minutes>02d:%<seconds>02d', hours: hours, minutes: minutes, seconds: seconds
    end

    # Determines the status of a time tracking result based on the presence and end time of items.
    #
    # @param result [Array] The result set containing time tracking items.
    #
    # @return [Symbol] The status of the time tracking result. Possible values are
    # :no_items, :in_progress, or :complete.
    #
    # @example Determine the status of an empty result set
    #   StatusHelper.determine_status([]) # => :no_items
    #
    # @example Determine the status of a result set with an in-progress item
    #   StatusHelper.determine_status([[1, nil]]) # => :in_progress
    #
    # @example Determine the status of a result set with a completed item
    #   StatusHelper.determine_status([[1, 1633072800]]) # => :complete
    #
    # @note The method checks if the result set is empty and returns :no_items if true.
    # @note If the last item in the result set has no end time, it returns :in_progress.
    # @note If the last item in the result set has an end time, it returns :complete.
    def determine_status(result)
      return :no_items if result.nil?

      last_item_end = result[2]
      return :in_progress unless last_item_end

      :complete
    end

    private

    # Moves the old database file to the new location if it exists.
    #
    # @param database_path [String] The path to the new SQLite database file.
    def move_old_database_file(database_path)
      old_file = File.join(Dir.home, '.timet.db')
      return unless File.exist?(old_file)

      FileUtils.mkdir_p(File.dirname(database_path)) unless File.directory?(File.dirname(database_path))
      FileUtils.mv(old_file, database_path)
    end

    # Updates the `updated_at` and `created_at` columns for items where either of these columns is null.
    #
    # This method queries the database for items where the `updated_at` or `created_at` columns are null.
    # For each item found, it sets both the `updated_at` and `created_at` columns to the value of the `end_time` column.
    #
    # @note This method directly executes SQL queries on the database. Ensure that the `execute_sql` method is properly
    # defined and handles SQL injection risks.
    #
    # @return [void] This method does not return a value.
    #
    # @example
    #   update_time_columns
    #
    # @raise [StandardError] If there is an issue executing the SQL queries, an error may be raised.
    #
    def update_time_columns
      result = execute_sql('SELECT * FROM items where updated_at is null or created_at is null')
      result.each do |item|
        id = item[0]
        end_time = item[2]
        execute_sql("UPDATE items SET updated_at = #{end_time}, created_at = #{end_time} WHERE id = #{id}")
      end
    end
  end
end
