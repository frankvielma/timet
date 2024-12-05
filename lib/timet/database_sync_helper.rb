# frozen_string_literal: true

require 'tempfile'
require 'digest'

module Timet
  # Helper module for database synchronization operations
  # Provides methods for comparing and syncing local and remote databases
  module DatabaseSyncHelper
    # Main entry point for database synchronization
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param bucket [String] The S3 bucket name
    # @return [void]
    # @note This method initiates the database synchronization process by checking for the presence of a remote database
    def self.sync(local_db, bucket)
      remote_storage = S3Supabase.new
      remote_storage.create_bucket(bucket)

      objects = remote_storage.list_objects(bucket)
      if objects&.any? { |obj| obj[:key] == 'timet.db' }
        process_remote_database(local_db, remote_storage, bucket, Timet::Database::DEFAULT_DATABASE_PATH)
      else
        puts 'No remote database found, uploading local database'
        remote_storage.upload_file(bucket, Timet::Database::DEFAULT_DATABASE_PATH, 'timet.db')
      end
    end

    # Processes the remote database by comparing it with the local database and syncing changes
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param remote_storage [S3Supabase] The remote storage client for cloud operations
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @return [void]
    # @note This method orchestrates the entire sync process by downloading the remote database,
    #   comparing it with the local database, and handling any differences found
    def self.process_remote_database(local_db, remote_storage, bucket, local_db_path)
      with_temp_file do |temp_file|
        remote_storage.download_file(bucket, 'timet.db', temp_file.path)

        if databases_are_in_sync?(temp_file.path, local_db_path)
          puts 'Local database is up to date'
        else
          handle_database_differences(local_db, remote_storage, bucket, local_db_path, temp_file.path)
        end
      end
    end

    # Creates a temporary file and ensures it is properly cleaned up after use
    #
    # @yield [Tempfile] The temporary file object to use
    # @return [void]
    # @note This method ensures proper resource cleanup by using ensure block
    def self.with_temp_file
      temp_file = Tempfile.new('remote_db')
      yield temp_file
    ensure
      temp_file.close
      temp_file.unlink
    end

    # Compares two database files to check if they are identical
    #
    # @param remote_path [String] Path to the remote database file
    # @param local_path [String] Path to the local database file
    # @return [Boolean] true if databases are identical, false otherwise
    # @note Uses MD5 hashing to compare file contents
    def self.databases_are_in_sync?(remote_path, local_path)
      remote_md5 = Digest::MD5.file(remote_path).hexdigest
      local_md5 = Digest::MD5.file(local_path).hexdigest
      remote_md5 == local_md5
    end

    # Handles the synchronization process when differences are detected between databases
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param remote_storage [S3Supabase] The remote storage client for cloud operations
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @param remote_path [String] Path to the downloaded remote database file
    # @return [void]
    # @note This method attempts to sync the databases and handles any errors that occur during the process
    def self.handle_database_differences(local_db, remote_storage, bucket, local_db_path, remote_path)
      puts 'Differences detected between local and remote databases'
      begin
        sync_with_remote_database(local_db, remote_path, remote_storage, bucket, local_db_path)
      rescue SQLite3::Exception => e
        handle_sync_error(e, remote_storage, bucket, local_db_path)
      end
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
    def self.sync_with_remote_database(local_db, remote_path, remote_storage, bucket, local_db_path)
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
    def self.open_remote_database(remote_path)
      db_remote = SQLite3::Database.new(remote_path)
      raise 'Failed to initialize remote database' unless db_remote

      db_remote
    end

    # Handles errors that occur during database synchronization
    #
    # @param error [SQLite3::Exception] The error that occurred during sync
    # @param remote_storage [S3Supabase] The remote storage client for cloud operations
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @return [void]
    # @note When sync fails, this method falls back to uploading the local database
    def self.handle_sync_error(error, remote_storage, bucket, local_db_path)
      puts "Error opening remote database: #{error.message}"
      puts 'Uploading local database to replace corrupted remote database'
      remote_storage.upload_file(bucket, local_db_path, 'timet.db')
    end

    # Converts database items to a hash indexed by ID
    #
    # @param items [Array<Hash>] Array of database items
    # @return [Hash] Items indexed by ID
    def self.items_to_hash(items)
      items.to_h { |item| [item['id'], item] }
    end

    # Processes an item that exists in both databases
    #
    # @param id [Integer] Item ID
    # @param local_item [Hash] Local database item
    # @param remote_item [Hash] Remote database item
    # @param local_db [SQLite3::Database] Local database connection
    def self.process_existing_item(id, local_item, remote_item, local_db)
      local_time = local_item['updated_at'].to_i
      remote_time = remote_item['updated_at'].to_i

      # Handle deleted items
      if remote_item['deleted'].to_i == 1 && remote_time > local_time
        puts "Remote item #{id} is marked as deleted - updating local"
        update_item_from_hash(local_db, remote_item)
      elsif local_item['deleted'].to_i == 1 && local_time > remote_time
        puts "Local item #{id} is marked as deleted - will be uploaded"
      elsif local_time > remote_time
        puts "Local item #{id} is newer - will be uploaded"
      elsif local_time < remote_time
        puts "Remote item #{id} is newer - updating local"
        update_item_from_hash(local_db, remote_item)
      end
    end

    # Processes items from both databases and syncs them
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param remote_db [SQLite3::Database] The remote database connection
    # @return [void]
    def self.process_database_items(local_db, remote_db)
      remote_items = remote_db.execute('SELECT * FROM items ORDER BY updated_at DESC')
      local_items = local_db.execute_sql('SELECT * FROM items ORDER BY updated_at DESC')

      remote_by_id = items_to_hash(remote_items)
      local_by_id = items_to_hash(local_items)
      all_ids = (remote_by_id.keys + local_by_id.keys).uniq

      all_ids.each do |id|
        remote_item = remote_by_id[id]
        local_item = local_by_id[id]

        if remote_item && local_item
          process_existing_item(id, local_item, remote_item, local_db)
        elsif remote_item
          puts "Adding remote item #{id} to local"
          insert_item_from_hash(local_db, remote_item)
        else # local_item exists
          puts "Local item #{id} will be uploaded"
        end
      end
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
    def self.sync_databases(local_db, remote_db, remote_storage, bucket, local_db_path)
      process_database_items(local_db, remote_db)
      remote_storage.upload_file(bucket, local_db_path, 'timet.db')
      puts 'Database sync completed'
    end

    # Updates an existing item in the database with values from a hash
    #
    # @param db [SQLite3::Database] The database connection
    # @param item [Hash] Hash containing item data
    # @return [void]
    def self.update_item_from_hash(db, item)
      db.execute_sql(
        'UPDATE items SET start = ?, end = ?, tag = ?, notes = ?, pomodoro = ?, updated_at = ?, created_at = ?, deleted = ? WHERE id = ?',
        [item['start'], item['end'], item['tag'], item['notes'], item['pomodoro'], item['updated_at'],
         item['created_at'], item['deleted'], item['id']]
      )
    end

    # Inserts a new item into the database from a hash
    #
    # @param db [SQLite3::Database] The database connection
    # @param item [Hash] Hash containing item data
    # @return [void]
    def self.insert_item_from_hash(db, item)
      db.execute_sql(
        'INSERT INTO items (id, start, end, tag, notes, pomodoro, updated_at, created_at, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [item['id'], item['start'], item['end'], item['tag'], item['notes'], item['pomodoro'], item['updated_at'],
         item['created_at'], item['deleted']]
      )
    end
  end
end
