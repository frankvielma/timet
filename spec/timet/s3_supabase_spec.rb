# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_context 'when S3Supabase is set up' do
  let(:s3_endpoint) { 'http://localhost:9000' }
  let(:s3_access_key) { 'test' }
  let(:s3_secret_key) { 'test123' }
  let(:s3_region) { 'us-west-1' }
  let(:bucket_name) { 'test-bucket' }
  let(:env_file_path) { File.join('/tmp', '.timet', '.env') }
  let(:s3_client_mock) { instance_double(Aws::S3::Client) }

  before do
    # Create and populate .env file
    FileUtils.mkdir_p(File.dirname(env_file_path))
    File.write(env_file_path, <<~ENV)
      S3_ENDPOINT='#{s3_endpoint}'
      S3_ACCESS_KEY='#{s3_access_key}'
      S3_SECRET_KEY='#{s3_secret_key}'
      S3_REGION='#{s3_region}'
    ENV

    # Load environment variables
    Dotenv.load(env_file_path)

    # Mock AWS S3 Client
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client_mock)

    if File.exist?(Timet::S3Supabase::ENV_FILE_PATH)
      FileUtils.mv(Timet::S3Supabase::ENV_FILE_PATH, "#{Timet::S3Supabase::ENV_FILE_PATH}.backup", force: true)
    end
    ENV.delete('S3_ENDPOINT') # Ensure it's missing
  end

  after do
    if File.exist?("#{Timet::S3Supabase::ENV_FILE_PATH}.backup")
      FileUtils.mv("#{Timet::S3Supabase::ENV_FILE_PATH}.backup", Timet::S3Supabase::ENV_FILE_PATH, force: true)
    end
  end
end

RSpec.describe Timet::S3Supabase do
  include_context 'when S3Supabase is set up'

  describe '#initialize' do
    it 'initializes successfully with valid environment variables' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe '#create_bucket' do
    let(:s3_supabase) { described_class.new }

    it 'creates a bucket successfully' do
      allow(s3_client_mock).to receive(:create_bucket).with(bucket: bucket_name)
      expect(s3_supabase.create_bucket(bucket_name)).to be true
    end

    it 'handles bucket already exists error' do
      allow(s3_client_mock).to receive(:create_bucket)
        .and_raise(Aws::S3::Errors::BucketAlreadyExists.new(nil, 'Bucket exists'))
      expect(s3_supabase.create_bucket(bucket_name)).to be false
    end
  end

  describe '#list_objects' do
    let(:s3_supabase) { described_class.new }
    let(:empty_response) { instance_double(Aws::S3::Types::ListObjectsV2Output, contents: []) }
    let(:object_mock) { instance_double(Aws::S3::Types::Object, key: 'test.txt', last_modified: Time.now, to_h: {}) }
    let(:populated_response) { instance_double(Aws::S3::Types::ListObjectsV2Output, contents: [object_mock]) }

    it 'returns false for empty bucket' do
      allow(s3_client_mock).to receive(:list_objects_v2)
        .with(bucket: bucket_name)
        .and_return(empty_response)
      expect(s3_supabase.list_objects(bucket_name)).to be false
    end

    it 'returns array of objects for non-empty bucket' do
      allow(s3_client_mock).to receive(:list_objects_v2)
        .with(bucket: bucket_name)
        .and_return(populated_response)
      expect(s3_supabase.list_objects(bucket_name)).to be_an(Array)
    end
  end

  describe '#upload_file' do
    let(:s3_supabase) { described_class.new }
    let(:file_path) { 'test.txt' }
    let(:object_key) { 'uploaded.txt' }

    before do
      File.write(file_path, 'test content')
    end

    after do
      FileUtils.rm_f(file_path)
    end

    it 'uploads file successfully' do
      allow(s3_client_mock).to receive(:put_object)
      expect { s3_supabase.upload_file(bucket_name, file_path, object_key) }
        .not_to raise_error
    end
  end
end
