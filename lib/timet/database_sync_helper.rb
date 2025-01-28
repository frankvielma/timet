# frozen_string_literal: true

require 'tempfile'
require 'digest'
require_relative 'database_syncer'

module Timet
  # Helper module for database synchronization operations
  # Provides methods for comparing and syncing local and remote databases
  module DatabaseSyncHelper
    extend DatabaseSyncer

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
  end
end
