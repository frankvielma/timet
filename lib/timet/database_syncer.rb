# frozen_string_literal: true

module Timet
  # Module responsible for synchronizing local and remote databases
  module DatabaseSyncer
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
  end
end
