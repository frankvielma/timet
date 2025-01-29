# frozen_string_literal: true

require 'aws-sdk-s3'
require 'logger'
require 'dotenv'
require 'fileutils'

# The module includes several components:
# - S3 integration for data backup and sync
#
module Timet
  # Required environment variables for S3 configuration
  REQUIRED_ENV_VARS = %w[S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY].freeze

  # Ensures that the environment file exists and contains the required variables.
  # If the file doesn't exist, it creates it. If required variables are missing,
  # it adds them with empty values.
  #
  # @param env_file_path [String] The path to the environment file
  # @return [void]
  # @example
  #   Timet.ensure_env_file_exists('/path/to/.env')
  def self.ensure_env_file_exists(env_file_path)
    dir_path = File.dirname(env_file_path)
    FileUtils.mkdir_p(dir_path)

    # Create file if it doesn't exist or is empty
    File.write(env_file_path, '', mode: 'a')

    # Load and check environment variables
    Dotenv.load(env_file_path)
    missing_vars = REQUIRED_ENV_VARS.reject { |var| ENV.fetch(var, nil) }

    # Append missing variables with empty values
    return if missing_vars.empty?

    File.write(env_file_path, "#{missing_vars.map { |var| "#{var}=''" }.join("\n")}\n", mode: 'a')
  end

  # S3Supabase is a class that provides methods to interact with an S3-compatible
  # storage service. It encapsulates common operations such as creating a bucket,
  # listing objects, uploading and downloading files, deleting objects, and
  # deleting a bucket.
  #
  # This class requires the following environment variables to be set:
  # - S3_ENDPOINT: The endpoint URL for the S3-compatible storage service.
  # - S3_ACCESS_KEY: The access key ID for authentication.
  # - S3_SECRET_KEY: The secret access key for authentication.
  # - S3_REGION: The region for the S3-compatible storage service (default: 'us-west-1').
  #
  # @example Basic usage
  #   s3_supabase = S3Supabase.new
  #   s3_supabase.create_bucket('my-bucket')
  #   s3_supabase.upload_file('my-bucket', '/path/to/local/file.txt', 'file.txt')
  #
  # @example Advanced operations
  #   s3_supabase.list_objects('my-bucket')
  #   s3_supabase.download_file('my-bucket', 'file.txt', '/path/to/download/file.txt')
  #   s3_supabase.delete_object('my-bucket', 'file.txt')
  #   s3_supabase.delete_bucket('my-bucket')
  class S3Supabase
    ENV_FILE_PATH = File.join(Dir.home, '.timet', '.env')
    Timet.ensure_env_file_exists(ENV_FILE_PATH)
    Dotenv.load(ENV_FILE_PATH)

    S3_ENDPOINT = ENV.fetch('S3_ENDPOINT', nil)
    S3_ACCESS_KEY = ENV.fetch('S3_ACCESS_KEY', nil)
    S3_SECRET_KEY = ENV.fetch('S3_SECRET_KEY', nil)
    S3_REGION = ENV.fetch('S3_REGION', 'us-west-1')
    LOG_FILE_PATH = File.join(Dir.home, '.timet', 's3_supabase.log')

    # Initializes a new instance of the S3Supabase class.
    # Sets up the AWS S3 client with the configured credentials and endpoint.
    #
    # @raise [CustomError] If required environment variables are missing
    def initialize
      validate_env_vars
      @logger = Logger.new(LOG_FILE_PATH)
      @logger.level = Logger::INFO
      @s3_client = Aws::S3::Client.new(
        region: S3_REGION,
        access_key_id: S3_ACCESS_KEY,
        secret_access_key: S3_SECRET_KEY,
        endpoint: S3_ENDPOINT,
        force_path_style: true
      )
    end

    # Creates a new bucket in the S3-compatible storage service.
    #
    # @param bucket_name [String] The name of the bucket to create
    # @return [Boolean] true if bucket was created successfully, false otherwise
    # @example
    #   create_bucket('my-new-bucket')
    def create_bucket(bucket_name)
      begin
        @s3_client.create_bucket(bucket: bucket_name)
        @logger.info "Bucket '#{bucket_name}' created successfully!"
        return true
      rescue Aws::S3::Errors::BucketAlreadyExists
        @logger.error "Error: The bucket '#{bucket_name}' already exists."
      rescue Aws::S3::Errors::BucketAlreadyOwnedByYou
        @logger.error "Error: The bucket '#{bucket_name}' is already owned by you."
      rescue Aws::S3::Errors::ServiceError => e
        @logger.error "Error creating bucket: #{e.message}"
      end
      false
    end

    # Lists all objects in the specified bucket.
    #
    # @param bucket_name [String] The name of the bucket to list objects from
    # @return [Array<Hash>, false, nil] Array of object hashes if objects found, false if bucket is empty,
    # nil if error occurs
    # @raise [Aws::S3::Errors::ServiceError] if there's an error accessing the S3 service
    # @example
    #   list_objects('my-bucket') #=> [{key: 'example.txt', last_modified: '2023-01-01', ...}, ...]
    #   list_objects('empty-bucket') #=> false
    #   list_objects('invalid-bucket') #=> nil
    def list_objects(bucket_name)
      response = @s3_client.list_objects_v2(bucket: bucket_name)
      if response.contents.empty?
        @logger.info "No objects found in '#{bucket_name}'."
        false
      else
        @logger.info "Objects in '#{bucket_name}':"
        response.contents.each { |object| @logger.info "- #{object.key} (Last modified: #{object.last_modified})" }
        response.contents.map(&:to_h)
      end
    rescue Aws::S3::Errors::ServiceError => e
      @logger.error "Error listing objects: #{e.message}"
      nil
    end

    # Uploads a file to the specified bucket.
    #
    # @param bucket_name [String] The name of the bucket to upload to
    # @param file_path [String] The local path of the file to upload
    # @param object_key [String] The key (name) to give the object in the bucket
    # @return [void]
    # @example
    #   upload_file('my-bucket', '/path/to/local/file.txt', 'remote-file.txt')
    def upload_file(bucket_name, file_path, object_key)
      @s3_client.put_object(
        bucket: bucket_name,
        key: object_key,
        body: File.open(file_path, 'rb')
      )
      @logger.info "File '#{object_key}' uploaded successfully."
    rescue Aws::S3::Errors::ServiceError => e
      @logger.error "Error uploading file: #{e.message}"
    end

    # Downloads a file from the specified bucket.
    #
    # @param bucket_name [String] The name of the bucket to download from
    # @param object_key [String] The key of the object to download
    # @param download_path [String] The local path where the file should be saved
    # @return [void]
    # @example
    #   download_file('my-bucket', 'remote-file.txt', '/path/to/local/file.txt')
    def download_file(bucket_name, object_key, download_path)
      response = @s3_client.get_object(bucket: bucket_name, key: object_key)
      File.binwrite(download_path, response.body.read)
      @logger.info "File '#{object_key}' downloaded successfully."
    rescue Aws::S3::Errors::ServiceError => e
      @logger.error "Error downloading file: #{e.message}"
    end

    # Deletes an object from the specified bucket.
    #
    # @param bucket_name [String] The name of the bucket containing the object
    # @param object_key [String] The key of the object to delete
    # @return [void]
    # @example
    #   delete_object('my-bucket', 'file-to-delete.txt')
    def delete_object(bucket_name, object_key)
      @s3_client.delete_object(bucket: bucket_name, key: object_key)
      @logger.info "Object '#{object_key}' deleted successfully."
    rescue Aws::S3::Errors::ServiceError => e
      @logger.error "Error deleting object: #{e.message}"
    end

    # Deletes a bucket and all its contents.
    # First deletes all objects in the bucket, then deletes the bucket itself.
    #
    # @param bucket_name [String] The name of the bucket to delete
    # @return [void]
    # @example
    #   delete_bucket('bucket-to-delete')
    def delete_bucket(bucket_name)
      list_objects(bucket_name)
      @s3_client.list_objects_v2(bucket: bucket_name).contents.each do |object|
        delete_object(bucket_name, object.key)
      end
      @s3_client.delete_bucket(bucket: bucket_name)
      @logger.info "Bucket '#{bucket_name}' deleted successfully."
    rescue Aws::S3::Errors::ServiceError => e
      @logger.error "Error deleting bucket: #{e.message}"
    end

    private

    # Validates that all required environment variables are present and non-empty.
    #
    # @raise [CustomError] If any required environment variables are missing
    # @return [void]
    def validate_env_vars
      missing_vars = []
      missing_vars << 'S3_ENDPOINT' if S3_ENDPOINT.nil? || S3_ENDPOINT.empty?
      missing_vars << 'S3_ACCESS_KEY' if S3_ACCESS_KEY.nil? || S3_ACCESS_KEY.empty?
      missing_vars << 'S3_SECRET_KEY' if S3_SECRET_KEY.nil? || S3_SECRET_KEY.empty?

      puts "DEBUG: Missing vars: #{missing_vars.inspect}"

      return if missing_vars.empty?

      raise CustomError, "Missing required environment variables (.env): #{missing_vars.join(', ')}"
    end

    # Custom error class that suppresses the backtrace for cleaner error messages.
    #
    # @example
    #   raise CustomError, "Missing required environment variables"
    class CustomError < StandardError
      def backtrace
        nil
      end
    end
  end
end
