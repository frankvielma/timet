# frozen_string_literal: true

require 'aws-sdk-s3'
require 'logger'
require 'dotenv'
require 'fileutils'

module Timet
  def self.ensure_env_file_exists(env_file_path)
    # Ensure the file exists
    FileUtils.mkdir_p(File.dirname(env_file_path)) unless File.exist?(env_file_path)
    File.write(env_file_path, '') unless File.size?(env_file_path)

    # Load the environment variables from the file
    Dotenv.load(env_file_path)

    # Check if required environment variables are present
    required_vars = %w[S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY]
    missing_vars = required_vars.select { |var| ENV[var].nil? }

    return unless missing_vars.any?

    File.open(env_file_path, 'a') do |file|
      missing_vars.each do |var|
        file.puts("#{var}=''")
      end
    end
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
  # Example usage:
  #   s3_supabase = S3Supabase.new
  #   s3_supabase.create_bucket('my-bucket')
  #   s3_supabase.upload_file('my-bucket', '/path/to/local/file.txt', 'file.txt')
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

    # Function to create a bucket
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

    # List objects in a bucket
    def list_objects(bucket_name)
      response = @s3_client.list_objects_v2(bucket: bucket_name)
      if response.contents.empty?
        @logger.info "No objects found in '#{bucket_name}'."
        false
      else
        @logger.info "Objects in '#{bucket_name}':"
        response.contents.each { |object| @logger.info "- #{object.key} (Last modified: #{object.last_modified})" }
        response.contents
      end
    rescue Aws::S3::Errors::ServiceError => e
      @logger.error "Error listing objects: #{e.message}"
    end

    # Upload a file to a bucket
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

    # Download a file from a bucket
    def download_file(bucket_name, object_key, download_path)
      response = @s3_client.get_object(bucket: bucket_name, key: object_key)
      File.binwrite(download_path, response.body.read)
      @logger.info "File '#{object_key}' downloaded successfully."
    rescue Aws::S3::Errors::ServiceError => e
      @logger.error "Error downloading file: #{e.message}"
    end

    # Delete an object from a bucket
    def delete_object(bucket_name, object_key)
      @s3_client.delete_object(bucket: bucket_name, key: object_key)
      @logger.info "Object '#{object_key}' deleted successfully."
    rescue Aws::S3::Errors::ServiceError => e
      @logger.error "Error deleting object: #{e.message}"
    end

    # Delete a bucket
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

    def validate_env_vars
      missing_vars = []
      missing_vars << 'S3_ENDPOINT' if S3_ENDPOINT.empty?
      missing_vars << 'S3_ACCESS_KEY' if S3_ACCESS_KEY.empty?
      missing_vars << 'S3_SECRET_KEY' if S3_SECRET_KEY.empty?

      return if missing_vars.empty?

      error_message = "Missing required environment variables (.env): #{missing_vars.join(', ')}"
      raise CustomError, error_message
    end

    class CustomError < StandardError
      def backtrace
        nil
      end
    end
  end
end
