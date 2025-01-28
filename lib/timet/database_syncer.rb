# frozen_string_literal: true

module Timet
  # Module responsible for synchronizing local and remote databases
  module DatabaseSyncer
    # Fields used in item operations
    ITEM_FIELDS = %w[start end tag notes pomodoro updated_at created_at deleted].freeze

    # Handles the synchronization process when differences are detected between databases
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param remote_storage [S3Supabase] The remote storage client for cloud operations
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @param remote_path [String] Path to the downloaded remote database file
    # @return [void]
    # @note This method attempts to sync the databases and handles any errors that occur during the process
    def handle_database_differences(*args)
      local_db, remote_storage, bucket, local_db_path, remote_path = args
      puts 'Differences detected between local and remote databases'
      begin
        sync_with_remote_database(local_db, remote_path, remote_storage, bucket, local_db_path)
      rescue SQLite3::Exception => e
        handle_sync_error(e, remote_storage, bucket, local_db_path)
      end
    end

    # Handles errors that occur during database synchronization
    #
    # @param error [SQLite3::Exception] The error that occurred during sync
    # @param remote_storage [S3Supabase] The remote storage client for cloud operations
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @return [void]
    # @note When sync fails, this method falls back to uploading the local database
    def handle_sync_error(error, remote_storage, bucket, local_db_path)
      puts "Error opening remote database: #{error.message}"
      puts 'Uploading local database to replace corrupted remote database'
      remote_storage.upload_file(bucket, local_db_path, 'timet.db')
    end

    # Performs the actual database synchronization by setting up connections and syncing data
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param remote_path [String] Path to the remote database file
    # @param remote_storage [S3Supabase] The remote storage client for cloud operations
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @return [void]
    # @note Configures both databases to return results as hashes for consistent data handling
    def sync_with_remote_database(*args)
      local_db, remote_path, remote_storage, bucket, local_db_path = args
      db_remote = open_remote_database(remote_path)
      db_remote.results_as_hash = true
      local_db.instance_variable_get(:@db).results_as_hash = true
      sync_databases(local_db, db_remote, remote_storage, bucket, local_db_path)
    end

    # Opens and validates a connection to the remote database
    #
    # @param remote_path [String] Path to the remote database file
    # @return [SQLite3::Database] The initialized database connection
    # @raise [RuntimeError] If the database connection cannot be established
    # @note Validates that the database connection is properly initialized
    def open_remote_database(remote_path)
      db_remote = SQLite3::Database.new(remote_path)
      raise 'Failed to initialize remote database' unless db_remote

      db_remote
    end

    # Synchronizes the local and remote databases by comparing and merging their items
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param remote_db [SQLite3::Database] The remote database connection
    # @param remote_storage [S3Supabase] The remote storage client for cloud operations
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @return [void]
    # @note This method orchestrates the entire database synchronization process
    def sync_databases(*args)
      local_db, remote_db, remote_storage, bucket, local_db_path = args
      process_database_items(local_db, remote_db)
      remote_storage.upload_file(bucket, local_db_path, 'timet.db')
      puts 'Database sync completed'
    end

    # Processes items from both databases and syncs them
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param remote_db [SQLite3::Database] The remote database connection
    # @return [void]
    def process_database_items(local_db, remote_db)
      remote_items = remote_db.execute('SELECT * FROM items ORDER BY updated_at DESC')
      local_items = local_db.execute_sql('SELECT * FROM items ORDER BY updated_at DESC')

      sync_items_by_id(
        local_db,
        items_to_hash(local_items),
        items_to_hash(remote_items)
      )
    end

    # Syncs items between local and remote databases based on their IDs
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param local_items_by_id [Hash] Local items indexed by ID
    # @param remote_items_by_id [Hash] Remote items indexed by ID
    # @return [void]
    def sync_items_by_id(local_db, local_items_by_id, remote_items_by_id)
      all_item_ids = (remote_items_by_id.keys + local_items_by_id.keys).uniq

      all_item_ids.each do |id|
        if !remote_items_by_id[id]
          puts "Local item #{id} will be uploaded"
        elsif !local_items_by_id[id]
          puts "Adding remote item #{id} to local"
          insert_item_from_hash(local_db, remote_items_by_id[id])
        else
          process_existing_item(id, local_items_by_id[id], remote_items_by_id[id], local_db)
        end
      end
    end

    # Inserts a new item into the database from a hash
    #
    # @param db [SQLite3::Database] The database connection
    # @param item [Hash] Hash containing item data
    # @return [void]
    def insert_item_from_hash(db, item)
      fields = ['id', *ITEM_FIELDS].join(', ')
      placeholders = Array.new(ITEM_FIELDS.length + 1, '?').join(', ')
      db.execute_sql(
        "INSERT INTO items (#{fields}) VALUES (#{placeholders})",
        get_item_values(item, include_id_at_start: true)
      )
    end

    # Processes an item that exists in both databases
    #
    # @param id [Integer] Item ID
    # @param local_item [Hash] Local database item
    # @param remote_item [Hash] Remote database item
    # @param local_db [SQLite3::Database] Local database connection
    # @return [Symbol] :local_update if local was updated, :remote_update if remote needs update
    def process_existing_item(*args)
      id, local_item, remote_item, local_db = args
      local_time = local_item['updated_at'].to_i
      remote_time = remote_item['updated_at'].to_i

      if remote_wins?(remote_item, remote_time, local_time)
        puts format_status_message(id, remote_item, 'Remote')
        update_item_from_hash(local_db, remote_item)
        :local_update
      elsif local_time > remote_time
        puts format_status_message(id, local_item, 'Local')
        :remote_update
      end
    end

    # Converts database items to a hash indexed by ID
    #
    # @param items [Array<Hash>] Array of database items
    # @return [Hash] Items indexed by ID
    def items_to_hash(items)
      items.to_h { |item| [item['id'], item] }
    end

    # Determines if remote item should take precedence
    #
    # @param remote_item [Hash] Remote database item
    # @param remote_time [Integer] Remote item timestamp
    # @param local_time [Integer] Local item timestamp
    # @return [Boolean] true if remote item should take precedence
    def remote_wins?(remote_item, remote_time, local_time)
      remote_time > local_time && (remote_item['deleted'].to_i == 1 || remote_time > local_time)
    end

    # Formats item status message
    #
    # @param id [Integer] Item ID
    # @param item [Hash] Database item
    # @param source [String] Source of the item ('Remote' or 'Local')
    # @return [String] Formatted status message
    def format_status_message(id, item, source)
      deleted = item['deleted'].to_i == 1 ? ' and deleted' : ''
      "#{source} item #{id} is newer#{deleted} - #{source == 'Remote' ? 'updating local' : 'will be uploaded'}"
    end

    # Updates an existing item in the database with values from a hash
    #
    # @param db [SQLite3::Database] The database connection
    # @param item [Hash] Hash containing item data
    # @return [void]
    def update_item_from_hash(db, item)
      fields = "#{ITEM_FIELDS.join(' = ?, ')} = ?"
      db.execute_sql(
        "UPDATE items SET #{fields} WHERE id = ?",
        get_item_values(item)
      )
    end

    # Gets the values array for database operations
    #
    # @param item [Hash] Hash containing item data
    # @param include_id [Boolean] Whether to include ID at start (insert) or end (update)
    # @return [Array] Array of values for database operation
    def get_item_values(item, include_id_at_start: false)
      values = ITEM_FIELDS.map { |field| item[field] }
      include_id_at_start ? [item['id'], *values] : [*values, item['id']]
    end
  end
end
