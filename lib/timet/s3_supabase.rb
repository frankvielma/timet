# frozen_string_literal: true

require 'aws-sdk-s3'
require 'logger'
require 'dotenv'
require 'fileutils'

# Top-level module for the Timet time tracking gem.
module Timet
  # Required environment variables for S3 configuration.
  REQUIRED_ENV_VARS = %w[S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY].freeze

  def self.ensure_env_file_exists(env_file_path)
    ensure_directory_exists(env_file_path)
    ensure_file_exists(env_file_path)
    append_missing_env_vars(env_file_path)
  end

  def self.ensure_directory_exists(env_file_path)
    dir_path = File.dirname(env_file_path)
    FileUtils.mkdir_p(dir_path)
  end

  def self.ensure_file_exists(env_file_path)
    File.write(env_file_path, '', mode: 'a')
  end

  def self.append_missing_env_vars(env_file_path)
    Dotenv.load(env_file_path)
    missing_vars = REQUIRED_ENV_VARS.reject { |var| ENV.fetch(var, nil) }
    return if missing_vars.empty?

    File.write(env_file_path, "#{missing_vars.map { |var| "#{var}=''" }.join("\n")}\n", mode: 'a')
  end

  # Configuration constants for S3 Supabase integration.
  module S3Config
    ENV_FILE_PATH = File.join(Dir.home, '.timet', '.env')
    Timet.ensure_env_file_exists(ENV_FILE_PATH)
    Dotenv.load(ENV_FILE_PATH)

    S3_ENDPOINT = ENV.fetch('S3_ENDPOINT', nil)
    S3_ACCESS_KEY = ENV.fetch('S3_ACCESS_KEY', nil)
    S3_SECRET_KEY = ENV.fetch('S3_SECRET_KEY', nil)
    S3_REGION = ENV.fetch('S3_REGION', 'us-west-1')
    LOG_FILE_PATH = File.join(Dir.home, '.timet', 's3_supabase.log')
  end

  # Struct to hold S3 object reference (bucket name and object key).
  S3ObjectRef = Struct.new(:bucket_name, :object_key, keyword_init: true)

  # S3Supabase provides methods to interact with an S3-compatible storage service.
  class S3Supabase
    include S3Config

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

    def create_bucket(bucket_name)
      @s3_client.create_bucket(bucket: bucket_name)
      log(:info, "Bucket '#{bucket_name}' created successfully!")
      true
    rescue Aws::S3::Errors::BucketAlreadyExists
      log(:error, "Error: The bucket '#{bucket_name}' already exists.")
      false
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou
      log(:error, "Error: The bucket '#{bucket_name}' is already owned by you.")
      false
    rescue Aws::S3::Errors::ServiceError => e
      log(:error, "Error creating bucket: #{e.message}")
      false
    end

    def list_objects(bucket_name)
      response = @s3_client.list_objects_v2(bucket: bucket_name)
      contents = response.contents

      if contents.empty?
        log(:error, "No objects found in '#{bucket_name}'.")
        return false
      end

      log_object_list(contents, bucket_name)
      contents.map(&:to_h)
    rescue Aws::S3::Errors::ServiceError => e
      log(:error, "Error listing objects: #{e.message}")
      nil
    end

    def upload_file(bucket_name, file_path, object_key)
      File.open(file_path, 'rb') do |file|
        @s3_client.put_object(
          bucket: bucket_name,
          key: object_key,
          body: file
        )
      end
      log(:info, "File '#{object_key}' uploaded successfully.")
    rescue Aws::S3::Errors::ServiceError => e
      log(:error, "Error uploading file: #{e.message}")
    end

    def download_file(bucket_name, object_key, download_path)
      response = @s3_client.get_object(bucket: bucket_name, key: object_key)
      File.binwrite(download_path, response.body.read)
      log(:info, "File '#{object_key}' downloaded successfully.")
    rescue Aws::S3::Errors::ServiceError => e
      log(:error, "Error downloading file: #{e.message}")
    end

    def delete_object(bucket_name, object_key)
      @s3_client.delete_object(bucket: bucket_name, key: object_key)
      log(:info, "Object '#{object_key}' deleted successfully.")
    rescue Aws::S3::Errors::ServiceError => e
      log(:error, "Error deleting object: #{e.message}")
      raise e
    end

    def delete_bucket(bucket_name)
      delete_all_objects_in_bucket(bucket_name)
      @s3_client.delete_bucket(bucket: bucket_name)
      log(:info, "Bucket '#{bucket_name}' deleted successfully.")
    rescue Aws::S3::Errors::ServiceError => e
      log(:error, "Error deleting bucket: #{e.message}")
      raise e
    end

    private

    def log(level, message)
      @logger.send(level, message)
    end

    def log_object_list(contents, bucket_name)
      log(:error, "Objects in '#{bucket_name}':")
      contents.each { |object| log(:error, "- #{object.key} (Last modified: #{object.last_modified})") }
    end

    def delete_all_objects_in_bucket(bucket_name)
      list_objects(bucket_name)
      contents = @s3_client.list_objects_v2(bucket: bucket_name).contents
      contents.each { |object| delete_object(bucket_name, object.key) }
    end

    def validate_env_vars
      missing_vars = []
      missing_vars.concat(check_env_var('S3_ENDPOINT', S3_ENDPOINT))
      missing_vars.concat(check_env_var('S3_ACCESS_KEY', S3_ACCESS_KEY))
      missing_vars.concat(check_env_var('S3_SECRET_KEY', S3_SECRET_KEY))

      return if missing_vars.empty?

      raise CustomError, "Missing required environment variables (.env): #{missing_vars.join(', ')}"
    end

    def check_env_var(name, value)
      return [] if value && !value.empty?

      @s3_client&.list_objects_v2(bucket: 'dummy')
      [name]
    end

    # Custom error class that suppresses the backtrace for cleaner error messages.
    class CustomError < StandardError
      def backtrace
        nil
      end
    end
  end
end
