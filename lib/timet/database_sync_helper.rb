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
    def self.sync(local_db, bucket)
      s3 = S3Supabase.new
      s3.create_bucket(bucket)

      objects = s3.list_objects(bucket)
      if objects&.any? { |obj| obj[:key] == 'timet.db' }
        process_remote_database(local_db, s3, bucket, Timet::Database::DEFAULT_DATABASE_PATH)
      else
        puts 'No remote database found, uploading local database'
        s3.upload_file(bucket, Timet::Database::DEFAULT_DATABASE_PATH, 'timet.db')
      end
    end

    # Processes the remote database by comparing it with the local database and syncing changes
    #
    # @param local_db [SQLite3::Database] The local database connection
    # @param s3 [S3Supabase] The S3 client instance
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @return [void]
    def self.process_remote_database(local_db, s3, bucket, local_db_path)
      temp_file = Tempfile.new('remote_db')
      begin
        s3.download_file(bucket, 'timet.db', temp_file.path)
        remote_md5 = Digest::MD5.file(temp_file.path).hexdigest
        local_md5 = Digest::MD5.file(local_db_path).hexdigest

        if remote_md5 == local_md5
          puts 'Local database is up to date'
        else
          puts 'Differences detected between local and remote databases'
          begin
            db_remote = SQLite3::Database.new(temp_file.path)
            raise 'Failed to initialize remote database' unless db_remote

            db_remote.results_as_hash = true
            local_db.instance_variable_get(:@db).results_as_hash = true

            sync_databases(local_db, db_remote, s3, bucket, local_db_path)
          rescue SQLite3::Exception => e
            puts "Error opening remote database: #{e.message}"
            puts 'Uploading local database to replace corrupted remote database'
            s3.upload_file(bucket, local_db_path, 'timet.db')
          end
        end
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    # Converts database items to a hash indexed by ID
    # @param items [Array<Hash>] Array of database items
    # @return [Hash] Items indexed by ID
    def self.items_to_hash(items)
      items.to_h { |item| [item['id'], item] }
    end

    # Processes an item that exists in both databases
    # @param id [Integer] Item ID
    # @param local_item [Hash] Local database item
    # @param remote_item [Hash] Remote database item
    # @param local_db [SQLite3::Database] Local database connection
    def self.process_existing_item(id, local_item, remote_item, local_db)
      local_time = local_item['updated_at'].to_i
      remote_time = remote_item['updated_at'].to_i

      if local_time > remote_time
        puts "Local item #{id} is newer - will be uploaded"
      elsif local_time < remote_time
        puts "Remote item #{id} is newer - updating local"
        update_item_from_hash(local_db, remote_item)
      end
    end

    # Processes items from both databases and syncs them
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
    # @param s3 [S3Supabase] The S3 client instance
    # @param bucket [String] The S3 bucket name
    # @param local_db_path [String] Path to the local database file
    # @return [void]
    def self.sync_databases(local_db, remote_db, s3, bucket, local_db_path)
      process_database_items(local_db, remote_db)
      s3.upload_file(bucket, local_db_path, 'timet.db')
      puts 'Database sync completed'
    end

    # Updates an existing item in the database with values from a hash
    #
    # @param db [SQLite3::Database] The database connection
    # @param item [Hash] Hash containing item data
    # @return [void]
    def self.update_item_from_hash(db, item)
      db.execute(
        'UPDATE items SET start = ?, end = ?, tag = ?, notes = ?, pomodoro = ?, updated_at = ?, created_at = ? WHERE id = ?',
        [item['start'], item['end'], item['tag'], item['notes'], item['pomodoro'], item['updated_at'],
         item['created_at'], item['id']]
      )
    end

    # Inserts a new item into the database from a hash
    #
    # @param db [SQLite3::Database] The database connection
    # @param item [Hash] Hash containing item data
    # @return [void]
    def self.insert_item_from_hash(db, item)
      db.execute(
        'INSERT INTO items (id, start, end, tag, notes, pomodoro, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [item['id'], item['start'], item['end'], item['tag'], item['notes'], item['pomodoro'], item['updated_at'],
         item['created_at']]
      )
    end
  end
end
